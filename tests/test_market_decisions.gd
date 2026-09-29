extends SceneTree
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
	farm.storage.icecap = 100
	farm.season_clock.season = 2; farm.elapsed = 300; farm._refresh_market()
	var harvest_value: float = farm.market.icecap.sell * 100
	farm.trading.store(farm, "icecap", 100)
	check(farm.trading.held.icecap == 100 and farm.storage_used() == 100, "storing reserves actual sacks without duplicating capacity")
	winter(farm)
	check(farm.storage.icecap == 90 and farm.trading.held.icecap == 90, "Winter loses ten percent and keeps the surviving sacks")
	check(farm.ledger.total(1, "storage") == -200, "one Winter storage fee posts to the journal")
	var spoilage_note: bool = false
	for entry in farm.ledger.entries:
		if entry.category == "storage" and entry.label == "Spoilage: 10 icecap sacks" and entry.amount == 0: spoilage_note = true
	check(spoilage_note, "spoilage is recorded as sacks, without subtracting imaginary cash")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "stores, billing and spoilage round-trip")
	var damaged: Dictionary = farm._save_data()
	damaged.trading.winters["1"].fee = 0
	check(not farm._valid_save(damaged), "storage report cannot disagree with its fee journal entry")
	var before: float = farm.coins
	farm.trading.begin_winter(farm)
	check(farm.coins == before and farm.storage.icecap == 90, "reload cannot duplicate storage fee or spoilage")
	for crop in State.CROP_IDS:
		farm.season_clock.seconds = 0
		check(farm.trading.stored_price(farm, crop) == State.CropTable.CROPS[crop].base, crop + " Winter starts at base")
		var last: float = 0
		for seconds in [0, 50, 100, 149.9]:
			farm.season_clock.seconds = seconds
			var price: float = farm.trading.stored_price(farm, crop)
			check(price >= last and price <= farm.trading.peak_price(crop), crop + " Winter price rises without overshooting")
			last = price
	check(farm.trading.peak_price("russet") == 18 and farm.trading.peak_price("golden") == 29.4 and farm.trading.peak_price("icecap") == 48, "volatility sets the storage ceiling")
	farm.sell_crop("icecap")
	check(farm.storage.icecap == 90, "quick and market sales cannot bypass the Winter barn action")
	farm.trading.sell_stored(farm, "icecap")
	var sales: float = farm.ledger.total(1, "sales")
	check(sales - 200 > harvest_value, "late-Winter sale beats harvest sale after fee and spoilage in a calm year")
	check(farm.storage.icecap == 0 and farm.trading.held.icecap == 0, "stored sale consumes each sack once")
	check(farm.quest_progress.starter_spike == 10, "stored sales count toward the retained sale quest")
	check(is_equal_approx(farm.coins, farm.Ledger.STARTING_CASH + farm.ledger.total()), "purse equals the complete journal")
	farm.free()
	farm = fresh(); farm.storage.russet = 11
	winter(farm)
	check(farm.storage.russet == 9, "fractional spoiled sacks round up")
	farm.storage.icecap = 3
	farm.trading.store(farm, "icecap", 3)
	check(farm.trading.held.icecap == 0, "new Winter Icecap cannot instantly earn stored-crop prices")
	farm.sell_crop("icecap")
	check(farm.storage.icecap == 0 and farm.ledger.total(1, "sales") > 0, "new Winter harvests still sell normally")
	farm.season_clock.seconds = 149.9
	var peak: float = farm.trading.stored_price(farm, "russet")
	farm.update(.1)
	check(farm.season_clock.season == 0 and farm.trading.held.russet == 0 and farm.trading.stored_price(farm, "russet") < peak, "Spring resets the premium and releases unsold sacks")
	before = farm.coins
	farm.trading.sell_stored(farm, "russet")
	check(farm.coins == before and farm.storage.russet == 9, "Spring cannot sell at the expired Winter price")
	farm.sell_crop("russet")
	check(farm.storage.russet == 0, "unsold stores become ordinary Spring stock")
	farm.free()
	farm = fresh(); winter(farm)
	check(farm.ledger.total(1, "storage") == 0, "an empty barn has no storage fee")
	farm.free()
	for opening in [-300, -301]:
		farm = fresh(); farm.coins = opening; farm.storage.russet = 1
		winter(farm)
		check(farm.coins == opening - 4700 and farm.run_over == (opening == -301), "storage fee is included before exact overdraft foreclosure")
		farm.free()
	farm = fresh()
	farm.storage.russet = farm.capacity - 1
	farm.plots[5].merge({"crop":"russet", "stage":3, "tilled":true, "watered":true, "elapsed":75.0}, true)
	farm.interact_plot(5, "harvest")
	check(farm.storage_used() == farm.capacity and farm.plots[5].pending == 2, "barn capacity leaves excess harvest on the bed")
	farm.trading.store(farm, "russet", farm.capacity + 1)
	check(farm.trading.held.russet == 0, "cannot store sacks that do not exist")
	farm.trading.store(farm, "russet", farm.capacity)
	check(farm.storage_used() == farm.capacity and farm.trading.held.russet == farm.capacity, "fresh and committed sacks share one barn capacity")
	farm.trading.accept(farm)
	var order: Dictionary = farm.trading.contract.duplicate()
	farm.trading.accept(farm)
	check(farm.trading.contract == order, "one active Spring contract")
	farm.storage.russet = 12; farm.trading.clamp_stock(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "active contract and commitments reload")
	farm.season_clock.season = 1; farm.season_clock.seconds = 149.75
	farm.update(.25)
	check(farm.trading.contract.is_empty() and farm.trading.settled["1"].delivered == 12 and farm.storage.russet == 0, "Autumn buyer collects available sacks exactly once")
	check(is_equal_approx(farm.ledger.total(1, "contracts"), 12 * 16.5 - 8 * 5), "contract delivery and shortfall post to contracts")
	check(farm.trading.held.russet == 0, "contract cannot leave phantom stored sacks")
	before = farm.coins; farm.trading.settle(farm); farm.trading.accept(farm)
	check(farm.coins == before and farm.trading.contract.is_empty(), "settlement is idempotent and Autumn cannot accept orders")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "settled contract round-trips")
	var bad: Dictionary = farm._save_data(); bad.trading.held.russet = 1
	check(not farm._valid_save(bad), "reject stores without matching stock")
	bad = farm._save_data(); bad.trading.settled["1"].price = 999
	check(not farm._valid_save(bad), "reject tampered contract price")
	farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("MARKET DECISIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.state.storage.russet = 40
	game.hud.show_panel("sell_potatoes", game.state)
	var page = game.hud._refs.market_page
	check(page.crop_history.expected_price == 18 and not page.store_button.disabled, "sell card shows storage choice and dashed Winter price")
	page.quantity.value = 10; page.store_button.pressed.emit()
	check(game.state.trading.held.russet == 10, "store card action uses the selected quantity")
	game._on_action("contracts")
	check(game.hud._panel_kind == "contracts" and not game.hud._refs.contract_accept.disabled, "buyer board opens the Spring contract")
	game.hud._refs.contract_accept.pressed.emit()
	check(not game.state.trading.contract.is_empty() and game.hud._refs.contract_accept.disabled, "accept button commits one order")
	check(game.world.has_node("BuyerContracts"), "Golden Shores buyer board is reused on the Valley")
	game.hud.close_panel()
	game.state.season_clock.season = 1; game.state.season_clock.seconds = 149.75
	game.state.update(.25)
	winter(game.state)
	check(game.state.accounts_open and game.hud._panel_kind == "accounts", "storage posts before accounts pause opens")
	check(game.hud._refs.accounts_storage.text == game.state.money(-200), "accounts list storage charges")
	game.hud.close_panel(); game._on_action("winter_stores")
	game.state.season_clock.seconds = 140
	game.hud.update_state(game.state)
	check(not game.hud._refs["stored_sell:russet"].disabled, "Winter barn exposes stored sale action")
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
	game.hud._refs["stored_sell:russet"].pressed.emit()
	check(game.state.coins > before and game.state.trading.held.russet == 0, "Winter barn button sells at the live stored price")
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
