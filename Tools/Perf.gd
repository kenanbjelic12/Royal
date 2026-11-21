extends Node
## Performance probe: a crowded battle (20 monsters + all towers fighting),
## prints draw calls, primitives, node count and average frame time.
## Usage: godot --path . res://Tools/Perf.tscn

func _ready() -> void:
	EconomyManager.persist = false
	AudioManager.set_muted(true)
	var b: BattleManager = load("res://Scenes/Battle/Battle.tscn").instantiate()
	b.enemy_ai_enabled = false
	b.build_hud = not OS.get_cmdline_user_args().has("nohud")
	add_child(b)
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("nofill"):
		b.get_node("Fill").queue_free()
	if OS.get_cmdline_user_args().has("noshadow"):
		(b.get_node("Sun") as DirectionalLight3D).shadow_enabled = false
	if OS.get_cmdline_user_args().has("nooutline"):
		for m in b.find_children("*", "MeshInstance3D", true, false):
			var mat = m.material_override
			if mat is StandardMaterial3D:
				mat.next_pass = null
	var deck := CardDatabase.deck()
	var n_units := 0 if OS.get_cmdline_user_args().has("nounits") else 20
	for i in n_units:
		var team := i % 2
		var d: MonsterData = deck[i % deck.size()]
		var x := -6.0 + (i / 2) * 1.3
		if OS.get_cmdline_user_args().has("calm"):
			var u := b.spawn_monster(d, 0, Vector3(x, 0, 6.0), 1)
			u.data = u.data.duplicate()
			u.data.move_speed = 0.0
		else:
			b.spawn_monster(d, team, Vector3(x, 0, 3.0 if team == 0 else -3.0), 1)
	for i in 120:
		await get_tree().process_frame
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var draw := 0
	var prims := 0
	while frames < 120:
		await get_tree().process_frame
		frames += 1
		draw = maxi(draw, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	var meshes := 0
	for n in b.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
	print("PERF units=%d mesh_instances=%d max_draw_calls=%d max_primitives=%d avg_frame_ms=%.1f (software GL)" % [b.units.size(), meshes, draw, prims, ms])
	get_tree().quit()
