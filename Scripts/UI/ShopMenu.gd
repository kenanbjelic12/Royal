extends Control
## Shop with simulated, local-only purchases (no real money): Daily Deals,
## Special Offers, Chests, Cards, Gold and (test) Gems.

const CARD_PRICE := [20, 40, 150, 400]   # gold per copy by rarity

var _list: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_roll_day()
	var bg := UIStyle.gradient_rect(Color("#5a2d86"), Color("#151036"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var back := UIStyle.button("<", UIStyle.BLUE, 32, Vector2(70, 64))
	back.name = "Back"
	back.pressed.connect(GameManager.goto_menu)
	top.add_child(back)
	var title := UIStyle.label("Shop", 44, UIStyle.GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(CurrencyBar.new())
	root.add_child(UIStyle.label("Test build: all purchases use in-game currency only", 17, Color("#ffd6a8"), 4))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	_build()

func _roll_day() -> void:
	if EconomyManager.shop_day != EconomyManager.today():
		EconomyManager.shop_day = EconomyManager.today()
		EconomyManager.shop_bought = {}
		EconomyManager.save_game()

func _daily_deals() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(EconomyManager.today())
	var deck := CardDatabase.deck()
	var out := []
	var picks := deck.duplicate()
	for i in 3:
		var d: MonsterData = picks.pop_at(rng.randi() % picks.size())
		var n: int = [10, 6, 3, 2][d.rarity]
		var price := int(CARD_PRICE[d.rarity] * n * 0.6)
		out.append({"id": "deal_%d" % i, "card": d, "count": n, "price": price})
	return out

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	_section("Daily Deals", "Refreshes every day · 40% off")
	var row := _row()
	for deal in _daily_deals():
		var d: MonsterData = deal.card
		var bought: bool = EconomyManager.shop_bought.has(deal.id)
		var offer := _offer_box(row, "%s x%d" % [d.display_name, deal.count])
		var cv := CardView.new().setup(d, EconomyManager.get_card_level(d.id))
		cv.custom_minimum_size = Vector2(120, 152)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.add_child(cv)
		_buy_button(offer, "SOLD" if bought else str(deal.price), &"gold", deal.price, bought, func():
			EconomyManager.add_card_copies(d.id, deal.count)
			EconomyManager.shop_bought[deal.id] = true
			return "+%d %s cards" % [deal.count, d.display_name], "BuyDeal%d" % _list.get_child_count())

	_section("Special Offers", "Limited bundles")
	row = _row()
	var specials := [
		{"id": "special_starter", "title": "Royal Starter", "desc": "Golden Chest\n+1000 gold", "gems": 120, "chest": "golden", "gold": 1000},
		{"id": "special_legend", "title": "Dragon Hoard", "desc": "Frost Dragon x4\n+500 gold", "gems": 90, "card": &"frost_dragon", "n": 4, "gold": 500},
	]
	for sp in specials:
		var bought: bool = EconomyManager.shop_bought.has(sp.id)
		var offer := _offer_box(row, sp.title, Color("#ff9c2a"))
		var ic := UIIcon.new()
		ic.kind = &"chest" if sp.has("chest") else &"star"
		ic.tint = ChestPopup.CHEST_COLORS.get(sp.get("chest", ""), Color.WHITE)
		ic.custom_minimum_size = Vector2(0, 100)
		offer.add_child(ic)
		offer.add_child(UIStyle.label(sp.desc, 18, Color.WHITE, 4))
		_buy_button(offer, "SOLD" if bought else str(sp.gems), &"gem", sp.gems, bought, func():
			EconomyManager.shop_bought[sp.id] = true
			EconomyManager.add_gold(sp.gold)
			if sp.has("chest"):
				ChestPopup.show_rewards(self, EconomyManager.roll_chest(sp.chest))
			else:
				EconomyManager.add_card_copies(sp.card, sp.n)
			return "", "BuySpecial")

	_section("Chests", "Open instantly")
	row = _row()
	for ch in [["silver", 30], ["golden", 80], ["magic", 200]]:
		var offer := _offer_box(row, EconomyManager.CHESTS[ch[0]].name)
		var ic := UIIcon.new()
		ic.kind = &"chest"
		ic.tint = ChestPopup.CHEST_COLORS[ch[0]]
		ic.custom_minimum_size = Vector2(0, 110)
		offer.add_child(ic)
		offer.add_child(UIStyle.label("%d cards" % EconomyManager.CHESTS[ch[0]].cards, 18, Color("#c9d4ff"), 4))
		var type: String = ch[0]
		_buy_button(offer, str(ch[1]), &"gem", ch[1], false, func():
			ChestPopup.show_rewards(self, EconomyManager.roll_chest(type))
			return "", "BuyChest_" + type)

	_section("Cards", "Buy single copies with gold")
	row = _row()
	for d in CardDatabase.deck():
		var price: int = CARD_PRICE[d.rarity]
		var offer := _offer_box(row, MonsterData.rarity_name(d.rarity), MonsterData.rarity_color(d.rarity), 132)
		var cv := CardView.new().setup(d, EconomyManager.get_card_level(d.id))
		cv.custom_minimum_size = Vector2(100, 127)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		offer.add_child(cv)
		_buy_button(offer, str(price), &"gold", price, false, func():
			EconomyManager.add_card_copies(d.id, 1)
			return "+1 %s" % d.display_name, "BuyCard_" + String(d.id))

	_section("Gold", "Exchange gems for gold")
	row = _row()
	for g in [[1000, 60], [5000, 250], [15000, 600]]:
		var offer := _offer_box(row, "%s Gold" % CurrencyBar._fmt(g[0]))
		var ic := UIIcon.new()
		ic.kind = &"gold"
		ic.custom_minimum_size = Vector2(0, 90)
		offer.add_child(ic)
		var amount: int = g[0]
		_buy_button(offer, str(g[1]), &"gem", g[1], false, func():
			EconomyManager.add_gold(amount)
			return "+%d gold" % amount, "BuyGold%d" % amount)

	_section("Gems", "Simulated for testing – no real payment")
	row = _row()
	for g in [100, 500, 1200]:
		var offer := _offer_box(row, "%d Gems" % g, Color("#2ee06b"))
		var ic := UIIcon.new()
		ic.kind = &"gem"
		ic.custom_minimum_size = Vector2(0, 90)
		offer.add_child(ic)
		var amount: int = g
		_buy_button(offer, "FREE (test)", &"", 0, false, func():
			EconomyManager.add_gems(amount)
			return "+%d gems" % amount, "BuyGems%d" % amount)

func _section(title: String, sub: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(UIStyle.label(title, 32, Color.WHITE, 7, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UIStyle.label(sub, 16, Color("#c9b8ff"), 3, HORIZONTAL_ALIGNMENT_LEFT))
	_list.add_child(v)

func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 12)
	r.add_theme_constant_override("v_separation", 12)
	r.alignment = FlowContainer.ALIGNMENT_CENTER
	_list.add_child(r)
	return r

func _offer_box(row: Container, title: String, accent := Color("#6f5bff"), width := 210) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.box(Color("#2a2160"), 18, accent, 4, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0)
	row.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UIStyle.label(title, 20, Color.WHITE, 5))
	return v

func _buy_button(parent: Container, text: String, currency: StringName, price: int, sold: bool, grant: Callable, bname := "") -> Button:
	var b := UIStyle.button(text, UIStyle.GREEN, 22, Vector2(0, 58))
	if bname != "":
		b.name = bname
	b.disabled = sold
	if currency != &"" and not sold:
		var ic := UIIcon.new()
		ic.kind = currency
		ic.custom_minimum_size = Vector2(30, 30)
		ic.position = Vector2(8, 10)
		b.add_child(ic)
	b.pressed.connect(func(): _purchase(currency, price, grant))
	parent.add_child(b)
	return b

func _purchase(currency: StringName, price: int, grant: Callable) -> bool:
	var paid := true
	if currency == &"gold":
		paid = EconomyManager.spend_gold(price)
	elif currency == &"gem":
		paid = EconomyManager.spend_gems(price)
	if not paid:
		AudioManager.play(&"error")
		var p := UIPopup.open(self, "Not enough %s" % ("gold" if currency == &"gold" else "gems"), 520)
		p.content.add_child(UIStyle.label("Win battles or visit the Gems section.", 22, Color.WHITE, 4))
		return false
	AudioManager.play(&"coin")
	var msg: String = grant.call()
	EconomyManager.save_game()
	if msg != "":
		_flash(msg)
	_build()
	return true

func _flash(msg: String) -> void:
	var l := UIStyle.label(msg, 34, UIStyle.GOLD, 8)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.size = Vector2(600, 60)
	l.position = get_viewport_rect().size * 0.5 - Vector2(300, 30)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 80, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)

func run_self_test() -> bool:
	var ok := true
	EconomyManager.gems = 1000
	EconomyManager.gold = 1000
	var gold0 := EconomyManager.gold
	ok = ok and _purchase(&"gem", 60, func(): EconomyManager.add_gold(1000); return "")
	ok = ok and EconomyManager.gold == gold0 + 1000 and EconomyManager.gems == 940
	var copies := EconomyManager.get_card_copies(&"poison_witch")
	ok = ok and _purchase(&"gold", 40, func(): EconomyManager.add_card_copies(&"poison_witch", 1); return "")
	ok = ok and EconomyManager.get_card_copies(&"poison_witch") == copies + 1
	EconomyManager.gold = 0
	ok = ok and not _purchase(&"gold", 40, func(): return "")
	await get_tree().process_frame
	return ok
