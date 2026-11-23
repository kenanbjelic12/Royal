extends Node
## QA: shop scrolled to the chests, then an Epic chest opening.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	EconomyManager.persist = false
	EconomyManager.gems = 3450
	var shop: Control = load("res://Scenes/Shop/Shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await get_tree().create_timer(1.0).timeout
	var sc: ScrollContainer = shop.find_children("*", "ScrollContainer", true, false)[0]
	var h: Control = shop.find_child("Chests", true, false)
	sc.scroll_vertical = 700
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out + "/shop.png")
	ChestPopup.show_rewards(shop, EconomyManager.roll_chest("epic"))
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(out + "/shop_popup_early.png")
	await get_tree().create_timer(3.4).timeout
	get_viewport().get_texture().get_image().save_png(out + "/shop_popup.png")
	get_tree().quit()
