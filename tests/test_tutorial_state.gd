extends SceneTree
## Tutorial simulation, save migration, and completion grace periods.
## Uses only disposable saves; the player's farm is never opened.
const State = preload("res://scripts/game_state.gd")
const Activities = preload("res://scripts/island_activities.gd")
var checks: int = 0
var failures: int = 0
var notices: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	state.rng.seed = 70523
	check(not state.tutorial_active and state.tutorial_progress.version == 3, "controller starts the guided year")
	state.set_tutorial_active(true)
	var before: Dictionary = state._save_data().duplicate(true)
	state.update(3600)
	check(state._save_data() == before, "welcome pauses all simulation")
	state.buy_seeds("russet", 1)
	for action: String in ["hoe", "plant", "water"]: state.interact_plot(5, action)
	state.tutorial_progress.step = 5
	state.update(3600)
	check(state.season_clock.season == 1 and is_equal_approx(state.season_clock.seconds, 30), "calendar advances through Spring to Summer warning impact")
	check(state.tutorial_loss().sacks == 1 and state.climate.year_count(1) == 1, "one small scripted disaster")
	check(state.plots[5].stage == 3 and state.ClimateSystem.Protection.remaining(state.plots[5]) == 2, "normal growth survives partial storm loss")
	check(state.ledger.total(1, "seeds") == -270, "seed cost is real")
	state.tutorial_progress.step = 6
	before = state._save_data().duplicate(true)
	state.update(3600)
	check(state._save_data() == before, "cause card pauses clocks")
	var path: String = "user://tutorial-state-%d.json" % OS.get_process_id()
	check(state.save_game(path), "guided Summer saves")
	var restored = State.new(); root.add_child(restored)
	check(restored.load_game(path), "guided Summer loads")
	check(restored.tutorial_progress == state.tutorial_progress and not restored.tutorial_active, "progress restored with controller-owned transient lock")
	restored.set_tutorial_active(true)
	before = restored._save_data().duplicate(true)
	restored.update(3600)
	check(restored._save_data() == before, "resumed cause card cannot double-charge damage")
	restored.interact_plot(5, "harvest")
	restored.tutorial_progress.step = 9
	restored.tutorial_progress.choice = "store"
	before = restored._save_data().duplicate(true)
	restored.update(3600)
	check(restored._save_data() == before, "remaining ripe starters pause the calendar before cold can kill locked beds")
	for index in range(4): restored.interact_plot(index, "harvest")
	restored.update(3600)
	check(restored.season_clock.season == 3 and restored.ledger.is_closed(1), "state alone reaches settled first accounts")
	check(restored.stock_count("russet") == 13 and restored.ledger.total(1, "storage") < 0, "storage keeps crop and charges fee")
	check(restored.season_clock.autumn_loss == 0, "no unmanageable guided crops die to Autumn Cold")
	check(restored.climate.year_count(1) == 1, "no second guided disaster")
	check(restored._valid_save(restored._save_data()), "Winter guide state valid before controller completes")
	check(restored.ledger.guided_credit(1) == restored.ledger.fixed_cost_total(), "guided Winter offsets only the fixed bills, preserving seed and storage charges")
	check(is_equal_approx(restored.coins, State.Ledger.STARTING_CASH + restored.ledger.total(1, "seeds") + restored.ledger.total(1, "storage")), "stored crop is not income and its ordinary costs remain")
	var winter_journal: Dictionary = restored.ledger.save_data()
	check(not restored.ledger.post_fixed_costs(1, true) and restored.ledger.save_data() == winter_journal, "repeated settlement cannot duplicate the guided credit")
	check(restored.save_game(path) and restored.load_game(path) and restored.ledger.save_data() == winter_journal, "guided bills and credit round-trip without re-posting")
	for fault: String in ["amount", "year", "season", "category", "duplicate"]:
		var forged: Dictionary = restored._save_data()
		var credit: Dictionary = forged.ledger.entries.back()
		match fault:
			"amount": credit.amount += 1
			"year": credit.year = 2
			"season": credit.season = 2
			"category": credit.category = "sales"
			"duplicate": forged.ledger.entries.append(credit.duplicate())
		check(not restored._valid_save(forged), "validator rejects invalid guided credit: " + fault)
	for invalid in [{}, {"version": 3, "step": -1, "completed": false, "plot": 5}, {"version": 3, "step": 2, "completed": "false", "plot": 5}, {"version": 3, "step": 2, "completed": false, "plot": 99}]:
		var data: Dictionary = state._save_data(); data.tutorial_progress = invalid
		check(not state._valid_save(data), "reject malformed progress")
	# Entry/exit never cleanses a genuine farm or rolls its RNG.
	state.set_tutorial_active(false)
	state.plots[0].pests = true
	state.plots[0].pest_elapsed = 2.0
	before = state._save_data().duplicate(true)
	state.set_tutorial_active(true)
	state.set_tutorial_active(false)
	check(state._save_data() == before, "skip preserves hazards, crop age, money and RNG")
	state.tutorial_progress.tour_only = true
	state.set_tutorial_active(true)
	before = state._save_data().duplicate(true)
	state.update(3600)
	state.set_tutorial_active(false)
	check(state._save_data() == before, "optional tour preserves all farm state")
	# The starter-seed sale route contains no optional purchases or stored crop.
	var guided = State.new(); root.add_child(guided)
	guided.rng.seed = 70523
	guided.set_tutorial_active(true)
	for action: String in ["hoe", "plant", "water"]: guided.interact_plot(5, action)
	guided.tutorial_progress.step = 5
	guided.update(3600)
	guided.tutorial_progress.step = 7
	for index in [0, 1, 2, 3, 5]: guided.interact_plot(index, "harvest")
	guided.tutorial_progress.step = 8
	guided.sell_crop("russet")
	guided.tutorial_progress.choice = "sell"
	guided.tutorial_progress.step = 9
	guided.update(3600)
	check(guided.season_clock.season == 3 and guided.ledger.is_closed(1), "starter-seed sale route reaches Winter accounts")
	check(guided.lifetime_sales > 0 and is_equal_approx(guided.coins, State.Ledger.STARTING_CASH + guided.lifetime_sales), "guided year ends at starting cash plus its own sales")
	for cost in State.Ledger.FIXED_COSTS:
		check(guided.ledger.entries.any(func(entry): return entry.category == cost.category and entry.label == cost.label and entry.amount == cost.amount), "guide still posts the real bill: " + cost.label)
	check(guided._valid_save(guided._save_data()), "sale-route accounts with credit are valid")
	check(guided.NpcRoster.ledger_lines(guided).begins_with("Dad's last harvest paid this year. From now on it's yours."), "Nell explains the one-year credit")
	guided.tutorial_progress.completed = true
	guided.set_tutorial_active(false)
	guided.season_clock.year = 2
	guided.season_clock.season = 3
	guided._season_boundary()
	check(guided.ledger.guided_credit(2) == 0 and guided.ledger.total(0, "other") == guided.ledger.fixed_cost_total(), "year two gets no further inheritance credit")
	check(not guided.NpcRoster.ledger_lines(guided).contains("Dad's last harvest"), "Nell's credit line ends after year one")
	var skipped = State.new(); root.add_child(skipped)
	skipped.set_tutorial_active(true)
	skipped.tutorial_progress.completed = true
	skipped.set_tutorial_active(false)
	skipped.season_clock.season = 3
	skipped._season_boundary()
	check(skipped.ledger.guided_credit(1) == 0 and skipped.ledger.total(1, "other") == 0, "skipped guide gets no credit")
	check(skipped.coins == State.Ledger.STARTING_CASH - skipped.ledger.fixed_cost_total(), "skipped year pays the full fixed bills")
	check(skipped._valid_save(skipped._save_data()), "skipped first accounts remain valid")
	var tour = State.new(); root.add_child(tour)
	tour.tutorial_progress.tour_only = true
	tour.set_tutorial_active(true)
	tour.season_clock.season = 3
	tour._season_boundary()
	check(tour.ledger.guided_credit(1) == 0, "optional tour cannot earn the guided-year credit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free(); restored.free(); guided.free(); skipped.free(); tour.free()
	print("Tutorial state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
