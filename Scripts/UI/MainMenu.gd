extends Node3D
## Main menu: 3D kingdom backdrop, player profile (level, XP, trophies),
## gold & gems, ROYAL ARENA logo, battle deck, big BATTLE button, 4 chest
## slots with real unlock timers, quests popup and bottom navigation.

var ui: Control
var _chest_slots: Array[Button] = []
var _quest_badge: Label
var _profile_level: Label
var _xp_bar: ProgressBar
var _trophy_label: Label
var _battle_btn: Button
var _t := 0.0

func _ready() -> void:
	add_child(KingdomBackdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_build()
	EconomyManager.changed.connect(_refresh)
	_refresh()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	AudioManager.play_music(&"menu")

## Compact layout for short / landscape screens (PC windows).
func _apply_layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var compact := vs.x > vs.y * 0.9
	(ui.find_child("LogoCrown", true, false) as Control).visible = not compact
	(ui.find_child("DeckTitle", true, false) as Control).visible = not compact
	(ui.find_child("Logo", true, false) as Label).add_theme_font_size_override("font_size", 56 if compact else 78)
	for slot in _chest_slots:
		slot.custom_minimum_size = Vector2(158, 96 if compact else 150)
	for cv in (ui.find_child("DeckRow", true, false) as Control).get_children():
		(cv as Control).custom_minimum_size = Vector2(70, 89) if compact else Vector2(92, 117)
	_battle_btn.custom_minimum_size = Vector2(380, 84 if compact else 116)

func _build() -> void:
	# soft vignette gradient so UI text stays readable over the 3D scene
	var top_shade := UIStyle.gradient_rect(Color(0.05, 0.08, 0.2, 0.75), Color(0.05, 0.08, 0.2, 0.0))
	top_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shade.custom_minimum_size.y = 260
	ui.add_child(top_shade)
	var bottom_shade := UIStyle.gradient_rect(Color(0.05, 0.08, 0.2, 0.0), Color(0.05, 0.08, 0.2, 0.9))
	bottom_shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_shade.offset_top = -620
	ui.add_child(bottom_shade)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# --- top bar: profile + currencies
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var profile := PanelContainer.new()
	var psb := UIStyle.box(Color(0, 0, 0, 0.45), 20, Color(1, 1, 1, 0.15), 2)
	psb.content_margin_left = 8
	psb.content_margin_right = 14
	psb.content_margin_top = 6
	psb.content_margin_bottom = 6
	profile.add_theme_stylebox_override("panel", psb)
	top.add_child(profile)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	profile.add_child(ph)
	var lvl_box := Control.new()
	lvl_box.custom_minimum_size = Vector2(58, 58)
	var star := UIIcon.new()
	star.kind = &"xp"
	star.set_anchors_preset(Control.PRESET_FULL_RECT)
	lvl_box.add_child(star)
	_profile_level = UIStyle.label("1", 24, Color.WHITE, 6)
	_profile_level.set_anchors_preset(Control.PRESET_FULL_RECT)
	lvl_box.add_child(_profile_level)
	ph.add_child(lvl_box)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	ph.add_child(pv)
	pv.add_child(UIStyle.label(EconomyManager.player_name, 24, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_LEFT))
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(130, 12)
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("background", UIStyle.box(Color(0, 0, 0, 0.5), 6))
	_xp_bar.add_theme_stylebox_override("fill", UIStyle.box(Color("#4ad6ff"), 6))
	pv.add_child(_xp_bar)
	var trow := HBoxContainer.new()
	var tic := UIIcon.new()
	tic.kind = &"trophy"
	tic.custom_minimum_size = Vector2(26, 26)
	trow.add_child(tic)
	_trophy_label = UIStyle.label("0", 20, UIStyle.GOLD, 5, HORIZONTAL_ALIGNMENT_LEFT)
	trow.add_child(_trophy_label)
	pv.add_child(trow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var cur := CurrencyBar.new()
	cur.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(cur)

	# --- logo
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -10)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	var crown := UIIcon.new()
	crown.name = "LogoCrown"
	crown.kind = &"crown_gold"
	crown.custom_minimum_size = Vector2(0, 86)
	logo.add_child(crown)
	var title := UIStyle.label("ROYAL ARENA", 78, UIStyle.GOLD, 16)
	title.add_theme_color_override("font_outline_color", Color("#5a2a00"))
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.name = "Logo"
	logo.add_child(title)
	var sub := UIStyle.label("", 22, Color("#e6f0ff"), 6)
	sub.name = "ArenaName"
	logo.add_child(sub)

	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)

	# --- battle deck preview
	var deck_title := UIStyle.label("Battle Deck", 22, Color("#c9d4ff"), 5)
	deck_title.name = "DeckTitle"
	root.add_child(deck_title)
	var deck_row := HBoxContainer.new()
	deck_row.name = "DeckRow"
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 8)
	root.add_child(deck_row)
	for d in CardDatabase.deck():
		var cv := CardView.new().setup(d, EconomyManager.get_card_level(d.id))
		cv.custom_minimum_size = Vector2(92, 117)
		cv.pressed.connect(func(_c): GameManager.goto(GameManager.SCENE_CARDS))
		deck_row.add_child(cv)

	# --- battle button
	_battle_btn = UIStyle.button("BATTLE", UIStyle.GOLD, 52, Vector2(380, 116))
	_battle_btn.name = "BattleButton"
	_battle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_battle_btn.pressed.connect(GameManager.goto_battle)
	root.add_child(_battle_btn)

	# --- chest slots
	var chests := HBoxContainer.new()
	chests.alignment = BoxContainer.ALIGNMENT_CENTER
	chests.add_theme_constant_override("separation", 10)
	root.add_child(chests)
	for i in EconomyManager.CHEST_SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(158, 150)
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_stylebox_override("normal", UIStyle.box(Color(0.1, 0.14, 0.3, 0.85), 16, Color(1, 1, 1, 0.18), 3))
		slot.add_theme_stylebox_override("hover", UIStyle.box(Color(0.14, 0.2, 0.4, 0.9), 16, Color(1, 1, 1, 0.3), 3))
		slot.add_theme_stylebox_override("pressed", UIStyle.box(Color(0.08, 0.1, 0.22, 0.9), 16, Color(1, 1, 1, 0.3), 3))
		var sv := VBoxContainer.new()
		sv.set_anchors_preset(Control.PRESET_FULL_RECT)
		sv.alignment = BoxContainer.ALIGNMENT_CENTER
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(sv)
		var ic := UIIcon.new()
		ic.name = "Icon"
		ic.kind = &"chest"
		ic.custom_minimum_size = Vector2(0, 74)
		sv.add_child(ic)
		var l1 := UIStyle.label("", 16, Color.WHITE, 4)
		l1.name = "Title"
		sv.add_child(l1)
		var l2 := UIStyle.label("", 18, UIStyle.GOLD, 5)
		l2.name = "Status"
		sv.add_child(l2)
		slot.pressed.connect(_on_chest.bind(i))
		chests.add_child(slot)
		_chest_slots.append(slot)

	# --- bottom navigation
	var nav := PanelContainer.new()
	var nsb := UIStyle.box(Color("#13203f"), 22, Color("#0e1428"), 4, 6)
	nsb.content_margin_top = 6
	nsb.content_margin_bottom = 6
	nav.add_theme_stylebox_override("panel", nsb)
	root.add_child(nav)
	var nh := HBoxContainer.new()
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nh.add_theme_constant_override("separation", 6)
	nav.add_child(nh)
	nh.add_child(_nav_button("Shop", &"gem", func(): GameManager.goto(GameManager.SCENE_SHOP)))
	nh.add_child(_nav_button("Cards", &"star", func(): GameManager.goto(GameManager.SCENE_CARDS)))
	nh.add_child(_nav_button("Battle", &"crown_gold", GameManager.goto_battle, true))
	var q := _nav_button("Quests", &"trophy", _open_quests)
	q.name = "QuestsButton"
	_quest_badge = UIStyle.label("", 18, Color.WHITE, 5)
	_quest_badge.position = Vector2(100, -6)
	_quest_badge.size = Vector2(34, 34)
	var badge_bg := Panel.new()
	badge_bg.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.RED, 17, Color.WHITE, 2))
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_bg.position = _quest_badge.position
	badge_bg.size = _quest_badge.size
	badge_bg.name = "BadgeBg"
	q.add_child(badge_bg)
	q.add_child(_quest_badge)
	nh.add_child(q)

func _nav_button(text: String, icon: StringName, cb: Callable, highlight := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.name = text + "Button"
	var col := Color("#3b5a96") if highlight else Color("#24365f")
	b.add_theme_stylebox_override("normal", UIStyle.box(col, 16))
	b.add_theme_stylebox_override("hover", UIStyle.box(col.lightened(0.1), 16))
	b.add_theme_stylebox_override("pressed", UIStyle.box(col.darkened(0.15), 16))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UIIcon.new()
	ic.kind = icon
	ic.custom_minimum_size = Vector2(0, 50)
	v.add_child(ic)
	v.add_child(UIStyle.label(text, 20, Color.WHITE, 5))
	b.pressed.connect(func(): AudioManager.play(&"button"))
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	if not is_inside_tree():
		return
	_profile_level.text = str(EconomyManager.level)
	_xp_bar.max_value = EconomyManager.xp_needed()
	_xp_bar.value = EconomyManager.xp
	_trophy_label.text = str(EconomyManager.trophies)
	var sub: Label = ui.find_child("ArenaName", true, false)
	sub.text = "%s  ·  %d Trophies" % [EconomyManager.arena_name(), EconomyManager.trophies]
	var n := EconomyManager.quests_claimable()
	_quest_badge.text = str(n)
	_quest_badge.visible = n > 0
	(_quest_badge.get_parent().get_node("BadgeBg") as Control).visible = n > 0
	_refresh_chests()

func _refresh_chests() -> void:
	for i in _chest_slots.size():
		var slot := _chest_slots[i]
		var ic: UIIcon = slot.find_child("Icon", true, false)
		var t1: Label = slot.find_child("Title", true, false)
		var t2: Label = slot.find_child("Status", true, false)
		if i >= EconomyManager.chests.size():
			ic.visible = false
			t1.text = "Empty slot"
			t2.text = "Win to earn"
			t2.add_theme_color_override("font_color", Color("#8fa0c8"))
			continue
		var c: Dictionary = EconomyManager.chests[i]
		ic.visible = true
		ic.tint = ChestPopup.CHEST_COLORS.get(c.type, Color.WHITE)
		t1.text = EconomyManager.CHESTS[c.type].name
		if EconomyManager.chest_ready(i):
			t2.text = "OPEN!"
			t2.add_theme_color_override("font_color", UIStyle.GREEN)
		elif c.unlock_at > 0:
			t2.text = UIStyle.fmt_time(EconomyManager.chest_time_left(i))
			t2.add_theme_color_override("font_color", UIStyle.GOLD)
		else:
			t2.text = "Tap: %s" % UIStyle.fmt_time(EconomyManager.CHESTS[c.type].unlock)
			t2.add_theme_color_override("font_color", Color("#e6f0ff"))

func _process(delta: float) -> void:
	_t += delta
	if _battle_btn:
		_battle_btn.pivot_offset = _battle_btn.size * 0.5
		if not _battle_btn.is_pressed():
			_battle_btn.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.025)
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_refresh_chests()

func _on_chest(i: int) -> void:
	AudioManager.play(&"button")
	if i >= EconomyManager.chests.size():
		return
	if EconomyManager.chest_ready(i):
		var r := EconomyManager.open_chest(i)
		if not r.is_empty():
			ChestPopup.show_rewards(ui, r)
		_refresh()
	elif EconomyManager.chests[i].unlock_at <= 0 and not EconomyManager.any_unlocking():
		EconomyManager.start_unlock(i)
		_refresh()
	else:
		_open_chest_now_popup(i)

func _open_chest_now_popup(i: int) -> void:
	var c: Dictionary = EconomyManager.chests[i]
	var p := UIPopup.open(ui, EconomyManager.CHESTS[c.type].name, 560)
	var info := "Unlocking: %s left" % UIStyle.fmt_time(EconomyManager.chest_time_left(i)) if c.unlock_at > 0 else "Another chest is unlocking."
	p.content.add_child(UIStyle.label(info, 24, Color.WHITE, 5))
	var cost := EconomyManager.chest_gem_cost(i)
	var b := UIStyle.button("Open now  %d gems" % cost, UIStyle.GREEN, 28, Vector2(360, 84))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = EconomyManager.gems < cost
	b.pressed.connect(func():
		var r := EconomyManager.open_chest(i, true)
		p.close()
		if not r.is_empty():
			ChestPopup.show_rewards(ui, r)
		_refresh())
	p.content.add_child(b)

func _open_quests() -> UIPopup:
	var p := UIPopup.open(ui, "Daily Quests", 640)
	p.name = "QuestsPopup"
	for d in EconomyManager.QUEST_DEFS:
		var st := EconomyManager.quest_state(d.id)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIStyle.box(Color("#1d2f57"), 16))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UIStyle.label(d.title, 24, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_LEFT))
		var pb := ProgressBar.new()
		pb.max_value = d.goal
		pb.value = mini(int(st.progress), int(d.goal))
		pb.custom_minimum_size = Vector2(0, 22)
		pb.add_theme_stylebox_override("background", UIStyle.box(Color(0, 0, 0, 0.5), 10))
		pb.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.GREEN, 10))
		v.add_child(pb)
		var reward := "+%d gold" % d.reward_gold if d.reward_gold > 0 else ""
		if d.reward_gems > 0:
			reward += ("  " if reward != "" else "") + "+%d gems" % d.reward_gems
		v.add_child(UIStyle.label("%d / %d    %s" % [mini(int(st.progress), int(d.goal)), d.goal, reward], 17, Color("#c9d4ff"), 4, HORIZONTAL_ALIGNMENT_LEFT))
		var done := int(st.progress) >= int(d.goal)
		var b := UIStyle.button("Claimed" if st.claimed else "Claim", UIStyle.GREEN, 22, Vector2(130, 64))
		b.name = "Claim_" + d.id
		b.disabled = st.claimed or not done
		b.pressed.connect(func():
			if EconomyManager.claim_quest(d.id):
				AudioManager.play(&"coin")
				b.text = "Claimed"
				b.disabled = true
				_refresh())
		h.add_child(b)
		p.content.add_child(row)
	return p

## Used by the automated test suite (Tests/TestRunner.gd).
func run_self_test() -> bool:
	var ok := true
	var p := _open_quests()
	await get_tree().process_frame
	ok = ok and is_instance_valid(p) and p.content.get_child_count() == EconomyManager.QUEST_DEFS.size()
	p.close()
	# chest flow: start unlock, then pay gems to open
	EconomyManager.chests = [{"type": "wooden", "unlock_at": -1}]
	EconomyManager.gems = 100
	_refresh()
	_on_chest(0)
	ok = ok and EconomyManager.chests[0].unlock_at > 0
	var gems_before := EconomyManager.gems
	var r := EconomyManager.open_chest(0, true)
	ok = ok and not r.is_empty() and EconomyManager.gems < gems_before and EconomyManager.chests.is_empty()
	_refresh()
	ok = ok and _battle_btn != null and _battle_btn.is_visible_in_tree()
	return ok
