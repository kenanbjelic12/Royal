@tool
class_name TowerModel
extends MonsterModel
## Stylised stone tower matching the painted arena: princess towers carry a
## little archer, the king tower a cannon (drooping while it sleeps).
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
	# a small turret with a flag (cannon on the king, an archer on princess towers).
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
	# guard in the middle (rotates toward targets): cannon turret on the king,
	# a little archer on princess towers
	var guard := pivot("guard", body, Vector3(0, top_y + 0.4, 0))
	var tr := r * 0.42
	if big:
		add_mesh("", guard, cyl(tr, tr * 1.08, 0.5, 20), mat(Color("#a69e94"), 0.95), Vector3(0, 0.25, 0))
		add_mesh("", guard, cyl(tr * 1.12, tr * 1.12, 0.14, 20), mat(tc, 0.6), Vector3(0, 0.55, 0))
		add_mesh("", guard, cyl(tr * 0.8, tr * 0.8, 0.05, 20), mat(Color("#2c241f"), 0.9), Vector3(0, 0.62, 0))
		for i in 6:
			var ang := TAU * i / 6.0
			add_mesh("", guard, box(Vector3(0.14, 0.14, 0.12)), mat(tc_dark, 0.6), Vector3(sin(ang) * tr * 1.02, 0.68, cos(ang) * tr * 1.02), Vector3(0, rad_to_deg(ang), 0))
	# flag: on the king's turret, on the back rim of princess towers
	var pole := pivot("pole", guard if big else body, Vector3(tr * 0.45, 0.6, tr * 0.45) if big else Vector3(r * 0.55, top_y + 0.4, r * 0.75))
	add_mesh("", pole, cyl(0.035, 0.035, 1.1 if big else 0.9, 8), mat(Color("#5b4a3a"), 0.8), Vector3(0, 0.5, 0))
	add_mesh("", pole, sphere(0.07, -1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 1.08 if big else 0.92, 0))
	var flag := pivot("flag", pole, Vector3(0, 0.88 if big else 0.72, 0))
	for i in 3:
		var seg := pivot("flag%d" % i, flag if i == 0 else parts["flag%d" % (i - 1)], Vector3(0.0 if i == 0 else 0.2, 0, 0))
		add_mesh("", seg, box(Vector3(0.2, 0.3 - i * 0.06, 0.03)), mat(tc if i != 1 else tc_dark, 0.7), Vector3(0.1, 0, 0))
	if big:
		_build_cannon(guard, tr)
	else:
		_build_archer(guard, tc, tc_dark)

## Chibi archer: hooded team cape, big head and eyes, longbow in hand.
func _build_archer(guard: Node3D, tc: Color, tc_dark: Color) -> void:
	attack_anim_len = 0.55
	impact_at = 0.6
	const SKIN := Color("#ffd2a8")
	var a := pivot("archer", guard, Vector3.ZERO)
	a.scale = Vector3.ONE * 1.45
	add_mesh("", a, cyl(0.2, 0.24, 0.1, 14), mat(Color("#7b746c"), 0.95), Vector3(0, 0.05, 0))
	add_mesh("", a, cyl(0.17, 0.27, 0.42, 14), mat(tc, 0.7), Vector3(0, 0.3, 0))          # cape / tunic
	add_mesh("", a, torus(0.13, 0.2, 14), mat(Color("#6b4426"), 0.8), Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1, 0.6, 1))   # belt
	add_mesh("", a, sphere(0.035, -1, 8), mat(GOLD, 0.3, 0.1, 0.7), Vector3(0, 0.28, -0.2))
	# quiver on the back
	add_mesh("", a, cyl(0.06, 0.06, 0.32, 10), mat(Color("#7a4a26"), 0.8), Vector3(0.08, 0.45, 0.17), Vector3(-15, 0, -20))
	for k in 3:
		add_mesh("", a, box(Vector3(0.05, 0.06, 0.01)), mat(Color(1, 1, 1), 0.7), Vector3(0.1 + k * 0.025 - 0.03, 0.64, 0.21), Vector3(-15, 0, -20))
	var head := pivot("ghead", a, Vector3(0, 0.72, 0))
	add_mesh("", head, sphere(0.25), mat(SKIN, 0.75))
	add_mesh("", head, sphere(0.25, 0.34, 16), mat(Color("#8a4f22"), 0.8), Vector3(0, 0.1, 0.07))   # hair
	add_mesh("", head, sphere(0.28, 0.46, 16), mat(tc_dark, 0.7), Vector3(0, 0.08, 0.14))           # hood (open at the face)
	add_mesh("", head, cyl(0.0, 0.1, 0.22, 10), mat(tc_dark, 0.7), Vector3(0, 0.3, 0.16), Vector3(-50, 0, 0))
	add_mesh("", head, box(Vector3(0.03, 0.22, 0.02)), mat(GOLD, 0.4, 0.1, 0.6), Vector3(0.12, 0.3, 0.12), Vector3(-40, 0, -25))   # feather
	for sd: int in [-1, 1]:
		add_eye("geye_l" if sd < 0 else "geye_r", head, Vector3(0.09 * sd, -0.01, -0.22), 0.07, Color("#3d6b2f"))
		add_mesh("", head, sphere(0.04, -1, 8), mat(Color("#ff9e8a"), 0.9), Vector3(0.15 * sd, -0.09, -0.18), Vector3.ZERO, Vector3(1, 0.6, 0.4))
	add_mesh("", head, sphere(0.035, -1, 10), mat(Color("#7a2030"), 0.8), Vector3(0, -0.11, -0.22), Vector3.ZERO, Vector3(1.4, 0.6, 0.5))
	# arms + longbow held out in front
	for sd: int in [-1, 1]:
		add_mesh("", a, capsule(0.055, 0.26, 8), mat(tc, 0.7), Vector3(0.14 * sd, 0.42, -0.12), Vector3(70, 0, -20 * sd))
	var bow := pivot("bow", a, Vector3(-0.16, 0.36, -0.26), Vector3(0, 35, 0))
	for i in 7:
		var ang := deg_to_rad(-72 + i * 24)
		add_mesh("", bow, capsule(0.024, 0.15, 8), mat(Color("#8b5a2b"), 0.7), Vector3(sin(ang) * 0.32, cos(ang) * 0.32 - 0.32, 0) + Vector3(0, 0.32, 0), Vector3(0, 0, -rad_to_deg(ang) + 90))
	add_mesh("", bow, cyl(0.006, 0.006, 0.6, 4), mat(Color(1, 1, 1), 0.5), Vector3(0, 0.0, 0.07))
	add_mesh("", bow, cyl(0.012, 0.012, 0.5, 6), mat(Color("#d9c49a"), 0.7), Vector3(0, 0, -0.1), Vector3(90, 0, 0))   # arrow
	add_mesh("", bow, cyl(0.0, 0.03, 0.08, 6), mat(Color("#b9c0cc"), 0.35, 0, 0.7), Vector3(0, 0, -0.38), Vector3(-90, 0, 0))

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

## Initial facing of the guard (model local yaw, degrees).
func face_yaw(deg: float) -> void:
	var g: Node3D = parts.get("guard")
	if g == null:
		return
	_rest[g] = Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), (_rest[g] as Transform3D).origin)

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
	# archer: idle sway and blinking
	rot("archer", Vector3(0, 0, sin(t * 1.8) * 3))
	var blink := 1.0
	var bt := fmod(t + 0.5, 3.2)
	if bt < 0.12:
		blink = 1.0 - bump(bt / 0.12) * 0.9
	scl("geye_l", Vector3(1, blink, 1))
	scl("geye_r", Vector3(1, blink, 1))
	var p := attack_progress()
	if p >= 0.0:
		if parts.has("bow"):
			var draw := ease_out(clampf(p / impact_at, 0, 1)) if p < impact_at else 1.0 - ease_in_out((p - impact_at) / (1.0 - impact_at))
			off("bow", Vector3(0, 0, 0.1 * draw))
			rot("ghead", Vector3(-6 * draw, 0, 0))
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
	add_mesh("", _rubble, cyl(r * 1.18, r * 1.28, 0.35, 28), mat(Color("#5f5952"), 0.95), Vector3(0, 0.17, 0))
	add_mesh("", _rubble, cyl(r * 0.9, r * 1.05, 0.6, 12), mat(Color("#7b746c"), 0.95), Vector3(0, 0.6, 0), Vector3(4, 0, -6))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000)
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, r * 1.2)
		add_mesh("", _rubble, sphere(rng.randf_range(0.15, 0.35), -1, 10), mat(Color("#857e76") if i % 2 else Color("#5f5952"), 0.95), Vector3(sin(a) * d, rng.randf_range(0.6, 1.0), cos(a) * d), Vector3(rng.randf() * 90, 0, 0), Vector3(1, 0.7, 1.2))
	(parts["pole"] as Node3D).visible = true
	(parts["pole"] as Node3D).rotation_degrees = Vector3(0, 0, 50)
	(parts["pole"] as Node3D).position = Vector3(r * 0.4, 0.8, r * 0.4)
	_rest[parts["pole"]] = (parts["pole"] as Node3D).transform
