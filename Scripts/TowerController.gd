class_name TowerController
extends Combatant
## Princess / King tower: auto-targets the nearest enemy in range (ground and
## air) and shoots arrows (princess) or cannonballs (king). The king tower
## sleeps until it is damaged or one of its princess towers falls.

const STATS := {
	&"princess": {"hp": 2600.0, "damage": 85.0, "speed": 0.8, "range": 7.5, "radius": ArenaLayout.PRINCESS_RADIUS, "name": "Princess Tower"},
	&"king": {"hp": 4200.0, "damage": 105.0, "speed": 1.0, "range": 7.0, "radius": ArenaLayout.KING_RADIUS, "name": "King Tower"},
}

signal destroyed(tower: TowerController)

var kind := &"princess"
var lane := 0
var damage := 85.0
var attack_speed := 0.8
var attack_range := 7.5
var active := true
var target: Combatant
var cooldown := 0.5
var model: TowerModel
var _shot_target: Combatant

const TILT_DEG := 22.0

func setup(p_kind: StringName, p_team: int, p_lane: int, p_level: int, p_battle: Node) -> void:
	kind = p_kind
	team = p_team
	lane = p_lane
	level = p_level
	battle = p_battle
	var s: Dictionary = STATS[kind]
	var mult := 1.0 + 0.08 * (level - 1)
	max_hp = roundf(s.hp * mult)
	hp = max_hp
	damage = roundf(s.damage * mult)
	attack_speed = s.speed
	attack_range = s.range
	radius = s.radius
	mass = 1000.0
	is_building = true
	display_name = s.name
	active = kind != &"king"

func _ready() -> void:
	model = TowerModel.new()
	model.kind = kind
	model.team_color = battle.team_color(team)
	model.sleeping = not active
	add_child(model)
	# models are built facing -Z; rotate so banners and guards face the camera
	model.rotation.y = PI
	# lean slightly toward the high camera so walls, banner and torches read
	# like the painted arena (purely visual)
	model.rotation.x = deg_to_rad(TILT_DEG)
	model.impact.connect(_on_impact)

func activate() -> void:
	if active or hp <= 0.0:
		return
	active = true
	model.sleeping = false
	AudioManager.play(&"king_wake")
	VFX.burst(battle.effects_root(), global_position + Vector3(0, 3.6, 0), Color(1, 0.9, 0.4), 16, 3.0, 0.2, 0.6, Vector3.ZERO, true, true)

func _process(delta: float) -> void:
	if hp <= 0.0 or battle == null or battle.is_finished():
		return
	_tick_status(delta)
	if not active:
		return
	cooldown -= delta
	if target == null or not is_instance_valid(target) or not target.is_alive() or not _in_range(target):
		target = _find_target()
	if target == null:
		return
	model.aim_at(target.global_position)
	if cooldown <= 0.0 and not model.is_attacking():
		cooldown = attack_speed
		_shot_target = target
		model.play_attack(minf(model.attack_anim_len, attack_speed * 0.9))

func _in_range(c: Combatant) -> bool:
	return ground_pos().distance_to(c.ground_pos()) - c.radius <= attack_range

func _find_target() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for c: Combatant in battle.get_enemies_of(team):
		if c.is_building or not c.is_alive():
			continue
		if c is MonsterController and (c as MonsterController).state == &"deploying":
			continue
		var d := ground_pos().distance_to(c.ground_pos()) - c.radius
		if d <= attack_range and d < best_d:
			best_d = d
			best = c
	return best

func _on_impact() -> void:
	if _shot_target == null or not is_instance_valid(_shot_target) or not _shot_target.is_alive():
		return
	var is_king := kind == &"king"
	AudioManager.play(&"cannon" if is_king else &"arrow")
	battle.spawn_projectile({
		"type": Projectile.Kind.CANNONBALL if is_king else Projectile.Kind.ARROW,
		"from": model.get_muzzle_position(), "target": _shot_target,
		"speed": 13.0 if is_king else 18.0, "damage": damage, "team": team, "source": self,
		"splash": 0.0, "hits_air": true, "hits_ground": true,
	})

func _on_damaged(_amount: float) -> void:
	if model and hp > 0.0:
		model.play_hit()
	if kind == &"king" and not active:
		activate()

func _die() -> void:
	model.show_destroyed()
	AudioManager.play(&"tower_destroyed")
	VFX.tower_explosion(battle.effects_root(), ground_pos())
	battle.shake_camera(0.45, 0.5)
	destroyed.emit(self)
	super._die()
