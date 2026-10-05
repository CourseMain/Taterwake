extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func frames() -> void:
	await process_frame
	await process_frame
func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await frames()
	game.hud._toast_box.hide()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Begin calmly so explicit weather/practice scenarios own the fixture.
	game.state.rng.seed = 6
	await frames()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.state.coins = 40000000000000
	game.state.expand_field()
	game.state.coins = 4000000
	game.state.barn_level = 3
	game.state._recompute_capacity()
	game.state.storage["russet"] = Stock.pile(1000)
	# Keep unrelated random pests outside this flood's preparation window.

	for plot in game.state.plots:
		if not plot.unlocked: continue
		game.state._clear_crop(plot)
		plot.tilled = true
		plot.stage = 1
		plot.crop = "russet"
	game._on_action("climate")
	check(game.hud._panel_kind == "climate" and game.hud._refs.has("climate_fund:drainage"), "climate initiatives open from the controller")
	check(not game.hud._refs.has("climate_details") and game.hud._refs.weather_page.find_children("*", "Button", true, false).any(func(b): return b.text == "?" and b.tooltip_text.contains("Spring insurance")), "station explanations are behind a question mark")
	game.state.climate.begin_warning(game.state, "flood", 1.0)
	game.hud.update_state(game.state)
	check(game.hud._refs.climate_status.text.contains("45s") and game.hud._refs.climate_status.text.to_upper().contains("FLOOD"), "warning names the disaster and preparation time")
	check(game.hud._climate_effect.visible and game.state.climate.data.field_lost == 0, "warning builds weather atmosphere without early damage")
	check(game.hud._weather_button.picture.id == "rain" and game.hud._weather_button.picture.warning, "flood warning draws rain with the live warning dot")
	await shot("climate-warning")
	game.hud._climate_alert.dismiss()
	await shot("climate-prepare")
	var frame: Rect2 = game.hud._modal_card.get_global_rect()
	for id in ["rainwater", "drainage", "frost", "windbreaks"]:
		check(game.hud._refs["climate_fund:"+id].is_visible_in_tree(), "protection purchases remain reachable in scrollable equipment panel")
	game.hud._refs["climate_fund:drainage"].pressed.emit()
	check(game.hud._refs["climate_fund:drainage"].disabled and not game.state.climate.data.protection.pending.has("drainage") and game.state.coins == 4000000.0, "construction purchase is gated to Winter")
	game.hud.close_panel()
	game._advance_simulation(45.0)
	game.hud.update_state(game.state)
	check(game.hud._climate_effect.visible and game.hud._climate_effect.event == "flood", "flood produces a lightweight weather overlay")
	check(game.hud._weather_button.visible and game.hud._weather_button.picture.id == "rain" and not game.hud._weather_button.picture.warning and game.hud._weather_button.tooltip_text.to_upper().contains("FLOOD"), "dedicated weather shortcut shows active flood after its warning ends")
	await shot("climate-flood")
	game._on_action("climate")
	game.hud.close_panel()
	# Finish the weather cycle before crossing the overdraft limit.
	game._advance_simulation(105.0)
	game.state.coins = game.state.OVERDRAFT_LIMIT + game.state.ledger.fixed_cost_total() - 1
	game.state.season_clock.season = 2
	game.state.season_clock.seconds = 149.75
	game.state.update(0.25)
	for _i in range(3):
		game._advance_simulation(10.0)
	game.hud.update_state(game.state)
	var page: Control = game.hud._run_end
	await create_timer(0.75).timeout
	check(page.visible and page.headline.text == "FORECLOSED", "overdraft bankruptcy opens the editorial page")
	check(page.detail.text.contains("overdraft") and page._event.text.contains("YEAR 1") and page._threshold.text.contains("200,000"), "foreclosure shows the overdraft boundary and accounting year")
	check(page._metrics["FIELD LOST"].note.text.contains(str(game.state.climate.data.collapse.field_total)), "field loss metric comes from actual damage")
	check(page._event.text.contains("SPUD VALLEY"), "collapse identifies the farm")
	check(not game.hud._climate_effect.visible, "collapse clears ordinary HUD and weather effects")
	await shot("climate-bankruptcy")
	check(page._final_rows.is_visible_in_tree(), "foreclosure opens on the final ledger")
	page._summary_button.pressed.emit()
	check(not page._final_rows.is_visible_in_tree(), "final ledger can collapse")
	page._summary_button.pressed.emit()
	check(page._final_rows.is_visible_in_tree() and page._final_rows.get_children().any(func(row): return row.caption.text == "Living costs") and page._final_rows.get_children().any(func(row): return row.caption.text == "Mortgage"), "view accounts reveals applicable living cost and mortgage categories")
	await shot("climate-summary")
	for dimensions: Vector2i in [Vector2i(1024, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		await frames()
		page._scroll.scroll_vertical = 0
		await frames()
		var screen: Rect2 = game.hud.root.get_global_rect().grow(1.0)
		for item in [page.headline, page._balance, page._summary_button, page.find_child("TryAgain", true, false)]:
			check(screen.encloses(item.get_global_rect()), "editorial content and actions fit " + str(dimensions))
		page._scroll.ensure_control_visible(page._final_rows)
		await frames()
		check(page._final_rows.get_global_rect().end.y <= page._scroll.get_global_rect().end.y + 1, "scroll reaches the last annual category at " + str(dimensions))
	# Grouped balances must fit the same authored composition.
	game.state.ledger.post(1, 3, "other", "Grouped balance fixture", -12345 - game.state.coins)
	game.state.climate.capture_collapse(game.state)
	page.show_report(game.state)
	await frames()
	check(page._balance.text == "-\uE000 12,345" and game.hud.root.get_global_rect().encloses(page._balance.get_global_rect()), "negative balance remains legible")
	page.find_child("TryAgain", true, false).pressed.emit()
	await frames()
	check(not game.state.run_over and not page.visible and game.tutorial.active, "Try Again returns to a clean tutorial")
	game.tutorial.finish()
	game.hud.update_state(game.state)
	check(not game.hud._climate_effect.visible and game.hud._tool_buttons.hoe.is_visible_in_tree(), "normal farming controls and tone return after collapse")
	game.state.coins = 40000000000000
	game.state.expansion = 1
	for plot in game.state.plots: plot.unlocked = true
	game.hud.close_panel()
	game.state.climate.begin_warning(game.state, "storm", 1.0)
	game._advance_simulation(45.0)
	game.hud.update_state(game.state)
	game.hud._climate_alert.dismiss()
	await create_timer(1.0).timeout
	game._update_weather_shake(0.01)
	check(absf(game.world.camera.h_offset) > 0.0 and absf(game.world.camera.h_offset) <= 0.26, "storm impact adds bounded camera shake")
	check(game.hud._climate_effect.strength > 0.8 and game.climate_audio.wind.playing, "storm uses strong wind, rain and ambient sound")
	await shot("climate-storm")
	game._on_action("menu")
	await shot("climate-menu")
	game.hud.close_panel()
	game._on_action("climate")
	await shot("climate-protection")
	game.queue_free()
	await frames()
	# Headless frames can finish before the audio mixer releases stopped voices.
	await create_timer(0.1).timeout
	print("CLIMATE GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
