extends SceneTree
## Real movement, input and island switching; never opens the player's save.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func finish_walk() -> void:
	var stays_walkable: bool = true
	for frame: int in range(800):
		game._process(0.04)
		var position: Vector3 = game.world.player.position
		stays_walkable = stays_walkable and position.distance_to(game._clamp_destination(position)) < 0.01
		if not game.walking:
			break
	check(not game.walking, "walk arrives without getting stuck")
	check(stays_walkable, "entire walk stays on the allowed land and path")

func screenshot(filename: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "capture " + filename)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to protect player saves")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for island: int in [1, 2, 3]:
		game.state.current_island = island
		game.state.island2_unlocked = island > 1
		game.state.island3_unlocked = island > 2
		game._on_island_changed(island)
		await physics_frame
		await physics_frame
		var spawn: Vector3 = game.world.player.position
		var boarding: Vector3 = game.world.ferry_position()
		check(game.world.has_node("FerryPath"), "island %d has a visible ferry path" % island)
		check(game._clamp_destination(boarding).is_equal_approx(boarding), "island %d boarding area is walkable" % island)
		check(game.world.station_position("island").is_equal_approx(boarding), "island %d guide points to its dock, not an offshore island" % island)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = game.world.camera.unproject_position(boarding + Vector3(0, 0.8, 0))
		check(game.world.pick(event.position).get("station", "") == "island", "island %d dock can be clicked" % island)
		game._unhandled_input(event)
		check(game.walking and game.pending_ferry and not game.hud.is_panel_open(), "clicking ferry walks over before opening travel")
		finish_walk()
		check(game.hud.is_panel_open() and game.world.player.position.distance_to(boarding) < 0.4, "arrival opens travel at the boarding area")
		game.hud.close_panel()
		game.world.set_day_time(0.0)
		game.hud.update_state(game.state)
		await screenshot("ferry-island-%d" % island)
		var interact := InputEventKey.new()
		interact.physical_keycode = KEY_E
		interact.pressed = true
		game._unhandled_input(interact)
		check(game.hud.is_panel_open(), "E at the ferry opens travel")
		game.hud.close_panel()
		game._cancel_walk()
		game._start_walk(spawn)
		finish_walk()
		check(game.world.player.position.distance_to(spawn) < 0.4 and not game.hud.is_panel_open(), "can walk back from ferry without reopening it")
		game.queue_ferry()
		Input.action_press("move_left")
		game._process(0.04)
		Input.action_release("move_left")
		check(not game.walking and not game.pending_ferry and game.walk_waypoints.is_empty(), "keyboard movement cancels queued ferry interaction")
		# Follow the same visible path using keyboard movement, including the old
		# Valley boundary and every bend. Camera-relative input matches WASD.
		game.world.set_player_position(spawn)
		var route: Array[Vector3] = game.world.walk_route(spawn, boarding, true)
		for waypoint: Vector3 in route:
			for frame: int in range(500):
				var direction: Vector3 = waypoint - game.world.player.position
				direction.y = 0
				if direction.length() < 0.12:
					break
				direction = direction.normalized()
				var right: Vector3 = game.world.camera.global_basis.x
				var forward: Vector3 = game.world.camera.global_basis.z
				right.y = 0
				forward.y = 0
				var x: float = direction.dot(right.normalized())
				var y: float = direction.dot(forward.normalized())
				Input.action_press("move_right" if x >= 0 else "move_left", absf(x))
				Input.action_press("move_down" if y >= 0 else "move_up", absf(y))
				game._process(0.012)
				for action: String in ["move_left", "move_right", "move_up", "move_down"]:
					Input.action_release(action)
		check(game.world.player.position.distance_to(boarding) < 0.2, "WASD can follow the entire ferry path")
		game._unhandled_input(interact)
		check(game.hud.is_panel_open(), "keyboard-only ferry visit works")
		if island == 1:
			game._on_action("travel:2")
			check(game.state.current_island == 1 and not game.state.island2_unlocked, "reaching dock cannot bypass island unlock")
		game.hud.close_panel()
	game.state.current_island = 1
	game._on_island_changed(1)
	check(game._clamp_destination(Vector3(-12, 0, -20)).z >= -5, "northern sea remains out of bounds away from path")
	check(game._clamp_destination(Vector3(11.5, 0, -50)).z >= -16.2, "cannot walk off the end of the boarding area")
	check(game._clamp_destination(Vector3(10, 0, -8)).distance_to(Vector3(10, 0, -8)) > 2, "path extension does not open a route through Roll House")
	game.tutorial.start()
	game.queue_ferry()
	check(not game.walking and not game.hud.is_panel_open(), "early tutorial still blocks ferry actions")
	game.state.tutorial_progress.step = 18
	game.tutorial._enter_step()
	game.world.set_player_position(Vector3(7, 0, -4.7))
	game.world.animate(0.1, false)
	for chevron: Node3D in game.world._tutorial_trail:
		check(chevron.visible, "ferry route arrows remain visible around bends")
		var ground := Vector3(chevron.position.x, 0, chevron.position.z)
		check(ground.distance_to(game._clamp_destination(ground)) < 0.02, "guide arrows stay on walkable path")
	await screenshot("ferry-tutorial-path")
	game.queue_ferry()
	finish_walk()
	check(game.tutorial.visited and game.hud.is_panel_open(), "tutorial ferry visit completes by actual walking")
	game.queue_free()
	await create_timer(0.4).timeout
	print("FERRY ACCESS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
