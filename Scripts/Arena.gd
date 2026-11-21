class_name Arena
extends Node3D
## Builds the colourful fantasy arena: tiled grass field with dirt paths,
## river with animated water, two stone bridges, small waterfalls, trees,
## rocks, flowers and a border wall. Purely visual – gameplay geometry lives
## in ArenaLayout.

const GRASS_A := Color("#86d65a")
const GRASS_B := Color("#79ca4f")
const PATH := Color("#e3c98d")
const STONE := Color("#cfc2ad")
const STONE_DARK := Color("#9c8c78")

var deploy_overlay: MeshInstance3D
var _overlay_mat: StandardMaterial3D
var _pocket_overlays: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _mat_cache := {}

func _ready() -> void:
	_rng.seed = 1337
	_build_ground()
	_build_river()
	for bx in ArenaLayout.BRIDGE_X:
		_build_bridge(bx)
	for s: float in [-1.0, 1.0]:
		_build_waterfall(s)
	_build_border()
	_build_decorations()
	# static batching: thousands of decoration parts -> a few dozen draw calls
	MeshBatcher.bake_tree(self)
	_build_deploy_overlay()

# ------------------------------------------------------------------ materials
func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var key := c.to_html() + str(rough)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_mat_cache[key] = m
	return m

func _mesh(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere(r: float, h := -1.0, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0 else h
	s.radial_segments = seg
	s.rings = seg / 2
	return s

func _cyl(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c

# ------------------------------------------------------------------ ground
func _grass_texture(z_from: float, z_to: float) -> ImageTexture:
	# 1 tile = 16 px, checker + noise + sandy paths to the towers
	var tw := 16
	var w := int(ArenaLayout.HALF_W * 2) * tw
	var h := int(round((z_to - z_from) * tw))
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.035
	for y in h:
		for x in w:
			var wx := float(x) / tw - ArenaLayout.HALF_W
			var wz := z_from + float(y) / tw
			var tx := int(floor(wx + 100.0))
			var ty := int(floor(wz + 100.0))
			var c := GRASS_A if (tx + ty) % 2 == 0 else GRASS_B
			var n := noise.get_noise_2d(wx * tw, wz * tw)
			c = c.lightened(n * 0.08) if n > 0 else c.darkened(-n * 0.08)
			var p := _path_amount(wx, wz)
			if p > 0.0:
				c = c.lerp(PATH.lightened(n * 0.1), p)
			if x % tw == 0 or (int(round(wz * tw)) % tw) == 0:
				c = c.darkened(0.03)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _path_amount(wx: float, wz: float) -> float:
	var d := INF
	for bx: float in ArenaLayout.BRIDGE_X:
		# lane path from bridge to princess tower on both sides
		if absf(wz) < ArenaLayout.PRINCESS_Z:
			d = minf(d, absf(wx - bx) - 0.75)
		# ring around princess towers
		for s: float in [-1.0, 1.0]:
			d = minf(d, absf(Vector2(wx - bx, wz - s * ArenaLayout.PRINCESS_Z).length() - 2.0) - 0.45)
	# path linking princess towers to the king tower
	for s: float in [-1.0, 1.0]:
		var kz := s * ArenaLayout.KING_Z
		d = minf(d, absf(Vector2(wx, wz - kz).length() - 2.5) - 0.45)
		if absf(wx) < 5.5:
			d = minf(d, absf(wz - s * 12.0) - 0.45 + (0.0 if absf(wx) > 1.5 else 10.0))
	return clampf(1.0 - d / 0.25, 0.0, 1.0) * 0.85

func _build_ground() -> void:
	# two halves with a gap for the river; each half gets its own texture
	for sgn: float in [-1.0, 1.0]:
		var half_len := ArenaLayout.HALF_L - ArenaLayout.RIVER_HALF
		var z0 := ArenaLayout.RIVER_HALF if sgn > 0 else -ArenaLayout.HALF_L
		var gm := StandardMaterial3D.new()
		gm.albedo_texture = _grass_texture(z0, z0 + half_len)
		gm.roughness = 0.95
		gm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var pm := PlaneMesh.new()
		pm.size = Vector2(ArenaLayout.HALF_W * 2, half_len)
		_mesh(pm, gm, Vector3(0, 0, z0 + half_len * 0.5), Vector3.ZERO, Vector3.ONE, false)
	# outer meadow (leaves a gap for the river channel)
	var om := _mat(Color("#5fae3f"))
	var gap := ArenaLayout.RIVER_HALF + 0.12
	for sgn: float in [-1.0, 1.0]:
		var outer := PlaneMesh.new()
		outer.size = Vector2(90, 50)
		_mesh(outer, om, Vector3(0, -0.02, sgn * (gap + 25.0)), Vector3.ZERO, Vector3.ONE, false)
		var beyond := PlaneMesh.new()
		beyond.size = Vector2(30, gap * 2.0)
		_mesh(beyond, om, Vector3(sgn * (ArenaLayout.HALF_W + 3.6 + 15.0), -0.02, 0), Vector3.ZERO, Vector3.ONE, false)

func _build_river() -> void:
	var len := ArenaLayout.HALF_W * 2 + 6.0
	# river bed and earthy banks
	_mesh(_box(Vector3(len, 0.1, ArenaLayout.RIVER_HALF * 2 + 0.2)), _mat(Color("#2f6fa8")), Vector3(0, -0.75, 0), Vector3.ZERO, Vector3.ONE, false)
	for s: float in [-1.0, 1.0]:
		_mesh(_box(Vector3(len, 0.75, 0.25)), _mat(Color("#a47c52")), Vector3(0, -0.37, s * (ArenaLayout.RIVER_HALF + 0.05)), Vector3.ZERO, Vector3.ONE, false)
		# stone lip along the bank
		for i in int(len / 0.9):
			var x := -len * 0.5 + 0.45 + i * 0.9
			if ArenaLayout.in_bridge_corridor(x, -0.3):
				continue
			_mesh(_sphere(0.28 + _rng.randf() * 0.1, 0.32, 10), _mat(STONE if i % 2 else STONE_DARK), Vector3(x, 0.02, s * (ArenaLayout.RIVER_HALF + 0.05)), Vector3(0, _rng.randf() * 90, 0), Vector3(1.4, 1, 0.9))
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(len, ArenaLayout.RIVER_HALF * 2 + 0.2)
	pm.subdivide_width = 40
	pm.subdivide_depth = 4
	water.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Assets/Materials/water.gdshader")
	sm.set_shader_parameter("bank_half_width", ArenaLayout.RIVER_HALF)
	water.material_override = sm
	water.position = Vector3(0, -0.22, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# lily pads
	for i in 6:
		var x := _rng.randf_range(-8.5, 8.5)
		if ArenaLayout.in_bridge_corridor(x, -0.6):
			continue
		_mesh(_cyl(0.22, 0.22, 0.02, 12), _mat(Color("#3f9e3a"), 0.6), Vector3(x, -0.18, _rng.randf_range(-0.6, 0.6)), Vector3.ZERO, Vector3.ONE, false)
		if i % 2 == 0:
			_mesh(_sphere(0.07, 0.08, 8), _mat(Color("#ff9ad5"), 0.6), Vector3(x + 0.05, -0.14, _rng.randf_range(-0.6, 0.6)), Vector3.ZERO, Vector3.ONE, false)

func _build_bridge(bx: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(bx, 0, 0)
	add_child(root)
	var w := ArenaLayout.BRIDGE_HALF_W * 2
	var l := ArenaLayout.BRIDGE_HALF_LEN * 2 + 0.4
	_mesh(_box(Vector3(w, 0.22, l)), _mat(Color("#d8cab2")), Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE, true, root)
	# paving stones
	for zi in 6:
		for xi in 3:
			var c := Color("#e6dac4") if (zi + xi) % 2 == 0 else Color("#cdbea5")
			_mesh(_box(Vector3(w / 3.0 - 0.06, 0.04, l / 6.0 - 0.06)), _mat(c), Vector3(-w / 3.0 + xi * w / 3.0, 0.06, -l * 0.5 + l / 12.0 + zi * l / 6.0), Vector3.ZERO, Vector3.ONE, false, root)
	# arch underneath
	var arch := TorusMesh.new()
	arch.inner_radius = 0.75
	arch.outer_radius = 1.1
	arch.rings = 24
	_mesh(arch, _mat(STONE_DARK), Vector3(0, -0.45, 0), Vector3(0, 0, 90), Vector3(1.6, 1, 1.5), false, root)
	# railings with posts and lanterns
	for s: float in [-1.0, 1.0]:
		var x := s * (w * 0.5 - 0.1)
		_mesh(_box(Vector3(0.2, 0.18, l)), _mat(STONE), Vector3(x, 0.38, 0), Vector3.ZERO, Vector3.ONE, true, root)
		for i in 4:
			var z := -l * 0.5 + 0.2 + i * (l - 0.4) / 3.0
			_mesh(_box(Vector3(0.28, 0.5, 0.28)), _mat(STONE_DARK), Vector3(x, 0.2, z), Vector3.ZERO, Vector3.ONE, true, root)
			_mesh(_sphere(0.13, -1, 10), _mat(STONE), Vector3(x, 0.52, z), Vector3.ZERO, Vector3.ONE, true, root)
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			var lp := Vector3(s * (w * 0.5 + 0.05), 0.55, e * (l * 0.5 - 0.2))
			_mesh(_cyl(0.05, 0.05, 0.6), _mat(Color("#3a3a44")), lp + Vector3(0, 0.3, 0), Vector3.ZERO, Vector3.ONE, true, root)
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color(1.6, 1.25, 0.6)
			_mesh(_sphere(0.12, 0.2, 10), glow, lp + Vector3(0, 0.65, 0), Vector3.ZERO, Vector3.ONE, false, root)

func _build_waterfall(side: float) -> void:
	var x := side * (ArenaLayout.HALF_W + 2.3)
	var root := Node3D.new()
	root.position = Vector3(x, 0, 0)
	add_child(root)
	# rock cliff the water spills from
	var rock := _mat(Color("#8f8478"))
	var rock2 := _mat(Color("#a59a8c"))
	_mesh(_sphere(1.6, 2.6, 16), rock, Vector3(side * 1.3, 0.6, -1.4), Vector3(0, 30, 0), Vector3(1.0, 1, 0.8), true, root)
	_mesh(_sphere(1.5, 2.8, 16), rock2, Vector3(side * 1.4, 0.7, 1.5), Vector3(0, -20, 0), Vector3(1.0, 1, 0.8), true, root)
	_mesh(_sphere(1.4, 2.0, 14), rock, Vector3(side * 1.9, 1.4, 0), Vector3.ZERO, Vector3(1.0, 1, 1.2), true, root)
	_mesh(_sphere(0.9, 0.8, 12), _mat(Color("#5fae3f")), Vector3(side * 1.6, 2.35, 0.2), Vector3.ZERO, Vector3(1.4, 1, 1.6), true, root)
	# falling water sheet
	var fall := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.9, 2.4)
	fall.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Assets/Materials/water.gdshader")
	sm.set_shader_parameter("vertical_fall", true)
	sm.set_shader_parameter("alpha", 0.92)
	fall.material_override = sm
	fall.position = Vector3(side * 0.85, 0.95, 0)
	fall.rotation_degrees = Vector3(0, -90 * side, 0)
	fall.rotation_degrees.z = 0
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fall)
	# foam splash & mist
	var foam := CPUParticles3D.new()
	foam.amount = 30
	foam.lifetime = 0.9
	var fq := QuadMesh.new()
	fq.size = Vector2(0.45, 0.45)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = VFX.soft_dot_texture()
	fq.material = fm
	foam.mesh = fq
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	foam.emission_box_extents = Vector3(0.2, 0.05, 0.9)
	foam.direction = Vector3(-side, 1, 0)
	foam.spread = 35
	foam.initial_velocity_min = 0.8
	foam.initial_velocity_max = 1.8
	foam.gravity = Vector3(0, -2.5, 0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(0.85, 0.95, 1, 0.0))
	foam.color_ramp = g
	foam.position = Vector3(side * 0.6, -0.15, 0)
	root.add_child(foam)

func _build_border() -> void:
	var hw := ArenaLayout.HALF_W
	var hl := ArenaLayout.HALF_L
	var curb := _mat(Color("#d9ccb5"))
	var curb_dark := _mat(Color("#b5a68f"))
	# side walls (broken at the river)
	for s: float in [-1.0, 1.0]:
		for half: float in [-1.0, 1.0]:
			var seg_len := hl - ArenaLayout.RIVER_HALF - 0.2
			var zc := half * (ArenaLayout.RIVER_HALF + 0.2 + seg_len * 0.5)
			_mesh(_box(Vector3(0.45, 0.32, seg_len)), curb, Vector3(s * (hw + 0.22), 0.13, zc))
			for i in int(seg_len / 2.0) + 1:
				_mesh(_box(Vector3(0.6, 0.5, 0.5)), curb_dark, Vector3(s * (hw + 0.22), 0.2, half * (ArenaLayout.RIVER_HALF + 0.4) + half * i * 2.0))
	for s: float in [-1.0, 1.0]:
		_mesh(_box(Vector3(hw * 2 + 0.9, 0.32, 0.45)), curb, Vector3(0, 0.13, s * (hl + 0.22)))
		# castle wall behind each king tower
		_mesh(_box(Vector3(hw * 2 + 1.0, 1.3, 0.9)), _mat(Color("#c7b8a0")), Vector3(0, 0.65, s * (hl + 1.2)))
		for i in 10:
			_mesh(_box(Vector3(0.6, 0.45, 0.9)), _mat(Color("#d9ccb5")), Vector3(-hw + i * 2.0, 1.45, s * (hl + 1.2)))

func _build_decorations() -> void:
	var hw := ArenaLayout.HALF_W
	# trees along both sides, outside the playable field
	for s: float in [-1.0, 1.0]:
		var z := -15.0
		while z <= 15.0:
			if absf(z) > 3.5:
				_tree(Vector3(s * (hw + _rng.randf_range(1.6, 3.6)), 0, z + _rng.randf_range(-0.8, 0.8)), _rng.randf_range(0.85, 1.25))
			z += _rng.randf_range(3.0, 4.2)
		for i in 7:
			var p := Vector3(s * (hw + _rng.randf_range(0.8, 2.2)), 0, _rng.randf_range(-15.5, 15.5))
			if absf(p.z) < 3.4:
				continue
			_rock(p, _rng.randf_range(0.35, 0.7))
		for i in 14:
			var p := Vector3(s * (hw + _rng.randf_range(0.7, 4.5)), 0, _rng.randf_range(-16, 16))
			if absf(p.z) < 3.0:
				continue
			_flower_patch(p)
		for i in 5:
			var p := Vector3(s * (hw + _rng.randf_range(0.9, 3.5)), 0, _rng.randf_range(-15, 15))
			if absf(p.z) < 3.5:
				continue
			_bush(p)
	# outer forest so wide (landscape / PC) screens never look empty
	for i in 70:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(sx * _rng.randf_range(hw + 4.5, hw + 22.0), 0, _rng.randf_range(-20.0, 20.0))
		if absf(p.z) < 2.2 and absf(p.x) < hw + 6.0:
			continue
		match i % 5:
			0, 1, 2: _tree(p, _rng.randf_range(0.9, 1.5))
			3: _bush(p)
			4: _rock(p, _rng.randf_range(0.4, 0.9))
	for i in 30:
		var sx := -1.0 if i % 2 == 0 else 1.0
		_flower_patch(Vector3(sx * _rng.randf_range(hw + 4.0, hw + 20.0), 0, _rng.randf_range(-20.0, 20.0)))
	# tiny details inside the field, hugging the walls (no gameplay impact)
	for p in [Vector3(-8.3, 0, 6.5), Vector3(8.3, 0, -6.5), Vector3(-8.4, 0, -4.2), Vector3(8.4, 0, 4.0), Vector3(-8.4, 0, 15.2), Vector3(8.4, 0, -15.2)]:
		_flower_patch(p, 0.6)
	for p in [Vector3(-8.5, 0, 3.0), Vector3(8.5, 0, -3.0)]:
		_mushroom(p)

func _tree(p: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = p
	root.scale = Vector3.ONE * s
	root.rotation.y = _rng.randf() * TAU
	add_child(root)
	_mesh(_cyl(0.16, 0.24, 1.2, 8), _mat(Color("#8a5a33")), Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ONE, true, root)
	var leaf := [_mat(Color("#3f9e3a")), _mat(Color("#55b847")), _mat(Color("#2f8a3a"))]
	_mesh(_sphere(0.85, 1.4, 14), leaf[0], Vector3(0, 1.6, 0), Vector3.ZERO, Vector3.ONE, true, root)
	_mesh(_sphere(0.6, 1.0, 12), leaf[1], Vector3(0.35, 2.15, 0.1), Vector3.ZERO, Vector3.ONE, true, root)
	_mesh(_sphere(0.55, 0.9, 12), leaf[2], Vector3(-0.4, 1.95, -0.2), Vector3.ZERO, Vector3.ONE, true, root)
	if _rng.randf() < 0.5:
		for i in 3:
			_mesh(_sphere(0.08, -1, 8), _mat(Color("#ff5a5a"), 0.5), Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(1.3, 2.1), -0.7), Vector3.ZERO, Vector3.ONE, false, root)

func _rock(p: Vector3, s: float) -> void:
	_mesh(_sphere(s, s * 1.3, 10), _mat(Color("#9d9488") if _rng.randf() < 0.5 else Color("#b3a999")), p + Vector3(0, s * 0.3, 0), Vector3(_rng.randf() * 20, _rng.randf() * 180, 0), Vector3(1.3, 1, 1))
	_mesh(_sphere(s * 0.6, s * 0.6, 10), _mat(Color("#5fae3f")), p + Vector3(0, s * 0.82, 0), Vector3.ZERO, Vector3(1.2, 1, 1.1))

func _bush(p: Vector3) -> void:
	for i in 3:
		_mesh(_sphere(0.45, 0.7, 12), _mat(Color("#3f9e3a") if i % 2 else Color("#4caf45")), p + Vector3(i * 0.35 - 0.35, 0.3, _rng.randf_range(-0.2, 0.2)), Vector3.ZERO, Vector3.ONE, true)

func _flower_patch(p: Vector3, spread := 1.0) -> void:
	var colors := [Color("#ff6fae"), Color("#ffe14d"), Color("#ffffff"), Color("#9a7bff"), Color("#ff8a3d")]
	for i in 5:
		var fp := p + Vector3(_rng.randf_range(-0.5, 0.5) * spread, 0, _rng.randf_range(-0.5, 0.5) * spread)
		_mesh(_cyl(0.015, 0.015, 0.18, 3), _mat(Color("#3f9e3a")), fp + Vector3(0, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)
		_mesh(_sphere(0.075, 0.06, 6), _mat(colors[_rng.randi() % colors.size()], 0.6), fp + Vector3(0, 0.19, 0), Vector3.ZERO, Vector3.ONE, false)

func _mushroom(p: Vector3) -> void:
	_mesh(_cyl(0.07, 0.09, 0.22, 8), _mat(Color("#f4ead6")), p + Vector3(0, 0.11, 0))
	_mesh(_sphere(0.2, 0.2, 12), _mat(Color("#e8463c"), 0.6), p + Vector3(0, 0.25, 0))
	for i in 3:
		_mesh(_sphere(0.035, -1, 6), _mat(Color(1, 1, 1)), p + Vector3(cos(i * 2.1) * 0.12, 0.31, sin(i * 2.1) * 0.12))

# ------------------------------------------------------------------ deploy overlay
func _build_deploy_overlay() -> void:
	_overlay_mat = StandardMaterial3D.new()
	_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.38)
	deploy_overlay = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var len := ArenaLayout.HALF_L + ArenaLayout.DEPLOY_MIN_Z
	pm.size = Vector2(ArenaLayout.HALF_W * 2, len)
	deploy_overlay.mesh = pm
	deploy_overlay.material_override = _overlay_mat
	deploy_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deploy_overlay.position = Vector3(0, 0.05, -ArenaLayout.HALF_L + len * 0.5)
	deploy_overlay.visible = false
	add_child(deploy_overlay)

## Shows the red "can't deploy here" area for the player (team 0).
func show_deploy_overlay(v: bool, enemy_lane_open: Dictionary = {}) -> void:
	deploy_overlay.visible = v
	for lane in [-1, 1]:
		var open: bool = enemy_lane_open.get(lane, false)
		if v and open and not _pocket_overlays.has(lane):
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			var pocket_len := ArenaLayout.PRINCESS_Z - 4.0 - ArenaLayout.RIVER_HALF - 0.2
			pm.size = Vector2(ArenaLayout.HALF_W, pocket_len)
			mi.mesh = pm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.3, 1.0, 0.4, 0.25)
			mi.material_override = m
			mi.position = Vector3(lane * ArenaLayout.HALF_W * 0.5, 0.06, -(ArenaLayout.RIVER_HALF + 0.2 + pocket_len * 0.5))
			add_child(mi)
			_pocket_overlays[lane] = mi
		if _pocket_overlays.has(lane):
			(_pocket_overlays[lane] as Node3D).visible = v and open
