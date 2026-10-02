extends SceneTree
var game
var checks: int = 0
var failures: int = 0
var phone: bool = false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle() -> void:
	for i in range(10): await process_frame
func shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/weather-"+label+("-phone" if phone else "")+".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Begin calmly so explicit weather/practice scenarios own the fixture.
	game.state.rng.seed = 6
	await settle()
	game.set_process(false)
	phone = game.touch_controls.enabled
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(390,844) if phone else Vector2i(1280,800)
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.coins = 4e+19
	farm.coins = 400000
	game.hud._climate_alert.dismiss()
	game.hud._toast_box.hide()
	game.hud.show_panel("climate",farm)
	await settle()
	await shot("dashboard")
	check(game.hud._refs.climate_status.text == "Clear skies", "forecast reads actual calm phase")
	var page = game.hud._refs.weather_page
	check(page._values.water.text == "%d / %d water" % [int(farm.climate_info().supply.water),int(farm.climate_info().water_capacity)],"tank telemetry reads real supply")
	check(not game.hud._refs.climate_market.visible, "calm forecast has no filler advice")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	for id: String in ["rainwater", "drainage", "windbreaks", "frost"]:
		var button: Button = game.hud._refs["climate_fund:"+id]
		scroll.ensure_control_visible(button)
		await settle()
		check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "equipment action reachable: "+id)
		check(button.disabled and button.text.begins_with("Build"), "protection construction waits for Winter: " + id)
	check(page._grid.get_child_count() == 4 and not game.hud._refs.has("cover_all") and not game.hud._refs.has("protection_summary"), "four tiles replace reduction table and batch cover entrance")
	scroll.scroll_vertical = 100000
	await shot("bottom")
	farm.season_clock.season = 2; farm.season_clock.seconds = 149.75
	farm.update(0.25); game.hud.close_panel()
	game.hud.show_panel("climate", farm)
	page = game.hud._refs.weather_page
	scroll = game.hud._body.get_parent()
	var water: Button = game.hud._refs["climate_fund:rainwater"]
	scroll.ensure_control_visible(water)
	await settle()
	scroll.ensure_control_visible(water)
	await settle()
	await shot("checkout")
	var point: Vector2 = water.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await create_timer(0.05).timeout
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event,true)
		await create_timer(0.05).timeout
	await settle()
	check(farm.climate.data.protection.pending.has("rainwater") and farm.climate.data.projects.get("rainwater", 0) == 0, "pointer checkout reserves water tank construction")
	game.hud.close_panel()
	for stroke in range(3): farm.climate.Protection.work(farm, "rainwater")
	game.hud.show_panel("climate", farm)
	page = game.hud._refs.weather_page
	check(page._values.water.text.ends_with("72 water"),"tank telemetry updates after real purchase")
	game._on_action("climate")
	await settle()
	scroll = game.hud._body.get_parent()
	scroll.ensure_control_visible(game.hud._refs["climate_fund:rainwater"])
	await shot("equipment")
	farm.season_clock.year = 2; farm.season_clock.season = 0; farm.season_clock.seconds = 0
	farm.climate.begin_warning(farm,"flood",1)
	game.hud._climate_alert.dismiss()
	game.hud.update_state(farm)
	scroll.scroll_vertical = 0
	await settle()
	check(game.hud._refs.climate_status.text.contains("45s") and game.hud._refs.climate_market.text == "Open drainage gates","warning shows countdown and specific action")
	await shot("warning")
	var dimensions: Array = [Vector2i(390,844),Vector2i(844,390)] if phone else [Vector2i(1280,800),Vector2i(960,600),Vector2i(640,360)]
	for resolution: Vector2i in dimensions:
		root.size = resolution
		await settle()
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()),"station fits "+str(resolution))
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x+1,"no horizontal station overflow "+str(resolution))
	root.size = Vector2i(390,844) if phone else Vector2i(1280,800)
	for panel: String in ["tools","activities","climate"]:
		game.hud.show_panel(panel,farm)
		await settle()
		for label: Node in game.hud._body.find_children("*","Label",true,false):
			check(not label.text.contains("Equip tools with") and not label.text.contains("Partial deliveries welcome") and not label.text.contains("Trees shelter the far patch") and not label.text.contains("Forecasts, equipment"),"removed screenshot filler stays absent")
	game.hud.close_panel()
	if not phone:
		for island in [1]:
			game.world.build_world()
			var station: Node3D = game.world.weather_station
			game.world.camera.size = 8
			game.world.camera.position = station.global_position + Vector3(8,7,13)
			game.world.camera.look_at(station.global_position + Vector3(0,1.8,0))
			await shot("station-%d" % island)
	game.queue_free()
	await settle()
	print("WEATHER DASHBOARD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
