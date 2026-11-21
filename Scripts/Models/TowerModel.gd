@tool
class_name TowerModel
extends MonsterModel
## Stylised stone tower. Princess towers have a little archer, the king tower
## has a chubby king (who naps until woken up) with a cannon. Team-coloured
## roof trims, banners and a waving flag.

var kind := &"princess"
var destroyed := false
var sleeping := false
var _rubble: Node3D

const STONE := Color("#b3a796")
const STONE_DARK := Color("#8a7f72")
const WOOD := Color("#7a4a26")
const GOLD := Color("#f2b632")
const SKIN := Color("#ffd2a8")

func build() -> void:
	outline_width = 0.03
	var tc := team_color
	var tc_dark := tc.darkened(0.35)
	var big := kind == &"king"
	var r := 1.35 if big else 1.0
	var h := 2.3 if big else 2.0
	var body := pivot("tower", null, Vector3.ZERO)
	add_mesh("", body, cyl(r * 1.18, r * 1.28, 0.35, 28), mat(STONE_DARK, 0.95), Vector3(0, 0.17, 0))
	add_mesh("", body, cyl(r, r * 1.08, h, 28), mat(STONE, 0.95), Vector3(0, 0.35 + h * 0.5, 0))
	for i in 3:
		add_mesh("", body, torus(r * 0.98, r * 1.1, 28), mat(STONE_DARK, 0.95), Vector3(0, 0.6 + i * h * 0.33, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	# stone block details
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var y := 0.8 + (i % 3) * h * 0.25
		add_mesh("", body, box(Vector3(0.36, 0.2, 0.1)), mat(STONE_DARK if i % 2 == 0 else Color("#d9cbb6"), 0.95), Vector3(sin(a) * r * 1.03, y, cos(a) * r * 1.03), Vector3(0, rad_to_deg(a), 0))
	# top battlement
	var top_y := 0.35 + h
	add_mesh("", body, cyl(r * 1.25, r * 1.1, 0.35, 28), mat(STONE, 0.95), Vector3(0, top_y + 0.1, 0))
	add_mesh("", body, cyl(r * 1.27, r * 1.27, 0.16, 28), mat(tc, 0.6), Vector3(0, top_y - 0.04, 0))
	for i in 10:
		var a := TAU * i / 10.0
		add_mesh("", body, box(Vector3(0.32, 0.3, 0.26)), mat(STONE, 0.95), Vector3(sin(a) * r * 1.12, top_y + 0.42, cos(a) * r * 1.12), Vector3(0, rad_to_deg(a), 0))
		add_mesh("", body, box(Vector3(0.34, 0.08, 0.28)), mat(tc, 0.6), Vector3(sin(a) * r * 1.12, top_y + 0.6, cos(a) * r * 1.12), Vector3(0, rad_to_deg(a), 0))
	# banners on the front (facing the camera side of each team)
	var front := -1.0  # -Z is "forward" for the model; towers are rotated per team
	for s: int in [-1, 1]:
		add_mesh("", body, box(Vector3(0.42, 0.9, 0.05)), mat(tc, 0.7), Vector3(0.42 * s, top_y - 0.6, front * (r * 1.02 + 0.03)))
		add_mesh("", body, prism(Vector3(0.42, 0.22, 0.05)), mat(tc, 0.7), Vector3(0.42 * s, top_y - 1.16, front * (r * 1.02 + 0.03)), Vector3(0, 0, 180))
		add_mesh("", body, sphere(0.09, -1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0.42 * s, top_y - 0.55, front * (r * 1.02 + 0.07)))
	# door
	add_mesh("", body, cyl(0.38, 0.38, 0.12, 16), mat(WOOD, 0.8), Vector3(0, 0.72, front * r * 1.06), Vector3(90, 0, 0), Vector3(1, 1, 1.4))
	# flag on a pole at the back
	var pole := pivot("pole", body, Vector3(r * 0.6, top_y + 0.3, r * 0.6))
	add_mesh("", pole, cyl(0.04, 0.04, 1.5, 8), mat(WOOD, 0.8), Vector3(0, 0.75, 0))
	add_mesh("", pole, sphere(0.08, -1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 1.52, 0))
	var flag := pivot("flag", pole, Vector3(0, 1.3, 0))
	for i in 3:
		var seg := pivot("flag%d" % i, flag if i == 0 else parts["flag%d" % (i - 1)], Vector3(0.0 if i == 0 else 0.22, 0, 0))
		add_mesh("", seg, box(Vector3(0.22, 0.4 - i * 0.05, 0.03)), mat(tc if i != 1 else tc_dark, 0.7), Vector3(0.11, 0, 0))
	# guard on top
	var guard := pivot("guard", body, Vector3(0, top_y + 0.25, 0))
	if big:
		_build_king(guard, tc)
	else:
		_build_archer(guard, tc)

func _build_archer(guard: Node3D, tc: Color) -> void:
	attack_anim_len = 0.55
	impact_at = 0.6
	add_mesh("", guard, sphere(0.24, 0.42, 16), mat(tc, 0.7), Vector3(0, 0.25, 0))
	var head := pivot("ghead", guard, Vector3(0, 0.62, 0))
	add_mesh("", head, sphere(0.25), mat(SKIN, 0.75))
	add_mesh("", head, sphere(0.27, 0.4, 16), mat(tc, 0.7), Vector3(0, 0.08, 0.05))
	add_mesh("", head, cyl(0.0, 0.1, 0.25, 10), mat(tc, 0.7), Vector3(0, 0.28, 0.12), Vector3(-40, 0, 0))
	add_mesh("", head, sphere(0.04, -1, 8), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0.36, 0.22))
	for s: int in [-1, 1]:
		add_eye("geye_l" if s < 0 else "geye_r", head, Vector3(0.09 * s, -0.01, -0.22), 0.065, Color("#4a2f1a"))
	add_mesh("", head, sphere(0.04, -1, 10), mat(Color("#7a2030"), 0.8), Vector3(0, -0.11, -0.22), Vector3.ZERO, Vector3(1.4, 0.6, 0.5))
	var bow := pivot("bow", guard, Vector3(0.0, 0.35, -0.32))
	for i in 5:
		var a := deg_to_rad(-60 + i * 30)
		add_mesh("", bow, capsule(0.025, 0.2, 8), mat(WOOD, 0.7), Vector3(sin(a) * 0.3, cos(a) * 0.3 - 0.3, 0) * Vector3(1, 1, 1) + Vector3(0, 0.0, 0), Vector3(0, 0, -rad_to_deg(a) + 90))
	add_mesh("", bow, cyl(0.007, 0.007, 0.52, 4), mat(Color(1, 1, 1), 0.5), Vector3(0, -0.03, 0.06))

func _build_king(guard: Node3D, tc: Color) -> void:
	attack_anim_len = 0.7
	impact_at = 0.45
	add_mesh("", guard, sphere(0.36, 0.55, 18), mat(tc, 0.7), Vector3(0, 0.3, 0.1))
	add_mesh("", guard, torus(0.28, 0.36, 20), mat(Color(1, 1, 1), 0.8), Vector3(0, 0.55, 0.1), Vector3.ZERO, Vector3(1, 1.2, 1))
	var head := pivot("ghead", guard, Vector3(0, 0.82, 0.1))
	add_mesh("", head, sphere(0.32), mat(SKIN, 0.75))
	add_mesh("", head, sphere(0.25, 0.3, 16), mat(Color(1, 1, 1), 0.9), Vector3(0, -0.17, -0.12))
	add_mesh("", head, sphere(0.07, -1, 10), mat(Color("#f59c8a"), 0.8), Vector3(0, -0.02, -0.31))
	for s: int in [-1, 1]:
		add_eye("geye_l" if s < 0 else "geye_r", head, Vector3(0.12 * s, 0.07, -0.27), 0.075, Color("#3a5fbf"))
		add_mesh("", head, box(Vector3(0.12, 0.03, 0.04)), mat(Color(1, 1, 1), 0.8), Vector3(0.12 * s, 0.17, -0.27), Vector3(0, 0, 12 * s))
	# crown
	add_mesh("", head, cyl(0.25, 0.23, 0.16, 20), mat(GOLD, 0.25, 0.2, 0.8), Vector3(0, 0.3, 0))
	for i in 6:
		var a := TAU * i / 6.0
		add_mesh("", head, cyl(0.0, 0.06, 0.16, 6), mat(GOLD, 0.25, 0.2, 0.8), Vector3(sin(a) * 0.22, 0.45, cos(a) * 0.22))
	add_mesh("", head, sphere(0.05, -1, 10), glow_mat(Color(1, 0.2, 0.3), 1.2), Vector3(0, 0.3, -0.25))
	# cannon in front
	var cannon := pivot("cannon", guard, Vector3(0, 0.15, -0.65))
	add_mesh("", cannon, box(Vector3(0.5, 0.2, 0.5)), mat(WOOD, 0.8), Vector3(0, -0.1, 0.05))
	var barrel := pivot("barrel", cannon, Vector3(0, 0.12, 0), Vector3(-12, 0, 0))
	add_mesh("muzzle", barrel, cyl(0.15, 0.2, 0.75, 16), mat(Color("#3a3a44"), 0.35, 0, 0.7), Vector3(0, 0, -0.2), Vector3(90, 0, 0))
	add_mesh("", barrel, torus(0.13, 0.2, 16), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0, -0.56), Vector3(90, 0, 0))

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
	off("guard", Vector3(0, sin(t * 2.0) * 0.02, 0))
	var g := 1.0
	if sleeping:
		g = 0.12
		off("ghead", Vector3(0, -0.04 + sin(t * 1.5) * 0.02, 0))
		rot("ghead", Vector3(12, 0, sin(t * 1.5) * 6))
	else:
		var b := fmod(t + 0.5, 3.0)
		if b < 0.1:
			g = 1.0 - bump(b / 0.1) * 0.9
	scl("geye_l", Vector3(1, g, 1))
	scl("geye_r", Vector3(1, g, 1))
	var p := attack_progress()
	if p >= 0.0:
		if parts.has("bow"):
			var draw := ease_out(clampf(p / impact_at, 0, 1)) if p < impact_at else 1.0 - ease_in_out((p - impact_at) / (1.0 - impact_at))
			off("bow", Vector3(0, 0, 0.08 * draw))
			rot("ghead", Vector3(-5 * draw, 0, 0))
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
