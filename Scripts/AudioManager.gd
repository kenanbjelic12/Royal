extends Node
## Autoload: plays sound effects (pooled players, slight pitch variation) and
## looping music. Sounds are looked up by name in res://Assets/Audio/.

const AUDIO_DIR := "res://Assets/Audio/"
const POOL_SIZE := 14

var sfx_volume_db := -4.0
var music_volume_db := -14.0
var muted := false
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name: StringName = &""
var _last_played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_music.finished.connect(func(): if _music_name != &"": _music.play())

func _stream(sound: StringName) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStream = null
	for ext: String in [".mp3", ".ogg", ".wav"]:   # recorded / AI-generated audio wins over synthesized wav
		var path := AUDIO_DIR + String(sound) + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_cache[sound] = s
	return s

var _variants: Dictionary = {}

## Plays a random variant of a voice line: name, name_1, name_2 ... Returns
## false when no file exists so callers can fall back to a generic sound.
func play_voice(base: String, volume_offset := 2.0) -> bool:
	if not _variants.has(base):
		var found: Array[StringName] = []
		if _stream(StringName(base)) != null:
			found.append(StringName(base))
		for i in range(1, 6):
			var n := StringName("%s_%d" % [base, i])
			if _stream(n) != null:
				found.append(n)
		_variants[base] = found
	var list: Array = _variants[base]
	if list.is_empty():
		return false
	play(list[randi() % list.size()], 0.04, volume_offset, &"Voice")
	return true

func play(sound: StringName, pitch_var := 0.08, volume_offset := 0.0, bus: StringName = &"SFX") -> void:
	if muted or sound == &"":
		return
	# avoid stacking the exact same sound in the same frame (big fights)
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 40:
		return
	_last_played[sound] = now
	var s := _stream(sound)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.volume_db = sfx_volume_db + volume_offset
			p.bus = bus
			p.play()
			return

func play_music(music_name: StringName) -> void:
	if _music_name == music_name and _music.playing:
		return
	_music_name = music_name
	var s := _stream(StringName("music_" + String(music_name)))
	if s == null or muted:
		return
	_music.stream = s
	_music.volume_db = music_volume_db
	_music.play()

func stop_music() -> void:
	_music_name = &""
	_music.stop()

func set_muted(v: bool) -> void:
	muted = v
	if v:
		_music.stop()
