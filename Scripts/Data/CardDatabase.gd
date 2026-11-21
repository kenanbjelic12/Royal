extends Node
## Autoload: loads every MonsterData resource from res://Data/Cards/.
## New cards are picked up automatically – just drop a new .tres in the folder.

const CARD_DIR := "res://Data/Cards/"
const PORTRAIT_DIR := "res://Assets/Cards/"
## Display order of the test deck.
const DECK_ORDER: Array[StringName] = [&"fire_knight", &"shadow_assassin", &"stone_golem", &"frost_dragon", &"poison_witch"]

var cards: Dictionary = {}  # StringName -> MonsterData

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	cards.clear()
	var files := _list_dir(CARD_DIR)
	for f in files:
		var fname := String(f).trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res := load(CARD_DIR + fname)
		if res is MonsterData:
			var d: MonsterData = res
			if d.portrait == null:
				var p := PORTRAIT_DIR + String(d.id) + ".png"
				if ResourceLoader.exists(p):
					d.portrait = load(p)
			cards[d.id] = d
	if cards.is_empty():
		push_error("CardDatabase: no cards found in " + CARD_DIR)

func _list_dir(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			out.append(f)
		f = dir.get_next()
	return out

func get_card(id: StringName) -> MonsterData:
	return cards.get(id)

func deck() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for id in DECK_ORDER:
		if cards.has(id):
			out.append(cards[id])
	for id in cards:  # any extra cards added later
		if not DECK_ORDER.has(id):
			out.append(cards[id])
	return out
