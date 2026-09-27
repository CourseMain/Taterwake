extends SceneTree
## Real mouse/touch events exercise the camera without touching player saves.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func mouse_button(button: int, pressed: bool, point := Vector2(600, 350)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	root.push_input(event, true)

func settle_pan() -> void:
	for i in range(60): game._update_camera_pan(1.0 / 60.0)

func mouse_drag(delta: Vector2, button: int = MOUSE_BUTTON_RIGHT) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.position = Vector2(600, 350) + delta
	event.button_mask = 1 << (button - 1)
	root.push_input(event, true)
	settle_pan()

func home() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_HOME
	event.pressed = true
	root.push_input(event, true)

func finger(id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func drag(id: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = point
	root.push_input(event, true)
	settle_pan()

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(8): await process_frame
	await physics_frame
	game.set_process(false)
	game._cancel_walk()
	var camera: Camera3D = game.world.camera
	var original: Transform3D = camera.global_transform
	var player: Vector3 = game.world.player.position
	var plot: Vector3 = game.world.plot_positions[4]
	var before: Vector2 = camera.unproject_position(plot)
	game._pan_camera_by(Vector2(100, 50))
	check(camera.global_position == original.origin, "drag input never teleports the rendered camera")
	var destination: Vector3 = game._camera_home_position + game._camera_pan_offset
	game._update_camera_pan(1.0 / 60.0)
	check(camera.global_position != original.origin and camera.global_position.distance_to(destination) > 0.1, "first rendered frame moves only partway toward the drag target")
	var remaining: float = camera.global_position.distance_to(destination)
	var smooth := true
	for i in range(30):
		game._update_camera_pan(1.0 / 60.0)
		var next: float = camera.global_position.distance_to(destination)
		smooth = smooth and next <= remaining
		remaining = next
	check(smooth and remaining < 0.001, "camera eases continuously to release without overshoot")
	home()
	var screen_delta := Vector2(85, 40)
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	check(game._map_drag_button == MOUSE_BUTTON_RIGHT, "right mouse starts camera drag through the real input pipeline")
	mouse_drag(screen_delta)
	var projected_delta: Vector2 = (camera.unproject_position(plot) - before) * root.get_visible_rect().size / Vector2(game.farm_viewport.size)
	check(projected_delta.distance_to(screen_delta) < 0.01, "map follows pointer in both axes at the farm render resolution")
	check(camera.global_basis.is_equal_approx(original.basis) and is_equal_approx(camera.global_position.y, original.origin.y), "pan retains the angled view and camera height")
	mouse_button(MOUSE_BUTTON_LEFT, true)
	mouse_button(MOUSE_BUTTON_LEFT, false)
	check(not game.walking and game.pending_plot == -1 and game.world.player.position == player and not game.hud.is_panel_open(), "a second mouse button during a pan cannot farm, walk, or open a shop")
	mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(1250, 25))
	check(game._map_drag_button == 0, "releasing over a HUD control ends the drag")
	var stopped: Vector3 = camera.global_position
	mouse_drag(Vector2(100, 0))
	check(camera.global_position == stopped, "motion after release cannot keep panning")
	home()
	check(camera.global_transform.is_equal_approx(original), "Home restores the original island view")
	mouse_button(MOUSE_BUTTON_LEFT, true)
	check(not game.walking and game.pending_plot == -1, "left press waits to distinguish a tap from a pan")
	mouse_drag(Vector2(90, 40), MOUSE_BUTTON_LEFT)
	mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(690, 390))
	check(camera.global_position != original.origin and not game.walking and game.pending_plot == -1, "left drag pans without farming or walking")
	home()
	mouse_button(MOUSE_BUTTON_LEFT, true)
	# Embedded/native input can omit a held-button mask on a motion event.
	# Ownership belongs to the press/release pair, including pauses and reversals.
	for delta in [Vector2(18, 7), Vector2.ZERO, Vector2(24, 11), Vector2(-12, -6)]:
		var held_motion := InputEventMouseMotion.new()
		held_motion.relative = delta
		held_motion.position = Vector2(600, 350) + delta
		var prior: Vector3 = game._camera_pan_offset
		root.push_input(held_motion, true)
		check(game._map_drag_button == MOUSE_BUTTON_LEFT, "held drag survives a motion event without a button mask")
		check(delta == Vector2.ZERO or game._camera_pan_offset != prior, "held drag continues moving without another press")
		settle_pan()
	mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640, 370))
	check(game._map_drag_button == 0 and not game.walking and game.pending_plot == -1, "explicit release ends a maskless drag without a farm tap")
	home()
	await physics_frame
	# Find a genuinely empty ground target rather than assuming screen coordinates.
	var found_ground := false
	for x in range(200, 1000, 30):
		var point := Vector2(x, 580)
		var hit: Dictionary = game.world.pick(game.farm_viewport.to_farm_position(point))
		if hit.has("ground") and not hit.has("plot_index") and not hit.has("station"):
			mouse_button(MOUSE_BUTTON_LEFT, true, point)
			mouse_button(MOUSE_BUTTON_LEFT, false, point)
			found_ground = true
			break
	check(found_ground and not game.walking, "clicking empty island ground does not move the farmer")
	mouse_button(MOUSE_BUTTON_MIDDLE, true)
	mouse_drag(Vector2(-40, -30), MOUSE_BUTTON_MIDDLE)
	check(camera.global_position != original.origin, "middle drag also pans")
	mouse_button(MOUSE_BUTTON_MIDDLE, false)
	var target_zoom: float = game._zoom_target_size
	var scroll := InputEventPanGesture.new()
	scroll.delta = Vector2(2, -1)
	stopped = camera.global_position
	game._unhandled_input(scroll)
	settle_pan()
	check(camera.global_position != stopped and game._zoom_target_size == target_zoom, "two-finger trackpad scrolling pans instead of changing zoom")
	game._pan_camera_by(Vector2(1e8, -1e8))
	var limit: Vector2 = game._camera_pan_limit()
	check(absf(game._camera_pan_offset.x) <= limit.x and absf(game._camera_pan_offset.z) <= limit.y, "large drags stop at the island bounds")
	stopped = camera.global_position
	game._pan_camera_by(Vector2(NAN, INF))
	check(camera.global_position == stopped, "invalid motion cannot corrupt the camera")
	game._zoom_by_log_amount(-1.5)
	home()
	check(game._zoom_target_size == game._camera_home_size, "recenter also returns to the useful overview zoom")
	game.hud.show_panel("inventory", game.state)
	stopped = camera.global_position
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	mouse_drag(Vector2(80, 20))
	game._unhandled_input(scroll)
	settle_pan()
	check(game._map_drag_button == 0 and camera.global_position == stopped, "an open menu prevents drag and trackpad movement behind it")
	game.hud.close_panel()
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	game.hud.show_panel("inventory", game.state)
	game._update_camera_zoom(0.01)
	check(game._map_drag_button == 0, "opening a menu cancels an active camera drag")
	game.hud.close_panel()
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game._map_drag_button == 0, "losing focus releases camera drag ownership")
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	var window_size := root.size
	root.size += Vector2i(4, 0)
	for i in range(4): await process_frame
	game._update_camera_zoom(0.01)
	check(game._map_drag_button == 0, "resizing cancels the old drag before the viewport scale changes")
	root.size = window_size
	for i in range(4): await process_frame
	game._pan_camera_by(Vector2(60, 30))
	stopped = camera.global_position
	game.climate_shake = 0.1
	game._update_stock_shake(0.01)
	check(camera.global_position == stopped and absf(camera.h_offset) > 0.0, "weather/stock shake layers over the panned camera")
	game._update_stock_shake(1.0)
	for island in [2, 3, 1]:
		game.state.current_island = island
		game._on_island_changed(island)
		check(game._camera_pan_offset == Vector3.ZERO and game.world.camera.global_position == game._camera_home_position, "island %d arrives centered without a previous pan" % island)
		game._pan_camera_by(Vector2(25, 20))
		await physics_frame
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(game.world.plot_positions[4]))
		check(int(hit.get("plot_index", -1)) == 4, "island %d crop picking follows the panned view" % island)
	var island_home: Vector3 = game._camera_home_position
	var island_zoom: float = game._camera_home_size
	game.world.camera.size = 19.0
	game._zoom_target_size = 19.0
	game._on_island_changed(game.state.current_island)
	check(game.world.camera.global_position == island_home and game.world.camera.size == island_zoom and game._camera_home_position == island_home, "same-island loading restores the overview without replacing home with a panned view")
	game._recenter_camera()
	if game.touch_controls.enabled:
		game.hud.close_panel()
		game.touch_controls._process(0.3)
		var a := Vector2(550, 320)
		var b := Vector2(700, 320)
		var motion := Vector2(50, 35)
		stopped = game.world.camera.global_position
		target_zoom = game._zoom_target_size
		finger(1, a, true)
		drag(1, a + motion)
		finger(1, a + motion, false)
		check(game.world.camera.global_position != stopped and not game.walking and game.pending_plot == -1, "single-finger island drag pans without a farm action")
		stopped = game.world.camera.global_position
		finger(2, a, true)
		finger(3, b, true)
		drag(2, a + motion)
		drag(3, b + motion)
		check(game.world.camera.global_position != stopped, "two-finger touch drag pans the map")
		check(is_equal_approx(game._zoom_target_size, target_zoom), "parallel two-finger movement does not change the final zoom")
		drag(3, b + motion + Vector2(80, 0))
		check(game._zoom_target_size < target_zoom, "spreading fingers still zooms while panning")
		finger(2, a + motion, false)
		finger(3, b + motion + Vector2(80, 0), false)
		check(not game.walking and game.pending_plot == -1 and game.touch_controls.world_fingers.is_empty(), "pan and pinch releases never become a farm tap")
		game.touch_controls.open_drawer("tools")
		target_zoom = game._zoom_target_size
		var pinch := InputEventMagnifyGesture.new()
		pinch.factor = 1.5
		game._unhandled_input(pinch)
		finger(4, a, true)
		finger(4, a, false)
		check(game._zoom_target_size == target_zoom and not game.walking and game.touch_controls.world_fingers.is_empty(), "the open control drawer blocks background zoom and farm taps")
		var reset: Button
		for child in game.touch_controls.drawer_body.get_children():
			if child is Button and child.text == "Recenter view": reset = child
		check(is_instance_valid(reset), "touch controls provide a recenter action")
		if is_instance_valid(reset): reset.pressed.emit()
		check(game._camera_pan_offset == Vector3.ZERO and not game.touch_controls.drawer.visible, "touch recenter restores the overview and closes the drawer")
		finger(2, a, true)
		finger(3, b, true)
		game._on_island_changed(1)
		check(game.touch_controls.world_fingers.is_empty() and game._camera_pan_offset == Vector3.ZERO, "island arrival also cancels touches left on the previous map")
	game.queue_free()
	await process_frame
	print("MAP PAN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
