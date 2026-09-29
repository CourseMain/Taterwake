extends SceneTree
const State = preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var farm = State.new()
	farm.rng.seed = 9182
	for crop in farm.CROP_IDS:
		var bins: Array[int] = [0, 0, 0, 0, 0]
		var grow: float = farm.CropTable.CROPS[crop].grow
		for i in range(2000):
			var plot := {"crop": crop, "pest_delay": 0.0}
			farm._schedule_pest(plot)
			check(plot.pest_delay >= grow * 0.25 and plot.pest_delay <= grow * 0.6, "deadline inside the crop's growth window")
			bins[clampi(int((plot.pest_delay / grow - 0.25) / 0.07), 0, 4)] += 1
		for count in bins: check(count > 320 and count < 480, "independent deadlines spread across the window")
	farm.reset_game()
	farm.rng.seed = 7
	for plot in farm.plots: farm._clear_crop(plot)
	for action in ["hoe", "plant", "water"]: farm.interact_plot(5, action)
	farm.update(1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(farm._save_data()))
	check(farm._valid_save(saved), "growing deadline round trips")
	var clone = State.new()
	clone.restore_snapshot(saved)
	farm.update(29); clone.update(29)
	check(farm.rng.state == clone.rng.state, "saved pest chance preserves RNG")
	for i in range(farm.plots.size()):
		check(farm.plots[i].stage == clone.plots[i].stage and farm.plots[i].pests == clone.plots[i].pests and is_equal_approx(farm.plots[i].pest_delay, clone.plots[i].pest_delay) and is_equal_approx(farm.plots[i].plant_age, clone.plots[i].plant_age), "saved pest chance resumes deterministically")
	var p: Dictionary = farm.plots[5]
	p.pests = true; p.pest_checked = true
	farm.interact_plot(5, "pest")
	farm.update(120)
	check(not p.pests and p.pest_checked, "spraying does not schedule a late infestation")
	farm._clear_crop(p)
	check(p.plant_age == 0 and p.pest_delay == 0 and not p.pest_checked, "next planting gets a fresh chance")
	saved.plots[5].pest_delay = 1
	check(not farm._valid_save(saved), "too-early deadline rejected")
	clone.free(); farm.free()
	print("Pest schedule: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
