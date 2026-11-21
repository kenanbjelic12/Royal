class_name MonsterFactory
extends RefCounted
## Creates the visual model for a monster. Prefers an imported GLB (e.g. from
## Meshy) when `model_glb_path` points to an existing file, otherwise uses the
## procedural stylised model script.

static func create_model(data: MonsterData) -> MonsterModel:
	if data.model_glb_path != "" and ResourceLoader.exists(data.model_glb_path):
		var m := GLBMonsterModel.new()
		m.glb_path = data.model_glb_path
		return m
	if data.model_script:
		return data.model_script.new()
	push_warning("No model for %s, using placeholder" % data.id)
	return MonsterModel.new()
