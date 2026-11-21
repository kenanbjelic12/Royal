extends Node
## Builds res://Assets/Monsters/<id>/<id>_anims.res (an AnimationLibrary) from
## the Meshy animation GLBs, so the game only ships the rigged character plus
## a few hundred KB of animation data.
## Usage: godot --headless --path . res://Tools/MeshyImport.tscn

const CLIPS := {
	"idle": ["anim_idle.glb", true],
	"walk": ["anim_walking_armature.glb", true],
	"run": ["anim_running_armature.glb", true],
	"attack": ["anim_attack.glb", false],
	"hit": ["anim_hit.glb", false],
	"death": ["anim_death.glb", false],
	"select": ["anim_select.glb", false],
}

func _ready() -> void:
	for id in ["fire_knight", "shadow_assassin", "stone_golem", "frost_dragon", "poison_witch"]:
		var dir: String = "res://Assets/Monsters/%s/" % id
		var lib := AnimationLibrary.new()
		for clip in CLIPS:
			var path: String = dir + CLIPS[clip][0]
			if not ResourceLoader.exists(path):
				print(id, " missing ", clip)
				continue
			var scn: Node = load(path).instantiate()
			var ap: AnimationPlayer = scn.find_child("AnimationPlayer", true, false)
			var src := ap.get_animation(ap.get_animation_list()[0])
			var a: Animation = src.duplicate(true)
			a.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip][1] else Animation.LOOP_NONE
			# keep the character in place: drop horizontal root motion of the hips
			for t in a.get_track_count():
				if String(a.track_get_path(t)).ends_with(":Hips") and a.track_get_type(t) == Animation.TYPE_POSITION_3D and clip != "death":
					for k in a.track_get_key_count(t):
						var v: Vector3 = a.track_get_key_value(t, k)
						a.track_set_key_value(t, k, Vector3(0.0, v.y, 0.0))
			lib.add_animation(clip, a)
			scn.free()
		var out: String = dir + id + "_anims.res"
		ResourceSaver.save(lib, out)
		print(id, " -> ", out, " clips=", lib.get_animation_list())
	get_tree().quit()
