@tool
class_name GLBMonsterModel
extends MonsterModel
## Rigged Meshy AI character (GLB) driven like the procedural models.
## Animations come from <id>_anims.res (AnimationLibrary built by
## Tools/MeshyImport.tscn): idle, walk, run, attack, hit, death, select.
## Weapons the generator left out are attached to the hand bones.

## Visual setup per monster: height in metres (before UNIT_VISUAL_SCALE),
## yaw correction, attack impact moment, whether it hovers.
const SETUP := {
	&"fire_knight": {"height": 1.5, "impact": 0.52, "attack_len": 0.95},
	&"shadow_assassin": {"height": 1.4, "impact": 0.38, "attack_len": 0.55, "run": true},
	&"stone_golem": {"height": 2.15, "impact": 0.6, "attack_len": 1.5},
	&"frost_dragon": {"height": 1.3, "impact": 0.55, "attack_len": 0.8, "fly": true},
	&"poison_witch": {"height": 1.6, "impact": 0.58, "attack_len": 0.9},
}

var glb_path := ""
var monster_id: StringName = &""
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _meshes_glb: Array[MeshInstance3D] = []
var _current := ""
var _last_attack_t := -1.0
var _hit_anim_t := 99.0
var _setup: Dictionary = {}
var _anim_len := {}

func _init() -> void:
	batch_meshes = false
	procedural_death = false

func build() -> void:
	_setup = SETUP.get(monster_id, {"height": 1.3, "impact": 0.5, "attack_len": 0.8})
	impact_at = _setup.impact
	attack_anim_len = _setup.attack_len
	select_len = 2.2
	death_len = 1.6
	var packed: PackedScene = load(glb_path)
	if packed == null:
		push_error("GLBMonsterModel: cannot load " + glb_path)
		return
	var holder := pivot("glb", null, Vector3.ZERO)
	var inst := packed.instantiate()
	holder.add_child(inst)
	_player = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_meshes_glb.append(mi)
		mi.extra_cull_margin = 1.0
		_add_outline(mi)
	# animations
	var lib_path := glb_path.replace("_rigged.glb", "_anims.res")
	if _player and ResourceLoader.exists(lib_path):
		var lib: AnimationLibrary = load(lib_path)
		_player.add_animation_library(&"m", lib)
		for a in lib.get_animation_list():
			_anim_len[String(a)] = lib.get_animation(a).length
	# normalise size: Meshy rigs are exported at 1.3 m, scale to the design height
	var h := _measure_height(inst)
	if h > 0.01:
		holder.scale = Vector3.ONE * (float(_setup.height) / h)
	holder.rotation_degrees.y = 180.0   # Meshy characters face +Z, the game uses -Z
	_add_weapons()

func _measure_height(inst: Node) -> float:
	var top := 0.0
	for mi: MeshInstance3D in _meshes_glb:
		var aabb := mi.get_aabb()
		var xf := _relative(mi, inst)
		top = maxf(top, (xf * aabb).end.y)
	# skinned meshes report the bind-pose AABB in mesh space (already metres)
	return top if top > 0.0 else 1.3

func _relative(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	# Meshy's Armature node scales by 0.01 while the mesh data is in metres
	return Transform3D(Basis.IDENTITY, xf.origin) if xf.basis.get_scale().x < 0.05 else xf

func _add_outline(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if m is BaseMaterial3D:
			var dup := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			var o := StandardMaterial3D.new()
			o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			o.albedo_color = OUTLINE_COLOR
			o.cull_mode = BaseMaterial3D.CULL_FRONT
			o.grow = true
			o.grow_amount = 0.012
			dup.next_pass = o
			dup.rim_enabled = true
			dup.rim = 0.15
			mi.set_surface_override_material(s, dup)

## Weapon props on the hand bones (Meshy drops held items in A-pose).
func _add_weapons() -> void:
	if _skeleton == null:
		return
	match monster_id:
		&"fire_knight":
			var w := _hand(&"RightHand")
			if w:
				add_mesh("", w, cyl(0.03, 0.03, 0.22, 8), mat(Color("#5a3220"), 0.8), Vector3(0, 0.0, 0), Vector3(0, 0, 0))
				add_mesh("", w, box(Vector3(0.3, 0.05, 0.06)), mat(Color("#f2b632"), 0.3, 0, 0.7), Vector3(0, 0.12, 0))
				add_mesh("", w, box(Vector3(0.17, 0.85, 0.045)), mat(Color("#ff6a10"), 0.25, 0.6, 0.2), Vector3(0, 0.56, 0))
				add_mesh("", w, prism(Vector3(0.17, 0.16, 0.045)), mat(Color("#ff6a10"), 0.25, 0.6, 0.2), Vector3(0, 1.05, 0))
				add_mesh("", w, box(Vector3(0.04, 0.75, 0.04)), glow_mat(Color(1, 0.95, 0.6), 1.3), Vector3(0, 0.55, 0))
				var fire := add_particles("sword_fire", w, Color(1, 0.55, 0.12), 22, 0.45, 0.16, Vector3(0, 1.2, 0), 30.0, 0.1, false)
				fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				fire.emission_box_extents = Vector3(0.05, 0.4, 0.02)
				fire.position = Vector3(0, 0.6, 0)
		&"shadow_assassin":
			for side: StringName in [&"RightHand", &"LeftHand"]:
				var w := _hand(side)
				if w:
					add_mesh("", w, cyl(0.02, 0.02, 0.12, 6), mat(Color("#3a2a20"), 0.8), Vector3(0, 0.02, 0))
					add_mesh("", w, prism(Vector3(0.09, 0.38, 0.025)), mat(Color("#9b5cff"), 0.2, 0.5, 0.4), Vector3(0, 0.27, 0))
		&"poison_witch":
			var w := _hand(&"RightHand")
			if w:
				add_mesh("", w, cyl(0.025, 0.03, 1.0, 8), mat(Color("#6b4226"), 0.8), Vector3(0, 0.15, 0))
				var orb := pivot("orb", w, Vector3(0, 0.7, 0))
				add_mesh("orb_core", orb, sphere(0.09, -1, 12), glow_mat(Color("#7dff3a"), 1.5), Vector3.ZERO)
				add_mesh("", orb, sphere(0.13, -1, 12), glow_mat(Color(0.5, 1.0, 0.3), 0.7, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
				add_particles("orb_fx", orb, Color("#7dff3a"), 12, 0.8, 0.09, Vector3(0, 0.6, 0), 50.0, 0.08)
		&"frost_dragon":
			add_particles("frost", parts["glb"], Color(0.7, 0.95, 1.0), 10, 1.0, 0.1, Vector3(0, -0.6, 0), 60.0, 0.3)
		&"stone_golem":
			pass

## Creates a BoneAttachment on a hand and returns a node in metre scale.
func _hand(bone: StringName) -> Node3D:
	var idx := _skeleton.find_bone(bone)
	if idx < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	_skeleton.add_child(att)
	var n := Node3D.new()
	att.add_child(n)
	# the armature is scaled 0.01; _ready() rescales this holder to metres
	n.set_meta("needs_rescale", true)
	return n

func _ready() -> void:
	super._ready()
	# rescale weapon holders now that global transforms are valid
	if _skeleton:
		for att in _skeleton.get_children():
			if att is BoneAttachment3D:
				for n in att.get_children():
					if n.has_meta("needs_rescale"):
						var gs: float = (att as Node3D).global_transform.basis.get_scale().x
						var model_s: float = global_transform.basis.get_scale().x
						(n as Node3D).scale = Vector3.ONE * (model_s / maxf(gs, 0.00001))
						_rest[n] = (n as Node3D).transform

func get_muzzle_position() -> Vector3:
	if parts.has("orb"):
		return (parts["orb"] as Node3D).global_position
	if _skeleton and monster_id == &"frost_dragon":
		var i := _skeleton.find_bone(&"Head")
		if i >= 0:
			return _skeleton.to_global(_skeleton.get_bone_global_pose(i).origin)
	return global_position + Vector3(0, 0.9 * global_transform.basis.get_scale().y, 0)

func _play(anim: String, speed := 1.0, restart := false, blend := 0.15) -> void:
	if _player == null:
		return
	var full := "m/" + anim
	if not _player.has_animation(full):
		return
	if full != _current or restart:
		_current = full
		_player.play(full, blend, speed)
		if restart:
			_player.seek(0.0, true)
	else:
		_player.speed_scale = 1.0
		_player.set_speed_scale(1.0)

func pose(dt: float) -> void:
	_hit_anim_t += dt
	if bool(_setup.get("fly", false)):
		off("glb", Vector3(0, sin(t * 2.2) * 0.08, 0))
		rot("glb", Vector3(-12.0 * move_blend, 0, sin(t * 1.3) * 4.0))
	if death_t >= 0.0:
		_play("death", float(_anim_len.get("death", 1.6)) / death_len)
		return
	var p := attack_progress()
	if p >= 0.0:
		var new_attack := attack_t < _last_attack_t or _current != "m/attack"
		_last_attack_t = attack_t
		var speed := float(_anim_len.get("attack", 1.0)) / attack_len
		_play("attack", speed, new_attack, 0.08)
		return
	_last_attack_t = -1.0
	if select_t >= 0.0:
		_play("select", float(_anim_len.get("select", 2.0)) / select_len)
		return
	if hit_t < 0.05 and _hit_anim_t > 0.6 and not moving:
		_hit_anim_t = 0.0
		_play("hit", 1.6, true, 0.05)
		return
	if _current == "m/hit" and _hit_anim_t < 0.45:
		return
	if moving and not bool(_setup.get("fly", false)):
		var clip := "run" if bool(_setup.get("run", false)) else "walk"
		_play(clip, move_speed_factor * clampf(walk_rate, 0.6, 2.0))
	else:
		_play("idle")
	if parts.has("orb_core"):
		scl("orb_core", Vector3.ONE * (1.0 + sin(t * 5.0) * 0.08))

func overlay_targets() -> Array:
	return _meshes_glb
