class_name MonsterController
extends Combatant
## A summoned monster: HP/status, movement, attacks and animation driving.
## Targeting and pathing live in MonsterAI.

const DEPLOY_TIME := 1.0
const TURN_SPEED := 10.0

var data: MonsterData
var ai: MonsterAI
var model: MonsterModel
var state := &"deploying"   # deploying, active, dead
var deploy_timer := DEPLOY_TIME
var attack_cooldown := 0.0
var velocity := Vector3.ZERO
var facing := 0.0
var has_hit_once := false
var deployed_at_msec := 0
var _attack_target: Combatant
var _ring: MeshInstance3D
var _status_fx: CPUParticles3D

## Must be called before adding to the tree.
func setup(p_data: MonsterData, p_team: int, p_level: int, p_battle: Node) -> void:
	data = p_data
	team = p_team
	level = p_level
	battle = p_battle
	display_name = data.display_name
	max_hp = data.hp_at(level)
	hp = max_hp
	radius = data.radius
	mass = data.mass
	is_flying = data.is_flying
	is_building = false
	ai = MonsterAI.new(self)
	facing = 0.0 if team == 0 else PI  # face the enemy side

func _ready() -> void:
	deployed_at_msec = Time.get_ticks_msec()
	model = MonsterFactory.create_model(data)
	model.team_color = battle.team_color(team) if battle else Color.WHITE
	add_child(model)
	model.position.y = ArenaLayout.FLY_HEIGHT if is_flying else 0.0
	model.rotation.y = facing
	model.impact.connect(_on_impact)
	AudioManager.play_voice(String(data.id) + "_deploy")
	model.death_finished.connect(queue_free)
	_build_ring()
	# deploy: drop in from above with a squash
	model.scale = Vector3.ONE * data.model_scale * ArenaLayout.UNIT_VISUAL_SCALE * 0.2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(model, "scale", Vector3.ONE * data.model_scale * ArenaLayout.UNIT_VISUAL_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var base_y := model.position.y
	model.position.y = base_y + 2.5
	tw.tween_property(model, "position:y", base_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.85
	tm.outer_radius = radius * 1.05
	tm.rings = 28
	tm.ring_segments = 4
	_ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c: Color = battle.team_color(team) if battle else Color.WHITE
	m.albedo_color = Color(c.r, c.g, c.b, 0.75)
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.03
	add_child(_ring)

func _process(delta: float) -> void:
	if state == &"dead" or battle == null:
		return
	if battle.is_finished():
		model.set_moving(false)
		return
	_tick_status(delta)
	if hp <= 0.0:
		return
	_update_status_visuals()
	model.move_speed_factor = speed_factor()
	if state == &"deploying":
		deploy_timer -= delta
		if deploy_timer <= 0.0:
			state = &"active"
		return
	attack_cooldown -= delta * speed_factor()
	ai.update(delta)
	var target := ai.target
	if target == null:
		velocity = Vector3.ZERO
		model.set_moving(false)
		return
	var in_range := ai.in_attack_range(target)
	if in_range or model.is_attacking():
		velocity = Vector3.ZERO
		model.set_moving(false)
		_face_towards(target.ground_pos(), delta)
		if in_range and attack_cooldown <= 0.0 and not model.is_attacking():
			_start_attack(target)
	else:
		var wp := ai.next_waypoint(target.ground_pos())
		var dir := wp - ground_pos()
		dir.y = 0
		if dir.length() > 0.01:
			dir = dir.normalized()
		velocity = dir * data.move_speed * speed_factor()
		global_position += velocity * delta
		model.set_moving(true)
		_face_towards(global_position + dir, delta)
		# first attack after reaching the target comes quickly
		attack_cooldown = minf(attack_cooldown, 0.25)

func _face_towards(p: Vector3, delta: float) -> void:
	var d := p - ground_pos()
	if d.length() < 0.001:
		return
	var want := atan2(-d.x, -d.z)
	facing = lerp_angle(facing, want, clampf(TURN_SPEED * delta, 0, 1))
	model.rotation.y = facing

func _start_attack(target: Combatant) -> void:
	_attack_target = target
	attack_cooldown = data.attack_speed
	var anim_len := minf(model.attack_anim_len, data.attack_speed * 0.92) / maxf(speed_factor(), 0.3)
	model.play_attack(anim_len)

func _on_impact() -> void:
	var target := _attack_target
	if state != &"active" or target == null or not is_instance_valid(target) or not target.is_alive():
		return
	if not ai.in_attack_range(target, 0.8):
		return
	var dmg := data.damage_at(level)
	if not has_hit_once:
		dmg *= data.first_hit_multiplier
		has_hit_once = true
	AudioManager.play(data.sfx_attack)
	if randf() < 0.35:
		AudioManager.play_voice(String(data.id) + "_attack", -2.0)
	if data.projectile != MonsterData.ProjectileType.NONE:
		battle.spawn_projectile({
			"type": data.projectile, "from": model.get_muzzle_position(), "target": target,
			"speed": data.projectile_speed, "damage": dmg, "team": team, "source": self,
			"splash": data.splash_radius, "hits_air": data.can_hit_air, "hits_ground": true,
			"slow": data.slow_amount, "slow_time": data.slow_duration,
			"poison": data.poison_dps, "poison_time": data.poison_duration,
		})
		return
	# melee
	var hit_pos := target.aim_point()
	if data.splash_radius > 0.0:
		var center := ground_pos() + (target.ground_pos() - ground_pos()).normalized() * (radius + data.attack_range * 0.6)
		battle.damage_area(center, data.splash_radius + 0.3, dmg, team, self, data.can_hit_air, true, target)
	else:
		target.take_damage(dmg, self)
	match data.id:
		&"fire_knight":
			VFX.slash_arc(battle.effects_root(), ground_pos() + Vector3(0, 0.55, 0), facing, Color(1, 0.55, 0.15), 1.25, -15.0)
			VFX.fire_hit(battle.effects_root(), hit_pos)
		&"shadow_assassin":
			VFX.slash_arc(battle.effects_root(), ground_pos() + Vector3(0, 0.45, 0), facing, Color(0.75, 0.45, 1.0), 0.85, 25.0, 130.0, 0.2)
			VFX.slash_arc(battle.effects_root(), ground_pos() + Vector3(0, 0.45, 0), facing + 0.3, Color(0.4, 0.9, 1.0), 0.8, -25.0, 130.0, 0.24)
			VFX.dagger_hit(battle.effects_root(), hit_pos)
		&"stone_golem":
			VFX.rock_hit(battle.effects_root(), hit_pos)
			battle.shake_camera(0.18, 0.25)
		_:
			VFX.burst(battle.effects_root(), hit_pos, data.accent_color, 12, 3.0, 0.18, 0.4)

func _on_damaged(_amount: float) -> void:
	if model and hp > 0.0:
		model.play_hit()

func _die() -> void:
	if state == &"dead":
		return
	state = &"dead"
	velocity = Vector3.ZERO
	if not AudioManager.play_voice(String(data.id) + "_death"):
		AudioManager.play(&"death")
	VFX.death_poof(battle.effects_root(), aim_point())
	if _ring:
		_ring.visible = false
	if _status_fx:
		_status_fx.emitting = false
	model.play_death()
	super._die()

func _update_status_visuals() -> void:
	var tint := Color(0, 0, 0, 0)
	if slow_time > 0.0:
		tint = Color(0.45, 0.85, 1.0, 0.45)
	elif poison_time > 0.0:
		tint = Color(0.45, 1.0, 0.25, 0.3 + 0.15 * sin(Time.get_ticks_msec() * 0.012))
	model.status_tint = tint
	var want_fx := poison_time > 0.0
	if want_fx and _status_fx == null:
		_status_fx = VFX.status_bubbles(self, Color(0.5, 1.0, 0.3))
		_status_fx.position = Vector3(0, model.position.y + 0.8, 0)
	if _status_fx:
		_status_fx.emitting = want_fx
