extends Node
## Renders card illustrations from the real in-game 3D models (transparent PNG)
## into res://Assets/Cards/<id>.png, so card art always matches the monster.
## Close "hero" framing (from the hips up) in a chosen moment of an animation.
##
## Usage (needs a display / xvfb):
##   godot --path . res://Tools/PortraitRenderer.tscn                 # final card art
##   godot --path . res://Tools/PortraitRenderer.tscn -- candidates=/tmp/out   # pose contact sheets

const SIZE := Vector2i(512, 600)
## Best pose per monster: [clip, seconds into the clip, yaw degrees, zoom].
## zoom < 1 frames tighter (more of the face), > 1 shows more of the body.
const SHOTS := {
	&"fire_knight": ["select", 0.55, -18.0, 1.0],
	&"shadow_assassin": ["walk", 0.45, -15.0, 0.72],
	&"stone_golem": ["select", 0.3, -18.0, 0.78],
	&"frost_dragon": ["select", 1.3, -18.0, 0.85],
	&"poison_witch": ["select", 0.55, -18.0, 0.78],
	&"thunder_mage": ["spawn", 0.9, -18.0, 0.72],
	&"healing_fairy": ["select", 0.55, -18.0, 0.75],
	&"goblin_gang": ["select", 0.55, -18.0, 0.75],
	&"viking_berserker": ["select", 0.55, -18.0, 0.75],
	&"bomb_pirate": ["select", 0.55, -18.0, 0.78],
	&"skeleton_squad": ["select", 0.3, -18.0, 0.78],
}
## Cards that use hand-made key art (Assets/Cards/<id>.png) – never overwritten.
const CUSTOM_ART := [&"fire_knight", &"shadow_assassin", &"stone_golem", &"frost_dragon", &"poison_witch",
	&"healing_fairy", &"viking_berserker", &"goblin_gang", &"skeleton_squad", &"bomb_pirate", &"thunder_mage"]
const CANDIDATES := [["idle", 0.6], ["select", 0.3], ["select", 0.55], ["select", 0.9], ["select", 1.3],
	["attack", 0.3], ["attack", 0.5], ["spawn", 0.9]]

func _ready() -> void:
	var cand_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("candidates="):
			cand_dir = a.substr(11)
	if cand_dir != "":
		DirAccess.make_dir_recursive_absolute(cand_dir)
		for d: MonsterData in CardDatabase.deck():
			for i in CANDIDATES.size():
				var c: Array = CANDIDATES[i]
				await _render(d, c[0], c[1], -18.0, 1.0, "%s/%s_%d_%s_%.2f.png" % [cand_dir, d.id, i, c[0], c[1]])
	else:
		var out_dir := ProjectSettings.globalize_path("res://Assets/Cards/")
		DirAccess.make_dir_recursive_absolute(out_dir)
		for d: MonsterData in CardDatabase.deck():
			if CUSTOM_ART.has(d.id) and not OS.get_cmdline_user_args().has("all"):
				continue
			var s: Array = SHOTS.get(d.id, ["idle", 0.5, -18.0, 1.0])
			await _render(d, s[0], s[1], s[2], s[3], out_dir + String(d.id) + ".png")
	get_tree().quit()

func _render(d: MonsterData, clip: String, time: float, yaw: float, zoom: float, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := WorldEnv.make_environment(0.85)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.glow_enabled = false
	we.environment = env
	vp.add_child(we)
	WorldEnv.add_lights(vp, true, 150.0, -40.0)
	var rim := DirectionalLight3D.new()   # coloured rim light from behind
	rim.rotation_degrees = Vector3(-20, -20, 0)
	rim.light_color = d.accent_color.lightened(0.4)
	rim.light_energy = 1.0
	vp.add_child(rim)
	var m := MonsterFactory.create_model(d)
	vp.add_child(m)
	m.rotation.y = deg_to_rad(yaw)
	m.set_process(false)
	match clip:
		"select": m.play_select()
		"attack": m.play_attack(1.0)
		"walk": m.set_moving(true)
		"spawn": m.play_spawn()
	for i in int(time * 60.0):
		m._apply_pose(1.0 / 60.0)
	if m.get("_player") != null:
		var ap: AnimationPlayer = m.get("_player")
		ap.advance(0.0)
	# frame from the hips up using the design height of the model
	var h := 1.3
	if m is GLBMonsterModel:
		h = float(GLBMonsterModel.SETUP.get(d.id, {"height": 1.3}).height)
	var base_y := 0.0
	if m is GLBMonsterModel and bool(GLBMonsterModel.SETUP.get(d.id, {}).get("fly", false)):
		base_y = 0.0
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var look := Vector3(0, base_y + h * (0.62 + (1.0 - zoom) * 0.25), 0)
	var dist := (h * 0.62 * zoom) / tan(deg_to_rad(cam.fov * 0.5))
	cam.position = look + Vector3(-0.28, 0.22, -1.0).normalized() * dist
	cam.look_at(look)
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("portrait ", path)
	vp.queue_free()
