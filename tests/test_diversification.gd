extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Business = preload("res://scripts/diversification.gd")
const Balance = preload("res://scripts/balance.gd")
const SAVE := "user://diversification_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(note)
func fresh():
	var farm = State.new()
	farm.rng.seed = 6
	for plot in farm.plots: farm._clear_crop(plot)
	farm.coins = 1200000
	return farm
func winter(farm, year: int = 3) -> void:
	farm.season_clock.year = year
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
func reconcile(farm) -> void:
	var cash: float = Balance.STARTING_CASH
	for entry in farm.ledger.entries: cash += float(entry.amount)
	check(cash == farm.coins, "every business payment reconciles exactly")
func run() -> void:
	var farm = fresh()
	for id in Business.NAMES: farm.diversification.buy(farm, id)
	check(farm.diversification.built.is_empty(), "businesses reject early Spring purchases")
	winter(farm, 2)
	for id in Business.NAMES: farm.diversification.buy(farm, id)
	check(farm.diversification.built.is_empty(), "year two accounts cannot buy a business")
	farm.update(150)
	farm.diversification.buy(farm, "shop")
	check(not farm.diversification.owns("shop"), "year three still requires Winter")
	winter(farm)
	farm.tutorial_active = true
	farm.diversification.buy(farm, "shop")
	check(not farm.diversification.owns("shop"), "tutorial cannot buy businesses")
	farm.tutorial_active = false
	var before: float = farm.coins
	farm.accounts_open = true
	for id in Business.NAMES: farm.diversification.buy(farm, id)
	check(farm.diversification.built.size() == 3 and farm.coins == before - 220000, "paused accounts can build both businesses and enrol once")
	var snapshot: Dictionary = farm._save_data()
	for id in Business.NAMES: farm.diversification.buy(farm, id)
	farm.update(50)
	check(farm._save_data() == snapshot, "duplicate clicks and paused time cannot change the accounts")
	check(farm.ledger.entries.any(func(e): return e.label == "Contract grower enrolment" and e.amount == 0), "free enrolment has its own journal label")
	farm.diversification.winter(farm)
	check(farm.diversification.income(farm) == 0, "construction Winter does not pay retroactive income")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "paused purchases survive reload")
	farm.climate.data.projects = {"rainwater": 2, "drainage": 1, "irrigation": 2}
	check(Business.protection_count(farm.climate.data.projects) == 2, "lodging counts protection types, not levels or sprinklers")
	farm.update(150)
	check(farm.season_clock.year == 4 and farm.season_clock.season == 0, "first business year begins normally")
	farm.update(150)
	check(farm.season_clock.season == 1 and farm.season_seconds() == 120, "shop Summer budget is 120 seconds")
	farm.update(119.75)
	check(farm.season_clock.season == 1 and is_equal_approx(farm.calendar_light_seconds(), 149.6875), "sun reaches dusk at the shortened Summer end")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "short Summer resumes from its saved second")
	var bad: Dictionary = farm._save_data(); bad.season_clock.seconds = 120
	check(not farm._valid_save(bad), "save cannot place the clock past its shortened Summer")
	farm.update(0.25)
	check(farm.season_clock.season == 2 and farm.season_clock.seconds == 0 and farm.season_seconds() == 150, "Autumn starts exactly at Summer second 120")
	before = farm.coins
	farm.update(150)
	check(farm.diversification.winters["4"].shop == 32000 and farm.diversification.winters["4"].lodging == 12000, "first full year pays 32,000 shop and 12,000 for two lodging protections")
	check(farm.coins == before + 44000 - farm.ledger.fixed_cost_total() - 2 * Balance.PROTECTION_UPKEEP, "business income pays before the Winter bill")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "income reports and entries round-trip")
	before = farm.coins
	farm.diversification.winter(farm)
	check(farm.coins == before, "reload cannot duplicate business income")
	for defect in ["owner", "future", "report", "duplicate", "missing", "extra"]:
		bad = farm._save_data()
		match defect:
			"owner": bad.diversification.built.erase("shop")
			"future": bad.diversification.built.shop = 5
			"report": bad.diversification.winters["4"].lodging += 1
			"duplicate":
				for e in bad.ledger.entries.duplicate():
					if e.label == "Farm shop income": bad.ledger.entries.append(e.duplicate())
			"missing": bad.diversification.winters.erase("4")
			"extra": bad.diversification.winters["10"] = bad.diversification.winters["4"].duplicate()
		check(not farm._valid_save(bad), "reject inconsistent diversification: " + defect)
	reconcile(farm)
	farm.reset_game()
	check(farm.diversification.built.is_empty() and farm.diversification.winters.is_empty() and farm.run_title().is_empty(), "new run clears businesses and title")
	farm.free()
	for count in range(5):
		farm = fresh(); winter(farm)
		farm.diversification.buy(farm, "lodging")
		for i in range(count): farm.climate.data.projects[["rainwater", "drainage", "windbreaks", "frost"][i]] = 1
		winter(farm, 4)
		check(farm.diversification.winters["4"].lodging == 6000 * count, "lodging scales from zero to four protections")
		farm.free()
	farm = fresh(); winter(farm)
	farm.coins = Balance.OVERDRAFT_LIMIT + Balance.BUSINESS_COSTS.shop - 1
	before = farm.coins
	farm.diversification.buy(farm, "shop")
	check(farm.coins == before and not farm.diversification.owns("shop"), "one coin short refuses construction atomically")
	farm.coins += 1
	farm.diversification.buy(farm, "shop")
	check(farm.coins == Balance.OVERDRAFT_LIMIT and not farm.run_over, "last affordable coin may build without retroactive foreclosure")
	farm.free()
	weather_checks()
	contract_checks()
	title_checks()
	await ui_checks()
	for suffix in ["", ".bak", ".rejected", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("DIVERSIFICATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func weather_checks() -> void:
	var farm = fresh()
	winter(farm)
	farm.diversification.buy(farm, "shop")
	farm.update(300)
	farm.climate.start_season(farm)
	# Summer's warning and active event must finish, but its recovery must not
	# occupy Autumn and silently suppress the next saved weather draw.
	farm.climate.end_working_year()
	farm.climate.data.outlook.records.clear()
	farm.climate.begin_warning(farm, "drought")
	farm.climate.data.outlook.next = {"year": 4, "season": 2, "event": "flood", "fires": true}
	farm.update(119)
	check(farm.climate.data.phase == "recovery", "shop labour never shortens warning or active weather")
	var records: int = farm.climate.data.outlook.records.size()
	farm.update(1)
	check(farm.season_clock.season == 2 and farm.climate.data.phase == "calm", "short Summer ends its weather recovery")
	farm.update(1)
	check(farm.climate.data.phase == "warning" and farm.climate.data.event == "flood" and farm.climate.data.outlook.records.size() == records + 1, "Autumn honours the saved weather draw after shop Summer")
	farm.free()

func contract_checks() -> void:
	var farm = fresh()
	farm.trading.accept(farm, 1)
	check(farm.trading.contracts.is_empty(), "ordinary farm cannot accept a second order")
	winter(farm)
	farm.diversification.buy(farm, "grower")
	farm.update(150)
	check(farm.trading.order_limit(farm) == 2, "enrolment unlocks two Spring orders")
	# Year four buyers want Sunburst and Icecap; two distinct stock pools.
	for slot in range(2):
		farm.trading.accept(farm, slot)
		check(is_equal_approx(farm.trading.active_order(slot).price, farm.trading.offer(4, slot).price * 1.2), "each contract quote receives the premium")
	farm.trading.accept(farm, 0); farm.trading.accept(farm, 2)
	check(farm.trading.contracts.size() == 2, "duplicate and third orders are refused")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "two active orders survive reload")
	for defect in ["duplicate", "premium", "ownership", "slot"]:
		var bad: Dictionary = farm._save_data()
		match defect:
			"duplicate": bad.trading.contracts[1] = bad.trading.contracts[0].duplicate()
			"premium": bad.trading.contracts[1].price += 1
			"ownership": bad.diversification.built.erase("grower")
			"slot": bad.trading.contracts[1].slot = 2
		check(not farm._valid_save(bad), "reject invalid simultaneous orders: " + defect)
	var orders: Array = farm.trading.contracts.duplicate(true)
	farm.storage[orders[0].crop] = farm.Stock.pile(20)
	farm.storage[orders[1].crop] = farm.Stock.pile(7)
	farm.Stock.add(farm.storage, orders[1].crop, 10, 20)
	var before: float = farm.coins
	winter(farm, 4)
	check(farm.trading.contracts.is_empty() and farm.trading.settled["4"].size() == 2, "both orders settle at the same Autumn boundary")
	check(farm.trading.completed_order(4, 0).delivered == 20 and farm.trading.completed_order(4, 1).delivered == 7 and farm.trading.completed_order(4, 1).shortfall == 13, "each order uses its own tonnes and rejects Feed")
	var earned: float = 20 * orders[0].price + 7 * orders[1].price
	check(is_equal_approx(farm.ledger.total(4, "contracts"), earned - 13 * Balance.SHORTFALL_FEE), "both deliveries and the shortfall have honest ledger amounts")
	check(is_equal_approx(farm.diversification.income(farm), earned), "premium contract receipts count as diversification income, not penalties")
	check(farm.coins < before and farm.save_game(SAVE) and farm.load_game(SAVE), "settled orders and shortfall journal round-trip")
	before = farm.coins; farm.trading.settle(farm)
	check(farm.coins == before, "neither contract settles twice")
	var bad: Dictionary = farm._save_data(); bad.trading.settled["4"].pop_back()
	check(not farm._valid_save(bad), "a settlement receipt cannot disappear while its money remains")
	reconcile(farm)
	farm.free()

func title_checks() -> void:
	var farm = fresh()
	check(farm.run_title().is_empty(), "no title before run end")
	farm.run_outcome = "completed"
	check(farm.run_title() == "Stubborn", "survived without protection")
	farm.climate.data.projects = {"rainwater": 2, "drainage": 2}
	check(farm.run_title() == "Survivor", "two level-two projects do not count as three protections")
	farm.climate.data.projects.frost = 1
	check(farm.run_title() == "Adapter", "three protection types earn Adapter")
	farm.post_money("sales", "Crops", 32000)
	farm.post_money("other", "Farm shop income", 32000)
	check(farm.run_title() == "Adapter", "a tie is not most income")
	farm.post_money("other", "Lodging income", 1)
	check(farm.run_title() == "Shopkeeper", "majority diversification takes precedence over Adapter")
	farm.run_outcome = "foreclosed"
	check(farm.run_title() == "Sold Up", "foreclosure takes precedence over all earned titles")
	farm.free()

func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.rng.seed = 6
	game.state.coins = 1200000
	winter(game.state)
	await process_frame
	check(game.hud._panel_kind == "accounts" and game.state.accounts_open, "year-three accounts remain paused")
	for id in Business.NAMES:
		check(game.hud._refs.has("diversify:" + id) and not game.hud._refs["diversify:" + id].disabled, "accounts offer " + id)
		game.hud._refs["diversify:" + id].pressed.emit()
		check(game.state.diversification.owns(id) and game.hud._refs["diversify:" + id].disabled, "accounts button buys and disables " + id)
	check(game.hud._refs.business_ledger.text.contains("Farm shop construction") and game.hud._refs.business_ledger.text.contains("Lodging construction") and game.hud._refs.business_ledger.text.contains("Contract grower enrolment"), "accounts show each business's own journal label")
	var seconds: float = game.state.season_clock.seconds
	game._process(10)
	check(game.state.season_clock.seconds == seconds, "business purchasing leaves the accounts pause active")
	for size in [Vector2i(1280,800), Vector2i(390,844)]:
		root.size = size
		for frame in range(5): await process_frame
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "accounts fit desktop and phone")
		for id in Business.NAMES:
			var button: Button = game.hud._refs["diversify:" + id]
			check(button.size.x <= game.hud._modal_card.size.x, "business button fits the paper width")
			var scroll: ScrollContainer = game.hud._body.get_parent()
			scroll.ensure_control_visible(button)
			for frame in range(2): await process_frame
			check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "every business action can be scrolled fully into view")
		if "--capture" in OS.get_cmdline_user_args():
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/diversification-accounts-%d.png" % size.x)
	game.hud.close_panel()
	game.state.update(150)
	game._on_action("contracts")
	check(game.hud._refs.has("contract_accept:1"), "enrolled buyer board offers two independent actions")
	game.hud._refs.contract_accept.pressed.emit()
	game.hud._refs["contract_accept:1"].pressed.emit()
	check(game.state.trading.contracts.size() == 2, "both UI actions accept the right order")
	for frame in range(5): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/diversification-contracts.png")
	game.state.run_outcome = "completed"
	game._on_action("run_summary")
	check(game.hud._refs.run_title.text == game.state.run_title(), "ten-year summary presents the derived title")
	game.queue_free()
	await process_frame
	# Let the audio mixer release the accountant's stopped voice playback.
	await create_timer(0.4).timeout
