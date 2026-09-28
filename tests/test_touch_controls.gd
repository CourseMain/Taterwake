extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func frames(count: int = 8) -> void:
	for i in range(count): await process_frame
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
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	# Exercise the complete touch-only UI through its normal startup flag.
	if "--touch-controls" not in OS.get_cmdline_user_args():
		var arguments := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_touch_controls.gd"])
		if DisplayServer.get_name() == "headless": arguments.insert(0, "--headless")
		arguments.append("--")
		arguments.append_array(OS.get_cmdline_user_args())
		arguments.append("--touch-controls")
		var output: Array = []
		var status := OS.execute(OS.get_executable_path(), arguments, output, true)
		for line in output: print(line)
		quit(status)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Touch input checks need a calm crop; weather behavior has separate suites.
	game.state.rng.seed = 6
	await frames()
	game.state.ClimateSystem.Lesson.finish(game.state)
	game.state.coins = 1e20
	game.state.pest_timer = 1000
	game.hud.close_panel()
	game.set_process(false)
	var touch = game.touch_controls
	check(touch.enabled, "touch controls enabled")
	for size in [Vector2i(390,844), Vector2i(844,390), Vector2i(768,1024), Vector2i(1024,768), Vector2i(1366,768)]:
		root.size = size
		await frames()
		game.hud.close_panel()
		touch._process(0.3)
		await frames()
		var bounds := root.get_visible_rect()
		for control in [touch.stick,touch.tools_button,touch.menu_button,touch.use_button,touch.sell_button]:
			check(bounds.encloses(control.get_global_rect()), "%s control inside %s" % [control.name,size])
			check(control.size.y * size.y / bounds.size.y >= 43, "touch target at least 44px (rounding) at %s" % size)
		for kind in ["menu","market","inventory","tools","climate","quests","activities","duck_patrol","dex","help","graphics","debug"]:
			game.hud.show_panel(kind, game.state)
			touch._process(0.3)
			await frames()
			check(bounds.grow(1).encloses(game.hud._modal_card.get_global_rect()), "%s modal inside %s: %s" % [kind,size,game.hud._modal_card.get_global_rect()])
			var scroll: ScrollContainer = game.hud._body.get_parent()
			check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 1, "%s content fits %s: %s > %s" % [kind,size,game.hud._body.get_combined_minimum_size().x,scroll.size.x])
			check(not touch.stick.visible, "menus suppress movement")
		game.hud.close_panel()
		if "--capture" in OS.get_cmdline_user_args():
			touch._process(0.3)
			await frames()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/mobile-qa/farm-%dx%d.png" % [size.x,size.y])
	root.size = Vector2i(844,390)
	await frames()
	touch._process(0.3)
	var center: Vector2 = touch.stick.get_global_rect().get_center()
	finger(0, center + Vector2(60,0), true)
	check(touch.movement.x > 0.8 and touch.sprinting, "outer stick sprints")
	var before: Vector3 = game.world.player.position
	game._process(0.1)
	check(game.world.player.position.distance_to(before) > 0.2, "stick moves actual farmer")
	finger(1, touch.tools_button.get_global_rect().get_center(), true)
	finger(1, touch.tools_button.get_global_rect().get_center(), false)
	check(touch.drawer.visible, "second finger opens tools while moving")
	finger(0,center,false)
	check(touch.movement == Vector2.ZERO and not touch.sprinting, "release stops movement")
	touch.drawer.hide()
	game._cancel_walk()
	var zoom: float = game._zoom_target_size
	var p := Vector2(620,300)
	finger(2,p,true)
	finger(3,p+Vector2(80,0),true)
	drag(3,p+Vector2(180,0))
	check(game._zoom_target_size < zoom, "spread pinch zooms in")
	finger(2,p,false)
	finger(3,p+Vector2(180,0),false)
	check(not game.walking and game.pending_plot == -1, "pinch never triggers farming or movement")
	check(touch.world_fingers.is_empty(), "pinch releases all fingers")
	# Exercise the actual touch Use button through the complete manual crop loop.
	game.hud.close_panel()
	game._cancel_walk()
	game.state.select_crop("russet")
	game.state.seed_inventory.russet = 20
	game.state._clear_crop(game.state.plots[0])
	game.state.plots[0].tilled = false
	game.world.set_player_position(game.world.plot_positions[0])
	await frames()
	touch._process(0.3)
	var use_point: Vector2 = touch.use_button.get_global_rect().get_center()
	for tool in ["hoe", "plant", "water"]:
		game._select_tool(tool)
		finger(4,use_point,true)
		finger(4,use_point,false)
		check(game.state.plots[0].tilled, "touch " + tool + " reaches bed")
	check(game.state.plots[0].stage > 0 and game.state.plots[0].watered, "touch plants and waters crop")
	game.state.plots[0].pests = true
	game._select_tool("pest")
	finger(4,use_point,true)
	finger(4,use_point,false)
	check(not game.state.plots[0].pests, "touch sprayer removes pests")
	game.state.update(float(game.state.CROPS.russet.grow) + 1.0)
	var stored: int = game.state.storage.russet
	game._select_tool("harvest")
	finger(4,use_point,true)
	finger(4,use_point,false)
	check(game.state.storage.russet > stored, "touch harvest delivers crop to barn")
	game.queue_free()
	await frames()
	print("TOUCH CONTROLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
