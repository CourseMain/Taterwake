extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
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
	check(clock.year == 1 and clock.season == 0 and clock.seconds == 0, "new farm starts at Spring dawn")
	check(not clock.advance(149.5), "fractional time stays in the season")
	check(clock.advance(0.5) and clock.season == 1 and clock.seconds == 0, "exact Spring boundary")
	clock.advance(150)
	check(clock.season == 2 and not clock.can_plant(), "Autumn closes planting")
	clock.advance(150)
	check(clock.season == 3 and not clock.can_plant(), "Winter is the fourth working season without planting")
	clock.advance(75)
	check(clock.seconds == 75 and clock.year == 1, "Winter has a real midpoint")
	check(clock.advance(75) and clock.year == 2 and clock.season == 0, "Winter rolls automatically into Spring")
	for invalid in [NAN, INF, -1.0]:
		check(not clock.advance(invalid) and clock.seconds == 0, "invalid delta cannot corrupt time")
	for bad in [{"year": 11}, {"season": -1}, {"seconds": 150}, {"winter_menu": true}, {"autumn_loss": 25}]:
		var data: Dictionary = clock.save_data(); data.merge(bad, true)
		check(not Clock.valid(data), "reject corrupt clock " + str(bad))
	clock.year = 10; clock.season = 3; clock.seconds = 149.75
	check(not clock.finished(), "year ten remains playable before Winter ends")
	check(clock.advance(0.25) and clock.finished() and Clock.valid(clock.save_data()), "final Winter ends exactly at 150 seconds")
	check(not clock.advance(150) and clock.year == 10, "there is no year eleven")

	var farm = fresh()
	farm.boundary_save_path = SAVE
	var boundaries: Array = []
	farm.season_changed.connect(func():
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		check(farm._valid_save(saved) and saved.season_clock == JSON.parse_string(JSON.stringify(farm.season_clock.save_data())), "complete boundary saved before listeners")
		boundaries.append(int(saved.season_clock.season)))
	farm.update(149.75); farm.update(0.5)
	check(farm.season_clock.season == 1 and farm.season_clock.seconds == 0.25, "excess time carries into Summer")
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 1, "Summer permits tilling and planting")
	farm._clear_crop(farm.plots[5]); farm.plots[5].tilled = false
	farm.update(149.75)
	farm.interact_plot(5, "hoe")
	check(not farm.plots[5].tilled, "Autumn blocks tilling")
	farm.plots[0].merge({"stage": 1, "tilled": true}, true)
	farm.plots[1].merge({"stage": 3, "tilled": true, "watered": true, "elapsed": State.CropTable.CROPS.russet.grow}, true)
	farm.storage["russet"] = Stock.pile(7)
	var notices: Array = []
	farm.notified.connect(func(message): notices.append(message))
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	check(farm.season_clock.season == 3 and farm.season_clock.autumn_loss == 2, "Autumn records both unharvested crops")
	check(farm.plots.all(func(p): return p.stage == 0 and not p.tilled and p.winter_ice), "every bed freezes after crops and prepared soil are cleared")
	check(Stock.count(farm.storage, "russet") == 7 and farm.trading.winters["1"].spoiled.russet == 0 and boundaries == [1, 2, 3], "Winter applies barn spoilage and saves once")
	check(notices.any(func(n): return "2 unharvested beds were lost" in n), "visible notice names Winter loss")
	farm.climate.data.operations.supply.water = 0
	farm.climate.data.operations.supply.can = 0
	farm.update(4)
	check(farm.season_clock.seconds == 4 and farm.climate.data.operations.supply.water == 6 and farm.climate.data.operations.supply.can == 0, "Winter snow refills the tank at one quarter rain rate, not the can")
	farm.interact_plot(5, "hoe")
	check(not farm.plots[5].winter_ice and not farm.plots[5].tilled, "Winter hoe clears ice without tilling")
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant")
	check(not farm.plots[5].tilled and farm.plots[5].stage == 0, "Winter cannot till or plant after clearing")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and not farm.plots[5].winter_ice and farm.plots[6].winter_ice and farm.season_clock.seconds == 4, "Winter time and per-bed clearing survive reload")
	farm.update(146)
	check(farm.season_clock.year == 2 and farm.season_clock.season == 0 and boundaries == [1, 2, 3, 0], "fourth boundary saves automatic Spring rollover")
	farm.interact_plot(5, "hoe")
	check(farm.plots[5].tilled, "a bed cleared in Winter is tillable on the first second of Spring")
	farm.interact_plot(6, "hoe")
	check(not farm.plots[6].winter_ice and not farm.plots[6].tilled, "uncleared Spring bed needs a separate ice-clearing action")
	farm.interact_plot(6, "hoe")
	check(farm.plots[6].tilled, "second Spring action tills the cleared bed")
	farm.climate.begin_warning(farm, "flood", 1)
	farm.update(150)
	check(farm.plots[7].winter_ice, "weather resets and recovery do not melt outstanding Winter work")
	farm.boundary_save_path = ""
	farm.free()

	# Every variety uses seasonal growth, independent of earlier day-length constants.
	for crop in State.CROP_IDS:
		farm = fresh()
		farm.selected_crop = crop; farm.seed_inventory[crop] = 1
		farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
		farm.plots[5].pest_checked = true
		var duration: float = State.CropTable.CROPS[crop].grow
		check(duration >= 60 and duration <= 200, crop + " has a 60–200 second base duration")
		farm.update(minf(74.5, duration - 0.5))
		check(farm.plots[5].stage == 2, crop + " does not ripen in the old first minute")
		farm.free()
	farm = fresh()
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
	farm.update(60)
	check(farm.plots[5].stage == 3 and farm.season_clock.season == 0, "fast Russet ripens halfway through Spring")
	farm.free()
	farm = fresh()
	farm.rng.seed = 6
	farm.selected_crop = "icecap"; farm.seed_inventory.icecap = 1
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
	farm.plots[5].pest_checked = true
	farm.update(150)
	check(farm.season_clock.season == 1 and farm.plots[5].stage == 2, "slow Icecap carries growth into Summer")
	farm.update(50)
	check(farm.plots[5].stage == 3, "slow Icecap ripens at second 200")
	farm.reset_game()
	farm.update(600)
	check(farm.elapsed == 600 and farm.season_clock.year == 2 and farm.season_clock.season == 0, "headless full year advances through all four working seasons")
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
	game.set_process(false)
	game.state.boundary_save_path = SAVE
	game.state.season_clock.season = 2
	game.state.season_clock.seconds = 149.75
	game._process(10)
	check(game.state.season_clock.season == 3 and game.state.season_clock.seconds == 0 and game.hud._panel_kind == "accounts", "accounts interrupt excess simulation exactly at Winter start")
	check(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).season_clock.season == 3, "Winter saves before accounts open")
	check(game.hud._top.season.text == "Winter · Year 1" and game.world.season_transition_info().active, "season strip shows Winter while snow begins its crossfade")
	game.world._process(1.0)
	check(game.world._winter_cover.visible and not game.world.season_transition_info().active, "Winter snow finishes its one-second crossfade")
	check(not game.hud._season_jobs.visible, "Winter jobs wait until the accounts close")
	var matching_ice := true
	for i in range(game.state.plots.size()):
		matching_ice = matching_ice and game.world._ice_roots[i].visible == game.state.plots[i].unlocked
	check(matching_ice, "frost meshes show ice only on opened beds")
	var snapshot: Dictionary = game.state._save_data()
	game._process(10); game.state.update(10)
	check(game.state._save_data() == snapshot, "accounts pause both controller and state simulation")
	var escape := InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	game._unhandled_input(escape)
	game._process(1)
	check(not game.hud.is_panel_open() and game.state.season_clock.seconds == 1, "Escape closes accounts and resumes Winter")
	check(game.hud._season_jobs.visible and game.hud._season_jobs.jobs.has("ice"), "closed accounts reveal the actual ice-clearing job")
	game._on_action("menu")
	check(not game.hud._modal.find_children("*", "Button", true, false).any(func(b): return b.text == "Annual accounts"), "Nell owns the accounts entrance")
	check(not game.hud._modal.find_children("*", "Button", true, false).any(func(b): return b.text.begins_with("Winter")), "old Winter menu entry is gone")
	game._on_action("accounts")
	check(game.state.accounts_open, "reopening accounts pauses again")
	game.hud._act("close")
	check(not game.state.accounts_open and not game.hud.is_panel_open(), "Walk out to the field resumes Winter without skipping it")
	game.perform_plot(5, "hoe")
	check(not game.world._ice_roots[5].visible, "clearing a bed removes its frost mesh")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/working-winter.png")
	game._on_action("menu")
	game._process(149)
	game.world._process(1.0)
	check(game.state.season_clock.year == 2 and not game.world._winter_cover.visible, "automatic Spring restores green ground after the crossfade")
	check(not game.hud._modal.find_children("*", "Button", true, false).any(func(b): return b.text == "Annual accounts"), "Spring refresh removes the Winter-only accounts link")
	game._on_action("accounts")
	check(game.state.accounts_open and game.hud._panel_kind == "accounts", "Nell can review accounts in Spring")
	game.hud.close_panel()
	game.state.reset_game()
	game._start_conversation("mara")
	await create_timer(0.1).timeout
	game._process(10)
	check(game.state.season_clock.seconds == 0, "NPC conversations still pause time")
	game.conversation.finish()
	game.state.coins = game.state.OVERDRAFT_LIMIT + game.state.ledger.fixed_cost_total() - 1
	game.state.season_clock.season = 2; game.state.season_clock.seconds = 149.75
	game.state.update(0.25)
	game._process(10)
	check(game.state.run_outcome == "foreclosed" and game.state.season_clock.seconds == 0, "foreclosure still stops the clock at Winter start")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout

func accelerated_run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.rng.seed = 6
	game.state.boundary_save_path = SAVE
	game._set_debug_session(true)
	game._debug_action(PackedStringArray(["debug", "time", "30"]))
	game.hud.close_panel()
	for year in range(1, 11):
		game.state.post_money("sales", "Annual receipts for calendar fixture", 200000)
		for frame in range(450): game._process(1.0 / 30.0)
		check(game.state.season_clock.year == year and game.state.season_clock.season == 3 and not game.state.run_over, "30x reaches a playable Winter in year %d" % year)
		check(game.hud._panel_kind == "accounts" and game.hud._top.season.text == "Winter · Year %d" % year, "30x accounts and year display agree")
		check(int(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).season_clock.year) == year, "boundary save agrees with displayed year")
		game.hud.close_panel()
		for frame in range(149): game._process(1.0 / 30.0)
		check(not game.state.run_over and game.state.season_clock.year == year, "Winter lasts its full working time")
		game._process(1.0 / 30.0)
		if year < 10:
			check(game.hud._top.season.text == "Spring · Year %d" % (year + 1) and not game.hud.is_panel_open(), "30x rolls straight into next Spring")
		await process_frame
	check(game.state.run_outcome == "completed" and game.state.season_clock.finished() and game.hud._panel_kind == "run_summary", "only the end of tenth Winter opens the ten-year summary")
	check(game.state.load_game(SAVE) and game.state.season_clock.finished(), "completed final boundary round-trips")
	game.state.reset_game(); game.hud.close_panel()
	game.state.season_changed.disconnect(game._on_season_changed)
	game.state.changed.disconnect(game._on_state_changed)
	game.state.coins = 400000
	game.state.season_clock.year = 10; game.state.season_clock.season = 2; game.state.season_clock.seconds = 149.75
	game.state.update(0.25)
	game.hud.update_state(game.state)
	check(game.hud._panel_kind == "accounts" and game.state.accounts_open, "ordinary HUD refresh repairs a missed accounts transition")
	game.hud.close_panel(); game.state.update(150); game._process(0.01)
	check(game.hud._panel_kind == "run_summary", "ordinary HUD refresh repairs missed completion without restarting")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
