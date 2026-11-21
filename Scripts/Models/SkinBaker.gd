class_name SkinBaker
extends RefCounted
## Converts a procedurally assembled rig (Node3D joints + many MeshInstance3D
## parts) into ONE skinned mesh per shadow mode, driven by a Skeleton3D whose
## bones mirror the joints. All parts that share a material become a single
## surface, so a monster costs ~a dozen draw calls instead of ~40 instances.
## Joints keep animating as plain Node3D; `sync()` copies their local
## transforms into the skeleton every frame.

var skeleton: Skeleton3D
var instances: Array[MeshInstance3D] = []
var bone_nodes: Array[Node3D] = []

## `root` holds the rig, `joints` are the animated nodes (pivots and named
## mesh parts). Returns false when nothing could be baked.
func bake(root: Node3D, joints: Array, extra_cull := 1.5) -> bool:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	var bone_of := {}
	_add_bones(root, -1, joints, bone_of)
	if bone_nodes.is_empty():
		return false
	# gather mesh parts per (material, shadow) group
	var groups := {}   # shadow -> {material -> arrays}
	var to_free: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not (mi.material_override is BaseMaterial3D) or not (mi.mesh is PrimitiveMesh):
			continue
		var bone_node: Node3D = mi if bone_of.has(mi) else _bone_ancestor(mi, bone_of, root)
		var local := Transform3D.IDENTITY if bone_node == mi else _relative(mi, bone_node)
		var bone_idx: int = bone_of.get(bone_node, -1)
		if bone_idx < 0:
			continue
		var global_rest := skeleton.get_bone_global_rest(bone_idx) if skeleton.get_bone_count() > 0 else Transform3D.IDENTITY
		_append(groups, mi, global_rest * local, bone_idx)
		to_free.append(mi)
	if groups.is_empty():
		return false
	root.add_child(skeleton)
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	for shadow in groups:
		var mesh := ArrayMesh.new()
		for mat in groups[shadow]:
			var g: Dictionary = groups[shadow][mat]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = g.v
			arr[Mesh.ARRAY_NORMAL] = g.n
			arr[Mesh.ARRAY_TEX_UV] = g.uv
			arr[Mesh.ARRAY_BONES] = g.b
			arr[Mesh.ARRAY_WEIGHTS] = g.w
			arr[Mesh.ARRAY_INDEX] = g.i
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, g.mat)
		var inst := MeshInstance3D.new()
		inst.name = "Skinned%d" % shadow
		inst.mesh = mesh
		inst.skin = skin
		inst.cast_shadow = shadow
		inst.extra_cull_margin = extra_cull
		skeleton.add_child(inst)
		inst.skeleton = inst.get_path_to(skeleton)
		instances.append(inst)
	# the original parts are no longer drawn; named parts stay as joints
	for mi in to_free:
		if bone_of.has(mi):
			mi.mesh = null
			mi.material_overlay = null
		else:
			mi.get_parent().remove_child(mi)
			mi.queue_free()
	sync()
	return true

func _add_bones(node: Node3D, parent_idx: int, joints: Array, bone_of: Dictionary) -> void:
	for c in node.get_children():
		if not (c is Node3D) or c is CPUParticles3D or c == skeleton:
			continue
		var is_joint: bool = joints.has(c) or not (c is MeshInstance3D)
		if not is_joint:
			continue
		var idx := skeleton.add_bone("%s_%d" % [c.name, skeleton.get_bone_count()])
		skeleton.set_bone_parent(idx, parent_idx)
		skeleton.set_bone_rest(idx, (c as Node3D).transform)
		bone_of[c] = idx
		bone_nodes.append(c)
		_add_bones(c, idx, joints, bone_of)

func _bone_ancestor(n: Node, bone_of: Dictionary, root: Node3D) -> Node3D:
	var cur := n.get_parent()
	while cur != null and cur != root:
		if bone_of.has(cur):
			return cur
		cur = cur.get_parent()
	return null

func _relative(n: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _append(groups: Dictionary, mi: MeshInstance3D, xf: Transform3D, bone: int) -> void:
	var shadow := mi.cast_shadow
	if not groups.has(shadow):
		groups[shadow] = {}
	var mat: Material = mi.material_override
	if not groups[shadow].has(mat):
		groups[shadow][mat] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
			"b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var g: Dictionary = groups[shadow][mat]
	var src := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var uvs = src[Mesh.ARRAY_TEX_UV]
	var idx = src[Mesh.ARRAY_INDEX]
	var base: int = g.v.size()
	var nbasis := xf.basis.inverse().transposed()
	for k in verts.size():
		g.v.append(xf * verts[k])
		g.n.append((nbasis * norms[k]).normalized())
		g.uv.append(uvs[k] if uvs != null and k < uvs.size() else Vector2.ZERO)
		g.b.append_array([bone, 0, 0, 0])
		g.w.append_array([1.0, 0.0, 0.0, 0.0])
	if idx != null and idx.size() > 0:
		for k in idx.size():
			g.i.append(base + idx[k])
	else:
		for k in verts.size():
			g.i.append(base + k)

## Copies the joint transforms into the skeleton (call after posing).
func sync() -> void:
	for i in bone_nodes.size():
		var n := bone_nodes[i]
		if not is_instance_valid(n):
			continue
		var t := n.transform
		skeleton.set_bone_pose_position(i, t.origin)
		var s := t.basis.get_scale()
		skeleton.set_bone_pose_scale(i, s)
		skeleton.set_bone_pose_rotation(i, t.basis.orthonormalized().get_rotation_quaternion())

func set_overlay(mat: Material) -> void:
	for inst in instances:
		inst.material_overlay = mat
