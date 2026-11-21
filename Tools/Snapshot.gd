extends Node
## QA tool: runs a real battle (AI on both sides) and saves screenshots.
## Usage: godot --path . res://Tools/Snapshot.tscn -- out=/tmp/x times=5,20,40 scale=2 size=720x1280 [select=2] [scene=res://...]

var out_dir := "user://snapshots"
var times: Array[float] = [3.0]
var sim_scale := 1.0
var select_card := -1
var scene_path := "res://Scenes/Battle/Battle.tscn"
var player_ai := true

func _ready() -> void:
	var size := Vector2i(720, 1280)
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"out": out_dir = kv[1]
			"times":
				times.clear()
				for t in kv[1].split(","):
					times.append(float(t))
			"scale": sim_scale = float(kv[1])
			"select": select_card = int(kv[1])
			"scene": scene_path = kv[1]
			"playerai": player_ai = kv[1] == "1"
			"size":
				var wh := kv[1].split("x")
				size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	EconomyManager.persist = false
	get_window().size = size
	get_window().content_scale_size = Vector2i(720, 1280) if size.x < size.y else Vector2i(1280, 720)
	await get_tree().process_frame
	var scene: Node = load(scene_path).instantiate()
	if scene is BattleManager:
		scene.player_ai_controlled = player_ai and select_card < 0
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = sim_scale
	var elapsed := 0.0
	var idx := 0
	var tag := scene_path.get_file().get_basename()
	while idx < times.size():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed >= times[idx]:
			if select_card >= 0 and scene is BattleManager:
				var b: BattleManager = scene
				b.card_manager.select(select_card)
				var vp := get_viewport().get_visible_rect().size
				b.card_manager.update_hover(Vector2(vp.x * 0.35, vp.y * 0.55))
				for i in 20:
					await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var f := "%s/%s_%dx%d_t%03d.png" % [out_dir, tag, size.x, size.y, int(times[idx])]
			img.save_png(f)
			print("saved ", f)
			idx += 1
	get_tree().quit()
