@tool
extends MonsterModel
## FIRE KNIGHT – a small, brave chibi knight with a huge blazing greatsword,
## crimson & gold armour, flame plume and a fluttering cape.

const ARMOR := Color("#c8323a")
const ARMOR_DARK := Color("#7a1a24")
const GOLD := Color("#f2b632")
const STEEL := Color("#b9c3d1")
const SKIN := Color("#ffcf9e")
const BLADE := Color("#ff7a1a")

var _sword_fire: CPUParticles3D
var _plume_fire: CPUParticles3D

func build() -> void:
	attack_anim_len = 0.95
	impact_at = 0.5
	select_len = 1.7
	var body := pivot("body", null, Vector3(0, 0, 0))
	# legs
	for s: int in [-1, 1]:
		var n := "leg_l" if s < 0 else "leg_r"
		var leg := pivot(n, body, Vector3(0.13 * s, 0.33, 0))
		add_mesh("", leg, capsule(0.085, 0.3), mat(STEEL, 0.35, 0, 0.6), Vector3(0, -0.13, 0))
		add_mesh("", leg, sphere(0.11, 0.16), mat(ARMOR_DARK, 0.5), Vector3(0, -0.28, -0.04), Vector3.ZERO, Vector3(1, 1, 1.35))
	# torso
	var torso := pivot("torso", body, Vector3(0, 0.36, 0))
	add_mesh("chest", torso, sphere(0.3, 0.5), mat(ARMOR, 0.4, 0, 0.35), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.05, 1, 0.9))
	add_mesh("", torso, torus(0.24, 0.31), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1.4, 0.92))
	add_mesh("", torso, sphere(0.25, 0.22), mat(ARMOR_DARK, 0.5), Vector3(0, -0.02, 0))
	# chest emblem (flame gem)
	add_mesh("", torso, sphere(0.07, 0.11, 12), glow_mat(Color(1, 0.55, 0.1), 1.6), Vector3(0, 0.24, -0.27))
	add_mesh("", torso, torus(0.065, 0.09, 16), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0.24, -0.26), Vector3(90, 0, 0))
	# cape
	var cape := pivot("cape", torso, Vector3(0, 0.42, 0.17), Vector3(8, 0, 0))
	add_mesh("", cape, box(Vector3(0.46, 0.55, 0.04)), mat(ARMOR_DARK, 0.8), Vector3(0, -0.27, 0.03))
	add_mesh("", cape, box(Vector3(0.48, 0.07, 0.05)), mat(GOLD, 0.4, 0, 0.6), Vector3(0, -0.55, 0.03))
	# shoulders + arms
	for s: int in [-1, 1]:
		add_mesh("", torso, sphere(0.15, 0.22), mat(GOLD, 0.3, 0, 0.7), Vector3(0.31 * s, 0.4, 0), Vector3(0, 0, -20 * s), Vector3(1.1, 1, 1.1))
		add_mesh("", torso, sphere(0.13, 0.19), mat(ARMOR, 0.4, 0, 0.35), Vector3(0.32 * s, 0.44, 0), Vector3(0, 0, -20 * s))
		var n := "arm_l" if s < 0 else "arm_r"
		var arm := pivot(n, torso, Vector3(0.32 * s, 0.36, 0), Vector3(40, 0, 18 * s))
		add_mesh("", arm, capsule(0.07, 0.28), mat(STEEL, 0.35, 0, 0.6), Vector3(0, -0.13, 0))
		add_mesh("", arm, sphere(0.09, -1, 14), mat(ARMOR_DARK, 0.5), Vector3(0, -0.29, 0))
	# greatsword in the right hand
	var sword := pivot("sword", parts["arm_r"], Vector3(-0.04, -0.3, 0), Vector3(10, 0, -12))
	add_mesh("", sword, cyl(0.035, 0.035, 0.26, 10), mat(Color("#5a3220"), 0.8), Vector3(0, 0, 0.02), Vector3(90, 0, 0))
	add_mesh("", sword, sphere(0.055, -1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0, 0.16))
	add_mesh("", sword, box(Vector3(0.36, 0.06, 0.07)), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0, -0.12))
	add_mesh("", sword, sphere(0.05, -1, 10), glow_mat(Color(1, 0.4, 0.1), 1.5), Vector3(0, 0, -0.12))
	add_mesh("blade", sword, box(Vector3(0.16, 0.035, 1.05)), mat(BLADE, 0.25, 1.4, 0.2), Vector3(0, 0, -0.67))
	add_mesh("", sword, prism(Vector3(0.15, 0.16, 0.035)), mat(BLADE, 0.25, 1.4, 0.2), Vector3(0, 0, -1.27), Vector3(-90, 0, 0))
	add_mesh("", sword, box(Vector3(0.05, 0.045, 0.92)), glow_mat(Color(1, 0.95, 0.6), 1.3), Vector3(0, 0, -0.66))
	_sword_fire = add_particles("sword_fire", sword, Color(1, 0.55, 0.12), 26, 0.5, 0.2, Vector3(0, 1.4, 0), 30.0, 0.12, false)
	_sword_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sword_fire.emission_box_extents = Vector3(0.06, 0.02, 0.45)
	_sword_fire.position = Vector3(0, 0, -0.7)
	# head
	var head := pivot("head", torso, Vector3(0, 0.66, 0))
	add_mesh("face", head, sphere(0.31), mat(SKIN, 0.75), Vector3(0, 0.02, -0.02))
	add_mesh("helmet", head, sphere(0.355), mat(ARMOR, 0.35, 0, 0.35), Vector3(0, 0.11, 0.07))
	add_mesh("", head, torus(0.3, 0.37, 28), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0.03, -0.04), Vector3(-62, 0, 0), Vector3(1, 0.8, 1))
	add_mesh("", head, sphere(0.06, 0.1, 10), mat(GOLD, 0.3, 0, 0.7), Vector3(0, 0.34, -0.2), Vector3(-30, 0, 0))
	for s: int in [-1, 1]:
		add_mesh("", head, sphere(0.11, 0.2), mat(ARMOR, 0.35, 0, 0.35), Vector3(0.27 * s, -0.06, -0.08), Vector3(0, 0, 10 * s), Vector3(0.7, 1, 1))
		add_eye("eye_l" if s < 0 else "eye_r", head, Vector3(0.115 * s, 0.0, -0.27), 0.085, Color("#3b2a1a"))
		add_mesh("brow_l" if s < 0 else "brow_r", head, box(Vector3(0.12, 0.035, 0.04)), mat(Color("#3d2412"), 0.8), Vector3(0.12 * s, 0.11, -0.29), Vector3(0, 0, 18 * s))
	add_mesh("", head, sphere(0.045, 0.04, 10), mat(Color("#e8806a"), 0.8), Vector3(0, -0.07, -0.31))
	add_mesh("mouth", head, sphere(0.055, -1, 12), mat(Color("#6b1f22"), 0.8), Vector3(0, -0.15, -0.275), Vector3.ZERO, Vector3(1.5, 0.5, 0.5))
	add_mesh("", head, box(Vector3(0.1, 0.022, 0.02)), mat(Color(1, 1, 1), 0.4), Vector3(0, -0.137, -0.297))
	for s: int in [-1, 1]:
		add_mesh("", head, sphere(0.05, 0.03, 10), glow_mat(Color(1, 0.55, 0.55), 1.0, 0.45), Vector3(0.2 * s, -0.09, -0.24))
	# flame plume
	var plume := pivot("plume", head, Vector3(0, 0.42, 0.1))
	add_mesh("", plume, sphere(0.1, 0.24, 14), glow_mat(Color(1, 0.45, 0.08), 1.4), Vector3(0, 0.05, 0.02), Vector3(-25, 0, 0))
	add_mesh("", plume, sphere(0.07, 0.2, 12), glow_mat(Color(1, 0.85, 0.3), 1.4), Vector3(0, 0.1, 0.0), Vector3(-25, 0, 0))
	_plume_fire = add_particles("plume_fire", plume, Color(1, 0.6, 0.15), 18, 0.55, 0.2, Vector3(0, 1.2, 0.5), 20.0, 0.06, false)

func get_muzzle_position() -> Vector3:
	return (parts["blade"] as Node3D).global_position

func pose(_dt: float) -> void:
	var walk := move_blend
	var cyc := t * 9.0
	# idle breathing
	off("body", Vector3(0, absf(sin(cyc)) * 0.06 * walk + sin(t * 2.2) * 0.012 * (1.0 - walk), 0))
	rot("torso", Vector3(-6 * walk + sin(t * 2.2) * 1.5, sin(cyc) * 6 * walk, 0))
	rot("leg_l", Vector3(sin(cyc) * 35 * walk, 0, 0))
	rot("leg_r", Vector3(-sin(cyc) * 35 * walk, 0, 0))
	rot("arm_l", Vector3(-sin(cyc) * 14 * walk, 0, 0))
	rot("arm_r", Vector3(sin(cyc) * 10 * walk + sin(t * 2.2) * 3, 0, 0))
	rot("head", Vector3(sin(t * 2.2 + 1.0) * 2.0, sin(cyc) * -4 * walk, 0))
	rot("cape", Vector3(10 * walk + sin(t * 5.0) * 4, 0, sin(t * 3.0) * 3))
	rot("plume", Vector3(sin(t * 7.0) * 6 + 18 * walk, 0, sin(t * 5.0) * 5))
	# blink
	_blink()
	# attack: big overhead cleave
	var p := attack_progress()
	if p >= 0.0:
		var s := swing_curve(p, impact_at)
		var up := clampf(-s, 0, 1)
		var down := clampf(s, 0, 1)
		rot("arm_r", Vector3(up * 120 - down * 45, 0, -up * 12))
		rot("sword", Vector3(-down * 40, 0, 0))
		rot("arm_l", Vector3(up * 125 - down * 30, up * 25 + down * 30, 18 * down))
		rot("torso", Vector3(-up * 12 + down * 22, -up * 15 + down * 18, 0))
		off("body", Vector3(0, up * 0.06, -down * 0.12))
		rot("head", Vector3(-up * 6 + down * 8, 0, 0))
		rot("brow_l", Vector3(0, 0, -10 * (up + down)))
		rot("brow_r", Vector3(0, 0, 10 * (up + down)))
		scl("mouth", Vector3(1, 1 + 1.5 * down, 1))
	# select: triumphant sword raise with jump
	var q := select_progress()
	if q >= 0.0:
		var j := bump(clampf(q / 0.45, 0, 1))
		var raise := ease_out(clampf(q / 0.3, 0, 1)) * (1.0 - ease_in_out(clampf((q - 0.75) / 0.25, 0, 1)))
		off("body", Vector3(0, j * 0.45, 0))
		rot("arm_r", Vector3(raise * 125, 0, -raise * 20))
		rot("sword", Vector3(-raise * 60, 0, 0))
		rot("arm_l", Vector3(0, 0, -raise * 60))
		rot("leg_l", Vector3(j * 30, 0, 0))
		rot("leg_r", Vector3(-j * 20, 0, 0))
		rot("torso", Vector3(-raise * 8, 0, 0))
		scl("mouth", Vector3(1, 1 + raise * 2.5, 1))
		_sword_fire.amount = 26
		_sword_fire.speed_scale = 1.0 + raise * 1.5

func _blink() -> void:
	var b := fmod(t + 0.7, 3.4)
	if b < 0.12:
		var k := 1.0 - bump(b / 0.12) * 0.9
		scl("eye_l", Vector3(1, k, 1))
		scl("eye_r", Vector3(1, k, 1))
