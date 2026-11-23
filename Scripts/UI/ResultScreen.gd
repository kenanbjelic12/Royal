extends Control
## Victory / Defeat screen. Victory: golden rays, confetti, crowns slamming
## in one by one, trophies and gold counting up, earned chest, Continue.
## Defeat: cold palette, lost trophies, Try Again + Menu.

@export var victory := true

var r: Dictionary
var _rays: Control
var _t := 0.0
var _crowns: Array[UIIcon] = []
var _trophy_val: Label
var _gold_val: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	r = GameManager.last_result
	if r.is_empty():
		r = {"won": victory, "crowns_player": 3 if victory else 0, "crowns_enemy": 0 if victory else 3, "trophies": 30 if victory else -20, "gold": 100 if victory else 0, "chest": "rare" if victory else ""}
	var top := Color("#ffb52e") if victory else Color("#4a5a7a")
	var bottom := Color("#7a2a8a") if victory else Color("#141a2a")
	var bg := UIStyle.gradient_rect(top, bottom)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	if victory:
		_confetti()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	add_child(v)
	var title := UIStyle.label("VICTORY!" if victory else "DEFEAT", 96, Color("#fff4b0") if victory else Color("#ff8080"), 18)
	title.add_theme_color_override("font_outline_color", Color("#6a2a00") if victory else Color("#1a0a14"))
	title.name = "Title"
	v.add_child(title)
	# crowns
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 18)
	v.add_child(crow)
	for i in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(130, 120)
		var shadow := UIIcon.new()
		shadow.kind = &"crown_gray"
		shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(shadow)
		var c := UIIcon.new()
		c.kind = &"crown_gold" if victory else &"crown_blue"
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.modulate.a = 0.0
		slot.add_child(c)
		_crowns.append(c)
		crow.add_child(slot)
	var score := UIStyle.label("%d  -  %d" % [int(r.get("crowns_player", 0)), int(r.get("crowns_enemy", 0))], 40, Color.WHITE, 8)
	v.add_child(score)
	# rewards panel
	var panel := UIStyle.make_panel(Color(0.08, 0.1, 0.25, 0.75), 24, Color(0, 0, 0, 0.5), 4)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	_trophy_val = _reward_row(pv, &"trophy", "Trophies")
	_gold_val = _reward_row(pv, &"gold", "Gold")
	var chest: String = r.get("chest", "")
	if chest != "":
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := UIIcon.new()
		ic.kind = &"chest"
		ic.tint = ChestPopup.CHEST_COLORS.get(chest, Color.WHITE)
		ic.custom_minimum_size = Vector2(70, 70)
		ch.add_child(ic)
		ch.add_child(UIStyle.label("%s earned!" % EconomyManager.CHESTS[chest].name, 26, UIStyle.GOLD, 6))
		pv.add_child(ch)
	elif victory and EconomyManager.chests.size() >= EconomyManager.CHEST_SLOTS:
		pv.add_child(UIStyle.label("Chest slots full!", 22, Color("#ffd6a8"), 5))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	v.add_child(btns)
	if victory:
		var cont := UIStyle.button("Continue", UIStyle.BLUE, 36, Vector2(300, 96))
		cont.name = "Continue"
		cont.pressed.connect(GameManager.goto_menu)
		btns.add_child(cont)
	else:
		var again := UIStyle.button("Try Again", UIStyle.GOLD, 34, Vector2(280, 96))
		again.name = "TryAgain"
		again.pressed.connect(GameManager.goto_battle)
		btns.add_child(again)
		var menu := UIStyle.button("Menu", UIStyle.BLUE, 34, Vector2(200, 96))
		menu.name = "Menu"
		menu.pressed.connect(GameManager.goto_menu)
		btns.add_child(menu)
	btns.modulate.a = 0.0
	_animate(title, btns)

func _reward_row(parent: Container, icon: StringName, caption: String) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size = Vector2(420, 0)
	var ic := UIIcon.new()
	ic.kind = icon
	ic.custom_minimum_size = Vector2(56, 56)
	h.add_child(ic)
	var l := UIStyle.label(caption, 28, Color("#c9d4ff"), 5, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var val := UIStyle.label("0", 36, Color.WHITE, 7, HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(val)
	parent.add_child(h)
	return val

func _animate(title: Label, btns: Control) -> void:
	title.pivot_offset = Vector2(title.size.x * 0.5, 60)
	title.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var earned := int(r.get("crowns_player", 0))
	for i in 3:
		var c := _crowns[i]
		if i < earned:
			tw.tween_callback(func():
				c.pivot_offset = c.size * 0.5
				c.scale = Vector2(2.4, 2.4)
				c.modulate.a = 1.0
				AudioManager.play(&"king_wake"))
			tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.12)
	var trophies := int(r.get("trophies", 0))
	var gold := int(r.get("gold", 0))
	tw.tween_method(func(x: float): _trophy_val.text = ("+" if trophies >= 0 else "") + str(int(x)), 0.0, float(trophies), 0.7)
	tw.tween_callback(func(): if gold > 0: AudioManager.play(&"coin"))
	tw.tween_method(func(x: float): _gold_val.text = "+" + str(int(x)), 0.0, float(gold), 0.6)
	tw.tween_callback(func():
		_trophy_val.add_theme_color_override("font_color", UIStyle.GREEN if trophies >= 0 else Color("#ff6b6b")))
	tw.tween_property(btns, "modulate:a", 1.0, 0.3)
	AudioManager.play(&"victory" if victory else &"defeat")

func _confetti() -> void:
	var cols := [Color("#ff4a6a"), Color("#ffd84a"), Color("#4ad6ff"), Color("#7dff3a"), Color("#c04dff"), Color.WHITE]
	for i in cols.size():
		var p := CPUParticles2D.new()
		p.amount = 26
		p.lifetime = 4.0
		p.preprocess = 2.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(420, 10)
		p.position = Vector2(get_viewport_rect().size.x * 0.5, -20)
		p.direction = Vector2(0, 1)
		p.spread = 25
		p.gravity = Vector2(0, 160)
		p.initial_velocity_min = 60
		p.initial_velocity_max = 200
		p.angular_velocity_min = -360
		p.angular_velocity_max = 360
		p.angle_min = 0
		p.angle_max = 360
		p.scale_amount_min = 6
		p.scale_amount_max = 11
		p.color = cols[i]
		var img := Image.create(2, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		p.texture = ImageTexture.create_from_image(img)
		add_child(p)

func _process(delta: float) -> void:
	_t += delta
	_rays.queue_redraw()

func _draw_rays() -> void:
	var c := Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.3)
	var col := Color(1, 0.95, 0.6, 0.16) if victory else Color(0.6, 0.7, 1.0, 0.05)
	for i in 16:
		var a := i * TAU / 16.0 + _t * (0.25 if victory else 0.05)
		var p1 := c + Vector2(cos(a - 0.08), sin(a - 0.08)) * 1400.0
		var p2 := c + Vector2(cos(a + 0.08), sin(a + 0.08)) * 1400.0
		_rays.draw_colored_polygon(PackedVector2Array([c, p1, p2]), col)

func run_self_test() -> bool:
	await get_tree().create_timer(3.5, true, false, true).timeout
	var btn: Button = find_child("Continue" if victory else "TryAgain", true, false)
	return btn != null and btn.modulate.a > 0.9 and _crowns.size() == 3
