extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Ledger = preload("res://scripts/ledger.gd")
const SAVE := "user://ledger_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func purse(farm) -> void:
	var sum: float = 0
	for entry in farm.ledger.entries: sum += float(entry.amount)
	check(farm.coins == Ledger.STARTING_CASH + sum, "purse equals opening cash plus every journal entry")
func fresh():
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 6
	return farm
func winter(farm) -> void:
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
func run() -> void:
	var farm = fresh()
	check(farm.coins == 2000 and farm.ledger.entries.is_empty(), "opening cash is not counted as income")
	purse(farm)
	farm.buy_seeds("russet", 2)
	check(farm.ledger.total(1, "seeds") == -22.5, "seed purchase has its own signed category")
	purse(farm)
	farm.storage.russet = 3
	farm.sell_crop("russet", 2)
	check(farm.ledger.total(1, "sales") == 30, "sale is posted at the actual quote")
	purse(farm)
	farm.upgrade_tool("hoe"); farm.upgrade_barn(); farm.expand_field()
	check(farm.ledger.total(1, "upkeep") == -300 and farm.ledger.total(1, "storage") == -300 and farm.ledger.total(1, "rent") == -1200, "upgrades and expansion are categorized")
	farm.climate.fund(farm, "irrigation")
	check(farm.ledger.total(1, "protection") == -500, "protection posts through the same ledger")
	purse(farm)
	farm.coins = 1000
	check(farm.ledger.total(1, "other") != 0 and farm.coins == 1000, "setting a test balance posts an adjustment")
	farm.apply_debug(2)
	purse(farm)
	farm.ledger.post(1, 0, "contracts", "Direct journal receipt", 12.25)
	purse(farm)
	var copy: Array = farm.ledger.entries
	copy[0].amount = 99999
	purse(farm)
	check(farm.ledger.total(1, "seeds") == -22.5, "journal snapshots cannot edit posted entries")
	var before: Dictionary = farm.ledger.save_data()
	check(not farm.ledger.post(1, 0, "unknown", "Bad", 1) and not farm.ledger.post(1, 0, "other", "Bad", NAN) and farm.ledger.save_data() == before, "invalid postings are atomic")
	var activities = preload("res://scripts/island_activities.gd").new()
	activities.setup(farm)
	root.add_child(activities)
	activities.hire_duck(); activities.train_ducks()
	check(farm.ledger.total(1, "labour") < 0, "duck hiring and training post labour costs")
	purse(farm)
	activities.free()
	farm.quest_progress.starter_crash = farm.QUEST_TARGETS.starter_crash
	var other_before: float = farm.ledger.total(1, "other")
	farm.claim_quest("starter_crash")
	check(farm.ledger.total(1, "other") == other_before + farm.QUEST_REWARD, "quest cash is journaled")
	purse(farm)
	farm.reset_game()
	farm.storage.russet = 10000
	farm.sell_crop("russet")
	check(farm.coins == 152000 and farm.ledger.total(1, "sales") == 150000, "sales never silently cap proceeds outside the journal")
	purse(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.coins == 152000, "uncapped receipts round-trip through the journal")
	farm.reset_game()
	farm.coins = -5000
	var count: int = farm.ledger.entries.size()
	farm.buy_seeds("russet", 1)
	check(farm.coins == -5000 and farm.ledger.entries.size() == count, "purchase cannot exceed the overdraft")
	farm.coins = -4988.75
	farm.buy_seeds("russet", 1)
	check(farm.coins == -5000 and not farm.run_over, "last affordable seed can reach the exact limit")
	farm.free()

	farm = fresh()
	farm.boundary_save_path = SAVE
	farm.season_changed.connect(func():
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		check(farm._valid_save(saved) and saved.ledger == JSON.parse_string(JSON.stringify(farm.ledger.save_data())), "complete accounts save before the boundary is presented"))
	farm.update(450)
	check(farm.season_clock.winter_menu and farm.coins == -2500, "full headless year posts 4500 costs against 2000 opening cash")
	check(farm.ledger.total(1, "mortgage") == -2000 and farm.ledger.total(1, "rent") == -500 and farm.ledger.total(1, "living") == -1500 and farm.ledger.total(1, "upkeep") == -500, "Winter fixed cost table matches the plan")
	check(farm.ledger.loan_remaining() == 19000, "principal reduces the original 20000 loan")
	check(farm.ledger.entries.all(func(e): return e.year == 1 and e.season == 3), "fixed charges belong to Winter")
	before = farm.ledger.save_data()
	check(not farm.ledger.post_fixed_costs(1) and farm.ledger.save_data() == before, "Winter charges post only once")
	check(farm.load_game(SAVE) and farm.ledger.save_data() == before and not farm.ledger.post_fixed_costs(1), "save/load cannot duplicate annual charges")
	var saved: Dictionary = farm._save_data()
	check(not saved.has("coins"), "save contains no independent purse")
	saved.coins = 777
	check(not farm._valid_save(saved), "a forged separate purse is rejected")
	saved = farm._save_data(); saved.ledger.entries[0].amount = "bad"
	check(not farm._valid_save(saved), "malformed entries fail validation")
	for defect in ["missing_charge", "duplicate_charge", "missing_close", "future_entry"]:
		saved = farm._save_data()
		match defect:
			"missing_charge": saved.ledger.entries.pop_back()
			"duplicate_charge": saved.ledger.entries.append(saved.ledger.entries[0].duplicate())
			"missing_close": saved.ledger.closed_years.clear()
			"future_entry": saved.ledger.entries[0].year = 2
		check(not farm._valid_save(saved), "reject inconsistent accounts: " + defect)
	purse(farm)
	farm.free()

	for opening in [-500.0, -501.0]:
		farm = fresh()
		farm.coins = opening
		farm.season_clock.season = 2
		farm.season_clock.seconds = 149.5
		farm.update(0.25)
		check(not farm.run_over and farm.coins == opening, "no foreclosure before Winter costs")
		farm.update(0.25)
		check(farm.coins == opening - 4500 and farm.run_over == (opening == -501), "one coin distinguishes survival at -5000 from foreclosure at -5001")
		if farm.run_over:
			check(farm.run_outcome == "foreclosed" and farm.climate.data.collapse.year == 1 and farm.climate.data.collapse.year_net == farm.ledger.total(1), "foreclosure records the year's ledger and cause")
			check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_over, "foreclosure survives reload")
		purse(farm)
		farm.free()
	farm = fresh()
	farm.coins = -5001
	check(not farm.run_over, "a midyear balance below the limit waits for annual assessment")
	winter(farm)
	check(farm.run_over, "midyear shortfall forecloses at annual assessment")
	farm.free()

	farm = fresh()
	for year in range(1, 11):
		farm.post_money("sales", "Annual crop receipts", 5000 if year % 2 else 4000)
		farm.update(450)
		check(farm.season_clock.winter_menu and farm.ledger.is_closed(year), "each of ten years has closed accounts")
		purse(farm)
		if year < 10: check(farm.start_next_year(), "solvent farm starts its next year")
	check(farm.run_over and farm.run_outcome == "completed" and not farm.start_next_year(), "ten years end the run without an eleventh")
	check(farm.ledger.total() == 0 and farm.ledger.years_in_profit() == 5 and farm.ledger.best_year().year == 1 and farm.ledger.worst_year().year == 2, "ten-year summary and earliest tied best/worst years")
	check(farm.ledger.category_totals(10).size() == 13 and farm.ledger.year_totals().size() == 10, "all categories and years stay visible")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.run_outcome == "completed", "completed run persists")
	before = farm.ledger.save_data()
	farm.coins += 100; farm.buy_seeds("russet", 1); farm.update(450)
	check(farm.ledger.save_data() == before, "ended run cannot change its accounts")
	farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("LEDGER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.rng.seed = 6
	game.state.boundary_save_path = SAVE
	game.state.update(450)
	await process_frame
	check(game.hud._panel_kind == "winter" and game.hud._refs.accounts_net.text.contains("4,500"), "annual accounts show the year net")
	check((game.hud._modal.get_child(0) as ColorRect).color.a == 1 and game.hud._modal.modulate.a == 1, "opaque paper hides all HUD chrome without a fade")
	for category in Ledger.CATEGORIES:
		check(game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text == Ledger.LABELS[category]), "accounts include " + category)
	game.touch_controls._process(0.1)
	check(not game.touch_controls.fullscreen.visible, "accounts hide the native fullscreen chrome")
	if "--capture" in OS.get_cmdline_user_args(): await capture("accounts")
	game.state.post_money("other", "Winter adjustment", 10)
	game.hud.update_state(game.state)
	check(game.hud._refs.accounts_other.text == game.state.money(10) and game.hud._refs.accounts_net.text.contains("4,490"), "open accounts refresh from new journal entries")
	if "--touch-controls" in OS.get_cmdline_user_args():
		root.size = Vector2i(390, 844)
		for frame in range(5): await process_frame
		game.touch_controls._process(0.3)
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "portrait accounts stay inside the screen")
		check(game.hud._modal_trade_footer.is_visible_in_tree(), "portrait keeps next-year actions reachable")
		if "--capture" in OS.get_cmdline_user_args(): await capture("accounts-phone")
	game.state.start_next_year()
	game.state.update(450)
	await process_frame
	check(game.hud._run_end.visible and game.hud._run_end.headline.text == "FORECLOSED" and game.hud._run_end._event.text.contains("YEAR 2"), "foreclosure reuses the editorial page with the last accounting year")
	game.touch_controls._process(0.1)
	for frame in range(3): await process_frame
	check(game.hud._run_end._balance.size.x >= 265, "foreclosure balance stays legible on narrow screens")
	check(not game.touch_controls.fullscreen.visible, "foreclosure hides fullscreen chrome")
	if "--capture" in OS.get_cmdline_user_args(): await capture("foreclosure")
	game.state.reset_game()
	for year in range(1, 11):
		game.state.post_money("sales", "Harvest receipts", 5000)
		game.state.update(450)
		if year < 10: game.state.start_next_year()
	check(game.hud._panel_kind == "winter" and not game.hud._run_end.visible, "successful year ten shows accounts before a summary, not foreclosure")
	game._on_action("run_summary")
	check(game.hud._modal_title.text == "Ten years on the farm" and game.hud._modal_trade_footer.find_children("*", "Button", true, false).any(func(button): return button.text == "New Run"), "ten-year summary offers New Run")
	if "--capture" in OS.get_cmdline_user_args(): await capture("ten-years")
	game._on_action("reset")
	check(game.state.coins == 2000 and game.state.ledger.entries.is_empty() and not game.state.run_over and game.state.season_clock.year == 1, "New Run resets the journal and calendar")
	game.queue_free()
	await process_frame
	# Let the audio mixer release the final run-end playback before exit.
	await create_timer(0.25).timeout
func capture(label: String) -> void:
	await create_timer(0.8).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/ledger-" + label + ".png")
