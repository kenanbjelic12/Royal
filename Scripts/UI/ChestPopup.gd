class_name ChestPopup
extends Control
## Chest opening sequence: chest shakes, bursts open with rays and sparkles,
## then gold and each card reward pop out one by one.

const CHEST_COLORS := {"gold": Color("#ffc22e"), "rare": Color("#3d8bff"), "epic": Color("#b04dff")}

var rewards: Dictionary
var _center: Control
var _chest: Control
var _view: ChestView   # 3D Meshy chest when available
var _rays: Control
var _items: HBoxContainer
var _t := 0.0
var _done := false

static func show_rewards(parent: Node, p_rewards: Dictionary) -> ChestPopup:
	var c := ChestPopup.new()
	c.rewards = p_rewards
	parent.add_child(c)
	return c

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var type: String = rewards.get("type", "gold")
	v.add_child(UIStyle.label(EconomyManager.CHESTS[type].name, 44, UIStyle.GOLD, 9))
	_center = CenterContainer.new()
	_center.custom_minimum_size = Vector2(0, 260)
	v.add_child(_center)
	if ChestView.available(type):
		_view = ChestView.make(type, true)
		_view.custom_minimum_size = Vector2(340, 300)
		_chest = _view
	else:
		var ic := UIIcon.new()
		ic.kind = &"chest"
		ic.tint = CHEST_COLORS.get(type, Color("#b8722c"))
		ic.custom_minimum_size = Vector2(220, 220)
		_chest = ic
	_center.add_child(_chest)
	_items = HBoxContainer.new()
	_items.alignment = BoxContainer.ALIGNMENT_CENTER
	_items.add_theme_constant_override("separation", 14)
	_items.custom_minimum_size = Vector2(0, 220)
	v.add_child(_items)
	var btn := UIStyle.button("Collect", UIStyle.GREEN, 30, Vector2(240, 80))
	btn.name = "Collect"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.modulate.a = 0.0
	btn.pressed.connect(queue_free)
	v.add_child(btn)
	_sequence(btn)

func _sequence(btn: Button) -> void:
	_chest.pivot_offset = _chest.custom_minimum_size * 0.5
	var tw := create_tween()
	if _view != null:
		tw.tween_interval(0.35)
		tw.tween_callback(func(): _view.shake(0.9))
		tw.tween_interval(0.9)
		tw.tween_callback(func():
			AudioManager.play(&"chest_open")
			_view.open()
			_done = true)
		tw.tween_interval(0.45)
	for i in (0 if _view != null else 6):
		tw.tween_property(_chest, "rotation", 0.12 * (1 if i % 2 == 0 else -1), 0.06)
	if _view == null:
		tw.tween_property(_chest, "rotation", 0.0, 0.05)
		tw.tween_callback(func():
			AudioManager.play(&"chest_open")
			_done = true
			_chest.scale = Vector2(1.25, 1.25))
		tw.tween_property(_chest, "scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_BACK)
	# gold first
	tw.tween_callback(func(): _add_item(&"gold", "+%d" % int(rewards.get("gold", 0)), "Gold"))
	tw.tween_interval(0.35)
	var cards: Dictionary = rewards.get("cards", {})
	for id in cards:
		var d: MonsterData = CardDatabase.get_card(id)
		if d == null:
			continue
		tw.tween_callback(func(): _add_card(d, int(cards[id])))
		tw.tween_interval(0.35)
	tw.tween_property(btn, "modulate:a", 1.0, 0.25)

func _add_item(icon: StringName, value: String, caption: String) -> void:
	AudioManager.play(&"coin")
	var box := VBoxContainer.new()
	var ic := UIIcon.new()
	ic.kind = icon
	ic.custom_minimum_size = Vector2(96, 96)
	box.add_child(ic)
	box.add_child(UIStyle.label(value, 32, Color.WHITE, 7))
	box.add_child(UIStyle.label(caption, 18, Color("#c9d4ff"), 4))
	_pop(box)

func _add_card(d: MonsterData, n: int) -> void:
	AudioManager.play(&"card_select")
	var box := VBoxContainer.new()
	var cv := CardView.new().setup(d, EconomyManager.get_card_level(d.id))
	cv.custom_minimum_size = Vector2(100, 128)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cv)
	box.add_child(UIStyle.label("x%d" % n, 30, Color.WHITE, 7))
	_pop(box)

func _pop(c: Control) -> void:
	_items.add_child(c)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)

func _process(delta: float) -> void:
	_t += delta
	_rays.queue_redraw()

func _draw_rays() -> void:
	if not _done:
		return
	var c := _center.get_global_rect().get_center()
	var tc: Color = CHEST_COLORS.get(rewards.get("type", "gold"), Color(1, 0.85, 0.35)).lightened(0.25)
	for i in 14:
		var a := i * TAU / 14.0 + _t * 0.4
		var p1 := c + Vector2(cos(a - 0.09), sin(a - 0.09)) * 900.0
		var p2 := c + Vector2(cos(a + 0.09), sin(a + 0.09)) * 900.0
		_rays.draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(tc.r, tc.g, tc.b, 0.13))
	_rays.draw_circle(c, 150.0, Color(tc.r, tc.g, tc.b, 0.14))
