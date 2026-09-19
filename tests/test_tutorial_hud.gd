extends SceneTree
## A staged introduction stays calm, readable, and safe around every shop.
const State = preload("res://scripts/game_state.gd")
const HUD = preload("res://scripts/game_hud.gd")
const Activities = preload("res://scripts/island_activities.gd")
const Builds = preload("res://scripts/player_builds.gd")
var state
var hud
var activities
var builds
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
	return {"id": "market", "title": "Grab a seed", "body": "Follow the arrow to the market.\nBuy 1 Russet seed.", "step": 3, "total": 20, "tools": tools, "features": features, "allowed_actions": allowed, "continue": true}

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
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(builds)
	hud = HUD.new()
	root.add_child(hud)
	hud.action_requested.connect(func(action: String) -> void: actions.append(action))
	hud.update_state(state)
	hud.set_process(false)
	hud.set_market_intensity(1, 1800.0)
	check(hud._market_impact.active, "normal market can display a jackpot")
	hud.set_tutorial(guide())
	await settle()
	check(hud._tutorial_card.visible and hud.root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "intro card appears without a blocking full-screen tutorial overlay")
	check(not hud._hotbar.visible and not hud._stats_card.visible and not hud._menu_button.visible, "intro starts without unexplained controls or stats")
	check(not hud._export_box.visible and not hud._market_impact.visible and not hud._market_impact.is_processing(), "starting or replaying guide clears previous jackpot")
	check(not hud._quick_sell.visible and not hud._sidebar_box.visible, "sale actions and sidebar wait for their introduction")
	hud.set_tool("pest")
	check(hud._selected_tool == "hoe", "hidden tools cannot be equipped through HUD API")
	hud._act("roll:all_in")
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
	check(hud._top.coins.is_visible_in_tree() and not hud._top.price.is_visible_in_tree() and not hud._top.luck.is_visible_in_tree(), "coins reveal independently from stocks and luck")
	check(hud._crop_row.visible and not hud._tracked_box.visible, "first planting shows seeds without tracked price clutter")
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
	purchase_guide["continue"] = false
	hud.set_tutorial(purchase_guide)
	hud._update_tutorial_pointer()
	check(hud._tutorial_pointer.target == hud._refs["buy:russet:1"], "pointer targets the real enabled Russet buy button")
	check(hud._tutorial_next.visible and hud._tutorial_next.disabled and hud._tutorial_skip.get_global_rect().end.y < hud._tutorial_next.get_global_rect().position.y, "exit is above the lesson and cannot replace the disabled action prompt")
	check(not hud._refs["buy:russet:1"].disabled and hud._refs["buy:russet:5"].disabled and not hud._refs.has("buy:golden:1"), "first purchase explicitly allows one Russet seed only")
	check(hud._panel_crops == ["russet"] and not hud._refs["buy:russet:5"].visible and not hud._refs["sell:russet:-1"].visible and not hud._refs["russet:graph"].visible, "first market removes other crops, bulk buys, sell buttons, and price graphs")
	check(hud._known_crops().size() >= 4, "simplified seed market leaves full inventory crop catalog intact")
	check(hud._refs["buy:russet:1"].text == "Buy 1 Russet", "guided purchase names the exact seed to buy")
	hud._act("buy:russet:5")
	hud._act("buy:russet:1")
	check(actions == ["buy:russet:1"], "whitelist is enforced on dispatch as well as visual button state")
	hud.show_purchase({"kind": "seeds", "id": "russet", "name": "Russet", "quantity": 1, "cost": 20.0, "total": 13})
	hud.show_toast("An unrelated farm notification")
	hud.show_reward("A surprise", "Another distraction", "legendary")
	hud.set_market_intensity(1, 3000.0)
	hud.show_market_surge(1, 1.0, 5.0)
	state.combo_time = 2.0
	state.surge_timer = 3.0
	hud.update_state(state)
	hud._process(0.1)
	check(hud._purchase_box.visible, "actual purchase quantity remains visible during tutorial")
	check(not hud._toast_box.visible and not hud._reward_box.visible and not hud._combo_box.visible, "ordinary notifications and streaks cannot cover the introduction")
	check(not hud._market_impact.visible and not hud._export_box.visible and not hud._surge_urgent, "state refresh and frame update cannot revive countdown or aura")
	check(not hud._crop_row.visible and not hud._tracked_box.visible, "open shop keeps seed tray closed")
	check(hud._tutorial_card.get_index() > hud._modal.get_index(), "guide keeps mouse priority above modal backdrop")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = size
		await settle()
		hud._process(0.0)
		await settle()
		var guide_rect: Rect2 = hud._tutorial_card.get_global_rect()
		check(hud.root.get_global_rect().grow(0.5).encloses(guide_rect), "guide fits %s canvas" % size)
		check(not guide_rect.intersects(hud._modal_card.get_global_rect()), "guide leaves shop unobscured at %s" % size)
		check(guide_rect.grow(0.5).encloses(hud._tutorial_skip.get_global_rect()) and guide_rect.grow(0.5).encloses(hud._tutorial_next.get_global_rect()), "both guide actions fit at %s" % size)
		check(hud._tutorial_body.get_minimum_size().y <= hud._tutorial_body.size.y + 0.5, "guide text wraps without vertical clipping at %s" % size)
	hud.set_tutorial(guide(["hoe", "plant", "water", "harvest", "pest"], ["coins", "market", "inventory", "tools", "builds", "quests", "roll", "duck_patrol", "stock", "island", "menu"], ["inventory_tab:", "close", "menu"]))
	state.coins = 1e9
	for panel: String in ["barn", "inventory", "tools", "builds", "quests", "roll", "duck_patrol", "island", "pause"]:
		hud.show_panel(panel, state)
		hud.update_state(state)
		await settle()
		check(not hud._tutorial_card.get_global_rect().intersects(hud._modal_card.get_global_rect()), "%s panel keeps guide in clear left margin" % panel)
		check(hud._tutorial_card.is_visible_in_tree() and not hud._tutorial_skip.disabled, "%s panel leaves skip available" % panel)
		if panel == "tools":
			check(hud._refs["upgrade:hoe"].disabled, "affordable tool upgrades stay disabled on guided inspection")
		if panel == "roll":
			check(hud._refs["roll:normal"].disabled, "affordable roll cannot spend during guided inspection")
	check(hud._top.market_name.text == "STOCKS PAUSED" and hud._top.price.text == "After the tour", "stock introduction explains calm market without countdown excitement")
	check(hud._crop_row.anchor_left == 0.0 and hud._crop_row.anchor_right == 1.0 and hud._crop_row.offset_left == 28.0 and hud._crop_row.offset_right == -28.0, "stock introduction restores full seed tray layout")
	check(button_for("debug") == null, "guided menu does not reveal debugging clutter")
	hud.set_tutorial({})
	hud.close_panel()
	await settle()
	check(not hud._tutorial_card.visible and hud._menu_button.visible and hud._export_box.visible, "finishing restores ordinary menu and stock countdown")
	check(hud._top.coins.is_visible_in_tree() and hud._top.price.is_visible_in_tree() and hud._top.luck.is_visible_in_tree(), "finishing restores all normal stats")
	check(hud._hotbar.size.x == 508 and hud._tool_buttons.pest.visible, "full hotbar width restores")
	hud.show_panel("tools", state)
	check(not hud._refs["upgrade:hoe"].disabled, "finishing releases tutorial lock while preserving actual affordability")
	hud.show_panel("pause", state)
	check(button_for("tutorial:restart") != null and not button_for("tutorial:restart").disabled, "normal menu offers repeatable guided introduction")
	hud.set_tutorial(guide(["hoe"], [], []))
	hud.show_panel("market", state)
	state.coins = 0.0
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
	hud.queue_free()
	state.queue_free()
	activities.queue_free()
	builds.queue_free()
	await process_frame
	print("TUTORIAL HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
