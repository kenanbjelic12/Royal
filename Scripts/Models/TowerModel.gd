@tool
class_name TowerModel
extends MonsterModel
## Stylised stone tower matching the painted arena: princess towers carry a
## ballista turret, the king tower a cannon (drooping while it sleeps).
## Team-coloured crown, crest banner, torches and a waving flag.

var kind := &"princess"
var destroyed := false
var sleeping := false
var _rubble: Node3D

const STONE := Color("#b3a796")
const STONE_DARK := Color("#8a7f72")
const WOOD := Color("#7a4a26")
const GOLD := Color("#f2b632")

func build() -> void:
	# Squat round cobblestone tower: team-coloured crenellated crown, a big
	# banner with a golden crown on the front, burning torches on the rim and
	# a small turret with a flag (cannon on the king, ballista on princesses).
	outline_width = 0.03
	# deeper royal red / blue like the painted towers
	var tc := Color("#d8342f") if team_color.r > team_color.b else Color("#2f72e0")
	var tc_dark := tc.darkened(0.35)
	var big := kind == &"king"
	var r := 1.45 if big else 1.08
	var h := 1.45 if big else 1.2
	var body := pivot("tower", null, Vector3.ZERO)
	# plinth
	add_mesh("", body, cyl(r * 1.16, r * 1.24, 0.3, 28), mat(STONE_DARK, 0.95), Vector3(0, 0.15, 0))
	if big:   # stepped base like a keep
		add_mesh("", body, cyl(r * 1.24, r * 1.3, 0.14, 28), mat(Color("#9c9184"), 0.95), Vector3(0, 0.07, 0))
	# wall + cobblestones in staggered rows
	var base_y := 0.3
	add_mesh("", body, cyl(r, r * 1.04, h, 28), mat(Color("#5f5952"), 0.95), Vector3(0, base_y + h * 0.5, 0))
	var rows := 4 if big else 3
	var per_row := 16 if big else 13
	var stone_cols := [Color("#9b948b"), Color("#857e76"), Color("#a8a094"), Color("#7b746c")]
	for row in rows:
		var y := base_y + (row + 0.5) * h / rows
		for i in per_row:
			var ang := TAU * (i + (0.5 if row % 2 else 0.0)) / per_row
			var w := TAU * r / per_row * 0.9
			var c: Color = stone_cols[(i * 3 + row) % stone_cols.size()]
			add_mesh("", body, box(Vector3(w, h / rows * 0.84, 0.14)), mat(c, 0.95),
				Vector3(sin(ang) * r * 1.0, y, cos(ang) * r * 1.0), Vector3(0, rad_to_deg(ang), 0))
	# dark doorway at the bottom front
	add_mesh("", body, box(Vector3(0.5 if big else 0.4, 0.45, 0.1)), mat(Color("#2c241f"), 0.9), Vector3(0, base_y + 0.22, -r * 1.06))
	add_mesh("", body, cyl(0.25 if big else 0.2, 0.25 if big else 0.2, 0.1, 14), mat(Color("#2c241f"), 0.9), Vector3(0, base_y + 0.45, -r * 1.06), Vector3(90, 0, 0))
	# team-coloured crown band with gold trims
	var top_y := base_y + h
	add_mesh("", body, cyl(r * 1.14, r * 1.05, 0.42, 28), mat(tc, 0.6), Vector3(0, top_y + 0.19, 0))
	add_mesh("", body, cyl(r * 1.16, r * 1.16, 0.06, 28), mat(GOLD, 0.3, 0.0, 0.7), Vector3(0, top_y + 0.02, 0))
	add_mesh("", body, torus(r * 1.08, r * 1.2, 28), mat(GOLD, 0.3, 0.0, 0.7), Vector3(0, top_y + 0.38, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	# stone floor of the rooftop
	add_mesh("", body, cyl(r * 1.06, r * 1.06, 0.06, 28), mat(Color("#6f6861"), 0.95), Vector3(0, top_y + 0.4, 0))
	# merlons: team colour with stone caps
	var merlons := 12 if big else 10
	for i in merlons:
		var ang := TAU * (i + 0.5) / merlons
		var mp := Vector3(sin(ang) * r * 1.08, top_y + 0.56, cos(ang) * r * 1.08)
		add_mesh("", body, box(Vector3(0.34, 0.3, 0.24)), mat(tc, 0.6), mp, Vector3(0, rad_to_deg(ang), 0))
		add_mesh("", body, box(Vector3(0.38, 0.07, 0.28)), mat(tc_dark, 0.6), mp + Vector3(0, 0.17, 0), Vector3(0, rad_to_deg(ang), 0))
	# front banner with a golden crown (front is -Z; the controller turns it to the camera)
	var bw := 1.0 if big else 0.8
	var bh := 1.0 if big else 0.78
	var bz := -(r * 1.17 + 0.04)
	var by := top_y + 0.36 - bh * 0.5
	add_mesh("", body, box(Vector3(bw + 0.08, bh + 0.06, 0.04)), mat(GOLD, 0.3, 0.0, 0.7), Vector3(0, by, bz + 0.01))
	add_mesh("", body, box(Vector3(bw, bh, 0.05)), mat(tc, 0.7), Vector3(0, by, bz - 0.01))
	add_mesh("", body, prism(Vector3(bw + 0.08, bw * 0.38, 0.04)), mat(GOLD, 0.3, 0.0, 0.7), Vector3(0, by - bh * 0.5 - bw * 0.17, bz + 0.01), Vector3(0, 0, 180))
	add_mesh("", body, prism(Vector3(bw, bw * 0.32, 0.05)), mat(tc, 0.7), Vector3(0, by - bh * 0.5 - bw * 0.14, bz - 0.01), Vector3(0, 0, 180))
	var cz := bz - 0.05
	var cs := bw * 0.62
	add_mesh("", body, box(Vector3(cs, cs * 0.22, 0.05)), mat(GOLD, 0.25, 0.25, 0.8), Vector3(0, by - cs * 0.22, cz))
	for k in 3:
		var kx := (k - 1) * cs * 0.4
		var kh := cs * (0.5 if k == 1 else 0.4)
		add_mesh("", body, prism(Vector3(cs * 0.3, kh, 0.05)), mat(GOLD, 0.25, 0.25, 0.8), Vector3(kx, by - cs * 0.11 + kh * 0.5, cz))
		add_mesh("", body, sphere(cs * 0.07, -1, 8), mat(GOLD, 0.25, 0.25, 0.8), Vector3(kx, by - cs * 0.11 + kh + cs * 0.04, cz))
	# torches on the rim
	var torch_angles := [150.0, 210.0, 30.0, 330.0] if not big else [140.0, 180.0, 220.0, 40.0, 320.0, 0.0]
	for ti in torch_angles.size():
		var ang := deg_to_rad(float(torch_angles[ti]))
		var tp := Vector3(sin(ang) * r * 1.02, top_y + 0.42, cos(ang) * r * 1.02)
		if big and ti == 1:
			continue   # keep the banner area clear
		add_mesh("", body, cyl(0.04, 0.04, 0.42, 6), mat(WOOD, 0.8), tp + Vector3(0, 0.2, 0))
		add_mesh("", body, cyl(0.12, 0.06, 0.12, 10), mat(GOLD, 0.3, 0.1, 0.7), tp + Vector3(0, 0.45, 0))
		var fl := pivot("flame%d" % ti, body, tp + Vector3(0, 0.52, 0))
		add_mesh("", fl, sphere(0.24, 0.5, 10), glow_mat(Color(1.0, 0.32, 0.04), 1.2, 0.6), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3.ONE, false)
		add_mesh("", fl, sphere(0.15, 0.4, 10), glow_mat(Color(1.0, 0.5, 0.08), 1.25), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, false)
		add_mesh("", fl, sphere(0.08, 0.22, 8), glow_mat(Color(1.0, 0.85, 0.4), 1.3), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.ONE, false)
	# turret (guard) in the middle: rotates toward targets
	var guard := pivot("guard", body, Vector3(0, top_y + 0.4, 0))
	var tr := r * 0.42
	add_mesh("", guard, cyl(tr, tr * 1.08, 0.5, 20), mat(Color("#a69e94"), 0.95), Vector3(0, 0.25, 0))
	add_mesh("", guard, cyl(tr * 1.12, tr * 1.12, 0.14, 20), mat(tc, 0.6), Vector3(0, 0.55, 0))
	add_mesh("", guard, cyl(tr * 0.8, tr * 0.8, 0.05, 20), mat(Color("#2c241f"), 0.9), Vector3(0, 0.62, 0))
	for i in 6:
		var ang := TAU * i / 6.0
		add_mesh("", guard, box(Vector3(0.14, 0.14, 0.12)), mat(tc_dark, 0.6), Vector3(sin(ang) * tr * 1.02, 0.68, cos(ang) * tr * 1.02), Vector3(0, rad_to_deg(ang), 0))
	# flag on the turret
	var pole := pivot("pole", guard, Vector3(tr * 0.45, 0.6, tr * 0.45))
	add_mesh("", pole, cyl(0.035, 0.035, 1.1 if big else 0.9, 8), mat(Color("#5b4a3a"), 0.8), Vector3(0, 0.5, 0))
	add_mesh("", pole, sphere(0.07, -1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 1.08 if big else 0.92, 0))
	var flag := pivot("flag", pole, Vector3(0, 0.88 if big else 0.72, 0))
	for i in 3:
		var seg := pivot("flag%d" % i, flag if i == 0 else parts["flag%d" % (i - 1)], Vector3(0.0 if i == 0 else 0.2, 0, 0))
		add_mesh("", seg, box(Vector3(0.2, 0.3 - i * 0.06, 0.03)), mat(tc if i != 1 else tc_dark, 0.7), Vector3(0.1, 0, 0))
	if big:
		_build_cannon(guard, tr)
	else:
		_build_ballista(guard, tr)

func _build_ballista(guard: Node3D, tr: float) -> void:
	attack_anim_len = 0.55
	impact_at = 0.6
	var bow := pivot("bow", guard, Vector3(0, 0.62, -tr * 0.95))
	add_mesh("", bow, box(Vector3(0.12, 0.1, 0.5)), mat(WOOD, 0.8), Vector3(0, 0, -0.1))
	for sd: int in [-1, 1]:
		add_mesh("", bow, capsule(0.03, 0.42, 8), mat(WOOD, 0.7), Vector3(0.2 * sd, 0, -0.28), Vector3(0, 0, 90 + 18 * sd))
	add_mesh("", bow, cyl(0.006, 0.006, 0.78, 4), mat(Color(1, 1, 1), 0.5), Vector3(0, 0, -0.2), Vector3(0, 0, 90))
	add_mesh("", bow, cyl(0.0, 0.03, 0.1, 6), mat(Color("#b9c0cc"), 0.35, 0, 0.7), Vector3(0, 0.0, -0.42), Vector3(-90, 0, 0))

func _build_cannon(guard: Node3D, tr: float) -> void:
	attack_anim_len = 0.7
	impact_at = 0.45
	var cannon := pivot("cannon", guard, Vector3(0, 0.62, -tr * 0.6))
	var barrel := pivot("barrel", cannon, Vector3(0, 0.05, 0), Vector3(-12, 0, 0))
	add_mesh("muzzle", barrel, cyl(0.14, 0.19, 0.7, 16), mat(Color("#3a3a44"), 0.35, 0, 0.7), Vector3(0, 0, -0.2), Vector3(90, 0, 0))
	add_mesh("", barrel, torus(0.12, 0.19, 16), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0, -0.54), Vector3(90, 0, 0))

func get_muzzle_position() -> Vector3:
	if parts.has("muzzle"):
		return (parts["muzzle"] as Node3D).global_position + (parts["barrel"] as Node3D).global_transform.basis.z * -0.4
	if parts.has("bow"):
		return (parts["bow"] as Node3D).global_position
	return global_position + Vector3(0, 3, 0)

## Turns the guard toward a world position.
func aim_at(world_pos: Vector3) -> void:
	var g: Node3D = parts.get("guard")
	if g == null:
		return
	var local := to_local(world_pos)
	var yaw := atan2(-local.x, -local.z)
	var rest: Transform3D = _rest[g]
	_rest[g] = Transform3D(Basis(Vector3.UP, lerp_angle(rest.basis.get_euler().y, yaw, 0.25)), rest.origin)

func pose(_dt: float) -> void:
	rot("flag", Vector3(0, sin(t * 3.0) * 15 + 20, 0))
	for i in 3:
		rot("flag%d" % i, Vector3(0, sin(t * 6.0 - i * 1.1) * 18, 0))
	if destroyed:
		return
	for i in 6:
		var f := 1.0 + sin(t * 13.0 + i * 1.7) * 0.12 + sin(t * 23.0 + i) * 0.08
		scl("flame%d" % i, Vector3(2.0 - f, f, 2.0 - f))
	if sleeping:
		rot("barrel", Vector3(14, 0, 0))   # the king's cannon droops while he naps
	var p := attack_progress()
	if p >= 0.0:
		if parts.has("bow"):
			var draw := ease_out(clampf(p / impact_at, 0, 1)) if p < impact_at else 1.0 - ease_in_out((p - impact_at) / (1.0 - impact_at))
			off("bow", Vector3(0, 0, 0.08 * draw))
		if parts.has("barrel"):
			var rec := bump(clampf((p - impact_at) / (1.0 - impact_at), 0, 1)) if p >= impact_at else 0.0
			off("cannon", Vector3(0, 0, 0.18 * rec))
			scl("muzzle", Vector3(1, 1 + 0.15 * rec, 1))

func show_destroyed() -> void:
	destroyed = true
	for c in _root.get_children():
		c.visible = false
	(parts["tower"] as Node3D).visible = true
	for c in (parts["tower"] as Node3D).get_children():
		c.visible = false
	_rubble = Node3D.new()
	_root.add_child(_rubble)
	var r := 1.35 if kind == &"king" else 1.0
	add_mesh("", _rubble, cyl(r * 1.18, r * 1.28, 0.35, 28), mat(STONE_DARK, 0.95), Vector3(0, 0.17, 0))
	add_mesh("", _rubble, cyl(r * 0.9, r * 1.05, 0.6, 12), mat(STONE, 0.95), Vector3(0, 0.6, 0), Vector3(4, 0, -6))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000)
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, r * 1.2)
		add_mesh("", _rubble, sphere(rng.randf_range(0.15, 0.35), -1, 10), mat(STONE if i % 2 else STONE_DARK, 0.95), Vector3(sin(a) * d, rng.randf_range(0.6, 1.0), cos(a) * d), Vector3(rng.randf() * 90, 0, 0), Vector3(1, 0.7, 1.2))
	(parts["pole"] as Node3D).visible = true
	(parts["pole"] as Node3D).rotation_degrees = Vector3(0, 0, 50)
	(parts["pole"] as Node3D).position = Vector3(r * 0.4, 0.8, r * 0.4)
	_rest[parts["pole"]] = (parts["pole"] as Node3D).transform
