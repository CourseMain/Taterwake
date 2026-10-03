extends SceneTree
## Last-mile timing, real pace input, Winter resolution and playable feedback.
const State = preload("res://scripts/game_state.gd")
const Audio = preload("res://scripts/farm_audio.gd")
const Ambience = preload("res://scripts/farm_ambience.gd")
const Stock = preload("res://scripts/graded_stock.gd")
const SAVE: String = "user://feel-boundary-test-only.json"
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)

func settle() -> void:
	for frame in range(4): await process_frame

func prepare_winter(farm, seconds: float = 25.0) -> void:
	farm.tutorial_progress.completed = true
	farm.season_clock.year = 2
	farm.season_clock.season = 3
	farm.storage.russet = Stock.pile(30, 100)
	farm._season_boundary()
	farm.accounts_open = false
	farm.season_clock.seconds = seconds
	farm.climate.data.outlook.started = 7

func audio_checks() -> void:
	var unique: Dictionary = {}
	for stream in Ambience.STREAMS:
		check(stream.get_length() >= 2 and stream.get_length() <= 10 and stream.data.size() > 0, "short audible seasonal loop exists")
		unique[hash(stream.data)] = true
	check(unique.size() == 4, "birds, cicadas, wind and snow have distinct recordings")
	for kind in ["hoe", "plant", "water", "harvest", "pest", "paper", "foreclosure"]:
		check(Audio.CLIPS.has(kind) and Audio.CLIPS[kind].get_length() > 0, "prebuilt foley/cue present: " + kind)
	check(Audio.CLIPS.grade_table.data != Audio.CLIPS.grade_standard.data and Audio.CLIPS.grade_standard.data != Audio.CLIPS.grade_feed.data, "three distinct grade sounds")
	var ambience = game.seasonal_ambience
	ambience.set_process(false)
	ambience.set_season(0)
	ambience.advance(1.0)
	ambience.set_season(1)
	ambience.advance(.5)
	check(is_equal_approx(ambience.gains[0], .5) and is_equal_approx(ambience.gains[1], .5), "ambience crossfades at the half-second")
	ambience.advance(.499)
	check(ambience.gains[0] > 0, "ambience does not finish early")
	ambience.advance(.001)
	check(ambience.gains[0] == 0 and ambience.gains[1] == 1, "ambience finishes at exactly one second")
	check(is_instance_valid(game.climate_audio) and game.climate_audio.wind.stream != null and game.climate_audio.thunder.stream != null, "weather keeps its dedicated ClimateAudio channel")

func transition_checks() -> void:
	var world = game.world
	world.set_process(false)
	world.set_calendar(1, 0, 0)
	world._process(1)
	var snow_builds: int = world.visuals.snow_builds
	world.set_calendar(1, 3, 0)
	check(world.season_transition_info().progress == 0 and world.season_transition_info().duration == 1, "Winter boundary starts a one-second crossfade")
	world._process(.5)
	check(is_equal_approx(world.season_transition_info().progress, .5) and is_equal_approx(world.season_transition_info().snow, .5), "snow and calendar transition have a halfway state")
	world._process(.499)
	check(world.season_transition_info().active, "season fade does not end before one second")
	world._process(.001)
	check(not world.season_transition_info().active and world.season_transition_info().snow == 1, "season fade settles at one second")
	check(world.visuals.snow_builds == snow_builds, "Winter boundary reuses prebuilt snow")
	world.set_calendar(2, 0, 0)
	world._process(1)
	check(world.season_transition_info().snow == 0 and not world._winter_cover.visible, "Spring fades snow away completely")
	check(world.get_node_or_null("RedBarn/LedgerBook") != null, "accounts have a real book in Nell's barn")
	game.state.season_clock.season = 3
	game.state.tutorial_progress.completed = true
	game.hud.set_process(false)
	game.hud.show_panel("accounts", game.state)
	await settle()
	check(game.feedback_audio.last_cue == "paper", "accounts entrance plays paper foley")
	check(game.hud.panel_entrance_duration() == .6 and game.hud.panel_entrance_progress() == 0, "accounts begin their book slide")
	var origin: Vector2 = game.hud.ledger_screen_position() - game.hud._modal_card.get_global_rect().get_center()
	check(game.hud.panel_entrance_offset().is_equal_approx(origin), "accounts slide starts at the projected ledger book")
	var camera_size: float = world.camera.size
	game._process(.3)
	game.hud.advance_panel_entrance(.3)
	check(game.hud.panel_entrance_offset().length() < origin.length() and game.hud._modal_entrance_shield.visible, "moving accounts keep input shield until settled")
	check(world.camera.size < camera_size and world.camera.size > camera_size * .96, "accounts camera pushes in gently")
	game.hud.advance_panel_entrance(.299)
	check(game.hud._modal_entrance_shield.visible, "accounts slide does not finish early")
	game.hud.advance_panel_entrance(.001)
	check(game.hud.panel_entrance_offset() == Vector2.ZERO and not game.hud._modal_entrance_shield.visible, "accounts finish at .6 seconds with live input")
	game.hud.close_panel()
	game._process(.01)
	check(is_equal_approx(world.camera.size, game._zoom_target_size), "closing accounts restores the chosen camera zoom")
	game.year_intro.present(game.state)
	game.year_intro.set_process(false)
	check(game.year_intro.front_page_progress() == 0 and game.year_intro.modulate.a == 0, "newspaper begins transparent")
	game.year_intro._process(.3)
	check(is_equal_approx(game.year_intro.modulate.a, .5), "newspaper fades through its halfway point")
	game.year_intro._process(.3)
	check(game.year_intro.front_page_progress() == 1 and game.year_intro.modulate.a == 1, "newspaper fade finishes at .6 seconds")
	game.year_intro.finish()

func growth_checks() -> void:
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 6
	farm.climate.data.outlook.started = 0
	farm.interact_plot(5, "hoe")
	farm.interact_plot(5, "plant")
	farm.plots[5].pest_checked = true
	farm.update(10)
	check(is_equal_approx(farm.plots[5].elapsed, 4.0) and not farm.plots[5].watered, "dry bed grows at exactly forty percent")
	check(farm._valid_save(JSON.parse_string(JSON.stringify(farm._save_data()))), "part-grown dry bed round-trips through save validation")
	farm.interact_plot(5, "water")
	farm.update(10)
	check(is_equal_approx(farm.plots[5].elapsed, 14), "watering restores full growth without resetting progress")
	farm.free()
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.interact_plot(5, "hoe")
	game.state.interact_plot(5, "plant")
	game._on_state_changed()
	check(5 in game.world.visuals.dry_beds, "thirsty bed has a pooled droplet marker")
	var point: Vector2 = game.world.camera.unproject_position(game.world.plot_positions[5]) * game.hud.root.size / Vector2(game.farm_viewport.size)
	game._update_hover_at(point)
	check(game.hud._context.text.begins_with("Needs water · growth paused"), "hover names the waiting-for-water state")

func pace_checks() -> void:
	game.hud.close_panel()
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.climate.data.outlook.started = 0
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	key.pressed = true
	game._unhandled_input(key)
	check(InputMap.action_has_event("hurry", key) and not game.hud.is_panel_open(), "physical H is reserved for hurry without opening help")
	Input.action_press("hurry")
	var before: float = game.state.elapsed
	game._process(1)
	check(is_equal_approx(game.state.elapsed - before, 3) and game.hurry_active, "holding H advances three simulation seconds per real second")
	Input.action_release("hurry")
	before = game.state.elapsed
	game._process(1)
	check(is_equal_approx(game.state.elapsed - before, 1) and not game.hurry_active, "releasing H immediately restores normal time")
	Input.action_press("hurry")
	game.state.season_clock.season = 3
	game.hud.show_panel("accounts", game.state)
	before = game.state.elapsed
	game._process(1)
	check(game.state.elapsed == before and not game.hurry_active, "held H cannot advance accounts")
	game.hud.close_panel()
	game._start_conversation("mara")
	game._process(1)
	check(game.state.elapsed == before and not game.hurry_active, "held H cannot advance a conversation")
	game.conversation.finish()
	game.hud.show_panel("loss_notices", game.state)
	check(game._simulation_delta(1) == 1, "held H cannot accelerate a cause card")
	game.hud.close_panel()
	game.state.reset_game()
	game.tutorial.start()
	game.state.tutorial_progress.step = 5
	game.state.interact_plot(5, "hoe")
	game.state.interact_plot(5, "plant")
	game.state.interact_plot(5, "water")
	check(game._simulation_delta(1) == 10, "guide wait is capped at ten and ignores H")
	game._process(1000)
	check(game.state.season_clock.season == 1 and game.state.tutorial_loss().is_empty(), "accelerated Spring stops before the storm warning")
	check(game._simulation_delta(1) == 1 and game.state.climate.data.phase == "warning", "storm warning switches the guide to one-times speed")
	game._process(7)
	check(game.state.tutorial_loss().is_empty(), "the warning gets its real eight seconds")
	game._process(1)
	check(game.tutorial.current_id() == "loss" and game._simulation_delta(1) == 1, "cause card retains one-times scale and pauses reading")
	Input.action_release("hurry")
	game.tutorial.finish()
	game.hud.close_panel()
	game.state.climate.reset()
	game.state.season_clock.season = 1
	game.state.climate.begin_warning(game.state, "storm", 1)
	game.state.climate._impact(game.state)
	var shake_peak := Vector2.ZERO
	for frame in range(180):
		game.climate_shake = .22
		game._update_weather_shake(1.0 / 60.0)
		shake_peak.x = maxf(shake_peak.x, absf(game.world.camera.h_offset))
		shake_peak.y = maxf(shake_peak.y, absf(game.world.camera.v_offset))
	check(shake_peak.x <= .26 and shake_peak.y <= .156, "storm camera shake stays bounded across gusts")
	game.state.climate.reset()
	game.climate_shake = 0
	game._update_weather_shake(1)

func sleep_checks() -> void:
	var farm = State.new()
	root.add_child(farm)
	prepare_winter(farm, 149)
	farm.boundary_save_path = SAVE
	var quote: Dictionary = farm.winter_sleep_quote()
	check(quote.tonnes == 28 and is_equal_approx(quote.peak_value, 28 * farm.trading.peak_price("russet", "Table")), "sleep quote uses tonnes and actual stored grades after spoilage")
	check(farm.climate.begin_warning(farm, "blizzard", 1), "late Winter blizzard fixture begins")
	var saved_boundary: Array = []
	farm.season_changed.connect(func():
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		saved_boundary.append(data.season_clock)
		check(farm.climate.data.phase == "calm", "weather resolves before the sleep boundary")
		check(farm._valid_save(data), "sleep uses the complete normal boundary save"))
	for step in range(1200):
		if farm.winter_sleep_step(3): break
	check(farm.season_clock.year == 3 and farm.season_clock.season == 0 and farm.season_clock.seconds == 0, "sleep lands exactly at Spring dawn")
	check(saved_boundary.size() == 1, "sleep emits and saves only one season boundary")
	check(Stock.count(farm.storage, "russet") == 20 and Stock.count(farm.trading.held, "russet") == 0, "blizzard losses apply and surviving stored sacks return unsold")
	check(farm.ledger.total(2, "sales") == 0, "sleep never creates an automatic sale")
	check(farm.last_save_ms > 0, "boundary save exposes measured main-thread duration")
	farm.season_clock.year = 10
	farm.season_clock.season = 3
	check(not farm.can_sleep_until_spring(), "last Winter cannot invent an eleventh Spring")
	farm.free()
	game.state.reset_game()
	prepare_winter(game.state)
	game.hud.close_panel()
	game._on_state_changed()
	check(game.hud._season_jobs.sleep_button.visible, "Winter jobs offer sleep outside the work count")
	game._on_action("menu")
	check(game.hud._body.find_children("MenuSleepUntilSpring", "Button", true, false).size() == 1, "farm menu offers the same sleep action")
	game.hud._act("sleep_spring")
	check(game.hud._panel_kind == "sleep_confirm" and game.hud._refs.sleep_quote.text.contains("28 t") and game.hud._refs.sleep_quote.text.contains(game.state.money(game.state.winter_sleep_quote().peak_value)), "confirmation states stored tonnes and late Winter value")
	var clock: Dictionary = game.state.season_clock.save_data()
	game._on_action("close")
	check(game.state.season_clock.save_data() == clock and not game.sleeping_until_spring, "cancel sleep changes no farm time")
	game._on_action("sleep_spring")
	game._on_action("confirm_sleep_spring")
	check(game.sleeping_until_spring and not game.hud.is_panel_open(), "confirmation starts the budgeted sleep")
	for frame in range(30):
		game._process(1.0 / 60.0)
		if not game.sleeping_until_spring: break
	check(not game.sleeping_until_spring and game.state.season_clock.season == 0 and game.state.season_clock.year == 3, "budgeted scene sleep finishes at Spring")

func touch_checks() -> void:
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.climate.data.outlook.started = 0
	game.hud.close_panel()
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(390, 844)
	game.touch_controls.enabled = true
	game.touch_controls._build_touch_sheets()
	game.touch_controls.resize()
	await settle()
	var touch = game.touch_controls
	touch._process(.2)
	var physical_scale: float = float(root.size.x) / game.hud.root.size.x
	check(touch.hurry_button.size.x * physical_scale >= 44 and touch.hurry_button.size.y * physical_scale >= 44, "touch hurry has a physical forty-four-pixel target")
	var down := InputEventScreenTouch.new()
	down.index = 12
	down.pressed = true
	down.position = touch.hurry_button.get_global_rect().get_center()
	touch._input(down)
	check(touch.hurry_held, "touch hurry starts on finger down")
	var before: float = game.state.elapsed
	game._process(1)
	check(is_equal_approx(game.state.elapsed - before, 3), "touch hold uses the same three-times simulation")
	var drag := InputEventScreenDrag.new()
	drag.index = 12
	drag.position = Vector2.ZERO
	touch._input(drag)
	check(not touch.hurry_held, "dragging off hurry releases its hold")
	down.pressed = false
	down.canceled = true
	touch._input(down)
	check(not touch.hurry_held and not touch.button_fingers.has(12), "cancelled touch cannot leave hurry latched")
	touch.update_interaction_prompt()
	var scans: int = touch.interaction_scans
	for frame in range(60): touch._process(1.0 / 60.0)
	check(touch.interaction_scans - scans <= 11, "station discovery stays near ten scans per second when idle")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/feel-phone-controls.png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.tutorial_progress.completed = true
	audio_checks()
	await transition_checks()
	growth_checks()
	pace_checks()
	sleep_checks()
	await touch_checks()
	Input.action_release("hurry")
	game.queue_free()
	await process_frame
	await create_timer(.3).timeout
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("FEEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
