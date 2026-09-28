extends SceneTree
var game
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func settle() -> void:
	for _i in range(8): await process_frame
func shot(label: String) -> void:
	game._update_equipment_card()
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/water-loop-" + label + ".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.hud.close_panel()
	game.state.coins = 1e18
	game.state.expansion = 1
	game.state.set_tutorial_active(false)
	for plot in game.state.plots:
		plot.merge({"unlocked": true, "stage": 1, "crop": "russet", "tilled": true, "watered": false}, true)
	game._select_tool("water")
	for i in range(16): game.perform_plot(i, "water")
	var ops = game.state.ClimateSystem.Operations
	check(ops.local(game.state).can == 0 and game.state.plots[15].watered, "sixteen real beds empty starter can")
	game._update_equipment_card()
	check(game.hud._climate_console.equipment == "tank", "first empty can selects its visible source")
	game.perform_plot(16, "water")
	check(not game.state.plots[16].watered, "empty can blocks next crop")
	await shot("empty-can")
	game._queue_refill()
	check(game.pending_refill and ops.local(game.state).can == 0, "refill waits for farmer to walk")
	for _i in range(120):
		game._process(0.1)
		if not game.pending_refill: break
	check(not game.pending_refill and ops.local(game.state).can == 16 and ops.local(game.state).water < 36, "arrival transfers tank water to can")
	check(game.hud._climate_console.equipment.is_empty() and game.world._climate_field.loop.refill_time > 0, "successful refill dismisses tip and animates transfer")
	await shot("refilling")
	game.state.update(4)
	check(ops.local(game.state).water == 36 and game.state.climate.data.phase == "calm", "Island1 tank quickly replenishes without disaster")
	game.state.upgrade_tool("water")
	await settle()
	check(ops.can_capacity(game.state) == 32 and game.hud._climate_console.equipment == "tank", "can upgrade teaches filling expanded capacity")
	game.state.climate.fund(game.state,"irrigation")
	game._climate_action("lesson_start")
	await shot("practice-target")
	game.perform_plot(18, "water")
	game._climate_action("show_sprinkler")
	check(game.hud._climate_console.equipment == "sprinkler2", "practice uses ordinary equipment selection")
	await shot("practice-pipe")
	game._climate_action("use_sprinkler")
	check(game.state.climate.data.lesson.stage == "success" and game.world._climate_field.loop.flow_patch == 2, "connected sprinkler completes practice")
	await shot("practice-result")
	game._climate_action("lesson_skip")
	for plot in game.state.plots:
		plot.merge({"unlocked": true, "stage": 1, "crop": "sunburst", "tilled": true, "watered": false}, true)
	game._select_equipment("sprinkler1")
	var before: float = ops.local(game.state).water
	game._climate_action("use_sprinkler")
	check(ops.local(game.state).water == before - ops.water_cost(game.state) and game.state.plots[16].watered and not game.state.plots[0].watered, "ordinary sprinkler waters fixed middle patch for displayed cost")
	await shot("ordinary-irrigation")
	for id in ["drainage", "windbreaks", "barn"]: game.state.climate.fund(game.state, id)
	await settle()
	game._close_equipment()
	game.state.climate.begin_warning(game.state, "flood", 1)
	game._advance_simulation(55)
	game.hud._climate_alert.dismiss()
	game._climate_action("show_drain")
	await shot("drain-before")
	game._climate_action("gates")
	game._advance_simulation(5)
	await shot("drain-after")
	check(ops.local(game.state).gates, "gate action opens world drainage")
	for dimensions in [Vector2i(1024, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		await settle()
		game._select_equipment("tank")
		game._update_equipment_card()
		await settle()
		check(root.get_visible_rect().encloses(game.hud._climate_console.get_global_rect()), "equipment card fits viewport " + str(dimensions))
	game.queue_free()
	await settle()
	# The audio mixer uses wall time; headless frames can finish before queued
	# playback stops are drained. Give the mixer its shutdown interval.
	await create_timer(0.25).timeout
	print("WATER LOOP GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
