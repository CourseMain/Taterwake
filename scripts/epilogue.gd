extends RefCounted
## An isolated continuation of GameState, with ordinary actions and quarter-second
## weather. No new projects, businesses, crops, grants or random seed are added.
const State = preload("res://scripts/game_state.gd")
const Operations = preload("res://scripts/climate_operations.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Balance = preload("res://scripts/balance.gd")
const OUTCOMES := ["Dust", "Drowned", "Deserted", "Sold to the estate", "Holding on", "The shop village", "Thriving"]
const AXES := ["solvency", "adaptation", "diversification", "land_health"]
var farm
var crops: Array[String] = []
var projects: Dictionary = {}
var conditions: Dictionary = {}
var years: Array[Dictionary] = []
var initial_cash: float
var initial_debt: float
var initial_year: int
var failed_year: int = 0
var health: float = 1.0
var exposure := {"drought": 0.0, "flood": 0.0, "storm": 0.0, "freeze": 0.0}
var record_cursor: int = 0
var insured: bool = false
var result: Dictionary = {}
var working_year: int = 0
var opening: float = 0
var last_season: int = -1
var planted: Dictionary = {}

func begin(snapshot: Dictionary) -> void:
	# Use the save format's numeric precision for both a live final state and a
	# reloaded one. The projection must not change after closing the browser.
	snapshot = JSON.parse_string(JSON.stringify(snapshot))
	farm = State.new()
	if snapshot.has("activities"):
		farm.activity_system = preload("res://scripts/island_activities.gd").new()
		farm.activity_system.setup(farm)
	farm.restore_snapshot(snapshot)
	initial_cash = farm.coins
	initial_debt = farm.ledger.loan_remaining()
	initial_year = farm.season_clock.year
	projects = farm.climate.data.projects.duplicate(true)
	for id in projects: conditions[id] = 1.0
	for plot in farm.plots: crops.append(str(plot.crop))
	insured = Protection.insured(farm)
	if farm.run_outcome == "foreclosed": failed_year = initial_year
	# Carry earlier repeated disasters into the soil, even though seasonal rescue
	# stress is cleared by the ordinary Winter boundary.
	for event in farm.climate.data.outlook.records: _weather_soil(event, 0.5)
	for stress in farm.climate.data.operations.stress.values(): health -= float(stress) / 240.0
	health = clampf(health, 0, 1)
	record_cursor = farm.climate.data.outlook.records.size()
	farm.caretaker_mode = true
	farm.season_clock.last_year = 50
	farm.ledger.last_year = 50
	farm.run_over = false
	farm.run_outcome = ""
	farm.accounts_open = false
	farm.climate_report_open = false
	farm.tutorial_active = false
	farm.climate.data.lesson.stage = "done"
	# At a completed boundary the clock still reads Winter second 150.
	# Advance that boundary once, without charging year ten again.
	if farm.season_clock.seconds == farm.season_seconds():
		farm.season_clock.seconds = 0
		farm.season_clock.season = 0
		farm.season_clock.year += 1
		farm._season_boundary()

func advance_year(tick_budget: int = 100000) -> bool:
	if not result.is_empty(): return true
	var year: int = farm.season_clock.year
	if year != working_year:
		working_year = year
		opening = farm.coins
		last_season = -1
		planted.clear()
	var ticks: int = 0
	while farm.season_clock.year == year and not farm.run_over:
		if ticks >= tick_budget: return false
		ticks += 1
		var season: int = farm.season_clock.season
		if season != last_season:
			last_season = season
			planted.clear()
			if failed_year == 0:
				if season == 0:
					if insured: Protection.insure(farm)
					if farm.trading.grower_active(farm):
						for slot in range(farm.trading.order_limit(farm)):
							if farm.trading.offer(year, slot, true).crop in crops: farm.trading.accept(farm, slot)
				if season == 3: _repair()
		if failed_year == 0:
			if season == 3 and farm.season_clock.seconds >= 149:
				for crop in State.CROP_IDS: farm.trading.sell_stored(farm, crop)
			_work(planted)
		farm.update(1.0)
		if failed_year == 0 and farm.season_clock.season == 3 and farm.coins < Balance.OVERDRAFT_LIMIT:
			failed_year = farm.season_clock.year
		while record_cursor < farm.climate.data.outlook.records.size():
			_weather_soil(farm.climate.data.outlook.records[record_cursor])
			record_cursor += 1
	years.append({"year": year, "opening": opening, "closing": farm.coins, "net": farm.coins - opening, "land_health": health})
	if farm.run_over: _finish()
	return not result.is_empty()

func _work(planted: Dictionary) -> void:
	var season: int = farm.season_clock.season
	for i in range(farm.plots.size()):
		var plot: Dictionary = farm.plots[i]
		if not plot.unlocked: continue
		if Operations.frozen(farm, i): farm.interact_plot(i, "hoe")
		if season == 3 and Protection.can_cover(farm, i): Protection.cover(farm, i)
		if int(plot.stage) == 0 and season in [0, 1] and not planted.has(i):
			farm.select_crop(crops[i])
			farm.interact_plot(i, "hoe")
			if int(farm.seed_inventory[crops[i]]) == 0: farm.buy_seeds(crops[i], 1)
			farm.interact_plot(i, "plant")
			if int(plot.stage) > 0: planted[i] = true
		if Operations.needs_water(farm, i):
			if float(Operations.local(farm).can) < 1: Operations.refill(farm)
			farm.interact_plot(i, "water")
		if plot.pests: farm.interact_plot(i, "pest")
		if int(plot.stage) == 3:
			var crop: String = plot.crop
			var before: int = farm.stock_count(crop)
			farm.interact_plot(i, "harvest")
			var amount: int = farm.stock_count(crop) - before
			var promised: int = 0
			for order in farm.trading.contracts:
				if order.crop == crop: promised += int(order.quantity)
			var sell: int = mini(amount / 2, maxi(0, farm.stock_count(crop) - promised))
			if sell > 0: farm.sell_crop(crop, sell)

func _weather_soil(event: Dictionary, weight: float = 1.0) -> void:
	var kind: String = str(event.event)
	if kind not in exposure: kind = "freeze"
	var project: String = Protection.PROJECT_FOR[kind]
	var level: int = int(projects.get(project, 0))
	var reduction: float = Protection.REDUCTION[level] * float(conditions.get(project, 1.0))
	var stress: float = float(event.severity) * (1.0 - reduction) * weight
	exposure[kind] += stress
	# Trees slow erosion; maintained water projects keep the soil usable.
	var trees: float = float(projects.get("windbreaks", 0)) / 2.0
	health = clampf(health - stress * 0.009 * (1.0 - trees * 0.4), 0.0, 1.0)
	if conditions.has(project): conditions[project] = maxf(0, conditions[project] - float(event.severity) * 0.06)

func _repair() -> void:
	for id in projects:
		var damage: float = 1.0 - float(conditions[id])
		var cost: float = damage * Balance.PROTECTION_UPKEEP * int(projects[id])
		if cost > 0 and farm.coins >= cost:
			farm.post_money("upkeep", Protection.NAMES.get(id, "Irrigation") + " caretaker repair", -cost)
			conditions[id] = 1.0
		# Failed equipment loses its protection until repaired; original levels
		# remain the ceiling, so maintenance can never become a new investment.
		farm.climate.data.projects[id] = projects[id] if float(conditions[id]) >= 0.5 else 0

func _finish() -> void:
	var axes: Dictionary = {}
	var trend: float = 0
	for row in years.slice(maxi(0, years.size() - 10)): trend += float(row.net) / 10.0
	var cash_score: float = clampf((initial_cash - initial_debt + Balance.INITIAL_LOAN) / Balance.INITIAL_LOAN, 0, 1)
	var trend_score: float = clampf((trend + Balance.STARTING_CASH * 0.5) / Balance.STARTING_CASH, 0, 1)
	var liquidity: float = clampf((farm.coins - Balance.OVERDRAFT_LIMIT) / (-3.0 * Balance.OVERDRAFT_LIMIT), 0, 1)
	axes.solvency = clampf(cash_score * 0.25 + trend_score * 0.35 + liquidity * 0.4, 0, 1)
	var adaptation: float = 0
	var pressure: float = 0
	for kind in exposure:
		var id: String = Protection.PROJECT_FOR[kind]
		var weight: float = maxf(1.0, float(exposure[kind]))
		adaptation += weight * float(projects.get(id, 0)) / 2.0 * float(conditions.get(id, 1.0))
		pressure += weight
	axes.adaptation = adaptation / pressure
	var receipts: float = 0
	var business: float = 0
	for entry in farm.ledger.entries:
		if int(entry.year) <= initial_year or float(entry.amount) <= 0: continue
		if entry.category in ["sales", "contracts"] or farm.diversification.income_entry(entry): receipts += float(entry.amount)
		if farm.diversification.income_entry(entry): business += float(entry.amount)
	# Half of receipts independent of ordinary crop sales is a full score.
	axes.diversification = clampf(business / maxf(1, receipts) * 2.0, 0, 1)
	axes.land_health = health
	var outcome: String = classify(axes, exposure, failed_year)
	var value: float = maxf(0, Balance.INITIAL_LOAN * health + farm.coins - farm.ledger.loan_remaining())
	result = {"clothing_unlocked": farm.clothing_unlocked.duplicate(), "decorations": farm.decorations.duplicate(), "farmer_appearance": farm.farmer_appearance.duplicate(), "outcome": outcome, "axes": axes, "failed_year": failed_year, "years": years.duplicate(true), "records": farm.climate.data.outlook.records.duplicate(true), "farm_value": value, "cash": farm.coins, "debt": farm.ledger.loan_remaining(), "projects": projects.duplicate(), "active_projects": farm.climate.data.projects.duplicate(), "conditions": conditions.duplicate(), "crops": crops.duplicate(), "headlines": headlines(farm.climate.data.outlook.records), "verdicts": verdicts(axes)}
	if is_instance_valid(farm.activity_system): farm.activity_system.free()
	farm.free()
	farm = null

static func classify(axes: Dictionary, burdens: Dictionary, failure: int = 0) -> String:
	var strong: bool = true
	for axis in AXES: strong = strong and float(axes[axis]) > 0.75
	if strong: return "Thriving"
	if float(axes.land_health) < 0.25:
		return "Drowned" if float(burdens.get("flood", 0)) > float(burdens.get("drought", 0)) else "Dust"
	if failure > 0:
		return "Sold to the estate" if failure <= 20 else "Deserted"
	if float(axes.diversification) >= 0.45: return "The shop village"
	return "Holding on"

static func verdicts(axes: Dictionary) -> Array[String]:
	return ["Solvency · " + ("The books still balance." if axes.solvency > 0.5 else "The bank outlasted the harvests."),
		"Adaptation · " + ("Protection kept pace with the weather." if axes.adaptation > 0.5 else "The weather outran the protection."),
		"Diversification · " + ("There was more than one way to earn." if axes.diversification >= 0.45 else "Everything still rested on potatoes."),
		"Land health · " + ("There is living soil to hand on." if axes.land_health > 0.5 else "The soil carries the cost of fifty years.")]

static func headlines(records: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for decade in range(1, 6):
		var count: int = 0
		var severity: float = 0
		for event in records:
			if int(event.year) > (decade - 1) * 10 and int(event.year) <= decade * 10:
				count += 1
				severity += float(event.severity)
		rows.append({"year": decade * 10, "text": ["The warnings became a pattern", "Extreme weather becomes ordinary", "A generation farming through disaster", "The old seasons are a memory", "What the next generation inherits"][decade - 1], "events": count, "severity": severity / maxf(1, count)})
	return rows

static func simulate(snapshot: Dictionary) -> Dictionary:
	var continuation = load("res://scripts/epilogue.gd").new()
	continuation.begin(snapshot)
	while not continuation.advance_year(): pass
	return continuation.result
