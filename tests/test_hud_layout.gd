extends SceneTree
## Farming masthead, live Winter work note and ledger presentation.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	game.hud.advance_panel_entrance(game.hud.ACCOUNTS_ENTRANCE_SECONDS)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png("res://artifacts/hud-layout-" + name + ".png") == OK, "render " + name)

func noninteractive(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not noninteractive(child):
			return false
	return true

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
	game.hud.close_panel()
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud.set_context("")
	check(not game.hud._context_box.visible, "empty farm context leaves no dark empty bar")
	game.hud.set_context("Russet · Ready to harvest · E")
	check(game.hud._context_box.visible, "actual crop interactions retain their context")
	game.hud.set_context("")
	var hint_removed: bool = true
	for label: Node in game.hud.root.find_children("*", "Label", true, false):
		if label.text == "WASD walk · Wheel zoom · I inventory":
			hint_removed = false
	check(hint_removed, "persistent movement/zoom/inventory hint is removed")
	check(not game.hud._tool_caption.visible, "equipped-tool control hint is absent from the persistent HUD")
	check(game.hud._tool_buttons.size() == 5 and game.hud.root.get_node("MainMenuButton").visible, "five tools and menu remain available")
	check(game.hud._top.coins.is_visible_in_tree() and game.hud._top.price.is_visible_in_tree(), "money and selected crop quote remain visible")
	check(noninteractive(game.hud._top.coins.get_parent().get_parent().get_parent()), "noninteractive stats pass camera gestures through")
	var hotbar: Control = game.hud.root.get_node("ToolHotbar")
	await process_frame
	check(game.hud._top.coins.get_parent().get_parent().get_parent().size.y <= 74.0, "numeric stats keep their compact height without symbol-font padding")
	check(absf(game.hud._quick_sell.get_global_rect().end.y - hotbar.get_global_rect().end.y) < 1.0, "sell action aligns with the bottom of the tool hotbar")
	for island in [1]:
		game.state._refresh_market()
		game.hud.update_state(game.state)
		game.hud._process(0.01)
		game.hud._toast_box.hide()
		game.hud._context_box.hide()
		await process_frame
		await shot("island-" + str(island))
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
		game.state.update(0.02)
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
	game.state._refresh_market()
	game.hud.update_state(game.state)
	game.hud._process(0.01)
	root.size = Vector2i(960, 600)
	await process_frame
	await shot("compact")
	game.hud.set_tool("plant")
	check(game.hud._crop_row.visible, "seed tool reveals seed controls without the extra tracked-price strip")
	await shot("compact-seeds")
	game.hud.set_tool("water")
	check(not game.hud._crop_row.visible, "leaving seeds returns to the clean farm view")
	game._on_action("help")
	var drag_explained: bool = false
	var zoom_explained: bool = false
	for label: Node in game.hud._body.find_children("*", "Label", true, false):
		drag_explained = drag_explained or label.text.contains("Hold click + drag")
		zoom_explained = zoom_explained or label.text.contains("Mouse wheel / pinch")
	check(drag_explained and zoom_explained, "controls explain held-click camera dragging and wheel or pinch zoom")
	await winter_pages()
	game.queue_free()
	await process_frame
	# Let the audio mixer release the last stopped NPC playback under parallel runs.
	await create_timer(0.4).timeout
	print("HUD LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func winter_pages() -> void:
	game.year_intro.stop()
	game.state.climate_report_open = false
	game.state.tutorial_active = false
	game.state.tutorial_progress.completed = true
	game.hud.set_tutorial({})
	game.hud.close_panel()
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.storage.russet = game.state.Stock.pile(20, 90)
	game.state.season_clock.year = 3
	game.state.update(450)
	game.hud.update_state(game.state)
	check(game.hud._panel_kind == "accounts", "accounts open before Winter jobs")
	check(not game.hud._season_jobs.visible, "Winter jobs stay hidden while accounts pause")
	check(game.hud._body.find_child("LedgerYearStamp", true, false) != null, "accounts stamp the year")
	check(game.hud._refs.has("ledger_screenshot"), "annual accounts offer a screenshot")
	check(game.hud._modal.get_child(0).color.a < 1 and game.hud._modal_card.get_theme_stylebox("panel").get_meta("surface_fill") == game.hud.INK, "ledger has an ink frame over the visible farm")
	game.hud.close_panel()
	game.state.climate.data.protection.pending.rainwater = 1
	game.state.climate.data.projects.frost = 1
	game.state.interact_plot(0, "hoe")
	game.state.plots[1].crop = "icecap"
	game.state.plots[1].stage = 3
	game.state.plots[1].yield_total = 2
	game.state.climate.begin_warning(game.state, "blizzard", 0.5)
	game.hud.update_state(game.state)
	var note = game.hud._season_jobs
	check(note.visible, "Winter note appears after accounts close")
	check(not game.hud._climate_alert.visible, "the Winter blizzard line replaces the overlapping transient banner")
	check(note.lines.get_child(0).name == "WinterJob_blizzard", "the urgent blizzard action stays above the job scroll")
	for key in ["ice", "stores:russet", "project:rainwater", "covers", "ripe", "seed", "business:grower", "blizzard"]:
		check(note.jobs.has(key), "live Winter job: " + key)
	var previous_seeds: int = game.state.seed_inventory.russet
	game.state.seed_inventory.russet = game.state.MAX_INVENTORY - 1
	check(note.available().seed[0].begins_with("1 t"), "seed job respects remaining seed space")
	game.state.seed_inventory.russet = previous_seeds
	check(note.jobs["project:rainwater"][0].contains("1 / 3"), "paid project shows actual work")
	check(note.quote_key.visible and note.quote_key.text.contains("now → late Winter"), "one key explains current and late-Winter store quotes")
	check(note.jobs["stores:russet"][0].contains("%s → %s/t" % [game.state.market_money(game.state.trading.stored_price(game.state, "russet", "Table")), game.state.market_money(game.state.trading.peak_price("russet", "Table"))]), "stores show actual current and rising prices")
	note.heading.pressed.emit()
	check(note.collapsed and not note.scroll.visible and note.heading.text.contains("jobs left"), "Winter card collapses with a live count")
	note.heading.pressed.emit()
	var first_ice: int = game.pending_plot
	game.hud._act("winter_walk:ice")
	check(game.pending_plot != first_ice and game.pending_tool == "hoe", "ice job walks to a frozen bed with Hoe")
	game._cancel_walk()
	game.hud._act("winter_walk:ripe")
	check(game.pending_plot == 1 and game.pending_tool == "harvest", "Icecap job walks to ripe Winter crop")
	game._cancel_walk()
	game.state.climate.data.protection.pending.erase("rainwater")
	note.refresh()
	check(note.completed.has("project:rainwater") and not note.jobs.has("project:rainwater"), "completed project ticks off")
	game.hud.show_panel("barn", game.state)
	check(game.hud._panel_kind == "barn" and game.hud._refs.has("upgrade:barn"), "Winter barn keeps capacity and crate shelves")
	game.hud._act("sell_potatoes")
	check(game.hud._panel_kind == "sell_potatoes" and game.hud._refs.market_page.stored_mode, "barn Sell opens the market on rising stores")
	game.hud.close_panel()
	root.min_size = Vector2i.ZERO
	for dimensions in [Vector2i(1280, 800), Vector2i(390, 844)]:
		game.touch_controls.enabled = dimensions.x < 600
		if game.touch_controls.enabled: game.touch_controls._build_touch_sheets()
		root.size = dimensions
		for frame in range(12): await process_frame
		game.touch_controls.resize(); note.refresh()
		# This fixture freezes HUD processing. Fill the live status explicitly,
		# then run the same HUD layout updates that follow its wrapped text in play.
		if game.touch_controls.enabled: game.touch_controls._process(.21)
		for frame in range(8):
			await process_frame
			game.hud._process(.01)
		if game.touch_controls.enabled:
			check(game.touch_controls.status.text.contains(game.state.climate_info().name), "phone layout includes the live blizzard status")
			check(not note.get_global_rect().intersects(game.touch_controls.status.get_global_rect()), "Winter note clears the phone's live weather status")
		await shot("winter-jobs-%d" % dimensions.x)
	game.state.season_clock.season = 0
	note.refresh()
	check(not note.visible and note.jobs.is_empty(), "Spring has no Winter to-do list")
