class_name BattleCamera
extends Camera3D
## High-angle (~70°) perspective camera that automatically fits the whole arena
## between the top bar and the card panel for any screen aspect ratio, with a
## small screen shake.

@export var pitch_deg := 70.0
@export var top_margin := 0.085      # fraction of screen used by the top HUD
@export var bottom_margin := 0.24    # fraction of screen used by the card panel
@export var side_margin := 0.01

var _base: Transform3D
var _shake_t := 0.0
var _shake_amp := 0.0
var _shake_len := 0.0
var _zoom := 1.0

func _ready() -> void:
	fov = 42.0
	near = 0.5
	far = 200.0
	get_viewport().size_changed.connect(fit)
	fit()

func fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(0, sin(pitch), cos(pitch))  # from target toward camera
	var hw := ArenaLayout.HALF_W + 0.6
	var hl := ArenaLayout.HALF_L + 0.6
	var corners := [Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(-hw, 0, hl), Vector3(hw, 0, hl),
		Vector3(-hw, 2.8, -hl + 1.5), Vector3(hw, 2.8, -hl + 1.5)]
	var zc := 0.0
	var dist := 30.0
	# iterate: binary search distance, then recentre vertically
	for _iter in 4:
		var lo := 8.0
		var hi := 120.0
		for _i in 30:
			var mid := (lo + hi) * 0.5
			if _fits(corners, dir, zc, mid, vp):
				hi = mid
			else:
				lo = mid
		dist = hi
		zc = _recenter(corners, dir, zc, dist, vp)
	global_transform = _make_xform(dir, zc, dist / _zoom)
	_base = global_transform

func _make_xform(dir: Vector3, zc: float, dist: float) -> Transform3D:
	var target := Vector3(0, 0, zc)
	var xf := Transform3D(Basis(), target + dir * dist)
	return xf.looking_at(target, Vector3.UP)

func _project(p: Vector3, xf: Transform3D, vp: Vector2) -> Vector2:
	var local := xf.affine_inverse() * p
	var f := 1.0 / tan(deg_to_rad(fov) * 0.5)
	var aspect := vp.x / vp.y
	var ndc := Vector2(local.x / -local.z * f / aspect, local.y / -local.z * f)
	return Vector2((ndc.x * 0.5 + 0.5), (0.5 - ndc.y * 0.5))

func _fits(corners: Array, dir: Vector3, zc: float, dist: float, vp: Vector2) -> bool:
	var xf := _make_xform(dir, zc, dist)
	for c: Vector3 in corners:
		var s := _project(c, xf, vp)
		if s.x < side_margin or s.x > 1.0 - side_margin or s.y < top_margin or s.y > 1.0 - bottom_margin:
			return false
	return true

func _recenter(corners: Array, dir: Vector3, zc: float, dist: float, vp: Vector2) -> float:
	var xf := _make_xform(dir, zc, dist)
	var min_y := INF
	var max_y := -INF
	for c: Vector3 in corners:
		var s := _project(c, xf, vp)
		min_y = minf(min_y, s.y)
		max_y = maxf(max_y, s.y)
	var want_mid := (top_margin + 1.0 - bottom_margin) * 0.5
	var mid := (min_y + max_y) * 0.5
	# shift target along z: moving target +z moves the arena up on screen
	return zc + (mid - want_mid) * dist * 0.9

func shake(amplitude: float, duration: float) -> void:
	_shake_amp = maxf(_shake_amp, amplitude)
	_shake_len = maxf(duration, 0.01)
	_shake_t = duration

func _process(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		var k := clampf(_shake_t / _shake_len, 0, 1)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_amp * k
		global_transform = _base.translated_local(off)
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			global_transform = _base
