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
	check(game.hud._top.coins.is_visible_in_tree() and game.hud._quick_sell.text.contains("360/t"), "money is in the top band and the quote is on Sell")
	check(noninteractive(game.hud._stats_card), "noninteractive stats pass camera gestures through")
	var hotbar: Control = game.hud.root.get_node("ToolHotbar")
	await process_frame
	check(game.hud._play_band.size.y <= 64.0, "numeric stats keep their compact height without symbol-font padding")
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
	check(game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text == "Net for year %d" % game.state.season_clock.year), "accounts name the year beside the net")
	check(game.hud._refs.has("ledger_screenshot"), "annual accounts offer a screenshot")
	check(game.hud._modal.get_child(0).color == game.hud.Kit.INK and game.hud._modal_card.get_theme_stylebox("panel").get_meta("surface_fill") == game.hud.Kit.PAPER, "ledger uses kit paper over the ink felt")
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
	check(game.hud._climate_alert.visible, "blizzard retains its weather warning outside the jobs list")
	check([str(note.lines.get_child(0).name), str(note.lines.get_child(1).name), str(note.lines.get_child(2).name), str(note.lines.get_child(3).name)] == ["WinterJob_ice", "WinterJob_ripe", "WinterJob_covers", "WinterJob_project_rainwater"], "Winter jobs follow ice, ripe, covers, paid work order: " + str(note.jobs.keys()))
	for key in ["ice", "project:rainwater", "covers", "ripe", "business:grower"]:
		check(note.jobs.has(key), "live Winter job: " + key)
	var previous_seeds: int = game.state.seed_inventory.russet
	game.state.seed_inventory.russet = game.state.MAX_INVENTORY - 1
	check(preload("res://scripts/farm_advice.gd").seed_capacity(game.state, "russet") == 1, "per-crop seed offer respects remaining seed space")
	game.state.seed_inventory.russet = previous_seeds
	check(note.jobs["project:rainwater"][0].contains("1 / 3"), "paid project shows actual work")
	check(note.quote_key.visible and note.quote_key.text.contains("now → late Winter"), "one key explains current and late-Winter store quotes")
	check(note.stores["stores:russet"][0].contains("%s/t now, %s/t late Winter" % [game.state.market_money(game.state.trading.stored_price(game.state, "russet", "Table")), game.state.market_money(game.state.trading.peak_price("russet", "Table"))]), "Stores says now and late Winter beside actual grade-weighted prices")
	check(note.heading.text.contains("%d jobs left" % note.jobs.size()) and not note.jobs.has("seed") and not note.jobs.has("stores:russet"), "job count excludes Stores and seed facts")
	check(note.stores_lines.get_child(-1).text == "Keep some as next Spring's seed", "seed offer is last under Stores with no tonne total")
	check(note.quote_key.get_parent() == note.stores_heading.get_parent() and note.quote_key.get_index() == note.stores_heading.get_index() + 1, "quote key sits under Stores heading")
	check(note.stores_lines.find_children("*", "Button", true, false).is_empty(), "Winter store facts have no alternate selling entrance")
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
	game.hud.show_market(true, game.state)
	check(game.hud._panel_kind == "market" and game.hud._market_selling and game.hud._refs.market_page.stored_mode, "barn directly opens rising Winter store quotes")
	check(not game.hud._refs.has("upgrade:barn"), "barn capacity expansion belongs to Tools")
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
			check(game.hud._weather_button.picture.id == "snow" and game.hud._weather_button.picture.warning, "phone layout includes the live blizzard status")
			check(not note.get_global_rect().intersects(game.hud._weather_button.get_global_rect()), "Winter note clears the phone's live weather status")
		await shot("winter-jobs-%d" % dimensions.x)
	var saved_stores: Dictionary = game.state.trading.held.duplicate(true)
	game.state.trading.held = game.state.Stock.empty()
	note.refresh()
	check(note.stores_heading.text == "Stores · empty" and not note.quote_key.visible, "empty Stores still has an explicit block without quotes")
	game.state.trading.held = saved_stores
	game.state.season_clock.season = 0
	note.refresh()
	check(not note.visible and note.jobs.is_empty(), "Spring has no Winter to-do list")
