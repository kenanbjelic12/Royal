class_name BattleManager
extends Node3D
## Runs one battle: builds the world, owns all units/towers, resolves
## collisions, elixir, the match clock, crowns and the final result.

signal unit_spawned(unit: MonsterController)
signal tower_destroyed(tower: TowerController)
signal crowns_changed(player: int, enemy: int)
signal phase_changed(phase: StringName)   # &"battle", &"double", &"overtime"
signal battle_finished(result: Dictionary)
signal card_played(team: int, data: MonsterData, pos: Vector3)

const TEAM_COLORS := [Color("#3d8bff"), Color("#ff4a4a")]
const MATCH_TIME := 180.0
const DOUBLE_ELIXIR_AT := 60.0   # remaining seconds when double elixir starts
const OVERTIME := 60.0

@export var player_ai_controlled := false   # used by automated tests
@export var enemy_ai_enabled := true
@export var build_hud := true

var arena: Arena
var camera: BattleCamera
var units_root: Node3D
var projectiles_root: Node3D
var effects: Node3D
var elixir: Array[ElixirManager] = []
var card_manager: CardManager
var enemy_ai: EnemyAI
var player_ai: EnemyAI
var hud: Node

var units: Array[MonsterController] = []
var towers: Array = [[], []]       # per team: Array[TowerController]
var crowns := [0, 0]
var time_left := MATCH_TIME
var phase := &"battle"
var finished := false
var result: Dictionary = {}
var stats := {"spawned": [0, 0], "cards_played": [{}, {}]}

func _ready() -> void:
	_build_world()
	_spawn_towers()
	for t in 2:
		var em := ElixirManager.new()
		em.name = "Elixir%d" % t
		em.team = t
		add_child(em)
		elixir.append(em)
	card_manager = CardManager.new()
	card_manager.name = "CardManager"
	card_manager.setup(self, 0)
	add_child(card_manager)
	if enemy_ai_enabled:
		enemy_ai = EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.setup(self, 1)
		add_child(enemy_ai)
	if player_ai_controlled:
		player_ai = EnemyAI.new()
		player_ai.name = "PlayerAI"
		player_ai.setup(self, 0)
		add_child(player_ai)
	if build_hud:
		hud = load("res://Scenes/UI/BattleHUD.tscn").instantiate()
		hud.battle = self
		add_child(hud)
	AudioManager.play_music(&"battle")

func _build_world() -> void:
	var we := WorldEnvironment.new()
	we.environment = WorldEnv.make_environment()
	add_child(we)
	var sun := WorldEnv.add_lights(self, SettingsManager.shadows_enabled(), -30.0, -55.0)
	SettingsManager.changed.connect(func(): if is_instance_valid(sun): sun.shadow_enabled = SettingsManager.shadows_enabled())
	arena = load("res://Scenes/Arena/Arena.tscn").instantiate()
	add_child(arena)
	camera = BattleCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.current = true
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	projectiles_root = Node3D.new()
	projectiles_root.name = "Projectiles"
	add_child(projectiles_root)
	effects = Node3D.new()
	effects.name = "Effects"
	add_child(effects)

func _spawn_towers() -> void:
	for team in 2:
		for info in ArenaLayout.tower_positions(team):
			var t := TowerController.new()
			t.name = "%s_%s_%d" % ["Player" if team == 0 else "Enemy", info.kind, info.lane]
			t.setup(info.kind, team, info.lane, _tower_level(team), self)
			t.position = info.pos
			units_root.add_child(t)
			towers[team].append(t)
			t.destroyed.connect(_on_tower_destroyed)

func _tower_level(team: int) -> int:
	return GameManager.player_level() if team == 0 else GameManager.enemy_level()

# ------------------------------------------------------------------ queries
func team_color(team: int) -> Color:
	return TEAM_COLORS[team]

func is_finished() -> bool:
	return finished

func effects_root() -> Node3D:
	return effects

func get_towers(team: int) -> Array:
	return towers[team]

func alive_towers(team: int) -> Array:
	return towers[team].filter(func(t): return t.is_alive())

func get_units(team: int) -> Array[MonsterController]:
	var out: Array[MonsterController] = []
	for u in units:
		if u.team == team and u.is_alive():
			out.append(u)
	return out

func get_enemies_of(team: int) -> Array:
	var out: Array = []
	for u in units:
		if u.team != team and u.is_alive():
			out.append(u)
	for t in towers[1 - team]:
		if t.is_alive():
			out.append(t)
	return out

func king_tower(team: int) -> TowerController:
	for t in towers[team]:
		if t.kind == &"king":
			return t
	return null

## Lanes where the given team may also deploy on the enemy half.
func open_enemy_lanes(team: int) -> Dictionary:
	var out := {-1: false, 1: false}
	for t in towers[1 - team]:
		if t.kind == &"princess" and not t.is_alive():
			out[t.lane] = true
	return out

func screen_to_ground(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0:
		return null
	return from + dir * t

# ------------------------------------------------------------------ spawning
func card_level(team: int, data: MonsterData) -> int:
	if team == 0:
		return EconomyManager.get_card_level(data.id)
	return GameManager.enemy_card_level(data.id)

## Validates, pays and spawns. Used by the player CardManager and the AI.
func deploy_card(team: int, data: MonsterData, pos: Vector3) -> bool:
	if finished:
		return false
	if not ArenaLayout.is_valid_deploy(team, pos, open_enemy_lanes(team)):
		return false
	if not elixir[team].spend(data.elixir_cost):
		return false
	var lvl := card_level(team, data)
	if data.spawn_count <= 1:
		spawn_monster(data, team, pos, lvl)
	else:
		# swarm: a small formation around the tapped point
		for i in data.spawn_count:
			var a := TAU * i / data.spawn_count + PI * 0.5
			var off := Vector3(cos(a), 0, sin(a)) * data.spawn_spread
			spawn_monster(data, team, pos + off, lvl, i > 0)
	stats.cards_played[team][data.id] = stats.cards_played[team].get(data.id, 0) + 1
	if team == 0 and not player_ai_controlled:
		EconomyManager.add_quest_progress("deploy", 1)
	card_played.emit(team, data, pos)
	if team == 0:
		SettingsManager.vibrate(25)
	return true

func spawn_monster(data: MonsterData, team: int, pos: Vector3, lvl := 1, quiet := false) -> MonsterController:
	var m := MonsterController.new()
	m.setup(data, team, lvl, self)
	m.name = "%s_%s_%d" % [data.id, team, stats.spawned[team]]
	m.position = ArenaLayout.clamp_to_arena(Vector3(pos.x, 0, pos.z), data.radius)
	units_root.add_child(m)
	units.append(m)
	stats.spawned[team] += 1
	m.died.connect(_on_unit_died)
	if not quiet:
		VFX.spawn_effect(effects, m.position, team_color(team))
		AudioManager.play(data.sfx_deploy)
	m.quiet_spawn = quiet
	unit_spawned.emit(m)
	return m

func spawn_projectile(info: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.setup(info, self)
	projectiles_root.add_child(p)
	return p

## Damages every valid enemy in a circle; returns the list of victims.
func damage_area(center: Vector3, r: float, amount: float, attacker_team: int, source: Combatant,
		hits_air: bool, hits_ground: bool, primary: Combatant = null) -> Array:
	var victims: Array = []
	for c: Combatant in get_enemies_of(attacker_team):
		if c.is_flying and not hits_air:
			continue
		if not c.is_flying and not hits_ground:
			continue
		var d := Vector2(c.global_position.x - center.x, c.global_position.z - center.z).length() - c.radius
		if d <= r or c == primary:
			victims.append(c)
	for c: Combatant in victims:
		c.take_damage(amount, source)
	return victims

func show_damage(c: Combatant, amount: float) -> void:
	if not SettingsManager.damage_numbers:
		return
	var col := Color("#fff4c2") if c.is_building else (Color("#9fd0ff") if c.team == 0 else Color("#ffb3b3"))
	VFX.damage_number(effects, c.aim_point() + Vector3(0, 0.9 if c.is_building else 0.5, 0), amount, col, c.is_building)

## Instant lightning that jumps to `extra` more enemies near the last one hit.
func chain_lightning(source: Combatant, from: Vector3, first: Combatant, dmg: float, extra: int, jump: float, hits_air: bool) -> void:
	var hit: Array = []
	var cur := first
	var p := from
	for i in extra + 1:
		if cur == null or not is_instance_valid(cur) or not cur.is_alive():
			break
		VFX.lightning_bolt(effects, p, cur.aim_point())
		VFX.lightning_hit(effects, cur.aim_point())
		cur.take_damage(dmg, source)
		hit.append(cur)
		p = cur.aim_point()
		var nxt: Combatant = null
		var best := INF
		for c: Combatant in get_enemies_of(source.team):
			if hit.has(c) or (c.is_flying and not hits_air):
				continue
			var d := c.ground_pos().distance_to(cur.ground_pos())
			if d <= jump and d < best:
				best = d
				nxt = c
		cur = nxt
	AudioManager.play(&"lightning_hit")

func shake_camera(amp: float, dur: float) -> void:
	if camera:
		camera.shake(amp, dur)

# ------------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	if finished:
		return
	_resolve_collisions()
	_tick_clock(delta)

func _resolve_collisions() -> void:
	var live: Array[MonsterController] = []
	for u in units:
		if is_instance_valid(u) and u.state != &"dead":
			live.append(u)
	# unit vs unit (same layer: ground with ground, air with air)
	for i in live.size():
		var a := live[i]
		for j in range(i + 1, live.size()):
			var b := live[j]
			if a.is_flying != b.is_flying:
				continue
			var d := Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
			var min_d := (a.radius + b.radius) * 0.9
			var dist := d.length()
			if dist >= min_d:
				continue
			if dist < 0.001:
				d = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				dist = 0.001
			var n := d / dist
			var overlap := min_d - dist
			var wa := b.mass / (a.mass + b.mass)
			var wb := 1.0 - wa
			# deploying units do not get shoved around much
			if a.state == &"deploying": wa *= 0.3
			if b.state == &"deploying": wb *= 0.3
			a.position -= Vector3(n.x, 0, n.y) * overlap * wa * 0.5
			b.position += Vector3(n.x, 0, n.y) * overlap * wb * 0.5
	# units vs towers, river and arena bounds
	for u in live:
		if not u.is_flying:
			for team in 2:
				for t in towers[team]:
					var d := Vector2(u.position.x - t.position.x, u.position.z - t.position.z)
					var min_d: float = u.radius + t.radius * (1.0 if t.is_alive() else 0.75)
					if d.length() < min_d:
						var n := d.normalized() if d.length() > 0.001 else Vector2(0, 1)
						u.position = Vector3(t.position.x + n.x * min_d, 0, t.position.z + n.y * min_d)
			_keep_out_of_river(u)
		u.position = ArenaLayout.clamp_to_arena(u.position, u.radius)

func _keep_out_of_river(u: MonsterController) -> void:
	var limit := ArenaLayout.RIVER_HALF + u.radius * 0.3
	if absf(u.position.z) >= limit:
		u.set_meta("bank", signf(u.position.z))
		return
	for bx: float in ArenaLayout.BRIDGE_X:
		var half := ArenaLayout.BRIDGE_HALF_W - u.radius * 0.6
		if absf(u.position.x - bx) <= half:
			return
		if absf(u.position.x - bx) <= ArenaLayout.BRIDGE_HALF_W + u.radius and absf(u.position.z) < ArenaLayout.RIVER_HALF:
			# slid against the railing while on the bridge: push back inside
			u.position.x = bx + clampf(u.position.x - bx, -half, half)
			return
	var bank: float = u.get_meta("bank", signf(u.position.z) if u.position.z != 0.0 else 1.0)
	u.position.z = bank * limit

func _tick_clock(delta: float) -> void:
	time_left -= delta
	if phase == &"battle" and time_left <= DOUBLE_ELIXIR_AT:
		_set_phase(&"double")
	if time_left > 0.0:
		return
	if phase != &"overtime":
		if crowns[0] != crowns[1]:
			_finish(0 if crowns[0] > crowns[1] else 1, "time")
			return
		_set_phase(&"overtime")
		time_left = OVERTIME
		return
	# overtime ran out: tie-break on the most damaged tower
	var lowest := [_lowest_tower_ratio(0), _lowest_tower_ratio(1)]
	if is_equal_approx(lowest[0], lowest[1]):
		_finish(-1, "draw")
	else:
		_finish(0 if lowest[0] > lowest[1] else 1, "tiebreak")

func _lowest_tower_ratio(team: int) -> float:
	var r := 1.0
	for t in towers[team]:
		r = minf(r, t.hp / t.max_hp)
	return r

func _set_phase(p: StringName) -> void:
	phase = p
	for em in elixir:
		em.multiplier = 2.0 if p != &"battle" else 1.0
	phase_changed.emit(p)

func _on_unit_died(c: Combatant) -> void:
	units.erase(c)

func _on_tower_destroyed(t: TowerController) -> void:
	var scorer := 1 - t.team
	if t.kind == &"king":
		crowns[scorer] = 3
	else:
		crowns[scorer] = mini(crowns[scorer] + 1, 3)
		var king := king_tower(t.team)
		if king:
			king.activate()
	crowns_changed.emit(crowns[0], crowns[1])
	AudioManager.play_voice("crowd_cheer")
	if t.team == 0 and t.kind != &"king":
		AudioManager.play_voice("king_laugh")   # the enemy king gloats
	tower_destroyed.emit(t)
	SettingsManager.vibrate(120)
	if t.kind == &"king" or phase == &"overtime":
		# king falls -> instant win; any tower in overtime -> sudden death win
		if t.kind == &"king":
			for other in towers[t.team]:
				if other.is_alive():
					other.hp = 0.0
					other.model.show_destroyed()
		_finish(scorer, "king" if t.kind == &"king" else "overtime")

func _finish(winner: int, reason: String) -> void:
	if finished:
		return
	finished = true
	for em in elixir:
		em.running = false
	for u in units:
		if is_instance_valid(u) and u.model:
			u.model.set_moving(false)
			u.model.celebrating = u.team == winner and u.is_alive()
	result = {
		"winner": winner, "won": winner == 0, "draw": winner == -1, "reason": reason,
		"crowns_player": crowns[0], "crowns_enemy": crowns[1],
		"time_left": time_left, "phase": phase,
	}
	result.merge(GameManager.apply_battle_result(result), true)
	AudioManager.stop_music()
	AudioManager.play(&"victory" if winner == 0 else &"defeat")
	AudioManager.play_voice("crowd_victory" if winner == 0 else "crowd_defeat")
	battle_finished.emit(result)

## Debug / test helper: ends the match immediately.
func force_finish(winner: int) -> void:
	_finish(winner, "forced")
