extends Node3D
## QA tool: renders every monster (or one) in several poses to PNG files.
## Usage: godot --path . res://Tools/ModelViewer.tscn -- out=/tmp/dir [id=fire_knight] [pose=idle|attack|walk|select] [view=front|game]

var out_dir := "user://model_qa"
var only_id := ""
var pose_name := "idle"
var view := "front"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"out": out_dir = kv[1]
				"id": only_id = kv[1]
				"pose": pose_name = kv[1]
				"view": view = kv[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var we := WorldEnvironment.new()
	we.environment = WorldEnv.make_environment()
	add_child(we)
	WorldEnv.add_lights(self)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#5fbf45")
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	var ids: Array = []
	for d in CardDatabase.deck():
		if only_id == "" or String(d.id) == only_id:
			ids.append(d)
	var x := 0.0
	var models: Array = []
	for d: MonsterData in ids:
		var m: MonsterModel = MonsterFactory.create_model(d)
		add_child(m)
		m.scale = Vector3.ONE * d.model_scale
		m.position = Vector3(x, 2.2 if d.is_flying else 0.0, 0)
		m.rotation.y = PI if view == "game" else deg_to_rad(25)
		models.append(m)
		x += 2.6
	var center := (x - 2.6) * 0.5
	if view == "game":
		cam.position = Vector3(center, 9.5 + x * 0.4, 6 + x * 0.3)
		cam.look_at(Vector3(center, 0.6, 0))
	else:
		cam.position = Vector3(center, 2.4, -4.6 - x * 0.62)
		cam.look_at(Vector3(center, 1.2, 0))
	get_viewport().size = Vector2i(1600, 700) if ids.size() > 1 else Vector2i(700, 700)
	# advance animations to an interesting frame
	var frames := 40
	match pose_name:
		"attack":
			for m: MonsterModel in models:
				m.play_attack(1.0)
			frames = 0
		"select":
			for m: MonsterModel in models:
				m.play_select()
		"walk":
			for m: MonsterModel in models:
				m.set_moving(true)
	var wait := frames
	if pose_name == "attack":
		wait = int(0.38 * 60)
	elif pose_name == "select":
		wait = int(0.5 * 60)
	for m: MonsterModel in models:
		m.set_process(false)
		for i in wait:
			m._apply_pose(1.0 / 60.0)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var fname := "%s/%s_%s_%s.png" % [out_dir, only_id if only_id != "" else "all", pose_name, view]
	img.save_png(fname)
	print("saved ", fname)
	get_tree().quit()
