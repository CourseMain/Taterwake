extends SceneTree
const Epilogue = preload("res://scripts/epilogue.gd")
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + text)
func fixture(outcome: String) -> Dictionary:
	var axes: Dictionary = {"solvency": 0.85, "adaptation": 0.85, "diversification": 0.85, "land_health": 0.85}
	var projects: Dictionary = {"rainwater": 2, "drainage": 2, "windbreaks": 2, "frost": 2}
	match outcome:
		"Dust", "Drowned":
			axes = {"solvency": 0.0, "adaptation": 0.0, "diversification": 0.0, "land_health": 0.1}
			projects = {}
		"Deserted", "Sold to the estate":
			axes = {"solvency": 0.1, "adaptation": 0.3, "diversification": 0.0, "land_health": 0.55}
			projects = {"rainwater": 1, "drainage": 1}
		"Holding on":
			axes = {"solvency": 0.5, "adaptation": 0.65, "diversification": 0.0, "land_health": 0.6}
		"The shop village":
			axes = {"solvency": 0.7, "adaptation": 0.4, "diversification": 0.8, "land_health": 0.6}
	var records: Array = []
	for year in range(1, 51):
		for season in range(1 if year < 10 else 3):
			records.append({"year": year, "season": season, "event": "drought" if outcome == "Dust" else "flood", "severity": minf(1.0, 0.5 + year * 0.03)})
	return {"outcome": outcome, "axes": axes, "projects": projects, "records": records, "headlines": Epilogue.headlines(records), "verdicts": Epilogue.verdicts(axes), "farm_value": 128000 * axes.land_health}

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.state.season_clock.year = 10
	game.state.season_clock.season = 3
	game.state.season_clock.seconds = 150
	game.state._end_run("completed")
	game.state.ledger.post_fixed_costs(10)
	game._on_state_changed()
	var before: String = var_to_str(game.state._save_data())
	for outcome in Epilogue.OUTCOMES:
		game.epilogue_result = fixture(outcome)
		game.hud._act("epilogue")
		await frames()
		var screen = game.epilogue_screen
		check(is_instance_valid(screen) and screen.ready_scene, outcome + " opens from summary")
		if not is_instance_valid(screen): continue
		check(game.world.future_outcome == outcome, outcome + " rendered on same map")
		match outcome:
			"Dust": check(not game.world.get_node("RedBarn").visible and game.world._climate_field.info.supply.water == 0, "dust has a ruined barn and dry tank")
			"Drowned": check(game.world._climate_field.water.visible and not game.world.get_node("FarmPier").visible, "flooded beds and missing jetty")
			"Deserted", "Sold to the estate":
				for resident in game.world._villagers: check(not resident.visible, "no residents in abandoned future")
			"Holding on", "The shop village", "Thriving": check(game.world.future_root.find_children("PotatoTuber*", "Node3D", true, false).size() > 0, "occupied farm keeps its potato crops")
		check(not game.hud.visible and not game.touch_controls.visible, "ordinary chrome hidden")
		var camera_before: Vector3 = game.world.camera.position
		screen._process(1.0)
		check(camera_before != game.world.camera.position, "slow pan plays")
		var camera: Camera3D = game.world.camera
		var bounds_fit := is_equal_approx(camera.far - camera.near, 70.0)
		for point: Vector3 in game.world.Surface.mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var depth: float = -camera.to_local(point).z
			bounds_fit = bounds_fit and depth > camera.near and depth < camera.far
		check(bounds_fit, "epilogue pan keeps every coastline edge inside the fitted shadow range")
		check(var_to_str(game.state._save_data()) == before, "presentation leaves ten-year save untouched")
		if "--capture" in OS.get_cmdline_user_args():
			await create_timer(2.1).timeout
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://artifacts/epilogue")
			root.get_texture().get_image().save_png("res://artifacts/epilogue/" + outcome.to_snake_case() + ".png")
			if outcome == "The shop village":
				await screen.capture()
				check(FileAccess.file_exists("user://taterland-50-years.png"), "screenshot button saves a real PNG")
		screen.finished.emit()
		await frames()
		check(not is_instance_valid(game.epilogue_screen) and game.world.future_outcome.is_empty(), "ledger restores original world")
		check(game.hud._panel_kind == "run_summary", "returns to ten-year summary")
		var restored_depth: float = -game.world.camera.to_local(Vector3.ZERO).z
		check(restored_depth > game.world.camera.near and restored_depth < game.world.camera.far and is_equal_approx(game.world.camera.far - game.world.camera.near, 70.0), "returning to the ledger restores the original camera's fitted depth")
	game.epilogue_result = fixture("Holding on")
	game._on_user_action("epilogue")
	await create_timer(2.1).timeout
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = dimensions
		await frames(5)
		var screen = game.epilogue_screen
		check(screen.bottom.get_global_rect().end.y <= screen.size.y + 1, "ending footer fits " + str(dimensions))
		check(screen.actions.get_global_rect().end.x <= screen.size.x, "buttons fit " + str(dimensions))
		check(screen.top.get_global_rect().end.y < screen.bottom.position.y, "farm remains visible " + str(dimensions))
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/epilogue/layout_%dx%d.png" % [dimensions.x, dimensions.y])
	game.epilogue_screen.new_run.emit()
	await frames()
	check(not game.state.run_over and game.state.season_clock.year == 1 and game.epilogue_result.is_empty(), "new run resets ending cache")
	game.queue_free()
	await frames()
	print("Epilogue scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
