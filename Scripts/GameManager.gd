extends Node
## Autoload: scene flow, battle results and rewards.

const SCENE_MENU := "res://Scenes/MainMenu/MainMenu.tscn"
const SCENE_BATTLE := "res://Scenes/Battle/Battle.tscn"
const SCENE_CARDS := "res://Scenes/Cards/CardsMenu.tscn"
const SCENE_SHOP := "res://Scenes/Shop/Shop.tscn"
const SCENE_VICTORY := "res://Scenes/Victory/Victory.tscn"
const SCENE_DEFEAT := "res://Scenes/Defeat/Defeat.tscn"

const WIN_TROPHIES := 30
const LOSS_TROPHIES := 20

var last_result: Dictionary = {}

func goto(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Scene not available yet: " + path)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

func goto_menu() -> void:
	goto(SCENE_MENU if ResourceLoader.exists(SCENE_MENU) else SCENE_BATTLE)

func goto_battle() -> void:
	goto(SCENE_BATTLE)

func goto_result() -> void:
	var path := SCENE_VICTORY if last_result.get("won", false) else SCENE_DEFEAT
	goto(path if ResourceLoader.exists(path) else SCENE_BATTLE)

func player_level() -> int:
	return EconomyManager.level

## Fair matchmaking for the test build: the AI mirrors the player's levels.
func enemy_level() -> int:
	return EconomyManager.level

func enemy_card_level(id: StringName) -> int:
	return EconomyManager.get_card_level(id)

## Converts a raw battle result into rewards and applies them to the economy.
func apply_battle_result(r: Dictionary) -> Dictionary:
	var rewards := {"trophies": 0, "gold": 0, "xp": 0, "chest": ""}
	if r.get("draw", false):
		rewards.gold = 10
		rewards.xp = 5
	elif r.get("won", false):
		rewards.trophies = WIN_TROPHIES
		rewards.gold = 40 + 20 * int(r.get("crowns_player", 0))
		rewards.xp = 20
		rewards.chest = EconomyManager.award_chest()
	else:
		rewards.trophies = -mini(LOSS_TROPHIES, EconomyManager.trophies)
		rewards.gold = 5 * int(r.get("crowns_player", 0))
		rewards.xp = 5
	EconomyManager.apply_battle_rewards(rewards, r)
	last_result = r.duplicate()
	last_result.merge(rewards, true)
	return rewards
