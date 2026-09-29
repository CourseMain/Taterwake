extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
const State = preload("res://scripts/game_state.gd")
const Climate = preload("res://scripts/climate_system.gd")
const World = preload("res://scripts/farm_world.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const SAVE := "user://climate_curve_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(note)
func fresh():
	var farm = State.new(); root.add_child(farm)
	farm.coins = 1000000
	for plot in farm.plots: farm._clear_crop(plot)
	return farm
func run() -> void:
	var farm = fresh()
	for year in range(1, 16):
		check(is_equal_approx(Climate.chance(year), minf(0.6, 0.15 + 0.04 * (year - 1))), "year chance follows capped curve")
		check(is_equal_approx(Climate.severity_mean(year), 0.5 + 0.03 * (year - 1)), "severity mean follows curve")
	for year in [1, 6, 10]:
		var total: float = 0
		farm.rng.seed = 410 + year
		for i in range(12000): total += Climate.draw_severity(farm.rng, year)
		check(absf(total / 12000 - Climate.severity_mean(year)) < 0.003, "sampled severity is centered on year mean")
	var counts := {"drought": [0, 0, 0, 0], "flood": [0, 0, 0, 0], "storm": [0, 0, 0, 0]}
	var outcomes_match: bool = true
	var signals_match: bool = true
	for year in [1, 6, 10]:
		var strikes: int = 0
		var signalled: int = 0
		var signalled_strikes: int = 0
		var quiet: int = 0
		var quiet_strikes: int = 0
		farm.rng.seed = 510 + year
		for i in range(12000):
			farm.climate.reset()
			# Independent seasons isolate the curve from the separate annual cap.
			var season: int = i % 4
			farm.season_clock.season = (season + 3) % 4
			farm.season_clock.year = year - (1 if season == 0 else 0)
			farm.climate.prime_next(farm)
			var next: Dictionary = farm.climate.data.outlook.next.duplicate()
			var hint: String = farm.climate.data.outlook.signal
			farm.season_clock.year = year; farm.season_clock.season = season
			farm.climate.start_season(farm)
			var fired: bool = farm.climate.data.phase == "warning"
			if fired: strikes += 1
			outcomes_match = outcomes_match and fired == next.fires and (not fired or farm.climate.data.event == next.event)
			signals_match = signals_match and (hint == "" or (counts.has(next.event) and hint == next.event))
			if not counts.has(next.event): continue
			# Only drought/flood/storm have signals; freezes and Winter have none.
			var bucket: int = 0 if fired else 2
			counts[next.event][bucket] += 1
			if hint != "":
				counts[next.event][bucket + 1] += 1
				signalled += 1
				if fired: signalled_strikes += 1
			else:
				quiet += 1
				if fired: quiet_strikes += 1
		var signal_rate: float = float(signalled_strikes) / signalled
		var quiet_rate: float = float(quiet_strikes) / quiet
		check(signal_rate >= 3.0 * quiet_rate, "year %d: disaster is at least three times likelier with an eligible signal" % year)
		check(absf(strikes / 12000.0 - Climate.chance(year)) < 0.02, "pre-rolled seasonal frequency follows year %d chance" % year)
		print("Year %d: signal %.3f, no signal %.3f, overall %.3f (curve %.3f)" % [year, signal_rate, quiet_rate, strikes / 12000.0, Climate.chance(year)])
	check(outcomes_match, "season starts honor every saved occurrence roll and event type")
	check(signals_match, "only drought, flood and storm produce their matching signal")
	for event in counts:
		check(absf(float(counts[event][1]) / counts[event][0] - 0.7) < 0.025, "seventy percent of actual " + event + " seasons are signalled")
		check(absf(float(counts[event][3]) / counts[event][2] - 0.1) < 0.025, "ten percent of calm potential " + event + " seasons give false alarms")
	for year in [1, 6, 10]:
		var strikes: int = 0
		for seed_value in range(2000):
			farm.climate.reset(); farm.rng.seed = seed_value + year * 2000
			farm.season_clock.year = year; farm.season_clock.season = 0
			farm.climate.start_season(farm)
			if farm.climate.data.phase == "warning": strikes += 1
		check(absf(strikes / 2000.0 - Climate.chance(year)) < 0.035, "sampled seasonal frequency follows year chance")
	var mix_ok: bool = true
	var cap_ok: bool = true
	var winter_seen: bool = false
	for seed_value in range(200):
		farm.climate.reset(); farm.rng.seed = seed_value
		for year in range(1, 11):
			farm.season_clock.year = year
			for season in range(4):
				farm.season_clock.season = season
				farm.climate.end_working_year()
				farm.climate.start_season(farm)
				var size_before: int = farm.climate.data.outlook.records.size()
				farm.climate.start_season(farm)
				cap_ok = cap_ok and size_before == farm.climate.data.outlook.records.size()
				if farm.climate.data.phase == "warning":
					mix_ok = mix_ok and farm.climate.data.event in Climate.SEASON_EVENTS[season]
					winter_seen = winter_seen or season == 3
			cap_ok = cap_ok and farm.climate.year_count(year) <= 3
	check(mix_ok and winter_seen, "natural warnings use the seasonal pools, including Winter")
	check(cap_ok, "one draw per season and at most three disasters per year")
	check(Climate.WARNING_SECONDS + Climate.ACTIVE_SECONDS + Climate.RECOVERY_SECONDS == 150, "weather phases still occupy the whole season")
	farm.climate.reset(); farm.season_clock.year = 1; farm.season_clock.season = 2
	farm.climate.prime_next(farm)
	farm.climate.data.outlook.next.fires = true
	for season in range(3): farm.climate.data.outlook.records.append({"year":1, "season":season, "event":Climate.SEASON_EVENTS[season][0], "severity":0.5})
	check(Protection.forecast(farm).chance == 0, "forecast still respects the annual cap")
	farm.season_clock.season = 3; farm.climate.start_season(farm)
	check(farm.climate.data.phase == "calm" and farm.climate.year_count(1) == 3, "annual cap overrides a saved true occurrence roll")
	farm.climate.data.outlook.next.fires = true
	farm.season_clock.year = 2; farm.season_clock.season = 0; farm.climate.start_season(farm)
	check(farm.climate.data.phase == "warning" and farm.climate.year_count(2) == 1, "new year can honor its saved occurrence after last year's cap")
	farm.climate.prime_next(farm)
	for level in range(3):
		farm.climate.data.protection.station = level
		farm.climate.data.outlook.next.fires = false
		var calm_forecast: Dictionary = Protection.forecast(farm)
		farm.climate.data.outlook.next.fires = true
		check(Protection.forecast(farm) == calm_forecast and is_equal_approx(calm_forecast.chance, Climate.chance(2)), "forecast at level %d reads curve, never the hidden occurrence roll" % level)
	var malformed: Dictionary = farm.climate.data.outlook.duplicate(true)
	malformed.next.erase("fires")
	check(not Climate.valid_outlook(malformed), "saved outlook requires its occurrence roll")
	malformed.next.fires = 1
	check(not Climate.valid_outlook(malformed), "saved occurrence roll must be boolean")
	farm.free()
	farm = fresh(); farm.rng.seed = 91
	farm.climate.start_season(farm)
	var outlook: String = JSON.stringify(farm.climate.data.outlook)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and JSON.parse_string(JSON.stringify(farm.climate.data.outlook)) == JSON.parse_string(outlook), "planned type, occurrence, signal, season draw and record persist")
	for fires in [false, true]:
		farm.climate.data.outlook.next.fires = fires
		var planned: Dictionary = farm.climate.data.outlook.next.duplicate()
		check(farm.save_game(SAVE) and farm.load_game(SAVE), "saved %s occurrence loads" % fires)
		farm.climate.end_working_year()
		farm.season_clock.year = int(planned.year); farm.season_clock.season = int(planned.season)
		# Unrelated random work cannot change an already planned outcome.
		for i in range(20): farm.rng.randf()
		farm.climate.start_season(farm)
		check((farm.climate.data.phase == "warning") == fires and (not fires or farm.climate.data.event == planned.event), "loaded occurrence survives unrelated RNG use without rerolling")
	var supply: Dictionary = Climate.Operations.local(farm)
	farm.climate.end_working_year(); farm.climate.data.outlook.signal = "drought"
	supply.water = 0; Climate.Operations.update(farm, 1)
	check(is_equal_approx(supply.water, 3), "dry precursor halves tank refill before the drought")
	farm.climate.data.outlook.signal = ""; supply.water = 0; Climate.Operations.update(farm, 1)
	check(is_equal_approx(supply.water, 6), "ordinary refill returns after precursor")
	farm.climate.reset(); farm.season_clock.year = 9; farm.season_clock.season = 3
	for level in range(3):
		farm.climate.data.protection.station = level
		var f: Dictionary = Protection.forecast(farm)
		check(f.year == 10 and f.season == 0 and is_equal_approx(f.chance, Climate.chance(10)), "Winter forecast reads next year's curve")
		for event in f.events:
			check(event in Climate.SEASON_EVENTS[0] and f.events[event].low <= f.chance/2 and f.events[event].high >= f.chance/2, "forecast event ranges bracket the matching seasonal probability")
	farm.free()
	for event in Climate.WINTER_LOSS:
		farm = fresh(); farm.rng.seed = 6
		Protection.insure(farm)
		farm.storage["russet"] = Stock.pile(100)
		farm.season_clock.season = 2; farm.season_clock.seconds = 149.75; farm.update(0.25)
		farm.climate.end_working_year()
		farm.storage["icecap"] = Stock.pile(12)# Fresh Winter harvest is not part of stored sacks.
		farm.plots[0].merge({"stage":2, "crop":"icecap", "tilled":true, "watered":true, "elapsed":50.0}, true)
		var empty: Dictionary = farm.plots[1].duplicate(true)
		var before: float = farm.coins
		check(farm.climate.begin_warning(farm, event, 1), "Winter warning begins")
		farm.climate.update(farm, 45)
		var barn_lost: int = roundi(95 * float(Climate.WINTER_LOSS[event]))
		var field_lost: int = roundi(3 * float(Climate.WINTER_LOSS[event]))
		check(Stock.count(farm.storage, "russet") == 95 - barn_lost and Stock.count(farm.trading.held, "russet") == Stock.count(farm.storage, "russet"), "Winter event removes and clamps actual stored sacks")
		check(Stock.count(farm.storage, "icecap") == 12, "Winter barn damage only hits stored sacks, not fresh harvests")
		check(Protection.remaining(farm.plots[0]) == 3 - field_lost and farm.plots[1] == empty, "Winter hits living Icecap and leaves empty beds untouched")
		check(is_equal_approx(farm.coins - before, (barn_lost * 15 + field_lost * 50) * 0.4), "annual insurance pays Winter barn and field loss exactly once")
		check(farm.save_game(SAVE) and farm.load_game(SAVE), "active Winter losses and insurance survive reload")
		before = farm.coins; farm.climate.update(farm, 0.25)
		check(farm.coins == before, "reload does not repeat impact or payout")
		farm.free()
	var spring: Dictionary = World.season_tints(1, 0)
	var summer: Dictionary = World.season_tints(1, 1)
	var autumn: Dictionary = World.season_tints(1, 2)
	var late: Dictionary = World.season_tints(6, 1)
	check(spring.grass != summer.grass and summer.grass != autumn.grass and spring.canopy != autumn.canopy, "three growing seasons have distinct grass and canopy palettes")
	check(spring.blossom == 1 and spring.flower == 1 and autumn.leaf == 1, "Spring blooms and Autumn path leaves follow the calendar")
	check(late.grass != summer.grass and late.haze > summer.haze, "year six Summer is visibly drier and hazier even in calm weather")
	await scene_checks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("CLIMATE CURVE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func scene_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	game.state.coins = 1000000
	game.world.set_calendar(1, 0, 149)
	game.world._process(1)
	var old_grass: Color = game.world._season_palette.grass
	var old_sky: Color = game.world._day_environment.background_color
	game.world.set_calendar(1, 1, 0)
	check(game.world._season_palette.grass == old_grass and game.world._day_environment.background_color == old_sky, "boundary starts from the existing grass and sky without a snap")
	game.world._process(0.5)
	check(game.world._season_palette.grass != old_grass and game.world._season_palette.grass != World.season_tints(1,1).grass, "halfway transition is between both seasonal palettes")
	game.world._process(0.5)
	check(game.world._season_blend == 1 and game.world._season_palette.grass == World.season_tints(1,1).grass, "crossfade finishes in one second")
	game.state.climate.data.outlook.records = [{"year":1,"season":0,"event":"flood","severity":0.5}]
	game._show_year_start()
	var seconds: float = game.state.season_clock.seconds
	game._process(1); game.state.update(1)
	check(game.year_intro.visible and game.year_intro.chapter.text.contains("YEAR 1") and game.state.season_clock.seconds == seconds, "year-start front page pauses farm time")
	check(game.year_intro.strip.records.size() == 1, "front page strip contains actual season history")
	game.year_intro.skip.pressed.emit()
	check(not game.state.climate_report_open and game.state.climate.data.outlook.seen_year == 1, "skip resumes play and records the seen year")
	game.hud.show_panel("accounts", game.state)
	var accounts_strip: Control
	for child in game.hud._body.get_children():
		if child.get_script() == preload("res://scripts/climate_strip.gd"): accounts_strip = child
	check(accounts_strip != null and accounts_strip.records == game.year_intro.strip.records, "Winter accounts share the actual ten-year disaster strip")
	game.hud.close_panel()
	game._show_year_start(); game.year_intro._process(12)
	check(not game.year_intro.visible and not game.state.climate_report_open, "annual page's inherited timed skip resumes the farm")
	for year in [1, 6]:
		for season in range(4):
			game.world.set_calendar(year, season, 85); game.world._process(1)
			if "--capture" in OS.get_cmdline_user_args():
				await create_timer(0.2).timeout
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://artifacts/climate-year%d-season%d.png" % [year,season])
	game._show_year_start()
	for size in [Vector2i(1280,800), Vector2i(390,844)]:
		root.size = size
		await create_timer(0.1).timeout
		root.content_scale_size = size
		await create_timer(0.1).timeout
		check(game.year_intro.strip.size.x <= game.year_intro.size.x and game.year_intro.chapter.size.x <= game.year_intro.size.x, "annual front page fits desktop and phone")
		if "--capture" in OS.get_cmdline_user_args():
			RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/climate-frontpage-%d.png" % size.x)
	game.year_intro.finish(); game.queue_free(); await process_frame; await create_timer(0.1).timeout
