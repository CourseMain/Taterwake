extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
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
	check(not game.hud._crop_row.visible, "seed choices and prices are absent from normal farming view")
	await shot("clarity-farm")
	key(KEY_2)
	check(game.selected_tool == "plant" and game.hud._crop_row.visible, "2 equips seeds and reveals seed choices without a second tracked-price strip")
	var russet = game.hud._crop_buttons.russet
	var old_seeds: int = game.state.seed_inventory.russet
	var old_held: int = Stock.count(game.state.storage, "russet")
	game.state.seed_inventory.russet = 17
	game.state.storage["russet"] = Stock.pile(9)
	game._on_state_changed()
	await process_frame
	check(russet.seed_count.text == "17" and russet.barn_count.text == "9", "seed slot separates actual seed inventory from potatoes held in barn")
	var dividers: Array[Node] = russet.find_children("*", "VSeparator", true, false)
	check(dividers.size() == 1 and dividers[0].is_visible_in_tree() and dividers[0].size.x > 0, "seed and barn quantities have a visible dividing line")
	game.state.seed_inventory.russet = old_seeds
	game.state.storage["russet"] = Stock.pile(old_held)
	game._on_state_changed()
	game.hud._crop_buttons.golden.pressed.emit()
	check(game.state.selected_crop == "golden" and game.selected_tool == "plant" and game.hud._crop_buttons.golden.selected and not russet.selected, "seed tray selects the actual planting crop and marks the active packet")
	await shot("clarity-seeds")
	key(KEY_3)
	check(not game.hud._crop_row.visible, "switching tools immediately clears seed tray")
	game.hud._tool_buttons.plant.pressed.emit()
	check(game.hud._crop_row.visible, "mouse seed slot opens the same tray")
	key(KEY_I)
	check(not game.hud._crop_row.visible, "seed tray does not stack behind a menu")
	game.hud.close_panel()
	check(game.hud._crop_row.visible, "closing menu restores tray when seeds are equipped")
	key(KEY_1)
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
	game.state.coins = 8000000000000.0
	game.state.harvested_total = 25000
	for island in [1]:
		game.hud._toast_box.hide()
		game.hud._reward_box.hide()
		game.hud._context_box.hide()
		game._on_state_changed()
	if capture:
		root.size = Vector2i(960, 600)
		await shot("clarity-compact")
		key(KEY_2)
		await shot("clarity-compact-seeds")
	game.queue_free()
	await process_frame
	print("CLARITY UPDATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
