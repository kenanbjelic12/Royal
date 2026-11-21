@tool
extends MonsterModel
## FROST DRAGON – a chubby little sky-blue dragon with huge eyes, ice horns,
## translucent wings and a crystal tail. Cute, but its ice breath hits hard.

const SKIN := Color("#4aa8ff")
const SKIN_DARK := Color("#2b74d9")
const BELLY := Color("#cdf1ff")
const ICE := Color("#a8f4ff")
const WING := Color("#57b8ff")

func build() -> void:
	attack_anim_len = 0.8
	impact_at = 0.5
	select_len = 1.5
	var body := pivot("body", null, Vector3.ZERO)
	var torso := pivot("torso", body, Vector3(0, 0, 0))
	add_mesh("", torso, sphere(0.36, 0.66, 20), mat(SKIN, 0.5), Vector3(0, 0, 0.05), Vector3(-15, 0, 0), Vector3(1, 1, 1.15))
	add_mesh("", torso, sphere(0.28, 0.5, 16), mat(BELLY, 0.6), Vector3(0, -0.07, -0.16), Vector3(-25, 0, 0), Vector3(1, 1, 0.8))
	for i in 3:
		add_mesh("", torso, cyl(0.0, 0.06, 0.15, 6), mat(ICE, 0.15, 0.6), Vector3(0, 0.3 - i * 0.05, 0.12 + i * 0.16), Vector3(-30 - i * 15, 0, 0))
	# tiny legs
	for s: int in [-1, 1]:
		var leg := pivot("leg_l" if s < 0 else "leg_r", torso, Vector3(0.18 * s, -0.25, 0.05))
		add_mesh("", leg, capsule(0.07, 0.18), mat(SKIN_DARK, 0.5), Vector3(0, -0.06, 0), Vector3(-30, 0, 0))
		add_mesh("", leg, sphere(0.06, -1, 10), mat(BELLY, 0.6), Vector3(0, -0.14, -0.06))
	# tail chain
	var tail_parent := torso
	var tail_pos := Vector3(0, -0.1, 0.38)
	for i in 4:
		var seg := pivot("tail%d" % i, tail_parent, tail_pos, Vector3(15 if i == 0 else 10, 0, 0))
		var r := 0.13 - i * 0.025
		add_mesh("", seg, sphere(r, -1, 12), mat(SKIN if i % 2 == 0 else SKIN_DARK, 0.5), Vector3(0, 0, r * 0.8))
		tail_parent = seg
		tail_pos = Vector3(0, 0, r * 1.5)
	add_mesh("", tail_parent, cyl(0.0, 0.08, 0.22, 6), mat(ICE, 0.15, 0.8), Vector3(0, 0, 0.2), Vector3(90, 0, 0))
	# wings (two-part, translucent membrane)
	for s: int in [-1, 1]:
		var w := pivot("wing_l" if s < 0 else "wing_r", torso, Vector3(0.2 * s, 0.2, 0.08), Vector3(0, 0, 8 * s))
		add_mesh("", w, capsule(0.035, 0.5, 8), mat(SKIN_DARK, 0.5), Vector3(0.25 * s, 0.1, 0), Vector3(0, 0, 70 * s))
		var mem := StandardMaterial3D.new()
		mem.albedo_color = Color(WING.r, WING.g, WING.b, 0.96)
		mem.roughness = 0.9
		mem.metallic_specular = 0.1
		mem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mem.cull_mode = BaseMaterial3D.CULL_DISABLED
		mem.rim_enabled = true
		mem.rim = 0.5
		mem.emission_enabled = true
		mem.emission = WING * 0.3
		add_mesh("", w, sphere(0.36, 0.72, 16), mem, Vector3(0.3 * s, 0.0, 0.14), Vector3(0, 0, 18 * s), Vector3(1.0, 0.1, 0.9))
		var tip := pivot("wingtip_l" if s < 0 else "wingtip_r", w, Vector3(0.52 * s, 0.17, 0))
		add_mesh("", tip, capsule(0.03, 0.36, 8), mat(SKIN_DARK, 0.5), Vector3(0.14 * s, 0.03, 0.0), Vector3(0, 0, 80 * s))
		add_mesh("", tip, sphere(0.27, 0.54, 14), mem, Vector3(0.18 * s, 0.0, 0.16), Vector3(0, 0, 10 * s), Vector3(1.0, 0.1, 0.95))
	# head
	var neck := pivot("neck", torso, Vector3(0, 0.25, -0.22))
	var head := pivot("head", neck, Vector3(0, 0.12, -0.1))
	add_mesh("", head, sphere(0.31, 0.56, 20), mat(SKIN, 0.5), Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1, 1))
	var jaw := pivot("jaw", head, Vector3(0, -0.1, -0.2))
	add_mesh("", jaw, sphere(0.16, 0.16, 14), mat(BELLY, 0.6), Vector3(0, -0.02, -0.1), Vector3.ZERO, Vector3(1.1, 1, 1.2))
	add_mesh("snout", head, sphere(0.18, 0.24, 16), mat(SKIN, 0.5), Vector3(0, -0.04, -0.3), Vector3.ZERO, Vector3(1.15, 1, 1.15))
	for s: int in [-1, 1]:
		add_mesh("", head, sphere(0.025, -1, 8), mat(SKIN_DARK, 0.6), Vector3(0.06 * s, 0.03, -0.47))
		add_eye("eye_l" if s < 0 else "eye_r", head, Vector3(0.14 * s, 0.1, -0.21), 0.1, Color("#1f6fe0"))
		var horn := pivot("horn_l" if s < 0 else "horn_r", head, Vector3(0.17 * s, 0.24, 0.05), Vector3(-35, 0, -25 * s))
		add_mesh("", horn, cyl(0.0, 0.065, 0.28, 8), mat(ICE, 0.15, 0.7), Vector3(0, 0.12, 0))
		add_mesh("", head, cyl(0.0, 0.06, 0.16, 8), mat(SKIN_DARK, 0.5), Vector3(0.28 * s, 0.04, 0.05), Vector3(0, 0, -75 * s))
	for i in 3:
		add_mesh("", head, cyl(0.0, 0.045, 0.14, 6), mat(ICE, 0.15, 0.7), Vector3(0, 0.29 - i * 0.03, 0.02 + i * 0.12), Vector3(-30 - i * 20, 0, 0))
	add_mesh("", head, sphere(0.04, 0.03, 10), glow_mat(Color(1, 0.6, 0.75), 1.0, 0.45), Vector3(-0.2, -0.04, -0.22))
	add_mesh("", head, sphere(0.04, 0.03, 10), glow_mat(Color(1, 0.6, 0.75), 1.0, 0.45), Vector3(0.2, -0.04, -0.22))
	var breath := add_particles("breath", head, Color(0.75, 0.97, 1.0), 20, 0.4, 0.16, Vector3(0, 0, -3.0), 18.0, 0.05)
	breath.position = Vector3(0, -0.08, -0.45)
	breath.emitting = false
	var frost := add_particles("frost", body, Color(0.7, 0.95, 1.0), 10, 1.0, 0.12, Vector3(0, -0.6, 0), 60.0, 0.35)
	frost.position = Vector3(0, -0.2, 0)

func get_muzzle_position() -> Vector3:
	return (parts["snout"] as Node3D).global_position

func pose(_dt: float) -> void:
	var fly := move_blend
	var flap_speed := 7.0 + 3.0 * fly
	var flap := sin(t * flap_speed)
	off("body", Vector3(0, -flap * 0.07 + sin(t * 1.3) * 0.05, 0))
	rot("torso", Vector3(-10 * fly + flap * 2, 0, sin(t * 1.1) * 3))
	rot("wing_l", Vector3(0, -10, -flap * 30 + 4))
	rot("wing_r", Vector3(0, 10, flap * 30 - 4))
	rot("wingtip_l", Vector3(0, 0, -flap * 18))
	rot("wingtip_r", Vector3(0, 0, flap * 18))
	rot("neck", Vector3(10 * fly + flap * 3, 0, 0))
	rot("head", Vector3(sin(t * 1.3 + 1) * 4, sin(t * 0.8) * 8 * (1.0 - fly), 0))
	for i in 4:
		rot("tail%d" % i, Vector3(sin(t * 3.0 - i * 0.7) * 8, sin(t * 2.2 - i * 0.8) * 12, 0))
	rot("leg_l", Vector3(20 * fly + flap * 5, 0, 0))
	rot("leg_r", Vector3(20 * fly - flap * 5, 0, 0))
	var b := fmod(t + 2.1, 3.7)
	if b < 0.1:
		var k := 1.0 - bump(b / 0.1) * 0.9
		scl("eye_l", Vector3(1, k, 1))
		scl("eye_r", Vector3(1, k, 1))
	(parts["breath"] as CPUParticles3D).emitting = false
	# attack: rear back, then snap forward spitting ice
	var p := attack_progress()
	if p >= 0.0:
		var s := swing_curve(p, impact_at)
		var up := clampf(-s, 0, 1)
		var down := clampf(s, 0, 1)
		rot("neck", Vector3(-up * 35 + down * 30, 0, 0))
		rot("head", Vector3(-up * 15 + down * 15, 0, 0))
		rot("jaw", Vector3(down * 35, 0, 0))
		rot("torso", Vector3(-up * 10 + down * 8, 0, 0))
		off("body", Vector3(0, up * 0.08, up * 0.15 - down * 0.15))
		(parts["breath"] as CPUParticles3D).emitting = down > 0.3
	# select: loop-the-loop
	var q := select_progress()
	if q >= 0.0:
		var e := ease_in_out(q)
		rot("body", Vector3(-e * 360, 0, 0))
		off("body", Vector3(0, bump(q) * 0.6, -sin(e * TAU) * 0.3))
		rot("jaw", Vector3(bump(q) * 30, 0, 0))
