extends Control
## Card collection: all cards with level and copies progress. Tapping a card
## opens a detail view with a live 3D model doing its special animation,
## full stats (elixir, rarity, level, damage, HP, attack speed, range, speed,
## targets) and a working Upgrade button (copies + gold).

var _grid: GridContainer
var _detail: UIPopup
var _preview_model: MonsterModel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := UIStyle.gradient_rect(Color("#2d4a86"), Color("#101a36"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var back := UIStyle.button("<", UIStyle.BLUE, 32, Vector2(70, 64))
	back.name = "Back"
	back.pressed.connect(GameManager.goto_menu)
	top.add_child(back)
	var title := UIStyle.label("Cards", 44, UIStyle.GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(CurrencyBar.new())
	var info := UIStyle.label("Collection %d / %d   ·   Tap a card for details" % [CardDatabase.cards.size(), CardDatabase.cards.size()], 20, Color("#c9d4ff"), 4)
	root.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 22)
	center.add_child(_grid)
	_fill()

func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for d in CardDatabase.deck():
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		var cv := CardView.new().setup(d, EconomyManager.get_card_level(d.id))
		cv.custom_minimum_size = Vector2(190, 242)
		cv.name = "Card_" + String(d.id)
		cv.pressed.connect(func(_c): open_detail(d))
		v.add_child(cv)
		v.add_child(_copies_bar(d))
		_grid.add_child(v)

func _copies_bar(d: MonsterData) -> Control:
	var cost := EconomyManager.upgrade_cost(d.id)
	var have := EconomyManager.get_card_copies(d.id)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(190, 30)
	pb.show_percentage = false
	pb.max_value = maxi(cost.copies, 1)
	pb.value = mini(have, int(cost.copies)) if not cost.max else pb.max_value
	pb.add_theme_stylebox_override("background", UIStyle.box(Color(0, 0, 0, 0.5), 10, Color(0, 0, 0, 0.6), 2))
	var ready := EconomyManager.can_upgrade(d.id)
	pb.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.GREEN if ready else Color("#3d8bff"), 10))
	var l := UIStyle.label("MAX" if cost.max else "%d / %d" % [have, cost.copies], 18, Color.WHITE, 4)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	pb.add_child(l)
	return pb

func open_detail(d: MonsterData) -> UIPopup:
	AudioManager.play(&"card_select")
	_detail = UIPopup.open(self, d.display_name, 680)
	_detail.name = "Detail"
	var lvl := EconomyManager.get_card_level(d.id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.content.add_child(head)
	var cv := CardView.new().setup(d, lvl)
	cv.custom_minimum_size = Vector2(200, 254)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(cv)
	head.add_child(_model_preview(d))
	var tags := HBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("separation", 10)
	tags.add_child(_tag(MonsterData.rarity_name(d.rarity), MonsterData.rarity_color(d.rarity)))
	tags.add_child(_tag("Level %d" % lvl, Color("#4ad6ff")))
	tags.add_child(_tag(d.role, Color("#ffcb2e")))
	_detail.content.add_child(tags)
	var desc := UIStyle.label(d.description, 20, Color("#e6ecff"), 4)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(600, 0)
	_detail.content.add_child(desc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_detail.content.add_child(grid)
	var rows := [
		["Elixir cost", str(d.elixir_cost)],
		["Hitpoints", str(int(d.hp_at(lvl)))],
		["Damage", str(int(d.damage_at(lvl))) + (" (area)" if d.splash_radius > 0.0 else "")],
		["Damage / sec", str(int(d.dps_at(lvl)))],
		["Attack speed", "%.2f s" % d.attack_speed],
		["Attack range", d.range_label()],
		["Move speed", d.speed_label()],
		["Targets", d.targets_label()],
	]
	if d.slow_amount > 0.0:
		rows.append(["Freeze", "-%d%% speed %.0fs" % [int(d.slow_amount * 100), d.slow_duration]])
	if d.poison_dps > 0.0:
		rows.append(["Poison", "%d dmg/s for %.0fs" % [int(d.poison_dps), d.poison_duration]])
	if d.first_hit_multiplier > 1.0:
		rows.append(["Ambush", "x%.0f first hit" % d.first_hit_multiplier])
	for r in rows:
		grid.add_child(_stat_cell(r[0], r[1]))
	var cost := EconomyManager.upgrade_cost(d.id)
	var up := UIStyle.button("MAX LEVEL" if cost.max else "Upgrade  ·  %d gold" % cost.gold, UIStyle.GREEN, 28, Vector2(420, 84))
	up.name = "Upgrade"
	up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	up.disabled = not EconomyManager.can_upgrade(d.id)
	_detail.content.add_child(up)
	if not cost.max:
		_detail.content.add_child(UIStyle.label("Cards: %d / %d" % [EconomyManager.get_card_copies(d.id), cost.copies], 18, Color("#c9d4ff"), 4))
	up.pressed.connect(func():
		if EconomyManager.upgrade_card(d.id):
			AudioManager.play(&"coin")
			_detail.close()
			_fill()
			open_detail(d))
	return _detail

func _tag(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.box(col.darkened(0.55), 14, col, 3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UIStyle.label(text, 18, Color.WHITE, 4))
	return p

func _stat_cell(name_text: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.box(Color("#1d2f57"), 12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(300, 0)
	var h := HBoxContainer.new()
	p.add_child(h)
	var n := UIStyle.label(name_text, 18, Color("#9fb3dd"), 3, HORIZONTAL_ALIGNMENT_LEFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(UIStyle.label(value, 20, Color.WHITE, 4, HORIZONTAL_ALIGNMENT_RIGHT))
	return p

## Live 3D turntable of the real monster playing its special animation.
func _model_preview(d: MonsterData) -> Control:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(400, 254)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var we := WorldEnvironment.new()
	var env := WorldEnv.make_environment()
	env.background_mode = Environment.BG_CLEAR_COLOR
	we.environment = env
	vp.add_child(we)
	WorldEnv.add_lights(vp, true, 20.0, -40.0)
	var cam := Camera3D.new()
	cam.fov = 32
	var big := d.id == &"stone_golem"
	cam.position = Vector3(0, 1.7 if big else 1.3, 5.6 if big else 4.0)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.1 if big else 0.75, 0))
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.2
	cm.height = 0.14
	ped.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = d.accent_color.darkened(0.3)
	ped.material_override = pm
	ped.position.y = -0.07
	vp.add_child(ped)
	_preview_model = MonsterFactory.create_model(d)
	vp.add_child(_preview_model)
	_preview_model.position.y = 0.6 if d.is_flying else 0.0
	_preview_model.play_select()
	return svc

func _process(delta: float) -> void:
	if _preview_model and is_instance_valid(_preview_model):
		_preview_model.rotation.y += delta * 0.6
		if _preview_model.select_t < 0.0 and fmod(Time.get_ticks_msec() / 1000.0, 3.0) < delta * 2.0:
			_preview_model.play_select()

func run_self_test() -> bool:
	var ok := _grid.get_child_count() == 5
	for d in CardDatabase.deck():
		var p := open_detail(d)
		await get_tree().process_frame
		ok = ok and is_instance_valid(p) and p.find_child("Upgrade", true, false) != null
		p.close()
	# upgrade flow with enough copies and gold
	var id := &"fire_knight"
	var lv := EconomyManager.get_card_level(id)
	EconomyManager.add_card_copies(id, 10)
	EconomyManager.gold += 1000
	ok = ok and EconomyManager.upgrade_card(id) and EconomyManager.get_card_level(id) == lv + 1
	return ok
