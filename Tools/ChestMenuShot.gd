extends Node
## QA: main menu with one chest of each type, then the opening popup.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	EconomyManager.persist = false
	EconomyManager.chests = [{"type": "gold", "unlock_at": -1}, {"type": "rare", "unlock_at": -1}, {"type": "epic", "unlock_at": 1}]
	var menu: Node = load("res://Scenes/MainMenu/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/menu_chests.png")
	menu._on_chest(2)
	await get_tree().create_timer(2.6).timeout
	var pp: Control = menu.ui.get_child(menu.ui.get_child_count() - 1)
	print("popup ", pp.name, " ", pp.size, " ui ", menu.ui.size, " anchors ", pp.anchor_right)
	get_viewport().get_texture().get_image().save_png(out + "/chest_popup.png")
	get_tree().quit()
