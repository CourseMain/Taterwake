extends SceneTree
## Optional help changes real mechanics: protect first pests, preserve quote timing,
## count independent farming, and never manufacture a major stock/tax event.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const Activities = preload("res://scripts/island_activities.gd")
var checks: int = 0
var failures: int = 0
var state
var builds
var activities

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func reset() -> void:
	state.reset_game()
	state.rng.seed = 62547
	state.tutorial_progress.completed = true
	state.farm_help.enable()
	state.farm_help.dismiss("repeat")
	state.pest_timer = 100.0
	state._event_in = 11.0
	for field: Array in state.island_plots.values():
		for plot: Dictionary in field: state._clear_crop(plot)
	state.changed.emit()

func prepare_practice() -> void:
	state.farm_help.data.independent = 4
	state.selected_crop = "russet"
	state.storage.russet = 20
	state.natural_remaining = 0.0
	state.natural_factor = 1.0
	state.surge_remaining = 0.0
	state.surge_factor = 1.0
	state.surge_timer = 180.0
	state.current_event = ""
	state.event_remaining = 0.0
	state.event_strength = 1.0
	state._market_core.russet.sell = State.CROPS.russet.base
	state._refresh_market(false)

func run() -> void:
	state = State.new()
	root.add_child(state)
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(builds)
	activities = Activities.new()
	activities.setup(state)
	state.activity_system = activities
	root.add_child(activities)
	reset()
	state.sell_crop("russet")
	state.interact_plot(5, "harvest")
	check(state.farm_help.data.independent == 0, "unsuccessful sale/harvest never counts as learning")
	state.interact_plot(5, "hoe")
	state.interact_plot(5, "plant")
	state.interact_plot(5, "water")
	state.update(10.1)
	state.interact_plot(5, "harvest")
	check(state.farm_help.data.independent == 3, "real independent crop waits for a sale")
	state.storage.golden = 1
	state.sell_crop("golden")
	check(state.farm_help.data.independent == 3, "unrelated crop sale cannot complete the independent crop")
	state.sell_crop("russet")
	check(state.farm_help.data.independent == 4, "successful same-crop sale completes independent cycle")
	reset()
	state.interact_plot(5, "hoe")
	state.interact_plot(5, "plant")
	state.interact_plot(5, "water")
	state.update(35.1)
	check(state.farm_help.data.pest_phase == 1 and state.plots[5].pests, "first naturally ripe infestation arms protection")
	state.farm_help.dismiss("pests")
	state.update(70.0)
	check(state.plots[5].stage == 3 and state.plots[5].pest_ticks == 0, "dismissing tip never releases current pests to destroy crops")
	check(state._infest_random_plots() == 0, "first encounter does not accumulate more infestations")
	var path: String = "user://farm-help-%d.json" % OS.get_process_id()
	check(state.save_game(path), "protected pests save")
	var restored = State.new()
	root.add_child(restored)
	check(restored.load_game(path), "protected pests reload")
	restored.update(10.0)
	check(restored.plots[5].pest_ticks == 0 and restored.farm_help.data.dismissed.has("pests"), "protection and dismiss choice both survive reload")
	state.interact_plot(5, "pest")
	check(state.farm_help.data.pest_phase == 2, "spray completes first encounter")
	state._infest_random_plots()
	state.update(5.1)
	check(state.plots[5].pest_ticks == 1, "later pests deal normal damage")
	reset()
	prepare_practice()
	check(state.farm_help.tip(state).id == "stocks", "held harvest offers practical stock lesson")
	var before: float = state.coins
	check(state.farm_help.start_practice(state), "opt-in practice starts")
	check(state.market.russet.change == 100.0 and state.market.russet.seed == state.market.russet.sell * State.CROPS.russet.yield * State.SEED_YIELD_RATIO, "practice has fixed +100% quote and matching seed cost")
	check(state.blind_cycle.booms == 0 and state.surge_timer == 180.0, "practice neither counts a major boom nor resets its schedule")
	state.update(4.25)
	check(is_equal_approx(state.farm_help.data.practice_remaining, 5.75) and state.market.russet.change == 100.0, "price holds while ordinary market ticks continue")
	check(state.save_game(path) and restored.load_game(path), "active practice saves and reloads")
	check(is_equal_approx(restored.farm_help.data.practice_remaining, 5.75) and restored.market.russet.change == 100.0, "reload retains remaining time, not a fresh ten seconds")
	state.update(5.75)
	check(state.farm_help.data.practice_remaining == 0.0 and state.blind_cycle.booms == 0 and is_equal_approx(state.surge_timer, 170.0), "expiry is exact and major timer advances normally")
	check(state.farm_help.unseen("stocks") and state.coins == before, "missing window grants no money and permits another attempt")
	prepare_practice()
	state.farm_help.start_practice(state)
	var quote: float = state.market.russet.sell
	state.sell_crop("russet", 1)
	check(is_equal_approx(state.coins - before, quote) and state.farm_help.data.dismissed.has("stocks"), "actual sale uses practice quote and records success")
	check(not state.farm_help.start_practice(state), "completed practice cannot be replayed for bonus money")
	check(state.save_game(path) and restored.load_game(path) and not restored.farm_help.start_practice(restored), "completed practice remains completed after reload")
	reset()
	prepare_practice()
	state._start_surge()
	var real_quote: float = state.market.russet.sell
	check(not state.farm_help.start_practice(state) and state.market.russet.sell == real_quote, "practice cannot replace an actual boom")
	prepare_practice()
	state.farm_help.start_practice(state)
	state.update(0.5)
	state.tutorial_progress.tour_only = true
	state.set_tutorial_active(true)
	var saved_help: Dictionary = state.farm_help.data.duplicate(true)
	state.update(50.0)
	state.set_tutorial_active(false)
	check(state.farm_help.data == saved_help and state.market.russet.change == 100.0, "optional tour pauses and preserves practice")
	reset()
	state.surge_timer = 30.0
	check(state.farm_help.tip(state).id == "taxes", "tax help appears before first major stock even without independent success")
	state.farm_help.dismiss("taxes")
	state.coins = -1.0
	check(state.farm_help.tip(state).id == "debt", "first debt explains recovery and actual bankruptcy boundary")
	state.farm_help.data.hidden = true
	check(state.farm_help.tip(state).is_empty(), "hide tips respects player choice even for debt")
	reset()
	state.farm_help.data.independent = 4
	state.coins = 0.0
	check(state.farm_help.tip(state).is_empty(), "unaffordable features produce no tour prompt")
	state.coins = float(State.TOOL_COSTS.hoe[0])
	check(state.farm_help.tip(state).id == "tools", "tool help waits for a purchasable upgrade")
	state.farm_help.dismiss("tools")
	state.coins = activities.duck_hire_cost()
	check(state.farm_help.tip(state).id == "ducks", "duck help waits for an affordable helper")
	state.farm_help.dismiss("ducks")
	builds.build_crates = 1
	check(state.farm_help.tip(state).id == "builds", "owned crate creates relevant build help")
	var saved: Dictionary = state._save_data()
	for invalid: Variant in [null, {}, {"enabled": true}, "bad"]:
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.farm_help = invalid
		check(not state._valid_save(corrupt), "malformed help data is rejected")
	for pair: Array in [["practice_remaining", -1], ["independent", 4.5], ["protected", ["3:80"]], ["dismissed", ["unknown"]], ["crop", "bad"]]:
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.farm_help[pair[0]] = pair[1]
		check(not state._valid_save(corrupt), "out-of-range help field rejected: " + str(pair[0]))
	saved.erase("farm_help")
	saved.mechanics_revision = 12
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	check(restored.load_game(path) and not restored.farm_help.data.enabled, "established revision-12 farms get no surprise onboarding")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	restored.free()
	activities.free()
	builds.free()
	state.free()
	print("FARM HELP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
