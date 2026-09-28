extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE: String = "user://taterland_disaster_markets_test_only.json"
var farm
var builds
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func fresh() -> void:
	farm.reset_game()
	farm.debug_unlock_island(3)
	farm.travel_to(3)
	farm.climate.acknowledge(farm)
	farm.coins = 1e20
	farm.rng.seed = 45321
	farm.selected_crop = "icecap"
func crash(event: String, severity: float) -> void:
	farm.climate.begin_warning(farm, event, severity)
	farm.climate._impact(farm)
	farm._refresh_market(false)
func bounded(label: String) -> void:
	for crop: String in farm.CROP_IDS:
		var percent: float = farm.market[crop].change
		check(percent >= -95.000001 and percent <= 0.000001 and farm.market[crop].sell > 0, label + ": " + crop + " stays between -95% and 0%")
func run() -> void:
	farm = State.new()
	root.add_child(farm)
	builds = Builds.new()
	builds.state = farm
	farm.build_system = builds
	root.add_child(builds)
	for event: String in ["drought", "flood", "storm"]:
		for severity: float in [0.5, 0.75, 1.0]:
			fresh()
			crash(event, severity)
			check(is_equal_approx(farm.market.icecap.change, -95.0 * severity), event + " severity controls crash strength")
			farm.inventory_items.market_monocle = 1
			farm.equipment.charm = "market_monocle"
			farm.export_active = true
			farm.export_factor = 6
			farm.thaw_remaining = 5
			farm.current_event = "supply_collapse"
			farm.event_crop = "icecap"
			farm.event_strength = 16
			for crop: String in farm.CROP_IDS: farm._market_core[crop].sell = farm.CROPS[crop].base * 3
			farm.natural_crop = "golden"
			farm.natural_remaining = 10
			farm.natural_factor = 101
			farm.surge_kind = "rocket"
			farm.surge_remaining = 10
			farm.surge_factor = 1001
			farm.surge_crop = "icecap"
			farm._refresh_market(false)
			bounded(event + " stacked offers")
			check(farm.surge_remaining == 0 and farm.natural_remaining == 0 and farm.surge_kind == "normal", "incoming booms are cancelled")
			farm._start_surge()
			farm._prepare_rocket()
			check(not farm.rocket_pending and farm.blind_cycle.booms == 0, "disaster cannot launch or advance tax count")
			farm._start_event("festival")
			check(farm.current_event == "crash", "positive flash offers become crashes")
			farm.export_active = false
			farm._toggle_export()
			check(farm.news.contains("Disaster prices still apply") and not farm.news.contains("EXPORT FLASH"), "export arrival does not advertise a disaster boom")
			farm._end_frost(true)
			check(farm.news.contains("cannot override disaster prices"), "frost reward explains disaster pricing")
			farm.climate.data.phase = "recovery"
			farm.climate.data.timer = 37.5
			farm._refresh_market(false)
			bounded(event + " recovery")
			check(farm.surge_info().crash and not farm.surge_info().active, "recovery advertises crashes instead of booms")
	fresh()
	farm.climate.begin_warning(farm, "storm", 1.0)
	farm.climate.data.timer = 0.5
	farm.surge_timer = 0.5
	farm.rocket_timer = 0.5
	farm.update(0.5)
	check(farm.disaster_market_active() and not farm.rocket_pending and farm.blind_cycle.booms == 0, "weather wins a simultaneous disaster/stock/rocket boundary")
	bounded("boundary")
	var rocket_time: float = farm.rocket_timer
	farm.update(10)
	check(farm.rocket_timer == rocket_time and farm.elapsed > 10, "paused rocket does not stall simulation")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "crash state and near-zero rocket timer round trip")
	bounded("restored crash")
	farm.update(95)
	check(not farm.disaster_market_active(), "full active and recovery periods return to calm")
	farm.update(0.01)
	check(farm.rocket_pending, "deferred rocket resumes after recovery")
	farm.complete_rocket_launch()
	check(farm.market.icecap.change >= 35000 and farm.blind_cycle.booms == 1, "calm rocket still grants its normal opportunity")
	fresh()
	farm._start_surge()
	crash("flood", 1)
	check(farm.surge_remaining == 0 and farm.blind_cycle.booms == 1, "impact cancels an existing boom without inventing another tax event")
	farm.travel_to(1)
	farm._start_surge()
	check(farm.market[farm.surge_crop].change >= 500, "unaffected island keeps ordinary stocks")
	farm.travel_to(3)
	bounded("return to affected island")
	check(farm.surge_remaining == 0, "travel cannot carry a positive stock into disaster")
	fresh()
	farm.blind_cycle.tax_rolled = true
	for _i: int in range(3):
		farm._start_surge()
		if _i < 2: farm.update(10)
	crash("drought", 1)
	farm.update(10)
	check(farm.blind_cycle.clears == 1, "an already-due tax is still collected once")
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	farm.queue_free()
	builds.queue_free()
	await process_frame
	print("DISASTER MARKETS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
