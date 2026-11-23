extends Node
## Renders card illustrations from the real in-game 3D models (transparent PNG)
## into res://Assets/Cards/<id>.png, so card art always matches the monster.
## Usage (needs a display / xvfb): godot --path . res://Tools/PortraitRenderer.tscn

const SIZE := Vector2i(512, 600)
## Per monster framing: pose, pose time (s), camera pos, look-at, model yaw.
const SHOTS := {
	&"fire_knight": {"pose": "select", "time": 0.5, "cam": Vector3(-1.3, 1.5, -3.6), "look": Vector3(0, 1.05, 0), "fov": 36.0},
	&"shadow_assassin": {"pose": "walk", "time": 0.45, "cam": Vector3(-0.9, 1.25, -2.9), "look": Vector3(0, 0.78, 0), "fov": 34.0},
	&"stone_golem": {"pose": "idle", "time": 0.5, "cam": Vector3(-1.3, 1.9, -4.2), "look": Vector3(0, 1.1, 0), "fov": 36.0},
	&"frost_dragon": {"pose": "idle", "time": 0.5, "cam": Vector3(-1.0, 1.35, -3.1), "look": Vector3(0, 0.68, 0), "fov": 36.0},
	&"thunder_mage": {"pose": "idle", "time": 0.5, "cam": Vector3(-1.1, 1.45, -3.4), "look": Vector3(0, 0.85, 0), "fov": 35.0},
	&"healing_fairy": {"pose": "idle", "time": 0.5, "cam": Vector3(-0.9, 1.2, -3.0), "look": Vector3(0, 0.7, 0), "fov": 35.0},
	&"goblin_gang": {"pose": "walk", "time": 0.45, "cam": Vector3(-0.8, 1.0, -2.5), "look": Vector3(0, 0.55, 0), "fov": 35.0},
	&"viking_berserker": {"pose": "walk", "time": 0.45, "cam": Vector3(-1.2, 1.5, -3.6), "look": Vector3(0, 0.9, 0), "fov": 35.0},
	&"bomb_pirate": {"pose": "idle", "time": 0.5, "cam": Vector3(-1.1, 1.4, -3.4), "look": Vector3(0, 0.8, 0), "fov": 35.0},
	&"poison_witch": {"pose": "select", "time": 0.45, "cam": Vector3(-1.2, 1.6, -3.7), "look": Vector3(0, 1.05, 0), "fov": 36.0},
}

func _ready() -> void:
	var out_dir := ProjectSettings.globalize_path("res://Assets/Cards/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for d: MonsterData in CardDatabase.deck():
		await _render(d, out_dir + String(d.id) + ".png")
	get_tree().quit()

func _render(d: MonsterData, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := WorldEnv.make_environment(0.8)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.glow_enabled = false
	we.environment = env
	vp.add_child(we)
	WorldEnv.add_lights(vp, true, 150.0, -40.0)
	# strong coloured rim light from behind for a premium card look
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -20, 0)
	rim.light_color = d.accent_color.lightened(0.4)
	rim.light_energy = 0.9
	vp.add_child(rim)
	var shot: Dictionary = SHOTS.get(d.id, {"pose": "idle", "time": 0.5, "cam": Vector3(-1, 1.2, -2.8), "look": Vector3(0, 0.8, 0), "fov": 35.0})
	var m := MonsterFactory.create_model(d)
	vp.add_child(m)
	m.rotation.y = deg_to_rad(-10)
	m.set_process(false)
	match shot.pose:
		"select": m.play_select()
		"attack": m.play_attack(1.0)
		"walk": m.set_moving(true)
	for i in int(shot.time * 60.0):
		m._apply_pose(1.0 / 60.0)
	var cam := Camera3D.new()
	cam.fov = shot.fov
	vp.add_child(cam)
	cam.position = shot.cam
	cam.look_at(shot.look)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("portrait ", path)
	vp.queue_free()
