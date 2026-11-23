extends Node
## QA: plays a battle, destroys the enemy king, screenshots the end screen,
## presses its buttons and reports where it lands.
## godot --path . res://Tools/EndFlowCheck.tscn -- out=/tmp/x [lose]

var out := "user://endflow"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var lose := OS.get_cmdline_user_args().has("lose")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var battle: Node = load("res://Scenes/Battle/Battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	await get_tree().create_timer(3.0).timeout
	battle = battle.get_node(".") if battle.has_method("get_towers") else battle.find_children("*", "", true, false).filter(func(n): return n.has_method("get_towers"))[0]
	print("scene: ", battle.name)
	if OS.get_cmdline_user_args().has("pocket"):
		for t in battle.get_towers(1):
			if t.kind == &"princess" and t.lane == -1:
				t.take_damage(99999.0)
		await get_tree().create_timer(2.5).timeout
		battle.card_manager.select(0)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(out + "/pocket.png")
		get_tree().quit()
		return
	for t in battle.get_towers(0 if lose else 1):
		if t.kind == &"king":
			t.take_damage(99999.0)
	for i in 5:
		await get_tree().create_timer(1.0).timeout
		print("t+%d finished=%s paused=%s fps=%d" % [i, battle.is_finished(), get_tree().paused, Engine.get_frames_per_second()])
	get_viewport().get_texture().get_image().save_png(out + "/end.png")
	var btns: Array = []
	_collect(get_tree().root, btns)
	for b: BaseButton in btns:
		print("button: ", b.name, " text=", b.get("text"), " visible=", b.is_visible_in_tree())
	get_tree().quit()

func _collect(n: Node, acc: Array) -> void:
	if n is BaseButton and (n as BaseButton).is_visible_in_tree():
		acc.append(n)
	for c in n.get_children():
		_collect(c, acc)
