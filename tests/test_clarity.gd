extends SceneTree
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "render " + name)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.hud.set_process(false)
	check(not game.hud._crop_row.visible and not game.hud._tracked_box.visible, "seed choices and prices are absent from normal farming view")
	check(game.hud._export_box.visible and game.hud._top.surge.text.contains("3:00"), "one prominent stock countdown occupies the banner")
	await shot("clarity-farm")
	key(KEY_2)
	check(game.selected_tool == "plant" and game.hud._crop_row.visible and game.hud._tracked_box.visible, "2 equips seeds and reveals seed choices and tracked prices")
	game.hud._crop_buttons.golden.pressed.emit()
	check(game.state.selected_crop == "golden" and game.selected_tool == "plant", "seed tray selects the actual planting crop")
	await shot("clarity-seeds")
	key(KEY_3)
	check(not game.hud._crop_row.visible and not game.hud._tracked_box.visible, "switching tools immediately clears seed tray")
	game.hud._tool_buttons.plant.pressed.emit()
	check(game.hud._crop_row.visible, "mouse seed slot opens the same tray")
	key(KEY_I)
	check(not game.hud._crop_row.visible and not game.hud._tracked_box.visible, "seed tray does not stack behind a menu")
	game.hud.close_panel()
	check(game.hud._crop_row.visible, "closing menu restores tray when seeds are equipped")
	key(KEY_1)
	for event in ["seed_fair", "crash"]:
		game.state._start_event(event)
		game._on_state_changed()
		check(game.hud._top.surge.text.begins_with("NEXT STOCK"), "routine market event cannot replace the stock countdown: " + event)
	game.state._end_event()
	game.state.surge_timer = 10.01
	game._on_state_changed()
	check(not game.hud._surge_urgent, "countdown does not flash before last ten seconds")
	game.state.surge_timer = 10.0
	game._on_state_changed()
	check(game.hud._surge_urgent and game.hud._market_impact._anticipation > 0.0, "ten-second threshold starts flashing and energy buildup")
	game.hud._hud_clock = 0.0
	game.hud._process(0.01)
	var before: Color = game.hud._surge_style.bg_color
	game.hud._process(0.13)
	check(before != game.hud._surge_style.bg_color, "warning background animates instead of only changing a label")
	await shot("clarity-countdown-10")
	game.hud.set_process(true)
	game.state.surge_timer = 0.01
	game._process(0.01)
	check(game.state.surge_remaining > 0.0 and game.hud._surge_active and game.hud._top.surge.text.contains("SELL"), "countdown opens a real bounded market surge")
	game.state.update(5.0)
	check(not game.hud._surge_active and not game.hud._surge_urgent, "expired surge returns to calm countdown")
	game.state.select_crop("russet")
	game.state.pest_timer = 100.0
	var plot: Dictionary = game.state.plots[4]
	game.state._clear_crop(plot)
	plot.merge({"stage": 3, "tilled": true, "watered": true, "elapsed": 10.0, "pests": true}, true)
	game._on_state_changed()
	key(KEY_5)
	game.perform_plot(4, "pest")
	check(not plot.pests and plot.stage == 3, "bug sprayer removes pests without destroying the crop")
	check(game.hud._tool_caption.text.contains("sprayer"), "fifth equipped tool is clearly named Bug sprayer")
	await shot("clarity-sprayer")
	plot.pests = true
	game._on_state_changed()
	game.state.update(15.0)
	check(plot.stage == 0 and game.world._pest_labels[4].text == "CROP LOST", "pests destroy crop with a short final notice")
	game.world.animate(1.5, false)
	game._on_state_changed()
	check(not game.world._pest_labels[4].visible and game.world._pest_labels[4].text.is_empty(), "destroyed crop never leaves persistent zero-yield text")
	game.state.coins = 2.0e11
	game.state.mastery.russet = 25000
	game.state.unlock_island2()
	game.state.travel_to(2)
	game.state.unlock_island3()
	for island in [1, 2, 3]:
		game.state.travel_to(island)
		game.hud._toast_box.hide()
		game.hud._reward_box.hide()
		game.hud._context_box.hide()
		game.state.market.russet.change = 1700.0
		game.state.market.russet.sell = game.state.CROPS.russet.base * 18.0
		game._on_state_changed()
		game.hud._market_impact._process(0.7)
		check(game.hud._market_impact._strong and game.hud._market_impact.island == island, "jackpot aura activates in island palette " + str(island))
		check(game.hud._market_impact.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.hud._market_impact._mist.mouse_filter == Control.MOUSE_FILTER_IGNORE, "aura and mist cannot intercept field input")
		await shot("clarity-jackpot-island-" + str(island))
	if capture:
		root.size = Vector2i(960, 600)
		await shot("clarity-compact")
		key(KEY_2)
		await shot("clarity-compact-seeds")
	game.queue_free()
	await process_frame
	print("CLARITY UPDATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
