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
	var label_visibility: Dictionary = {}
	for label: Label3D in game.world.find_children("*", "Label3D", true, false): label_visibility[label] = label.visible
	var background: int = game.world._day_environment.background_mode
	var sky = game.world._day_environment.sky
	game._show_title(false)
	var title = game.title_scene
	check(title.idle.actors.size() == 3 and title.idle.petals.size() == 6, "only Mara, Bram and the farmer idle beside six Spring title petals")
	var mara_pose: Transform3D = title.idle.actors[0].rig
	var poses: Array[Transform3D] = []
	for record: Dictionary in title.idle.actors: poses.append(record.person._rig.transform)
	title.elapsed = 1.0
	title._process(0)
	for i in range(3):
		check(not title.idle.actors[i].person._rig.transform.is_equal_approx(poses[i]), "each gate character breathes on the title")
		title.idle.advance(3.4 + i * .7 - .09)
		check(title.idle.actors[i].person._eyes.all(func(eye): return eye.scale.y < .1), "each gate character blinks at its 3–5 second interval")
	title.elapsed = 0.0
	title.idle.advance(0)
	var petal: Vector3 = title.idle.petals[0].position
	title.idle.advance(1)
	check(title.idle.petals[0].position != petal, "Spring petals drift without a collision or UI target")
	check(title.walk is Button and title.resume is Button and not title.confirmation.visible, "title has its world action and a hidden title-owned confirmation")
	check(title.walk.text == "Walk to the farm" and not title.resume.visible, "fresh title shows one action and no second line")
	check(title.resume.disabled, "a missing save cannot be continued")
	check(not game.hud.root.visible and not game.touch_controls.root.visible, "title hides gameplay controls")
	check(game.world.title_gate.get_node("GateWordmark").text == "TATERLAND", "the name is painted on a world gate")
	check(game.world.title_gate.get_node("GateWordmark").billboard == BaseMaterial3D.BILLBOARD_DISABLED, "gate name faces with its wood instead of following the camera")
	var visible_words: Array[String] = []
	for label: Label3D in label_visibility:
		if label.is_visible_in_tree(): visible_words.append(label.text)
	check(visible_words == ["TATERLAND"], "the gate name is the only world lettering on the title")
	check(game.world._lease_boards.all(func(board): return not board.visible), "To Let boards wait until the player enters")
	check(game.world.visuals.grade_batches.values().all(func(marker): return not marker.visible) and not game.world.visuals.water_markers.visible, "crop grade and water markers stay out of the welcome")
	check(title.walk.get_theme_stylebox("normal").bg_color == Color("17382d"), "the large title action is an ink surface")
	check(title.resume.get_theme_stylebox("normal") is StyleBoxEmpty, "Start a new farm is a quiet text action with no second large card")
	check(title.resume.get_theme_color("font_outline_color") == Color("17382d"), "New farm remains readable over the moving farm")
	check(is_equal_approx(game.world._sun.rotation_degrees.x, -15) and game.world._sun.light_color.r > game.world._sun.light_color.b, "title uses a low fifteen-degree amber sun")
	check(game.world._day_environment.background_mode == Environment.BG_SKY and game.world._day_environment.sky != sky, "the title owns a temporary dusk sky gradient")
	game.world._sun.rotation_degrees = Vector3(-60, -32, 0)
	title._process(0)
	check(is_equal_approx(game.world._sun.rotation_degrees.x, -15), "live world lighting cannot lift the title's low sun")
	var pan: Transform3D = game.world.camera.transform
	var close_size: float = game.world.camera.size
	var world_time: float = game.world._time
	game._process(4)
	check(not game.world.camera.transform.is_equal_approx(pan), "the title camera slowly pans")
	var middle_size: float = game.world.camera.size
	game._process(4)
	var wide_size: float = game.world.camera.size
	check(close_size < middle_size and middle_size < wide_size, "eight-second pullback reveals more farm continuously")
	pan = game.world.camera.transform
	game._process(1)
	check(is_equal_approx(game.world.camera.size, wide_size) and not game.world.camera.transform.is_equal_approx(pan), "after eight seconds the wide view keeps drifting without another zoom or cut")
	check(game.world._time > world_time + 8.9, "the farm animates behind the title")
	check(game.state._save_data() == before, "waiting at the gate never advances crops, weather, accounts or save state")
	check(is_equal_approx(game.world._day_elapsed, game.world.DAY_CYCLE_SECONDS * .94), "title uses golden-hour light without changing the calendar")
	check(not game.can_hurry() and not game._map_navigation_allowed(), "title blocks hurry and farm navigation")
	game._on_user_action("quick_sell")
	game._on_action("reset")
	check(game.state._save_data() == before and game.title_active(), "hidden gameplay and reset shortcuts cannot change the title farm")
	game.touch_controls.enabled = true
	for size: Vector2i in [Vector2i(390,844), Vector2i(844,390), Vector2i(1280,800)]:
		game.touch_controls.enabled = size.x < 900
		if not game.touch_controls.enabled: root.content_scale_size = size
		root.size = size
		await frames()
		game.touch_controls.resize()
		title._layout()
		var bounds := root.get_visible_rect()
		var scale: float = minf(float(root.size.x) / bounds.size.x, float(root.size.y) / bounds.size.y)
		for button: Button in [title.walk]:
			check(bounds.encloses(button.get_global_rect()), "title action stays inside " + str(size))
			check(button.size.y * scale >= 43.9, "title action stays at least 44 px high at " + str(size))
		if size in [Vector2i(390,844), Vector2i(1280,800)] and "--capture" in OS.get_cmdline_user_args():
			for seconds: float in [0,8]:
				title.elapsed = seconds
				title.advance(0)
				await frames()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/segment21c-title-%d-%ds.png" % [size.x,int(seconds)])
	title.walk.pressed.emit()
	check(game.title_active() and title.walking_in and not game.tutorial.active, "guide waits for the walk-in")
	title.advance(title.WALK_IN_SECONDS)
	check(not game.title_active() and game.tutorial.current_id() == "welcome", "walking into a fresh farm starts the existing guided year")
	check(is_equal_approx(game.world.camera.size, game.world.overview_size()), "fresh entry fits the overview to the current viewport")
	check(title.idle.actors.is_empty() and title.idle.petals.is_empty(), "breathing overrides and petals stop at the title exit")
	check(game.world._npc_actors.mara._rig.transform.is_equal_approx(mara_pose), "Mara returns to her original shop pose after the title")
	var restored: bool = true
	for label: Label3D in label_visibility:
		if label.visible != bool(label_visibility[label]): restored = false
	check(restored, "entry restores each world's visible and hidden label state")
	check(game.world._day_environment.background_mode == background and game.world._day_environment.sky == sky, "entry restores the farm's original sky resource and background mode")
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
	check(title.idle.petals.is_empty(), "Autumn title does not add Spring petals")
	check(title.resume.visible and title.walk.text == "Continue · Year 3, Autumn" and title.resume.text == "Start a new farm", "Continue uses the loaded farm's own year and season")
	title.resume.pressed.emit()
	check(title.confirming and title.confirmation.visible and not game.hud._reset_pending and not game.hud.is_panel_open(), "starting over opens a title-owned confirmation without the pause reset flag")
	game._process(8)
	check(game.state._save_data() == before and FileAccess.get_file_as_string(SAVE) == saved_bytes, "new-farm confirmation preserves farm and save until confirmed")
	title.keep_farm.pressed.emit()
	game._process(.01)
	check(game.title_active() and title.root.visible and not game.hud.is_panel_open(), "Keep my farm returns to the gate")
	title.walk.pressed.emit()
	check(not game.title_active() and game.state._save_data() == before, "Continue resumes the exact saved farm without resetting it")
	check(is_equal_approx(game.world._day_elapsed, game.state.calendar_light_seconds()), "Continue restores actual calendar lighting")
	game._show_title(true)
	title.resume.pressed.emit()
	check(title.keep_farm.has_focus() and title.confirmation_words.text == "Replace your Year 3 farm? This cannot be undone.", "replacement says which farm and defaults to Keep")
	title.replace_farm.pressed.emit()
	game._process(title.WALK_IN_SECONDS)
	check(not game.title_active() and game.state.season_clock.year == 1 and game.tutorial.current_id() == "welcome", "only confirmed new-farm action resets and starts the guide")
	game.tutorial.finish()
	game.state.coins = -100000
	game.state.update(game.state.season_seconds() * 3)
	check(game.state.run_outcome == "foreclosed", "title end-state fixture reaches actual foreclosure")
	game._show_title(true)
	title.resume.pressed.emit()
	check(title.confirming and title.confirmation.visible and not game.hud._run_end.visible, "new-farm confirmation stays reachable above a saved foreclosure")
	title.keep_farm.pressed.emit()
	game._process(.01)
	check(game.title_active() and title.root.visible, "a foreclosed farmer can keep their saved run")
	title.walk.pressed.emit()
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
