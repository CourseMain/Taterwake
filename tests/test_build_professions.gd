extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	var builds = Builds.new()
	builds.state = farm
	farm.build_system = builds
	root.add_child(builds)
	farm.reset_game()
	for id in builds.IDS: builds.levels[id] = 20
	var p = builds.professions
	farm.storage.russet = 100
	builds.select_build("industrialist")
	p.action("method", "cure")
	var used: int = farm.storage_used()
	p.load_batch()
	var grade: String = builds.processing.grade
	check(builds.processing.quantity == 20 and farm.storage.russet == 80, "load exact selected quantity")
	check(farm.storage_used() == used, "processing conserves occupied storage")
	p.load_batch()
	p.load_batch()
	p.load_batch()
	check(p.data.queue.size() == 2 and farm.storage.russet == 40, "bounded production queue cannot double spend")
	var queued_save: Dictionary = JSON.parse_string(JSON.stringify(builds.save_data()))
	check(builds.load_data(queued_save) and p.data.queue.size() == 2 and builds.processing.quantity == 20, "JSON reload preserves loaded and queued batches")
	builds.select_build("farmer")
	check(builds.active == "farmer", "switching allowed with loaded jobs")
	builds.update(100)
	check(builds.processing.is_empty() and p.data.queue.is_empty() and builds.processed.russet.count == 60, "all queued jobs advance across coarse simulation step")
	check(p.data.last_grade == grade, "jobs preserve quoted grade across switching")
	var value: float = builds.processed_value()
	var before: float = farm.coins
	builds.sell_processed()
	builds.sell_processed()
	check(is_equal_approx(farm.coins-before,value), "graded shipment pays exactly once")
	farm.plots[0].stage = 2
	farm.plots[0].watered = true
	farm.plots[0].crop = "russet"
	p.cultivate(0)
	var compost: int = p.data.compost
	p.cultivate(0)
	check(farm.plots[0].cultivated and p.data.compost == compost, "giant-potato patch spends compost once")
	farm.plots[0].stage = 3
	var harvested: int = farm._harvest_plot(farm.plots[0])
	check(harvested >= 9 and not farm.plots[0].has("cultivated"), "giant yields more and clears after harvest")
	builds.select_build("scientist")
	farm.storage.russet = 40
	farm.storage.golden = 40
	p.breed()
	p.breed()
	check(p.data.seedbank == ["hearty"] and farm.storage.russet == 30 and farm.storage.golden == 30, "discovery consumes both parents once")
	builds.select_build("farmer")
	farm._clear_crop(farm.plots[1])
	farm.plots[1].tilled = true
	farm.seed_inventory.russet = 20
	farm.interact_plot(1,"plant")
	check(farm.plots[1].get("variety","") == "hearty", "seed bank works after changing build")
	builds.select_build("investor")
	p.reserve()
	var locked: float = p.data.contract.quote
	farm.market.russet.sell *= 5
	farm.storage.russet = 100
	before = farm.coins
	builds.select_build("farmer")
	p.deliver()
	p.deliver()
	check(is_equal_approx(farm.coins-before,100*locked) and p.data.deliveries == 1, "locked contract delivers once with any build")
	builds.select_build("investor")
	p.reserve()
	p.update(181)
	check(p.data.contract.is_empty(), "expired contract releases reservation")
	builds.select_build("gambler")
	builds.cooldown = 0
	farm.storage.russet = 100
	p.stake_harvest()
	check(farm.storage.russet == 80 and p.data.wager.quantity == 20, "only selected harvest enters wager")
	var wager: Dictionary = p.data.wager.duplicate()
	check(builds.load_data(JSON.parse_string(JSON.stringify(builds.save_data()))) and p.data.wager.crop == wager.crop and p.data.wager.quantity == wager.quantity and is_equal_approx(p.data.wager.quote, wager.quote) and p.data.wager.factor == wager.factor, "unclaimed wager survives JSON reload without rerolling")
	wager = p.data.wager.duplicate()
	p.stake_harvest()
	check(p.data.wager == wager and farm.storage.russet == 80, "pending wager cannot be overwritten")
	p.reroll()
	var factor: float = p.data.wager.factor
	p.reroll()
	check(not p.data.charm and p.data.wager.factor == factor, "charm used once")
	before = farm.coins
	var payout: float = p.data.wager.quote * 20 * factor
	p.claim(); p.claim()
	check(is_equal_approx(farm.coins-before,payout), "wager pays once at locked quote")
	var save: Dictionary = builds.save_data()
	check(builds.valid_data(save), "new profession state validates")
	check(builds.load_data(JSON.parse_string(JSON.stringify(save))) and p.data.seedbank == ["hearty"], "JSON round trip preserves discoveries")
	var checkpoint: Dictionary = builds.save_data()
	var bad: Dictionary = save.duplicate(true)
	bad.professions.contract = {"crop":"russet","quantity":20,"quote":-1,"remaining":40,"island":1}
	check(not builds.load_data(bad) and builds.save_data() == checkpoint, "malformed contract rejected before changing state")
	var legacy: Dictionary = save.duplicate(true)
	legacy.version = 1
	legacy.erase("professions")
	check(builds.load_data(legacy) and builds.levels.scientist == 20 and p.data.seedbank.is_empty(), "legacy levels and economy migrate without losing ownership")
	# Full farm saves preserve plot traits, not just the build subdocument.
	farm.reset_game()
	builds.levels.scientist = 1
	builds.select_build("scientist")
	farm.storage.russet = 80; farm.storage.golden = 20
	p.breed()
	builds.select_build("farmer")
	farm._clear_crop(farm.plots[0]); farm.plots[0].tilled = true
	farm.seed_inventory.russet = 20
	farm.interact_plot(0,"plant")
	p.cultivate(0)
	const SAVE = "user://professions_isolated_test.json"
	check(farm.save_game(SAVE), "complete farm with inherited traits saves")
	farm.reset_game()
	check(farm.load_game(SAVE) and farm.plots[0].get("variety","") == "hearty" and farm.plots[0].get("cultivated",false), "complete farm restores giant-potato patch and seed trait")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	# The preview covers every named rank across real input choices and ranks.
	var attainable: Array = []
	for rank in [1,3,10,20]:
		builds.levels.industrialist = rank
		for method in ["polish","cure"]:
			p.data.method = method
			for fresh in [false,true]:
				p.data.fresh_lots.clear()
				farm.storage.russet = 100
				if fresh: p.mark_fresh("russet", 100)
				for bank in [[], ["hearty","dry"]]:
					p.data.seedbank = bank
					var g: String = p.grade_preview().grade
					if g not in attainable: attainable.append(g)
	check(attainable.size() == 9, "all F through SSS grades are attainable")
	farm.debug_unlock_island(3)
	farm.travel_to(3); farm.climate.acknowledge(farm)
	for plot in farm.plots:
		plot.stage = 2; plot.variety = "frost"
	farm._start_frost()
	check(not farm.frost_active, "fully frost-hardy farm safely completes frost without an impossible target")
	farm.travel_to(2); farm.climate.acknowledge(farm)
	farm.climate.data.phase = "active"; farm.climate.data.event = "drought"; farm.climate.data.island = 2; farm.climate.data.severity = 1
	farm.plots[0].stage = 2; farm.plots[0].variety = "dry"
	farm.climate.data.operations.stress.clear()
	farm.ClimateSystem.Operations._tick(farm,.25)
	var protected: float = farm.climate.data.operations.stress["0"]
	farm.plots[0].erase("variety")
	farm.climate.data.operations.stress.clear()
	farm.ClimateSystem.Operations._tick(farm,.25)
	check(is_equal_approx(protected*2,farm.climate.data.operations.stress["0"]), "Sundew halves actual drought stress")
	builds.queue_free(); farm.queue_free()
	await process_frame
	print("BUILD PROFESSIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
