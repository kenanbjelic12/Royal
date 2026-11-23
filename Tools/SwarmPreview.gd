extends Node3D
## QA: close-up of the two swarm cards fighting. godot --path . res://Tools/SwarmPreview.tscn -- <outdir>
func _ready() -> void:
	EconomyManager.persist = false
	SettingsManager.persist = false
	AudioManager.set_muted(true)
	var b: BattleManager = load("res://Scenes/Battle/Battle.tscn").instantiate()
	b.enemy_ai_enabled = false
	b.build_hud = false
	add_child(b)
	await get_tree().process_frame
	b.camera.set_process(false)
	b.camera.fov = 40
	b.camera.global_position = Vector3(0.5, 9.5, 7.5)
	b.camera.look_at(Vector3(0.5, 0.4, 2.2))
	var g: MonsterData = CardDatabase.get_card(&"stone_golem").duplicate()
	g.move_speed = 0.0
	b.spawn_monster(g, 1, Vector3(0.5, 0, 1.9), 1)
	b.elixir[0].elixir = 10
	b.deploy_card(0, CardDatabase.get_card(&"skeleton_squad"), Vector3(-1.2, 0, 4.2))
	b.deploy_card(0, CardDatabase.get_card(&"goblin_gang"), Vector3(2.4, 0, 4.0))
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/swarm.png")
	get_tree().quit()
