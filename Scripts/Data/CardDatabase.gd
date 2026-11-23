extends Node
## Autoload: loads every MonsterData resource from res://Data/Cards/.
## New cards are picked up automatically – just drop a new .tres in the folder.

const CARD_DIR := "res://Data/Cards/"
const PORTRAIT_DIR := "res://Assets/Cards/"
## Display order of the test deck.
const DECK_ORDER: Array[StringName] = [&"fire_knight", &"shadow_assassin", &"stone_golem", &"frost_dragon", &"poison_witch",
	&"thunder_mage", &"healing_fairy", &"goblin_gang", &"viking_berserker", &"bomb_pirate", &"skeleton_squad"]
const DECK_SIZE := 8
const DEFAULT_DECK: Array[StringName] = [&"fire_knight", &"shadow_assassin", &"stone_golem", &"frost_dragon", &"poison_witch",
	&"thunder_mage", &"goblin_gang", &"bomb_pirate"]

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

## Cards for a list of ids (unknown ids are skipped).
func cards_for(ids: Array) -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for id in ids:
		var c := get_card(StringName(id))
		if c:
			out.append(c)
	return out

## The player's chosen 8-card battle deck.
func battle_deck() -> Array[MonsterData]:
	var d := cards_for(EconomyManager.deck_ids())
	if d.size() < mini(DECK_SIZE, cards.size()):
		d = cards_for(DEFAULT_DECK)
	return d

## A balanced random deck for the AI: always some anti-air and a tank.
func random_deck(rng: RandomNumberGenerator) -> Array[MonsterData]:
	var all := deck()
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := all[i]
		all[i] = all[j]
		all[j] = tmp
	var out: Array[MonsterData] = all.slice(0, mini(DECK_SIZE, all.size()))
	var anti_air := out.filter(func(c): return c.can_hit_air and c.target_type == MonsterData.TargetType.ANY).size()
	if anti_air < 2:
		for c in all:
			if not out.has(c) and c.can_hit_air and c.target_type == MonsterData.TargetType.ANY:
				out[out.size() - 1 - anti_air] = c
				anti_air += 1
				if anti_air >= 2:
					break
	return out

## Whole collection in display order.
func deck() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for id in DECK_ORDER:
		if cards.has(id):
			out.append(cards[id])
	for id in cards:  # any extra cards added later
		if not DECK_ORDER.has(id):
			out.append(cards[id])
	return out
