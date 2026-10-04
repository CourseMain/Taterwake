extends SceneTree
## Opening the gate is presentation only until the player chooses a farm.
const SAVE := "user://taterland_title_scene_test_only.json"
var checks := 0
var failures := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(why)
func frames() -> void:
	for i in range(6): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await frames()
	check(not game.title_active(), "integration fixtures keep direct farm access")
	var before: Dictionary = game.state._save_data()
	var camera: Transform3D = game.world.camera.transform
	game._show_title(false)
	var title = game.title_scene
	check(title.root.get_child_count() == 2 and title.walk is Button and title.resume is Button, "title consists of two buttons with no modal, logo label or body")
	check(title.walk.text == "Walk to the farm" and title.resume.text == "Continue · Year 1, Spring", "first title reads the fresh farm's year and season")
	check(title.resume.disabled, "a missing save cannot be continued")
	check(not game.hud.root.visible and not game.touch_controls.root.visible, "title hides gameplay controls")
	check(game.world.title_gate.get_node("GateWordmark").text == "TATERLAND", "the name is painted on a world gate")
	check(game.world.title_gate.get_node("GateWordmark").billboard == BaseMaterial3D.BILLBOARD_DISABLED, "gate name faces with its wood instead of following the camera")
	var pan: Transform3D = game.world.camera.transform
	var world_time: float = game.world._time
	game._process(5)
	check(not game.world.camera.transform.is_equal_approx(pan), "the title camera slowly pans")
	check(game.world._time > world_time + 4.9, "the farm animates behind the title")
	check(game.state._save_data() == before, "waiting at the gate never advances crops, weather, accounts or save state")
	check(is_equal_approx(game.world._day_elapsed, game.world.DAY_CYCLE_SECONDS * .94), "title uses golden-hour light without changing the calendar")
	check(not game.can_hurry() and not game._map_navigation_allowed(), "title blocks hurry and farm navigation")
	game._on_user_action("quick_sell")
	game._on_action("reset")
	check(game.state._save_data() == before and game.title_active(), "hidden gameplay and reset shortcuts cannot change the title farm")
	game.touch_controls.enabled = true
	for size: Vector2i in [Vector2i(390,844), Vector2i(844,390), Vector2i(1280,800)]:
		root.size = size
		await frames()
		game.touch_controls.resize()
		title._layout()
		var bounds := root.get_visible_rect()
		var scale: float = minf(float(root.size.x) / bounds.size.x, float(root.size.y) / bounds.size.y)
		for button: Button in [title.walk, title.resume]:
			check(bounds.encloses(button.get_global_rect()), "title action stays inside " + str(size))
			check(button.size.y * scale >= 43.9, "title action stays at least 44 px high at " + str(size))
		if size == Vector2i(390,844) and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/segment21c-title-390.png")
	title.walk.pressed.emit()
	check(not game.title_active() and game.tutorial.current_id() == "welcome", "walking into a fresh farm starts the existing guided year")
	check(game.world.camera.transform.is_equal_approx(camera), "entry restores the player's normal farm camera")
	game.tutorial.finish()
	game.year_intro.stop()
	game.state.coins = 90000
	for season in range(10):
		game.hud.close_panel()
		game.state.update(game.state.season_seconds())
	game.hud.close_panel()
	game.state.update(42)
	check(game.state.save_game(SAVE) and game.state.load_game(SAVE), "returning title fixture loads a real validated farm save")
	var saved_bytes := FileAccess.get_file_as_string(SAVE)
	before = game.state._save_data()
	game._show_title(true)
	check(not title.resume.disabled and title.resume.text == "Continue · Year 3, Autumn", "Continue uses the loaded farm's own year and season")
	title.walk.pressed.emit()
	check(title.confirming and game.hud._reset_pending, "starting over from a saved title opens the existing reset confirmation")
	game._process(8)
	check(game.state._save_data() == before and FileAccess.get_file_as_string(SAVE) == saved_bytes, "new-farm confirmation preserves farm and save until confirmed")
	game.hud._act("cancel_reset")
	game._process(.01)
	check(game.title_active() and title.root.visible and not game.hud.is_panel_open(), "Keep my farm returns to the gate")
	title.resume.pressed.emit()
	check(not game.title_active() and game.state._save_data() == before, "Continue resumes the exact saved farm without resetting it")
	check(is_equal_approx(game.world._day_elapsed, game.state.calendar_light_seconds()), "Continue restores actual calendar lighting")
	game._show_title(true)
	title.walk.pressed.emit()
	game.hud._act("reset")
	check(not game.title_active() and game.state.season_clock.year == 1 and game.tutorial.current_id() == "welcome", "only confirmed new-farm action resets and starts the guide")
	game.tutorial.finish()
	game.state.coins = -100000
	game.state.update(game.state.season_seconds() * 3)
	check(game.state.run_outcome == "foreclosed", "title end-state fixture reaches actual foreclosure")
	game._show_title(true)
	title.walk.pressed.emit()
	check(title.confirming and not game.hud._run_end.visible, "new-farm confirmation stays reachable above a saved foreclosure")
	game.hud._act("cancel_reset")
	game._process(.01)
	check(game.title_active() and title.root.visible, "a foreclosed farmer can keep their saved run")
	title.resume.pressed.emit()
	check(not game.title_active() and game.hud._run_end.visible and game.state.run_outcome == "foreclosed", "Continue restores the saved foreclosure screen")
	for path: String in [SAVE, SAVE + ".bak", SAVE + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# The final Winter entry starts Nell's real voice. Stop it before freeing
	# the scene, then let the audio mixer release its deferred WAV playback.
	game.conversation.voice.stop()
	game.year_intro.voice.stop()
	game.queue_free()
	await frames()
	await create_timer(.1).timeout
	print("FARM TITLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
