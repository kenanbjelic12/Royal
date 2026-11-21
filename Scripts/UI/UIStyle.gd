class_name UIStyle
extends RefCounted
## Central UI palette and widget factory so every screen shares one look:
## chunky rounded panels, thick outlines on text, glossy 3D-ish buttons.

const NAVY := Color("#16213d")
const NAVY_LIGHT := Color("#24365f")
const PANEL := Color("#2b4374")
const PANEL_LIGHT := Color("#3b5a96")
const GOLD := Color("#ffcb2e")
const GOLD_DARK := Color("#c27a00")
const BLUE := Color("#3d8bff")
const RED := Color("#ff4a4a")
const GREEN := Color("#5fd13b")
const ELIXIR := Color("#e03cf0")
const TEXT := Color("#ffffff")
const OUTLINE := Color("#0e1428")

static func box(bg: Color, radius := 18, border := Color(0, 0, 0, 0), border_w := 0, shadow := 0, shadow_offset := Vector2(0, 4)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = shadow_offset
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.2
	return s

static func label(text: String, size := 24, color := TEXT, outline := 6, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Glossy game button. `color` is the face colour.
static func button(text: String, color := GOLD, font_size := 28, min_size := Vector2(200, 70)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var dark := color.darkened(0.45)
	var normal := box(color, 16, dark, 0, 4, Vector2(0, 5))
	normal.border_width_bottom = 7
	normal.border_color = dark
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 6
	pressed.bg_color = color.darkened(0.06)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#8a8f99")
	disabled.border_color = Color("#5a5f69")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 7)
	b.pressed.connect(func(): AudioManager.play(&"button"))
	b.button_down.connect(func(): b.pivot_offset = b.size * 0.5; b.scale = Vector2(0.96, 0.96))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	return b

static func make_panel(bg := PANEL, radius := 22, border := NAVY, border_w := 4) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, radius, border, border_w, 6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	return p

## Currency pill (icon + value) used in top bars.
static func currency_pill(kind: StringName, value: String, width := 150) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(0, 0, 0, 0.45), 20, Color(1, 1, 1, 0.15), 2)
	s.content_margin_left = 6
	s.content_margin_right = 14
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(width, 42)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var icon := UIIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(38, 38)
	h.add_child(icon)
	var l := label(value, 24, TEXT, 5, HORIZONTAL_ALIGNMENT_RIGHT)
	l.name = "Value"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return p

static func gradient_rect(top: Color, bottom: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

static func fmt_time(sec: float) -> String:
	var s := maxi(0, int(ceil(sec)))
	return "%d:%02d" % [s / 60, s % 60]
