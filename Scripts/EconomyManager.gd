extends Node
## Autoload: local, simulated economy (no real purchases). Gold, gems,
## trophies, player level/XP, card levels & copies, chests and quests.
## Saved to user://save.cfg.

signal changed

const SAVE_PATH := "user://save.cfg"
const MAX_CARD_LEVEL := 9
const CHEST_SLOTS := 4
## Copies and gold needed to go from level N to N+1.
const UPGRADE_COPIES := [0, 2, 4, 10, 20, 50, 100, 200, 400]
const UPGRADE_GOLD := [0, 5, 20, 50, 150, 400, 1000, 2000, 4000]
const XP_PER_LEVEL := [0, 20, 50, 100, 200, 400, 800, 1600, 3200, 6400]

## Chest types: unlock time in seconds (shortened for the test build).
const CHESTS := {
	"wooden": {"name": "Wooden Chest", "unlock": 15, "gold": [20, 40], "cards": 6, "gems_open": 2},
	"silver": {"name": "Silver Chest", "unlock": 60, "gold": [50, 90], "cards": 15, "gems_open": 6},
	"golden": {"name": "Golden Chest", "unlock": 180, "gold": [150, 260], "cards": 40, "gems_open": 18},
	"magic": {"name": "Magical Chest", "unlock": 300, "gold": [400, 600], "cards": 90, "gems_open": 40},
}
const CHEST_CYCLE := ["wooden", "silver", "wooden", "silver", "golden", "wooden", "silver", "silver", "magic"]

var persist := true
var player_name := "Player"
var gold := 500
var gems := 100
var trophies := 0
var level := 1
var xp := 0
var card_levels: Dictionary = {}
var card_copies: Dictionary = {}
var chests: Array = []              # [{type, unlock_at (unix) or -1 locked, unlocking}]
var chest_cycle_index := 0
var wins := 0
var losses := 0
var battles := 0
var quests: Dictionary = {}         # id -> {progress, claimed, day}
var shop_day := ""
var shop_bought: Dictionary = {}
var deck: Array = []                # 8 card ids chosen in the Cards menu

func _ready() -> void:
	load_game()

# ------------------------------------------------------------------ persistence
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_name = cfg.get_value("player", "name", player_name)
		gold = cfg.get_value("player", "gold", gold)
		gems = cfg.get_value("player", "gems", gems)
		trophies = cfg.get_value("player", "trophies", trophies)
		level = cfg.get_value("player", "level", level)
		xp = cfg.get_value("player", "xp", xp)
		wins = cfg.get_value("player", "wins", 0)
		losses = cfg.get_value("player", "losses", 0)
		battles = cfg.get_value("player", "battles", 0)
		card_levels = cfg.get_value("cards", "levels", {})
		card_copies = cfg.get_value("cards", "copies", {})
		chests = cfg.get_value("chests", "slots", [])
		chest_cycle_index = cfg.get_value("chests", "cycle", 0)
		quests = cfg.get_value("quests", "state", {})
		shop_day = cfg.get_value("shop", "day", "")
		shop_bought = cfg.get_value("shop", "bought", {})
		deck = cfg.get_value("cards", "deck", [])

func save_game() -> void:
	changed.emit()
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "gold", gold)
	cfg.set_value("player", "gems", gems)
	cfg.set_value("player", "trophies", trophies)
	cfg.set_value("player", "level", level)
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "wins", wins)
	cfg.set_value("player", "losses", losses)
	cfg.set_value("player", "battles", battles)
	cfg.set_value("cards", "levels", card_levels)
	cfg.set_value("cards", "copies", card_copies)
	cfg.set_value("cards", "deck", deck)
	cfg.set_value("chests", "slots", chests)
	cfg.set_value("chests", "cycle", chest_cycle_index)
	cfg.set_value("quests", "state", quests)
	cfg.set_value("shop", "day", shop_day)
	cfg.set_value("shop", "bought", shop_bought)
	cfg.save(SAVE_PATH)

## Resets to a fresh profile (used by tests and the settings menu).
func reset_profile() -> void:
	gold = 500
	gems = 100
	trophies = 0
	level = 1
	xp = 0
	wins = 0
	losses = 0
	battles = 0
	card_levels = {}
	card_copies = {}
	chests = []
	chest_cycle_index = 0
	quests = {}
	shop_day = ""
	shop_bought = {}
	deck = []
	save_game()

# ------------------------------------------------------------------ currencies
func add_gold(n: int) -> void:
	gold += n
	save_game()

func spend_gold(n: int) -> bool:
	if gold < n:
		return false
	gold -= n
	save_game()
	return true

func add_gems(n: int) -> void:
	gems += n
	save_game()

func spend_gems(n: int) -> bool:
	if gems < n:
		return false
	gems -= n
	save_game()
	return true

func add_xp(n: int) -> void:
	xp += n
	while level < XP_PER_LEVEL.size() and xp >= XP_PER_LEVEL[level]:
		xp -= XP_PER_LEVEL[level]
		level += 1
	save_game()

func xp_needed() -> int:
	return XP_PER_LEVEL[mini(level, XP_PER_LEVEL.size() - 1)]

func arena_name() -> String:
	if trophies >= 600: return "Crystal Peaks"
	if trophies >= 300: return "Golem Quarry"
	return "Meadow Kingdom"

# ------------------------------------------------------------------ cards
func get_card_level(id: StringName) -> int:
	return int(card_levels.get(String(id), 1))

func get_card_copies(id: StringName) -> int:
	return int(card_copies.get(String(id), 0))

func add_card_copies(id: StringName, n: int) -> void:
	card_copies[String(id)] = get_card_copies(id) + n
	save_game()

func upgrade_cost(id: StringName) -> Dictionary:
	var lv := get_card_level(id)
	if lv >= MAX_CARD_LEVEL:
		return {"copies": 0, "gold": 0, "max": true}
	return {"copies": UPGRADE_COPIES[lv], "gold": UPGRADE_GOLD[lv], "max": false}

func can_upgrade(id: StringName) -> bool:
	var c := upgrade_cost(id)
	return not c.max and get_card_copies(id) >= c.copies and gold >= c.gold

func upgrade_card(id: StringName) -> bool:
	if not can_upgrade(id):
		return false
	var c := upgrade_cost(id)
	card_copies[String(id)] = get_card_copies(id) - c.copies
	gold -= c.gold
	card_levels[String(id)] = get_card_level(id) + 1
	add_xp(4 * get_card_level(id))
	save_game()
	return true

## Puts `card_id` into the battle deck in place of `replace_id`.
func swap_deck_card(card_id: StringName, replace_id: StringName) -> bool:
	if deck.is_empty():
		deck = CardDatabase.DEFAULT_DECK.map(func(x): return String(x))
	var i := deck.find(String(replace_id))
	if i < 0 or deck.has(String(card_id)):
		return false
	deck[i] = String(card_id)
	save_game()
	return true

func deck_ids() -> Array:
	if deck.size() < CardDatabase.DECK_SIZE:
		return CardDatabase.DEFAULT_DECK.map(func(x): return String(x))
	return deck

# ------------------------------------------------------------------ chests
func award_chest() -> String:
	if chests.size() >= CHEST_SLOTS:
		return ""
	var type: String = CHEST_CYCLE[chest_cycle_index % CHEST_CYCLE.size()]
	chest_cycle_index += 1
	chests.append({"type": type, "unlock_at": -1})
	save_game()
	return type

func now() -> int:
	return int(Time.get_unix_time_from_system())

func any_unlocking() -> bool:
	for c in chests:
		if c.unlock_at > 0 and c.unlock_at > now():
			return true
	return false

func start_unlock(i: int) -> bool:
	if i < 0 or i >= chests.size() or chests[i].unlock_at > 0 or any_unlocking():
		return false
	chests[i].unlock_at = now() + int(CHESTS[chests[i].type].unlock)
	save_game()
	return true

func chest_ready(i: int) -> bool:
	return i >= 0 and i < chests.size() and chests[i].unlock_at > 0 and chests[i].unlock_at <= now()

func chest_time_left(i: int) -> int:
	if i < 0 or i >= chests.size() or chests[i].unlock_at <= 0:
		return -1
	return maxi(0, int(chests[i].unlock_at) - now())

func chest_gem_cost(i: int) -> int:
	var t := chest_time_left(i)
	var base: int = CHESTS[chests[i].type].gems_open
	if t < 0:
		return base
	return maxi(1, int(ceil(base * float(t) / float(CHESTS[chests[i].type].unlock))))

## Opens a chest (ready, or paying gems). Returns the rewards.
func open_chest(i: int, pay_gems := false) -> Dictionary:
	if i < 0 or i >= chests.size():
		return {}
	if not chest_ready(i):
		if not pay_gems or not spend_gems(chest_gem_cost(i)):
			return {}
	var type: String = chests[i].type
	chests.remove_at(i)
	var rewards := roll_chest(type)
	save_game()
	return rewards

func roll_chest(type: String) -> Dictionary:
	var def: Dictionary = CHESTS[type]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var g := rng.randi_range(def.gold[0], def.gold[1])
	gold += g
	var cards := {}
	var remaining: int = def.cards
	var deck := CardDatabase.deck()
	while remaining > 0 and not deck.is_empty():
		var c: MonsterData = deck[rng.randi() % deck.size()]
		var weight: int = [4, 3, 2, 1][c.rarity]
		var n := mini(remaining, rng.randi_range(1, weight * 2))
		cards[c.id] = cards.get(c.id, 0) + n
		remaining -= n
	for id in cards:
		card_copies[String(id)] = get_card_copies(id) + cards[id]
	save_game()
	return {"type": type, "gold": g, "cards": cards}

# ------------------------------------------------------------------ battle
func apply_battle_rewards(rewards: Dictionary, r: Dictionary) -> void:
	battles += 1
	if r.get("won", false):
		wins += 1
	elif not r.get("draw", false):
		losses += 1
	trophies = maxi(0, trophies + int(rewards.trophies))
	gold += int(rewards.gold)
	add_quest_progress("play_battles", 1)
	if r.get("won", false):
		add_quest_progress("win_battles", 1)
	add_quest_progress("crowns", int(r.get("crowns_player", 0)))
	add_xp(int(rewards.xp))
	save_game()

# ------------------------------------------------------------------ quests
const QUEST_DEFS := [
	{"id": "play_battles", "title": "Play 3 battles", "goal": 3, "reward_gold": 100, "reward_gems": 0},
	{"id": "win_battles", "title": "Win 2 battles", "goal": 2, "reward_gold": 150, "reward_gems": 5},
	{"id": "crowns", "title": "Collect 5 crowns", "goal": 5, "reward_gold": 0, "reward_gems": 10},
	{"id": "deploy", "title": "Summon 25 monsters", "goal": 25, "reward_gold": 120, "reward_gems": 0},
]

func today() -> String:
	return Time.get_date_string_from_system()

func _quest(id: String) -> Dictionary:
	var q: Dictionary = quests.get(id, {})
	if q.get("day", "") != today():
		q = {"progress": 0, "claimed": false, "day": today()}
		quests[id] = q
	return q

func add_quest_progress(id: String, n: int) -> void:
	var q := _quest(id)
	q.progress = int(q.progress) + n
	quests[id] = q

func quest_state(id: String) -> Dictionary:
	return _quest(id)

func claim_quest(id: String) -> bool:
	for d in QUEST_DEFS:
		if d.id == id:
			var q := _quest(id)
			if q.claimed or int(q.progress) < int(d.goal):
				return false
			q.claimed = true
			quests[id] = q
			gold += int(d.reward_gold)
			gems += int(d.reward_gems)
			save_game()
			return true
	return false

func quests_claimable() -> int:
	var n := 0
	for d in QUEST_DEFS:
		var q := _quest(d.id)
		if not q.claimed and int(q.progress) >= int(d.goal):
			n += 1
	return n
