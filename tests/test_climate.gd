extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const Climate = preload("res://scripts/climate_system.gd")
const SAVE: String = "user://taterland_climate_test_only.json"
var state
var builds
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func fresh(island: int = 2) -> void:
	state.reset_game()
	state.coins = 1e18
	state.rng.seed = 77821
	state.barn_level = 3
	state._recompute_capacity()
	state.expansion = 1
	for plot in state.island_plots["1"]: plot.unlocked = true
	if island > 1:
		state.island2_unlocked = true
		state.island3_unlocked = island == 3
		for id in range(2, island + 1):
			for plot in state.island_plots[str(id)]: plot.unlocked = true
		state.travel_to(island)
		state.climate.acknowledge(state)
	for plot in state.plots:
		state._clear_crop(plot)
		plot.unlocked = true
		plot.tilled = true
		plot.stage = 1
		plot.elapsed = 0.0
		plot.crop = "russet"
		plot.watered = false
	state.storage.russet = 1000
	state._market_core.russet.sell = state.CROPS.russet.base
	state.current_event = ""
	state._refresh_market(false)

func collect() -> void:
	state.blind_cycle.tax_rolled = true
	for _index in range(3):
		state._start_surge()
		state.update(10.0)

func save_load() -> void:
	var before: Dictionary = state.climate.data.duplicate(true)
	var money: float = state.coins
	check(state.save_game(SAVE) and state.load_game(SAVE), "climate checkpoint round trip")
	check(same_data(state.climate.data, before) and state.coins == money, "warnings, projects, losses and recovery pressure persist")

func same_data(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_data(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not same_data(a[index], b[index]): return false
		return true
	return a == b

func run() -> void:
	state = State.new()
	root.add_child(state)
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(builds)
	fresh(1)
	state.update(1200.0)
	check(not state.climate.data.introduced and state.climate.data.history.is_empty() and state.climate.data.timer == Climate.FIRST_WARNING, "Valley play never advances weather or damages crops through climate")
	state.island2_unlocked = true
	for plot in state.island_plots["2"]: plot.unlocked = true
	state.travel_to(2)
	check(state.climate.data.intro_pending and state.climate.data.introduced, "arrival starts the once-per-run introduction")
	var paused_time: float = state.elapsed
	save_load()
	state.update(600.0)
	check(state.elapsed == paused_time and state.climate.data.intro_pending, "saved pending introduction cannot spend preparation time")
	state.climate.acknowledge(state)
	state.update(Climate.FIRST_WARNING)
	check(state.climate.data.phase == "warning", "first warning follows a complete preparation period on Island 2")
	state.travel_to(1)
	state.travel_to(2)
	check(not state.climate.data.intro_pending, "return travel never repeats introduction")
	fresh(1)
	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.mechanics_revision = 11
	legacy.climate.erase("introduced")
	legacy.climate.erase("intro_pending")
	legacy.climate.island = 1
	legacy.climate.phase = "active"
	legacy.climate.event = "flood"
	legacy.climate.timer = 20.0
	legacy.climate.severity = 1.0
	var old_file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	old_file.store_string(JSON.stringify(legacy))
	old_file.close()
	check(state.load_game(SAVE) and state.climate.data.phase == "calm" and not state.climate.data.introduced, "revision-11 Valley flood migrates to safe weather without losing the farm")
	for island in [1, 2, 3]:
		fresh(island)
		var baseline: float = [1e6, 1e11, 5e15][island - 1]
		check(state.blind_info().tax == baseline * 0.05 and state.bankruptcy_limit() == -baseline * 0.05, "tax and bankruptcy use progression baseline island %d" % island)
		check(state.stock_opportunity().reference == baseline * 0.08, "major opportunity reference equals eight percent of progression")
		state.blind_cycle.tax_multiplier = 2.5
		check(state.blind_info().tax == baseline * 0.125, "severe tax ceiling is twelve-point-five percent")
		state.climate.data.tax_events = [{"event": "storm", "island": island, "pressure": 1.5}]
		check(state.blind_info().tax == baseline * 0.125, "weather plus random Tax Boom cannot exceed shared ceiling")
	check(state.available_crops().has("icecap") and state.island_plots.size() == 3 and state.stock_opportunity().virtual, "winter virtual baseline adds no fourth island")

	for event in ["drought", "flood", "storm"]:
		fresh()
		var before_field: int = state.plots.size()
		var before_coins: float = state.coins
		check(state.climate.begin_warning(state, event, 1.0), "start warned " + event)
		check(state.climate.data.phase == "warning" and state.storage.russet == 1000 and state.climate.data.field_lost == 0 and state.coins == before_coins, "warning gives time to prepare without damage or tax collection")
		check(state.climate_info().warning_tax > state.blind_info().tax, "warning previews the higher recovery bill before physical damage")
		state.update(44.999)
		check(state.climate.data.phase == "warning" and state.climate.data.field_lost == 0, "disaster never arrives before its complete warning")
		save_load()
		state.update(0.001)
		check(state.climate.data.phase == "active" and state.climate.data.field_lost > 0 and state.climate.data.field_lost < before_field, "disaster hits once and loses real planted crops")
		check(state.storage.russet < 1000 and state.climate.data.barn_lost == 1000 - state.storage.russet, "barn losses match removed potatoes")
		check(state.blind_info().tax > 5e9 and state.blind_info().tax <= 12.5e9, "physical disaster leaves capped tax pressure")
		state._market_core.russet.sell = state.CROPS.russet.base
		state.current_event = ""
		state.event_strength = 1.0
		state.event_remaining = 0.0
		state._refresh_market(false)
		check(state.market.russet.sell < state.CROPS.russet.base and state.market.russet.seed > state.CROPS.russet.base * 3.0 * State.SEED_YIELD_RATIO, "ordinary sell prices weaken while seeds become more expensive")
		var unprotected_loss: int = state.climate.data.field_lost
		var unprotected_barn: int = state.climate.data.barn_lost
		var unprotected_tax: float = state.blind_info().tax
		save_load()
		state.update(30.0)
		check(state.climate.data.phase == "recovery", "weather transitions to economic recovery")
		save_load()
		state.update(75.0)
		check(state.climate.data.phase == "calm" and state.climate.factor("sell", 2) == 1.0 and state.climate.factor("seed", 2) == 1.0, "weather market effects fully end after recovery")
		check(state.climate.data.field_lost == unprotected_loss and state.climate.data.barn_lost == unprotected_barn and is_equal_approx(state.blind_info().tax, unprotected_tax), "losses do not repeat and recovery bill survives calm weather")
		collect()
		check(state.climate.tax_pressure() == 0.0 and state.blind_info().tax == 5e9, "one tax collection clears the recovery bill")
		fresh()
		for project in ["rainwater" if event == "drought" else ("drainage" if event == "flood" else "windbreaks"), "barn"]:
			state.climate.fund(state, project)
			state.climate.fund(state, project)
		state.climate.begin_warning(state, event, 1.0)
		state.update(45.0)
		check(state.climate.data.field_lost < unprotected_loss and state.climate.data.barn_lost < unprotected_barn, "climate initiatives reduce both crop and barn damage for " + event)
		check(state.blind_info().tax < unprotected_tax, "initiatives reduce the resulting recovery tax")
		save_load()

	fresh()
	state.climate.begin_warning(state, "flood", 1.0)
	state.update(45.0)
	var pending: float = state.blind_info().tax
	state.climate.fund(state, "drainage")
	check(state.blind_info().tax < pending, "funding recovery work reduces an already pending bill without undoing recorded crop losses")
	state.climate.fund(state, "drainage")
	var paid: float = state.coins
	state.climate.fund(state, "drainage")
	check(state.coins == paid and state.climate.data.projects["2"].drainage == 2, "initiatives cannot exceed two levels or charge at cap")
	state.coins = 0.0
	state.climate.fund(state, "barn")
	check(state.coins == 0.0 and not state.climate.data.projects["2"].has("barn"), "unaffordable protection never charges or grants a level")

	fresh(3)
	state.climate.begin_warning(state, "storm", 1.0)
	state.update(45.0)
	state.selected_crop = "icecap"
	state.blind_cycle.tax_rolled = true
	state._start_surge()
	var boom_price: float = state.CROPS.icecap.base * state.surge_factor
	check(state.market.icecap.sell == boom_price, "disaster sale pressure preserves the full major stock opportunity")
	state.update(10.0)
	state._start_surge()
	state.update(10.0)
	state._start_surge()
	state.update(3.0)
	var bill: float = state.blind_info().tax
	save_load()
	check(state.blind_cycle.booms == 3 and is_equal_approx(state.blind_cycle.due_in, 7.0) and state.blind_info().tax == bill, "climate and pending tax deadline reload together")
	state.update(7.0)
	check(state.blind_cycle.clears == 1 and state.climate.tax_pressure() == 0.0, "reloaded third stock collects recovery costs exactly once")
	var clean: Dictionary = state._save_data().duplicate(true)
	for defect in ["timer", "severity", "project", "history", "event"]:
		var broken: Dictionary = clean.duplicate(true)
		match defect:
			"timer": broken.climate.timer = 9000.0
			"severity": broken.climate.severity = 2.0
			"project": broken.climate.projects["3"].barn = 3
			"history": broken.climate.history[0].field_lost = 99999999
			"event": broken.climate.event = "unknown"
		check(not state._valid_save(broken), "reject corrupt climate " + defect)
		var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(broken))
		file.close()
		check(not state.load_game(SAVE) and state._save_data() == clean, "invalid climate save leaves current farm unchanged")

	fresh()
	builds.active = "industrialist"
	builds.levels.industrialist = 1
	builds.processed = {"russet": {"count": 100, "multiplier": 2.0}}
	builds.processing = {"crop": "russet", "quantity": 100, "remaining": 20.0, "duration": 20.0}
	state.climate.begin_warning(state, "flood", 1.0)
	state.update(45.0)
	check(builds.processed.russet.count == 70 and builds.processing.quantity == 70, "processing queues cannot hide potatoes from barn losses")
	# Exact processing fixture format is covered separately by the builds suite.
	builds.processing.clear()
	builds.processed.clear()

	fresh()
	state.climate.begin_warning(state, "storm", 1.0)
	state.update(45.0)
	state.coins = 10000.0
	state.blind_cycle.tax_rolled = true
	collect()
	check(state.run_over and state.blind_cycle.reason == "bankrupt", "climate recovery tax can bankrupt the run")
	var report: Dictionary = state.climate.data.collapse
	check(report.cause.contains("Recovery taxes") and report.tax == 12.5e9 and report.field_lost > 0 and report.barn_lost > 0, "collapse records actual cause, lost crops/storage and tax bill")
	check(report.build == "Farmer" and report.phase == "recovery" and report.event == "storm", "collapse snapshots build and current climate phase")
	save_load()
	var dead: String = JSON.stringify(state._save_data())
	state.update(3600.0)
	check(JSON.stringify(state._save_data()) == dead, "bankruptcy freezes weather as well as economy")

	fresh()
	state.tutorial_active = true
	state.update(3600.0)
	check(state.climate.data.phase == "calm" and state.climate.data.timer == Climate.FIRST_WARNING and not state.climate.begin_warning(state, "flood"), "tutorial is protected from climate warnings and damage")
	fresh(3)
	state.climate.begin_warning(state, "storm", 1.0)
	state._prepare_rocket()
	var timer: float = state.climate.data.timer
	state.update(60.0)
	check(state.climate.data.timer == timer, "Rocket cinematic does not spend weather preparation time")
	state.complete_rocket_launch()
	state.update(10.0)
	check(state.climate.data.timer == timer - 10.0, "weather resumes after the cinematic")
	state.reset_game()
	check(state.climate.data == Climate.fresh_data() and not state.run_over, "new run clears climate history, projects and pressures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.queue_free()
	builds.queue_free()
	print("CLIMATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
