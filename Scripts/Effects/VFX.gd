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
	ground_cracks(parent, ground, 2.8)
	shockwave(parent, ground, Color(1.0, 0.85, 0.55, 0.9), 2.2, 0.5)
	burst(parent, ground, Color(0.55, 0.45, 0.35), 18, 5.0, 0.22, 0.8, Vector3(0, -14, 0), false, false, Vector3.UP, 60.0)
	burst(parent, ground, Color(0.85, 0.78, 0.65, 0.6), 14, 2.0, 0.7, 0.9, Vector3(0, 0.6, 0), false)

static func ice_hit(parent: Node, pos: Vector3, radius := 0.9) -> void:
	burst(parent, pos, Color(0.6, 0.95, 1.0), 22, 3.5, 0.2, 0.55, Vector3(0, -4, 0), true, true)
	burst(parent, pos, Color(0.85, 1.0, 1.0, 0.7), 10, 1.2, 0.6, 0.6, Vector3.ZERO, true)
	shockwave(parent, Vector3(pos.x, 0.05, pos.z), Color(0.5, 0.9, 1.0, 0.8), radius * 1.4, 0.35)

static func poison_hit(parent: Node, pos: Vector3) -> void:
	poison_puddle(parent, Vector3(pos.x, 0, pos.z), 0.8)
	burst(parent, pos, Color(0.45, 1.0, 0.25), 20, 2.5, 0.26, 0.7, Vector3(0, 1.2, 0), true)
	burst(parent, pos, Color(0.25, 0.6, 0.1, 0.6), 8, 0.8, 0.7, 0.9, Vector3(0, 0.5, 0), false)

static func arrow_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.95, 0.75), 8, 2.5, 0.12, 0.3, Vector3.ZERO, true, true)

static func cannon_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.75, 0.3), 16, 3.5, 0.25, 0.4, Vector3.ZERO, true)
	burst(parent, pos, Color(0.4, 0.38, 0.36, 0.7), 10, 1.5, 0.6, 0.8, Vector3(0, 1, 0), false)

static func spawn_effect(parent: Node, pos: Vector3, team_color: Color) -> void:
	var ground := Vector3(pos.x, 0.06, pos.z)
	summon_circle(parent, ground, team_color)
	shockwave(parent, ground, Color(team_color.r, team_color.g, team_color.b, 0.95), 1.6, 0.5)
	shockwave(parent, ground, Color(1, 1, 1, 0.7), 1.0, 0.35)
	burst(parent, ground + Vector3(0, 0.3, 0), Color(1, 1, 0.85), 18, 3.0, 0.16, 0.6, Vector3(0, -2, 0), true, true, Vector3.UP, 70.0)
	burst(parent, ground, Color(0.9, 0.85, 0.7, 0.55), 12, 1.8, 0.7, 0.7, Vector3.ZERO, false)

static func death_poof(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.95, 0.95, 1.0, 0.85), 18, 2.2, 0.75, 0.8, Vector3(0, 1.2, 0), false)
	burst(parent, pos, Color(1, 0.95, 0.5), 10, 3.5, 0.16, 0.6, Vector3(0, -3, 0), true, true)

static func tower_explosion(parent: Node, pos: Vector3) -> void:
	debris(parent, pos, Color("#b3a796"), 16, 7.0)
	ground_cracks(parent, pos, 5.0, 3.0)
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

# ======================================================================
# Premium effects (summon circle, light pillar, debris, damage numbers...)
# ======================================================================
static var _rune_tex: Texture2D
static var _crack_tex: Texture2D

## Procedural summoning circle: two rings, rune ticks and a star, white on
## transparent so it can be tinted per team.
static func rune_texture() -> Texture2D:
	if _rune_tex == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n, n) * 0.5
		for y in n:
			for x in n:
				var p := Vector2(x, y) - c
				var r := p.length() / (n * 0.5)
				var a := atan2(p.y, p.x)
				var v := 0.0
				v = maxf(v, 1.0 - absf(r - 0.94) / 0.025)
				v = maxf(v, 1.0 - absf(r - 0.80) / 0.018)
				if r > 0.82 and r < 0.92 and fmod(a + PI, TAU / 24.0) < 0.07:
					v = maxf(v, 0.9)
				# five-point star
				var star := 0.0
				for k in 5:
					var ang := k * TAU / 5.0
					var d := absf(p.normalized().rotated(-ang).y) * p.length() / (n * 0.5)
					if r < 0.78:
						star = maxf(star, 1.0 - d / 0.012)
				v = maxf(v, star * 0.8)
				v = maxf(v, clampf(1.0 - r / 0.35, 0, 1) * 0.25)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(v, 0, 1)))
		img.generate_mipmaps()
		_rune_tex = ImageTexture.create_from_image(img)
	return _rune_tex

static func crack_texture() -> Texture2D:
	if _crack_tex == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 9:
			var ang := k * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
			var p := Vector2(n, n) * 0.5
			for s in 60:
				ang += rng.randf_range(-0.35, 0.35)
				p += Vector2(cos(ang), sin(ang)) * 2.0
				var w := 3.0 * (1.0 - s / 60.0) + 0.6
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						if Vector2(ox, oy).length() <= w:
							var q := Vector2i(p) + Vector2i(ox, oy)
							if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
								img.set_pixel(q.x, q.y, Color(0.12, 0.08, 0.05, 0.85))
		img.generate_mipmaps()
		_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex

static func _ground_decal(parent: Node, pos: Vector3, tex: Texture2D, color: Color, size: float, additive: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = color
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.045, pos.z)
	return mi

## Team-coloured summoning circle that spins open, plus a light pillar.
static func summon_circle(parent: Node, pos: Vector3, color: Color, radius := 1.1) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := _ground_decal(parent, pos, rune_texture(), Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.95), radius * 2.6, true)
	mi.scale = Vector3.ONE * 0.3
	var m: StandardMaterial3D = mi.material_override
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", PI * 0.9, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5).set_delay(0.65)
	tw.chain().tween_callback(mi.queue_free)
	light_pillar(parent, pos, color, radius * 0.55)

static func light_pillar(parent: Node, pos: Vector3, color: Color, radius := 0.6, height := 5.0) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	mi.mesh = cm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = gt
	m.albedo_color = Color(color.r * 1.5 + 0.3, color.g * 1.5 + 0.3, color.b * 1.5 + 0.3, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, height * 0.5, pos.z)
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.3, 1.0, 1.3), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.55).set_delay(0.1)
	tw.chain().tween_callback(mi.queue_free)

## Ground cracks that fade (golem slam, tower collapse).
static func ground_cracks(parent: Node, pos: Vector3, size := 2.6, life := 1.6) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := _ground_decal(parent, pos, crack_texture(), Color(1, 1, 1, 0.9), size, false)
	mi.rotation.y = randf() * TAU
	var m: StandardMaterial3D = mi.material_override
	var tw := mi.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.4)
	tw.tween_callback(mi.queue_free)

## Lingering poison puddle with bubbles.
static func poison_puddle(parent: Node, pos: Vector3, radius := 0.9, life := 2.2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := _ground_decal(parent, pos, soft_dot_texture(), Color(0.4, 1.0, 0.2, 0.55), radius * 2.4, true)
	mi.scale = Vector3.ONE * 0.4
	var m: StandardMaterial3D = mi.material_override
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.4)
	tw.tween_callback(mi.queue_free)
	var p := burst(parent, Vector3(pos.x, 0.1, pos.z), Color(0.55, 1.0, 0.3), 14, 0.8, 0.22, 1.2, Vector3(0, 0.8, 0), true, false, Vector3.UP, 30.0)
	if p:
		p.emission_sphere_radius = radius * 0.7
		p.explosiveness = 0.2

## Stone chunks thrown out with gravity (tower collapse).
static func debris(parent: Node, pos: Vector3, color: Color, count := 14, power := 6.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	for i in count:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.18, 0.45)
		bm.size = Vector3(s, s * randf_range(0.6, 1.0), s * randf_range(0.7, 1.1))
		mi.mesh = bm
		mi.material_override = m
		parent.add_child(mi)
		var start := pos + Vector3(randf_range(-0.6, 0.6), randf_range(1.0, 2.6), randf_range(-0.6, 0.6))
		mi.global_position = start
		var vel := Vector3(randf_range(-1, 1), randf_range(0.6, 1.3), randf_range(-1, 1)).normalized() * power * randf_range(0.6, 1.0)
		var t_land := (vel.y + sqrt(vel.y * vel.y + 2.0 * 18.0 * start.y)) / 18.0
		var end := start + Vector3(vel.x, 0, vel.z) * t_land
		end.y = s * 0.3
		var tw := mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				mi.global_position = start + vel * t + Vector3(0, -9.0 * t * t, 0)
				mi.rotation += Vector3(0.15, 0.2, 0.1), 0.0, t_land, t_land)
		tw.tween_callback(func(): if is_instance_valid(mi): mi.global_position = end)
		tw.tween_interval(1.2)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(mi.queue_free)

## Floating damage number (billboarded, pops and rises).
static func damage_number(parent: Node, pos: Vector3, amount: float, color := Color(1, 1, 1), big := false) -> void:
	if parent == null or not parent.is_inside_tree() or amount < 1.0:
		return
	var l := Label3D.new()
	l.text = str(int(round(amount)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.017 if big else 0.014
	l.font_size = 48
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.06, 0.05, 0.12)
	var f := load("res://Assets/UI/Fonts/LilitaOne.woff2")
	if f:
		l.font = f
	l.render_priority = 10
	l.outline_render_priority = 9
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.4, 0)
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.1, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

## Ice crystals clinging to a slowed unit.
static func frost_shell(parent: Node3D, height: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.95, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.4, 0.8, 1.0)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.1
	for i in 6:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.09
		cm.height = randf_range(0.3, 0.5)
		cm.radial_segments = 5
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := i * TAU / 6.0
		mi.position = Vector3(cos(a) * 0.35, randf_range(0.1, height), sin(a) * 0.35)
		mi.rotation = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.8, 0.8))
		root.add_child(mi)
	return root

# ----------------------------------------------------------------- new card effects
## Jagged lightning bolt between two points (fades fast).
static func lightning_bolt(parent: Node, a: Vector3, b: Vector3, color := Color(0.6, 0.85, 1.0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var pts: Array[Vector3] = [a]
	var seg := 9
	var side := (b - a).cross(Vector3.UP).normalized()
	for i in range(1, seg):
		var f := float(i) / seg
		pts.append(a.lerp(b, f) + side * randf_range(-0.35, 0.35) + Vector3(0, randf_range(-0.3, 0.3), 0))
	pts.append(b)
	var im := ImmediateMesh.new()
	for width: float in [0.16, 0.06]:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var w := Vector3.UP * width
			im.surface_add_vertex(p0 - w); im.surface_add_vertex(p0 + w); im.surface_add_vertex(p1 + w)
			im.surface_add_vertex(p0 - w); im.surface_add_vertex(p1 + w); im.surface_add_vertex(p1 - w)
			var s := side * width
			im.surface_add_vertex(p0 - s); im.surface_add_vertex(p0 + s); im.surface_add_vertex(p1 + s)
			im.surface_add_vertex(p0 - s); im.surface_add_vertex(p1 + s); im.surface_add_vertex(p1 - s)
		im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var outer := StandardMaterial3D.new()
	outer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	outer.cull_mode = BaseMaterial3D.CULL_DISABLED
	outer.albedo_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.8, 0.8)
	var core := outer.duplicate() as StandardMaterial3D
	core.albedo_color = Color(2, 2, 2, 1)
	mi.set_surface_override_material(0, outer)
	mi.set_surface_override_material(1, core)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(outer, "albedo_color:a", 0.0, 0.25)
	tw.tween_property(core, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(mi.queue_free)

static func lightning_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.7, 0.9, 1.0), 16, 4.5, 0.16, 0.3, Vector3.ZERO, true, true)
	burst(parent, pos, Color(0.5, 0.75, 1.0, 0.8), 4, 0.5, 1.2, 0.25, Vector3.ZERO, true)

## Healing wave: green ring + rising plus-sparkles.
static func heal_pulse(parent: Node, pos: Vector3, radius: float, height := 0.0) -> void:
	shockwave(parent, Vector3(pos.x, 0.05, pos.z), Color(0.4, 1.0, 0.5, 0.9), radius, 0.5)
	var p := burst(parent, Vector3(pos.x, maxf(height, 0.3), pos.z), Color(0.6, 1.0, 0.6), 14, 1.5, 0.2, 0.8, Vector3(0, 1.0, 0), true, true, Vector3.DOWN, 70.0)
	if p:
		p.emission_sphere_radius = 0.4

static func heal_sparkle(parent: Node, pos: Vector3) -> void:
	burst(parent, pos + Vector3(0, 0.3, 0), Color(0.5, 1.0, 0.5), 8, 1.2, 0.18, 0.7, Vector3(0, 1.5, 0), true, true, Vector3.UP, 40.0)

## Dust and speed streaks behind a charging unit (toggle `emitting`).
static func charge_trail(parent: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = 0.5
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.5)
	qm.material = _particle_material(false)
	p.mesh = qm
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.8, 0.6, 0.7))
	g.set_color(1, Color(0.9, 0.8, 0.6, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.2, 0)
	p.emitting = false
	parent.add_child(p)
	return p

static func bomb_explosion(parent: Node, pos: Vector3, radius := 1.4) -> void:
	var ground := Vector3(pos.x, 0.05, pos.z)
	burst(parent, ground + Vector3(0, 0.4, 0), Color(1.0, 0.75, 0.25), 30, 5.0, 0.45, 0.5, Vector3(0, 2, 0), true)
	burst(parent, ground + Vector3(0, 0.4, 0), Color(0.35, 0.32, 0.3, 0.8), 16, 2.0, 1.0, 1.1, Vector3(0, 1.2, 0), false)
	shockwave(parent, ground, Color(1, 0.7, 0.3, 0.9), radius * 1.5, 0.4)
	ground_cracks(parent, ground, radius * 1.8, 1.4)
