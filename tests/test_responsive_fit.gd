extends SceneTree
## Keep every game control reachable when the exported canvas changes shape.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false
const SIZES: Array[Vector2i] = [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(800, 600), Vector2i(640, 360), Vector2i(600, 900)]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	while is_instance_valid(game) and game.hud.accounts_building: await process_frame
	for _frame: int in range(4):
		await process_frame
	if is_instance_valid(game): game.hud.advance_panel_entrance(game.hud.ACCOUNTS_ENTRANCE_SECONDS)

func inside(control: Control, label: String) -> void:
	var bounds: Rect2 = game.hud.root.get_global_rect().grow(0.5)
	check(bounds.encloses(control.get_global_rect()), label + " remains inside the game canvas: " + str(control.get_global_rect()) + " within " + str(bounds))

func shot(label: String) -> void:
	if capture:
		await create_timer(0.18).timeout
		RenderingServer.force_draw()
		check(root.get_texture().get_image().save_png("res://artifacts/responsive-" + label + ".png") == OK, "capture " + label)

func check_menu(label: String) -> void:
	inside(game.hud._modal_card, label + " modal")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, label + " content needs no unavailable horizontal scrolling")
	var close: Control = game.hud._modal_card.get_child(0).get_child(0).get_child(1)
	if close.is_visible_in_tree(): inside(close, label + " close button")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.hud.set_process(false)
	game.state.coins = 80000
	game.hud.update_state(game.state)
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud.set_context("")
	# Desktop minimums do not apply to an embedded web canvas. Exercise those
	# smaller sizes too without changing the saved project/window preference.
	root.min_size = Vector2i.ZERO
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "game keeps its complete layout at every canvas aspect ratio")
	for requested: Vector2i in SIZES:
		root.size = requested
		await settle()
		var tag: String = "%dx%d" % [requested.x, requested.y]
		print("FIT %s: actual window %s, logical canvas %s" % [tag, root.size, game.hud.root.size])
		check(game.hud.root.size.is_equal_approx(Vector2(1280, 800)), tag + " preserves the complete logical canvas")
		game.hud.close_panel()
		game.hud.set_tool("plant")
		game.hud._purchase_box.hide()
		await settle()
		for item: Control in [game.hud._stats_card, game.hud.root.get_node("MainMenuButton"), game.hud.root.get_node("ToolHotbar"), game.hud._quick_sell, game.hud._crop_row]:
			inside(item, tag + " " + item.name)
		check(not game.hud.root.get_node("ToolHotbar").get_global_rect().intersects(game.hud._quick_sell.get_global_rect()), tag + " sell button clears the hotbar")
		for button: Control in game.hud._crop_buttons.values():
			if button.visible:
				inside(button, tag + " seed choice")
		await shot(tag + "-farm")
		game.hud.show_panel("market", game.state)
		game.hud.show_purchase({"kind": "seeds", "id": "sunburst", "name": "Sunburst", "quantity": 5, "cost": 3420.0, "total": 6})
		await settle()
		check_menu(tag + " market")
		inside(game.hud._purchase_box, tag + " purchase receipt")
		check(not game.hud._purchase_box.get_global_rect().intersects(game.hud._modal_card.get_global_rect()), tag + " receipt leaves every market button clear")
		check(not game.hud._crop_row.visible, tag + " open menu hides the seed tray")
		await shot(tag + "-market")
		game.hud._purchase_remaining = 0.0
		game.hud._purchase_receipt.clear()
		game.hud._purchase_box.hide()
	# Every menu uses the same fixed canvas, but each can have its own minimum
	# width. Check the actual content after container layout, not a mock panel.
	for kind: String in ["inventory", "tools", "pause", "dex", "quests", "duck_patrol", "debug", "graphics", "help"]:
		game.hud.show_panel(kind, game.state)
		await settle()
		check_menu(kind)
		if kind in ["inventory", "tools"]:
			game.hud.show_purchase({"kind": "barn" if kind == "inventory" else "tool", "name": "Watering can", "quantity": 200 if kind == "inventory" else 1, "cost": 20000.0, "total": 400, "level": 2})
			await settle()
			inside(game.hud._purchase_box, kind + " upgrade receipt")
			check(not game.hud._purchase_box.get_global_rect().intersects(game.hud._modal_card.get_global_rect()), kind + " receipt leaves upgrade controls clear")
			game.hud._purchase_remaining = 0.0
			game.hud._purchase_receipt.clear()
			game.hud._purchase_box.hide()
		if kind == "debug":
			game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
			game.hud._refs.debug_unlock.pressed.emit()
			await settle()
			check_menu("unlocked debug controls")
	await paper_pages()
	game.queue_free()
	await process_frame
	# Let the audio mixer release the last year-start voice before exit.
	await create_timer(0.25).timeout
	print("RESPONSIVE FIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func paper_pages() -> void:
	game.year_intro.stop()
	game.state.climate_report_open = false
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.tutorial_active = false
	game.hud.set_tutorial({})
	for crop in game.state.CROP_IDS:
		game.state.storage[crop] = game.state.Stock.pile(12, 90)
	game.state.season_clock.year = 3
	game.state.update(450)
	game.hud.close_panel()
	# Keep every kind of work available while the responsive note is measured.
	game.state.climate.data.protection.pending.rainwater = 1
	game.state.climate.data.projects.frost = 1
	game.state.interact_plot(0, "hoe")
	game.state.plots[1].crop = "icecap"
	game.state.plots[1].stage = 3
	game.state.plots[1].yield_total = 2
	for crop in game.state.CROP_IDS:
		game.state.Stock.add(game.state.storage, crop, 6, 90)
		game.state.Stock.add(game.state.storage, crop, 4, 60)
		game.state.Stock.add(game.state.storage, crop, 2, 30)
	if capture:
		root.size = Vector2i(1280, 800)
		await settle()
		for kind in ["accounts", "market", "barn", "inventory", "tools", "climate", "quests", "run_summary"]:
			game.hud.show_panel(kind, game.state)
			await settle()
			await shot("desktop-" + kind)
			(game.hud._body.get_parent() as ScrollContainer).scroll_vertical = int(game.hud._body.size.y)
			await settle()
			await shot("desktop-" + kind + "-end")
		game.hud.close_panel()
		game.year_intro.present(game.state)
		await settle()
		await shot("desktop-front-page")
		game.year_intro.stop()
		game.hud._season_jobs.refresh()
		await settle()
		await shot("desktop-winter-jobs")
		game.hud._run_end.show_report(game.state)
		await settle()
		await shot("desktop-foreclosure")
		game.hud._run_end.hide()
	game.touch_controls.enabled = true
	game.touch_controls._build_touch_sheets()
	for requested: Vector2i in SIZES + [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = requested
		await settle()
		game.touch_controls.resize()
		var tag: String = "%dx%d" % [requested.x, requested.y]
		for kind: String in ["accounts", "market", "barn", "inventory", "tools", "climate", "quests", "run_summary"]:
			game.hud.show_panel(kind, game.state)
			await settle()
			game.touch_controls.fit_modal()
			await settle()
			check_menu(tag + " " + kind)
			if kind == "climate" and requested == Vector2i(390,844):
				var page = game.hud._refs.weather_page
				var fonts: Dictionary = {}
				var sizes: Dictionary = {}
				for text: Control in page.find_children("*", "Control", true, false):
					if text is Label or text is Button:
						fonts[text] = text.get_theme_font("font")
						sizes[text] = text.get_theme_font_size("font_size")
				page._layout()
				for text: Control in fonts:
					check(text.get_theme_font("font") == fonts[text] and text.get_theme_font_size("font_size") == sizes[text], "Weather resize retains its fitted font: " + text.name)
				await settle()
				check_menu(tag + " settled climate")
			if kind == "accounts":
				game.hud._refs.account_records.show()
				await settle()
				check(game.hud._refs.land_bill.text == "Mortgage and land ›" and game.hud._refs.land_amount.text == game.state.money(-60000), tag + " grouped fixed land bill")
				for category in game.state.Ledger.CATEGORIES:
					if category in ["mortgage", "rent"]: continue
					var amount: Label = game.hud._refs["accounts_" + category]
					var row = amount.get_parent().get_parent()
					if not row.visible: continue
					check(amount.get_line_count() == 1 and absf(amount.get_global_rect().get_center().y - row.caption.get_global_rect().get_center().y) < 1, tag + " aligned ledger amount " + category)
			var physical_scale: float = minf(float(root.size.x) / game.hud.root.size.x, float(root.size.y) / game.hud.root.size.y)
			for button in game.hud._modal_card.find_children("*", "Button", true, false):
				if not button.is_visible_in_tree(): continue
				check(minf(button.size.x, button.size.y) * physical_scale >= 43.9, tag + " " + kind + " touch target " + button.text)
			if requested in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]:
				await shot(tag + "-" + kind)
				var scroll: ScrollContainer = game.hud._body.get_parent()
				scroll.scroll_vertical = int(game.hud._body.size.y)
				await settle()
				await shot(tag + "-" + kind + "-end")
			if kind == "accounts" and capture and requested == Vector2i(1280, 800):
				scroll_to_top()
				await settle()
				game.hud._act("ledger_screenshot")
				await settle()
				check(FileAccess.file_exists(game.hud.last_screenshot_path), "screenshot button saves a real PNG to user folder")
		game.hud.close_panel()
		game.year_intro.present(game.state)
		await settle()
		inside(game.year_intro.skip, tag + " newspaper skip")
		var front_scale: float = minf(float(root.size.x) / game.year_intro.size.x, float(root.size.y) / game.year_intro.size.y)
		for control in game.year_intro.find_children("*", "Button", true, false):
			if control.is_visible_in_tree(): check(minf(control.size.x, control.size.y) * front_scale >= 43.9, tag + " newspaper target " + control.text)
		if requested in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]: await shot(tag + "-front-page")
		game.year_intro.stop()
		game.hud._season_jobs.refresh()
		await settle()
		inside(game.hud._season_jobs, tag + " Winter jobs")
		var note = game.hud._season_jobs
		for control in [game.touch_controls.stick, game.touch_controls.tools_button, game.touch_controls.use_button, game.touch_controls.sell_button]:
			check(not note.get_global_rect().intersects(control.get_global_rect()), tag + " Winter note clears " + control.name)
		check(note.scroll.get_global_rect().encloses(note.lines.get_child(0).get_global_rect()), tag + " first Winter job has a fully visible picture, caption and tap target")
		for button in note.find_children("*", "Button", true, false):
			if not button.is_visible_in_tree(): continue
			var available_width: float = button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
			var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			if button.get_parent() == note.stores_lines:
				check(button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and button.size.x <= note.scroll.size.x + 1, tag + " Stores fact wraps within its block: " + button.text)
			else:
				check((button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART or text_width <= available_width + .5) and button.size.x <= note.size.x, tag + " one unclipped Winter job: " + button.text)
			check(minf(button.size.x, button.size.y) * front_scale >= 43.9, tag + " Winter touch target: " + button.text)
		if requested in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]: await shot(tag + "-winter-jobs")
		game.hud._run_end.show_report(game.state)
		await settle()
		inside(game.hud._run_end.find_child("TryAgain", true, false), tag + " foreclosure action")
		if requested in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]: await shot(tag + "-foreclosure")
		game.hud._run_end.hide()

func scroll_to_top() -> void:
	(game.hud._body.get_parent() as ScrollContainer).scroll_vertical = 0
