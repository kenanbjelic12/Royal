class_name UIPopup
extends Control
## Modal popup: dimmed backdrop, rounded panel with title ribbon, content box
## and a close button. Pops in with a bounce.

signal closed

var panel: PanelContainer
var content: VBoxContainer
var title_label: Label

static func open(parent: Node, title: String, width := 600.0) -> UIPopup:
	var p := UIPopup.new()
	p._build(title, width)
	parent.add_child(p)
	return p

func _build(title: String, width: float) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	var sb := UIStyle.box(Color("#2b4374"), 26, Color("#0e1428"), 5, 10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_label = UIStyle.label(title, 36, UIStyle.GOLD, 8)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var x := UIStyle.button("X", UIStyle.RED, 26, Vector2(56, 56))
	x.name = "Close"
	x.pressed.connect(close)
	head.add_child(x)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	v.add_child(content)
	panel.pivot_offset = Vector2(width * 0.5, 200)
	panel.scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	closed.emit()
	queue_free()
