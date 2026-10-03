extends SceneTree
## Object-shaped pages at desktop and actual phone pixel widths.
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + words)
func settle() -> void:
	for frame in range(12): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(); game.set_process(false); game.hud.set_process(false)
	game.state.tutorial_progress.completed = true; game.hud.set_tutorial({})
	game.state.season_clock.year = 3; game.state.coins = 80000
	for crop in game.state.CROP_IDS: game.state.storage[crop] = game.state.Stock.pile(12)
	game.state.ledger.post_fixed_costs(2)
	game.state.ledger.post_fixed_costs(3)
	game.state.ledger.post(3, 2, "sales", "Table Russet · 12 t", 5184)
	game.state.ledger.post(3, 0, "seeds", "Russet seed", -3240)
	game.state.climate.data.outlook.records.append({"year":2, "season":1, "event":"storm", "severity":0.5})
	game.state.ClimateSystem.Protection.record(game.state, "autumn_cold", "russet", 3, 0.0, 1.0, "Harvest before Winter", "field", 2)
	game.hud._climate_alert.dismiss(); game.hud._toast_box.hide()
	var pages: Array = ["market", "sell_potatoes", "quests", "loss_notices", "climate", "contracts", "barn", "tools", "front_page", "winter_stores", "accounts", "run_summary", "foreclosure"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="): pages = [arg.trim_prefix("--page=")]
	root.min_size = Vector2i.ZERO
	for dimensions in [Vector2i(1280, 800), Vector2i(390, 844)]:
		game.touch_controls.enabled = dimensions.x < 600
		if game.touch_controls.enabled: game.touch_controls._build_touch_sheets()
		root.size = dimensions; await settle()
		for kind in pages:
			game.state.climate.data.phase = "calm"; game.state.climate.data.event = ""; game.state.climate.data.timer = 0
			game.state.season_clock.year = 3; game.state.run_outcome = ""; game.state.run_over = false
			if kind == "run_summary":
				game.state.run_outcome = "completed"; game.state.season_clock.year = 10
			game.state.season_clock.season = 3 if kind in ["climate", "winter_stores", "accounts", "run_summary"] else 0
			if kind == "sell_potatoes":
				game.state.elapsed = 18.0; game.state._refresh_market()
			if kind == "winter_stores":
				game.state.season_clock.seconds = 140
				for crop in game.state.CROP_IDS: game.state.trading.held[crop] = game.state.Stock.pile(8)
			if kind == "foreclosure":
				var saved_ledger: Dictionary = game.state.ledger.save_data()
				game.hud.close_panel(); game.state.coins = -210000; game.state.run_outcome = "foreclosed"; game.state.run_over = true; game.state.climate.capture_collapse(game.state)
				game.hud.update_state(game.state); game.touch_controls.resize(); await settle()
				var final_page = game.hud._run_end
				check(final_page._final_rows.is_visible_in_tree(), "foreclosure opens its final ledger")
				if "--capture" in OS.get_cmdline_user_args():
					RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/segment19-foreclosure-%d.png" % dimensions.x)
					final_page._scroll.scroll_vertical = 100000; await settle(); RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/segment19-foreclosure-%d-end.png" % dimensions.x)
				final_page.hide(); game.state.ledger.load_data(saved_ledger); game.state.run_over = false; game.state.run_outcome = ""; game.hud.update_state(game.state); continue
			if kind == "front_page":
				game.hud.close_panel(); game.year_intro.present(game.state); await settle(); game.year_intro.elapsed = 1.0; game.year_intro._process(0)
				var front_scale: float = minf(float(root.size.x) / game.year_intro.size.x, float(root.size.y) / game.year_intro.size.y)
				for control in game.year_intro.find_children("*", "Button", true, false):
					if control.is_visible_in_tree(): check(minf(control.size.x, control.size.y) * front_scale >= 43.9, "newspaper target " + control.text)
				if "--capture" in OS.get_cmdline_user_args():
					RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/segment19-front_page-%d.png" % dimensions.x)
				game.year_intro.stop(); continue
			game.hud.show_panel(kind, game.state); await settle(); game.touch_controls.fit_modal(); await settle()
			var bounds: Rect2 = game.hud.root.get_global_rect().grow(1)
			check(bounds.encloses(game.hud._modal_card.get_global_rect()), kind + " modal fits " + str(dimensions))
			var scroll: ScrollContainer = game.hud._body.get_parent()
			check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 1, kind + " fits width")
			var scale: float = float(root.size.x) / game.hud.root.size.x
			if kind in ["market", "sell_potatoes", "winter_stores"]:
				var navigation: HBoxContainer = game.hud._modal_market_nav
				check(navigation.is_visible_in_tree() and navigation.get_child_count() == 2, "shop has Buy and Sell above its contents")
				check(navigation.get_child(0).text == "Buy" and navigation.get_child(1).text == "Sell", "shop navigation labels")
				check(navigation.get_child(0).button_pressed == (kind == "market") and navigation.get_child(1).button_pressed == (kind != "market"), "shop highlights the active counter")
			for button in game.hud._modal_card.find_children("*", "Button", true, false):
				if button.is_visible_in_tree(): check(minf(button.size.x, button.size.y) * scale >= 43.9, kind + " target " + button.text)
			if kind == "accounts":
				for category in game.state.Ledger.CATEGORIES:
					var ledger_row = game.hud._refs["accounts_" + category].get_parent().get_parent()
					check(ledger_row.caption.text == game.state.Ledger.LABELS[category], "ledger label stays frozen")
					check(ledger_row.visible == not is_zero_approx(game.state.ledger.total(3, category)), "ledger shows only applicable categories")
			if kind == "sell_potatoes":
				var sale = game.hud._refs.market_page
				check(not sale.trade_open, "sale stepper waits for a grade chip")
				for crop in sale.sale_rows:
					for grade in sale.sale_rows[crop].grades:
						check(sale.sale_rows[crop].grades[grade].visible == (sale.stock(crop, grade) > 0), "grade chip matches actual tonnes")
			if kind == "market":
				check(game.hud._body.find_child("MaraChalkboard", true, false) != null, "seeds sit on chalkboard")
				check(game.hud._refs.market_page.sale_rows.is_empty() and game.hud._body.find_child("PriceHistory", true, false) == null, "Buy has seed packets without harvested stock or price charts")
				for crop in game.hud._refs.market_page.crops:
					check(not game.hud._refs.has(crop + ":price") and not game.hud._refs.has(crop + ":history"), "packet excludes market statistics")
			if "--capture" in OS.get_cmdline_user_args():
				await create_timer(.25).timeout; RenderingServer.force_draw()
				check(root.get_texture().get_image().save_png("res://artifacts/segment19-%s-%d.png" % [kind, dimensions.x]) == OK, "capture " + kind)
				scroll.scroll_vertical = 100000; await settle(); RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://artifacts/segment19-%s-%d-end.png" % [kind, dimensions.x])
			if kind == "contracts":
				for help_button in game.hud._body.find_children("*", "Button", true, false):
					if help_button.text != "?": continue
					help_button.pressed.emit(); await settle()
					var notes: AcceptDialog = null
					for child in game.hud.root.get_children():
						if child is AcceptDialog: notes = child
					check(notes != null and notes.visible and notes.size.x <= game.hud.root.size.x, "tap opens a fitting explanation")
					if notes != null:
						check(notes.get_label().get_theme_color("font_color") == Color("34362c"), "help text has dark ink on cream")
						check(minf(notes.get_ok_button().size.x, notes.get_ok_button().size.y) * scale >= 43.9, "help dismissal is a phone-sized target: %s, minimum %s, scale %s" % [notes.get_ok_button().size, notes.get_ok_button().custom_minimum_size, scale])
						if "--capture" in OS.get_cmdline_user_args():
							RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/segment19-help-%d.png" % dimensions.x)
						notes.queue_free(); await settle()
			if kind in ["sell_potatoes", "winter_stores"]:
				var sale = game.hud._refs.market_page
				var entry: Dictionary = sale.sale_rows.russet
				entry.grades.Standard.pressed.emit(); await settle()
				check(sale.trade_open and sale.footer.is_visible_in_tree() and sale.selected_grade == "Standard", "stocked chip opens its amount stepper")
				if "--capture" in OS.get_cmdline_user_args():
					scroll.scroll_vertical = 0; await settle(); RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/segment19-%s-%d-stepper.png" % [kind, dimensions.x])
	game.queue_free(); await settle(); await create_timer(.25).timeout
	print("INTERFACE PAGES: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
