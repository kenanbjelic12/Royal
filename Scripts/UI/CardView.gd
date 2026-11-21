class_name CardView
extends Control
## Premium collectible card widget used in the battle hand, Cards menu and
## Shop: rarity frame, illustration rendered from the real 3D model, elixir
## drop with cost, name ribbon and level pill.

signal pressed(card: CardView)

const GRAY_SHADER := """
shader_type canvas_item;
uniform float gray = 0.0;
uniform float dim = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), gray) * (1.0 - dim);
	COLOR = c;
}
"""

var data: MonsterData
var level := 1
var show_level := true
var disabled := false:
	set(v):
		disabled = v
		_apply_state()
var selected := false:
	set(v):
		selected = v
		_apply_state()
## When true (battle hand) the card lifts itself up while selected.
var lift_enabled := false
var base_position := Vector2.ZERO
var _portrait: TextureRect
var _ribbon: Panel
var _pill: Panel
var _drop: UIIcon
var _name: Label
var _cost: Label
var _lvl: Label
var _shader: ShaderMaterial
var _t := 0.0
var _lift := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(40, 51)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(p_data: MonsterData, p_level := 1) -> CardView:
	data = p_data
	level = p_level
	return self

func _ready() -> void:
	clip_contents = false
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	_shader.shader = sh
	_portrait.material = _shader
	if data and data.portrait:
		_portrait.texture = data.portrait
	add_child(_portrait)
	_ribbon = Panel.new()
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_theme_stylebox_override("panel", UIStyle.box(Color(0.05, 0.07, 0.15, 0.85), 8))
	add_child(_ribbon)
	_pill = Panel.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_theme_stylebox_override("panel", UIStyle.box(Color(0.05, 0.07, 0.15, 0.85), 8))
	add_child(_pill)
	_drop = UIIcon.new()
	_drop.kind = &"elixir"
	add_child(_drop)
	_name = UIStyle.label(data.display_name if data else "?", 15, Color.WHITE, 4)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.clip_text = true
	add_child(_name)
	_cost = UIStyle.label(str(data.elixir_cost) if data else "", 24, Color.WHITE, 6)
	add_child(_cost)
	_lvl = UIStyle.label("Lv.%d" % level, 13, Color("#ffe9a8"), 4)
	_lvl.visible = show_level
	_pill.visible = show_level
	add_child(_lvl)
	resized.connect(_layout)
	_layout()
	_apply_state()

func set_level(v: int) -> void:
	level = v
	if _lvl:
		_lvl.text = "Lv.%d" % level

func _layout() -> void:
	var s := size
	var m := s.x * 0.06
	_portrait.position = Vector2(m, m)
	_portrait.size = Vector2(s.x - m * 2, s.y - m * 2 - s.y * 0.17)
	_ribbon.position = Vector2(m * 0.5, s.y - m - s.y * 0.19)
	_ribbon.size = Vector2(s.x - m, s.y * 0.19)
	_pill.position = Vector2(s.x * 0.52, s.y * 0.6)
	_pill.size = Vector2(s.x * 0.42, s.y * 0.13)
	_drop.position = Vector2(-s.x * 0.11, -s.y * 0.08)
	_drop.size = Vector2(s.x * 0.42, s.x * 0.42)
	_name.position = Vector2(m, s.y - m - s.y * 0.19)
	_name.size = Vector2(s.x - m * 2, s.y * 0.19)
	# shrink long names so they always fit on the ribbon
	var fs := int(clampf(s.x * 0.125, 9, 26))
	var font := get_theme_default_font()
	if data and font:
		while fs > 8 and font.get_string_size(data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _name.size.x - 6:
			fs -= 1
	_name.add_theme_font_size_override("font_size", fs)
	_cost.position = _drop.position + Vector2(0, s.x * 0.03)
	_cost.size = _drop.size
	_cost.add_theme_font_size_override("font_size", int(s.x * 0.2))
	_lvl.position = Vector2(s.x * 0.52, s.y * 0.6)
	_lvl.size = Vector2(s.x * 0.42, s.y * 0.13)
	_lvl.add_theme_font_size_override("font_size", int(clampf(s.x * 0.11, 10, 22)))

func _apply_state() -> void:
	if _shader:
		_shader.set_shader_parameter("gray", 0.85 if disabled else 0.0)
		_shader.set_shader_parameter("dim", 0.35 if disabled else 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if selected else 0.0
	_lift = move_toward(_lift, want, delta * 8.0)
	pivot_offset = size * Vector2(0.5, 1.0)
	scale = Vector2.ONE * (1.0 + 0.08 * _lift)
	if lift_enabled:
		position = base_position + Vector2(0, -18.0 * _lift)
	if data and data.rarity == MonsterData.Rarity.LEGENDARY or selected:
		queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var s := size
	var r := s.x * 0.11
	var rc := MonsterData.rarity_color(data.rarity)
	if data.rarity == MonsterData.Rarity.LEGENDARY:
		rc = Color.from_hsv(fmod(0.45 + sin(_t * 1.5) * 0.08, 1.0), 0.7, 1.0)
	if disabled:
		rc = rc.darkened(0.45)
	# shadow + selection glow
	draw_style_box(UIStyle.box(Color(0, 0, 0, 0.35), int(r)), Rect2(Vector2(0, 5), s))
	if selected:
		var glow := UIStyle.box(Color(1, 1, 0.7, 0.25 + 0.15 * sin(_t * 8.0)), int(r * 1.4))
		draw_style_box(glow, Rect2(Vector2(-7, -7), s + Vector2(14, 14)))
	# frame
	draw_style_box(UIStyle.box(Color("#0e1428"), int(r)), Rect2(Vector2(-2, -2), s + Vector2(4, 4)))
	draw_style_box(UIStyle.box(rc, int(r)), Rect2(Vector2.ZERO, s))
	draw_style_box(UIStyle.box(rc.lightened(0.35), int(r)), Rect2(Vector2(2, 2), Vector2(s.x - 4, s.y * 0.35)))
	draw_style_box(UIStyle.box(rc, int(r)), Rect2(Vector2(2, 6), Vector2(s.x - 4, s.y - 8)))
	# inner gradient background in the monster's accent colour
	var m := s.x * 0.06
	var inner := Rect2(Vector2(m, m), Vector2(s.x - m * 2, s.y - m * 2))
	var top := data.accent_color.lightened(0.35)
	var bottom := data.accent_color.darkened(0.55)
	if disabled:
		top = top.darkened(0.5)
		bottom = bottom.darkened(0.5)
	draw_polygon(PackedVector2Array([inner.position, inner.position + Vector2(inner.size.x, 0), inner.end, inner.position + Vector2(0, inner.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# light rays behind the illustration
	var cpos := inner.get_center() + Vector2(0, -s.y * 0.08)
	for i in 8:
		var a := i * TAU / 8.0 + _t * 0.15
		var p1 := cpos + Vector2(cos(a - 0.12), sin(a - 0.12)) * s.x
		var p2 := cpos + Vector2(cos(a + 0.12), sin(a + 0.12)) * s.x
		draw_colored_polygon(_clip_tri(cpos, p1, p2, inner), Color(1, 1, 1, 0.07))
	if data.portrait == null:
		draw_circle(cpos, s.x * 0.28, data.accent_color)

func _clip_tri(a: Vector2, b: Vector2, c: Vector2, rect: Rect2) -> PackedVector2Array:
	var poly := PackedVector2Array([a, b, c])
	var rp := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	var res := Geometry2D.intersect_polygons(poly, rp)
	return res[0] if res.size() > 0 else PackedVector2Array([a, a, a])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
