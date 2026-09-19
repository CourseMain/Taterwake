extends SceneTree
## The real gate, input paths and scaled simulation run without player save I/O.
const SAVE: String = "user://spud_debug_access_time_test_only.json"
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(label: String) -> void:
	if not capture:
		return
	game.hud._toast_box.hide()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/debug-access-" + label + ".png") == OK, "capture " + label)

func click_button(button: Button) -> void:
	await process_frame
	await process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)
	await process_frame

func enter_code(value: String) -> void:
	game.hud._refs.debug_code.text = value
	game.hud._refs.debug_code.grab_focus()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	root.push_input(enter)
	await process_frame

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 1000.0
	game.state.apply_debug(1.0, 10.0)
	game._on_action("debug")
	check(not game.debug_unlocked and game.debug_time_multiplier == 1.0, "session starts locked at normal speed despite saved debug effects")
	check(game.hud._refs.has("debug_code") and not game.hud._refs.has("debug_apply") and game.hud._refs.debug_code.secret, "locked page only exposes a masked access field")
	await shot("locked")
	for action: String in ["debug:apply:100:100", "debug:reset", "debug:time:30"]:
		game._on_action(action)
		game.hud._act(action)
	game.hud._act("debug_apply")
	game.hud._act("debug_money:100")
	check(game.state.coins == 1000.0 and game.state.debug_luck_multiplier == 10.0 and game.debug_time_multiplier == 1.0, "controller and HUD both reject locked debug mutations")
	await enter_code("wrong:code")
	check(not game.debug_unlocked and game.hud._refs.debug_access_error.text == "Incorrect code." and game.hud._refs.debug_code.text.is_empty(), "Enter rejects wrong code inline and clears the field")
	await shot("wrong-code")
	game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
	await click_button(game.hud._refs.debug_unlock)
	check(game.debug_unlocked and game.hud._refs.has("debug_apply") and not game.hud._refs.has("debug_code"), "mouse unlocks the real controls with the exact code")
	game.hud.close_panel()
	game._on_action("debug")
	check(game.hud._refs.has("debug_apply"), "session stays unlocked when the page is reopened")
	for speed: int in [2, 5, 10, 30, 1]:
		await click_button(game.hud._refs["debug_time_%d" % speed])
		check(game.debug_time_multiplier == speed and game.hud._refs["debug_time_%d" % speed].disabled, "%dx selected speed is shown by the active button" % speed)
		var elapsed: float = game.state.elapsed
		game._process(0.02)
		check(is_equal_approx(game.state.elapsed - elapsed, 0.02 * speed), "%dx advances simulation by the selected multiplier" % speed)
	for invalid: String in ["0", "-1", "3", "31", "inf", "nan", "bad"]:
		game._on_action("debug:time:" + invalid)
		check(game.debug_time_multiplier == 1.0, "unsupported speed rejected: " + invalid)
	game._on_action("debug:time:30")
	await shot("unlocked-time")
	(game.hud._body.get_parent() as ScrollContainer).scroll_vertical = 450
	await shot("unlocked-actions")
	check(game.state.save_game(SAVE), "debug effects can save without storing the session gate")
	game.state.surge_timer = 0.05
	game.state.surge_remaining = 0.0
	var before: float = game.state.elapsed
	game._process(50.0)
	check(is_equal_approx(game.state.elapsed - before, 1.0) and game.state.surge_remaining > 9.0, "large accelerated frame cannot skip a ten-second stock boom")
	check(game.hud._export_bar.max_value == 10.0, "stock HUD displays the complete ten-second range")
	game.state.current_event = ""
	game.state._event_in = 100.0
	game.builds.fertilizer = 0.1
	var fertilized: Dictionary = game.state.plots[0]
	fertilized.crop = "russet"
	fertilized.stage = 2
	fertilized.elapsed = 0.0
	fertilized.watered = true
	before = game.state.elapsed
	game._process(1.0)
	check(is_equal_approx(game.state.elapsed - before, 1.0) and is_equal_approx(float(fertilized.elapsed), 1.02) and game.builds.fertilizer == 0.0, "fertilizer expiry splits crop growth without discarding accelerated time")
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	game.state.travel_to(3)
	game.state.surge_remaining = 0.0
	game.state.rocket_timer = 100.0
	game.state.pest_timer = 100.0
	game.state.frost_timer = 100.0
	game.state.export_timer = 100.0
	game.state._event_in = 100.0
	game.activities.furnace_remaining = 0.15
	game.activities.furnace_cooldown = 50.0
	game.builds.cooldown = 50.0
	game.builds.fertilizer = 50.0
	game.builds.processing = {"crop": "icecap", "quantity": 100, "elapsed": 0.0, "duration": 10.0, "multiplier": 1.2}
	var plot: Dictionary = game.state.plots[0]
	plot.unlocked = true
	plot.tilled = true
	plot.stage = 2
	plot.crop = "icecap"
	plot.watered = true
	plot.frozen = false
	plot.elapsed = 0.0
	game._process(0.01)
	check(is_equal_approx(game.state.pest_timer, 99.7) and is_equal_approx(game.state.frost_timer, 99.7) and is_equal_approx(game.state.export_timer, 99.7), "pest, winter and export clocks use the same scaled interval")
	check(is_equal_approx(game.activities.furnace_cooldown, 49.7) and is_equal_approx(game.builds.cooldown, 49.7) and is_equal_approx(game.builds.fertilizer, 49.7), "activities and build abilities share simulation time")
	check(is_equal_approx(float(game.builds.processing.elapsed), 0.6), "processing integrates furnace heat before the scaled interval consumes it")
	check(float(plot.elapsed) > 0.3, "crop growth uses scaled time and its active furnace bonus")
	game.hud.close_panel()
	game.world.set_player_position(Vector3(0.0, 0.0, 9.0))
	game.destination = Vector3(5.0, 0.0, 9.0)
	game.walking = true
	var position: Vector3 = game.world.player.position
	var clock: float = game.stock_shake_clock
	game._process(0.01)
	check(is_equal_approx(position.distance_to(game.world.player.position), game.WALK_SPEED * 0.01), "walking uses real time at thirty-times simulation speed")
	check(is_equal_approx(game.stock_shake_clock - clock, 0.01) and Engine.time_scale == 1.0, "camera and global presentation time remain real time")
	game.state.rocket_timer = 0.05
	before = game.state.elapsed
	var cooldown: float = game.builds.cooldown
	var frost: float = game.state.frost_timer
	var export_wait: float = game.state.export_timer
	game._process(1.0)
	game.rocket_cutscene.set_process(false)
	check(game.state.rocket_pending and game.rocket_cutscene.active and is_equal_approx(game.state.elapsed - before, 0.05), "thirty-times high-delta frame stops exactly at rocket launch")
	check(is_equal_approx(cooldown - game.builds.cooldown, 0.05), "builds consume only the interval before cinematic pause")
	check(is_equal_approx(frost - game.state.frost_timer, 0.05) and is_equal_approx(export_wait - game.state.export_timer, 0.05), "winter and export timers finish the same pre-launch interval")
	before = game.state.elapsed
	cooldown = game.builds.cooldown
	game._process(5.0)
	check(game.state.elapsed == before and game.builds.cooldown == cooldown, "all simulation stops during cinematic despite accelerated debug time")
	game.rocket_cutscene._process(0.1)
	check(is_equal_approx(game.rocket_cutscene.elapsed, 0.1), "cinematic advances by real seconds")
	game.rocket_cutscene._process(game.rocket_cutscene.DURATION - 0.1)
	check(game.state.surge_remaining == 10.0 and not game.state.rocket_pending, "cinematic hands off a full ten simulation seconds without consuming overshoot")
	game._process(0.01)
	check(is_equal_approx(game.state.surge_remaining, 9.7), "post-launch selling time follows the selected simulation speed")
	game.state.rocket_timer = 0.000001
	before = game.state.elapsed
	cooldown = game.builds.cooldown
	game._process(0.01)
	game.rocket_cutscene.set_process(false)
	check(game.state.rocket_pending and game.rocket_cutscene.active and game.state.elapsed > before, "minimum valid rocket timer cannot freeze the simulation")
	check(is_equal_approx(game.state.elapsed - before, cooldown - game.builds.cooldown), "epsilon rocket boundary keeps build and farm consumption coherent")
	game.rocket_cutscene._process(game.rocket_cutscene.DURATION)
	game._on_action("debug:lock")
	check(not game.debug_unlocked and game.debug_time_multiplier == 1.0 and game.state.debug_luck_multiplier == 10.0, "locking restores real-time speed while preserving saved money and luck effects")
	game._on_action("debug")
	await enter_code("ORIGINALLYSPUDREPUBLIC")
	check(game.debug_unlocked, "Enter also accepts the correct code")
	game._on_action("debug:time:5")
	game.hud._refs.debug_reset.pressed.emit()
	check(game.state.debug_luck_multiplier == 1.0 and game.debug_time_multiplier == 1.0 and game.state.coins == 1000.0, "reset restores luck and time while keeping money")
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.state.load_game(SAVE), "saved debug effects load into a new session")
	game._on_action("debug")
	check(not game.debug_unlocked and game.debug_time_multiplier == 1.0 and game.hud._refs.has("debug_code") and game.state.debug_luck_multiplier == 10.0, "reloading saved effects still requires the code in a fresh session")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("DEBUG ACCESS AND TIME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
