class_name KingdomBackdrop
extends Node3D
## Animated 3D fantasy kingdom for the main menu: a central castle with towers,
## banners and glowing windows on a hill, a village, river, trees, floating
## islands and drifting clouds. The camera slowly sways around the castle.

var _cam: Camera3D
var _t := 0.0
var _clouds: Array[Node3D] = []
var _flags: Array[Node3D] = []
var _mats := {}

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := WorldEnv.make_environment(0.85)
	env.fog_enabled = true
	env.fog_light_color = Color("#a9d4ff")
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	WorldEnv.add_lights(self, SettingsManager.shadows_enabled(), -40.0, -35.0)
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_build()
	var animated: Array = []
	for n in _flags + _clouds:
		animated.append_array(n.find_children("*", "MeshInstance3D", true, false))
	MeshBatcher.bake_tree(self, animated)

func _m(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var key := "%s%.2f%.2f" % [c.to_html(), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _add(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	(parent if parent else self).add_child(mi)
	return mi

func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c

func _sph(r: float, h := -1.0, seg := 18) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2 if h < 0 else h
	s.radial_segments = seg
	s.rings = seg / 2
	return s

func _box(v: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = v
	return b

func _build() -> void:
	var grass := _m(Color("#6cc24a"))
	var ground := PlaneMesh.new()
	ground.size = Vector2(300, 300)
	_add(ground, grass, Vector3.ZERO)
	# rolling hills
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(30, 90)
		var r := rng.randf_range(10, 22)
		_add(_sph(r, r * 0.9, 24), _m(Color("#5fb543") if i % 2 else Color("#76c95a")), Vector3(cos(a) * d, -r * 0.25, sin(a) * d - 20))
	# castle hill
	_add(_sph(16, 9, 32), _m(Color("#6fc451")), Vector3(0, -2.0, -6))
	var stone := _m(Color("#cbbca3"))
	var stone_dark := _m(Color("#a18f77"))
	var roof := _m(Color("#3d6fe0"), 0.6)
	var roof2 := _m(Color("#e0483d"), 0.6)
	var gold := _m(Color("#ffcb2e"), 0.3)
	var castle := Node3D.new()
	castle.position = Vector3(0, 2.2, -6)
	add_child(castle)
	# curtain walls
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * 7.0, 1.2, sin(a) * 7.0)
		_add(_cyl(1.2, 1.35, 4.6, 20), stone, p + Vector3(0, 1.1, 0), Vector3.ZERO, Vector3.ONE, castle)
		_add(_cyl(0.0, 1.55, 2.2, 20), roof if i % 2 == 0 else roof2, p + Vector3(0, 4.5, 0), Vector3.ZERO, Vector3.ONE, castle)
		var b := TAU * (i + 0.5) / 8.0
		var wall := _add(_box(Vector3(5.2, 2.8, 1.0)), stone_dark, Vector3(cos(b) * 6.6, 1.0, sin(b) * 6.6), Vector3(0, -rad_to_deg(b) + 90, 0), Vector3.ONE, castle)
		for k in 4:
			_add(_box(Vector3(0.6, 0.6, 1.1)), stone, Vector3(-1.8 + k * 1.2, 1.6, 0), Vector3.ZERO, Vector3.ONE, wall)
	# keep
	_add(_box(Vector3(7, 7, 7)), stone, Vector3(0, 3.5, 0), Vector3.ZERO, Vector3.ONE, castle)
	_add(_cyl(0, 5.6, 4.0, 4), roof, Vector3(0, 9.0, 0), Vector3(0, 45, 0), Vector3.ONE, castle)
	for p: Vector3 in [Vector3(-3.5, 0, -3.5), Vector3(3.5, 0, -3.5), Vector3(-3.5, 0, 3.5), Vector3(3.5, 0, 3.5)]:
		_add(_cyl(1.3, 1.4, 10, 20), stone, p + Vector3(0, 5, 0), Vector3.ZERO, Vector3.ONE, castle)
		_add(_cyl(0, 1.7, 3.4, 20), roof2, p + Vector3(0, 11.7, 0), Vector3.ZERO, Vector3.ONE, castle)
		_add(_sph(0.25), gold, p + Vector3(0, 13.5, 0), Vector3.ZERO, Vector3.ONE, castle)
		var flag := Node3D.new()
		flag.position = p + Vector3(0, 13.6, 0)
		castle.add_child(flag)
		_add(_cyl(0.06, 0.06, 2.0, 6), _m(Color("#6b4226")), Vector3(0, 1.0, 0), Vector3.ZERO, Vector3.ONE, flag)
		_add(_box(Vector3(1.4, 0.8, 0.05)), roof if p.x < 0 else roof2, Vector3(0.7, 1.55, 0), Vector3.ZERO, Vector3.ONE, flag)
		_flags.append(flag)
	# central spire
	_add(_cyl(1.8, 2.0, 6, 24), stone, Vector3(0, 10, 0), Vector3.ZERO, Vector3.ONE, castle)
	_add(_cyl(0, 2.5, 5.0, 24), roof, Vector3(0, 15.5, 0), Vector3.ZERO, Vector3.ONE, castle)
	_add(_sph(0.45), gold, Vector3(0, 18.2, 0), Vector3.ZERO, Vector3.ONE, castle)
	# glowing windows + gate
	var window := _m(Color("#ffd36b"), 0.5, 1.6)
	for i in 12:
		var a := TAU * i / 12.0
		_add(_box(Vector3(0.5, 0.9, 0.2)), window, Vector3(cos(a) * 1.95, 10.5 + (i % 2) * 1.2, sin(a) * 1.95), Vector3(0, -rad_to_deg(a) + 90, 0), Vector3.ONE, castle)
	for x in [-2.0, 0.0, 2.0]:
		_add(_box(Vector3(0.7, 1.1, 0.2)), window, Vector3(x, 5.0, 3.55), Vector3.ZERO, Vector3.ONE, castle)
	_add(_cyl(1.3, 1.3, 0.3, 20), _m(Color("#6b4226")), Vector3(0, 1.3, 3.55), Vector3(90, 0, 0), Vector3(1, 1, 1.6), castle)
	# banners on keep
	for x in [-2.6, 2.6]:
		_add(_box(Vector3(1.0, 2.6, 0.1)), roof2 if x < 0 else roof, Vector3(x, 4.4, 3.58), Vector3.ZERO, Vector3.ONE, castle)
	# village houses
	for i in 14:
		var a := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var d := rng.randf_range(16, 30)
		var hp := Vector3(cos(a) * d, 0, sin(a) * d + 4 + 30)
		if absf(hp.x) < 6:
			continue
		_house(hp, rng)
	# trees
	for i in 60:
		var a := rng.randf() * TAU
		var d := rng.randf_range(13, 70)
		var tp := Vector3(cos(a) * d, 0, sin(a) * d - 6)
		if tp.z > 18 and absf(tp.x) < 10:
			continue
		_tree(tp, rng.randf_range(0.9, 1.8))
	# river + bridge in front
	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(200, 5)
	wp.subdivide_width = 60
	water.mesh = wp
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Assets/Materials/water.gdshader")
	sm.set_shader_parameter("bank_half_width", 2.5)
	water.material_override = sm
	water.position = Vector3(0, 0.05, 20)
	add_child(water)
	_add(_box(Vector3(4, 0.5, 7)), stone, Vector3(0, 0.3, 20))
	# floating islands with crystals
	for p: Vector3 in [Vector3(-34, 22, -40), Vector3(38, 26, -45), Vector3(-20, 30, -70)]:
		var isl := Node3D.new()
		isl.position = p
		add_child(isl)
		_add(_cyl(4, 0.5, 5, 10), _m(Color("#8f8478")), Vector3(0, -2.5, 0), Vector3.ZERO, Vector3.ONE, isl)
		_add(_cyl(4.2, 4.2, 0.6, 18), grass, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, isl)
		_add(_cyl(0, 0.7, 2.6, 6), _m(Color("#46e0ff"), 0.2, 1.2), Vector3(0, 1.6, 0), Vector3.ZERO, Vector3.ONE, isl)
		_tree(Vector3(2, 0.5, 1), 1.0, isl)
	# clouds
	for i in 12:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-90, 90), rng.randf_range(28, 45), rng.randf_range(-110, -30))
		add_child(c)
		var white := _m(Color(1, 1, 1), 1.0)
		for k in 4:
			_add(_sph(rng.randf_range(3, 5.5), -1, 12), white, Vector3(k * 3.5 - 5, rng.randf_range(-0.8, 0.8), rng.randf_range(-1, 1)), Vector3.ZERO, Vector3(1, 0.65, 1), c)
		_clouds.append(c)

func _house(p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := Node3D.new()
	h.position = p
	h.rotation.y = rng.randf() * TAU
	add_child(h)
	_add(_box(Vector3(3, 2.4, 2.6)), _m(Color("#f2e6cf")), Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, h)
	var pm := PrismMesh.new()
	pm.size = Vector3(3.4, 1.8, 2.9)
	_add(pm, _m([Color("#e0483d"), Color("#3d6fe0"), Color("#e09a3d")][rng.randi() % 3], 0.6), Vector3(0, 3.3, 0), Vector3.ZERO, Vector3.ONE, h)
	_add(_box(Vector3(0.7, 1.2, 0.1)), _m(Color("#6b4226")), Vector3(0, 0.6, 1.32), Vector3.ZERO, Vector3.ONE, h)
	_add(_box(Vector3(0.6, 0.6, 0.1)), _m(Color("#ffd36b"), 0.5, 1.2), Vector3(0.9, 1.5, 1.32), Vector3.ZERO, Vector3.ONE, h)

func _tree(p: Vector3, s: float, parent: Node3D = null) -> void:
	var t := Node3D.new()
	t.position = p
	t.scale = Vector3.ONE * s
	(parent if parent else self).add_child(t)
	_add(_cyl(0.3, 0.45, 2.2, 8), _m(Color("#8a5a33")), Vector3(0, 1.1, 0), Vector3.ZERO, Vector3.ONE, t)
	_add(_sph(1.6, 2.6, 14), _m(Color("#3f9e3a")), Vector3(0, 3.0, 0), Vector3.ZERO, Vector3.ONE, t)
	_add(_sph(1.1, 1.8, 12), _m(Color("#55b847")), Vector3(0.6, 3.9, 0.3), Vector3.ZERO, Vector3.ONE, t)

func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * 0.12) * 0.35
	_cam.position = Vector3(sin(a) * 42.0, 13.0 + sin(_t * 0.2) * 1.0, cos(a) * 42.0 + 4.0)
	_cam.look_at(Vector3(0, 9.0, -6))
	for c in _clouds:
		c.position.x += delta * 1.5
		if c.position.x > 100:
			c.position.x = -100
	for i in _flags.size():
		_flags[i].rotation.y = sin(_t * 2.0 + i) * 0.4
