class_name UIManager
extends CanvasLayer
## Battle HUD: top bar (opponent, crowns, clock), 5-card hand with drag & drop
## or tap-to-place, elixir bar, monster preview with its special select
## animation, banners and the end-of-battle overlay.

var battle: BattleManager
var root: Control
var bars: HealthBarLayer
var cards: Array[CardView] = []
var _hand_root: Control
var _bottom: Control
var _elixir_fill: Control
var _elixir_label: Label
var _timer_label: Label
var _timer_caption: Label
var _crowns: Array = [[], []]
var _banner: Label
var _toast: Label
var _preview: SubViewportContainer
var _preview_vp: SubViewport
var _preview_model: MonsterModel
var _preview_name: Label
var _preview_stats: Label
var _drag_index := -1
var _dragging := false
var _press_pos := Vector2.ZERO
var _was_selected := false

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bars = HealthBarLayer.new()
	bars.battle = battle
	root.add_child(bars)
	_build_top_bar()
	_build_bottom()
	_build_preview()
	_banner = UIStyle.label("", 64, Color.WHITE, 12)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.size = Vector2(700, 140)
	_banner.position = Vector2(-350, -200)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_toast = UIStyle.label("", 30, Color("#ffd6d6"), 8)
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	battle.elixir[0].changed.connect(func(_v): _refresh_elixir())
	battle.card_manager.selection_changed.connect(_on_selection)
	battle.card_manager.deploy_failed.connect(_show_toast)
	battle.card_manager.deployed.connect(func(_i, _d): _hide_preview())
	battle.crowns_changed.connect(_on_crowns)
	battle.phase_changed.connect(_on_phase)
	battle.battle_finished.connect(_on_finished)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_elixir()
	_show_banner("BATTLE!", Color("#ffe27a"))

# ------------------------------------------------------------------ build
func _build_top_bar() -> void:
	var top := Panel.new()
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.box(Color(0.06, 0.09, 0.2, 0.82), 0)
	sb.border_width_bottom = 4
	sb.border_color = Color(0, 0, 0, 0.5)
	top.add_theme_stylebox_override("panel", sb)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 10)
	h.offset_left = 14
	h.offset_right = -14
	top.add_child(h)
	# opponent
	var opp := VBoxContainer.new()
	opp.add_theme_constant_override("separation", -4)
	opp.alignment = BoxContainer.ALIGNMENT_CENTER
	opp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp.add_child(UIStyle.label("Rival Bot", 24, Color("#ff9b9b"), 5, HORIZONTAL_ALIGNMENT_LEFT))
	opp.add_child(UIStyle.label("Level %d  ·  %s" % [GameManager.enemy_level(), EconomyManager.arena_name()], 15, Color("#c9d4ff"), 4, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(opp)
	# crowns: enemy (red) then player (blue)
	var crowns := VBoxContainer.new()
	crowns.alignment = BoxContainer.ALIGNMENT_CENTER
	crowns.add_theme_constant_override("separation", 0)
	for team in [1, 0]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		for i in 3:
			var ic := UIIcon.new()
			ic.kind = &"crown_gray"
			ic.custom_minimum_size = Vector2(30, 26)
			row.add_child(ic)
			_crowns[team].append(ic)
		crowns.add_child(row)
	h.add_child(crowns)
	# timer
	var tbox := PanelContainer.new()
	var tsb := UIStyle.box(Color(0, 0, 0, 0.45), 14, Color(1, 1, 1, 0.12), 2)
	tsb.content_margin_left = 12
	tsb.content_margin_right = 12
	tbox.add_theme_stylebox_override("panel", tsb)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	_timer_caption = UIStyle.label("Time left", 13, Color("#c9d4ff"), 3)
	_timer_label = UIStyle.label("3:00", 30, Color.WHITE, 6)
	tv.add_child(_timer_caption)
	tv.add_child(_timer_label)
	tbox.add_child(tv)
	tbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tbox)

func _build_bottom() -> void:
	_bottom = Control.new()
	_bottom.name = "CardPanel"
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_bottom)
	var bg := UIStyle.gradient_rect(Color("#2d4a86"), Color("#13203f"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bottom.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color("#ffcb2e")
	edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edge.custom_minimum_size.y = 4
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(edge)
	_hand_root = Control.new()
	_hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_hand_root)
	var cm := battle.card_manager
	for i in cm.hand.size():
		var d: MonsterData = cm.hand[i]
		var cv := CardView.new().setup(d, battle.card_level(0, d))
		cv.lift_enabled = true
		cv.gui_input.connect(_on_card_input.bind(i))
		_hand_root.add_child(cv)
		cards.append(cv)
	# elixir bar
	var bar := Control.new()
	bar.name = "ElixirBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(bar)
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.04, 0.1, 0.9), 12, Color(0, 0, 0, 0.6), 3))
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(back)
	_elixir_fill = Control.new()
	_elixir_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elixir_fill.draw.connect(_draw_elixir_fill)
	bar.add_child(_elixir_fill)
	var drop := UIIcon.new()
	drop.kind = &"elixir"
	drop.name = "Drop"
	bar.add_child(drop)
	_elixir_label = UIStyle.label("5", 28, Color.WHITE, 7)
	_elixir_label.name = "Count"
	bar.add_child(_elixir_label)

func _build_preview() -> void:
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	root.add_child(_preview)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	_preview.add_child(_preview_vp)
	var we := WorldEnvironment.new()
	var env := WorldEnv.make_environment()
	env.background_mode = Environment.BG_CLEAR_COLOR
	we.environment = env
	_preview_vp.add_child(we)
	WorldEnv.add_lights(_preview_vp, false, 20.0, -40.0)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 1.7, 5.4)
	_preview_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0))
	var pedestal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.0
	cm.height = 0.12
	pedestal.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("#3b5a96")
	pedestal.material_override = pm
	pedestal.position.y = -0.06
	_preview_vp.add_child(pedestal)
	_preview_name = UIStyle.label("", 22, Color.WHITE, 6)
	_preview_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_preview_name)
	_preview_stats = UIStyle.label("", 14, Color("#e6ecff"), 4)
	_preview.add_child(_preview_stats)

# ------------------------------------------------------------------ layout
func _layout() -> void:
	var vp := root.get_viewport_rect().size
	var top: Control = root.get_node("TopBar")
	top.size = Vector2(vp.x, vp.y * 0.075)
	top.position = Vector2.ZERO
	var bh := vp.y * battle.camera.bottom_margin
	_bottom.position = Vector2(0, vp.y - bh)
	_bottom.size = Vector2(vp.x, bh)
	var margin := 12.0
	var gap := 8.0
	var n := maxi(cards.size(), 1)
	var bar_h := clampf(bh * 0.17, 34, 54)
	var avail_h := bh - bar_h - margin * 3
	var cw := minf((minf(vp.x, 900.0) - margin * 2 - gap * (n - 1)) / n, avail_h / 1.27)
	var ch := cw * 1.27
	var total_w := cw * n + gap * (n - 1)
	var x0 := (vp.x - total_w) * 0.5
	for i in cards.size():
		var cv := cards[i]
		cv.size = Vector2(cw, ch)
		cv.base_position = Vector2(x0 + i * (cw + gap), margin + 6)
		cv.position = cv.base_position
	var bar: Control = _bottom.get_node("ElixirBar")
	bar.size = Vector2(total_w - bar_h * 0.6, bar_h)
	var cards_bottom := margin + 6 + ch
	var free := bh - cards_bottom - bar_h
	bar.position = Vector2(x0 + bar_h * 0.6, cards_bottom + free * 0.45)
	for cv in cards:
		cv.base_position.y += free * 0.15
	var drop: Control = bar.get_node("Drop")
	drop.size = Vector2(bar_h * 1.5, bar_h * 1.5)
	drop.position = Vector2(-bar_h * 0.95, -bar_h * 0.3)
	_elixir_label.size = drop.size
	_elixir_label.position = drop.position + Vector2(0, bar_h * 0.08)
	_elixir_label.add_theme_font_size_override("font_size", int(bar_h * 0.62))
	_elixir_fill.position = Vector2(bar_h * 0.55, 5)
	_elixir_fill.size = Vector2(bar.size.x - bar_h * 0.55 - 6, bar_h - 10)
	var pw := clampf(vp.x * 0.3, 180, 300)
	_preview.size = Vector2(pw, pw * 1.05)
	_preview.position = Vector2(10, vp.y - bh - pw * 1.05 - 10)
	_preview_name.position = Vector2(0, pw * 1.05 - 64)
	_preview_name.size = Vector2(pw, 30)
	_preview_stats.position = Vector2(0, pw * 1.05 - 34)
	_preview_stats.size = Vector2(pw, 26)
	_banner.position = Vector2(vp.x * 0.5 - 350, vp.y * 0.36)
	_toast.size = Vector2(vp.x, 40)
	_toast.position = Vector2(0, vp.y - bh - 60)
	_elixir_fill.queue_redraw()

# ------------------------------------------------------------------ updates
func _process(_delta: float) -> void:
	if battle == null:
		return
	var t := battle.time_left
	_timer_label.text = UIStyle.fmt_time(t)
	match battle.phase:
		&"double":
			_timer_caption.text = "x2 Elixir"
			_timer_caption.add_theme_color_override("font_color", Color("#f07dff"))
		&"overtime":
			_timer_caption.text = "Overtime"
			_timer_caption.add_theme_color_override("font_color", Color("#ffb03a"))
	if t < 10.0 and not battle.is_finished():
		_timer_label.add_theme_color_override("font_color", Color("#ff6b6b") if int(t * 2) % 2 == 0 else Color.WHITE)
	var em := battle.elixir[0]
	for i in cards.size():
		cards[i].disabled = not em.can_afford(cards[i].data.elixir_cost) or battle.is_finished()
	_elixir_fill.queue_redraw()

func _refresh_elixir() -> void:
	_elixir_label.text = str(battle.elixir[0].whole())

func _draw_elixir_fill() -> void:
	var s := _elixir_fill.size
	var e := battle.elixir[0].elixir
	var seg_w := s.x / 10.0
	for i in 10:
		var r := Rect2(Vector2(i * seg_w + 2, 0), Vector2(seg_w - 4, s.y))
		_elixir_fill.draw_rect(r, Color(0.18, 0.1, 0.25))
		var f := clampf(e - i, 0.0, 1.0)
		if f > 0.0:
			var full := f >= 1.0
			var col := Color("#d633e8") if full else Color("#9a3fb0")
			_elixir_fill.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
			if full:
				_elixir_fill.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.3))

# ------------------------------------------------------------------ input
func _on_card_input(event: InputEvent, i: int) -> void:
	var cm := battle.card_manager
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var gpos: Vector2 = cards[i].get_global_transform_with_canvas() * event.position
		if event.pressed:
			if battle.is_finished():
				return
			_press_pos = gpos
			_drag_index = i
			_dragging = false
			_was_selected = cm.selected == i
			if not _was_selected:
				cm.select(i)
				if not cm.can_play(i):
					_show_toast("Not enough elixir!")
		else:
			if _dragging and _drag_index == i:
				if _over_arena(gpos):
					cm.try_deploy(gpos)
				else:
					cm.hide_ghost()
			elif _was_selected and _drag_index == i:
				cm.deselect()
			_dragging = false
			_drag_index = -1
	elif event is InputEventMouseMotion and _drag_index == i:
		var gpos: Vector2 = cards[i].get_global_transform_with_canvas() * event.position
		if gpos.distance_to(_press_pos) > 12.0:
			_dragging = true
		if _dragging:
			if _over_arena(gpos):
				cm.update_hover(gpos)
			else:
				cm.hide_ghost()

func _over_arena(p: Vector2) -> bool:
	return p.y < _bottom.position.y - 4.0 and p.y > root.get_viewport_rect().size.y * 0.075

func _on_selection(index: int) -> void:
	for i in cards.size():
		cards[i].selected = i == index
	if index >= 0:
		_show_preview(battle.card_manager.hand[index])
	else:
		_hide_preview()

func _show_preview(d: MonsterData) -> void:
	if _preview_model:
		_preview_model.queue_free()
	_preview_model = MonsterFactory.create_model(d)
	_preview_vp.add_child(_preview_model)
	var s := 0.75 if d.id == &"stone_golem" else 1.0
	_preview_model.scale = Vector3.ONE * s
	_preview_model.position = Vector3(0, 0.55 if d.is_flying else 0.0, 0)
	_preview_model.rotation.y = PI + deg_to_rad(25)
	_preview_model.play_select()
	_preview_name.text = d.display_name
	_preview_stats.text = "HP %d  ·  DMG %d  ·  %s" % [d.hp_at(battle.card_level(0, d)), d.damage_at(battle.card_level(0, d)), d.speed_label()]
	_preview.visible = true
	_preview.modulate.a = 0.0
	_preview.scale = Vector2(0.85, 0.85)
	_preview.pivot_offset = _preview.size * Vector2(0.2, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_preview, "modulate:a", 1.0, 0.15)
	tw.tween_property(_preview, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_preview() -> void:
	_preview.visible = false
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null

# ------------------------------------------------------------------ feedback
func _show_banner(text: String, col: Color, hold := 1.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.4, 0.4)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _on_crowns(p: int, e: int) -> void:
	var counts := [p, e]
	for team in 2:
		for i in 3:
			var ic: UIIcon = _crowns[team][i]
			ic.kind = (&"crown_blue" if team == 0 else &"crown_red") if i < counts[team] else &"crown_gray"
	if not battle.is_finished():
		_show_banner("+1 Crown", Color("#8fc3ff") if p > e else Color("#ff9b9b"), 0.6)

func _on_phase(p: StringName) -> void:
	match p:
		&"double": _show_banner("2x ELIXIR!", Color("#f07dff"))
		&"overtime": _show_banner("OVERTIME!", Color("#ffb03a"))

func _on_finished(r: Dictionary) -> void:
	battle.card_manager.deselect()
	_hide_preview()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var won: bool = r.get("won", false)
	var draw: bool = r.get("draw", false)
	var title := "VICTORY!" if won else ("DRAW" if draw else "DEFEAT")
	var col := Color("#ffd84a") if won else (Color("#d9e2ff") if draw else Color("#ff6b6b"))
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.45, 0.6)
	_banner.text = title
	_banner.add_theme_color_override("font_color", col)
	_banner.add_theme_font_size_override("font_size", 84)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.3, 0.3)
	_banner.modulate.a = 1.0
	root.move_child(_banner, -1)
	var tw2 := create_tween()
	tw2.tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var btn := UIStyle.button("Continue", UIStyle.BLUE if won else UIStyle.GOLD, 32, Vector2(260, 84))
	btn.set_anchors_preset(Control.PRESET_CENTER)
	var vp := root.get_viewport_rect().size
	btn.position = Vector2(vp.x * 0.5 - 130, vp.y * 0.56)
	btn.modulate.a = 0.0
	btn.pressed.connect(GameManager.goto_result)
	root.add_child(btn)
	create_tween().tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(1.2)
