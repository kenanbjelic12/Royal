class_name ChestView
extends SubViewportContainer
## Shows a 3D ChestModel inside UI (chest popup, menu slots). `live` views
## keep rendering for animation; static ones render a few frames then stop
## (cheap enough for four menu slots).

var type := "gold"
var live := true
var chest: ChestModel
var _vp: SubViewport

static func available(p_type: String) -> bool:
	return ChestModel.has_model(p_type)

static func make(p_type: String, p_live := true) -> ChestView:
	var v := ChestView.new()
	v.type = p_type
	v.live = p_live
	return v

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 25, 0)
	key.light_energy = 1.25
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.75, 0.85, 1.0)
	_vp.add_child(fill)
	chest = ChestModel.new()
	chest.type = type
	_vp.add_child(chest)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.75, 2.75)
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.45, 0))
	if not live:
		chest.set_process(false)
		_freeze()

func _freeze() -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	if is_instance_valid(_vp):
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

func shake(duration := 0.7) -> void:
	chest.shake(duration)

func open() -> void:
	chest.open()
