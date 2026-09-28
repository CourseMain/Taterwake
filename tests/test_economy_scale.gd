extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://economy_scale_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	check(farm.coins == 2000 and farm.bankruptcy_limit() == -5000, "starting funds and overdraft boundary")
	var prices := {"russet":15.0, "giant":18.0, "golden":21.0, "radioactive":24.0, "sunburst":27.0, "icecap":30.0}
	for crop: String in prices:
		check(State.CROPS[crop].base == prices[crop], crop + " base price")
		check(State.CROPS[crop].seed == prices[crop] * 0.75 and farm.market[crop].seed == prices[crop] * 0.75, crop + " fixed seed ratio")
		for island in [1, 2, 3]:
			farm.current_island = island
			var bed: Dictionary = farm._empty_shores(true)[0]
			bed.merge({"crop":crop, "stage":3, "tilled":true, "watered":true}, true)
			var count: int = farm._harvest_plot(bed)
			check(count == State.CROPS[crop]["yield"] and count >= 3 and count <= 5, crop + " healthy yield stays 1x on island " + str(island))
	for costs: Array in State.TOOL_COSTS.values():
		for cost: float in costs: check(cost >= 300 and cost <= 1500, "bounded tool prices")
	for cost: float in State.FIELD_EXPANSION_COSTS.values(): check(cost == 1200, "flat field expansion cost")
	farm.reset_game()
	farm.coins = 10000
	for cost: float in [300.0, 800.0, 2000.0]:
		var before: float = farm.coins
		farm.upgrade_barn()
		check(farm.coins == before - cost, "barn charges its next fixed price")
	var balance: float = farm.coins
	farm.upgrade_barn()
	check(farm.coins == balance and farm.barn_level == 3, "only three barn upgrades")
	check(farm.money(12345.4) == "\uE000 12,345" and farm.money(-5000) == "-\uE000 5,000", "money uses grouped integers and the Spudion glyph")
	farm.coins = -1
	check(not farm.can_purchase(1), "purchases never borrow")
	farm.coins = -5000
	check(not farm.run_over, "exact overdraft boundary remains playable")
	farm.coins = -5001
	check(farm.run_over and farm.climate.data.collapse.balance == -5001, "crossing limit captures the final receipt immediately")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "ended run persists")
	farm.reset_game()
	var old: Dictionary = farm._save_data().duplicate(true)
	old.mechanics_revision = 25
	old.coins = 1e12
	old.barn_level = 12
	old.capacity = 1e12
	old.mastery = {"russet":500, "giant":42}
	for key in ["blind_cycle", "combo_count", "combo_multiplier", "combo_time", "coins_scientific", "tax_credit_eligible", "harvest_fraction"]: old[key] = "retired"
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	check(farm.load_game(SAVE) and farm.coins == 100000 and farm.barn_level == 3 and farm.harvested_total == 542, "legacy wealth is bounded and ordinary harvest progress survives")
	var data: Dictionary = farm._save_data()
	for key in ["blind_cycle", "combo_count", "combo_multiplier", "combo_time", "coins_scientific", "tax_credit_eligible", "harvest_fraction", "mastery"]: check(not data.has(key), key + " no longer saved")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "migrated farm round trips")
	farm.reset_game()
	farm.debug_unlock_island(2)
	farm.travel_to(2)
	farm.climate.acknowledge(farm)
	farm.elapsed = 200000
	farm.climate.begin_warning(farm, "flood", 1.0)
	farm.climate._impact(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "long weather timestamps are not limited by the money cap")
	farm.coins = -5001
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "late-run final receipt preserves elapsed time")
	for suffix in ["", ".bak", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	farm.free()
	print("ECONOMY SCALE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
