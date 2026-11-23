class_name HealthBarLayer
extends Control
## Draws all health bars, level badges and names in one pass (crisp 2D
## overlay projected from 3D positions – cheap and readable on phones).

var battle: BattleManager
var font: Font
var ui_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = get_theme_default_font()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if battle == null or battle.camera == null:
		return
	var cam := battle.camera
	var vs := get_viewport_rect().size
	ui_scale = clampf(minf(vs.x, vs.y) / 720.0, 0.7, 1.6)
	for team in 2:
		for t: TowerController in battle.get_towers(team):
			if t.is_alive():
				_draw_tower(cam, t)
	for u: MonsterController in battle.units:
		if is_instance_valid(u) and u.is_alive():
			_draw_unit(cam, u)

func _team_col(team: int) -> Color:
	return Color("#3d8bff") if team == 0 else Color("#ff4a4a")

func _draw_unit(cam: Camera3D, u: MonsterController) -> void:
	var h := (ArenaLayout.FLY_HEIGHT if u.is_flying else 0.0) + _unit_height(u) * ArenaLayout.UNIT_VISUAL_SCALE
	var wp := u.global_position + Vector3(0, h, 0)
	if cam.is_position_behind(wp):
		return
	var p := cam.unproject_position(wp)
	var w := (44.0 + u.data.radius * 30.0) * ui_scale
	var bh := 7.0 * ui_scale
	var col := _team_col(u.team)
	var ratio := u.hp / u.max_hp
	var rect := Rect2(p - Vector2(w * 0.5 - 8 * ui_scale, bh * 0.5), Vector2(w, bh))
	draw_rect(rect.grow(2.0 * ui_scale), Color(0.05, 0.06, 0.12, 0.9))
	draw_rect(rect, Color(0.2, 0.2, 0.25, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), col)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y * 0.4)), Color(1, 1, 1, 0.3))
	# level badge
	var bc := rect.position + Vector2(-2 * ui_scale, bh * 0.5)
	draw_circle(bc, 10.5 * ui_scale, Color(0.05, 0.06, 0.12))
	draw_circle(bc, 8.5 * ui_scale, col.darkened(0.15))
	var lv := str(u.level)
	var fs := int(12 * ui_scale)
	var tw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, bc + Vector2(-tw * 0.5, fs * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(3 * ui_scale), Color(0.05, 0.06, 0.12))
	draw_string(font, bc + Vector2(-tw * 0.5, fs * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# name
	var nfs := int(11 * ui_scale)
	var nm := u.data.display_name
	var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var np := Vector2(rect.get_center().x - nw * 0.5, rect.position.y - 5 * ui_scale)
	draw_string_outline(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, int(3 * ui_scale), Color(0.05, 0.06, 0.12, 0.9))
	draw_string(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(1, 1, 1, 0.95))
	# status icons
	if u.slow_time > 0.0:
		draw_circle(rect.end + Vector2(8 * ui_scale, -bh * 0.5), 5 * ui_scale, Color("#7fe3ff"))
	if u.poison_time > 0.0:
		draw_circle(rect.end + Vector2(19 * ui_scale, -bh * 0.5), 5 * ui_scale, Color("#7dff3a"))

func _unit_height(u: MonsterController) -> float:
	match u.data.id:
		&"stone_golem": return 2.2
		&"poison_witch": return 1.85
		&"frost_dragon": return 0.85
		_: return 1.55

func _draw_tower(cam: Camera3D, t: TowerController) -> void:
	var wp := t.global_position + Vector3(0, 3.8 if t.kind == &"king" else 4.5, 0)
	if cam.is_position_behind(wp):
		return
	var p := cam.unproject_position(wp)
	var w := (100.0 if t.kind == &"king" else 80.0) * ui_scale
	var bh := 13.0 * ui_scale
	var col := _team_col(t.team)
	var ratio := t.hp / t.max_hp
	var rect := Rect2(p - Vector2(w * 0.5, bh * 0.5), Vector2(w, bh))
	draw_style_box(UIStyle.box(Color(0.05, 0.06, 0.12, 0.92), int(5 * ui_scale)), rect.grow(3 * ui_scale))
	draw_rect(rect, Color(0.22, 0.22, 0.28))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), col)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y * 0.4)), Color(1, 1, 1, 0.3))
	var txt := str(int(ceil(t.hp)))
	var fs := int(13 * ui_scale)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := rect.get_center() + Vector2(-tw * 0.5, fs * 0.36)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(3 * ui_scale), Color(0.05, 0.06, 0.12))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# level / crown badge on the left
	var bc := rect.position + Vector2(-6 * ui_scale, bh * 0.5)
	draw_circle(bc, 13 * ui_scale, Color(0.05, 0.06, 0.12))
	draw_circle(bc, 11 * ui_scale, col.darkened(0.1))
	if t.kind == &"king":
		UIIcon.draw_crown(self, bc, 18 * ui_scale, Color("#ffcb2e"))
		if not t.active:
			var z := "z z"
			draw_string_outline(font, rect.position + Vector2(w + 6 * ui_scale, -2 * ui_scale), z, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(3 * ui_scale), Color(0.05, 0.06, 0.12))
			draw_string(font, rect.position + Vector2(w + 6 * ui_scale, -2 * ui_scale), z, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#bfe0ff"))
	else:
		var lv := str(t.level)
		var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, bc + Vector2(-lw * 0.5, fs * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(3 * ui_scale), Color(0.05, 0.06, 0.12))
		draw_string(font, bc + Vector2(-lw * 0.5, fs * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
