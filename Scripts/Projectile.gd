class_name Projectile
extends Node3D
## Homing projectile used by towers and ranged monsters.
## `info` keys: type, from, target, speed, damage, team, source, splash,
## hits_air, hits_ground, slow, slow_time, poison, poison_time.

enum Kind { ARROW = 100, CANNONBALL = 101, ICE_SHARD = 1, POISON_ORB = 2, LIGHTNING = 3, BOMB = 4 }

var info: Dictionary
var battle: Node
var target: Combatant
var last_target_pos: Vector3
var speed := 10.0
var kind := 100
var _visual: Node3D
var _arc := 0.0
var _start: Vector3
var _travelled := 0.0
var _total := 1.0

func setup(p_info: Dictionary, p_battle: Node) -> void:
	info = p_info
	battle = p_battle
	target = info.get("target")
	speed = info.get("speed", 10.0)
	kind = info.get("type", Kind.ARROW)
	_start = info.get("from", Vector3.ZERO)
	last_target_pos = target.aim_point() if target else _start
	_total = maxf(_start.distance_to(last_target_pos), 0.1)
	_arc = 0.0
	match kind:
		Kind.CANNONBALL: _arc = 0.6
		Kind.POISON_ORB: _arc = 0.9
		Kind.BOMB: _arc = 1.8
		Kind.ARROW: _arc = 0.35

func _ready() -> void:
	global_position = _start
	_visual = _make_visual()
	add_child(_visual)

func _process(delta: float) -> void:
	if target != null and is_instance_valid(target) and target.is_alive():
		last_target_pos = target.aim_point()
	var flat_pos := global_position - Vector3(0, _arc_offset(), 0)
	var to := last_target_pos - flat_pos
	var step := speed * delta
	if to.length() <= step:
		_hit()
		return
	var dir := to.normalized()
	flat_pos += dir * step
	_travelled += step
	_total = maxf(_total, _travelled + to.length() - step)
	global_position = flat_pos + Vector3(0, _arc_offset(), 0)
	var look_dir := dir + Vector3(0, _arc_slope(), 0)
	if look_dir.length() > 0.01 and absf(look_dir.normalized().dot(Vector3.UP)) < 0.99:
		look_at(global_position + look_dir, Vector3.UP)
	if kind == Kind.ICE_SHARD or kind == Kind.POISON_ORB or kind == Kind.BOMB:
		_visual.rotate_object_local(Vector3.FORWARD, delta * 10.0)

func _arc_offset() -> float:
	var f := clampf(_travelled / _total, 0, 1)
	return sin(f * PI) * _arc * minf(_total * 0.25, 2.0)

func _arc_slope() -> float:
	var f := clampf(_travelled / _total, 0, 1)
	return cos(f * PI) * _arc * 0.6

func _hit() -> void:
	var dmg: float = info.get("damage", 0.0)
	var team: int = info.get("team", 0)
	var src: Combatant = info.get("source") if is_instance_valid(info.get("source")) else null
	var splash: float = info.get("splash", 0.0)
	var fx: Node3D = battle.effects_root()
	var p := last_target_pos
	var victims: Array = []
	if splash > 0.0:
		victims = battle.damage_area(Vector3(p.x, 0, p.z), splash, dmg, team, src, info.get("hits_air", true), info.get("hits_ground", true), target)
	elif target != null and is_instance_valid(target) and target.is_alive():
		target.take_damage(dmg, src)
		victims = [target]
	for v: Combatant in victims:
		if is_instance_valid(v) and v.is_alive():
			v.apply_slow(info.get("slow", 0.0), info.get("slow_time", 0.0))
			v.apply_poison(info.get("poison", 0.0), info.get("poison_time", 0.0), src)
	match kind:
		Kind.ICE_SHARD:
			VFX.ice_hit(fx, p, splash)
			AudioManager.play(&"ice_hit")
		Kind.POISON_ORB:
			VFX.poison_hit(fx, p)
			AudioManager.play(&"poison_hit")
		Kind.BOMB:
			VFX.bomb_explosion(fx, p, splash)
			AudioManager.play(&"bomb_explode")
			battle.shake_camera(0.1, 0.2)
		Kind.CANNONBALL:
			VFX.cannon_hit(fx, p)
			AudioManager.play(&"cannon_hit")
		_:
			VFX.arrow_hit(fx, p)
	queue_free()

func _make_visual() -> Node3D:
	var root := Node3D.new()
	match kind:
		Kind.ARROW:
			_add(root, _cyl(0.025, 0.7), _mat(Color("#8a5a2b")), Vector3(0, 0, 0), Vector3(90, 0, 0))
			_add(root, _cone(0.06, 0.16), _mat(Color("#d9dde6"), 0.4), Vector3(0, 0, -0.42), Vector3(-90, 0, 0))
			_add(root, BoxMesh.new(), _mat(Color("#f4f4f4")), Vector3(0, 0, 0.32), Vector3.ZERO, Vector3(0.12, 0.02, 0.14))
		Kind.CANNONBALL:
			var s := SphereMesh.new()
			s.radius = 0.2
			s.height = 0.4
			_add(root, s, _mat(Color("#2b2b33"), 0.0, 0.4))
			VFX.trail(root, Color(0.7, 0.7, 0.7, 0.6), 0.25, false)
		Kind.BOMB:
			var s := SphereMesh.new()
			s.radius = 0.2
			s.height = 0.4
			_add(root, s, _mat(Color("#1d1d24"), 0.3, 0.3))
			_add(root, _cyl(0.03, 0.12), _mat(Color("#8a6a3a")), Vector3(0, 0.22, 0))
			VFX.trail(root, Color(1.0, 0.7, 0.2), 0.14)
		Kind.ICE_SHARD:
			var c := _cone(0.13, 0.55)
			_add(root, c, _glow(Color(0.55, 0.95, 1.0), 1.8), Vector3.ZERO, Vector3(-90, 0, 0))
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.32
			_add(root, s, _glow(Color(0.8, 1.0, 1.0), 1.3), Vector3(0, 0, 0.1))
			VFX.trail(root, Color(0.6, 0.95, 1.0), 0.22)
		Kind.POISON_ORB:
			var s := SphereMesh.new()
			s.radius = 0.17
			s.height = 0.34
			_add(root, s, _glow(Color(0.5, 1.0, 0.25), 1.6))
			var s2 := SphereMesh.new()
			s2.radius = 0.26
			s2.height = 0.52
			var m := _glow(Color(0.4, 1.0, 0.2), 0.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.35
			_add(root, s2, m)
			VFX.trail(root, Color(0.5, 1.0, 0.25), 0.25)
	return root

func _add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	return c

func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c

func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * e, c.g * e, c.b * e)
	return m
