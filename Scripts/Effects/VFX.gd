@tool
class_name VFX
extends RefCounted
## Stateless factory for one-shot visual effects. All effects free themselves.
## CPUParticles3D is used on purpose – identical on PC, Android and the
## Compatibility renderer.

static var _dot: Texture2D
static var _star: Texture2D
static var _materials: Dictionary = {}

static func soft_dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.85))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_dot = tex
	return _dot

static func star_texture() -> Texture2D:
	if _star == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var dx := absf(x - 31.5) / 31.5
				var dy := absf(y - 31.5) / 31.5
				var v := clampf(1.0 - (dx * dy * 9.0 + (dx + dy) * 0.55), 0.0, 1.0)
				var c := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(v * 1.4 + c * c * 0.6, 0, 1)))
		_star = ImageTexture.create_from_image(img)
	return _star

static func _particle_material(additive: bool, star := false) -> StandardMaterial3D:
	var key := "%s%s" % [additive, star]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = star_texture() if star else soft_dot_texture()
	_materials[key] = m
	return m

static func _auto_free(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)

## Generic one-shot particle burst.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 20, speed := 3.0, size := 0.18,
		lifetime := 0.6, gravity := Vector3.ZERO, additive := true, star := false, direction := Vector3.UP, spread := 180.0, end_color := Color(0, 0, 0, 0)) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = lifetime
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = _particle_material(additive, star)
	p.mesh = qm
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.angle_min = 0
	p.angle_max = 360
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, color)
	var ec := end_color if end_color.a > 0.0 else Color(color.r, color.g, color.b, 0.0)
	ec.a = 0.0
	g.set_color(1, ec)
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, lifetime + 0.3)
	return p

## Flat expanding ring on the ground.
static func shockwave(parent: Node, pos: Vector3, color: Color, radius := 1.5, duration := 0.45, height := 0.06) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height, 0)
	mi.scale = Vector3(0.2, 0.05, 0.2) * radius
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.12 * radius, radius), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

## Curved weapon trail (crescent ribbon) facing `yaw` (radians), tilt in degrees.
static func slash_arc(parent: Node, pos: Vector3, yaw: float, color: Color, radius := 0.9, tilt_deg := 0.0, arc_deg := 150.0, duration := 0.28) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var seg := 18
	for i in seg + 1:
		var f := float(i) / seg
		var a := deg_to_rad(-arc_deg * 0.5 + arc_deg * f)
		var w := sin(f * PI) * 0.35 * radius
		var dir := Vector3(sin(a), 0, -cos(a))
		verts.append(dir * radius)
		verts.append(dir * (radius - w))
		var alpha := sin(f * PI) * (0.4 + 0.6 * f)
		cols.append(Color(color.r, color.g, color.b, alpha))
		cols.append(Color(color.r, color.g, color.b, 0.0))
	for i in seg:
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.6, 1.6, 1)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation = Vector3(deg_to_rad(tilt_deg), yaw, 0)
	mi.scale = Vector3.ONE * 0.6
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.1, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", yaw + deg_to_rad(40), duration)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

# ----------------------------------------------------------------- presets
static func fire_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.7, 0.15), 26, 3.5, 0.32, 0.55, Vector3(0, 2.5, 0), true, false, Vector3.UP, 120.0, Color(0.9, 0.1, 0.0))
	burst(parent, pos, Color(1, 0.95, 0.6), 10, 5.0, 0.12, 0.35, Vector3.ZERO, true, true)

static func dagger_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.75, 0.45, 1.0), 14, 4.0, 0.16, 0.35, Vector3.ZERO, true, true)
	burst(parent, pos, Color(0.25, 0.1, 0.4, 0.7), 8, 1.5, 0.4, 0.5, Vector3(0, 1, 0), false)

static func rock_hit(parent: Node, pos: Vector3) -> void:
	var ground := Vector3(pos.x, 0.05, pos.z)
	shockwave(parent, ground, Color(1.0, 0.85, 0.55, 0.9), 2.2, 0.5)
	burst(parent, ground, Color(0.55, 0.45, 0.35), 18, 5.0, 0.22, 0.8, Vector3(0, -14, 0), false, false, Vector3.UP, 60.0)
	burst(parent, ground, Color(0.85, 0.78, 0.65, 0.6), 14, 2.0, 0.7, 0.9, Vector3(0, 0.6, 0), false)

static func ice_hit(parent: Node, pos: Vector3, radius := 0.9) -> void:
	burst(parent, pos, Color(0.6, 0.95, 1.0), 22, 3.5, 0.2, 0.55, Vector3(0, -4, 0), true, true)
	burst(parent, pos, Color(0.85, 1.0, 1.0, 0.7), 10, 1.2, 0.6, 0.6, Vector3.ZERO, true)
	shockwave(parent, Vector3(pos.x, 0.05, pos.z), Color(0.5, 0.9, 1.0, 0.8), radius * 1.4, 0.35)

static func poison_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.45, 1.0, 0.25), 20, 2.5, 0.26, 0.7, Vector3(0, 1.2, 0), true)
	burst(parent, pos, Color(0.25, 0.6, 0.1, 0.6), 8, 0.8, 0.7, 0.9, Vector3(0, 0.5, 0), false)

static func arrow_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.95, 0.75), 8, 2.5, 0.12, 0.3, Vector3.ZERO, true, true)

static func cannon_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.75, 0.3), 16, 3.5, 0.25, 0.4, Vector3.ZERO, true)
	burst(parent, pos, Color(0.4, 0.38, 0.36, 0.7), 10, 1.5, 0.6, 0.8, Vector3(0, 1, 0), false)

static func spawn_effect(parent: Node, pos: Vector3, team_color: Color) -> void:
	var ground := Vector3(pos.x, 0.06, pos.z)
	shockwave(parent, ground, Color(team_color.r, team_color.g, team_color.b, 0.95), 1.6, 0.5)
	shockwave(parent, ground, Color(1, 1, 1, 0.7), 1.0, 0.35)
	burst(parent, ground + Vector3(0, 0.3, 0), Color(1, 1, 0.85), 18, 3.0, 0.16, 0.6, Vector3(0, -2, 0), true, true, Vector3.UP, 70.0)
	burst(parent, ground, Color(0.9, 0.85, 0.7, 0.55), 12, 1.8, 0.7, 0.7, Vector3.ZERO, false)

static func death_poof(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.95, 0.95, 1.0, 0.85), 18, 2.2, 0.75, 0.8, Vector3(0, 1.2, 0), false)
	burst(parent, pos, Color(1, 0.95, 0.5), 10, 3.5, 0.16, 0.6, Vector3(0, -3, 0), true, true)

static func tower_explosion(parent: Node, pos: Vector3) -> void:
	burst(parent, pos + Vector3(0, 1.5, 0), Color(1, 0.6, 0.15), 40, 6.0, 0.6, 0.8, Vector3(0, 2, 0), true)
	burst(parent, pos + Vector3(0, 1.0, 0), Color(0.45, 0.42, 0.4, 0.8), 30, 3.0, 1.4, 1.6, Vector3(0, 1.5, 0), false)
	burst(parent, pos + Vector3(0, 1.5, 0), Color(0.6, 0.55, 0.5), 30, 7.0, 0.3, 1.2, Vector3(0, -15, 0), false)
	shockwave(parent, pos, Color(1, 0.8, 0.4, 0.9), 4.0, 0.7)

## Looping bubbles attached to a unit (poison status).
static func status_bubbles(parent: Node3D, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.8
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.14)
	qm.material = _particle_material(true)
	p.mesh = qm
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p

## Continuous trail for projectiles (world-space particles left behind).
static func trail(parent: Node3D, color: Color, size := 0.2, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.35
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = _particle_material(additive)
	p.mesh = qm
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p
