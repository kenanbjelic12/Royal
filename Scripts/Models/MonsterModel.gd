@tool
class_name MonsterModel
extends Node3D
## Base class for all procedurally built, procedurally animated stylised monsters.
##
## Sub-classes implement `build()` (create the parts) and `pose(dt)` (offset the
## parts from their rest pose every frame). Every frame the parts are reset to
## their rest transform first, so poses are layered additively and never drift.
##
## Animation states: idle, move, attack, hit (overlay), death, select (special).
## The controller listens to `impact` to apply damage at the exact strike frame.

signal impact
signal death_finished

const OUTLINE_COLOR := Color(0.09, 0.06, 0.12)

@export var outline_enabled := true
@export var outline_width := 0.022

var team_color := Color(0.25, 0.55, 1.0)
var t := 0.0
var moving := false
var move_blend := 0.0
var move_speed_factor := 1.0   # animation speed multiplier (slows show too)

var attack_t := -1.0
var attack_len := 0.8
var impact_at := 0.5
var _impact_sent := false

var hit_t := 99.0
## Length of the attack animation in seconds (shortened for fast attackers).
var attack_anim_len := 0.8
## Status colour overlay (slow = blue, poison = green). Alpha = strength.
var status_tint := Color(0, 0, 0, 0)
var death_t := -1.0
var death_len := 1.0
var select_t := -1.0
var select_len := 1.6

var parts: Dictionary = {}        # name -> Node3D
var _rest: Dictionary = {}        # Node3D -> Transform3D
var _mat_cache: Dictionary = {}
var _outline_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _root: Node3D               # everything is under this node (death/hit squash)

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Rig"
	add_child(_root)
	parts["root"] = _root
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.albedo_color = OUTLINE_COLOR
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.grow = true
	_outline_mat.grow_amount = outline_width
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	build()
	for p in parts.values():
		_rest[p] = p.transform
	_apply_pose(0.0)

func _process(delta: float) -> void:
	_apply_pose(delta)

## Override: create all parts with the helpers below.
func build() -> void:
	pass

## Override: animate parts. Use the state helpers (attack_progress() etc).
func pose(_dt: float) -> void:
	pass

## Override: world position where projectiles spawn.
func get_muzzle_position() -> Vector3:
	return global_position + Vector3(0, 0.9 * scale.y, 0)

# ---------------------------------------------------------------- controller API
func set_moving(v: bool) -> void:
	moving = v

func play_attack(duration: float, impact_fraction := -1.0) -> void:
	attack_t = 0.0
	attack_len = maxf(duration, 0.1)
	if impact_fraction > 0.0:
		impact_at = impact_fraction
	_impact_sent = false

func cancel_attack() -> void:
	attack_t = -1.0

func is_attacking() -> bool:
	return attack_t >= 0.0

func play_hit() -> void:
	hit_t = 0.0

func play_death() -> void:
	if death_t >= 0.0:
		return
	death_t = 0.0
	attack_t = -1.0
	select_t = -1.0

func play_select() -> void:
	select_t = 0.0

func is_dead_anim() -> bool:
	return death_t >= 0.0

# ---------------------------------------------------------------- state helpers
func attack_progress() -> float:
	return -1.0 if attack_t < 0.0 else clampf(attack_t / attack_len, 0.0, 1.0)

func select_progress() -> float:
	return -1.0 if select_t < 0.0 else clampf(select_t / select_len, 0.0, 1.0)

func death_progress() -> float:
	return -1.0 if death_t < 0.0 else clampf(death_t / death_len, 0.0, 1.0)

## Smooth anticipation -> strike -> recover curve. Returns 0..1 "swing" amount:
## 0 rest, rises to `-windup` before the strike (negative), +1 at impact.
static func swing_curve(p: float, strike: float) -> float:
	if p < 0.0:
		return 0.0
	var w := strike * 0.75
	if p < w:
		return -ease_out(p / w)
	if p < strike:
		return lerpf(-1.0, 1.0, ease_in((p - w) / (strike - w)))
	return lerpf(1.0, 0.0, ease_in_out((p - strike) / (1.0 - strike)))

static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0, 1), 3.0)

static func ease_in(x: float) -> float:
	return pow(clampf(x, 0, 1), 2.0)

static func ease_in_out(x: float) -> float:
	x = clampf(x, 0, 1)
	return x * x * (3.0 - 2.0 * x)

## Bell curve 0 -> 1 -> 0 over p in 0..1
static func bump(p: float) -> float:
	if p < 0.0 or p > 1.0:
		return 0.0
	return sin(p * PI)

func _apply_pose(delta: float) -> void:
	t += delta * move_speed_factor
	move_blend = move_toward(move_blend, 1.0 if moving else 0.0, delta * 6.0)
	if attack_t >= 0.0:
		attack_t += delta
		if not _impact_sent and attack_t >= attack_len * impact_at:
			_impact_sent = true
			impact.emit()
		if attack_t >= attack_len:
			attack_t = -1.0
	if select_t >= 0.0:
		select_t += delta
		if select_t >= select_len:
			select_t = -1.0
	hit_t += delta
	for p in _rest:
		if is_instance_valid(p):
			p.transform = _rest[p]
	pose(delta)
	_post_pose(delta)

func _post_pose(delta: float) -> void:
	# hit: squash + white flash
	var flash := 0.0
	if hit_t < 0.25:
		var k := 1.0 - hit_t / 0.25
		flash = k * 0.75
		var sq := 1.0 - 0.12 * k
		_root.scale *= Vector3(1.0 + (1.0 - sq) * 0.7, sq, 1.0 + (1.0 - sq) * 0.7)
	if flash > 0.01:
		_flash_mat.albedo_color = Color(1, 1, 1, flash)
	else:
		_flash_mat.albedo_color = status_tint
	# death: hop, tip over, shrink
	if death_t >= 0.0:
		death_t += delta
		var p := death_progress()
		_root.position.y += bump(minf(p * 2.0, 1.0)) * 0.35
		_root.rotation.x += ease_in_out(p * 1.4) * 1.3
		var s := 1.0 - ease_in(clampf((p - 0.45) / 0.55, 0, 1))
		_root.scale *= maxf(s, 0.001)
		if death_t >= death_len and death_t - delta < death_len:
			death_finished.emit()

# ---------------------------------------------------------------- build helpers
func mat(color: Color, roughness := 0.65, emission := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, emission, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.45
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	# Godot's rim widens with roughness, so keep it subtle on rough surfaces
	m.rim_enabled = true
	m.rim = 0.2 if roughness < 0.75 else 0.06
	m.rim_tint = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if outline_enabled:
		m.next_pass = _outline_mat
	_mat_cache[key] = m
	return m

## Unlit glowing material without outline (eyes highlights, magic, fire).
func glow_mat(color: Color, energy := 1.5, alpha := 1.0) -> StandardMaterial3D:
	var key := "glow|%s|%.2f|%.2f" % [color.to_html(), energy, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cache[key] = m
	return m

## Creates an empty pivot (joint) node.
func pivot(pname: String, parent: Node3D, pos: Vector3, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = pos
	n.rotation_degrees = rot_deg
	(parent if parent else _root).add_child(n)
	parts[pname] = n
	return n

func add_mesh(pname: String, parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if pname != "":
		mi.name = pname
	mi.mesh = mesh
	mi.material_override = material
	mi.material_overlay = _flash_mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _root).add_child(mi)
	if pname != "":
		parts[pname] = mi
	_meshes.append(mi)
	return mi

func sphere(r: float, h := -1.0, seg := 24) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = (r * 2.0) if h < 0.0 else h
	m.radial_segments = seg
	m.rings = maxi(seg / 2, 6)
	return m

func capsule(r: float, h: float, seg := 16) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = seg
	m.rings = 6
	return m

func cyl(top: float, bottom: float, h: float, seg := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func torus(inner: float, outer: float, seg := 24) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = seg
	m.ring_segments = 10
	return m

func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m

## Big cartoon eye: white sclera, coloured iris, pupil and two highlights.
## `pos` is on the face surface, the eye looks along -Z of `parent`.
func add_eye(pname: String, parent: Node3D, pos: Vector3, r: float, iris: Color, glow := false) -> Node3D:
	var e := pivot(pname, parent, pos)
	if glow:
		add_mesh("", e, sphere(r, r * 2.1, 16), glow_mat(iris, 1.6), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55), false)
		add_mesh("", e, sphere(r * 0.38, -1, 10), glow_mat(Color(1, 1, 1), 1.4), Vector3(-r * 0.25, r * 0.3, -r * 0.42), Vector3.ZERO, Vector3.ONE, false)
		return e
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1, 1, 1)
	white.roughness = 0.25
	white.rim_enabled = true
	white.rim = 0.2
	if outline_enabled:
		white.next_pass = _outline_mat
	add_mesh("", e, sphere(r, r * 2.2, 18), white, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.62), false)
	add_mesh("", e, sphere(r * 0.66, -1, 14), mat(iris, 0.3), Vector3(0, -r * 0.05, -r * 0.4), Vector3.ZERO, Vector3(1, 1.08, 0.5), false)
	add_mesh("", e, sphere(r * 0.4, -1, 12), mat(Color(0.05, 0.04, 0.08), 0.2), Vector3(0, -r * 0.05, -r * 0.55), Vector3.ZERO, Vector3(1, 1.1, 0.4), false)
	add_mesh("", e, sphere(r * 0.2, -1, 8), glow_mat(Color(1, 1, 1), 1.0), Vector3(-r * 0.22, r * 0.25, -r * 0.66), Vector3.ZERO, Vector3.ONE, false)
	add_mesh("", e, sphere(r * 0.09, -1, 6), glow_mat(Color(1, 1, 1), 1.0), Vector3(r * 0.2, -r * 0.25, -r * 0.66), Vector3.ZERO, Vector3.ONE, false)
	return e

# ---------------------------------------------------------------- pose helpers
func rot(pname: String, deg: Vector3) -> void:
	var p: Node3D = parts.get(pname)
	if p:
		p.rotation_degrees += deg

func off(pname: String, v: Vector3) -> void:
	var p: Node3D = parts.get(pname)
	if p:
		p.position += v

func scl(pname: String, s: Vector3) -> void:
	var p: Node3D = parts.get(pname)
	if p:
		p.scale *= s

## Particle emitter helper (CPU particles work on every renderer / Android).
func add_particles(pname: String, parent: Node3D, color: Color, amount := 16, lifetime := 0.6, size := 0.08, velocity := Vector3(0, 1, 0), spread := 25.0, emission_radius := 0.05, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = pname
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = VFX.soft_dot_texture()
	qm.material = m
	p.mesh = qm
	p.direction = velocity.normalized() if velocity.length() > 0 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = velocity.length() * 0.6
	p.initial_velocity_max = velocity.length()
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = emission_radius
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g.add_point(0.5, Color(color.r * 0.95, color.g * 0.55, color.b * 0.4, 0.8))
	g.set_color(g.get_point_count() - 1, Color(color.r * 0.6, color.g * 0.25, color.b * 0.25, 0.0))
	p.color_ramp = g
	(parent if parent else _root).add_child(p)
	parts[pname] = p
	return p
