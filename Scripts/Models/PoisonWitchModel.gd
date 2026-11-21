@tool
extends MonsterModel
## POISON WITCH – a mischievous little witch with a giant bent hat, mint-green
## hair, a cheeky grin and a crooked staff topped with a bubbling poison orb.

const ROBE := Color("#6a2fb0")
const ROBE_DARK := Color("#43207a")
const TRIM := Color("#7cff4f")
const SKIN := Color("#ffd8c2")
const HAIR := Color("#3fdc9a")
const WOOD := Color("#6b4226")
const POISON := Color("#7dff3a")

func build() -> void:
	attack_anim_len = 0.9
	impact_at = 0.55
	select_len = 1.6
	var body := pivot("body", null, Vector3.ZERO)
	# robe (bell shape) with glowing trim, little boots peeking out
	for s: int in [-1, 1]:
		var leg := pivot("leg_l" if s < 0 else "leg_r", body, Vector3(0.1 * s, 0.12, 0))
		add_mesh("", leg, sphere(0.08, 0.12, 12), mat(Color("#2b1b3d"), 0.6), Vector3(0, -0.06, -0.06), Vector3.ZERO, Vector3(1, 1, 1.5))
	var torso := pivot("torso", body, Vector3(0, 0.05, 0))
	add_mesh("robe", torso, cyl(0.17, 0.36, 0.55, 22), mat(ROBE, 0.7), Vector3(0, 0.3, 0))
	add_mesh("", torso, torus(0.32, 0.38, 26), mat(TRIM, 0.5, 0.6), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	add_mesh("", torso, sphere(0.2, 0.3, 16), mat(ROBE_DARK, 0.7), Vector3(0, 0.6, 0))
	add_mesh("", torso, torus(0.13, 0.2, 20), mat(ROBE_DARK, 0.7), Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	add_mesh("", torso, torus(0.16, 0.21, 20), mat(Color("#2b1b3d"), 0.6), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1.15, 1.2, 1.15))
	# potion on the belt
	add_mesh("", torso, sphere(0.07, -1, 12), mat(POISON, 0.1, 0.9), Vector3(0.2, 0.3, -0.13))
	add_mesh("", torso, cyl(0.025, 0.03, 0.06, 8), mat(WOOD, 0.8), Vector3(0.2, 0.38, -0.13))
	# arms with wide sleeves
	for s: int in [-1, 1]:
		var n := "arm_l" if s < 0 else "arm_r"
		var arm := pivot(n, torso, Vector3(0.18 * s, 0.6, 0), Vector3(25, 0, 25 * s))
		add_mesh("", arm, cyl(0.06, 0.11, 0.26, 12), mat(ROBE, 0.7), Vector3(0, -0.12, 0))
		add_mesh("", arm, torus(0.08, 0.115, 14), mat(TRIM, 0.5, 0.6), Vector3(0, -0.25, 0))
		add_mesh("", arm, sphere(0.055, -1, 10), mat(SKIN, 0.7), Vector3(0, -0.29, 0))
	# crooked staff with poison orb
	var staff := pivot("staff", parts["arm_r"], Vector3(0, -0.29, 0), Vector3(-30, 0, -25))
	add_mesh("", staff, cyl(0.03, 0.035, 0.95, 8), mat(WOOD, 0.8), Vector3(0, 0.2, 0))
	add_mesh("", staff, torus(0.06, 0.09, 12), mat(WOOD, 0.8), Vector3(0, 0.7, -0.05), Vector3(90, 0, 0))
	add_mesh("", staff, torus(0.035, 0.05, 10), mat(Color("#ffd35a"), 0.3, 0, 0.7), Vector3(0, 0.6, 0))
	var orb := pivot("orb", staff, Vector3(0, 0.82, 0))
	add_mesh("orb_core", orb, sphere(0.1, -1, 16), glow_mat(POISON, 1.4), Vector3.ZERO)
	add_mesh("", orb, sphere(0.14, -1, 16), glow_mat(Color(0.5, 1.0, 0.3), 0.7, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	add_particles("orb_fx", orb, POISON, 14, 0.8, 0.1, Vector3(0, 0.7, 0), 50.0, 0.1)
	# head
	var head := pivot("head", torso, Vector3(0, 0.95, 0))
	add_mesh("", head, sphere(0.3), mat(SKIN, 0.75), Vector3.ZERO)
	# hair clumps
	var hair := mat(HAIR, 0.6)
	add_mesh("", head, sphere(0.32, 0.5, 18), hair, Vector3(0, 0.08, 0.06))
	for s: int in [-1, 1]:
		add_mesh("", head, sphere(0.13, 0.28, 12), hair, Vector3(0.26 * s, -0.12, 0.02), Vector3(0, 0, 15 * s))
		add_mesh("", head, sphere(0.09, -1, 10), hair, Vector3(0.32 * s, -0.26, 0.05))
	add_mesh("", head, sphere(0.1, 0.12, 12), hair, Vector3(-0.1, 0.17, -0.24), Vector3(0, 0, 25))
	add_mesh("", head, sphere(0.09, 0.1, 12), hair, Vector3(0.08, 0.19, -0.25), Vector3(0, 0, -20))
	add_eye("eye_l", head, Vector3(-0.11, 0.0, -0.26), 0.085, Color("#2fbf4a"))
	add_eye("eye_r", head, Vector3(0.11, 0.0, -0.26), 0.085, Color("#2fbf4a"))
	add_mesh("brow_l", head, box(Vector3(0.1, 0.028, 0.03)), mat(Color("#1f8a5a"), 0.7), Vector3(-0.12, 0.11, -0.27), Vector3(0, 0, -12))
	add_mesh("brow_r", head, box(Vector3(0.1, 0.028, 0.03)), mat(Color("#1f8a5a"), 0.7), Vector3(0.12, 0.13, -0.27), Vector3(0, 0, 22))
	# cheeky grin
	add_mesh("mouth", head, sphere(0.06, -1, 12), mat(Color("#7a2030"), 0.8), Vector3(0.03, -0.13, -0.26), Vector3(0, 0, -12), Vector3(1.5, 0.55, 0.5))
	add_mesh("", head, box(Vector3(0.025, 0.025, 0.02)), mat(Color(1, 1, 1), 0.4), Vector3(0.0, -0.115, -0.285))
	add_mesh("", head, sphere(0.045, 0.03, 10), glow_mat(Color(1, 0.55, 0.6), 1.0, 0.45), Vector3(-0.19, -0.08, -0.22))
	add_mesh("", head, sphere(0.045, 0.03, 10), glow_mat(Color(1, 0.55, 0.6), 1.0, 0.45), Vector3(0.19, -0.08, -0.22))
	# giant bent hat
	var hat := pivot("hat", head, Vector3(0, 0.2, 0.03), Vector3(-6, 0, 6))
	add_mesh("", hat, cyl(0.52, 0.55, 0.05, 28), mat(ROBE_DARK, 0.7), Vector3.ZERO)
	add_mesh("", hat, cyl(0.25, 0.3, 0.26, 24), mat(ROBE, 0.7), Vector3(0, 0.15, 0))
	add_mesh("", hat, cyl(0.29, 0.31, 0.08, 24), mat(TRIM, 0.5, 0.6), Vector3(0, 0.07, 0))
	add_mesh("", hat, box(Vector3(0.1, 0.1, 0.03)), mat(Color("#ffd35a"), 0.3, 0, 0.7), Vector3(0, 0.08, -0.31), Vector3(0, 0, 45))
	var h2 := pivot("hat2", hat, Vector3(0, 0.28, 0), Vector3(-18, 0, 0))
	add_mesh("", h2, cyl(0.15, 0.25, 0.28, 20), mat(ROBE, 0.7), Vector3(0, 0.13, 0))
	var h3 := pivot("hat3", h2, Vector3(0, 0.26, 0), Vector3(-35, 0, 0))
	add_mesh("", h3, cyl(0.0, 0.15, 0.3, 18), mat(ROBE, 0.7), Vector3(0, 0.14, 0))
	add_mesh("", h3, sphere(0.04, -1, 8), mat(TRIM, 0.5, 0.6), Vector3(0, 0.29, 0))

func get_muzzle_position() -> Vector3:
	return (parts["orb"] as Node3D).global_position

func pose(_dt: float) -> void:
	var walk := move_blend
	var cyc := t * 8.0
	off("body", Vector3(0, absf(sin(cyc)) * 0.07 * walk + sin(t * 2.0) * 0.015, 0))
	rot("torso", Vector3(-5 * walk, 0, sin(cyc) * 5 * walk + sin(t * 1.5) * 2))
	rot("leg_l", Vector3(sin(cyc) * 30 * walk, 0, 0))
	rot("leg_r", Vector3(-sin(cyc) * 30 * walk, 0, 0))
	rot("arm_l", Vector3(-sin(cyc) * 20 * walk, 0, sin(t * 2.0) * 4))
	rot("arm_r", Vector3(sin(cyc) * 8 * walk, 0, 0))
	rot("head", Vector3(sin(t * 2.0) * 3, sin(t * 0.9) * 10 * (1.0 - walk), sin(t * 1.3) * 4))
	rot("hat", Vector3(sin(t * 2.4) * 3 + 6 * walk, 0, sin(t * 1.9) * 3))
	rot("hat2", Vector3(sin(t * 2.4 - 0.5) * 6 + 6 * walk, 0, sin(t * 1.9 - 0.4) * 5))
	rot("hat3", Vector3(sin(t * 2.4 - 1.0) * 10 + 8 * walk, 0, sin(t * 1.9 - 0.8) * 8))
	off("orb", Vector3(0, sin(t * 3.0) * 0.02, 0))
	scl("orb_core", Vector3.ONE * (1.0 + sin(t * 5.0) * 0.08))
	var b := fmod(t + 0.4, 3.1)
	if b < 0.1:
		var k := 1.0 - bump(b / 0.1) * 0.9
		scl("eye_l", Vector3(1, k, 1))
		scl("eye_r", Vector3(1, k, 1))
	# attack: raise staff, then thrust it forward to fling the orb
	var p := attack_progress()
	if p >= 0.0:
		var s := swing_curve(p, impact_at)
		var up := clampf(-s, 0, 1)
		var down := clampf(s, 0, 1)
		rot("arm_r", Vector3(up * 110 + down * 60, 0, -up * 10))
		rot("staff", Vector3(-up * 20 + down * 30, 0, 0))
		rot("arm_l", Vector3(up * 40, 0, -up * 40))
		rot("torso", Vector3(-up * 8 + down * 12, 0, 0))
		off("body", Vector3(0, up * 0.08, 0))
		scl("orb_core", Vector3.ONE * (1.0 + up * 0.6))
		rot("brow_l", Vector3(0, 0, -10 * up))
	# select: staff twirl with a cheeky hop
	var q := select_progress()
	if q >= 0.0:
		var a := bump(q)
		off("body", Vector3(0, absf(sin(q * PI * 3.0)) * 0.25 * a, 0))
		rot("body", Vector3(0, sin(q * TAU) * 25, 0))
		rot("arm_r", Vector3(110 * a, 0, 0))
		rot("staff", Vector3(0, q * 720, 0))
		rot("arm_l", Vector3(0, 0, -50 * a))
		scl("mouth", Vector3(1.2, 1 + 1.6 * a, 1))
		rot("head", Vector3(-12 * a, 0, sin(q * PI * 4.0) * 10 * a))
