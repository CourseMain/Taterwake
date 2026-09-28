extends SceneTree
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.hud._blind_card.visible and not game.hud._run_end.visible, "fresh run shows one tax forecast")
	check(game.hud._blind_labels.balance.text == "\uE000 50K due  ›" and game.hud._blind_card.tooltip_text.contains("\uE000 240"), "fixed target and estimated tax visible before first boom")
	check(game.hud._blind_labels.balance.get_theme_color("font_color") == Color("ff7777") and game.hud._top.coins.get_theme_color("font_color") == Color("bb4334"), "positive balance below tax threshold turns red")
	game.state.coins = 50000.0
	game.hud.update_state(game.state)
	check(game.hud._blind_card.tooltip_text.contains("100% covered") and game.hud._blind_labels.balance.get_theme_color("font_color") != Color("ff7777"), "exactly funded bill removes shortfall red")
	game.state.coins = 240.0
	game.tutorial.start()
	game.hud.update_state(game.state)
	check(not game.hud._blind_card.visible, "guided tutorial keeps blind clutter hidden")
	game.tutorial.finish()
	game.state.coins = 13.8e9
	game.state.island2_unlocked = true
	game.state.travel_to(2)
	game.state.climate.acknowledge(game.state)
	game.state.blind_cycle.kind = "big"
	game.hud.update_state(game.state)
	check(game.hud._blind_labels.balance.text == "\uE000 5B due  ›" and game.hud._blind_card.tooltip_text.contains("\uE000 13.8B"), "HUD compares cash to the amount owed, with no separate blind")
	check(game.hud._blind_card.tooltip_text.contains("After tax \uE000 8.8B"), "tax forecast shows correct projected wallet")
	game.state.blind_cycle.tax_multiplier = 2.5
	game.state.blind_cycle.tax_rolled = true
	game.state._start_surge()
	game.state.update(10.0)
	game.hud.update_state(game.state)
	check(game.hud._blind_labels.balance.text == "\uE000 12.5B due  ›" and game.hud._blind_labels.title.get_theme_color("font_color") == Color("ffb85e"), "Tax Boom remains prominently warned on farm")
	await shot("taxes-tax-boom")
	game._on_action("taxes")
	check(game.hud._panel_kind == "taxes" and not game.hud._blind_card.visible, "forecast opens rules with no duplicate clutter")
	check(not game.hud._blind_modal_warning.visible and game.hud._refs.blind_forecast.text.contains("TAX BOOM"), "tax page keeps its warning without a duplicate banner")
	check(game.hud._refs.blind_forecast.text.contains("+150%"), "detailed forecast matches HUD")
	await shot("taxes-rules")
	game.hud.close_panel()
	game.state.coins = -4e9
	game.hud.update_state(game.state)
	check(game.hud._top.coins.text == "-\uE000 4.0B" and game.hud._blind_labels.debt.text.contains("-\uE000 5B"), "debt and bankruptcy warning share consistent signed formatting")
	await shot("taxes-debt")
	game.state.coins = 18e9
	game.state.blind_cycle.tax_multiplier = 1.0
	game.state._start_surge()
	game._advance_simulation(10.0)
	check(game.state.blind_cycle.clears == 0, "second stock does not collect early")
	game.state._start_surge()
	game._advance_simulation(10.0)
	game.hud.update_state(game.state)
	check(not game.state.run_over and game.state.blind_cycle.last_result.cleared, "controller pays tax after third full selling window")
	game._on_action("taxes")
	check(game.hud._refs.blind_last.text.contains("Last payment · Paid") and game.hud._refs.blind_last.text.contains("3.60× OVERKILL") and game.hud._refs.blind_last.text.contains("Before collection \uE000 18B"), "receipt compares the pre-tax wallet to the collected bill and keeps its rank")
	await shot("taxes-cleared")
	game.hud.close_panel()
	game.state.coins = 1e15
	game.state.coins = -5.001e9
	game.hud.update_state(game.state)
	check(game.hud._run_end.visible and game.hud._run_end_title.text == "BANKRUPT", "bankruptcy interrupts even a roll presentation immediately")
	check(not game.hud.is_panel_open(), "run over hides shopping and cannot be dismissed as a normal modal")
	var elapsed: float = game.state.elapsed
	var position: Vector3 = game.world.player.position
	var snapshot: Dictionary = game.state._save_data().duplicate(true)
	game._process(1.0)
	game._on_action("quick_sell")
	game._on_action("travel:1")
	game._on_action("debug:apply:100:100")
	game.perform_plot(0)
	game.activities.hire_duck()
	game.builds.use_ability()
	check(game.state._save_data() == snapshot and game.state.elapsed == elapsed and game.world.player.position == position, "run end blocks simulation, movement, debug, farming and economy")
	await shot("taxes-bankrupt")
	for dimensions: Vector2i in [Vector2i(1024, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var screen: Rect2 = game.hud.root.get_global_rect()
		check(screen.encloses(game.hud._run_end_title.get_global_rect()) and screen.encloses(game.hud._run_end_detail.get_global_rect()), "run-over screen fits at " + str(dimensions))
	game.hud._act("reset")
	await process_frame
	check(not game.state.run_over and not game.hud._run_end.visible and game.state.coins == 240.0 and game.tutorial.active, "clear New Run button starts a fresh playable tutorial")
	game.tutorial.finish()
	game.state.blind_cycle.tax_rolled = true
	for event in range(3):
		game.state._start_surge()
		game._advance_simulation(10.0)
	game.hud.update_state(game.state)
	check(not game.state.run_over and not game.hud._run_end.visible and game.state.coins < 0.0, "unfunded third stock incurs playable debt rather than a failed-blind screen")
	check(game.hud._blind_labels.balance.get_theme_color("font_color") == Color("ff7777"), "debt remains red on the farm")
	game._on_action("taxes")
	check(game.hud._refs.blind_live.get_theme_color("font_color") == Color("bb4334") and game.hud._blind_modal_warning.get_theme_color("font_color") == Color("bb4334"), "in-menu threshold text also stays red")
	await shot("taxes-borrowed")
	game.hud.close_panel()
	game.state.blind_cycle.tax_rolled = true
	for event in range(3):
		game.state._start_surge()
		game._advance_simulation(10.0)
	game.hud.update_state(game.state)
	check(game.state.run_over and game.hud._run_end_title.text == "BANKRUPT", "a subsequent unpaid bill ends the run only after crossing bankruptcy")
	game.queue_free()
	await process_frame
	print("TAXES GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
