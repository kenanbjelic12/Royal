class_name EnemyAI
extends Node
## Opponent brain (one difficulty level). Not random: every few hundred ms it
## evaluates threats on its half, picks counters with a data-driven matchup
## score (time-to-kill vs. survival, air immunity, cost), places defenders
## between the threat and its towers, supports its own pushes, and launches
## tank+support attacks on the weakest lane when it has enough elixir.

var battle: BattleManager
var team := 1
var think_min := 0.55
var think_max := 1.0
var attack_threshold := 8.0
var _think := 1.5
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _last_played: StringName = &""
var _tank_push_next := true
var _recent: Array[StringName] = []
var _punish_cooldown := 0.0
var _pending_support: Array = []   # [{data, lane, at_time}]
var log_decisions := false
var decisions: Array[String] = []

func setup(p_battle: BattleManager, p_team: int) -> void:
	battle = p_battle
	team = p_team
	_rng.randomize()

func _process(delta: float) -> void:
	if battle == null or battle.is_finished():
		return
	_clock += delta
	_punish_cooldown -= delta
	_think -= delta
	if _think > 0.0:
		return
	_think = _rng.randf_range(think_min, think_max)
	_decide()

func elixir() -> float:
	return battle.elixir[team].elixir

func hand() -> Array[MonsterData]:
	return CardDatabase.deck()

func home() -> float:
	return ArenaLayout.home_sign(team)

# ------------------------------------------------------------------ main loop
func _decide() -> void:
	var threats := _threats()
	if not threats.is_empty():
		if _defend(threats):
			return
	if _support_push():
		return
	if _punish():
		return
	if elixir() >= attack_threshold:
		_attack()
	elif elixir() >= 9.7:
		_dump()

## Enemy units on (or about to reach) our half, sorted by danger.
func _threats() -> Array:
	var out: Array = []
	for u: MonsterController in battle.get_units(1 - team):
		var local_z := u.ground_pos().z * home()  # >0 = our half
		if local_z > -3.5:
			var danger := float(u.data.elixir_cost) * (u.hp / u.max_hp) + (local_z + 4.0) * 0.25
			out.append({"unit": u, "danger": danger})
	out.sort_custom(func(a, b): return a.danger > b.danger)
	return out

func _defenders_near(pos: Vector3, r: float) -> float:
	var value := 0.0
	for u: MonsterController in battle.get_units(team):
		if u.ground_pos().distance_to(pos) <= r:
			value += u.data.elixir_cost * (u.hp / u.max_hp)
	return value

func _defend(threats: Array) -> bool:
	var main: MonsterController = threats[0].unit
	var threat_value := 0.0
	for t in threats:
		if (t.unit as MonsterController).ground_pos().distance_to(main.ground_pos()) < 4.0:
			threat_value += t.unit.data.elixir_cost * (t.unit.hp / t.unit.max_hp)
	var covered := _defenders_near(main.ground_pos(), 6.0)
	if covered >= threat_value * 0.9:
		return false
	# small, slow threats far away can be left to the towers for a moment
	if threat_value <= 3.0 and main.ground_pos().z * home() < 3.0 and elixir() < 6.0:
		return false
	var best: MonsterData = null
	var best_score := -INF
	for c in hand():
		if not battle.elixir[team].can_afford(c.elixir_cost):
			continue
		var s := matchup_score(c, main.data, main.hp)
		if s <= 0.0:
			continue   # cannot fight this threat at all
		if c.id == _last_played:
			s *= 0.9
		elif not _recent.has(c.id):
			s += 0.12   # mild preference for cards not seen recently (less predictable)
		s += _rng.randf_range(0.0, 0.08)
		if s > best_score:
			best_score = s
			best = c
	if best == null or best_score <= 0.05:
		return false
	var pos := _defense_position(best, main)
	if _play(best, pos, "defend vs %s" % main.data.id):
		# counter-push: sometimes follow a good defence with support
		if _rng.randf() < 0.4:
			_queue_support(ArenaLayout.lane_of(pos.x), 5.0)
		return true
	return false

## How good is card `c` against enemy monster `e` (higher = better).
func matchup_score(c: MonsterData, e: MonsterData, e_hp := -1.0) -> float:
	if c.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
		return 0.0
	if e.is_flying and not c.can_hit_air:
		return 0.0
	var e_health := e_hp if e_hp > 0.0 else e.max_hp
	var my_dps := c.damage / c.attack_speed + c.poison_dps * 0.6
	var ttk := e_health / maxf(my_dps, 1.0)                 # how fast I kill it
	var e_can_hit_me := e.target_type != MonsterData.TargetType.BUILDINGS_ONLY and (not c.is_flying or e.can_hit_air)
	var survive := 99.0
	if e_can_hit_me:
		survive = c.max_hp / maxf(e.damage / e.attack_speed, 1.0)
	var ratio := minf(survive / ttk, 6.0)
	var s := ratio / float(c.elixir_cost)
	if e.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
		s += my_dps / 400.0      # free hits on a tank that ignores troops
	if e.splash_radius > 0.0 and c.max_hp < 700.0:
		s *= 0.85
	if c.slow_amount > 0.0:
		s *= 1.1
	return s

func _defense_position(c: MonsterData, threat: MonsterController) -> Vector3:
	var tp := threat.ground_pos()
	var tower := _closest_own_tower(tp)
	var tower_pos: Vector3 = tower.ground_pos() if tower else Vector3(tp.x, 0, ArenaLayout.PRINCESS_Z * home())
	var to_tower := tower_pos - tp
	var dir := to_tower.normalized() if to_tower.length() > 0.1 else Vector3(0, 0, home())
	var pos: Vector3
	if c.attack_range >= 2.0:
		# ranged: stay back near the tower, inside our own territory
		pos = tower_pos - dir * 1.0 + Vector3(_rng.randf_range(-0.8, 0.8), 0, home() * 0.6)
	elif threat.data.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
		pos = tp + dir * 1.2 + Vector3(_rng.randf_range(-0.6, 0.6), 0, 0)
	else:
		pos = tp + dir * minf(2.5, to_tower.length() * 0.5)
	return ArenaLayout.clamp_deploy(team, pos, battle.open_enemy_lanes(team))

func _closest_own_tower(p: Vector3) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for t in battle.alive_towers(team):
		var d: float = (t as Combatant).ground_pos().distance_to(p)
		if d < bd:
			bd = d
			best = t
	return best

# ------------------------------------------------------------------ offense
func _weak_lane() -> int:
	var best := 1 if _rng.randf() < 0.5 else -1
	var lowest := INF
	for t in battle.get_towers(1 - team):
		if t.kind != &"princess":
			continue
		var ratio: float = t.hp / t.max_hp if t.is_alive() else -1.0
		if ratio < lowest:
			lowest = ratio
			best = t.lane
	return best

func _attack() -> void:
	var lane := _weak_lane()
	var bx: float = ArenaLayout.BRIDGE_X[0] if lane < 0 else ArenaLayout.BRIDGE_X[1]
	var cards := {}
	for c in hand():
		cards[c.id] = c
	var golem: MonsterData = _find(func(c): return c.target_type == MonsterData.TargetType.BUILDINGS_ONLY)
	# alternate between a slow heavy-tank push and a fast bridge push
	var tank_push := _tank_push_next
	_tank_push_next = not _tank_push_next
	if golem and tank_push and battle.elixir[team].can_afford(golem.elixir_cost):
		# slow tank push from the back, support follows when it reaches the bridge
		var pos := Vector3(bx * 0.75, 0, ArenaLayout.KING_Z * home() - home() * 1.5)
		if _play(golem, pos, "attack: tank at back, lane %d" % lane):
			_queue_support(lane, 6.0)
			return
	var tank: MonsterData = _best_by(func(c): return c.max_hp if c.target_type == MonsterData.TargetType.ANY and not c.is_flying else -1.0)
	var support: MonsterData = _best_by(func(c): return c.attack_range if c.attack_range >= 2.0 else -1.0)
	if tank and battle.elixir[team].can_afford(tank.elixir_cost):
		var pos := Vector3(bx, 0, home() * (ArenaLayout.RIVER_HALF + 2.0))
		if _play(tank, pos, "attack: bridge push lane %d" % lane):
			if support:
				_queue_support(lane, 2.0)
			return
	if support and battle.elixir[team].can_afford(support.elixir_cost):
		_play(support, Vector3(bx, 0, home() * 6.0), "attack: ranged lane %d" % lane)

func _queue_support(lane: int, delay: float) -> void:
	_pending_support.append({"lane": lane, "at": _clock + delay})

## Adds a ranged supporter behind our leading unit when it nears the bridge.
func _support_push() -> bool:
	if _pending_support.is_empty():
		return false
	var now := _clock
	var job: Dictionary = _pending_support[0]
	if now < job.at:
		return false
	var leader: MonsterController = null
	for u: MonsterController in battle.get_units(team):
		var lz := u.ground_pos().z * home()
		if leader == null or lz < leader.ground_pos().z * home():
			leader = u
	if leader == null:
		_pending_support.pop_front()
		return false
	var lz := leader.ground_pos().z * home()
	if lz > ArenaLayout.RIVER_HALF + 5.0 and now < job.at + 8.0:
		return false   # wait until the tank gets closer to the river
	var support: MonsterData = _best_by(func(c): return (c.attack_range + (2.0 if c.can_hit_air else 0.0)) if c.attack_range >= 2.0 and battle.elixir[team].can_afford(c.elixir_cost) else -1.0)
	if support == null:
		if now > job.at + 12.0:
			_pending_support.pop_front()
		return false
	var lp := leader.ground_pos()
	var pos := Vector3(lp.x, 0, maxf(lz + 2.5, ArenaLayout.DEPLOY_MIN_Z + 0.5) * home())
	_pending_support.pop_front()
	return _play(support, pos, "support behind %s" % leader.data.id)

## Quick counter-punch with a cheap fast unit when the opponent is low on elixir.
func _punish() -> bool:
	if _punish_cooldown > 0.0 or battle.elixir[1 - team].elixir > 2.0 or elixir() < 7.0:
		return false
	if not battle.get_units(1 - team).is_empty():
		return false   # opponent still has troops that would defend
	_punish_cooldown = 25.0
	var fast: MonsterData = _best_by(func(c): return c.move_speed if c.move_speed >= 2.5 and battle.elixir[team].can_afford(c.elixir_cost) else -1.0)
	if fast == null:
		return false
	var lane := _weak_lane()
	var bx: float = ArenaLayout.BRIDGE_X[0] if lane < 0 else ArenaLayout.BRIDGE_X[1]
	return _play(fast, Vector3(bx, 0, home() * (ArenaLayout.DEPLOY_MIN_Z + 0.3)), "punish low elixir")

func _dump() -> void:
	# never sit at full elixir: play the cheapest card safely at the back
	var cheapest: MonsterData = _best_by(func(c): return 100.0 - c.elixir_cost)
	if cheapest:
		_play(cheapest, Vector3(_rng.randf_range(-4, 4), 0, home() * 12.0), "avoid elixir leak")

# ------------------------------------------------------------------ helpers
func _find(pred: Callable) -> MonsterData:
	for c in hand():
		if pred.call(c):
			return c
	return null

func _best_by(score: Callable) -> MonsterData:
	var best: MonsterData = null
	var bs := -INF
	for c in hand():
		var s: float = score.call(c)
		if s >= 0.0 and s > bs:
			bs = s
			best = c
	return best

func _play(c: MonsterData, pos: Vector3, why: String) -> bool:
	pos = ArenaLayout.clamp_deploy(team, pos, battle.open_enemy_lanes(team))
	if battle.deploy_card(team, c, pos):
		_last_played = c.id
		_recent.append(c.id)
		if _recent.size() > 3:
			_recent.pop_front()
		var line := "%.1fs  %s -> %s at (%.1f, %.1f)" % [battle.time_left, why, c.id, pos.x, pos.z]
		decisions.append(line)
		if log_decisions:
			print("[AI%d] %s" % [team, line])
		return true
	return false
