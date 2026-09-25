extends SceneTree
## Exercises real press/release dispatch while the HUD continues refreshing.
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func frames(count: int = 6) -> void:
	for _i in range(count): await process_frame
func click(button: Button, refreshes: int = 4) -> void:
	await frames()
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(2)
	check(button.button_pressed, "mouse press reaches " + button.text)
	for _i in range(refreshes):
		game.hud.update_state(game.state)
		await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames()
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.state.debug_unlock_island(3)
	game.state.travel_to(2)
	game.hud.close_panel()
	var card = game.hud._climate_console
	await click(card.primary)
	check(game.state.climate.data.lesson.stage == "water", "held click starts practice across HUD refreshes")
	if game.state.climate.data.lesson.stage == "water":
		game.perform_plot(34, "water")
		await click(card.primary)
		check(card.equipment == "sprinkler2", "held click shows connected near sprinkler")
		await click(card.primary)
		check(game.state.climate.data.lesson.stage == "success", "held click waters the practice patch")
	game.state.climate.data.lesson.stage = "offer"
	game._close_equipment()
	game.hud.update_state(game.state)
	await click(card.secondary)
	check(game.state.climate.data.lesson.stage == "done", "held click dismisses invitation")
	# Speed and animation checks use fixed real-time steps; simulation stays isolated.
	game.set_process(false)
	game._close_equipment()
	game.state.travel_to(1)
	game.hud.close_panel()
	var world = game.world
	var loop = world._climate_field.loop
	check(is_equal_approx(world.farm_bounds().get_area() / (35.0 * 17.0), 1.5), "land footprint grows by 50 percent")
	check(world.plot_positions.size() == 24 and world.plot_positions[0] == Vector3(-7.5, 0, -2), "saved bed count and coordinates remain unchanged")
	var distances: Array[float] = []
	for sprint in [false, true]:
		game._cancel_walk()
		world.set_player_position(Vector3.ZERO)
		Input.action_press("move_right")
		if sprint: Input.action_press("sprint")
		for _i in range(60): game._process(1.0 / 60.0)
		distances.append(world.player.position.length())
		Input.action_release("move_right")
		Input.action_release("sprint")
	check(distances[1] > distances[0] * 1.5 and distances[1] < distances[0] * 1.7, "Shift provides an eased 1.65x keyboard sprint")
	check(world._player_body._run_blend > 0.9, "running changes the farmer stride")
	game._cancel_walk()
	world.set_player_position(Vector3.ZERO)
	game._start_walk(Vector3(10, 0, 0))
	Input.action_press("sprint")
	for _i in range(180): game._process(1.0 / 60.0)
	Input.action_release("sprint")
	check(not game.walking and world.player.position.is_equal_approx(Vector3(10, 0, 0)), "sprint click-walking arrives exactly without overshoot")
	game.hud.show_panel("help", game.state)
	var stopped: Vector3 = world.player.position
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _i in range(20): game._process(1.0 / 60.0)
	Input.action_release("move_right")
	Input.action_release("sprint")
	check(world.player.position == stopped, "open menus prevent sprint movement")
	game.hud.close_panel()
	world.set_player_position(Vector3.ZERO)
	for _i in range(60):
		world.animate(1.0 / 60.0, false)
		loop.animate(game.state.climate_info(), 1.0 / 60.0)
	var offset: Vector3 = world.player.to_local(loop.can.position)
	world._player_heading += PI
	for _i in range(90):
		world.animate(1.0 / 60.0, false)
		loop.animate(game.state.climate_info(), 1.0 / 60.0)
	check(world.player.to_local(loop.can.position).distance_to(offset) < 0.12, "can turns with the farmer and remains beside the same hand")
	world.play_farm_effect([0], "water")
	var pour_peak: float = 0.0
	for _i in range(60):
		world.animate(1.0 / 60.0, false)
		loop.animate(game.state.climate_info(), 1.0 / 60.0)
		pour_peak = maxf(pour_peak, loop.pour_blend)
	check(pour_peak > 0.65 and loop.pour_blend < 0.01 and loop.can.visible and not world._tool.visible, "one persistent can eases through pouring and back to rest")
	world.set_player_position(loop.tank_position() + Vector3(-0.4, 0, 2.3))
	for _i in range(30):
		world.animate(1.0 / 60.0, false)
		loop.animate(game.state.climate_info(), 1.0 / 60.0)
	loop.refill_time = 1.6
	var largest_step: float = 0.0
	for _i in range(150):
		var before: Vector3 = loop.can.position
		world.animate(1.0 / 60.0, false)
		loop.animate(game.state.climate_info(), 1.0 / 60.0)
		largest_step = maxf(largest_step, before.distance_to(loop.can.position))
	check(largest_step < 0.30 and loop.refill_blend < 0.01, "refill reaches the tap and returns without teleporting the can")
	print("FARM INTERACTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
