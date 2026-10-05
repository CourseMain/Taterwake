extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## Inspect every menu at both ends, including expanded sections and long rewards.
var game
var checks: int = 0
var failures: int = 0
var capture: bool
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for _i: int in range(6): await process_frame
func shot(tag: String, bottom: bool = false, focus: Control = null) -> void:
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud._purchase_box.hide()
	game.hud._climate_alert.dismiss()
	await settle()
	var scroll: ScrollContainer = game.hud._body.get_parent()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value) if bottom else 0
	if focus != null: scroll.ensure_control_visible(focus)
	await settle()
	check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), tag + " modal fits")
	check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, tag + " no horizontal overflow")
	if bottom:
		check(game.hud._body.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, tag + " bottom is reachable")
	for label: Node in game.hud._body.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			check(label.size.y + 1 >= label.get_minimum_size().y, tag + " wrapped text fits")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/audit-" + tag + ".png") == OK, "capture " + tag)
func page(kind: String, tag: String = "") -> void:
	game.hud.show_panel(kind, game.state)
	var name: String = kind if tag.is_empty() else tag
	await shot(name + "-top")
	await shot(name + "-bottom", true)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Begin calmly so explicit weather/practice scenarios own the fixture.
	game.state.rng.seed = 6
	await settle()
	game.set_process(false)
	game.state.coins = 8.92e+18
	for crop: String in game.state.CROP_IDS:
		game.state.seed_inventory[crop] = 30
		game.state.storage[crop] = Stock.pile(10)
	game.hud.update_state(game.state)
	game.hud.set_debug_session(true)
	for kind: String in ["market", "barn", "inventory", "tools", "pause", "dex", "quests", "duck_patrol", "debug", "graphics", "help", "climate", "accounts", "calendar", "farmer", "grades"]:
		await page(kind)
	game.hud.show_panel("dex", game.state)
	await shot("dex-crops-top")
	await shot("dex-crops-bottom", true)
	game.state.climate.begin_warning(game.state, "storm", 1.0)
	game.state.climate._impact(game.state)
	game.state._refresh_market()
	game.hud.update_state(game.state)
	await page("climate", "climate-disaster")
	root.size = Vector2i(960, 600)
	for kind: String in ["dex", "climate", "help", "debug"]:
		await page(kind, "compact-" + kind)
	await entrances()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("UI AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

const SERVICES: Array[String] = ["market", "barn", "accounts", "climate", "quests", "tools"]
const RETIRED: Array[String] = ["sell_potatoes", "quick_sell", "winter_stores", "winter_seeds", "winter_seed_choices", "loss_notices", "contracts", "store_advice", "advice:home", "advice:golden", "advice:stores", "forge", "bank", "activities"]
func entrances() -> void:
	game.hud.close_panel()
	for node in game.hud.root.find_children("*", "Button", true, false):
		var action: String = str(node.get_meta("hud_action", ""))
		check(action not in RETIRED, "no retired HUD entrance: " + action)
		if action in SERVICES: check(action in ["barn", "climate"], "farm HUD exposes only Sell and Weather shortcuts: " + action)
	for kind in ["market", "barn", "accounts", "climate", "quests", "tools", "pause", "inventory", "help", "dex", "duck_patrol", "calendar", "farmer", "grades"]:
		game.hud.show_panel(kind, game.state)
		await settle()
		var closes: int = 0
		var service_links: Array[String] = []
		for node in game.hud._modal_card.find_children("*", "Button", true, false):
			var action: String = str(node.get_meta("hud_action", ""))
			check(action not in RETIRED, kind + " has no retired route: " + action)
			if action == "close": closes += 1
			if action in SERVICES: service_links.append(action)
		check(closes == 1, kind + " has exactly one Close")
		check(service_links == (["barn"] if kind == "accounts" else []), kind + " has only its mapped service link: " + str(service_links))
	game.hud.close_panel()
	for action in RETIRED:
		game._on_action(action)
		check(not game.hud.is_panel_open(), "retired action cannot open a service: " + action)
	game._on_user_action("market")
	check(game.conversation.visible and game.conversation.service == "market" and game.conversation.choice_ids.count("service") == 1, "Mara has one conversation entrance to seeds")
	game.conversation.choose(0)
	var before: float = game.state.coins
	game._on_action("sell:russet:1:Standard")
	check(game.state.coins == before, "sales cannot bypass the barn")
	for service in ["climate", "quests", "tools", "duck_patrol", "barn"]:
		game.hud.close_panel()
		game._on_user_action(service)
		check(game.conversation.visible and game.conversation.service == service and game.conversation.choice_ids.count("service") == 1, "one keeper entrance before " + service)
		game.conversation.choose(0)
		check(game.hud._panel_kind == service, "keeper opens the canonical " + service)
	for season in range(4):
		game.state.season_clock.season = season
		game._on_user_action("accounts")
		check(game.conversation.visible and game.conversation.service == "accounts", "Nell greets before accounts in every season")
		game.conversation.choose(0)
		check(game.hud._panel_kind == "accounts", "Nell opens the same canonical accounts")
