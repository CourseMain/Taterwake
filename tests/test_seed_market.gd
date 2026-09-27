extends SceneTree
## Isolated exchange regression: real transactions, charts, gestures and layouts.
const State = preload("res://scripts/game_state.gd")
const Chart = preload("res://scripts/market_chart.gd")
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
func chart_labels(chart: Control) -> void:
	var layout: Dictionary = chart.chart_layout()
	var labels: Array = layout.labels
	check(labels.size() == layout.points.size(), "every visible point has a percentage")
	for i: int in labels.size():
		check(Rect2(Vector2.ZERO, chart.size).encloses(labels[i]), "point label stays within chart")
		for j: int in range(i + 1, labels.size()): check(not labels[i].intersects(labels[j]), "point labels do not overlap")

func capture_polish() -> void:
	if not capture: return
	# Representative quotes after the separate extreme-price spacing checks.
	var state = game.state
	state.reset_game()
	state.tutorial_progress.completed = true
	state.coins = 125000
	for crop: String in ["russet", "giant", "golden", "radioactive"]:
		state.storage[crop] = 24
		var base: float = State.CROPS[crop].base
		state.market[crop].history = []
		for factor: float in [1.0, 1.17, 0.75, 1.52, 1.33, 1.82, 1.6, 1.82]:
			state.market[crop].history.append(snappedf(base * factor, 0.01))
		state.market[crop].sell = state.market[crop].history.back()
		state.market[crop].seed = State.seed_price_for(state.market[crop].sell)
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

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	create_timer(90).timeout.connect(func() -> void: push_error("Market check timed out"); quit(1))
	capture = "--capture" in OS.get_cmdline_user_args()
	check(Chart.percent_label(182, 100) == "(+82%)", "182 against 100 is +82%")
	check(Chart.percent_label(75, 100) == "(−25%)", "75 against 100 is -25%, not change from 182")
	check(Chart.percent_label(100, 100) == "(0%)", "base price is 0%")
	check(Chart.percent_label(99.999, 100) == "(0%)", "rounded zero has no negative sign")
	check(State.seed_price_for(38) == 28.5 and is_equal_approx(State.seed_price_for(1.90), 1.43), "seed prices round to cents")
	var expected: Array[String] = ["russet", "giant", "golden", "radioactive", "sunburst", "icecap"]
	check(State.crops_by_base_price(State.CROP_IDS) == expected, "fixed ascending base order")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.hud.set_process(false)
	var state = game.state
	game.hud.show_panel("sell_potatoes", state)
	await settle()
	var empty_page = game.hud._refs.market_page
	check(empty_page.quantity.text == "0" and not empty_page.quantity.editable and empty_page.sell_button.disabled, "fresh empty inventory shows a disabled zero amount")
	state.coins = 100000
	for crop: String in State.CROP_IDS:
		check(State.CROPS[crop].seed == State.CROPS[crop].base * 0.75, "base seed " + crop)
		check(state.market[crop].seed == State.seed_price_for(state.market[crop].sell), "initial seed ratio " + crop)
	var base_values: Dictionary = {}
	for crop: String in State.CROP_IDS: base_values[crop] = State.CROPS[crop].base
	for event: String in State.EVENT_IDS:
		state._start_event(event)
		for crop: String in State.CROP_IDS:
			check(state.market[crop].seed == State.seed_price_for(state.market[crop].sell), "live event seed ratio " + event + " " + crop)
			check(State.CROPS[crop].base == base_values[crop], "market never changes base " + crop)
	state._end_event()
	state.inventory_items.trader_token = 5
	game.builds.levels.investor = 3
	game.builds.active = "investor"
	state._market_core.russet.sell = 100
	state._market_core.giant.sell = 63
	state._refresh_market(false)
	# Tokens now lift the final crop quote by 5% each; seed prices follow it.
	# Legacy seed-only discounts must not undo that final 75% relationship.
	check(state.market.russet.sell == 125 and state.market.giant.sell == 78.75, "five Trader Tokens increase live crop quotes by 25 percent")
	check(state.market.russet.seed == 93.75 and state.market.giant.seed == 59.06, "token-adjusted seed quotes remain 75 percent, rounded to cents")
	# The transaction cases below deliberately use unmodified \uE000 100/\uE000 63 quotes.
	# Do not leak this perk fixture into their exact receipt and chart amounts.
	state.inventory_items.trader_token = 0
	state._refresh_market(false)
	check(state.market.russet.seed == 75 and state.market.giant.seed == 47.25, "removing tokens restores unmodified quotes without investor seed discounts")
	game._on_action("market")
	await settle()
	var page = game.hud._refs.market_page
	check(page.crops == expected.slice(0, 4), "buy ordering stays fixed when live prices reverse")
	var cash: float = state.coins
	var seeds: int = state.seed_inventory.russet
	press(page, "buy:russet:1")
	press(page, "buy:russet:5")
	check(state.seed_inventory.russet == seeds + 6 and state.coins == cash - 450, "buy controls add seeds and spend live currency")
	check(game.hud._purchase_receipt.quantity == 6, "purchase receipt and inventory retained")
	state.coins = state.bankruptcy_limit()
	game.hud.update_state(state)
	check(game.hud._refs["buy:russet:1"].disabled, "unaffordable purchase disabled")
	state.buy_seeds("russet", 1)
	check(state.seed_inventory.russet == seeds + 6 and state.coins == state.bankruptcy_limit(), "exhausted credit do not mutate inventory")
	state.coins = 100000
	state._market_core.russet.sell = 38
	state._refresh_market()
	game.hud.update_state(state)
	game.hud._purchase_box.hide()
	game.hud._toast_box.hide()
	await shot("buy-desktop")
	state.storage.russet = 12
	state.storage.giant = 7
	state.market.russet.history = [38.0, 28.5, 45.6, 69.16, 55.1, 41.8, 50.54, 38.0]
	press(page, "sell_potatoes")
	await settle()
	page = game.hud._refs.market_page
	check(game.hud._panel_kind == "sell_potatoes" and page.selected == "russet", "separate sell page opens selected crop")
	check(page.crops == expected.slice(0, 4), "buy and sell share base order")
	page.quantity.value = 3
	check(page.payout.text == "\uE000 114.00", "quantity previews actual expected payout")
	cash = state.coins
	press(page, "market_sell")
	check(state.storage.russet == 9 and state.coins == cash + 114, "sell commits chosen quantity at live price")
	check(page.status.text.contains("sold") and page.status.text.contains("114.00"), "successful sale confirms committed payout")
	page.quantity.value = 10
	check(page.quantity.value == 9 and page.payout.text == "\uE000 342.00", "quantity is bounded by owned stock")
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
	check(state.storage.russet == 9 and state.coins == cash + 114, "insufficient direct sale is rejected without partial payout")
	press(page, "market_all")
	check(page.quantity.value == 9 and page.payout.text == "\uE000 342.00", "Max selects available stock and previews its value")
	page.quantity.get_line_edit().grab_focus()
	page.quantity.get_line_edit().text = "4"
	cash = state.coins
	page._sell()
	check(state.storage.russet == 5 and state.coins == cash + 152, "typed quantity commits before selling")
	press(page, "market_next")
	check(page.selected == "giant" and page.quantity.value == 1 and page.chart.base_price == 180 and page.crop_owned.text == "7 owned", "arrow updates variety, chart, quantity and inventory together")
	page.quantity.value = 2
	check(page.payout.text == "\uE000 126.00", "navigated payout uses new crop")
	press(page, "market_previous")
	check(page.selected == "russet", "previous returns to Russet")
	await settle()
	var point: Vector2 = page.chart.global_position + page.chart.size * 0.5
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
	check(page.selected == "radioactive" and page.sell_button.disabled and page.quantity.value == 0 and not page.quantity.editable and page.maximum.disabled, "wrap and zero inventory work")
	state.market.radioactive.history = []
	page.refresh()
	check(page.chart.samples.is_empty() and page.older.disabled and page.newer.disabled, "missing history is clean")
	state.storage.radioactive = 2
	page.refresh()
	check(not page.sell_button.disabled, "missing history still allows a real current-quote sale")
	cash = state.coins
	press(page, "market_sell")
	check(state.storage.radioactive == 1 and state.coins == cash + state.market.radioactive.sell, "missing-history sale pays current quote")
	press(page, "market_next")
	var history: Array = []
	for i: int in range(40): history.append(38.0 * [1.0, 1.82, 0.75, 1.33, 1.06][i % 5])
	state.market.russet.history = history
	page.refresh()
	await settle()
	chart_labels(page.chart)
	press(page, "history_older")
	check(page.chart.history_offset > 0 and not page.newer.disabled, "older history is reachable")
	for i: int in range(20): page.chart.move_window(1)
	check(page.chart.window_bounds().x == 0 and page.older.disabled, "can browse oldest retained sample")
	for i: int in range(20): page.chart.move_window(-1)
	check(page.chart.history_offset == 0, "can return to latest history")
	game.hud._toast_box.hide()
	await shot("sell-desktop")
	# Price updates refresh a held page without losing quantity or fixed ordering.
	page.quantity.value = 2
	state._market_core.russet.sell = 69.16
	state._refresh_market(false)
	game.hud.update_state(state)
	check(page.quantity.value == 2 and page.payout.text == "\uE000 138.32" and page.crops == expected.slice(0, 4), "live refresh updates payout and preserves selection/order")
	check(state.market.russet.history.back() == 69.16 and state.market.russet.history.size() == 40, "history includes unscheduled changes and remains bounded")
	check(state.save_game(SAVE) and state.load_game(SAVE), "new market and bounded history round-trip saves")
	check(is_equal_approx(state.market.russet.seed, 51.87), "load recomputes 75% seed price")
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.island2_unlocked = true
	state.island3_unlocked = true
	state.travel_to(3)
	state.climate.acknowledge(state)
	state.climate.begin_warning(state, "storm", 1.0)
	state.climate._impact(state)
	state._refresh_market()
	for crop: String in State.CROP_IDS:
		check(state.market[crop].seed == State.seed_price_for(state.market[crop].sell), "disaster seeds follow final quote " + crop)
	game.hud.show_panel("market", state)
	check(game.hud._refs.market_page.crops == State.crops_by_base_price(state.available_crops()), "buy preserves local island availability")
	game.hud.show_panel("sell_potatoes", state)
	page = game.hud._refs.market_page
	check(page.crops == expected, "sell includes unlocked and held varieties in base order")
	game.hud._climate_alert.dismiss()
	# Stress label spacing at the largest price-change scale.
	page.selected = "icecap"
	state.market.icecap.history = [2e9, 1.5e9, 2.002e12, 1.0e11, 2e9, 7.02e11, 2.002e12, 2e9]
	page.refresh()
	root.min_size = Vector2i.ZERO
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		game.touch_controls.fit_modal()
		await settle()
		chart_labels(page.chart)
		var scroll: ScrollContainer = game.hud._body.get_parent()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, "market fits width " + str(dimensions))
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "market fits viewport " + str(dimensions))
		await shot("sell-%dx%d" % [dimensions.x, dimensions.y])
		scroll.scroll_vertical = 0
		await settle()
		check(game.hud._modal_card.get_global_rect().encloses(page.sell_button.get_global_rect()), "sell control reachable " + str(dimensions))
		await shot("sell-controls-%dx%d" % [dimensions.x, dimensions.y])
		game.hud.show_panel("market", state)
		await settle()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, "seed cards fit width " + str(dimensions))
		await shot("buy-%dx%d" % [dimensions.x, dimensions.y])
		game.hud.show_panel("sell_potatoes", state)
		page = game.hud._refs.market_page
		await settle()
	await capture_polish()
	game.queue_free()
	await process_frame
	# Let the audio mixer drain stopped weather streams before headless exit.
	await create_timer(0.25).timeout
	print("SEED MARKET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
