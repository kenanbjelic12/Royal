extends Control
## QA: renders each 3D chest closed, shaking and open into one contact sheet.
## godot --path . res://Tools/ChestShot.tscn -- out=/tmp/chests.png

func _ready() -> void:
	var out := "user://chests.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var views: Array[ChestView] = []
	for i in 3:
		var t: String = ["gold", "rare", "epic"][i]
		var v := ChestView.make(t, true)
		v.position = Vector2(i * 240, 0)
		v.size = Vector2(240, 220)
		add_child(v)
		views.append(v)
	await get_tree().create_timer(0.6).timeout
	var shots: Array[Image] = []
	shots.append(get_viewport().get_texture().get_image())
	for v in views:
		v.open()
	await get_tree().create_timer(0.25).timeout
	shots.append(get_viewport().get_texture().get_image())
	await get_tree().create_timer(1.0).timeout
	shots.append(get_viewport().get_texture().get_image())
	var sheet := Image.create(720, 660, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 720, 220), Vector2i(0, i * 220))
	sheet.save_png(out)
	get_tree().quit()
