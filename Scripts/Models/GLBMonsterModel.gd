@tool
class_name GLBMonsterModel
extends MonsterModel
## Wraps an imported rigged GLB (Meshy / Blender export) so it can be used
## exactly like a procedural model. Expected animation names (case-insensitive,
## partial match): Idle, Walk|Run|Fly, Attack|Cast, Hit, Death, Select|Taunt.

var glb_path := ""
var _player: AnimationPlayer
var _current := ""

func build() -> void:
	var packed: PackedScene = load(glb_path)
	if packed == null:
		push_error("GLBMonsterModel: cannot load " + glb_path)
		return
	var inst := packed.instantiate()
	_root.add_child(inst)
	_player = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _find_anim(keys: Array) -> String:
	if _player == null:
		return ""
	for k in keys:
		for a in _player.get_animation_list():
			if String(a).to_lower().contains(k):
				return a
	return ""

func _play(keys: Array, speed := 1.0) -> void:
	var a := _find_anim(keys)
	if a != "" and a != _current:
		_current = a
		_player.play(a, 0.15, speed)

func pose(_dt: float) -> void:
	if death_t >= 0.0:
		_play(["death", "die"])
	elif attack_t >= 0.0:
		_play(["attack", "cast"])
	elif select_t >= 0.0:
		_play(["select", "taunt", "cheer"])
	elif moving:
		_play(["walk", "run", "fly"])
	else:
		_play(["idle", "fly"])
