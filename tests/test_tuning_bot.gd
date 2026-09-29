extends SceneTree
## Fixed policies, seeds 1..30. No invented yields, cash grants, forced weather,
## clock jumps, tutorial protection or debug purchases. Quarter-second hazards
## still run inside State.update; decisions are taken once per simulated second.
const State = preload("res://scripts/game_state.gd")
const Balance = preload("res://scripts/balance.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const STRATEGIES = ["naive", "cautious", "tidy", "diversifier"]
const BASELINE_PATH = "res://tests/fixtures/tuning_before_unit_scale.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/test-results")
	var results: Dictionary = {}
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH)).strategies
	for strategy in STRATEGIES:
		var rows: Array = []
		for seed_value in range(1, 31): rows.append(play(strategy, seed_value))
		results[strategy] = rows
		FileAccess.open("res://artifacts/test-results/tuning_" + strategy + ".json", FileAccess.WRITE).store_string(JSON.stringify(rows))
		var survived := 0
		var cash := 0.0
		var sales := 0.0
		var best := -INF
		var years: Array = []
		for row in rows:
			if row.completed: survived += 1
			cash += row.cash; sales += row.sales; best = maxf(best, row.cash)
			years.append(row.year)
			check(not row.completed or row.cash <= 320000, "%s seed %d cash ceiling: %.2f" % [strategy, row.seed, row.cash])
		years.sort()
		print("%s: survived %d/30, median end year %.1f, mean cash %.2f, max cash %.2f, mean sales %.2f" % [strategy, survived, (years[14]+years[15])/2.0, cash/30, best, sales/30])
		var expected_mean: float = 0.0
		for i in range(rows.size()):
			var old: Dictionary = baseline[strategy][i]
			var current: Dictionary = rows[i]
			expected_mean += float(old.cash) * Balance.MONEY_SCALE / 30.0
			check(current.seed == old.seed and current.year == old.year and current.completed == old.completed and current.harvested_sacks == old.harvested_sacks and current.table_sacks == old.table_sacks, "%s seed %d keeps its unscaled outcome and quantities" % [strategy, current.seed])
			for key in ["cash", "sales", "business_income"]:
				check(absf(float(current[key]) - float(old[key]) * Balance.MONEY_SCALE) < 0.00001, "%s seed %d %s scales by forty" % [strategy, current.seed, key])
		check(absf(cash / 30.0 - expected_mean) < 0.00001, strategy + " mean cash is the old mean times forty")
		if strategy == "naive": check((years[14]+years[15])/2.0 <= 6, "naive median foreclosure by year six")
		if strategy == "cautious": check(survived >= 24, "cautious survives at least 24 seeds")
		if strategy == "tidy":
			check(survived == 30, "tidy survives all thirty seeds")
			check(cash / rows.size() < 320000, "tidy mean ending cash stays below 320,000: %.2f" % (cash / rows.size()))
		if strategy == "diversifier": check(survived >= 24, "diversifier survives at least 24 seeds")
	var cautious_sales := 0.0
	var tidy_sales := 0.0
	for i in range(30):
		cautious_sales += results.cautious[i].sales
		tidy_sales += results.tidy[i].sales
		check(results.diversifier[i].business_income > 0 and results.diversifier[i].businesses.has("grower"), "diversifier earns business income seed %d" % (i+1))
	check(results.diversifier.filter(func(row): return row.businesses.has("shop")).size() >= 24, "at least 24 diversifiers build the shop without invented funding")
	var advantage: float = tidy_sales / cautious_sales - 1.0
	print("Tidy ten-year sales advantage: %.2f%%" % (100 * advantage))
	check(advantage >= 0.15 and advantage <= 0.40, "tidy earns 15–40% more crop receipts across matched seeds")
	print("Tuning bot: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func play(strategy: String, seed_value: int, keep_snapshot: bool = false) -> Dictionary:
	var farm = State.new()
	farm.rng.seed = seed_value
	# All policies pay for the same 24-bed field, keeping labour area comparable.
	farm.expand_field()
	var crops: Array[String] = State.crops_by_base_price(State.CROP_IDS)
	var crop: String = crops[-1] if strategy == "naive" else crops[crops.size()/2]
	farm.select_crop(crop)
	var tidy: bool = strategy == "tidy"
	var naive: bool = strategy == "naive"
	var year_open: float = Balance.STARTING_CASH
	var last_year := 1
	var last_season := -1
	var planted: Dictionary = {}
	var sold_winter := false
	var built_winter := false
	var table_sacks := 0
	var harvested := 0
	var annual: Array = []
	for tick in range(6001):
		if farm.run_over: break
		var year: int = farm.season_clock.year
		var season: int = farm.season_clock.season
		if year != last_year:
			annual.append(reconcile(farm, last_year, year_open, strategy, seed_value))
			year_open = farm.coins
			last_year = year
		if season != last_season:
			last_season = season
			planted.clear()
			if season == 0 and year >= 2 and not naive: Protection.insure(farm)
			# Bind only matching Golden orders: planting choice stays legible and
			# the bot does not knowingly promise crops it will never grow.
			if season == 0 and strategy == "diversifier" and farm.trading.grower_active(farm):
				for slot in range(farm.trading.order_limit(farm)):
					if farm.trading.offer(year, slot, true).crop == crop: farm.trading.accept(farm, slot)
			if season == 3: sold_winter = false; built_winter = false
		# Accounts are presentation-only in the scene; the standalone state keeps running.
		farm.accounts_open = false
		if season == 3:
			for i in range(farm.plots.size()):
				if Operations.frozen(farm, i): farm.interact_plot(i, "hoe")
			if not naive and not sold_winter and farm.season_clock.seconds >= 149:
				for id in State.CROP_IDS: farm.trading.sell_stored(farm, id)
				sold_winter = true
				if strategy == "diversifier" and year >= Balance.DIVERSIFY_YEAR:
					farm.diversification.buy(farm, "grower")
					# At most one new building per Winter; keep 40,000 of credit for
					# next Spring's seeds/insurance rather than exhausting the bank.
					var business: String = "lodging" if farm.diversification.owns("shop") else "shop"
					if farm.coins - Balance.BUSINESS_COSTS[business] >= Balance.OVERDRAFT_LIMIT + 40000:
						farm.diversification.buy(farm, business)
			if not naive and not built_winter:
				var id: String = "rainwater" if int(farm.climate.data.projects.get("rainwater",0)) == 0 else "drainage"
				if int(farm.climate.data.projects.get(id,0)) == 0 and farm.can_purchase(Protection.COSTS[id]):
					farm.climate.fund(farm,id)
					for action in range(Protection.WORK_ACTIONS): Protection.work(farm,id)
					built_winter = true
		for i in range(farm.plots.size()):
			var plot: Dictionary = farm.plots[i]
			# Shared rescue routine for ice; naive still performs ordinary farm work.
			if Operations.crop_frozen(farm,i): farm.interact_plot(i,"hoe")
			if int(plot.stage) == 0 and season in [0,1] and not planted.has(i):
				farm.interact_plot(i,"hoe")
				if int(farm.seed_inventory[crop]) == 0: farm.buy_seeds(crop,1)
				farm.interact_plot(i,"plant")
				if int(plot.stage) > 0: planted[i] = true
			if int(plot.stage) in [1,2] and (tidy or float(plot.plant_age) >= 30):
				if Operations.needs_water(farm,i):
					if float(Operations.local(farm).can) < 1: Operations.refill(farm)
					farm.interact_plot(i,"water")
			if tidy and plot.pests: farm.interact_plot(i,"pest")
			if int(plot.stage) == 3 and (tidy or naive or float(plot.quality_ripe_age) >= 35):
				var id: String = plot.crop
				var before: int = farm.stock_count(id)
				var table_before: int = farm.stock_count(id,"Table")
				farm.interact_plot(i,"harvest")
				var amount: int = farm.stock_count(id)-before
				harvested += amount
				table_sacks += farm.stock_count(id,"Table")-table_before
				# Sell exactly half cumulatively (including odd sacks), leaving the
				# other half in the barn for automatic Winter storage.
				var sell: int = amount if naive else (harvested/2 - (harvested-amount)/2)
				if strategy == "diversifier":
					var promised: int = 0
					for order in farm.trading.contracts:
						if order.crop == id: promised += int(order.quantity)
					sell = mini(sell, maxi(0, farm.stock_count(id) - promised))
				if sell > 0: farm.sell_crop(id,sell)
		farm.update(1.0)
	annual.append(reconcile(farm,last_year,year_open,strategy,seed_value))
	check(farm.run_outcome in ["completed","foreclosed"], "run has a real ending")
	if tidy: check(table_sacks > harvested/2, "tidy majority Table seed %d" % seed_value)
	var result: Dictionary = {"seed":seed_value,"year":farm.season_clock.year,"completed":farm.run_outcome == "completed","cash":farm.coins,"sales":farm.ledger.total(0,"sales"), "table_sacks":table_sacks, "harvested_sacks":harvested, "years":annual, "businesses":farm.diversification.built.duplicate(), "business_income":farm.diversification.income(farm), "title":farm.run_title()}
	if keep_snapshot: result.snapshot = farm._save_data()
	farm.free()
	return result

func reconcile(farm, year: int, opening: float, strategy: String, seed_value: int) -> Dictionary:
	# Replay from the observed opening purse in posting order. Floating-point
	# addition is not associative: summing from zero and subtracting a different
	# opening balance can introduce rounding noise. This comparison is exact,
	# with no tolerance and no synthetic balancing journal entries.
	var closing: float = opening
	for entry in farm.ledger.entries:
		if int(entry.year) == year: closing += float(entry.amount)
	check(closing == farm.coins and closing-opening == farm.coins-opening, "%s seed %d year %d journal equals cash delta" % [strategy,seed_value,year])
	return {"year":year, "opening":opening, "closing":farm.coins, "net":closing-opening, "categories":farm.ledger.category_totals(year)}
