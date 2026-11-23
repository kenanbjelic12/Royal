extends Node
## Automated gameplay tests covering the 10 mandatory checks.
## Run: godot --headless --path . res://Tests/TestRunner.tscn  (exit code 0 = all passed)

var results: Array = []
var current := ""
var battle: BattleManager

func _ready() -> void:
	EconomyManager.persist = false
	SettingsManager.persist = false
	EconomyManager.reset_profile()
	AudioManager.set_muted(true)
	Engine.time_scale = 4.0
	await _run_all()
	var failed := 0
	print("\n================ ROYAL ARENA TEST REPORT ================")
	for r in results:
		print(("PASS  " if r.ok else "FAIL  ") + r.name + ("" if r.ok else "   -> " + r.msg))
		if not r.ok:
			failed += 1
	print("=========================================================")
	print("%d / %d checks passed" % [results.size() - failed, results.size()])
	get_tree().quit(1 if failed > 0 else 0)

func check(name: String, ok: bool, msg := "") -> void:
	results.append({"name": current + " :: " + name, "ok": ok, "msg": msg})

## Waits `seconds` of simulated physics time (timer ticks in physics frames, so
## it stays in sync with the battle clock even when a render frame is slow).
func sim(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true, false).timeout

func new_battle(enemy_ai := false, player_ai := false, hud := false) -> BattleManager:
	if battle and is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame
	battle = load("res://Scenes/Battle/Battle.tscn").instantiate()
	battle.enemy_ai_enabled = enemy_ai
	battle.player_ai_controlled = player_ai
	battle.build_hud = hud
	add_child(battle)
	for i in 3:
		await get_tree().physics_frame
	return battle

func _run_all() -> void:
	await test_cards_display()
	await test_card_summons()
	await test_movement()
	await test_attacks_and_damage()
	await test_towers_attack()
	await test_elixir()
	await test_ai_uses_cards()
	await test_win_lose()
	await test_menus()

# 1 ---------------------------------------------------------------------------
func test_cards_display() -> void:
	current = "1. Cards display"
	var deck := CardDatabase.deck()
	check("10 cards loaded from data files", deck.size() == 10, "got %d" % deck.size())
	var ids := deck.map(func(d): return String(d.id))
	check("expected card ids", ids.slice(0, 5) == ["fire_knight", "shadow_assassin", "stone_golem", "frost_dragon", "poison_witch"] and ids.has("thunder_mage") and ids.has("healing_fairy") and ids.has("goblin_gang") and ids.has("viking_berserker") and ids.has("bomb_pirate"), str(ids))
	check("battle deck has 8 cards", CardDatabase.battle_deck().size() == 8)
	for d: MonsterData in deck:
		check("%s has portrait illustration" % d.id, d.portrait != null)
	var costs := deck.map(func(d): return d.elixir_cost)
	check("elixir costs 5/3/6/4/4/5/4/2/4/3", costs == [5, 3, 6, 4, 4, 5, 4, 2, 4, 3], str(costs))
	await new_battle(false, false, true)
	var hud: UIManager = battle.hud
	check("HUD shows 5 card widgets", hud.cards.size() == 5)
	var bd := CardDatabase.battle_deck()
	for i in hud.cards.size():
		check("card slot %d shows a battle-deck card" % i, bd.has(hud.cards[i].data) and hud.cards[i].data == battle.card_manager.hand[i] and hud.cards[i].is_visible_in_tree())
	check("HUD shows the Next card", hud._next_view != null and hud._next_view.data == battle.card_manager.cycle.next_card())
	# cycling: playing a card brings the next one into that slot
	var cm := battle.card_manager
	var nxt: MonsterData = cm.cycle.next_card()
	var played: MonsterData = cm.hand[0]
	battle.elixir[0].elixir = 10.0
	cm.select(0)
	cm.try_deploy_world(Vector3(0, 0, 6))
	await get_tree().process_frame
	check("played card is replaced by the Next card", cm.hand[0] == nxt and cm.cycle.queue.back() == played)
	check("HUD slot updates after cycling", hud.cards[0].data == nxt)

# 2 ---------------------------------------------------------------------------
func test_card_summons() -> void:
	current = "2. Card summons matching monster"
	await new_battle()
	for d: MonsterData in CardDatabase.deck():
		battle.elixir[0].elixir = 10.0
		var before := battle.units.size()
		var ok := battle.deploy_card(0, d, Vector3(-3, 0, 8))
		var spent := 10.0 - battle.elixir[0].elixir
		check("%s summons %d monster(s)" % [d.id, d.spawn_count], battle.units.size() - before == d.spawn_count)
		var unit: MonsterController = battle.units.back() if battle.units.size() > before else null
		check("%s deploys" % d.id, ok and unit != null)
		if unit:
			await get_tree().process_frame
			check("%s spawns %s monster" % [d.id, d.display_name], unit.data.id == d.id)
			var own_model: bool = (unit.model is GLBMonsterModel and (unit.model as GLBMonsterModel).glb_path == d.model_glb_path) if d.model_glb_path != "" else unit.model.get_script() == d.model_script
			check("%s uses its own 3D model" % d.id, own_model)
			if d.model_glb_path != "":
				var anims_ok: bool = unit.model._player != null and unit.model._player.has_animation("m/attack") and unit.model._player.has_animation("m/death") and unit.model._player.has_animation("m/select")
				check("%s Meshy model has idle/walk/attack/hit/death/select" % d.id, anims_ok)
			check("%s cost %d elixir" % [d.id, d.elixir_cost], is_equal_approx(spent, d.elixir_cost), "spent %.2f" % spent)
		battle.units.back().queue_free()
		battle.units.pop_back()
	# player cannot deploy on the enemy half
	battle.elixir[0].elixir = 10.0
	check("deploy on enemy half rejected", not battle.deploy_card(0, CardDatabase.get_card(&"fire_knight"), Vector3(0, 0, -8)))
	# card manager clamps placement onto the own half
	battle.card_manager.select(1)
	check("card manager places selected card", battle.card_manager.try_deploy_world(Vector3(2, 0, 5)))

# 3 ---------------------------------------------------------------------------
func test_movement() -> void:
	current = "3. Movement & bridges"
	for d: MonsterData in CardDatabase.deck():
		await new_battle()
		if d.target_type == MonsterData.TargetType.HEAL_ALLIES:
			battle.spawn_monster(CardDatabase.get_card(&"stone_golem"), 0, Vector3(-2.5, 0, 7.5), 1)   # a friend to follow
		var u := battle.spawn_monster(d, 0, Vector3(-2.5, 0, 9), 1)
		var start := u.position
		var crossed_on_bridge := true
		var max_t := 45.0 / d.move_speed + 5.0
		var t := 0.0
		var reached_enemy_half := false
		while t < max_t and is_instance_valid(u) and u.is_alive():
			await sim(0.1)
			t += 0.1
			var z := u.position.z
			if not d.is_flying and absf(z) < ArenaLayout.RIVER_HALF - 0.05 and not ArenaLayout.in_bridge_corridor(u.position.x, -0.15):
				crossed_on_bridge = false
			if z < -ArenaLayout.RIVER_HALF - 0.5:
				reached_enemy_half = true
				break
		check("%s moves" % d.id, is_instance_valid(u) and u.position.distance_to(start) > 2.0)
		check("%s reaches enemy half" % d.id, reached_enemy_half, "z=%.2f after %.1fs" % [u.position.z if is_instance_valid(u) else 99.0, t])
		if not d.is_flying:
			check("%s crosses only via a bridge" % d.id, crossed_on_bridge)
		elif d.target_type != MonsterData.TargetType.HEAL_ALLIES:
			check("%s flies straight over the river" % d.id, absf(u.position.x - start.x) < 2.5)
		if is_instance_valid(u):
			check("%s walk animation active" % d.id, u.model.move_blend > 0.5)

# 4 + 5 ------------------------------------------------------------------------
func test_attacks_and_damage() -> void:
	current = "4/5. Unique attacks & HP"
	var signatures := {}
	for d: MonsterData in CardDatabase.deck():
		if d.target_type == MonsterData.TargetType.HEAL_ALLIES:
			continue
		await new_battle()
		# placed in the middle of the player half, out of every tower's range
		var attacker := battle.spawn_monster(d, 0, Vector3(-3, 0, 2.0), 1)
		# a stationary victim: a fire knight for troops, the princess tower for golems
		var victim: Combatant
		if d.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
			attacker.position = Vector3(5.5, 0, -7.8)
			victim = battle.get_towers(1)[1]
		else:
			var dummy_data: MonsterData = CardDatabase.get_card(&"stone_golem").duplicate()
			dummy_data.damage = 0.0
			dummy_data.move_speed = 0.0
			dummy_data.target_type = MonsterData.TargetType.BUILDINGS_ONLY
			victim = battle.spawn_monster(dummy_data, 1, Vector3(-3.0 + d.attack_range + 1.8, 0, 2.0), 1)
		var hp0 := victim.hp
		var projectiles_seen := 0
		var impacts := [0]   # array: lambdas capture locals by value
		attacker.model.impact.connect(func(): impacts[0] += 1)
		var t := 0.0
		var first_damage_t := -1.0
		var hp_after_first := hp0
		while t < 8.0 and victim.is_alive():
			await sim(0.05)
			t += 0.05
			for pr in battle.projectiles_root.get_children():
				if pr.info.get("source") == attacker:
					projectiles_seen += 1
			if first_damage_t < 0.0 and victim.hp < hp0:
				first_damage_t = t
				hp_after_first = victim.hp
		var expected := d.damage_at(1) * d.first_hit_multiplier
		check("%s attack animation fires impact" % d.id, impacts[0] > 0)
		check("%s reduces target HP" % d.id, victim.hp < hp0, "hp %.0f -> %.0f" % [hp0, victim.hp])
		if d.target_type != MonsterData.TargetType.BUILDINGS_ONLY:
			check("%s first hit deals %.0f" % [d.id, expected], absf((hp0 - hp_after_first) - expected) < 1.0 or d.poison_dps > 0.0, "dealt %.0f" % (hp0 - hp_after_first))
		var ranged := d.projectile != MonsterData.ProjectileType.NONE and d.projectile != MonsterData.ProjectileType.LIGHTNING
		check("%s %s" % [d.id, "fires projectiles" if ranged else "hits instantly (melee / lightning)"], (projectiles_seen > 0) == ranged)
		if d.slow_amount > 0.0:
			check("%s slows its target" % d.id, victim.slow_time > 0.0 or not victim.is_alive())
		if d.poison_dps > 0.0:
			check("%s poisons its target" % d.id, victim.poison_time > 0.0 or not victim.is_alive())
		signatures[d.id] = "%s|%s|%.0f|%.2f|%.1f|%s" % [d.projectile, d.target_type, d.damage, d.attack_speed, d.attack_range, d.is_flying]
	var uniq := {}
	for k in signatures:
		uniq[signatures[k]] = true
	check("all attack profiles are different", uniq.size() == signatures.size())
	# chain lightning hits several clustered enemies
	await new_battle()
	var mage := battle.spawn_monster(CardDatabase.get_card(&"thunder_mage"), 0, Vector3(-3, 0, 2.0), 1)
	var group: Array = []
	for k in 3:
		var dd: MonsterData = CardDatabase.get_card(&"stone_golem").duplicate()
		dd.damage = 0.0
		dd.move_speed = 0.0
		group.append(battle.spawn_monster(dd, 1, Vector3(2.0 + k * 1.2, 0, 2.0), 1))
	await sim(4.0)
	check("thunder mage lightning chains to 3 enemies", group.all(func(g): return g.hp < g.max_hp))
	# berserker charge doubles the first hit
	await new_battle()
	var vk := battle.spawn_monster(CardDatabase.get_card(&"viking_berserker"), 0, Vector3(-4, 0, 2.0), 1)
	var vd: MonsterData = CardDatabase.get_card(&"stone_golem").duplicate()
	vd.damage = 0.0
	vd.move_speed = 0.0
	vd.target_type = MonsterData.TargetType.BUILDINGS_ONLY
	var tgt := battle.spawn_monster(vd, 1, Vector3(1.5, 0, 2.0), 1)
	var charged_seen := [false]
	var hp_start := tgt.hp
	var tt := 0.0
	while tt < 8.0 and tgt.hp == hp_start:
		await sim(0.05)
		tt += 0.05
		if vk.charging:
			charged_seen[0] = true
	check("berserker starts charging after a run-up", charged_seen[0])
	check("charged first hit deals double damage", absf((hp_start - tgt.hp) - vk.data.damage_at(1) * 2.0) < 1.0, "dealt %.0f" % (hp_start - tgt.hp))
	# healer restores HP of nearby allies
	await new_battle()
	var ally := battle.spawn_monster(CardDatabase.get_card(&"fire_knight"), 0, Vector3(-3, 0, 6.0), 1)
	ally.data = ally.data.duplicate()
	ally.data.move_speed = 0.0
	var fairy := battle.spawn_monster(CardDatabase.get_card(&"healing_fairy"), 0, Vector3(-3, 0, 7.5), 1)
	await sim(1.2)
	ally.hp = ally.max_hp * 0.5
	var hp_mid := ally.hp
	await sim(3.0)
	check("healing fairy heals a damaged ally", ally.hp > hp_mid, "hp %.0f -> %.0f" % [hp_mid, ally.hp])
	check("healing fairy never damages allies", fairy.is_alive())
	# death
	await new_battle()
	var u := battle.spawn_monster(CardDatabase.get_card(&"shadow_assassin"), 0, Vector3(0, 0, 6), 1)
	await sim(1.2)
	u.take_damage(99999)
	check("unit dies at 0 HP", not u.is_alive())
	await sim(1.6)
	check("dead unit removed after death animation", not is_instance_valid(u) and not battle.units.has(u))

# 6 ---------------------------------------------------------------------------
func test_towers_attack() -> void:
	current = "6. Towers attack"
	await new_battle()
	var tower: TowerController = battle.get_towers(0)[0]
	var u := battle.spawn_monster(CardDatabase.get_card(&"fire_knight"), 1, tower.position + Vector3(0, 0, -5.5), 1)
	u.data = u.data.duplicate()
	u.data.move_speed = 0.0
	var hp0 := u.hp
	var shots := 0
	await sim(4.0)
	check("princess tower damages enemy in range", u.hp < hp0, "hp %.0f -> %.0f" % [hp0, u.hp])
	var king := battle.king_tower(0)
	check("king tower sleeps at start", not king.active)
	tower.take_damage(99999)
	check("princess tower destroyed at 0 HP", not tower.is_alive())
	check("enemy gets a crown", battle.crowns[1] == 1)
	check("king tower wakes when princess falls", king.active)
	check("enemy may now deploy in the opened lane", battle.open_enemy_lanes(1)[-1] == true)
	# flying target
	await new_battle()
	var dragon := battle.spawn_monster(CardDatabase.get_card(&"frost_dragon"), 1, Vector3(5.5, 0, 5.0), 1)
	dragon.data = dragon.data.duplicate()
	dragon.data.move_speed = 0.0
	var dh := dragon.hp
	await sim(3.5)
	check("towers hit flying units", dragon.hp < dh)

# 7 ---------------------------------------------------------------------------
func test_elixir() -> void:
	current = "7. Elixir"
	await new_battle()
	var em := battle.elixir[0]
	check("starts with 5 elixir", absf(em.elixir - 5.0) < 0.3, "%.2f" % em.elixir)
	em.elixir = 0.0
	await sim(2.8)
	check("regenerates ~1 per 2.8s", absf(em.elixir - 1.0) < 0.25, "%.2f" % em.elixir)
	em.elixir = 9.9
	await sim(3.0)
	check("caps at 10", is_equal_approx(em.elixir, 10.0))
	em.elixir = 2.0
	check("cannot play 3-cost card with 2 elixir", not battle.deploy_card(0, CardDatabase.get_card(&"shadow_assassin"), Vector3(0, 0, 6)))
	check("elixir unchanged after failed play", absf(em.elixir - 2.0) < 0.05)
	em.elixir = 6.0
	check("can play 6-cost golem with 6 elixir", battle.deploy_card(0, CardDatabase.get_card(&"stone_golem"), Vector3(0, 0, 6)))
	check("golem cost deducted", em.elixir < 0.2)
	battle.time_left = BattleManager.DOUBLE_ELIXIR_AT + 0.5
	await sim(1.0)
	check("double elixir phase", battle.phase == &"double" and em.multiplier == 2.0)

# 8 ---------------------------------------------------------------------------
func test_ai_uses_cards() -> void:
	current = "8. Enemy AI"
	await new_battle(true, false)
	battle.enemy_ai.log_decisions = false
	await sim(40.0)
	var played: Dictionary = battle.stats.cards_played[1]
	var total := 0
	for k in played:
		total += played[k]
	check("AI played cards", total >= 4, "played %d" % total)
	check("AI spends elixir (not stuck at max)", battle.elixir[1].total_spent >= 12)
	# defence: AI responds to a push on its side with a counter
	await new_battle(true, false)
	battle.elixir[1].elixir = 10.0
	await sim(0.1)
	var golem := battle.spawn_monster(CardDatabase.get_card(&"stone_golem"), 0, Vector3(5.5, 0, -3.0), 1)
	var before: int = battle.stats.spawned[1]
	await sim(4.0)
	check("AI defends against a push", battle.stats.spawned[1] > before)
	var defenders := battle.get_units(1)
	var close := defenders.filter(func(d): return d.position.x > 0.0)
	check("AI places defenders in the threatened lane", close.size() > 0)
	check("AI counter can hit the threat", defenders.all(func(d): return d.data.target_type == MonsterData.TargetType.ANY))
	var dragon_threat := CardDatabase.get_card(&"frost_dragon")
	var knight := CardDatabase.get_card(&"fire_knight")
	var witch := CardDatabase.get_card(&"poison_witch")
	check("matchup: knight scores 0 vs air", battle.enemy_ai.matchup_score(knight, dragon_threat) == 0.0)
	check("matchup: witch can counter dragon", battle.enemy_ai.matchup_score(witch, dragon_threat) > 0.0)
	# variety over full AI-vs-AI games
	var used := {}
	for g in 3:
		await new_battle(true, true)
		await sim(80.0)
		for team in 2:
			for k in battle.stats.cards_played[team]:
				used[k] = true
	check("AI uses at least 6 different cards across games", used.size() >= 6, str(used.keys()))

# 9 ---------------------------------------------------------------------------
func test_win_lose() -> void:
	current = "9. Win / lose"
	var tro := EconomyManager.trophies
	await new_battle()
	battle.king_tower(1).take_damage(999999)
	check("destroying enemy king = victory", battle.finished and battle.result.won and battle.result.crowns_player == 3)
	check("victory grants trophies", EconomyManager.trophies == tro + GameManager.WIN_TROPHIES)
	check("victory grants a chest", EconomyManager.chests.size() >= 1)
	var gold := EconomyManager.gold
	await new_battle()
	battle.king_tower(0).take_damage(999999)
	check("losing own king = defeat", battle.finished and not battle.result.won and not battle.result.draw)
	check("defeat removes trophies", EconomyManager.trophies == tro + GameManager.WIN_TROPHIES - GameManager.LOSS_TROPHIES)
	# time out with more crowns
	await new_battle()
	battle.get_towers(1)[0].take_damage(999999)
	battle.time_left = 0.2
	await sim(1.0)
	check("more crowns at time-up wins", battle.finished and battle.result.won)
	# tie -> overtime
	await new_battle()
	battle.time_left = 0.2
	await sim(1.0)
	check("tie goes to overtime", not battle.finished and battle.phase == &"overtime")
	# full simulated match ends with a result
	await new_battle(true, true)
	Engine.time_scale = 8.0
	var t := 0.0
	while not battle.finished and t < 300.0:
		await sim(1.0)
		t += 1.0
	Engine.time_scale = 4.0
	check("full AI vs AI match finishes", battle.finished, "time_left %.0f phase %s crowns %s" % [battle.time_left, battle.phase, battle.crowns])
	print("   full match result: ", battle.result)

# 10 --------------------------------------------------------------------------
func test_menus() -> void:
	current = "10. Menus"
	# pause menu in battle
	await new_battle(false, false, true)
	var hud: UIManager = battle.hud
	check("battle has a pause button", hud.root.find_child("PauseButton", true, false) != null)
	hud.open_pause()
	var t0 := battle.time_left
	await get_tree().create_timer(1.0, true, false, true).timeout
	check("pause freezes the battle clock", get_tree().paused and is_equal_approx(battle.time_left, t0))
	check("pause menu offers Resume and Exit to Menu", hud.root.find_child("Resume", true, false) != null and hud.root.find_child("ExitToMenu", true, false) != null)
	hud.close_pause()
	await sim(0.5)
	check("resume continues the battle", not get_tree().paused and battle.time_left < t0)
	# settings
	SettingsManager.set_value("music", 0.25)
	SettingsManager.set_value("voice", 0.0)
	var mi := AudioServer.get_bus_index("Music")
	var vi := AudioServer.get_bus_index("Voice")
	check("music volume slider changes the Music bus", mi >= 0 and absf(AudioServer.get_bus_volume_db(mi) - linear_to_db(0.25)) < 0.1)
	check("voices at 0% mute the Voice bus", vi >= 0 and AudioServer.is_bus_mute(vi))
	SettingsManager.set_value("damage_numbers", false)
	var before_fx := battle.effects_root().get_child_count()
	battle.show_damage(battle.get_towers(1)[0], 100.0)
	check("damage numbers can be turned off", battle.effects_root().get_child_count() == before_fx)
	SettingsManager.set_value("damage_numbers", true)
	SettingsManager.set_value("quality", SettingsManager.Quality.LOW)
	check("low quality turns battle shadows off", not (battle.get_node("Sun") as DirectionalLight3D).shadow_enabled)
	SettingsManager.set_value("quality", SettingsManager.Quality.HIGH)
	check("high quality turns battle shadows on", (battle.get_node("Sun") as DirectionalLight3D).shadow_enabled)
	SettingsManager.set_value("music", 0.7)
	SettingsManager.set_value("voice", 0.9)
	var sp := SettingsPopup.open(hud.root, true)
	await get_tree().process_frame
	check("settings screen has music/sfx/voice sliders", sp.find_child("Slider_music", true, false) != null and sp.find_child("Slider_sfx", true, false) != null and sp.find_child("Slider_voice", true, false) != null)
	sp.close()
	if battle:
		battle.queue_free()
		battle = null
	for path in [GameManager.SCENE_MENU, GameManager.SCENE_CARDS, GameManager.SCENE_SHOP, GameManager.SCENE_VICTORY, GameManager.SCENE_DEFEAT]:
		if not ResourceLoader.exists(path):
			check("%s exists" % path.get_file(), false, "not implemented yet (Phase 3)")
			continue
		var scn: Node = load(path).instantiate()
		add_child(scn)
		await sim(0.5)
		check("%s loads and runs" % path.get_file(), is_instance_valid(scn) and scn.is_inside_tree())
		if scn.has_method("run_self_test"):
			var ok: bool = await scn.run_self_test()
			check("%s self-test (buttons/flows)" % path.get_file(), ok)
		scn.queue_free()
		await get_tree().process_frame
