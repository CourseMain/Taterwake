extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## The first-year card stays readable through crop choice, loss, sale and accounts.
const State = preload("res://scripts/game_state.gd")
const HUD = preload("res://scripts/game_hud.gd")
const Activities = preload("res://scripts/island_activities.gd")
var state
var hud
var activities
var checks: int = 0
var failures: int = 0
var actions: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for _frame: int in range(4):
		await process_frame

func guide(tools: Array = [], features: Array = [], allowed: Array = []) -> Dictionary:
	return {"id": "market", "title": "Grab a seed", "body": "Follow the arrow to the market.\nBuy 1 Russet seed.", "step": 2, "total": 10, "tools": tools, "features": features, "allowed_actions": allowed, "continue": true}

func button_for(action: String) -> Button:
	for node: Node in hud.root.find_children("*", "Button", true, false):
		if str(node.get_meta("hud_action", "")) == action:
			return node
	return null

func run() -> void:
	state = State.new()
	root.add_child(state)
	activities = Activities.new()
	activities.setup(state)
	state.activity_system = activities
	root.add_child(activities)
	hud = HUD.new()
	root.add_child(hud)
	hud.action_requested.connect(func(action: String) -> void: actions.append(action))
	hud.update_state(state)
	hud.set_process(false)
	hud.set_tutorial(guide())
	await settle()
	check(hud._tutorial_card.visible and hud.root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "intro card appears without a blocking full-screen tutorial overlay")
	check(not hud._hotbar.visible and not hud._stats_card.visible and not hud._menu_button.visible, "intro starts without unexplained controls or stats")
	check(not hud._quick_sell.visible, "sale actions and sidebar wait for their introduction")
	hud.set_tool("pest")
	check(hud._selected_tool == "hoe", "hidden tools cannot be equipped through HUD API")
	hud._act("tools")
	check(actions.is_empty(), "blocked actions never reach game state")
	hud._act("tutorial:next")
	hud._act("tutorial:skip")
	check(actions == ["tutorial:next"], "unguarded skip cannot dispatch an exit")
	hud._tutorial_skip.pressed.emit()
	check(actions.size() == 1 and hud._tutorial_exit_box.visible and not hud._tutorial_next.visible, "exit control reveals a separate choice without ending the tutorial")
	hud._act("tutorial:stay")
	check(hud._tutorial_next.visible and not hud._tutorial_exit_box.visible, "keep learning safely restores Next")
	hud._act("tutorial:exit")
	hud._act("tutorial:skip")
	check(actions == ["tutorial:next", "tutorial:skip"], "deliberate skip dispatches once")
	actions.clear()
	hud.set_tutorial(guide(["hoe", "plant"], ["coins", "market"], ["tool:", "buy:russet:1", "market", "close"]))
	hud.set_tool("plant")
	hud.update_state(state)
	check(hud._tool_buttons.hoe.visible and hud._tool_buttons.plant.visible and not hud._tool_buttons.water.visible, "hotbar reveals only introduced tools")
	check(hud._top.coins.is_visible_in_tree() and not hud._quick_sell.visible, "purse reveals before the full price display")
	check(hud._crop_row.visible, "first planting shows seeds without tracked price clutter")
	await settle()
	check(is_equal_approx(hud._crop_row.size.x, 300.0) and is_equal_approx(hud._crop_row.get_global_rect().get_center().x, hud.root.size.x * 0.5), "first Russet choice uses a compact centered tray")
	var visible_crops: int = 0
	for crop: String in hud._crop_buttons:
		if hud._crop_buttons[crop].is_visible_in_tree():
			visible_crops += 1
	check(visible_crops == 1 and hud._crop_buttons.russet.visible, "Russet is the sole first planting choice")
	hud.show_panel("market", state)
	await settle()
	var purchase_guide: Dictionary = guide(["hoe", "plant"], ["coins", "market"], ["tool:", "buy:russet:1", "market", "close"])
	purchase_guide["continue"] = true
	hud.set_tutorial(purchase_guide)
	hud._update_tutorial_pointer()
	check(hud._tutorial_pointer.target == hud._refs.starter_continue, "pointer targets the real owned-seed continuation")
	check(not hud._tutorial_card.visible and hud._refs.starter_continue.visible, "shop instruction replaces the guide card while the shop is open")
	check(not hud._refs["buy:russet:1"].disabled and hud._refs["buy:russet:5"].disabled and not hud._refs.has("buy:golden:1"), "first purchase explicitly allows one Russet seed only")
	var market_page: Control = hud._refs.market_page
	check(hud._panel_crops == ["russet"] and market_page.crops == ["russet"] and not hud._refs["buy:russet:5"].visible, "first market keeps only Russet and hides bulk purchases")
	check(not market_page.selling and market_page.sell_button == null and hud._modal_trade_footer.visible and not hud._refs.has("market_sell"), "guided seed footer offers continuation without sell controls or price chart")
	check(button_for("market:sell") != null and not button_for("market:sell").is_visible_in_tree(), "HUD selling waits for its introduction")
	check(hud._known_crops().size() >= 4, "simplified seed market leaves full inventory crop catalog intact")
	check(hud._refs["buy:russet:1"].text == "Buy 1 Russet", "guided purchase names the exact seed to buy")
	hud._act("buy:russet:5")
	hud._act("buy:russet:1")
	check(actions == ["buy:russet:1"], "whitelist is enforced on dispatch as well as visual button state")
	hud.show_purchase({"kind": "seeds", "id": "russet", "name": "Russet", "quantity": 1, "cost": 800.0, "total": 13})
	hud.show_toast("An unrelated farm notification")
	hud.show_reward("A surprise", "Another distraction", "legendary")
	hud.update_state(state)
	hud._process(0.1)
	check(hud._purchase_box.visible, "actual purchase quantity remains visible during tutorial")
	check(not hud._toast_box.visible and not hud._reward_box.visible, "ordinary notifications and streaks cannot cover the introduction")
	check(not hud._crop_row.visible, "open shop keeps seed tray closed")
	check(hud._tutorial_card.get_index() > hud._modal.get_index(), "guide keeps mouse priority above modal backdrop")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = size
		await settle()
		hud._process(0.0)
		await settle()
		var guide_rect: Rect2 = hud._tutorial_card.get_global_rect()
		check(hud.root.get_global_rect().grow(0.5).encloses(guide_rect), "guide fits %s canvas" % size)
		check(not hud._tutorial_card.visible, "guide cannot cover the shop at %s" % size)
		check(not hud._tutorial_card.visible and hud._refs.starter_continue.is_visible_in_tree(), "only the shop card appears at %s" % size)
		check(hud._tutorial_body.get_minimum_size().y <= hud._tutorial_body.size.y + 0.5, "guide text wraps without vertical clipping at %s" % size)
	# The guided first sale now lives on the separate selling page/footer.
	var sale_guide: Dictionary = guide(["hoe", "plant", "water", "harvest"], ["coins", "market", "barn"], ["sell:russet:", "barn", "market_sell", "quantity_minus", "quantity_plus", "market_all", "history_older", "history_newer", "close"])
	sale_guide["id"] = "sell"
	sale_guide["continue"] = true
	sale_guide["continue_label"] = "Store for Winter →"
	state.storage["russet"] = Stock.pile(3)
	hud.set_tutorial(sale_guide)
	hud.show_market(true, state)
	await settle()
	hud._update_tutorial_pointer()
	var sale_page: Control = hud._refs.market_page
	check(sale_page.selling and sale_page.selected == "russet" and not sale_page.sell_button.disabled, "guided selling opens the available Russet stock")
	check(not hud._tutorial_card.visible and hud._modal_trade_footer.find_children("*", "Button", true, false).any(func(button): return button.get_meta("hud_action", "") == "tutorial:next"), "store choice sits on the barn page beside Sell")
	actions.clear()
	sale_page.quantity.value = 2
	sale_page._sell()
	check(actions == ["current_sell:russet:2:Standard"], "guided sale dispatches the selected quantity through the existing whitelist")
	hud.set_tutorial(guide(["hoe", "plant", "water", "harvest", "pest"], ["coins", "market", "inventory", "tools", "quests", "duck_patrol", "stock", "island", "menu"], ["inventory_tab:", "close", "menu"]))
	state.coins = 40000000000
	for panel: String in ["barn", "inventory", "tools", "quests", "duck_patrol", "pause"]:
		hud.show_panel(panel, state)
		hud.update_state(state)
		await settle()
		check(not hud._tutorial_card.visible, "%s page is the sole visible card" % panel)
		if panel == "tools": check(hud._refs["upgrade:hoe"].disabled, "guided inspection cannot spend on unrelated upgrades")
	check(button_for("debug") == null, "guided menu does not reveal debugging clutter")
	hud.set_tutorial({})
	hud.close_panel()
	await settle()
	check(not hud._tutorial_card.visible and hud._menu_button.visible, "finishing restores ordinary menu and stock countdown")
	check(hud._top.coins.is_visible_in_tree() and hud._quick_sell.is_visible_in_tree(), "finishing restores all normal stats")
	check(hud._hotbar.size.x == 508 and hud._tool_buttons.pest.visible, "full hotbar width restores")
	hud.show_panel("tools", state)
	check(not hud._refs["upgrade:hoe"].disabled, "finishing releases tutorial lock while preserving actual affordability")
	hud.show_panel("pause", state)
	check(button_for("save_page") != null and not button_for("save_page").disabled, "normal menu releases the six-tile board")
	hud.set_tutorial(guide(["hoe"], [], []))
	hud.show_panel("market", state)
	state.coins = state.bankruptcy_limit()
	hud.update_state(state)
	hud.set_tutorial({})
	check(hud._refs["buy:russet:1"].disabled, "ending tutorial never enables an unaffordable purchase")
	check(hud._refs["buy:russet:1"].text == "Buy 1" and hud._crop_row.offset_left == 28.0 and hud._crop_row.offset_right == -28.0, "leaving an early guide restores normal purchase label and full seed layout")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 800)
		hud.set_tutorial(guide(["hoe", "plant"], ["coins", "market"], ["buy:russet:1", "close"]))
		await settle()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/tutorial-hud-market.png") == OK, "capture tutorial and shop")
	hud.set_tutorial({})
	hud.close_panel()
	state.farm_help.enable()
	state.farm_help.dismiss("repeat")
	hud.set_tool("hoe")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.size = size
		hud.update_state(state)
		await settle()
		hud._process(0.0)
		await settle()
		check(not hud._farm_help_card.visible, "no automatic advice banner after tutorial at " + str(size))
	hud.set_tool("plant")
	hud._process(0.0)
	check(not hud._farm_help_card.visible, "seed tray takes priority over optional tips")
	hud.set_tool("hoe")
	hud.show_panel("market", state)
	hud._process(0.0)
	check(not hud._farm_help_card.visible, "shops take priority over optional tips")
	hud.queue_free()
	state.queue_free()
	activities.queue_free()
	await process_frame
	print("TUTORIAL HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
