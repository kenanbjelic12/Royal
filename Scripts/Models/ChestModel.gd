class_name ChestModel
extends Node3D
## 3D reward chest built from the Meshy model (Assets/Chests/<type>_chest/).
## The lid is cut off the single Meshy mesh at runtime (triangles above the
## seam height) so it can swing open on a hinge at the back. Falls back to
## nothing visible if the model is missing (callers keep a 2D icon then).
##
## Animations: idle bob, shake (anticipation), open (lid swings with
## overshoot, light pours out, sparkles burst), close.

const SPEC := {
	# seam: lid cut height (fraction of model height); glow: light colour
	"gold": {"seam": 0.56, "glow": Color(1.0, 0.82, 0.35)},
	"rare": {"seam": 0.56, "glow": Color(0.35, 0.85, 1.0)},
	"epic": {"seam": 0.56, "glow": Color(0.95, 0.4, 1.0)},
}
const HEIGHT := 1.0

static var _cache: Dictionary = {}   # type -> {body, lid, size, hinge}

var type := "gold"
var ok := false
var opened := false
var _pivot: Node3D       # bobbing / shaking root
var _lid_hinge: Node3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _t := 0.0
var _shake := 0.0
var _lid_angle := 0.0

static func model_path(p_type: String) -> String:
	return "res://Assets/Chests/%s_chest/%s_chest_static.glb" % [p_type, p_type]

static func has_model(p_type: String) -> bool:
	return ResourceLoader.exists(model_path(p_type))

func _ready() -> void:
	var parts := _parts(type)
	if parts.is_empty():
		return
	ok = true
	var spec: Dictionary = SPEC.get(type, SPEC.gold)
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := MeshInstance3D.new()
	body.mesh = parts.body
	_pivot.add_child(body)
	_lid_hinge = Node3D.new()
	_lid_hinge.position = parts.hinge
	_pivot.add_child(_lid_hinge)
	var lid := MeshInstance3D.new()
	lid.mesh = parts.lid
	lid.position = -parts.hinge
	_lid_hinge.add_child(lid)
	# light inside the chest, only visible once the lid lifts
	var size: Vector3 = parts.size
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = VFX.soft_dot_texture()
	gm.albedo_color = Color(spec.glow.r * 1.4, spec.glow.g * 1.4, spec.glow.b * 1.4, 1.0)
	var quad := PlaneMesh.new()
	quad.size = Vector2(size.x * 1.1, size.z * 1.0)
	_glow = MeshInstance3D.new()
	_glow.mesh = quad
	_glow.material_override = gm
	_glow.position = Vector3(0, parts.hinge.y - 0.02, 0)
	_glow.visible = false
	_pivot.add_child(_glow)
	# soft beam of light rising out of the chest
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(spec.glow.r, spec.glow.g, spec.glow.b, 0.22)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = size.x * 0.55
	beam_mesh.bottom_radius = size.x * 0.3
	beam_mesh.height = 1.4
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = bm
	beam.position = Vector3(0, parts.hinge.y + 0.7, 0)
	beam.scale = Vector3(1, 1, 0.6)
	_glow.add_child(beam)
	beam.position = Vector3(0, 0.7, 0)
	_light = OmniLight3D.new()
	_light.light_color = spec.glow
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, parts.hinge.y + 0.3, 0)
	_pivot.add_child(_light)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 60
	_sparks.lifetime = 1.4
	_sparks.explosiveness = 0.85
	var sq := QuadMesh.new()
	sq.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = VFX.star_texture()
	sq.material = sm
	_sparks.mesh = sq
	_sparks.direction = Vector3.UP
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.2
	_sparks.gravity = Vector3(0, -3.5, 0)
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, spec.glow.lightened(0.5))
	g.set_color(1, Color(spec.glow.r, spec.glow.g, spec.glow.b, 0.0))
	_sparks.color_ramp = g
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(size.x * 0.3, 0.05, size.z * 0.25)
	_sparks.position = Vector3(0, parts.hinge.y, 0)
	_pivot.add_child(_sparks)

## Splits the Meshy mesh into body + lid once per chest type.
static func _parts(p_type: String) -> Dictionary:
	if _cache.has(p_type):
		return _cache[p_type]
	if not has_model(p_type):
		return {}
	var scene: Node = (load(model_path(p_type)) as PackedScene).instantiate()
	var mis := scene.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		scene.free()
		return {}
	var mi: MeshInstance3D = mis[0]
	var src := mi.mesh
	var xf := mi.global_transform if mi.is_inside_tree() else _scene_xform(mi, scene)
	var aabb := xf * src.get_aabb()
	var s := HEIGHT / maxf(aabb.size.y, 0.001)
	var center := aabb.get_center()
	# normalise: bottom on y=0, centred, height HEIGHT
	var norm := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-center.x * s, -aabb.position.y * s, -center.z * s)) * xf
	var seam: float = float(SPEC.get(p_type, SPEC.gold).seam) * HEIGHT
	var body_st := SurfaceTool.new()
	var lid_st := SurfaceTool.new()
	body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	lid_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	var back_z := INF   # front faces +Z, hinge at the back (min z)
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		mat = mi.get_active_material(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var nb := norm.basis.orthonormalized()
		for t in range(0, idx.size(), 3):
			var p := [norm * verts[idx[t]], norm * verts[idx[t + 1]], norm * verts[idx[t + 2]]]
			var cy: float = (p[0].y + p[1].y + p[2].y) / 3.0
			var st := lid_st if cy > seam else body_st
			for k in 3:
				var vi := idx[t + k]
				if not norms.is_empty():
					st.set_normal(nb * norms[vi])
				if not uvs.is_empty():
					st.set_uv(uvs[vi])
				st.add_vertex(p[k])
				if cy > seam and absf(p[k].y - seam) < 0.08:
					back_z = minf(back_z, p[k].z)
	body_st.set_material(mat)
	lid_st.set_material(mat)
	var size := aabb.size * s
	if back_z == INF:
		back_z = -size.z * 0.5
	var out := {"body": body_st.commit(), "lid": lid_st.commit(), "size": size, "hinge": Vector3(0, seam, back_z)}
	scene.free()
	_cache[p_type] = out
	return out

static func _scene_xform(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

func _process(delta: float) -> void:
	if not ok:
		return
	_t += delta
	_shake = maxf(0.0, _shake - delta)
	var bob := 0.0 if opened else sin(_t * 2.2) * 0.03
	_pivot.position = Vector3(0, bob, 0)
	if _shake > 0.0:
		var k := _shake * 6.0
		_pivot.rotation = Vector3(0, sin(_t * 47.0) * 0.06 * k, sin(_t * 61.0) * 0.08 * k)
		_lid_hinge.rotation.x = -absf(sin(_t * 38.0)) * 0.12 * k   # lid rattles
	else:
		_pivot.rotation = _pivot.rotation.lerp(Vector3(0, sin(_t * 0.8) * 0.12, 0), minf(1.0, delta * 5.0))
		_lid_hinge.rotation.x = _lid_angle

## Anticipation before opening.
func shake(duration := 0.7) -> void:
	_shake = duration

## Lid flies open with an overshoot, light pours out and sparkles burst.
func open() -> void:
	if not ok or opened:
		return
	opened = true
	_shake = 0.0
	_glow.visible = true
	_sparks.restart()
	_sparks.emitting = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(a: float): _lid_angle = a, 0.0, deg_to_rad(-118.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_light, "light_energy", 4.0, 0.15)
	tw.tween_property(_pivot, "scale", Vector3(1.12, 0.88, 1.12), 0.08)
	tw.chain().tween_property(_pivot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_light, "light_energy", 1.6, 0.6)

func close() -> void:
	opened = false
	_glow.visible = false
	_light.light_energy = 0.0
	_lid_angle = 0.0
