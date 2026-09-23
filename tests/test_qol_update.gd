extends SceneTree
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func settle() -> void:
	for _i in range(6): await process_frame
func shot(name: String) -> void:
	game.hud._toast_box.hide()
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/qol-" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	var state = game.state
	var expected: Array = [10, 25, 40, 50, 55, 60]
	for index: int in range(state.CROP_IDS.size()):
		var crop: String = state.CROP_IDS[index]
		check(state.CROPS[crop].grow == expected[index] and state.crop_grow_time(crop) <= 60.0, crop + " uses balanced base growth")
	var coins: float = state.coins
	var harvests: int = state.total_mastery()
	game._on_action("debug:island:3")
	game.hud._act("debug:island:2")
	check(not state.island2_unlocked and not state.island3_unlocked, "locked debug rejects island unlocks through both routes")
	game._on_action("debug:unlock:" + game.DEBUG_ACCESS_CODE)
	game._on_action("debug")
	game.hud._refs.debug_island_2.pressed.emit()
	check(state.island2_unlocked and not state.island3_unlocked and state.island_plots["2"].all(func(p): return p.unlocked), "debug unlocks Shores and its field")
	check(game.hud._refs.debug_island_2.disabled, "already unlocked button disables")
	game.hud._refs.debug_island_3.pressed.emit()
	check(state.island3_unlocked and state.island_plots["3"].all(func(p): return p.unlocked), "debug unlocks winter field")
	check(state.coins == coins and state.total_mastery() == harvests and state.current_island == 1 and state.blind_cycle.island == 1, "unlock preserves money, mastery, location and current tax tier")
	check(state.debug_info().active and state.debug_islands_modified, "debug progression marks later trophy results")
	state.reset_debug()
	check(state.debug_info().active, "reset luck does not erase debug progression history")
	state.luck = 2.0
	state.inventory_items.lucky_cap = 1
	state.equipment.head = "lucky_cap"
	state.apply_debug(1.0, 3.0)
	var info: Dictionary = state.luck_breakdown()
	check(is_equal_approx(info.earned, 1.0) and is_equal_approx(info.gear, 0.25) and is_equal_approx(info.normal, 2.25), "luck adds actual earned and equipped bonuses")
	check(is_equal_approx(info.normal_percent, 125.0) and is_equal_approx(info.total, 6.75) and is_equal_approx(info.total_percent, 575.0), "percent and final multiplier describe the same effective luck")
	game.hud.update_state(state)
	check(game.hud._top.luck.text == "6.75×" and game.hud._top.luck_percent.text.contains("575%"), "HUD shows precise total and percentage gain")
	game.hud._refs.debug_luck.value = 4.0
	game.hud._refresh_debug()
	check(game.hud._refs.debug_preview.text.contains("9.00×") and game.hud._refs.debug_preview.text.contains("800%"), "debug preview shows resulting luck before applying")
	await shot("debug-luck")
	(game.hud._body.get_parent() as ScrollContainer).scroll_vertical = 520
	await shot("debug-islands")
	game._on_action("dex")
	check(game.hud._dex_tab == "mutations", "Dex starts with special potato illustrations")
	check(game.hud._body.find_children("DexPicture_*", "Control", true, false).size() == 4, "each special mutation has a picture")
	check(game.hud._refs["dex_status:golden"].text.contains("NOT DISCOVERED"), "preview does not invent discoveries")
	await shot("dex-mutations")
	state.dex.append("golden")
	game.hud.update_state(state)
	check(game.hud._refs["dex_status:golden"].text == "DISCOVERED", "discovery state refreshes without reopening")
	game.hud._act("dex_tab:crops")
	check(game.hud._body.find_children("DexPicture_*", "Control", true, false).size() == 6, "crop tab illustrates all six varieties")
	check(game.hud._refs["dex_status:sunburst"].text.contains("55s") and game.hud._refs["dex_status:icecap"].text.contains("60s"), "Dex shows later-island growth and home")
	await shot("dex-crops")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = size
		await settle()
		check(game.hud.root.get_global_rect().encloses(game.hud._modal_card.get_global_rect()), "Dex modal fits " + str(size))
		check(game.hud._body.get_combined_minimum_size().x <= game.hud._body.size.x + 1.0, "Dex has no horizontal overflow " + str(size))
		for picture: Control in game.hud._body.find_children("DexPicture_*", "Control", true, false):
			check(picture.size.x >= 96 and picture.size.y >= 96, "illustration stays readable " + picture.name)
	root.size = Vector2i(1280, 800)
	game.hud.close_panel()
	state.travel_to(2)
	state.climate.acknowledge(state)
	state.climate.begin_warning(state, "drought", 1.0)
	state.climate.data.phase = "active"
	state.climate.data.timer = 30.0
	for crop: String in state.CROP_IDS:
		check(state.crop_grow_time(crop) <= 60.000001, crop + " weather slowdown is bounded")
	# Old saves are validated against their original times, then migrated by completion ratio.
	state.climate.reset()
	state.travel_to(1)
	var raw: Dictionary = state._save_data()
	raw.mechanics_revision = 13
	raw.erase("debug_islands_modified")
	for pair: Array in [[4, 2, 45.0], [5, 3, 90.0]]:
		var p: Dictionary = raw.island_plots["1"][pair[0]]
		p.crop = "radioactive"
		p.stage = pair[1]
		p.tilled = true
		p.watered = true
		p.elapsed = pair[2]
	var sun: Dictionary = raw.island_plots["2"][0]
	sun.crop = "sunburst"
	sun.stage = 3
	sun.tilled = true
	sun.watered = true
	sun.elapsed = 45.0
	var path: String = "user://qol-migration-%d.json" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	check(state.load_game(path), "pre-rebalance save with mature 90s crop loads")
	check(is_equal_approx(state.plots[4].elapsed, 25.0) and state.plots[4].stage == 2, "half-grown old Radioactive remains half-grown")
	check(state.plots[5].elapsed == 50.0 and state.plots[5].stage == 3 and state.island_plots["2"][0].elapsed == 55.0, "mature crops remain mature after shorter or longer baseline")
	check(state._valid_save(state._save_data()), "migrated farm validates at revision 14")
	state.reset_game()
	state.debug_unlock_island(3)
	check(state.island2_unlocked and state.island3_unlocked, "direct winter unlock includes prerequisite island")
	check(state.save_game(path) and state.load_game(path) and state.debug_islands_modified, "debug unlock and marker survive save/load")
	state.reset_game()
	check(not state.debug_islands_modified and not state.island2_unlocked and not state.island3_unlocked, "new farm resets debug progression")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("QOL UPDATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
