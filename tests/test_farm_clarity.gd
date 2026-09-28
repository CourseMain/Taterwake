extends SceneTree
## Quiet feedback under repeated input, small contextual help and readable signs.
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
	await settle()
	game.hud._process(0.0)
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/clarity-" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.hud.set_process(false)
	var hud = game.hud
	var state = game.state
	state.farm_help.enable()
	state.farm_help.dismiss("repeat")
	hud.update_state(state)
	await settle()
	check(not hud._farm_help_card.visible, "optional tax advice never floats over the farm")
	hud.show_panel("help", state)
	check(hud._modal_title.text == "Controls", "help contains only controls")
	check(not is_instance_valid(hud._farm_help_action) and not hud._refs.has("farm_tip_body"), "extra help launcher and explanation are removed")
	check(not hud._farm_help_card.visible, "controls never add a floating help launcher")
	hud.close_panel()
	state.coins = 240.0
	hud._help_cooldown = 0.0
	game._select_tool("water")
	state.plots[4].tilled = true
	state.plots[4].stage = 1
	state.plots[4].crop = "russet"
	state.plots[4].watered = false
	game.perform_plot(4, "water")
	check(state.plots[4].watered and not hud._toast_box.visible and not hud._farm_help_card.visible, "successful watering is quiet and hides optional help")
	hud.set_context("Russet · Ready in 10s")
	game.perform_plot(4, "water")
	check(hud._context.text == "Already watered" and not hud._toast_box.visible, "repeat water uses one brief footer reminder")
	hud._process(0.5)
	var remaining: float = hud._farm_hint_remaining
	for _i in range(25): game.perform_plot(4, "water")
	check(is_equal_approx(hud._farm_hint_remaining, remaining), "rapid repeats neither stack nor extend feedback")
	await settle()
	check(hud._context_box.size.y <= 32.0 and hud._context_box.size.x < 240.0, "short reminder hugs its text")
	check(not hud._context_box.get_global_rect().intersects(hud._hotbar.get_global_rect()), "reminder stays above the tool buttons")
	check(hud._context_box.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._context.mouse_filter == Control.MOUSE_FILTER_IGNORE, "field clicks pass through reminder")
	game.world.set_day_time(25.0)
	await shot("watering")
	hud._process(1.0)
	check(hud._context.text == "Russet · Ready in 10s", "expired feedback restores current hover instead of an old queue")
	game.perform_plot(5, "water")
	check(hud._context.text == "Plant a seed first [2]", "empty bed explains the specific missing step")
	state.seed_inventory.russet = 0
	game.perform_plot(5, "plant")
	check(hud._context.text.contains("No Russet seeds") and not hud._toast_box.visible, "seed failure has no duplicate central toast")
	game.perform_plot(5, "pest")
	check(hud._context.text == "No pests here", "spraying empty area stays brief")
	state.plots[5].stage = 3
	state.plots[5].crop = "russet"
	state.plots[5].tilled = true
	state.storage.russet = state.capacity
	game.perform_plot(5, "harvest")
	check(hud._context.text == "Barn full · Sell crops [F]" and not hud._toast_box.visible, "full barn retains actionable feedback without a toast")
	state.storage.russet = 0
	game.perform_plot(6, "hoe")
	check(hud._farm_hint_remaining == 0.0, "successful work clears the previous failure reminder")
	hud._process(3.1)
	hud.set_context("")
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = dimensions
		hud.update_state(state)
		await settle()
		hud._process(0.0)
		await settle()
		check(not hud._farm_help_card.visible, "no floating advice at " + str(dimensions))
		hud.show_farm_hint("Already watered")
		await settle()
		check(hud.root.get_global_rect().encloses(hud._context_box.get_global_rect()) and not hud._context_box.get_global_rect().intersects(hud._hotbar.get_global_rect()), "reminder fits " + str(dimensions))
		hud._process(3.1)
	root.size = Vector2i(1280, 800)
	hud.set_context("")
	state.debug_unlock_island(3)
	for island: int in [1, 2, 3]:
		state.travel_to(island)
		state.climate.acknowledge(state)
		game.world.set_day_time(0.0)
		game._on_state_changed()
		await settle()
		var signs: int = 0
		for label: Label3D in game.world.find_children("*", "Label3D", true, false):
			if not label.get_meta("shop_label", false): continue
			signs += 1
			check(label.font == game.world._shop_font and label.font_size <= 32 and label.outline_size > 0, "shared outlined shop typography: " + label.text)
		check(signs >= 7, "island %d retains discoverable shop signs" % island)
		await shot("island-%d" % island)
	state.coins = 215e6
	state.climate.begin_warning(state, "storm", 1.0)
	state.climate.data.timer = 22.0
	hud._climate_alert.dismiss()
	hud.update_state(state)
	await shot("winter-warning")
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("FARM CLARITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
