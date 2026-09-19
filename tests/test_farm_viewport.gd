extends SceneTree
const FarmViewport = preload("res://scripts/farm_viewport.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	check(game.world.get_viewport() == game.farm_viewport, "3D world lives in the independent farm viewport")
	check(game.hud.get_viewport() == root and game.rocket_cutscene.get_viewport() == root, "menus and rocket stay on the sharp root canvas")
	for resolution: Vector2i in [Vector2i(1280,800), Vector2i(2560,1600), Vector2i(3840,2160), Vector2i(900,1600)]:
		root.size = resolution
		await process_frame
		for mode: String in ["smooth", "balanced", "crisp"]:
			game._apply_graphics_quality(mode)
			await process_frame
			var size: Vector2i = game.farm_viewport.size
			var bound: Vector2i = FarmViewport.BUDGETS[mode]
			check(size.x <= bound.x and size.y <= bound.y, "3D budget respected")
			check(root.size == resolution, "quality cannot reduce UI resolution")
			var logical_size: Vector2 = root.get_visible_rect().size
			check(absf(float(size.x)/size.y - logical_size.x/logical_size.y) < 2.0/size.y, "letterboxing keeps the complete farm aspect ratio")
			for island: int in [1, 2, 3]:
				game.state.travel_to(island)
				game.state.plots[4].unlocked = true
				game._on_state_changed()
				await physics_frame
				await physics_frame
				var point: Vector2 = game.world.camera.unproject_position(game.world.plot_positions[4])
				var logical: Vector2 = point * root.get_visible_rect().size / Vector2(size)
				var event := InputEventMouseButton.new()
				event.position = logical
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				game._unhandled_input(event)
				check(game.pending_plot == 4, "scaled screen click queues exact plot on island%d / %s" % [island,mode])
				game._cancel_walk()
	game.queue_free()
	await process_frame
	print("FARM VIEWPORT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
