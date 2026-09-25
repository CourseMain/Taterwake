extends SceneTree
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for _i in range(5): await process_frame
func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await settle()
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	game.world.set_day_time(10)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/projects-" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.debug_unlock_island(3)
	for island: int in [2, 3]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		game.hud._climate_alert.dismiss()
		game.state.coins = 0
		game._on_action("climate_fund:rainwater")
		check(game.world._project_nodes.has("rainwater") and not game.world._project_nodes.has("drainage"), "starter tank exists before purchases")
		game.state.coins = 1e18
		for level: int in [1, 2]:
			for id: String in game.state.ClimateSystem.PROJECTS:
				game._on_action("climate_fund:" + id)
				check(game.world._project_nodes.has(id), "purchase immediately builds " + id)
				var project: Node3D = game.world._project_nodes[id]
				check(project.get_meta("level") == int(game.state.climate.data.projects[str(island)].get(id, 0)) + (1 if id == "rainwater" else 0), "scenery follows local upgrade level")
				var instance: int = project.get_instance_id()
				game._on_state_changed()
				check(game.world._project_nodes[id].get_instance_id() == instance, "ordinary refresh reuses project geometry")
				check(not project.find_children("*", "GeometryInstance3D", true, false).is_empty(), "project contains visible geometry")
			game.hud.close_panel()
			await shot("island-%d-level-%d" % [island, level])
		# Field centres remain clickable after every structure is installed.
		await settle()
		await physics_frame
		for index: int in range(game.world.plot_positions.size()):
			var point: Vector3 = game.world.plot_positions[index] + Vector3(0, 0.13, 0)
			var picked: Dictionary = game.world.pick(game.world.camera.unproject_position(point))
			check(picked.get("plot_index", -1) == index, "structures do not block bed " + str(index))
		game._on_action("climate")
		await shot("shop-%d" % island)
		game.hud.close_panel()
	game.state.travel_to(1)
	check(game.world._project_nodes.size() == 1 and game.world._project_nodes.has("rainwater"), "Island 1 keeps only its starter tank")
	game.state.travel_to(2)
	check(game.world._project_nodes.size() == 5 and game.world._project_nodes.rainwater.get_meta("level") == 3, "returning to island restores its projects")
	game.state.climate.reset()
	game._on_state_changed()
	check(game.world._project_nodes.size() == 1 and game.world._project_nodes.rainwater.get_meta("level") == 1, "reset removes purchases and retains starter tank")
	game.queue_free()
	await settle()
	print("CLIMATE PROJECTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
