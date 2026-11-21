@tool
extends MonsterModel
## STONE GOLEM – a huge, clumsy and lovable boulder giant with mossy shoulders,
## glowing crystals on its back, gigantic fists and big goofy eyes.

const STONE := Color("#6f7a8e")
const STONE_DARK := Color("#4d566b")
const STONE_LIGHT := Color("#8d97ab")
const MOSS := Color("#5fae3a")
const CRYSTAL := Color("#46e0ff")

func build() -> void:
	attack_anim_len = 1.5
	impact_at = 0.58
	select_len = 1.8
	death_len = 1.2
	var body := pivot("body", null, Vector3.ZERO)
	for s: int in [-1, 1]:
		var leg := pivot("leg_l" if s < 0 else "leg_r", body, Vector3(0.32 * s, 0.42, 0))
		add_mesh("", leg, cyl(0.17, 0.2, 0.34, 10), mat(STONE_DARK, 0.95), Vector3(0, -0.2, 0))
		add_mesh("", leg, sphere(0.24, 0.24, 12), mat(STONE, 0.95), Vector3(0, -0.36, -0.06), Vector3.ZERO, Vector3(1, 1, 1.25))
	var torso := pivot("torso", body, Vector3(0, 0.45, 0))
	add_mesh("", torso, sphere(0.74, 1.2, 20), mat(STONE, 0.95), Vector3(0, 0.55, 0.05), Vector3.ZERO, Vector3(1.1, 1, 0.95))
	add_mesh("", torso, sphere(0.5, 0.7, 16), mat(STONE_LIGHT, 0.95), Vector3(0, 0.42, -0.36), Vector3.ZERO, Vector3(1, 1, 0.6))
	# rocky bumps and cracks for a hand-sculpted feel
	var bumps := [Vector3(-0.5, 0.85, 0.3), Vector3(0.45, 0.3, 0.45), Vector3(0.6, 0.75, -0.1), Vector3(-0.62, 0.35, 0.0), Vector3(0.1, 1.0, 0.55)]
	for i in bumps.size():
		add_mesh("", torso, sphere(0.2 + 0.04 * (i % 3), -1, 10), mat(STONE_DARK if i % 2 == 0 else STONE_LIGHT, 0.95), bumps[i])
	# moss cap with little flowers
	add_mesh("", torso, sphere(0.62, 0.42, 18), mat(MOSS, 0.9), Vector3(0, 1.02, 0.12), Vector3(-8, 0, 0), Vector3(1.15, 1, 1.0))
	for f in [Vector3(-0.3, 1.2, -0.05), Vector3(0.35, 1.17, 0.2), Vector3(0.05, 1.22, 0.35)]:
		add_mesh("", torso, sphere(0.05, -1, 8), mat(Color("#ff8fc7"), 0.6), f)
		add_mesh("", torso, sphere(0.022, -1, 6), mat(Color("#ffe14d"), 0.6), f + Vector3(0, 0.035, 0))
	# crystals on the back
	var cr := [Vector3(-0.25, 1.05, 0.55), Vector3(0.12, 1.15, 0.6), Vector3(0.38, 0.9, 0.55)]
	for i in cr.size():
		add_mesh("crystal%d" % i, torso, cyl(0.0, 0.11 + i * 0.02, 0.45 + i * 0.08, 6), mat(CRYSTAL, 0.15, 1.2, 0.1), cr[i], Vector3(35, 0, (i - 1) * 25))
	# head sunk into the front of the body
	var head := pivot("head", torso, Vector3(0, 0.78, -0.55))
	add_mesh("", head, sphere(0.38, 0.62, 18), mat(STONE_LIGHT, 0.95), Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 1, 0.9))
	add_mesh("brow", head, box(Vector3(0.62, 0.12, 0.2)), mat(STONE_DARK, 0.95), Vector3(0, 0.15, -0.24), Vector3(10, 0, 0))
	for s: int in [-1, 1]:
		add_eye("eye_l" if s < 0 else "eye_r", head, Vector3(0.15 * s, 0.02, -0.3), 0.11, Color("#e88a1a"))
	add_mesh("mouth", head, sphere(0.09, -1, 12), mat(Color("#3a2620"), 0.9), Vector3(0, -0.17, -0.3), Vector3.ZERO, Vector3(1.6, 0.55, 0.6))
	add_mesh("", head, box(Vector3(0.06, 0.06, 0.04)), mat(Color("#f4efe2"), 0.6), Vector3(-0.06, -0.14, -0.34))
	add_mesh("", head, box(Vector3(0.06, 0.06, 0.04)), mat(Color("#f4efe2"), 0.6), Vector3(0.07, -0.14, -0.34))
	# giant arms
	for s: int in [-1, 1]:
		var n := "arm_l" if s < 0 else "arm_r"
		var arm := pivot(n, torso, Vector3(0.82 * s, 0.85, 0), Vector3(15, 0, 12 * s))
		add_mesh("", arm, sphere(0.3, -1, 14), mat(STONE, 0.95), Vector3.ZERO)
		add_mesh("", arm, sphere(0.26, 0.4, 14), mat(MOSS, 0.9), Vector3(0, 0.15, 0.02), Vector3.ZERO, Vector3(1.05, 1, 1.05))
		add_mesh("", arm, cyl(0.18, 0.22, 0.5, 10), mat(STONE_DARK, 0.95), Vector3(0, -0.33, 0))
		var fist := pivot("fist_l" if s < 0 else "fist_r", arm, Vector3(0, -0.72, -0.02))
		add_mesh("", fist, sphere(0.38, 0.66, 16), mat(STONE, 0.95), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 1.1))
		for k in 3:
			add_mesh("", fist, sphere(0.11, -1, 10), mat(STONE_LIGHT, 0.95), Vector3((k - 1) * 0.17, -0.12, -0.3))
	var dust := add_particles("dust", body, Color(0.8, 0.72, 0.6), 8, 0.8, 0.45, Vector3(0, 0.5, 0.4), 50.0, 0.3, false)
	dust.emitting = false

func get_muzzle_position() -> Vector3:
	return (parts["fist_r"] as Node3D).global_position

func pose(_dt: float) -> void:
	var walk := move_blend
	var cyc := t * 4.5
	# heavy waddle
	off("body", Vector3(0, absf(sin(cyc)) * 0.08 * walk + sin(t * 1.6) * 0.015, 0))
	rot("body", Vector3(0, 0, sin(cyc) * 6 * walk))
	rot("torso", Vector3(sin(t * 1.6) * 2 - 5 * walk, sin(cyc) * 4 * walk, 0))
	rot("leg_l", Vector3(sin(cyc) * 25 * walk, 0, 0))
	rot("leg_r", Vector3(-sin(cyc) * 25 * walk, 0, 0))
	rot("arm_l", Vector3(-sin(cyc) * 18 * walk + sin(t * 1.6) * 3, 0, 0))
	rot("arm_r", Vector3(sin(cyc) * 18 * walk + sin(t * 1.6 + 1) * 3, 0, 0))
	rot("head", Vector3(sin(t * 1.6 + 0.5) * 3, sin(t * 0.7) * 6 * (1.0 - walk), 0))
	(parts["dust"] as CPUParticles3D).emitting = walk > 0.5
	var b := fmod(t + 0.2, 4.6)
	if b < 0.16:
		var k := 1.0 - bump(b / 0.16) * 0.92
		scl("eye_l", Vector3(1, k, 1))
		scl("eye_r", Vector3(1, k, 1))
	# attack: double fist overhead slam
	var p := attack_progress()
	if p >= 0.0:
		var s := swing_curve(p, impact_at)
		var up := clampf(-s, 0, 1)
		var down := clampf(s, 0, 1)
		rot("arm_l", Vector3(up * 160 + down * 25, 0, -up * 10 - down * 20))
		rot("arm_r", Vector3(up * 160 + down * 25, 0, up * 10 + down * 20))
		rot("torso", Vector3(-up * 15 + down * 25, 0, 0))
		off("body", Vector3(0, up * 0.15 - down * 0.06, 0))
		rot("brow", Vector3(-15 * (up + down), 0, 0))
		scl("mouth", Vector3(1, 1 + 1.8 * (up + down), 1))
	# select: chest pounding roar
	var q := select_progress()
	if q >= 0.0:
		var beat := sin(q * PI * 6.0)
		var amt := bump(q)
		rot("arm_l", Vector3(80 * amt + maxf(beat, 0) * 30, 0, 30 * amt))
		rot("arm_r", Vector3(80 * amt + maxf(-beat, 0) * 30, 0, -30 * amt))
		rot("head", Vector3(-20 * amt, 0, 0))
		scl("mouth", Vector3(1.2, 1 + 2.5 * amt, 1))
		off("body", Vector3(0, absf(beat) * 0.08 * amt, 0))
