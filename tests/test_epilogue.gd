extends "res://tests/test_tuning_bot.gd"
const Epilogue = preload("res://scripts/epilogue.gd")

func run() -> void:
	var outcomes: Array[String] = []
	for strategy in ["naive", "cautious", "diversifier"]:
		var played: Dictionary = play(strategy, 1, true)
		var snapshot: Dictionary = played.snapshot
		var before: String = var_to_str(snapshot)
		var ending: Dictionary = Epilogue.simulate(snapshot)
		print("%s: %s %s, failure %s, cash %s" % [strategy, ending.outcome, ending.axes, ending.failed_year, ending.cash])
		check(var_to_str(snapshot) == before, "continuation never mutates source " + strategy)
		check(ending.years[-1].year == 50, "continues to year fifty " + strategy)
		if played.completed: check(ending.years.size() == 40 and ending.years[0].year == 11, "exactly forty additional years")
		for axis in ending.axes: check(ending.axes[axis] >= 0 and ending.axes[axis] <= 1, "bounded " + axis)
		check(ending.headlines.size() == 5, "one headline per decade")
		var repeated = Epilogue.new()
		repeated.begin(JSON.parse_string(JSON.stringify(snapshot)))
		var observed_year: int = 0
		while not repeated.advance_year(80):
			if repeated.farm.season_clock.year == observed_year: continue
			observed_year = repeated.farm.season_clock.year
			check(repeated.farm.diversification.built.size() == snapshot.diversification.built.size(), "caretaker keeps the same business count")
			for id in snapshot.diversification.built:
				check(repeated.farm.diversification.owns(id) and int(repeated.farm.diversification.built[id]) == int(snapshot.diversification.built[id]), "caretaker keeps business ownership and construction year")
			for id in repeated.farm.climate.data.projects:
				check(int(repeated.farm.climate.data.projects[id]) <= int(snapshot.climate.projects.get(id, 0)), "caretaker never adds protection")
		check(ending == repeated.result, "deterministic after JSON reload and frame batching " + strategy)
		outcomes.append(ending.outcome)
		if strategy == "diversifier":
			DirAccess.make_dir_recursive_absolute("res://artifacts/test-results")
			FileAccess.open("res://artifacts/test-results/epilogue.json", FileAccess.WRITE).store_string(JSON.stringify(ending))
			FileAccess.open("res://artifacts/test-results/epilogue-source.json", FileAccess.WRITE).store_string(JSON.stringify(snapshot))
	check(outcomes[0] != outcomes[1] and outcomes[1] != outcomes[2] and outcomes[0] != outcomes[2], "three bot strategies earn three different futures")
	for axis in Epilogue.AXES:
		var strong := {"solvency": 1.0, "adaptation": 1.0, "diversification": 1.0, "land_health": 1.0}
		for value in [0.0, 0.5, 0.75]:
			strong[axis] = value
			check(Epilogue.classify(strong, {}) != "Thriving", "Thriving strictly requires " + axis)
	check(Epilogue.classify({"solvency": 0.76, "adaptation": 0.76, "diversification": 0.76, "land_health": 0.76}, {}) == "Thriving", "all four axes can earn Thriving")

	# Every outcome has an explicit reachable classification, and the inherited
	# loan is not charged forever merely because the run clock used to stop at ten.
	var axes := {"solvency": 0.4, "adaptation": 0.5, "diversification": 0.0, "land_health": 0.6}
	check(Epilogue.classify(axes, {}, 15) == "Sold to the estate", "early foreclosure leaves an estate")
	check(Epilogue.classify(axes, {}, 25) == "Deserted", "later foreclosure leaves an empty farm")
	check(Epilogue.classify(axes, {}) == "Holding on", "adapted crop farm holds on")
	axes.diversification = 0.5
	check(Epilogue.classify(axes, {}) == "The shop village", "business income sustains the village")
	axes.land_health = 0.1
	check(Epilogue.classify(axes, {"drought": 8, "flood": 2}) == "Dust", "dry exposed land becomes Dust")
	check(Epilogue.classify(axes, {"drought": 2, "flood": 8}) == "Drowned", "wet exposed land becomes Drowned")
	var journal = State.Ledger.new()
	journal.last_year = 50
	for year in range(1, 51): check(journal.post_fixed_costs(year), "future year posts its actual bills")
	check(journal.loan_remaining() == 0 and journal.total(50, "mortgage") == 0, "paid-off mortgage ends without negative debt")
	check(journal.total(20, "mortgage") == Balance.FIXED_COSTS[0].amount + Balance.FIXED_COSTS[1].amount, "last principal payment remains due in year twenty")
	var repair_source = State.new()
	repair_source.climate.data.projects = {"rainwater": 2}
	var repair = Epilogue.new()
	repair.begin(repair_source._save_data())
	repair.farm.season_clock.season = 3
	repair.conditions.rainwater = 0.25
	var cash: float = repair.farm.coins
	repair._repair()
	check(repair.conditions.rainwater == 1 and repair.farm.coins == cash - 1.5 * Balance.PROTECTION_UPKEEP, "affordable repair is charged to the journal")
	repair.farm.coins = 0
	repair.conditions.rainwater = 0.25
	repair._repair()
	check(repair.conditions.rainwater == 0.25 and repair.farm.climate.data.projects.rainwater == 0 and repair.farm.coins == 0, "unaffordable repairs leave equipment broken")
	repair.farm.free()
	repair_source.free()
	print("Epilogue: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
