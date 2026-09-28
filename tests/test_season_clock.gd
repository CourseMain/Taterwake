extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Clock = preload("res://scripts/season_clock.gd")
const SAVE := "user://season_clock_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func fresh():
	var farm = State.new()
	root.add_child(farm)
	for plot in farm.plots: farm._clear_crop(plot); plot.tilled = false
	# Choose a calm first season; separate probability checks cover the weather draw.
	var probe := RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed = seed_value
		if probe.randf() >= 0.15:
			farm.rng.seed = seed_value
			break
	return farm
func run() -> void:
	var clock = Clock.new()
	check(clock.year == 1 and clock.season == 0 and clock.seconds == 0 and not clock.winter_menu, "new farm starts at year-one Spring dawn")
	check(not clock.advance(149.5) and clock.seconds == 149.5, "fractional working time")
	check(clock.advance(0.5) and clock.season == 1 and clock.seconds == 0, "exact Spring boundary")
	clock.advance(150)
	check(clock.season == 2 and not clock.can_plant(), "Autumn closes planting")
	clock.advance(150)
	var paused: Dictionary = clock.save_data()
	check(clock.winter_menu and not clock.advance(999) and clock.save_data() == paused, "Winter waits for the player")
	check(clock.start_next_year() and clock.year == 2 and clock.season == 0, "explicit next year returns to Spring")
	check(not clock.start_next_year(), "next-year action cannot skip working seasons")
	for invalid in [NAN, INF, -1.0]:
		check(not clock.advance(invalid) and clock.seconds == 0, "invalid delta never corrupts the calendar")
	for bad in [{"year": 11}, {"season": -1}, {"seconds": 150}, {"winter_menu": true}, {"autumn_loss": 25}]:
		var data: Dictionary = clock.save_data(); data.merge(bad, true)
		check(not Clock.valid(data), "reject corrupt clock " + str(bad))

	var farm = fresh()
	farm.boundary_save_path = SAVE
	var boundaries: Array = []
	farm.season_changed.connect(func():
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		check(farm._valid_save(saved) and saved.season_clock == JSON.parse_string(JSON.stringify(farm.season_clock.save_data())), "boundary is saved before listeners run")
		boundaries.append(int(saved.season_clock.season)))
	farm.update(149.75)
	check(farm.season_clock.season == 0 and is_equal_approx(farm.season_clock.seconds, 149.75) and boundaries.is_empty(), "no early transition or boundary save")
	farm.update(0.5)
	check(farm.season_clock.season == 1 and is_equal_approx(farm.season_clock.seconds, 0.25), "large step carries its remainder into Summer")
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 1, "Summer permits both tilling and planting")
	farm._clear_crop(farm.plots[5]); farm.plots[5].tilled = false
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.season_clock.season == 2 and boundaries == [1, 2], "Summer boundary saves Autumn")
	var seeds: int = farm.seed_inventory.russet
	farm.interact_plot(5, "hoe")
	check(not farm.plots[5].tilled, "Autumn cannot till empty beds")
	farm.plots[5].tilled = true
	farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 0 and farm.seed_inventory.russet == seeds, "Autumn planting cannot spend seeds")
	farm.plots[0].merge({"stage": 1, "tilled": true}, true)
	farm.plots[1].merge({"stage": 3, "tilled": true, "watered": true, "elapsed": State.CROPS.russet.grow}, true)
	farm.storage.russet = 7
	var notices: Array = []
	farm.notified.connect(func(message): notices.append(message))
	farm.season_clock.seconds = 149.75
	farm.update(10)
	check(farm.season_clock.winter_menu and farm.season_clock.autumn_loss == 2 and farm.plots.all(func(p): return p.stage == 0 and not p.tilled), "Autumn clears growing and ripe crops, plus prepared soil")
	check(farm.storage.russet == 7 and boundaries == [1, 2, 3], "Winter preserves stored harvest and saves exactly once")
	check(notices.any(func(n): return "2 unharvested beds were lost" in n), "visible notice gives loss count and winter cause")
	paused = farm._save_data()
	farm.update(500)
	check(farm._save_data() == paused, "Winter pauses crops, pests, ducks, prices, climate and elapsed time")
	farm.interact_plot(5, "hoe")
	check(not farm.plots[5].tilled, "Winter field controls cannot bypass the pause")
	farm.climate.fund(farm, "irrigation")
	check(farm.climate.data.projects.get("irrigation", 0) == 1, "Winter still allows buying protection while time is paused")
	check(farm.load_game(SAVE) and farm.season_clock.winter_menu and farm.season_clock.autumn_loss == 2, "Winter loss and menu phase survive reload")
	check(farm.start_next_year() and farm.season_clock.year == 2 and boundaries == [1, 2, 3, 0], "next year saves Spring before reopening work")
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 1, "Spring reopens tilling and planting")
	farm.boundary_save_path = ""
	farm.free()

	# Every variety uses seasonal growth, independent of earlier day-length constants.
	for crop in State.CROP_IDS:
		farm = fresh()
		farm.selected_crop = crop; farm.seed_inventory[crop] = 1
		farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
		var duration: float = State.CROPS[crop].grow
		check(duration >= 75 and duration <= 225, crop + " has a half- to one-and-a-half-season base duration")
		farm.update(minf(74.5, duration - 0.5))
		check(farm.plots[5].stage == 2, crop + " does not ripen in the old first minute")
		farm.free()
	farm = fresh()
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
	farm.update(75)
	check(farm.plots[5].stage == 3 and farm.season_clock.season == 0, "fast Russet ripens halfway through Spring")
	farm.free()
	farm = fresh()
	farm.rng.seed = 1
	farm.selected_crop = "icecap"; farm.seed_inventory.icecap = 1
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
	farm.update(150)
	check(farm.season_clock.season == 1 and farm.plots[5].stage == 2, "slow Icecap carries growth into Summer")
	farm.update(75)
	check(farm.plots[5].stage == 3, "slow Icecap ripens after a season and a half")
	farm.reset_game()
	farm.update(1000)
	check(farm.season_clock.winter_menu and farm.season_clock.year == 1 and farm.elapsed == 450, "a full working year stops exactly at Winter even with excess delta")
	farm.season_clock.year = 10
	check(not farm.start_next_year() and farm.season_clock.year == 10 and farm.season_clock.winter_menu, "year ten is the final Winter")
	farm.free()
	await scene_checks()
	await accelerated_run_checks()
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("SEASON CLOCK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func scene_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.boundary_save_path = SAVE
	game.state.season_clock.season = 2
	game.state.season_clock.seconds = 149.75
	game._process(1)
	check(game.state.season_clock.winter_menu and game.hud._panel_kind == "winter", "main opens Winter at the boundary")
	check(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).season_clock.winter_menu, "Winter is already on disk when its menu appears")
	check(game.hud._body.find_children("*", "Button", true, false).any(func(b): return b.text == "Start next year"), "Winter offers a real next-year button")
	check(game.hud._top.season.text == "Year 1 · Winter" and game.world._winter_cover.visible, "HUD calendar and snow reflect Winter")
	var snapshot: Dictionary = game.state._save_data()
	game._process(10)
	check(game.state._save_data() == snapshot, "main keeps Winter frozen while rendering")
	var escape := InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	game._unhandled_input(escape)
	check(not game.hud.is_panel_open(), "Escape can dismiss Winter")
	game._on_action("menu")
	check(game.hud._body.find_children("*", "Button", true, false).any(func(b): return b.get_meta("action", "") == "winter"), "farm menu always offers a route back to Winter")
	game._on_action("winter")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/season-winter.png")
	game._on_action("next_year")
	check(game.state.season_clock.year == 2 and not game.hud.is_panel_open() and not game.world._winter_cover.visible, "next year restores the green farm without trapping controls")
	game.state.season_clock.year = 10
	game.state.season_clock.season = 2
	game.state.season_clock.seconds = 149.75
	game._process(0.25)
	check(game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text == "Ten years complete"), "final Winter announces completion")
	check(not game.hud._body.find_children("*", "Button", true, false).any(func(button): return button.get_meta("action", "") == "next_year"), "year ten has no next-year button")
	game._on_action("next_year")
	check(game.state.season_clock.year == 10 and game.hud._panel_kind == "winter", "stale next-year actions cannot leave the final Winter")
	game._on_action("menu")
	check(game.hud.is_panel_open() and game.hud._panel_kind != "winter", "final Winter still opens the farm menu")
	game.state.reset_game()
	game.hud.close_panel()
	game._start_conversation("mara")
	# Exercise a real playback frame before ending the conversation.
	await create_timer(0.1).timeout
	var before: float = game.state.season_clock.seconds
	game._process(10)
	check(game.state.season_clock.seconds == before, "conversations pause the calendar")
	game.conversation.finish()
	# Let the audio mixer release the conversation playback before scene teardown.
	await create_timer(0.1).timeout
	game.state.coins = -5001
	game._process(10)
	check(game.state.season_clock.seconds == before, "collapse pauses the calendar")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout

func accelerated_run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.rng.seed = 6
	game.state.boundary_save_path = SAVE
	game._set_debug_session(true)
	game._debug_action(PackedStringArray(["debug", "time", "30"]))
	game.hud.close_panel()
	await process_frame
	check(game.debug_time_multiplier == 30, "accelerated regression uses the real 30x debug control")
	for year in range(1, 11):
		var frames: int = 0
		while not game.state.season_clock.winter_menu and frames < 1000:
			game._process(1.0 / 30.0)
			frames += 1
			if frames % 50 == 0: await process_frame
		check(game.state.season_clock.year == year and game.state.season_clock.winter_menu, "30x reaches Winter in year %d" % year)
		check(game.hud._top.season.text == "Year %d · Winter" % year and game.hud._modal_title.text == "Winter · Year %d" % year and game.hud._panel_kind == "winter", "30x keeps both year displays current in year %d" % year)
		check(int(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).season_clock.year) == year, "30x boundary save agrees with the displayed year")
		game.hud.close_panel()
		game._process(0.25)
		check(not game.hud.is_panel_open(), "regular refresh respects dismissed Winter in year %d" % year)
		game._on_action("winter")
		if year < 10:
			for button in game.hud._body.find_children("*", "Button", true, false):
				if button.get_meta("action", "") == "next_year":
					button.pressed.emit()
					break
			check(game.hud._top.season.text == "Year %d · Spring" % (year + 1) and not game.hud.is_panel_open(), "next-year button immediately updates the year at 30x")
		await process_frame
	check(game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text == "Ten years complete"), "30x run presents the final year-ten message")
	# A missed transition callback must heal on the next ordinary HUD refresh.
	game.state.reset_game()
	game.hud.close_panel()
	game.state.season_changed.disconnect(game._on_season_changed)
	game.state.changed.disconnect(game._on_state_changed)
	game.state.season_clock.year = 10
	game.state.season_clock.season = 2
	game.state.season_clock.seconds = 149.75
	game.state.update(0.25)
	check(not game.hud.is_panel_open(), "missed callback leaves the presentation stale before polling")
	await process_frame
	game.ui_elapsed = 0.21
	game._process(0.01)
	check(game.hud._top.season.text == "Year 10 · Winter" and game.hud._panel_kind == "winter" and game.hud._modal_title.text == "Winter · Year 10", "ordinary refresh repairs a missed final Winter transition without reload")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
