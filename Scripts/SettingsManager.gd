extends Node
## Autoload: player settings (audio buses, graphics quality, FPS, vibration,
## damage numbers). Saved to user://settings.cfg and applied immediately.

signal changed

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Voice"]
enum Quality { LOW, MEDIUM, HIGH }

var music := 0.7
var sfx := 0.9
var voice := 0.9
var muted := false
var quality: int = Quality.HIGH
var fps_limit := 60
var show_fps := false
var vibration := true
var damage_numbers := true
var persist := true
var _fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		quality = Quality.MEDIUM
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music = cfg.get_value("audio", "music", music)
	sfx = cfg.get_value("audio", "sfx", sfx)
	voice = cfg.get_value("audio", "voice", voice)
	muted = cfg.get_value("audio", "muted", muted)
	quality = cfg.get_value("graphics", "quality", quality)
	fps_limit = cfg.get_value("graphics", "fps_limit", fps_limit)
	show_fps = cfg.get_value("graphics", "show_fps", show_fps)
	vibration = cfg.get_value("game", "vibration", vibration)
	damage_numbers = cfg.get_value("game", "damage_numbers", damage_numbers)

func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "voice", voice)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("game", "vibration", vibration)
	cfg.set_value("game", "damage_numbers", damage_numbers)
	cfg.save(PATH)

## Applies everything and notifies open scenes (graphics are re-read by the
## battle / menu on `changed`).
func apply() -> void:
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	_set_bus("Voice", voice)
	AudioServer.set_bus_mute(0, muted)
	Engine.max_fps = fps_limit
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if quality == Quality.HIGH else Viewport.MSAA_DISABLED
		vp.mesh_lod_threshold = 2.0 if quality == Quality.HIGH else (6.0 if quality == Quality.MEDIUM else 14.0)
	_update_fps_label()
	changed.emit()

func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save_settings()

func shadows_enabled() -> bool:
	return quality != Quality.LOW

func outlines_enabled() -> bool:
	return quality != Quality.LOW

## Short haptic pulse on phones (deploys, tower falls).
func vibrate(ms := 30) -> void:
	if vibration:
		Input.vibrate_handheld(ms)

func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)

func _update_fps_label() -> void:
	if show_fps and _fps_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fps_label = Label.new()
		_fps_label.position = Vector2(8, 4)
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fps_label)
	if _fps_label:
		_fps_label.visible = show_fps

func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
