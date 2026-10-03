extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://market_decisions_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 6
	for plot in farm.plots: farm._clear_crop(plot)
	return farm
func winter(farm) -> void:
	farm.season_clock.season = 2; farm.season_clock.seconds = 149
	farm.elapsed = 449; farm._refresh_market()
	farm.update(1)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var farm = fresh()
	farm.storage["icecap"] = Stock.pile(100)
	farm.season_clock.season = 2; farm.elapsed = 300; farm._refresh_market()
	var harvest_value: float = farm.market.icecap.sell * 100
	check(Stock.count(farm.trading.held, "icecap") == 0 and farm.storage_used() == 100, "Autumn stock stays ordinary until Winter begins")
	winter(farm)
	check(Stock.count(farm.storage, "icecap") == 95 and Stock.count(farm.trading.held, "icecap") == 95, "Winter loses five percent and keeps the surviving tonnes")
	check(farm.ledger.total(1, "storage") == -State.MarketDecisions.STORAGE_FEE, "one Winter storage fee posts to the journal")
	var spoilage_note: bool = false
	for entry in farm.ledger.entries:
		if entry.category == "storage" and entry.label == "Spoilage: 5 icecap tonnes" and entry.amount == 0: spoilage_note = true
	check(spoilage_note, "spoilage is recorded as tonnes, without subtracting imaginary cash")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "stores, billing and spoilage round-trip")
	var damaged: Dictionary = farm._save_data()
	damaged.trading.winters["1"].fee = 0
	check(not farm._valid_save(damaged), "storage report cannot disagree with its fee journal entry")
	var before: float = farm.coins
	farm.trading.begin_winter(farm)
	check(farm.coins == before and Stock.count(farm.storage, "icecap") == 95, "reload cannot duplicate storage fee or spoilage")
	for crop in State.CROP_IDS:
		farm.season_clock.seconds = 0
		check(farm.trading.stored_price(farm, crop) == State.CropTable.CROPS[crop].base, crop + " Winter starts at base")
		var last: float = 0
		for seconds in [0, 50, 100, 149.9]:
			farm.season_clock.seconds = seconds
			var price: float = farm.trading.stored_price(farm, crop)
			check(price >= last and price <= farm.trading.peak_price(crop), crop + " Winter price rises without overshooting")
			last = price
	for id in State.CROP_IDS:
		check(is_equal_approx(farm.trading.peak_price(id), State.CropTable.CROPS[id].base * State.CropTable.VOLATILITY[State.CropTable.CROPS[id].volatility].storage_peak_factor), "volatility sets the storage ceiling for " + id)
	farm.sell_crop("icecap")
	check(Stock.count(farm.storage, "icecap") == 95, "quick and market sales cannot bypass the Winter barn action")
	farm.trading.sell_stored(farm, "icecap")
	var sales: float = farm.ledger.total(1, "sales")
	check(sales - State.MarketDecisions.STORAGE_FEE > harvest_value, "late-Winter sale beats harvest sale after fee and spoilage in a calm year")
	check(Stock.count(farm.storage, "icecap") == 0 and Stock.count(farm.trading.held, "icecap") == 0, "stored sale consumes each tonne once")
	check(farm.quest_progress.starter_spike == 10, "stored sales count toward the retained sale quest")
	check(is_equal_approx(farm.coins, farm.Ledger.STARTING_CASH + farm.ledger.total()), "purse equals the complete journal")
	farm.free()
	farm = fresh(); farm.storage["russet"] = Stock.pile(11)
	winter(farm)
	check(Stock.count(farm.storage, "russet") == 10, "fractional spoiled tonnes round to nearest")
	farm.storage["icecap"] = Stock.pile(3)
	check(Stock.count(farm.trading.held, "icecap") == 0, "new Winter Icecap cannot instantly earn stored-crop prices")
	farm.sell_crop("icecap")
	check(Stock.count(farm.storage, "icecap") == 0 and farm.ledger.total(1, "sales") > 0, "new Winter harvests still sell normally")
	farm.season_clock.seconds = 149.9
	var peak: float = farm.trading.stored_price(farm, "russet")
	farm.update(.1)
	check(farm.season_clock.season == 0 and Stock.count(farm.trading.held, "russet") == 0 and farm.trading.stored_price(farm, "russet") < peak, "Spring resets the premium and releases unsold tonnes")
	before = farm.coins
	farm.trading.sell_stored(farm, "russet")
	check(farm.coins == before and Stock.count(farm.storage, "russet") == 10, "Spring cannot sell at the expired Winter price")
	farm.sell_crop("russet")
	check(Stock.count(farm.storage, "russet") == 0, "unsold stores become ordinary Spring stock")
	farm.free()
	farm = fresh(); winter(farm)
	check(farm.ledger.total(1, "storage") == 0, "an empty barn has no storage fee")
	farm.free()
	for sacks in [1, 4, 5, 14, 15]:
		farm = fresh(); farm.storage["russet"] = Stock.pile(sacks)
		winter(farm)
		var loss: int = {1: 0, 4: 0, 5: 0, 14: 1, 15: 1}[sacks]
		check(Stock.count(farm.storage, "russet") == sacks - loss and farm.trading.winters["1"].spoiled.russet == loss, "whole-barn rounding for %d tonnes" % sacks)
		check(Stock.count(farm.trading.held, "russet") == sacks - loss and farm.ledger.total(1, "storage") == -State.MarketDecisions.STORAGE_FEE, "small barns store survivors and still pay the fee")
		farm.free()
	farm = fresh()
	farm.storage["russet"] = Stock.pile(1); farm.storage["giant"] = Stock.pile(6); farm.storage["golden"] = Stock.pile(7); farm.storage["icecap"] = Stock.pile(6)
	winter(farm)
	check(farm.storage_used() == 19 and Stock.count(farm.storage, "golden") == 6 and Stock.count(farm.storage, "russet") == 1 and Stock.count(farm.storage, "giant") == 6 and Stock.count(farm.storage, "icecap") == 6, "mixed barn loses five percent in total from the largest pile first")
	check(farm.trading.winters["1"].spoiled.golden == 1 and farm.save_game(SAVE) and farm.load_game(SAVE), "mixed-pile loss and journal notes round-trip")
	farm.free()
	farm = fresh(); farm.storage["russet"] = Stock.pile(5); farm.storage["giant"] = Stock.pile(5)
	winter(farm)
	check(Stock.count(farm.storage, "russet") == 4 and Stock.count(farm.storage, "giant") == 5, "equal largest piles resolve in catalogue order")
	farm.free()
	var winter_bill: float = State.Ledger.new().fixed_cost_total() + State.MarketDecisions.STORAGE_FEE
	for opening in [State.OVERDRAFT_LIMIT + winter_bill, State.OVERDRAFT_LIMIT + winter_bill - 1]:
		farm = fresh(); farm.coins = opening; farm.storage["russet"] = Stock.pile(1)
		winter(farm)
		check(farm.coins == opening - winter_bill and farm.run_over == (opening - winter_bill < State.OVERDRAFT_LIMIT), "storage fee is included before exact overdraft foreclosure")
		farm.free()
	farm = fresh()
	farm.storage["russet"] = Stock.pile(farm.capacity - 1)
	farm.plots[5].merge({"crop":"russet", "stage":3, "tilled":true, "watered":true, "elapsed":75.0}, true)
	farm.interact_plot(5, "harvest")
	check(farm.storage_used() == farm.capacity and farm.plots[5].pending == 2, "barn capacity leaves excess harvest on the bed")
	winter(farm)
	check(farm.storage_used() == 190 and Stock.count(farm.trading.held, "russet") == 190 and farm.capacity == 200, "automatic Winter storage shares the purchased barn capacity")
	farm.free()
	farm = fresh()
	check(farm.trading.accept(farm).contains("collected at the end of Autumn"), "acceptance states the Autumn-end collection deadline")
	var order: Dictionary = farm.trading.contracts[0].duplicate()
	farm.trading.accept(farm)
	check(farm.trading.contracts == [order], "one active Spring contract")
	farm.storage["russet"] = Stock.pile(12)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "active Spring contract reloads")
	var altered: Dictionary = farm._save_data()
	altered.trading.contracts[0].price += 0.001
	check(not farm._valid_save(altered), "serialization precision does not permit a changed contract quote")
	farm.season_clock.season = 1; farm.season_clock.seconds = 149.75
	farm.update(.25)
	check(farm.season_clock.season == 2 and not farm.trading.contracts.is_empty() and farm.trading.settled.is_empty() and Stock.count(farm.storage, "russet") == 12 and farm.ledger.total(1, "contracts") == 0, "Autumn starts without collecting or penalizing the order")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "active contract survives an Autumn reload")
	order = farm.trading.contracts[0].duplicate()
	farm.trading.accept(farm)
	check(farm.trading.contracts == [order], "Autumn cannot accept another order")
	var premature: Dictionary = farm._save_data(); premature.trading.held["russet"] = Stock.pile(1)
	check(not farm._valid_save(premature), "pre-Winter saves cannot mark tonnes as stored")
	farm.plots[5].merge({"crop":"russet", "stage":3, "tilled":true, "watered":true, "elapsed":75.0}, true)
	farm.interact_plot(5, "harvest")
	check(Stock.count(farm.storage, "russet") == 15, "Autumn harvesting adds tonnes before the collection deadline")
	winter(farm)
	check(farm.trading.contracts.is_empty() and farm.trading.settled["1"][0].delivered == 15 and Stock.count(farm.storage, "russet") == 0, "buyer collects the Autumn harvest exactly once at Winter start")
	check(is_equal_approx(farm.ledger.total(1, "contracts"), 15 * order.price - 5 * State.MarketDecisions.SHORTFALL_FEE), "contract delivery and shortfall post to contracts")
	check(farm.ledger.total(1, "storage") == 0, "collection empties the barn before assessing the storage fee")
	check(Stock.count(farm.trading.held, "russet") == 0, "contract cannot leave phantom stored tonnes")
	before = farm.coins; farm.trading.settle(farm); farm.trading.accept(farm)
	check(farm.coins == before and farm.trading.contracts.is_empty(), "settlement is idempotent and Winter cannot accept orders")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "settled contract round-trips")
	var bad: Dictionary = farm._save_data(); bad.trading.held["russet"] = Stock.pile(1)
	check(not farm._valid_save(bad), "reject stores without matching stock")
	bad = farm._save_data(); bad.trading.settled["1"][0].price = 999
	check(not farm._valid_save(bad), "reject tampered contract price")
	bad = farm._save_data()
	for entry in bad.ledger.entries:
		if entry.category == "contracts": entry.season = 2
	check(not farm._valid_save(bad), "contract postings must belong to the Autumn-to-Winter boundary")
	farm.free()
	for sacks in [0, 20, 40]:
		farm = fresh(); farm.trading.accept(farm)
		farm.storage["russet"] = Stock.pile(sacks)
		if sacks == 20:
			farm.storage["russet"] = Stock.pile(17); farm.season_clock.season = 2
			farm.plots[5].merge({"crop":"russet", "stage":3, "tilled":true, "watered":true, "elapsed":75.0}, true)
			farm.interact_plot(5, "harvest")
			check(Stock.count(farm.storage, "russet") == 20, "Autumn harvest completes the buyer quantity")
		farm.boundary_save_path = SAVE
		winter(farm)
		var delivered: int = mini(sacks, 20)
		var remaining: int = sacks - delivered
		check(farm.trading.settled["1"][0].delivered == delivered and farm.trading.settled["1"][0].shortfall == 20 - delivered, "contract settles before spoilage for %d tonnes" % sacks)
		check(farm.trading.winters["1"].spoiled.russet == roundi(remaining * 0.05) and Stock.count(farm.storage, "russet") == remaining - roundi(remaining * 0.05), "only the contract remainder spoils")
		check(farm.ledger.total(1, "storage") == (-State.MarketDecisions.STORAGE_FEE if remaining > 0 else 0), "only the contract remainder incurs a storage fee")
		check(farm.load_game(SAVE) and farm.trading.contracts.is_empty() and farm.trading.settled["1"][0].delivered == delivered, "boundary save contains complete contract settlement and storage")
		farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("MARKET DECISIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.state.storage["russet"] = Stock.pile(40)
	game.hud.show_panel("sell_potatoes", game.state)
	var page = game.hud._refs.market_page
	check(is_equal_approx(page.crop_history.expected_price, game.state.trading.peak_price("russet")) and not page.storage_note.visible and page.find_children("*", "Button", true, false).any(func(button): return button.text == "?" and button.tooltip_text.contains("Winter start")), "storage explanation is behind a question mark outside Winter")
	var store_actions: Array = page.find_children("*", "Button", true, false).filter(func(button): return button.get_meta("action", "") == "market_store" or button.text == "Store selected tonnes")
	check(store_actions.is_empty() and not page.storage_note.text.contains("Set aside"), "sell page has no Store button or held marker")
	check(Stock.count(game.state.trading.held, "russet") == 0, "opening the sell page does not reserve tonnes")
	game._on_action("contracts")
	check(game.hud._panel_kind == "contracts" and not game.hud._refs.contract_accept.disabled, "buyer board opens the Spring contract")
	game.hud._refs.contract_accept.pressed.emit()
	check(not game.state.trading.contracts.is_empty() and game.hud._refs.contract_accept.disabled, "accept button commits one order")
	check(game.world.has_node("BuyerContracts"), "the buyer order board sits on the Spud Valley farm")
	game.hud.close_panel()
	game.state.season_clock.season = 1; game.state.season_clock.seconds = 149.75
	game.state.update(.25)
	winter(game.state)
	check(game.state.accounts_open and game.hud._panel_kind == "accounts", "storage posts before accounts pause opens")
	check(game.hud._refs.accounts_storage.text == game.state.money(-State.MarketDecisions.STORAGE_FEE), "accounts list storage charges")
	game.hud.close_panel(); game._on_action("winter_stores")
	game.state.season_clock.seconds = 140
	game.hud.update_state(game.state)
	check(game.hud._refs.market_page.stored_mode and game.hud._refs.market_page.sale_rows.russet.grades.Standard.visible, "Winter market opens on stocked stores")
	page = game.hud._refs.market_page
	for grade in ["Table", "Standard", "Feed"]:
		page.select_variety("russet", grade)
		var base: float = State.CropTable.CROPS.russet.base * State.Quality.MULTIPLIER[grade]
		var premium: int = roundi((page.price_for("russet", grade) / base - 1.0) * 100.0)
		check(page.crop_change.text == "+%d%%" % premium and premium > 0, "Winter percentage uses the rising stored quote for " + grade)
		check(is_equal_approx(page.crop_history.samples[-1], page.price_for("russet", grade)) and page.crop_history.samples[0] < page.crop_history.samples[-1], "Winter chart ends at the actual rising stored quote for " + grade)
	var held_before_tabs: Dictionary = game.state.trading.held.duplicate(true)
	var cash_before_tabs: float = game.state.coins
	game.hud._modal_market_nav.get_child(0).pressed.emit()
	if game.conversation.visible:
		check(game.conversation.npc_id == "mara", "first Buy tab still introduces Mara")
		game.conversation.choose(0)
		await process_frame
	check(game.hud._panel_kind == "market" and game.hud._refs.market_page.sale_rows.is_empty(), "Winter Buy tab keeps held potatoes out of seed packets")
	game.hud._modal_market_nav.get_child(1).pressed.emit()
	check(game.hud._panel_kind == "sell_potatoes" and game.hud._refs.market_page.stored_mode, "Winter Sell tab returns to rising stored quotes")
	check(game.state.trading.held == held_before_tabs and game.state.coins == cash_before_tabs, "Winter tab switches neither sell stock nor spend cash")
	for size in [Vector2i(1280, 800), Vector2i(390, 844)]:
		root.size = size
		if game.touch_controls.enabled: game.touch_controls.resize()
		else: root.content_scale_size = Vector2i(maxi(600, size.x), roundi(size.y * maxf(1.0, 600.0 / size.x)))
		for panel in ["sell_potatoes", "contracts", "winter_stores", "accounts"]:
			game.hud.show_panel(panel, game.state)
			if not game.touch_controls.enabled:
				var width: float = minf(1000 if panel == "sell_potatoes" else 752, game.hud.root.size.x - 24)
				game.hud._modal_card.offset_left = -width / 2
				game.hud._modal_card.offset_right = width / 2
			for i in range(10): await process_frame
			check(game.hud._modal_card.get_global_rect().position.x >= 0 and game.hud._modal_card.get_global_rect().end.x <= game.hud.root.size.x, panel + " fits desktop/phone width")
			if "--capture" in OS.get_cmdline_user_args():
				await create_timer(.1).timeout
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://artifacts/decisions-%s-%d.png" % [panel, size.x])
	game.hud.show_panel("winter_stores", game.state)
	var before: float = game.state.coins
	game.hud._refs.market_page.select_variety("russet", "Standard")
	game.hud._refs.market_page.maximum.pressed.emit()
	game.hud._refs.market_page.sell_button.pressed.emit()
	check(game.state.coins > before and Stock.count(game.state.trading.held, "russet") == 0, "Winter barn button sells at the live stored price")
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
