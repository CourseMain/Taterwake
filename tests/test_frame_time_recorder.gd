extends SceneTree
## Measurement follows the real Debug and accounts controls without saving samples.
const Recorder = preload("res://scripts/frame_time_recorder.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var frames := PackedFloat64Array()
	for index in range(198): frames.append(10)
	frames.append(50); frames.append(150)
	var stats: Dictionary = Recorder.statistics(frames)
	check(is_equal_approx(stats.mean_fps, 200000.0 / 2180.0), "mean fps includes every slow frame")
	check(is_equal_approx(stats.low_fps, 10.0) and stats.worst_ms == 150, "one-percent low averages the two slowest of two hundred frames")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.frame_recorder.set_process(false)
	game.state.tutorial_progress.completed = true
	game.hud.show_panel("debug", game.state)
	var measure: Button
	for button in game.hud._body.find_children("*", "Button", true, false):
		if button.get_meta("hud_action", "") == "measure_year": measure = button
	check(is_instance_valid(measure) and not measure.disabled and not game.debug_unlocked, "measurement is available in the real locked Debug panel without funding access")
	var before: Dictionary = game.state._save_data().duplicate(true)
	measure.pressed.emit()
	check(game.frame_recorder.recording and not game.hud.is_panel_open(), "one tap starts recording and returns to the farm")
	check(game.state._save_data() == before, "starting measurement leaves the saved farm byte-for-byte equivalent")
	game.frame_recorder.observe(16, 1, 1, false)
	game.frame_recorder.observe(40, 1, 2, false)
	game.frame_recorder.observe(20, 1, 3, true)
	check(game.frame_recorder.recording, "Winter opening does not finish the sample")
	game.frame_recorder.observe(10, 1, 3, false)
	await process_frame
	check(not game.frame_recorder.recording and game.frame_recorder.report.worst_season == "Autumn", "accounts closing finishes and attributes the worst frame to its season")
	check(game.hud._panel_kind == "measurement" and game.frame_recorder.report_text.contains("Mean:") and game.frame_recorder.report_text.contains("1% low:"), "the result card includes mean and low frame rates")
	check(not game.state._save_data().has("measurement") and game.state._save_data() == before, "samples and result never enter the farm save")
	game.frame_recorder.copy_report()
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.clipboard_get() == game.frame_recorder.report_text, "native Copy exports the same card text")
	# Starting after Winter's accounts have closed waits for the following year.
	game.hud.close_panel()
	game.state.season_clock.season = 3
	game.frame_recorder.start()
	game.frame_recorder.observe(16, 1, 3, true)
	game.frame_recorder.observe(16, 1, 3, false)
	check(game.frame_recorder.recording, "a Winter start cannot mistake the current year's old accounts for the next Winter")
	game.frame_recorder.observe(16, 2, 3, true)
	game.frame_recorder.observe(16, 2, 3, false)
	check(not game.frame_recorder.recording, "a Winter start ends at next year's accounts closing")
	game.queue_free()
	await process_frame
	print("FRAME TIME RECORDER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
