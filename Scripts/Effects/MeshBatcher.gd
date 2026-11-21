class_name MeshBatcher
extends RefCounted
## Static batching: merges many small MeshInstance3D nodes that share a
## material into one mesh per (material, shadow) group. Cuts draw calls by an
## order of magnitude for procedurally assembled scenery and models.

## Merges every eligible MeshInstance3D below `root` (any depth) into meshes
## parented to `root`. Use for fully static scenery.
static func bake_tree(root: Node3D, exclude: Array = []) -> int:
	var groups := {}
	var removed := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if exclude.has(mi) or not _eligible(mi):
			continue
		var xf := _relative_xform(mi, root)
		_append(groups, mi, xf)
		mi.get_parent().remove_child(mi)
		mi.queue_free()
		removed += 1
	_commit(groups, root, null)
	return removed

## Merges the direct mesh children of `parent` that are not in `keep`
## (named/animated parts). Recurses into child pivots. Use for rigs.
static func bake_children(parent: Node3D, keep: Array, overlay: Material = null) -> void:
	var groups := {}
	for c in parent.get_children():
		if c is MeshInstance3D and not keep.has(c) and _eligible(c) and c.get_child_count() == 0:
			_append(groups, c, (c as MeshInstance3D).transform)
			parent.remove_child(c)
			c.queue_free()
	_commit(groups, parent, overlay)
	for c in parent.get_children():
		if c is Node3D and not c.has_meta("batched"):
			bake_children(c, keep, overlay)

static func _eligible(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or not (mi.material_override is StandardMaterial3D) or not mi.visible:
		return false
	if mi.has_meta("batched"):
		return false
	return mi.mesh is PrimitiveMesh

static func _relative_xform(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

static func _append(groups: Dictionary, mi: MeshInstance3D, xf: Transform3D) -> void:
	var key := "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
	if not groups.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[key] = {"st": st, "mat": mi.material_override, "shadow": mi.cast_shadow}
	(groups[key].st as SurfaceTool).append_from(mi.mesh, 0, xf)

static func _commit(groups: Dictionary, parent: Node3D, overlay: Material) -> void:
	for key in groups:
		var g: Dictionary = groups[key]
		var mesh: ArrayMesh = (g.st as SurfaceTool).commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = g.mat
		if overlay:
			mi.material_overlay = overlay
		mi.cast_shadow = g.shadow
		mi.set_meta("batched", true)
		parent.add_child(mi)
