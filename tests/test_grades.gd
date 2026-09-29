extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Q = preload("res://scripts/crop_quality.gd")
const Stock = preload("res://scripts/graded_stock.gd")
const SAVE = "user://grades_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(note)
func fresh():
	var farm = State.new(); root.add_child(farm)
	farm.coins = 100000
	farm.rng.seed = 6
	for plot in farm.plots: farm._clear_crop(plot); plot.tilled = plot.unlocked
	return farm
func plant(farm, crop: String = "russet") -> void:
	farm.selected_crop = crop; farm.seed_inventory[crop] = 1
	farm.interact_plot(5, "plant")
func winter(farm) -> void:
	farm.season_clock.season = 2; farm.season_clock.seconds = 149.75
	farm.update(0.25)
func run() -> void:
	for item in [[100,"Table"],[80,"Table"],[79,"Standard"],[40,"Standard"],[39,"Feed"],[0,"Feed"]]: check(Q.grade(item[0]) == item[1], "quality threshold %d" % item[0])
	var farm = fresh()
	for crop in State.CROP_IDS:
		check(farm.market[crop].sell == State.CropTable.CROPS[crop].base, "initial quote uses base for " + crop)
		check(State.CropTable.CROPS[crop].seed > 0 and State.CropTable.CROPS[crop].seed <= State.CropTable.CROPS[crop].base, "bounded seed price for " + crop)
	plant(farm)
	check(farm.plots[5].quality == 100, "planting starts quality at 100")
	farm.update(9.75)
	check(farm.plots[5].quality == 100, "dry deduction waits a full ten seconds")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "partial dry-quality interval survives reload")
	farm.update(0.25)
	check(farm.plots[5].quality == 98, "ten seconds growing unwatered costs two")
	farm.interact_plot(5, "water")
	farm.update(75)
	check(farm.plots[5].stage == 3 and farm.plots[5].quality == 98, "watered growth has no ongoing dry quality deduction")
	farm.plots[5].pest_delay = 90
	farm.update(30)
	check(farm.plots[5].quality == 98, "first thirty ripe seconds are free")
	farm.update(10)
	check(farm.plots[5].quality == 93, "next ten ripe seconds cost five")
	farm.plots[5].pests = true; farm.interact_plot(5, "pest")
	farm.update(10)
	check(farm.plots[5].quality == 88, "spraying cannot reset the quality harvest deadline")
	farm._clear_crop(farm.plots[5]); plant(farm)
	farm.plots[5].pests = true
	farm._pest_damage_tick(farm.plots[5])
	check(farm.plots[5].quality == 94, "each actual pest bite costs six quality")
	farm._clear_crop(farm.plots[5]); plant(farm, "icecap")
	Q.deduct(farm, 5, "pests", 6)
	check(farm.plots[5].quality == 89, "inverse resilience makes Icecap quality more fragile")
	for event in ["drought", "flood", "freeze", "storm"]:
		for level in range(3):
			farm._clear_crop(farm.plots[5]); plant(farm)
			farm.climate.data.projects[State.ClimateSystem.Protection.PROJECT_FOR[event]] = level
			farm.climate.data.protection.covers["5"] = {"year":1,"level":level}
			var points: int = 25 if event == "storm" else (15 if event == "freeze" else 4)
			Q.deduct(farm, 5, event, points)
			check(farm.plots[5].quality == 100 - State.ClimateSystem.Protection.loss(points, [0.0,0.5,0.75][level]), "same field-loss formula reduces " + event + " quality at level " + str(level))
	farm.free()
	for event in ["drought", "flood"]:
		farm = fresh(); plant(farm); farm.interact_plot(5, "water")
		farm.climate.begin_warning(farm, event, 0.1); farm.climate._impact(farm)
		farm.climate.data.operations.stress["5"] = 0.1
		farm.update(10)
		check(farm.plots[5].quality == 96, "active " + event + " stress costs four per ten seconds")
		farm.free()
	farm = fresh(); plant(farm); farm.interact_plot(5, "water")
	farm.climate.begin_warning(farm, "freeze", 0.1); farm.climate._impact(farm)
	check(farm.plots[5].quality == 85, "freeze impact takes fifteen once")
	farm.update(10)
	check(farm.plots[5].quality == 81, "frozen bed takes four more per ten seconds")
	farm.interact_plot(5, "hoe"); farm.update(10)
	check(farm.plots[5].quality == 81, "ice clearing stops further quality loss")
	farm.free()
	farm = fresh(); plant(farm); farm.interact_plot(5, "water")
	farm.climate.begin_warning(farm, "storm", 0.1); farm.climate._impact(farm)
	farm.climate.data.operations.strike_row = 0; farm.climate.data.operations.strike_in = 0.25
	farm.update(0.25)
	check(farm.plots[5].quality == 75, "lightning hits the actual row's quality")
	farm.climate.data.operations.strike_row = 0; farm.climate.data.operations.strike_in = 0.25
	farm.update(0.25)
	check(farm.plots[5].quality == 75, "lightning quality penalty is once per disaster on a bed")
	check(Q.description(farm.plots[5]).contains("Lightning took it to Standard"), "downgrade names largest deduction")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "quality clocks, losses and once-only markers survive saves")
	farm.free()
	farm = fresh(); plant(farm); farm.interact_plot(5, "water"); farm.update(75)
	farm.interact_plot(5, "harvest")
	check(Stock.count(farm.storage, "russet", "Table") == 3, "on-time healthy harvest is Table")
	var cash: float = farm.coins
	var price: float = farm.market.russet.sell
	farm.sell_crop("russet", 1, "Table")
	check(is_equal_approx(farm.coins - cash, price * Q.MULTIPLIER.Table), "Table sells at the Table multiplier times the variety quote")
	Stock.add(farm.storage, "russet", 4, 60); Stock.add(farm.storage, "russet", 4, 20)
	farm.sell_crop("russet", 2, "Standard"); farm.sell_crop("russet", 3, "Feed")
	var totals: Dictionary = Stock.sales(farm.ledger, 1)
	check(totals.Table.sacks == 1 and totals.Standard.sacks == 2 and totals.Feed.sacks == 3, "journal grade labels retain sack counts")
	check(is_equal_approx(totals.Table.total + totals.Standard.total + totals.Feed.total, farm.ledger.total(1,"sales")), "grade sales sum exactly to the sales journal")
	var raw: Dictionary = farm._save_data()
	raw.storage.russet.Table["39"] = 1
	check(not farm._valid_save(raw), "saved cohort cannot claim a grade inconsistent with its score")
	raw = farm._save_data(); raw.plots[5].quality = 50
	check(not farm._valid_save(raw), "saved quality must reconcile with deductions")
	farm.free()
	for points in [21, 61]:
		farm = fresh(); plant(farm); farm.interact_plot(5,"water"); farm.update(75)
		Q.deduct(farm,5,"late",points)
		var word: String = "Standard" if points == 21 else "Feed"
		farm.interact_plot(5,"harvest")
		check(farm.stock_count("russet",word) == 3, "downgraded crop harvest delivers " + word)
		var before: float = farm.coins
		var expected: float = farm.market.russet.sell * Q.MULTIPLIER[word] * 3
		farm.sell_crop("russet",-1,word)
		check(is_equal_approx(farm.coins - before, expected), "downgraded harvest sells at " + word + " multiplier")
		farm.free()
	farm = fresh()
	Stock.add(farm.storage,"golden",2,85); Stock.add(farm.storage,"golden",2,100); Stock.add(farm.storage,"golden",2,45)
	farm.trading.keep_seed(farm,"golden","Table")
	farm.trading.keep_seed(farm,"golden","Standard")
	farm.trading.keep_seed(farm,"golden","Feed")
	check(farm.trading.kept_seed.golden == 2 and farm.stock_count("golden") == 4, "only Standard or Table sacks leave saleable storage for seed")
	winter(farm)
	check(farm.trading.winters["1"].spoiled.golden == 0 and farm.stock_count("golden","Table") == 2 and farm.stock_count("golden","Standard") == 1 and farm.stock_count("golden","Feed") == 1, "Winter subtracts ten per cohort and regrades without ageing kept seeds")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "cohort qualities and kept seeds round-trip")
	var old: int = farm.seed_inventory.golden
	farm.season_clock.seconds = 149.75; farm.update(0.25)
	check(farm.seed_inventory.golden == old + 2 and farm.trading.kept_seed.golden == 0, "kept sacks become matching seeds next Spring")
	farm.update(0.25)
	check(farm.seed_inventory.golden == old + 2, "seed conversion occurs only once")
	farm.selected_crop = "golden"
	farm.interact_plot(5,"hoe"); farm.interact_plot(5,"hoe"); farm.interact_plot(5,"plant")
	check(farm.plots[5].crop == "golden" and farm.plots[5].stage == 1 and farm.seed_inventory.golden == old + 1, "kept seed plants its original variety")
	farm.free()
	farm = fresh(); Stock.add(farm.storage,"russet",2,100)
	farm.trading.keep_seed(farm,"russet","Table",2); winter(farm)
	check(farm.trading.winters["1"].fee == 0 and farm.stock_count("russet") == 0, "seed-only barn incurs no fee or spoilage")
	farm.free()
	farm = fresh(); farm.trading.accept(farm)
	Stock.add(farm.storage,"russet",20,20); Stock.add(farm.storage,"russet",7,60); Stock.add(farm.storage,"russet",3,100)
	winter(farm)
	check(farm.trading.settled["1"][0].delivered == 10 and farm.trading.settled["1"][0].shortfall == 10, "contract refuses Feed and collects Standard or better")
	check(farm.stock_count("russet","Feed") == 19 and farm.trading.winters["1"].spoiled.russet == 1, "remaining twenty Feed sacks suffer five percent spoilage")
	farm.free()
	farm = fresh()
	Stock.add(farm.storage,"russet",10,90); Stock.add(farm.storage,"russet",10,60); Stock.add(farm.storage,"russet",10,20)
	winter(farm)
	Stock.add(farm.storage,"russet",3,80) # Same quality as aged Table stores, but freshly harvested.
	var stored: int = Stock.count(farm.trading.held,"russet","Table")
	farm.sell_crop("russet",-1,"Table")
	check(Stock.count(farm.trading.held,"russet","Table") == stored and farm.stock_count("russet","Table") == stored, "ordinary sale preserves same-score Winter stores")
	farm.trading.sell_stored(farm,"russet",-1,"Table")
	farm.trading.sell_stored(farm,"russet",-1,"Standard")
	farm.trading.sell_stored(farm,"russet",-1,"Feed")
	totals = Stock.sales(farm.ledger,1)
	check(is_equal_approx(totals.Table.total + totals.Standard.total + totals.Feed.total, farm.ledger.total(1,"sales")), "ordinary and Winter grade receipts reconcile together")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "mixed fresh and stored graded sales leave valid state")
	farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".rejected", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("GRADES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	game.state.coins = 100000
	game.world.show_grade(0, game.state.plots[0])
	check(game.world.grade_tag.visible and game.world.grade_tag.text == "Grade: Table", "bed context has a small grade tag")
	game.world.harvest_feedback.harvest({0:game.state.plots[0].duplicate(true)})
	check(game.world.harvest_feedback.active[0].node.get_node("HarvestGrade").text == "Table", "harvest pop names the grade")
	game.world.grade_tag.hide()
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.1).timeout; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/grades-harvest.png")
	while not game.world.harvest_feedback.active.is_empty(): game.world.harvest_feedback._remove(0)
	game.world.player.position = game.world.plot_positions[0]
	Q.deduct(game.state,0,"pests",25)
	game._update_hover()
	for i in range(3): await process_frame
	check(game.world.grade_tag.text == "Grade: Standard" and game.hud._context_box.visible and game.hud._hover_context.contains("Pests took it to Standard"), "near-player context exposes current grade and largest downgrade cause")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.1).timeout; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/grades-bed.png")
	# Keep an actual growing bed under the pointer across HUD and state refreshes.
	game.state.plots[0].stage = 1
	game.state.plots[0].watered = true
	await physics_frame
	var point: Vector2 = game.world.camera.unproject_position(game.world.plot_positions[0])
	var pointer: Vector2 = point * root.get_visible_rect().size / Vector2(game.farm_viewport.size)
	game._update_hover_at(pointer)
	for i in range(4): await process_frame
	check(game.hover_plot == 0 and game.hud._context.text.contains("Ready in") and game.hud._context.text.contains("Grade: Standard"), "hover combines growth time and an explicit grade (bed %d, %s)" % [game.hover_plot, game.hud._context.text])
	if "--capture" in OS.get_cmdline_user_args():
		RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/grades-hover.png")
	var changes := {"resize": 0, "visibility": 0}
	game.hud._context_box.resized.connect(func(): changes.resize += 1)
	game.hud._context_box.visibility_changed.connect(func(): changes.visibility += 1)
	var stable_rect: Rect2 = game.hud._context_box.get_rect()
	check(stable_rect.size.y <= game.hud._context.get_line_height() * game.hud._context.get_line_count() + 12, "growth and grade hint stays compact after wrapping (%s)" % stable_rect)
	for i in range(12):
		game._update_hover_at(pointer)
		game.hud.update_state(game.state)
		game.hud._process(0)
		await process_frame
	check(changes.resize == 0 and changes.visibility == 0 and game.hud._context_box.get_rect() == stable_rect, "unchanged growth and grade hint neither resizes nor flashes across refreshes")
	for word in Q.GRADES: Stock.add(game.state.storage,"russet",4,{"Table":90,"Standard":60,"Feed":20}[word])
	game.hud.show_panel("sell_potatoes",game.state)
	await process_frame
	var page = game.hud._refs.market_page
	check(page.grade_buttons.size() == 3, "Sell Potatoes lists each grade")
	page.grade_buttons.Feed.pressed.emit()
	check(page.selected_grade == "Feed" and page.crop_quote.text == game.state.market_money(game.state.market.russet.sell * 0.5), "grade selection updates the sale price")
	page.quantity.value = 1; page._sell()
	check(game.state.stock_count("russet","Feed") == 3, "grade sale control sells only the chosen grade")
	for size in [Vector2i(1280,800), Vector2i(390,844)]:
		root.size = size; root.content_scale_size = Vector2i(maxi(600,size.x),size.y) if game.touch_controls.enabled else size
		game.hud._process(0)
		if not game.touch_controls.enabled:
			game.hud._modal_card.offset_left = -minf(500, size.x * 0.5 - 12)
			game.hud._modal_card.offset_right = minf(500, size.x * 0.5 - 12)
		for i in range(8): await process_frame
		check(page.grade_buttons.Table.size.x <= game.hud.root.size.x, "grade rows fit desktop and phone")
		if "--capture" in OS.get_cmdline_user_args():
			RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/grades-market-%d.png" % size.x)
	game.hud.show_panel("winter_stores", game.state)
	game.hud._refs["keep_seed:russet:Table"].pressed.emit()
	check(game.state.trading.kept_seed.russet == 1, "barn control keeps a Table sack as seed")
	for i in range(8): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/grades-barn.png")
	game.hud.close_panel()
	winter(game.state)
	check(game.hud._refs["grade_sales:Feed"].text.contains("1 sacks") and game.hud._refs["grade_sales:Table"].text.contains("0 sacks"), "Winter accounts show each grade's actual sack sales")
	for i in range(8): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://artifacts/grades-accounts.png")
	game.hud.close_panel()
	game.queue_free(); await process_frame; await create_timer(.2).timeout
