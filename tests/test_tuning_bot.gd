extends SceneTree
## Fixed policies, seeds 1..30. No invented yields, cash grants, forced weather,
## clock jumps, tutorial protection or debug purchases. Quarter-second hazards
## still run inside State.update; decisions are taken once per simulated second.
## v2.1.0 table · seeds 1..30 · owner's decision, 2026-10-12.
## Strategy     Survived Median year Mean cash   Max cash    Mean sales
## naive        0/30     5.0         -245254.65  -204288.99  483638.69
## cautious     30/30    10.0        60.75       95596.63    1402986.83
## tidy         30/30    10.0        293755.95   350722.25   1785475.63
## diversifier  30/30    10.0        82793.67    183550.81   1369195.49
## expander     30/30    10.0        152848.09   260278.61   2136596.57
## gambler      30/30    10.0        -33917.73   7696.63     1385359.37
## Gambler min -79688.57; above tidy mean 0/30; foreclosed 0/30.
## The two spread gates land in part J, then are rechecked at V2 and V4.
const State = preload("res://scripts/game_state.gd")
const Balance = preload("res://scripts/balance.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const STRATEGIES = ["naive", "cautious", "tidy", "diversifier", "expander", "gambler"]
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
	var mean_cash: Dictionary = {}
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
			check(not row.completed or row.cash <= (640000 if strategy in ["gambler","punter","trader"] else 400000), "%s seed %d cash ceiling: %.2f" % [strategy, row.seed, row.cash])
		years.sort()
		print("%s: survived %d/30, median end year %.1f, mean cash %.2f, max cash %.2f, mean sales %.2f" % [strategy, survived, (years[14]+years[15])/2.0, cash/30, best, sales/30])
		mean_cash[strategy] = cash / rows.size()
		if strategy == "naive": check((years[14]+years[15])/2.0 <= 6, "naive median foreclosure by year six")
		if strategy == "cautious": check(survived >= 24, "cautious survives at least 24 seeds")
		if strategy == "tidy":
			check(survived == 30, "tidy survives all thirty seeds")
			check(cash / rows.size() < 320000, "tidy mean ending cash stays below 320,000: %.2f" % (cash / rows.size()))
		if strategy == "diversifier": check(survived >= 24, "diversifier survives at least 24 seeds")
		if strategy == "expander": check(survived >= 24, "expander survives at least 24 seeds")
	# Frozen survival counts from tag v2.0.6; change only when a plan part says re-record.
	var baseline := {"naive":0, "cautious":30, "tidy":30, "diversifier":28, "expander":29}
	for strategy in baseline:
		check(absi(results[strategy].filter(func(row): return row.completed).size() - baseline[strategy]) <= 2, strategy + " survival stays within two seeds of v2.0.6")
	var gambler: Array = results.gambler
	var high: int = gambler.filter(func(row): return float(row.cash) > mean_cash.tidy).size()
	var foreclosed: int = gambler.filter(func(row): return not row.completed).size()
	var low: float = INF; var best: float = -INF
	for row in gambler: low = minf(low, row.cash); best = maxf(best, row.cash)
	print("Gambler spread: min %.2f, mean %.2f, max %.2f, above tidy mean %d/30, foreclosed %d/30" % [low, mean_cash.gambler, best, high, foreclosed])
	check(mean_cash.gambler > mean_cash.naive and mean_cash.gambler < mean_cash.tidy, "gambler mean stays between naive and tidy")
	print("Gambler above tidy mean: %d/30 (gate lands in part J)" % high)
	print("Gambler foreclosed: %d/30 (gate lands in part J)" % foreclosed)
	check(absi(gambler.filter(func(row): return row.completed).size()-results.cautious.filter(func(row): return row.completed).size()) <= 2,"gambler survival stays within two seeds of cautious")
	check(gambler.all(func(row): return int(row.pack_seeds_planted)>0),"every gambler plants ordinary seeds won from packs in free beds")
	check(gambler.any(func(row): return int(row.pack_oddities_sold)>0),"gambler sells pack oddities with ordinary stock")
	check(best <= 640000, "no gambler seed exceeds 640,000")
	check(mean_cash.expander > mean_cash.cautious and mean_cash.expander < mean_cash.tidy, "expansion mean cash stays between cautious and tidy")
	check(mean_cash.expander >= mean_cash.cautious + 40000, "expansion mean cash exceeds cautious by at least 40,000")
	check(mean_cash.diversifier >= mean_cash.cautious + 40000, "diversification mean cash exceeds cautious by at least 40,000")
	check(mean_cash.diversifier < mean_cash.tidy, "diversification mean cash stays below tidy")
	var cautious_sales := 0.0
	var tidy_sales := 0.0
	var expander_sales := 0.0
	for i in range(30):
		cautious_sales += results.cautious[i].sales
		tidy_sales += results.tidy[i].sales
		expander_sales += results.expander[i].sales
		check(results.diversifier[i].business_income > 0 and results.diversifier[i].businesses.has("grower"), "diversifier earns business income seed %d" % (i+1))
	check(results.diversifier.filter(func(row): return row.businesses.has("shop")).size() >= 24, "at least 24 diversifiers build the shop without invented funding")
	check(expander_sales > cautious_sales, "expander out-earns cautious in mean sales")
	var advantage: float = tidy_sales / cautious_sales - 1.0
	print("Tidy ten-year sales advantage: %.2f%%" % (100 * advantage))
	check(advantage >= 0.15 and advantage <= 0.40, "tidy earns 15–40% more crop receipts across matched seeds")
	print("Tuning bot: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func play(strategy: String, seed_value: int, keep_snapshot: bool = false) -> Dictionary:
	var farm = State.new()
	farm.rng.seed = seed_value
	# Owner's decision, 2026-10-12: the donated Twin is collection progress,
	# excluded from simulation stock, never sold. Keep the frozen five policies.
	farm.Stock.take(farm.storage,"russet",1,"Standard")
	farm.pedlar.data.oddities[0].held = false
	# All policies pay for the same 24-bed field, keeping labour area comparable.
	farm.expand_field()
	var crops: Array[String] = State.crops_by_base_price(State.CropTable.MARA_IDS)
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
	var pack_seeds: Array[String] = []
	var won_planted: int = 0
	var oddities_sold: int = 0
	var blue_planted: bool = false
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
			if season == 3 and year == 1 and strategy == "expander": farm.rent_field("low")
			if season == 0 and year >= 2 and not naive: Protection.insure(farm)
			# Bind only matching Golden orders: planting choice stays legible and
			# the bot does not knowingly promise crops it will never grow.
			if season == 0 and strategy == "diversifier" and farm.trading.grower_active(farm):
				for slot in range(farm.trading.order_limit(farm)):
					if farm.trading.offer(year, slot, true).crop == crop: farm.trading.accept(farm, slot)
			if season == 3: sold_winter = false; built_winter = false
		if strategy == "gambler" and season == 0 and year >= 2:
			for pack: String in farm.Pedlar.PACK_IDS:
				var prize: Dictionary = farm.pedlar.buy(farm, pack)
				if prize.is_empty() or prize.has("error"): continue
				if prize.kind == "seeds" and prize.id != "blue_pearl":
					for seed_number in range(Balance.PEDLAR_SEED_COUNT if pack == "seed" else Balance.PEDLAR_MYSTERY_SEEDS): pack_seeds.append(prize.id)
				if prize.kind == "oddity":
					farm.sell_crop(prize.id,1,"Standard"); oddities_sold += 1
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
			if not plot.unlocked: continue
			# Shared rescue routine for ice; naive still performs ordinary farm work.
			if Operations.crop_frozen(farm,i): farm.interact_plot(i,"hoe")
			if int(plot.stage) == 0 and season in [0,1] and not planted.has(i):
				farm.interact_plot(i,"hoe")
				var planting: String = str(pack_seeds[0]) if strategy == "gambler" and not pack_seeds.is_empty() else crop
				farm.select_crop(planting)
				if int(farm.seed_inventory[planting]) == 0: farm.buy_seeds(planting,1)
				farm.interact_plot(i,"plant")
				blue_planted = blue_planted or (int(plot.stage)>0 and plot.crop=="blue_pearl")
				if int(plot.stage) > 0 and strategy == "gambler" and not pack_seeds.is_empty(): pack_seeds.pop_front(); won_planted += 1
				farm.select_crop(crop)
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
	check(not blue_planted,"bot never plants Blue Pearl seed %d" % seed_value)
	check(farm.run_outcome in ["completed","foreclosed"], "run has a real ending")
	if tidy: check(table_sacks > harvested/2, "tidy majority Table seed %d" % seed_value)
	var result: Dictionary = {"seed":seed_value,"year":farm.season_clock.year,"completed":farm.run_outcome == "completed","cash":farm.coins,"sales":farm.ledger.total(0,"sales"), "table_sacks":table_sacks, "harvested_sacks":harvested, "years":annual, "businesses":farm.diversification.built.duplicate(), "business_income":farm.diversification.income(farm), "title":farm.run_title(),"pack_seeds_planted":won_planted,"pack_oddities_sold":oddities_sold}
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
