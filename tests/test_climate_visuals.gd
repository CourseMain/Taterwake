extends SceneTree
var game
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int = 5) -> void:
	for _i in range(count): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.state.debug_unlock_island(3)
	game.state.field_expansions["2"] = true
	game.state.travel_to(2)
	game.state.climate.acknowledge(game.state)
	game.state.coins = 1e18
	game.hud.close_panel()
	for project: String in game.state.ClimateSystem.PROJECTS:
		game.state.climate.fund(game.state, project)
	for event: String in ["flood", "drought", "storm"]:
		game.state.climate.data.phase = "calm"
		game.state.climate.data.event = ""
		for plot in game.state.plots:
			game.state._clear_crop(plot)
			plot.unlocked = true
			plot.tilled = true
			plot.stage = 2
			plot.watered = true
			plot.crop = "sunburst"
		game.state.climate.begin_warning(game.state, event, 1.0)
		game._advance_simulation(45)
		game._advance_simulation(12.5 if event == "storm" else 13)
		game._on_state_changed()
		game.world.set_climate(game.state.climate_info())
		game.world.set_day_time(0)
		game.hud._climate_alert.dismiss()
		game.hud._toast_box.hide()
		game.hud._purchase_box.hide()
		game.hud.update_state(game.state)
		await frames(15)
		var effect = game.world._climate_field
		check(effect.visible and effect.markings.visible, "world-space climate markings present")
		check(effect.water.visible == (event == "flood"), "puddles are exclusive to floods")
		check(game.hud._climate_console.visible, "field controls remain accessible during weather")
		if event == "storm": check(effect.bolts.visible, "lightning geometry follows the saved strike")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/climate-" + event + "-new.png")
		print("WEATHER VISUAL: ", event, " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.hud.show_panel("climate", game.state)
	await frames()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/climate-controls-new.png")
	check(not game.hud._refs.has("climate_control:mode") and game.hud._refs.has("climate_fund:irrigation"), "equipment panel retains upgrades without a duplicate control grid")
	game.queue_free()
	await create_timer(0.25).timeout
	await frames()
	print("CLIMATE VISUALS: %d failures" % failures)
	quit(1 if failures else 0)
