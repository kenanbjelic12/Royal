extends Node3D
## QA: renders the premium effects close-up. Usage: godot --path . res://Tools/FxShowcase.tscn -- out=/tmp/x
func _ready() -> void:
	var out := "user://fx"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	EconomyManager.persist = false
	AudioManager.set_muted(true)
	get_window().size = Vector2i(900, 900)
	var b: BattleManager = load("res://Scenes/Battle/Battle.tscn").instantiate()
	b.enemy_ai_enabled = false
	b.build_hud = false
	add_child(b)
	await get_tree().process_frame
	b.camera.set_process(false)
	b.camera.global_position = Vector3(1.5, 9.0, 12.5)
	b.camera.look_at(Vector3(1.5, 0.5, 6.0))
	var fx := b.effects_root()
	b.spawn_monster(CardDatabase.get_card(&"fire_knight"), 0, Vector3(-1.5, 0, 6.5), 1)
	var g := b.spawn_monster(CardDatabase.get_card(&"stone_golem"), 1, Vector3(3.0, 0, 5.5), 1)
	g.data = g.data.duplicate(); g.data.move_speed = 0.0
	g.apply_slow(0.35, 30.0)
	await get_tree().create_timer(0.3).timeout
	VFX.rock_hit(fx, Vector3(0.5, 0.5, 4.5))
	VFX.poison_puddle(fx, Vector3(4.5, 0, 7.5), 0.9)
	VFX.damage_number(fx, Vector3(3.0, 2.5, 5.5), 230, Color("#ffb3b3"))
	VFX.damage_number(fx, Vector3(-1.5, 2.0, 6.5), 85, Color("#9fd0ff"))
	VFX.debris(fx, Vector3(6.0, 0, 4.0), Color("#b3a796"), 16, 7.0)
	VFX.tower_explosion(fx, Vector3(6.0, 0, 4.0))
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/fx_showcase.png")
	print("saved")
	get_tree().quit()
