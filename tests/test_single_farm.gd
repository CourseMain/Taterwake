extends SceneTree
const State = preload("res://scripts/game_state.gd")
const World = preload("res://scripts/farm_world.gd")
const Climate = preload("res://scripts/climate_system.gd")
const SAVE := "user://single_farm_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	check(State.DEFAULT_SAVE_PATH == "user://taterland_save_v4.json" and State.SAVE_VERSION == 4 and State.MECHANICS_REVISION == 30, "new farm format and isolated v4 path")
	check(World.REGION == 1 and farm.plots.size() == 24 and farm.plots.filter(func(p): return p.unlocked).size() == 12, "Valley starts with twelve open and twelve locked beds")
	check(farm.field_columns() == 6 and farm.field_rows() == 4, "one six-by-four field")
	check(farm.available_crops().has("sunburst") and farm.available_crops().has("icecap"), "ordinary varieties have no travel gate")
	for crop in ["sunburst", "icecap"]:
		farm.buy_seeds(crop, 1)
		farm.select_crop(crop)
		farm.interact_plot(6, "hoe")
		farm.interact_plot(6, "plant")
		check(farm.plots[6].crop == crop and farm.plots[6].stage == 1, crop + " plants on the valley")
		farm._clear_crop(farm.plots[6])
	farm.coins = 1200
	farm.expand_field()
	check(farm.expansion == 1 and farm.coins == 0 and farm.plots.all(func(p): return p.unlocked), "one paid expansion opens the remaining twelve beds")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots.size() == 24 and farm.expansion == 1, "single field round trips")
	var saved: Dictionary = farm._save_data()
	for field in ["current_island", "island2_unlocked", "island3_unlocked", "island_plots", "field_expansions", "retained_beds", "export_active", "export_timer", "frost_active", "frost_timer"]:
		check(not saved.has(field), "save omits " + field)
	for version in [2, 3]:
		var old: Dictionary = saved.duplicate(true)
		old.schema_version = version
		old.mechanics_revision = 26
		var file := FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(old)); file.close()
		check(not farm.load_game(SAVE) and farm._save_data() == saved and FileAccess.file_exists(SAVE + ".rejected"), "older schema rejected without migrating or changing farm")
	for path in State.PROTECTED_SAVE_PATHS:
		check(not farm.load_game(path) and not farm.save_game(path), "old default path is neither loaded nor overwritten")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.expansion = 0
	check(not farm._valid_save(corrupt), "upper beds require the single expansion flag")
	for field in ["operations", "lesson"]:
		corrupt = saved.duplicate(true)
		corrupt.climate.erase(field)
		check(not farm._valid_save(corrupt), "missing climate component rejects safely: " + field)
	# Empty crops prevent unrelated pest RNG from consuming the weather draw.
	# Every season uses exactly the documented threshold, including season one.
	var hits := 0
	for seed_value in range(100):
		farm.reset_game()
		for plot in farm.plots: farm._clear_crop(plot)
		farm.rng.seed = seed_value
		var expected := RandomNumberGenerator.new()
		expected.seed = seed_value
		var event_expected: bool = expected.randf() < 0.15
		farm.update(0.25)
		check(farm.season_clock.season == 0, "first weather draw occurs in Spring")
		check((farm.climate.data.phase == "warning") == event_expected, "single 15 percent draw at season boundary")
		if event_expected: hits += 1
	check(hits > 0 and hits < 100 and Climate.DISASTER_CHANCE == 0.15, "both calm and disaster seasons are reachable")
	farm.reset_game()
	for plot in farm.plots: farm._clear_crop(plot)
	farm.update(149.5)
	check(farm.save_game(SAVE), "save just before seasonal draw")
	farm.update(0.75)
	var next: Dictionary = farm.climate.data.duplicate(true)
	var rng_after: String = str(farm.rng.state)
	check(farm.load_game(SAVE), "restore seasonal checkpoint")
	farm.update(0.75)
	check(JSON.parse_string(JSON.stringify(farm.climate.data)) == JSON.parse_string(JSON.stringify(next)) and str(farm.rng.state) == rng_after, "reload preserves the next weather outcome")
	farm.reset_game()
	farm.set_tutorial_active(true)
	farm.update(600)
	check(farm.season_clock.seconds == 0.0, "farm tour pauses weather draws")
	var subtitles = preload("res://scripts/chapter_subtitles.gd").new()
	root.add_child(subtitles)
	var completions: Array = []
	subtitles.finished.connect(func(): completions.append(true))
	subtitles.start("A new year on the farm")
	check(subtitles.visible and subtitles.chapter.text == "A new year on the farm", "chapter subtitles remain reusable")
	subtitles.skip.pressed.emit()
	check(not subtitles.visible and completions.size() == 1, "chapter skip completes once")
	subtitles.start("The weather ahead")
	subtitles._process(subtitles.DURATION)
	check(not subtitles.visible and completions.size() == 2, "timed subtitles finish without an arrival cinematic")
	subtitles.free()
	farm.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hud.show_panel("menu", game.state)
	for button in game.hud._body.find_children("*", "Button", true, false):
		check(not button.text.to_lower().contains("travel") and button.get_meta("action", "") != "island", "menu has no Travel entry")
	check(game.world.plot_positions.size() == 24 and is_instance_valid(game.world.weather_station), "Valley geometry and weather station boot together")
	check(game.world.has_method("_tropical_island") and game.world.has_method("_winter_island"), "dormant region builders retained")
	for target in game.world._interaction_targets:
		check(target.get_meta("station", "") != "island", "no jetty boarding interaction")
	game.debug_unlocked = true
	game._on_action("debug:weather:freeze")
	check(game.state.climate.data.phase == "warning" and game.state.climate.data.event == "freeze", "debug freeze works on the Valley without travel")
	game.state.climate.reset()
	game.hud._climate_alert.dismiss()
	game.hud.show_panel("menu", game.state)
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/segment7-menu.png")
		game.hud.close_panel()
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/segment7-valley.png")
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".rejected", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("SINGLE FARM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
