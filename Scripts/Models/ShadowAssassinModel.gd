@tool
extends MonsterModel
## SHADOW ASSASSIN – a small, cool ninja with a fox-eared hood, big glowing
## cyan eyes, a long magenta scarf and two violet daggers. Mysterious, never scary.

const HOOD := Color("#2b2350")
const HOOD_LIGHT := Color("#40357a")
const CLOTH := Color("#1d1a33")
const SCARF := Color("#d23ad6")
const BLADE := Color("#b98cff")
const FACE := Color("#141026")

func build() -> void:
	attack_anim_len = 0.5
	impact_at = 0.42
	select_len = 1.3
	var body := pivot("body", null, Vector3.ZERO)
	for s: int in [-1, 1]:
		var leg := pivot("leg_l" if s < 0 else "leg_r", body, Vector3(0.1 * s, 0.3, 0))
		add_mesh("", leg, capsule(0.065, 0.28), mat(CLOTH, 0.8), Vector3(0, -0.12, 0))
		add_mesh("", leg, sphere(0.08, 0.12), mat(HOOD, 0.7), Vector3(0, -0.27, -0.05), Vector3(0, 0, 0), Vector3(0.9, 1, 1.6))
		add_mesh("", leg, torus(0.055, 0.08, 14), mat(SCARF, 0.6), Vector3(0, -0.18, 0))
	var torso := pivot("torso", body, Vector3(0, 0.32, 0))
	add_mesh("", torso, sphere(0.22, 0.42), mat(HOOD, 0.7), Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	add_mesh("", torso, torus(0.17, 0.24), mat(SCARF, 0.6), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1.6, 0.9))
	add_mesh("", torso, sphere(0.05, -1, 10), mat(Color("#ffd35a"), 0.3, 0, 0.7), Vector3(0, 0.03, -0.21))
	# scarf: neck wrap + two long trailing tails
	add_mesh("", torso, torus(0.13, 0.22), mat(SCARF, 0.6), Vector3(0, 0.36, 0), Vector3(-8, 0, 0), Vector3(1, 1.5, 1))
	var scarf := pivot("scarf", torso, Vector3(0.08, 0.36, 0.17), Vector3(70, 15, 0))
	var seg_parent := scarf
	for i in 3:
		var sp := pivot("scarf%d" % i, seg_parent, Vector3(0, -0.2 if i > 0 else 0.0, 0))
		add_mesh("", sp, box(Vector3(0.13 - i * 0.02, 0.22, 0.03)), mat(SCARF, 0.6), Vector3(0, -0.1, 0))
		seg_parent = sp
	# arms with reverse-grip daggers
	for s: int in [-1, 1]:
		var n := "arm_l" if s < 0 else "arm_r"
		var arm := pivot(n, torso, Vector3(0.22 * s, 0.3, 0), Vector3(20, 0, 22 * s))
		add_mesh("", arm, capsule(0.055, 0.26), mat(CLOTH, 0.8), Vector3(0, -0.12, 0))
		add_mesh("", arm, torus(0.045, 0.07, 12), mat(SCARF, 0.6), Vector3(0, -0.19, 0))
		add_mesh("", arm, sphere(0.065, -1, 12), mat(HOOD_LIGHT, 0.7), Vector3(0, -0.27, 0))
		var dg := pivot("dagger_l" if s < 0 else "dagger_r", arm, Vector3(0, -0.29, 0), Vector3(-100, 0, 0))
		add_mesh("", dg, cyl(0.022, 0.022, 0.14, 8), mat(Color("#3a2a20"), 0.8), Vector3(0, 0, 0.04), Vector3(90, 0, 0))
		add_mesh("", dg, box(Vector3(0.12, 0.03, 0.035)), mat(Color("#ffd35a"), 0.3, 0, 0.7), Vector3(0, 0, -0.04))
		add_mesh("", dg, prism(Vector3(0.13, 0.44, 0.035)), mat(BLADE, 0.2, 1.6, 0.4), Vector3(0, 0, -0.26), Vector3(-90, 0, 0))
		add_mesh("", dg, box(Vector3(0.02, 0.03, 0.28)), glow_mat(Color(0.9, 0.75, 1.0), 1.4), Vector3(0, 0.005, -0.22))
	# head with fox-eared hood
	var head := pivot("head", torso, Vector3(0, 0.6, 0))
	add_mesh("hood", head, sphere(0.33), mat(HOOD, 0.7), Vector3(0, 0.02, 0.03))
	add_mesh("", head, sphere(0.27, 0.5), mat(FACE, 0.9), Vector3(0, -0.01, -0.12), Vector3.ZERO, Vector3(1.02, 0.95, 0.9))
	add_mesh("", head, torus(0.25, 0.3, 28), mat(HOOD_LIGHT, 0.7), Vector3(0, -0.01, -0.2), Vector3(-80, 0, 0), Vector3(1.0, 1.0, 0.9))
	for s: int in [-1, 1]:
		var ear := pivot("ear_l" if s < 0 else "ear_r", head, Vector3(0.17 * s, 0.27, 0.04), Vector3(-10, 0, -22 * s))
		add_mesh("", ear, cyl(0.0, 0.11, 0.24, 12), mat(HOOD, 0.7), Vector3(0, 0.1, 0))
		add_mesh("", ear, cyl(0.0, 0.065, 0.15, 10), mat(SCARF, 0.6), Vector3(0, 0.07, -0.05))
		add_eye("eye_l" if s < 0 else "eye_r", head, Vector3(0.105 * s, 0.03, -0.32), 0.08, Color(0.35, 0.95, 1.0), true)
	# mask over the lower face
	add_mesh("", head, sphere(0.22, 0.2), mat(HOOD_LIGHT, 0.7), Vector3(0, -0.15, -0.16), Vector3(0, 0, 0), Vector3(1.1, 1, 0.9))
	add_mesh("", head, cyl(0.0, 0.1, 0.25, 12), mat(HOOD, 0.7), Vector3(0, 0.08, 0.32), Vector3(-75, 0, 0))
	# shadow wisps trailing behind
	var wisp := add_particles("wisps", body, Color(0.45, 0.25, 0.9), 14, 0.7, 0.28, Vector3(0, 0.6, 0.4), 40.0, 0.2, false)
	wisp.position = Vector3(0, 0.4, 0.15)

func pose(_dt: float) -> void:
	var run := move_blend
	var cyc := t * 15.0
	# crouched ready stance; ninja run leans forward with arms back
	off("body", Vector3(0, absf(sin(cyc)) * 0.07 * run + sin(t * 3.0) * 0.01, 0))
	rot("torso", Vector3(-28 * run - 6, sin(cyc) * 5 * run, 0))
	rot("head", Vector3(20 * run + sin(t * 3.0) * 2, 0, sin(t * 1.7) * 3 * (1.0 - run)))
	rot("leg_l", Vector3(sin(cyc) * 55 * run + 10, 0, 0))
	rot("leg_r", Vector3(-sin(cyc) * 55 * run + 10, 0, 0))
	rot("arm_l", Vector3(-75 * run + sin(t * 3.0) * 4, 0, -10 * run))
	rot("arm_r", Vector3(-75 * run - sin(t * 3.0) * 4, 0, 10 * run))
	rot("scarf", Vector3(-45 * run + sin(t * 6.0) * 8, sin(t * 4.0) * 10, 0))
	rot("scarf1", Vector3(sin(t * 8.0 + 1) * 15 - 10 * run, 0, 0))
	rot("scarf2", Vector3(sin(t * 8.0 + 2) * 20 - 10 * run, 0, 0))
	rot("ear_l", Vector3(sin(t * 2.0) * 4, 0, 0))
	rot("ear_r", Vector3(sin(t * 2.0 + 0.6) * 4, 0, 0))
	var b := fmod(t + 1.3, 3.9)
	if b < 0.1:
		var k := 1.0 - bump(b / 0.1) * 0.9
		scl("eye_l", Vector3(1, k, 1))
		scl("eye_r", Vector3(1, k, 1))
	# attack: lunge with crossing double slash
	var p := attack_progress()
	if p >= 0.0:
		var s := swing_curve(p, impact_at)
		var up := clampf(-s, 0, 1)
		var down := clampf(s, 0, 1)
		off("body", Vector3(0, -up * 0.06, -down * 0.25))
		rot("torso", Vector3(-up * 5 - down * 30, up * 20 - down * 20, 0))
		rot("arm_r", Vector3(up * 140 - down * 10, -up * 30 + down * 40, up * 20 - down * 40))
		rot("arm_l", Vector3(up * 120 - down * 10, up * 30 - down * 40, -up * 20 + down * 40))
		rot("dagger_r", Vector3(down * 60, 0, 0))
		rot("dagger_l", Vector3(down * 60, 0, 0))
		rot("scarf", Vector3(-30 * down, 0, 0))
	# select: spinning dagger twirl leap
	var q := select_progress()
	if q >= 0.0:
		var j := bump(q)
		off("body", Vector3(0, j * 0.5, 0))
		rot("body", Vector3(0, ease_in_out(q) * 360, 0))
		rot("arm_l", Vector3(0, 0, -j * 80))
		rot("arm_r", Vector3(0, 0, j * 80))
		rot("dagger_l", Vector3(q * 720, 0, 0))
		rot("dagger_r", Vector3(q * 720, 0, 0))
		rot("leg_l", Vector3(j * 50, 0, 0))
		rot("leg_r", Vector3(j * 50, 0, 0))
