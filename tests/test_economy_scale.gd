extends SceneTree
const Balance = preload("res://scripts/balance.gd")
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://economy_scale_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func run() -> void:
	check_balance_constants()
	var farm = State.new()
	root.add_child(farm)
	check(farm.coins == 80000 and farm.bankruptcy_limit() == -200000, "starting funds and overdraft boundary")
	var prices: Dictionary = preload("res://scripts/balance.gd").CROPS
	for crop: String in prices:
		check(farm.market[crop].sell == prices[crop].base, crop + " base price")
		check(farm.market[crop].seed == prices[crop].seed and prices[crop].seed > 0, crop + " fixed seed price")
		for island in [1]:
			var bed: Dictionary = farm.plots[0].duplicate(true)
			bed.merge({"crop":crop, "stage":3, "tilled":true, "watered":true}, true)
			var count: int = farm._harvest_plot(bed)
			check(count == State.CropTable.CROPS[crop]["yield"] and count >= 2 and count <= 5, crop + " healthy yield stays 1x on island " + str(island))
	for costs: Array in State.TOOL_COSTS.values():
		for cost: float in costs: check(cost >= 12000 and cost <= 60000, "bounded tool prices")
	check(State.FIELD_EXPANSION_COST == 48000, "flat field expansion cost")
	farm.reset_game()
	farm.coins = 400000
	for cost: float in [12000.0, 32000.0, 80000.0]:
		var before: float = farm.coins
		farm.upgrade_barn()
		check(farm.coins == before - cost, "barn charges its next fixed price")
	var balance: float = farm.coins
	farm.upgrade_barn()
	check(farm.coins == balance and farm.barn_level == 3, "only three barn upgrades")
	check(farm.money(12345.4) == "\uE000 12,345" and farm.money(-5000) == "-\uE000 5,000", "money uses grouped integers and the Spudion glyph")
	farm.coins = -1
	check(farm.can_purchase(1), "purchases may use the bounded overdraft")
	farm.coins = -200000
	check(not farm.run_over, "exact overdraft boundary remains playable")
	farm.coins = farm.OVERDRAFT_LIMIT + farm.ledger.fixed_cost_total() - 1
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.run_over and farm.climate.data.collapse.balance == -200001, "Winter fixed costs crossing the limit capture the final receipt")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "ended run persists")
	farm.reset_game()
	var data: Dictionary = farm._save_data()
	for key in ["blind_cycle", "combo_count", "combo_multiplier", "combo_time", "coins_scientific", "tax_credit_eligible", "harvest_fraction", "mastery"]: check(not data.has(key), key + " no longer saved")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "farm round trips")
	farm.reset_game()
	farm.elapsed = farm.MAX_MONEY * 2
	farm.climate.begin_warning(farm, "flood", 1.0)
	farm.climate._impact(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "long weather timestamps are not limited by the money cap")
	farm.coins = farm.OVERDRAFT_LIMIT + farm.ledger.fixed_cost_total() - 1
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "late-run final receipt preserves elapsed time")
	for suffix in ["", ".bak", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	farm.free()
	await ui_checks()
	print("ECONOMY SCALE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_balance_constants() -> void:
	# Rates may legitimately be fractional (or zero); free grower enrolment is
	# the only zero monetary price. Signed costs are checked by magnitude.
	var rates := ["PEST_CHANCE","VOLATILITY", "GRADE_MULTIPLIER", "INSURANCE_PAYOUT", "PROTECTION_REDUCTION", "SPOILAGE", "CLIMATE_BASE_CHANCE", "CLIMATE_CHANCE_STEP", "CLIMATE_MAX_CHANCE", "CLIMATE_BASE_SEVERITY", "CLIMATE_SEVERITY_STEP", "CLIMATE_SEVERITY_SPREAD", "CLIMATE_SIGNAL_CHANCE", "CLIMATE_FALSE_ALARM_CHANCE", "CLIMATE_WINTER_LOSS", "CONTRACT_PRICE_FACTOR", "GROWER_PRICE_FACTOR"]
	var constants: Dictionary = Balance.new().get_script().get_script_constant_map()
	for key in constants:
		if key not in rates: check_scaled_value(constants[key], key)
	check(Balance.MONEY_SCALE == 40 and Balance.CROPS.russet.base == 360 and Balance.CROPS.icecap.base == 1200, "one factor produces farm-sized per-tonne prices")
	check(Balance.STARTING_CASH == 80000 and Balance.OVERDRAFT_LIMIT == -200000 and Balance.INITIAL_LOAN == 480000, "cash, debt limit and loan scale together")
	var fixed: float = 0
	for cost in Balance.FIXED_COSTS: fixed += cost.amount
	check(fixed == -104000 and Balance.MAX_MONEY == 4000000, "annual costs and debug cash cap scale")
	check(Balance.GRADE_MULTIPLIER == {"Table":1.2,"Standard":1.0,"Feed":0.5} and Balance.TABLE_THRESHOLD == 80, "grade rates and thresholds stay tuned")

func check_scaled_value(value: Variant, path: String) -> void:
	if value is Dictionary:
		for key in value: check_scaled_value(value[key], path + "." + str(key))
	elif value is Array:
		for i in range(value.size()): check_scaled_value(value[i], path + "." + str(i))
	elif value is float or value is int:
		check(is_finite(float(value)) and (absf(float(value)) >= 1 or (path == "BUSINESS_COSTS.grower" and value == 0)), path + " is at least one in magnitude unless an explicit rate or free enrolment")

func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var farm = game.state
	farm.Stock.add(farm.storage, "icecap", 20, 60)
	for size in [Vector2i(1280,800), Vector2i(390,844)]:
		root.size = size
		game.hud.show_panel("market", farm)
		for frame in range(8): await process_frame
		check(game.hud._refs["russet:seed_price"].text == "\uE000 270" and game.hud._refs["icecap:seed_price"].text == "\uE000 1,200", "seed packets show grouped per-seed prices")
		game.hud.show_panel("sell_potatoes", farm)
		var page = game.hud._refs.market_page
		page.selected = "icecap"
		page.selected_grade = "Standard"
		page.refresh()
		page.quantity.set_value_no_signal(3)
		page.refresh()
		for frame in range(8): await process_frame
		check(page.crop_quote.text == "\uE000 1,200/t" and page.payout.text == "\uE000 3,600" and page.crop_quote.tooltip_text.contains("per tonne"), "sell page shows grouped integer quotes and totals")
		check(page.grade_buttons.Standard.text.contains(" t") and page.crop_owned.text.contains("fresh tonnes"), "sell cards identify tonnes")
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "market fits desktop and phone")
		await capture("sell-%d" % size.x)
		page._sold({"id":"icecap","quantity":3,"total":3600})
		check(page.status.text.contains("3 t sold") and page.status.text.contains("3,600"), "sale receipt carries tonnes and grouped money")
		page.quantity.text = ""
		page.quantity.text_changed.emit("")
		page.refresh()
		check(page.payout.text == "\uE000 0", "invalid quantity never displays decimal money")
		game.hud.show_panel("inventory", farm)
		for frame in range(8): await process_frame
		var barn = game.hud._refs.shop_page
		check(game.hud._refs.inventory_total.text == "20 / 200 t", "barn quantities and capacity use tonnes")
		for entry in farm.inventory_info():
			if entry.kind == "crop": check(barn._item_quantities[entry.id].text.ends_with(" t"), "crop bins use tonnes")
	game.hud.close_panel()
	farm.reset_game()
	farm.update(450)
	for size in [Vector2i(1280,800), Vector2i(390,844)]:
		root.size = size
		game.hud.show_panel("accounts", farm)
		for frame in range(8): await process_frame
		check(game.hud._refs.accounts_net.text.contains("104,000") and game.hud._refs.accounts_mortgage.text == "-\uE000 48,000", "accounts show farm-sized annual costs")
		check(game.hud._refs.accounts_balance.text.contains("200,000") and game.hud._refs.accounts_balance.text.contains("456,000"), "accounts show grouped debt limit and remaining loan")
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "accounts fit desktop and phone")
		await capture("ledger-%d" % size.x)
	game.queue_free()
	await process_frame
	# Let the audio mixer release the accountant's stopped voice playback.
	await create_timer(0.4).timeout

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/farm-units-" + label + ".png")
