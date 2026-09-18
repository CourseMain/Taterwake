extends SceneTree
## Exercise real map input paths without loading or saving a player's farm.
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

func wheel(button: int, factor: float = 1.0, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.factor = factor
	event.pressed = pressed
	return event

func pan(amount: Vector2) -> InputEventPanGesture:
	var event := InputEventPanGesture.new()
	event.delta = amount
	return event

func pinch(factor: float) -> InputEventMagnifyGesture:
	var event := InputEventMagnifyGesture.new()
	event.factor = factor
	return event

func settle(seconds: float = 1.0, fps: int = 60) -> void:
	for _frame in range(int(seconds * fps)):
		game._update_camera_zoom(1.0 / fps)

func reset_zoom() -> void:
	game.world.camera.size = 38.0
	game._reset_camera_zoom()

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to protect player saves.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	reset_zoom()
	game._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP))
	check(game._zoom_target_size < 38.0 and game.world.camera.size == 38.0, "wheel requests zoom without jumping the rendered camera")
	game._update_camera_zoom(1.0 / 60.0)
	check(game.world.camera.size < 38.0 and game.world.camera.size > game._zoom_target_size, "camera smoothly follows the requested zoom")
	settle()
	check(absf(game.world.camera.size - game._zoom_target_size) < 0.001, "camera settles at its requested zoom")
	var whole_step: float = 38.0 - game._zoom_target_size
	reset_zoom()
	game._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP, 0.1))
	check(38.0 - game._zoom_target_size < whole_step * 0.2, "high-resolution trackpad wheel fractions remain small and precise")
	reset_zoom()
	game._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.0))
	check(game._zoom_target_size > 38.0, "older mice without a scroll factor retain wheel zoom")
	reset_zoom()
	game._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, false))
	game._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_LEFT))
	game._unhandled_input(pan(Vector2(5, 0)))
	check(game._zoom_target_size == 38.0, "releases and horizontal-only scrolling never change zoom")
	game._unhandled_input(pan(Vector2(0, -0.6)))
	check(game._zoom_target_size < 38.0, "native two-finger upward scroll zooms in")
	game._unhandled_input(pan(Vector2(0, 0.6)))
	check(is_equal_approx(game._zoom_target_size, 38.0), "native two-finger scrolling works in both directions")
	game._unhandled_input(pinch(1.25))
	check(is_equal_approx(game._zoom_target_size, 38.0 / 1.25), "spreading a native pinch magnifies the map proportionally")
	game._unhandled_input(pinch(0.8))
	check(is_equal_approx(game._zoom_target_size, 38.0), "closing a pinch zooms out proportionally")
	var before: float = game._zoom_target_size
	for event: InputEvent in [pinch(0.0), pinch(-1.0), pinch(NAN), pan(Vector2(0, INF)), wheel(MOUSE_BUTTON_WHEEL_UP, NAN)]:
		game._unhandled_input(event)
	check(game._zoom_target_size == before, "invalid gesture values cannot corrupt the camera")
	game.hud.show_panel("inventory", game.state)
	for event: InputEvent in [pinch(1.5), pan(Vector2(0, 3)), wheel(MOUSE_BUTTON_WHEEL_DOWN)]:
		game._unhandled_input(event)
	check(game._zoom_target_size == before, "inventory scroll and portrait gestures cannot zoom the map behind a menu")
	game.hud.close_panel()
	var positions: Array[float] = []
	for fps: int in [30, 60, 120]:
		reset_zoom()
		game._unhandled_input(pinch(1.5))
		settle(0.5, fps)
		positions.append(game.world.camera.size)
	check(absf(positions[0] - positions[2]) < 0.0001, "zoom smoothing reaches the same view at 30 and 120 FPS")
	for island: int in [1, 2, 3]:
		game.state.current_island = island
		game.state.island2_unlocked = island >= 2
		game.state.island3_unlocked = island >= 3
		game._on_island_changed(island)
		check(is_equal_approx(game._zoom_target_size, game.world.camera.size), "island %d resets the zoom target to its new camera" % island)
		game._unhandled_input(pinch(1000000.0))
		settle()
		check(is_equal_approx(game.world.camera.size, 18.0), "island %d enforces a useful close-up limit" % island)
		game._unhandled_input(pan(Vector2(0, 1000000.0)))
		settle()
		check(is_equal_approx(game.world.camera.size, float([56, 64, 74][island - 1])), "island %d can zoom out farther to expose buildings" % island)
		await physics_frame
		await physics_frame
		var barn: Vector3 = [Vector3(-12, 2, -8), Vector3(-15, 2, -10), Vector3(-18, 2, -12)][island - 1]
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(barn))
		check(str(hit.get("station", "")) == "barn", "island %d barn remains clickable after zooming out" % island)
	game.queue_free()
	await process_frame
	print("MAP ZOOM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
