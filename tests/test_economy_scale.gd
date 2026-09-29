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
	var prices := {"russet":15.0, "giant":18.0, "golden":21.0, "sunburst":27.0, "icecap":30.0}
	for crop: String in prices:
		check(State.CropTable.CROPS[crop].base == prices[crop], crop + " base price")
		check(State.CropTable.CROPS[crop].seed == prices[crop] * 0.75 and farm.market[crop].seed == prices[crop] * 0.75, crop + " fixed seed ratio")
		for island in [1]:
			var bed: Dictionary = farm.plots[0].duplicate(true)
			bed.merge({"crop":crop, "stage":3, "tilled":true, "watered":true}, true)
			var count: int = farm._harvest_plot(bed)
			check(count == State.CropTable.CROPS[crop]["yield"] and count >= 3 and count <= 5, crop + " healthy yield stays 1x on island " + str(island))
	for costs: Array in State.TOOL_COSTS.values():
		for cost: float in costs: check(cost >= 300 and cost <= 1500, "bounded tool prices")
	check(State.FIELD_EXPANSION_COST == 1200, "flat field expansion cost")
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
	check(farm.can_purchase(1), "purchases may use the bounded overdraft")
	farm.coins = -5000
	check(not farm.run_over, "exact overdraft boundary remains playable")
	farm.coins = -501
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.run_over and farm.climate.data.collapse.balance == -5001, "Winter fixed costs crossing the limit capture the final receipt")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "ended run persists")
	farm.reset_game()
	var data: Dictionary = farm._save_data()
	for key in ["blind_cycle", "combo_count", "combo_multiplier", "combo_time", "coins_scientific", "tax_credit_eligible", "harvest_fraction", "mastery"]: check(not data.has(key), key + " no longer saved")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "farm round trips")
	farm.reset_game()
	farm.elapsed = 200000
	farm.climate.begin_warning(farm, "flood", 1.0)
	farm.climate._impact(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "long weather timestamps are not limited by the money cap")
	farm.coins = -501
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "late-run final receipt preserves elapsed time")
	for suffix in ["", ".bak", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	farm.free()
	print("ECONOMY SCALE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
