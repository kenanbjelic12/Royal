class_name CurrencyBar
extends HBoxContainer
## Gold + gems pills that refresh whenever the economy changes and play a
## little bump animation when a value goes up.

var _gold: PanelContainer
var _gems: PanelContainer
var _last_gold := -1
var _last_gems := -1

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_END
	_gold = UIStyle.currency_pill(&"gold", "0", 150)
	_gems = UIStyle.currency_pill(&"gem", "0", 120)
	add_child(_gold)
	add_child(_gems)
	EconomyManager.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	_apply(_gold, EconomyManager.gold, _last_gold)
	_apply(_gems, EconomyManager.gems, _last_gems)
	_last_gold = EconomyManager.gold
	_last_gems = EconomyManager.gems

func _apply(pill: PanelContainer, v: int, last: int) -> void:
	var l: Label = pill.find_child("Value", true, false)
	l.text = _fmt(v)
	if last >= 0 and v > last:
		pill.pivot_offset = pill.size * 0.5
		var tw := pill.create_tween()
		tw.tween_property(pill, "scale", Vector2(1.15, 1.15), 0.1)
		tw.tween_property(pill, "scale", Vector2.ONE, 0.2)

static func _fmt(v: int) -> String:
	if v >= 100000:
		return "%dk" % (v / 1000)
	var s := str(v)
	if v >= 1000:
		s = "%d,%03d" % [v / 1000, v % 1000]
	return s
