class_name SettingsPopup
extends RefCounted
## Settings screen (opened from the main menu gear and the pause menu).

const VERSION := "0.1.0 test build"

static func open(parent: Node, in_battle := false) -> UIPopup:
	var p := UIPopup.open(parent, "Settings", 640)
	p.name = "SettingsPopup"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vs: Vector2 = parent.get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(0, minf(vs.y * 0.62, 760))
	p.content.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	var S = SettingsManager

	_section(v, "Sound")
	_slider(v, "Music", "music", S.music)
	_slider(v, "Sound effects", "sfx", S.sfx)
	_slider(v, "Character voices", "voice", S.voice)
	_toggle(v, "Mute all sound", "muted", S.muted)

	_section(v, "Graphics")
	_choice(v, "Quality", "quality", ["Low", "Medium", "High"], [0, 1, 2], S.quality,
		"Low: no shadows or outlines, best for older phones.")
	_choice(v, "Frame rate", "fps_limit", ["30 FPS", "60 FPS"], [30, 60], S.fps_limit,
		"30 FPS saves battery.")
	_toggle(v, "Show FPS counter", "show_fps", S.show_fps)

	_section(v, "Gameplay")
	_toggle(v, "Vibration", "vibration", S.vibration)
	_toggle(v, "Damage numbers", "damage_numbers", S.damage_numbers)

	if not in_battle:
		_section(v, "Profile")
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 10)
		var le := LineEdit.new()
		le.name = "PlayerName"
		le.text = EconomyManager.player_name
		le.max_length = 16
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.custom_minimum_size = Vector2(0, 56)
		le.add_theme_font_size_override("font_size", 24)
		le.add_theme_stylebox_override("normal", UIStyle.box(Color("#1d2f57"), 12, Color(1, 1, 1, 0.2), 2))
		le.add_theme_stylebox_override("focus", UIStyle.box(Color("#24365f"), 12, UIStyle.GOLD, 2))
		name_row.add_child(le)
		var save := UIStyle.button("Save name", UIStyle.BLUE, 22, Vector2(170, 56))
		save.name = "SaveName"
		save.pressed.connect(func():
			var n := le.text.strip_edges()
			if n != "":
				EconomyManager.player_name = n
				EconomyManager.save_game()
				save.text = "Saved")
		name_row.add_child(save)
		v.add_child(name_row)
		var reset := UIStyle.button("Reset progress", UIStyle.RED, 22, Vector2(0, 60))
		reset.name = "ResetProgress"
		v.add_child(reset)
		var confirm := HBoxContainer.new()
		confirm.visible = false
		confirm.add_theme_constant_override("separation", 10)
		var warn := UIStyle.label("Delete all gold, cards and trophies?", 18, Color("#ffb0b0"), 4, HORIZONTAL_ALIGNMENT_LEFT)
		warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		confirm.add_child(warn)
		var yes := UIStyle.button("Yes, reset", UIStyle.RED, 20, Vector2(150, 56))
		yes.name = "ConfirmReset"
		yes.pressed.connect(func():
			EconomyManager.reset_profile()
			p.close()
			GameManager.goto_menu())
		confirm.add_child(yes)
		var no := UIStyle.button("Cancel", UIStyle.BLUE, 20, Vector2(120, 56))
		no.pressed.connect(func(): confirm.visible = false; reset.visible = true)
		confirm.add_child(no)
		v.add_child(confirm)
		reset.pressed.connect(func(): reset.visible = false; confirm.visible = true)

	v.add_child(UIStyle.label("Royal Arena  ·  v" + VERSION, 16, Color("#8fa0c8"), 3))
	return p

static func _section(parent: Container, title: String) -> void:
	var l := UIStyle.label(title, 26, UIStyle.GOLD, 6, HORIZONTAL_ALIGNMENT_LEFT)
	parent.add_child(l)

static func _row(parent: Container, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)
	var l := UIStyle.label(label, 21, Color.WHITE, 4, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	parent.add_child(row)
	return row

static func _slider(parent: Container, label: String, key: String, value: float) -> HSlider:
	var row := _row(parent, label)
	var s := HSlider.new()
	s.name = "Slider_" + key
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 40)
	var track := UIStyle.box(Color(0, 0, 0, 0.45), 8)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", UIStyle.box(UIStyle.GREEN, 8))
	s.add_theme_stylebox_override("grabber_area_highlight", UIStyle.box(UIStyle.GREEN.lightened(0.15), 8))
	s.add_theme_icon_override("grabber", _knob(Color.WHITE))
	s.add_theme_icon_override("grabber_highlight", _knob(UIStyle.GOLD))
	var pct := UIStyle.label("%d%%" % int(value * 100), 20, Color("#c9d4ff"), 4, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(x: float):
		pct.text = "%d%%" % int(round(x * 100))
		SettingsManager.set_value(key, x))
	s.drag_ended.connect(func(_c):
		if key == "voice":
			AudioManager.play_voice("fire_knight_select")
		elif key == "sfx":
			AudioManager.play(&"coin"))
	row.add_child(s)
	row.add_child(pct)
	return s

static func _knob(c: Color) -> ImageTexture:
	var n := 34
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length()
			var a := clampf(n / 2.0 - d, 0, 1)
			var col := Color("#0e1428") if d > n / 2.0 - 3.0 else c
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

static func _toggle(parent: Container, label: String, key: String, value: bool) -> Button:
	var row := _row(parent, label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var b := UIStyle.button("ON" if value else "OFF", UIStyle.GREEN if value else Color("#6b7385"), 22, Vector2(120, 52))
	b.name = "Toggle_" + key
	b.toggle_mode = true
	b.button_pressed = value
	b.toggled.connect(func(on: bool):
		b.text = "ON" if on else "OFF"
		var col := UIStyle.GREEN if on else Color("#6b7385")
		for st in ["normal", "hover", "pressed"]:
			var sb := (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.bg_color = col if st != "hover" else col.lightened(0.1)
			sb.border_color = col.darkened(0.45)
			b.add_theme_stylebox_override(st, sb)
		SettingsManager.set_value(key, on))
	row.add_child(b)
	return b

static func _choice(parent: Container, label: String, key: String, names: Array, values: Array, current, hint := "") -> void:
	var row := _row(parent, label)
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(group)
	var buttons: Array[Button] = []
	for i in names.size():
		var b := UIStyle.button(names[i], UIStyle.BLUE if values[i] == current else Color("#3a4a6e"), 20, Vector2(110, 50))
		b.name = "Choice_%s_%s" % [key, str(values[i])]
		buttons.append(b)
		group.add_child(b)
	for i in buttons.size():
		var val = values[i]
		buttons[i].pressed.connect(func():
			SettingsManager.set_value(key, val)
			for j in buttons.size():
				var col := UIStyle.BLUE if j == i else Color("#3a4a6e")
				for st in ["normal", "hover", "pressed"]:
					var sb := (buttons[j].get_theme_stylebox(st) as StyleBoxFlat).duplicate() as StyleBoxFlat
					sb.bg_color = col if st != "hover" else col.lightened(0.1)
					sb.border_color = col.darkened(0.45)
					buttons[j].add_theme_stylebox_override(st, sb))
	if hint != "":
		var h := UIStyle.label(hint, 16, Color("#9fb3dd"), 3, HORIZONTAL_ALIGNMENT_LEFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(h)
