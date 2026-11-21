@tool
class_name UIIcon
extends Control
## Resolution-independent vector icons drawn in code (elixir drop, gold coin,
## gem, trophy, crowns, star, lock, chest). Crisp at any mobile DPI.

@export var kind: StringName = &"elixir":
	set(v):
		kind = v
		queue_redraw()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match kind:
		&"elixir": draw_elixir(self, c, s)
		&"gold": _coin(c, s)
		&"gem": _gem(c, s)
		&"trophy": _trophy(c, s)
		&"crown_blue": draw_crown(self, c, s, Color("#3d8bff"))
		&"crown_red": draw_crown(self, c, s, Color("#ff4a4a"))
		&"crown_gold": draw_crown(self, c, s, Color("#ffcb2e"))
		&"crown_gray": draw_crown(self, c, s, Color("#6b7385"))
		&"star": _star(c, s * 0.48, s * 0.2, Color("#ffd84a"))
		&"chest": _chest(c, s)
		&"lock": _lock(c, s)
		&"xp": _star(c, s * 0.48, s * 0.26, Color("#4ad6ff"))

static func draw_elixir(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_colored_polygon(_drop(c, s * 1.14), Color("#3a0a45"))
	ci.draw_colored_polygon(_drop(c, s), Color("#c42adf"))
	ci.draw_colored_polygon(_drop(c + Vector2(-s * 0.03, s * 0.03), s * 0.72), Color("#f07dff"))
	ci.draw_circle(c + Vector2(-s * 0.09, s * 0.02), s * 0.075, Color(1, 1, 1, 0.9))

## Teardrop polygon: pointed tip on top, round bottom.
static func _drop(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := s * 0.3
	var cc := c + Vector2(0, s * 0.1)
	pts.append(c + Vector2(0, -s * 0.44))
	var a0 := -PI * 0.5 + 0.75
	var a1 := PI * 1.5 - 0.75
	for i in 25:
		var a := lerpf(a0, a1, i / 24.0)
		pts.append(cc + Vector2(cos(a), sin(a)) * r)
	return pts

static func draw_crown(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.8
	var h := s * 0.55
	var base_y := c.y + h * 0.45
	var top_y := c.y - h * 0.55
	var pts := PackedVector2Array([
		Vector2(c.x - w * 0.5, base_y), Vector2(c.x - w * 0.5, top_y + h * 0.25),
		Vector2(c.x - w * 0.25, c.y - h * 0.05), Vector2(c.x, top_y),
		Vector2(c.x + w * 0.25, c.y - h * 0.05), Vector2(c.x + w * 0.5, top_y + h * 0.25),
		Vector2(c.x + w * 0.5, base_y)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * 1.18)
	ci.draw_colored_polygon(out, Color("#0e1428"))
	ci.draw_colored_polygon(pts, col)
	ci.draw_rect(Rect2(c.x - w * 0.5, base_y - h * 0.22, w, h * 0.22), col.darkened(0.25))
	for x in [-0.5, 0.0, 0.5]:
		ci.draw_circle(Vector2(c.x + w * x * (1.0 if x == 0.0 else 1.0), (top_y if x == 0.0 else top_y + h * 0.25)), s * 0.07, Color("#ffffff"))

func _coin(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.46, Color("#8a5200"))
	draw_circle(c, s * 0.42, Color("#ffb81f"))
	draw_circle(c, s * 0.3, Color("#ffd75e"))
	draw_circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.08, Color(1, 1, 1, 0.8))

func _gem(c: Vector2, s: float) -> void:
	var o := PackedVector2Array([c + Vector2(-s * 0.44, -s * 0.12), c + Vector2(-s * 0.22, -s * 0.42), c + Vector2(s * 0.22, -s * 0.42), c + Vector2(s * 0.44, -s * 0.12), c + Vector2(0, s * 0.46)])
	var outline := PackedVector2Array()
	for p in o:
		outline.append(c + (p - c) * 1.12)
	draw_colored_polygon(outline, Color("#0b3d1a"))
	draw_colored_polygon(o, Color("#2ee06b"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.44, -s * 0.12), c + Vector2(s * 0.44, -s * 0.12), c + Vector2(0, s * 0.46)]), Color("#1fb553"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.42), c + Vector2(0, -s * 0.42), c + Vector2(-s * 0.15, -s * 0.12)]), Color(1, 1, 1, 0.7))

func _trophy(c: Vector2, s: float) -> void:
	var gold := Color("#ffcb2e")
	var dark := Color("#8a5200")
	draw_rect(Rect2(c.x - s * 0.26, c.y + s * 0.3, s * 0.52, s * 0.14), dark)
	draw_rect(Rect2(c.x - s * 0.08, c.y + s * 0.08, s * 0.16, s * 0.24), gold.darkened(0.2))
	draw_circle(c + Vector2(-s * 0.3, -s * 0.18), s * 0.12, dark)
	draw_circle(c + Vector2(s * 0.3, -s * 0.18), s * 0.12, dark)
	var cup := PackedVector2Array([c + Vector2(-s * 0.34, -s * 0.42), c + Vector2(s * 0.34, -s * 0.42), c + Vector2(s * 0.22, s * 0.08), c + Vector2(-s * 0.22, s * 0.08)])
	draw_colored_polygon(cup, gold)
	draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.36, s * 0.1, s * 0.3), Color(1, 1, 1, 0.55))

func _star(c: Vector2, r_out: float, r_in: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(c + (p - c) * 1.15)
	draw_colored_polygon(outline, Color("#0e1428"))
	draw_colored_polygon(pts, col)

func _chest(c: Vector2, s: float) -> void:
	var col := tint if tint != Color.WHITE else Color("#b8722c")
	draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.1, s * 0.88, s * 0.5), Color("#0e1428"))
	draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.06, s * 0.8, s * 0.42), col)
	draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.4, s * 0.88, s * 0.34), Color("#0e1428"))
	draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.36, s * 0.8, s * 0.28), col.lightened(0.2))
	draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.16, s * 0.12, s * 0.2), Color("#ffcb2e"))
	draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.1, s * 0.8, s * 0.06), Color("#ffcb2e"))

func _lock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.1), s * 0.2, PI, TAU, 16, Color("#d0d6e2"), s * 0.08)
	draw_rect(Rect2(c.x - s * 0.28, c.y - s * 0.1, s * 0.56, s * 0.42), Color("#d0d6e2"))
	draw_circle(c + Vector2(0, s * 0.08), s * 0.06, Color("#3a4255"))
