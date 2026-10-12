extends SceneTree
## The owner's all-crops page uses real transactions and phone geometry.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func settle() -> void:
	for frame in range(20): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(); game.set_process(false); game.year_intro.stop()
	game.tutorial.active = false; game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false); game.hud.set_tutorial({})
	game.state.coins = 500000
	for crop in game.state.CROP_IDS:
		game.state.storage[crop] = game.state.Stock.pile(12,90)
		game.state.Stock.add(game.state.storage,crop,8,60)
		game.state.Stock.add(game.state.storage,crop,4,20)
	root.min_size = Vector2i.ZERO
	for dimensions in [Vector2i(1440,900),Vector2i(390,844)]:
		root.size = dimensions
		game.touch_controls.enabled = dimensions.x == 390
		if game.touch_controls.enabled: game.touch_controls._build_touch_sheets()
		game.touch_controls.resize(); await settle()
		for season in [0,3]:
			game.state.season_clock.season = season
			game.hud.show_market(true,game.state); await settle()
			game.touch_controls.fit_modal(); await settle()
			var page = game.hud._refs.market_page
			var scroll: ScrollContainer = game.hud._body.get_parent()
			check(page.sale_rows.size() == 5,"all five crops share the page")
			check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"Sell needs no vertical scrolling")
			check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()),"Sell paper fits the viewport: %s season %d paper %s viewport %s" % [dimensions,season,game.hud._modal_card.get_global_rect(),game.hud.root.get_global_rect()])
			check(game.hud._body.get_combined_minimum_size().y <= scroll.size.y+1,"all rows fit without clipping: %s season %d body %s scroll %s" % [dimensions,season,game.hud._body.get_combined_minimum_size(),scroll.size])
			for crop in page.sale_rows:
				var entry: Dictionary = page.sale_rows[crop]
				check(entry.card.is_visible_in_tree() and scroll.get_global_rect().grow(1).encloses(entry.card.get_global_rect()),"crop and graph visible together: "+crop)
				check(entry.history.size.y*float(dimensions.x)/game.hud.root.size.x >= 31,"chart stays readable: "+crop)
				for amount in [1,5]:
					var button: Button = entry.sales[amount]
					check(button.text == ("1 tonne" if amount == 1 else "5 tonnes") and minf(button.size.x,button.size.y)*float(dimensions.x)/game.hud.root.size.x >= 43.9,"drawn whole-tonne button: "+crop+str(amount))
	var page = game.hud._refs.market_page
	page.select_variety("golden","Standard")
	var journal: Dictionary = game.state.ledger.save_data()
	var stock: Dictionary = game.state.storage.duplicate(true)
	var before: int = game.state.stock_count("golden","Standard")
	page.sale_rows.golden.sales[5].pressed.emit()
	check(game.state.stock_count("golden","Standard") == before-5,"five-tonne button sells exactly five of its chosen grade")
	check(page.sale_rows.golden.sales[5].text == "Undo" and page.sale_rows.golden.sales[1].text == "1 tonne","Undo stays on the pressed amount button")
	page.sale_rows.golden.sales[5].pressed.emit()
	check(game.state.storage == stock and game.state.ledger.save_data() == journal,"five-tonne Undo restores the identical stock and ledger")
	page.select_variety("golden","Feed")
	page.sale_rows.golden.sales[5].pressed.emit()
	check(game.state.storage == stock and game.state.ledger.save_data() == journal,"insufficient five-tonne stock never becomes a partial sale")
	game.hud.show_panel("market",game.state); await settle()
	page = game.hud._refs.market_page
	game.state.buy_seeds("russet",1)
	check(page.seed_cards.russet.has_meta("purchase_tween") and page.seed_cards.russet.scale == Vector2(.985,.985),"a purchase animates its own seed card")
	check(absf(game.world.camera.rotation.z) < .001,"purchase does not roll the farm camera")
	check(await preload("res://tests/audio_fixture.gd").release(game,self),"audio releases before teardown")
	game.queue_free(); await settle()
	print("SELL PAGE: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
