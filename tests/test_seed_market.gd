extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## Isolated market regression: real transactions, gestures and layouts.
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://taterland_seed_market_test_only.json"
var checks: int = 0
var failures: int = 0
var game
var capture: bool = false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
func settle() -> void:
	for _i: int in range(5): await process_frame
func shot(label: String) -> void:
	if not capture: return
	await create_timer(0.25).timeout
	# macOS can suppress frame_post_draw for an occluded native window.
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/exchange-" + label + ".png")
func press(page: Control, action: String) -> void:
	for button: Node in game.hud._modal_card.find_children("*", "Button", true, false):
		if button.get_meta("action", "") == action:
			check(not button.disabled, "enabled " + action)
			button.pressed.emit()
			return
	check(false, "found " + action)
func capture_polish() -> void:
	if not capture: return
	# Representative quotes after the separate extreme-price spacing checks.
	var state = game.state
	state.reset_game()
	state.tutorial_progress.completed = true
	state.coins = 125000
	for crop: String in ["russet", "giant", "golden"]:
		state.storage[crop] = Stock.pile(24)
	state.elapsed = 420.0
	state._refresh_market()
	game.hud.update_state(state)
	game.hud._sell_crop = "russet"
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		game.hud.show_panel("sell_potatoes", state)
		await settle()
		game.hud._refs.market_page.quantity.value = 8
		await settle()
		await shot("polished-sell-%dx%d" % [dimensions.x, dimensions.y])
		game.hud.show_panel("market", state)
		await settle()
		await shot("polished-buy-%dx%d" % [dimensions.x, dimensions.y])

func check_price_information(state) -> void:
	state.tutorial_progress.completed = true
	game.hud.set_tutorial({})
	for moment: float in [0.0, 37.0, 150.0, 337.0, 450.0]:
		state.elapsed = moment
		state._refresh_market()
		game.hud.show_panel("market", state)
		for crop: String in game.hud._refs.market_page.crops:
			var expected: int = roundi((state.market[crop].sell / State.CropTable.CROPS[crop].base - 1.0) * 100.0)
			var text: String = "· " + ("+" if expected >= 0 else "−") + str(absi(expected)) + "%"
			var color: Color = Color("436733") if moment > 0 and moment < 300 else (Color("a63529") if moment > 300 else game.hud.INK)
			var label: Label = game.hud._refs[crop + ":change"]
			check(label.text == text and label.get_theme_color("font_color") == color, crop + " buy signed percentage and color")
			check(game.hud._refs[crop + ":history"].samples == state.market[crop].history, crop + " buy sparkline samples")
		game.hud.show_panel("sell_potatoes", state)
		var page = game.hud._refs.market_page
		for crop: String in page.crops:
			page.selected = crop
			state.selected_crop = crop
			game.hud.update_state(state)
			var expected: int = roundi((state.market[crop].sell / State.CropTable.CROPS[crop].base - 1.0) * 100.0)
			var text: String = "· " + ("+" if expected >= 0 else "−") + str(absi(expected)) + "%"
			var color: Color = Color("436733") if moment > 0 and moment < 300 else (Color("a63529") if moment > 300 else game.hud.INK)
			check(page.crop_change.text == text and page.crop_change.get_theme_color("font_color") == color, crop + " sell signed percentage and color")
			check(page.crop_history.samples == state.market[crop].history, crop + " sell navigation updates sparkline")
			check(game.hud._top.price.text == state.market_money(state.market[crop].sell) and game.hud._top.price_change.text == text and game.hud._top.price_change.get_theme_color("font_color") == color, crop + " top bar live price, signed percentage and color")

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	create_timer(90).timeout.connect(func() -> void: push_error("Market check timed out"); quit(1))
	capture = "--capture" in OS.get_cmdline_user_args()
	var expected: Array[String] = ["russet", "giant", "golden", "sunburst", "icecap"]
	check(State.crops_by_base_price(State.CROP_IDS) == expected, "fixed ascending base order")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Begin calmly so explicit weather/practice scenarios own the fixture.
	game.state.rng.seed = 6
	await settle()
	game.set_process(false)
	game.hud.set_process(false)
	var state = game.state
	state.elapsed = 0.0
	state._refresh_market()
	game.hud.show_panel("sell_potatoes", state)
	await settle()
	var empty_page = game.hud._refs.market_page
	check(empty_page.quantity.text == "0" and not empty_page.quantity.editable and empty_page.sell_button.disabled, "fresh empty inventory shows a disabled zero amount")
	state.coins = 10000
	for crop: String in State.CROP_IDS:
		check(State.CropTable.CROPS[crop].seed > 0 and State.CropTable.CROPS[crop].seed <= State.CropTable.CROPS[crop].base, "base seed " + crop)
		check(state.market[crop].seed == State.CropTable.CROPS[crop].seed, "initial seed ratio " + crop)
	game._on_action("market")
	await settle()
	var page = game.hud._refs.market_page
	check(page.crops == expected, "buy ordering stays fixed when live prices reverse")
	var cash: float = state.coins
	var seeds: int = state.seed_inventory.russet
	press(page, "buy:russet:1")
	press(page, "buy:russet:5")
	check(state.seed_inventory.russet == seeds + 6 and state.coins == cash - 6 * State.CropTable.CROPS.russet.seed, "buy controls add seeds and spend live currency")
	check(game.hud._purchase_receipt.quantity == 6, "purchase receipt and inventory retained")
	state.coins = state.bankruptcy_limit()
	game.hud.update_state(state)
	check(game.hud._refs["buy:russet:1"].disabled, "unaffordable purchase disabled")
	state.buy_seeds("russet", 1)
	check(state.seed_inventory.russet == seeds + 6 and state.coins == state.bankruptcy_limit(), "exhausted credit do not mutate inventory")
	state.coins = 10000
	state._refresh_market()
	game.hud.update_state(state)
	game.hud._purchase_box.hide()
	game.hud._toast_box.hide()
	await shot("buy-desktop")
	state.storage["russet"] = Stock.pile(12)
	state.storage["giant"] = Stock.pile(7)
	press(page, "sell_potatoes")
	await settle()
	page = game.hud._refs.market_page
	check(game.hud._panel_kind == "sell_potatoes" and page.selected == "russet", "separate sell page opens selected crop")
	check(page.crops == expected, "buy and sell share base order")
	page.quantity.value = 3
	check(page.payout.text == state.money(3 * state.market.russet.sell), "quantity previews actual expected payout")
	cash = state.coins
	press(page, "market_sell")
	check(Stock.count(state.storage, "russet") == 9 and state.coins == cash + 3 * state.market.russet.sell, "sell commits chosen quantity at live price")
	check(page.status.text.contains("sold") and page.status.text.contains(state.format_number(3 * state.market.russet.sell)), "successful sale confirms committed payout")
	page.quantity.value = 10
	check(page.quantity.value == 9 and page.payout.text == state.money(9 * state.market.russet.sell), "quantity is bounded by owned stock")
	page.quantity.text = "2.5"
	page.quantity.text_changed.emit("2.5")
	check(page.sell_button.disabled and page.status.text.contains("whole number"), "invalid text blocks selling with clear guidance")
	page.quantity.text = ""
	page.quantity.text_changed.emit("")
	check(page.sell_button.disabled, "empty amount never sells an old quantity")
	page.quantity.value = 1
	press(page, "quantity_plus")
	check(page.quantity.value == 2, "plus raises quantity")
	press(page, "quantity_minus")
	check(page.quantity.value == 1 and page.minus.disabled, "minus stops at one")
	state.sell_crop("russet", 10)
	check(Stock.count(state.storage, "russet") == 9 and state.coins == cash + 3 * state.market.russet.sell, "insufficient direct sale is rejected without partial payout")
	press(page, "market_all")
	check(page.quantity.value == 9 and page.payout.text == state.money(9 * state.market.russet.sell), "Max selects available stock and previews its value")
	page.quantity.get_line_edit().grab_focus()
	page.quantity.get_line_edit().text = "4"
	cash = state.coins
	page._sell()
	check(Stock.count(state.storage, "russet") == 5 and state.coins == cash + 4 * state.market.russet.sell, "typed quantity commits before selling")
	press(page, "market_next")
	check(page.selected == "giant" and page.quantity.value == 1 and page.crop_owned.text == "7 owned", "arrow updates variety, chart, quantity and inventory together")
	page.quantity.value = 2
	check(page.payout.text == state.money(2 * state.market.giant.sell), "navigated payout uses new crop")
	press(page, "market_previous")
	check(page.selected == "russet", "previous returns to Russet")
	await settle()
	var point: Vector2 = page.hero.global_position + page.hero.size * 0.5
	var down := InputEventScreenTouch.new()
	down.index = 2
	down.pressed = true
	down.position = point
	root.push_input(down, true)
	var up := InputEventScreenTouch.new()
	up.index = 2
	up.position = point - Vector2(100, 0)
	root.push_input(up, true)
	check(page.selected == "giant", "left swipe navigates forward through real input dispatch")
	down.position = point
	root.push_input(down, true)
	up.position = point + Vector2(100, 0)
	root.push_input(up, true)
	check(page.selected == "russet", "right swipe navigates back")
	down.position = point
	root.push_input(down, true)
	up.position = point + Vector2(10, 100)
	root.push_input(up, true)
	check(page.selected == "russet", "vertical scrolling does not switch crops")
	press(page, "market_previous")
	check(page.selected == "icecap" and page.sell_button.disabled and page.quantity.value == 0 and not page.quantity.editable and page.maximum.disabled, "wrap and zero inventory work")
	page.refresh()
	state.storage["icecap"] = Stock.pile(2)
	page.refresh()
	check(not page.sell_button.disabled, "missing history still allows a real current-quote sale")
	cash = state.coins
	press(page, "market_sell")
	check(Stock.count(state.storage, "icecap") == 1 and state.coins == cash + state.market.icecap.sell, "missing-history sale pays current quote")
	press(page, "market_next")
	game.hud._toast_box.hide()
	await shot("sell-desktop")
	# Price updates refresh a held page without losing quantity or fixed ordering.
	page.quantity.value = 2
	state.elapsed = 150.0
	state._refresh_market()
	game.hud.update_state(state)
	check(page.quantity.value == 2 and page.payout.text == state.money(2 * state.market.russet.sell) and page.crops == expected, "live refresh updates payout and preserves selection/order")
	check(state.save_game(SAVE) and state.load_game(SAVE), "new market and bounded history round-trip saves")
	check(is_equal_approx(state.market.russet.seed, State.CropTable.CROPS.russet.seed), "load recomputes fixed seed price")
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.climate.begin_warning(state, "storm", 1.0)
	state.climate._impact(state)
	state._refresh_market()
	for crop: String in State.CROP_IDS:
		check(state.market[crop].seed == State.CropTable.CROPS[crop].seed, "disaster seeds follow final quote " + crop)
	game.hud.show_panel("market", state)
	check(game.hud._refs.market_page.crops == State.crops_by_base_price(state.available_crops()), "buy preserves local island availability")
	game.hud.show_panel("sell_potatoes", state)
	page = game.hud._refs.market_page
	check(page.crops == expected, "sell includes unlocked and held varieties in base order")
	game.hud._climate_alert.dismiss()
	# Stress label spacing at the largest price-change scale.
	page.selected = "icecap"
	page.refresh()
	root.min_size = Vector2i.ZERO
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		game.touch_controls.fit_modal()
		await settle()
		var scroll: ScrollContainer = game.hud._body.get_parent()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, "market fits width " + str(dimensions))
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "market fits viewport " + str(dimensions))
		check(page.crop_quote.get_line_count() == 1 and page.crop_change.get_line_count() == 1 and page.crop_quote.get_global_rect().end.x <= page.crop_change.global_position.x, "sell quote and percentage stay adjacent without overlap " + str(dimensions))
		await shot("sell-%dx%d" % [dimensions.x, dimensions.y])
		scroll.scroll_vertical = 0
		await settle()
		check(game.hud._modal_card.get_global_rect().encloses(page.sell_button.get_global_rect()), "sell control reachable " + str(dimensions))
		await shot("sell-controls-%dx%d" % [dimensions.x, dimensions.y])
		game.hud.show_panel("market", state)
		await settle()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, "seed cards fit width " + str(dimensions))
		for crop: String in game.hud._refs.market_page.crops:
			var quote_label: Label = game.hud._refs[crop + ":price"]
			var change_label: Label = game.hud._refs[crop + ":change"]
			check(quote_label.get_line_count() == 1 and change_label.get_line_count() == 1 and quote_label.get_global_rect().end.x <= change_label.global_position.x, crop + " buy quote and percentage stay adjacent without overlap " + str(dimensions))
		await shot("buy-%dx%d" % [dimensions.x, dimensions.y])
		game.hud.show_panel("sell_potatoes", state)
		page = game.hud._refs.market_page
		await settle()
	check_price_information(state)
	await capture_polish()
	game.queue_free()
	await process_frame
	# Let the audio mixer drain stopped weather streams before headless exit.
	await create_timer(0.25).timeout
	print("SEED MARKET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
