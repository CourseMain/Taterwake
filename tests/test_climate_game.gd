extends SceneTree
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
	await frames()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.state.coins = 1e12
	game._advance_simulation(300.0)
	check(game.state.climate.data.phase == "calm" and not game.state.climate.data.introduced, "Island 1 never starts climate disasters")
	game.state.island2_unlocked = true
	for plot in game.state.island_plots["2"]: plot.unlocked = true
	game.state.travel_to(2)
	check(game.state.climate.data.intro_pending and game.hud._climate_alert.introduction, "first arrival presents the Island 2 climate introduction")
	var intro_elapsed: float = game.state.elapsed
	game._advance_simulation(120.0)
	check(game.state.elapsed == intro_elapsed, "introduction pauses taxes, crops and weather")
	await shot("climate-introduction")
	game.hud._climate_alert.action.pressed.emit()
	check(not game.state.climate.data.intro_pending and game.hud._panel_kind == "climate", "one clear introduction button opens protection choices")
	game.state.barn_level = 3
	game.state._recompute_capacity()
	game.state.storage.russet = 1000
	# Keep unrelated random pests outside this flood's preparation window.
	game.state.pest_timer = 100.0
	for plot in game.state.plots:
		if not plot.unlocked: continue
		game.state._clear_crop(plot)
		plot.tilled = true
		plot.stage = 1
		plot.crop = "russet"
	game._on_action("climate")
	check(game.hud._panel_kind == "climate" and game.hud._refs.has("climate_fund:drainage"), "climate initiatives open from the controller")
	check(game.hud._refs.climate_reference.text.contains("$8B") and not game.hud._refs.climate_reference.is_visible_in_tree(), "balancing details stay available behind an optional toggle")
	game.state.climate.begin_warning(game.state, "flood", 1.0)
	game.hud.update_state(game.state)
	check(game.hud._refs.climate_status.text.contains("45s") and game.hud._refs.climate_status.text.to_upper().contains("FLOOD"), "warning names the disaster and preparation time")
	check(game.hud._climate_effect.visible and game.state.climate.data.field_lost == 0, "warning builds weather atmosphere without early damage")
	await shot("climate-warning")
	game.hud._climate_alert.dismiss()
	await shot("climate-prepare")
	var frame: Rect2 = game.hud._modal_card.get_global_rect()
	for id in ["rainwater", "drainage", "barn", "windbreaks"]:
		check(game.hud._refs["climate_fund:"+id].is_visible_in_tree(), "protection purchases remain reachable in scrollable equipment panel")
	game.hud._refs["climate_fund:drainage"].pressed.emit()
	check(game.state.climate.data.projects["2"].get("drainage") == 1 and game.state.coins == 998500000000.0, "initiative button buys exactly one local level")
	game.hud.close_panel()
	game._advance_simulation(45.0)
	game.hud.update_state(game.state)
	check(game.hud._climate_effect.visible and game.hud._climate_effect.event == "flood", "flood produces a lightweight weather overlay")
	check(game.hud._blind_labels.weather.visible and game.hud._blind_labels.weather.text.to_upper().contains("FLOOD"), "existing tax card carries the current weather warning")
	await shot("climate-flood")
	game._on_action("climate")
	check(game.hud._refs.climate_market.text.contains("Seeds +70%") and game.hud._refs.climate_market.text.contains("$9.4B"), "market disruption and protection-adjusted recovery costs appear together")
	game.hud.close_panel()
	# Crashes no longer advance tax collection; let the market recover first.
	game._advance_simulation(105.0)
	game.state.coins = 10000.0
	game.state.blind_cycle.tax_rolled = true
	for _i in range(3):
		game.state._start_surge()
		game._advance_simulation(10.0)
	game.hud.update_state(game.state)
	var page: Control = game.hud._run_end
	await create_timer(0.75).timeout
	check(page.visible and page.headline.text == "BANKRUPT", "climate recovery bankruptcy opens the editorial page")
	check(page.detail.text.contains("Recovery costs") and page._event.text.to_upper().contains("FLOOD"), "collapse shows its cause and actual climate event")
	check(page._metrics["FIELD LOST"].note.text.contains("48") and page._metrics["BARN LOST"].note.text.contains("270"), "loss metrics come from actual damage")
	check(page._context.text.contains("Farmer build") and page._context.text.contains("market"), "collapse includes build and market context")
	check(not game.hud._blind_card.visible and not game.hud._climate_effect.visible, "collapse clears ordinary HUD and weather effects")
	await shot("climate-bankruptcy")
	page._summary_button.pressed.emit()
	check(page._summary.is_visible_in_tree() and page._summary.text.contains("1 protection upgrades"), "view run summary reveals recorded projects and run totals")
	await shot("climate-summary")
	for dimensions: Vector2i in [Vector2i(1024, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		await frames()
		var screen: Rect2 = game.hud.root.get_global_rect().grow(1.0)
		for item in [page.headline, page._balance, page._summary, page._summary_button, page.find_child("TryAgain", true, false)]:
			check(screen.encloses(item.get_global_rect()), "editorial content and actions fit " + str(dimensions))
	# Long scientific balances must fit the same authored composition.
	game.state.climate.data.collapse.balance = -8.4e103
	page.show_report(game.state)
	await frames()
	check(page._balance.text == "-$8.4e103" and game.hud.root.get_global_rect().encloses(page._balance.get_global_rect()), "huge negative balance remains legible")
	page.find_child("TryAgain", true, false).pressed.emit()
	await frames()
	check(not game.state.run_over and not page.visible and game.tutorial.active, "Try Again returns to a clean tutorial")
	game.tutorial.finish()
	game.hud.update_state(game.state)
	check(game.hud._blind_card.visible and not game.hud._climate_effect.visible and game.hud._tool_buttons.hoe.is_visible_in_tree(), "normal farming controls and tone return after collapse")
	game.state.coins = 1e12
	game.state.island2_unlocked = true
	for plot in game.state.island_plots["2"]: plot.unlocked = true
	game.state.travel_to(2)
	game.hud._climate_alert.action.pressed.emit()
	game.hud.close_panel()
	game.state.climate.begin_warning(game.state, "storm", 1.0)
	game._advance_simulation(45.0)
	game.hud.update_state(game.state)
	game.hud._climate_alert.dismiss()
	await create_timer(1.0).timeout
	game._update_stock_shake(0.01)
	check(absf(game.world.camera.h_offset) > 0.0 and absf(game.world.camera.h_offset) <= 0.26, "storm impact adds bounded camera shake")
	check(game.hud._climate_effect.strength > 0.8 and game.climate_audio.wind.playing, "storm uses strong wind, rain and ambient sound")
	await shot("climate-storm")
	game._on_action("menu")
	await shot("climate-menu")
	game.hud.close_panel()
	game._on_action("taxes")
	await shot("climate-taxes")
	game.queue_free()
	await frames()
	# Headless frames can finish before the audio mixer releases stopped voices.
	await create_timer(0.1).timeout
	print("CLIMATE GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
