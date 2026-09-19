extends SceneTree
## Real UI actions for debug controls, true trophy history, and Crown bonus presentation.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/debug-trophies-" + name + ".png") == OK, "render " + name)

func find_button(action: String) -> Button:
	for node: Node in game.hud.find_children("*", "Button", true, false):
		if node.get_meta("action", "") == action and node.is_visible_in_tree():
			return node as Button
	return null

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 1000
	game._on_action("menu")
	var menu_debug: Button = find_button("debug")
	check(menu_debug != null, "Debug is discoverable in the three-line menu")
	menu_debug.pressed.emit()
	check(game.hud._panel_kind == "debug", "menu Debug card opens the actual controls")
	game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
	game.hud._refs.debug_unlock.pressed.emit()
	find_button("debug_money:10").pressed.emit()
	find_button("debug_luck:100").pressed.emit()
	check(game.hud._refs.debug_money.value == 10 and game.hud._refs.debug_luck.value == 100, "money and luck presets change their numeric controls")
	await shot("controls")
	game.hud._refs.debug_apply.pressed.emit()
	check(game.state.coins == 10000 and game.state.debug_luck_multiplier == 100, "Apply multiplies current money once and activates debug luck")
	check(game.hud._refs.debug_money.value == 1, "applied money multiplier resets to neutral to avoid accidental repeated multiplication")
	check(game.hud._refs.debug_luck_status.text.contains("Normal luck 1.00") and game.hud._refs.debug_luck_status.text.contains("Effective luck 100.00"), "normal and debug-effective luck are shown separately")
	game.hud._refs.debug_reset.pressed.emit()
	check(game.state.coins == 10000 and game.state.debug_luck_multiplier == 1, "reset restores normal luck without rewinding money")
	check(game.hud._refs.debug_luck.value == 1 and game.hud._refs.debug_reset.disabled, "reset immediately synchronizes controls")
	game.hud.close_panel()
	game._on_action("roll")
	check(not game.hud._refs.trophy_gallery.visible, "trophy collection starts collapsed")
	game.hud._refs.trophy_toggle.pressed.emit()
	check(game.state.trophy_info().is_empty() and game.hud._refs.trophy_gallery.find_children("*", "PanelContainer", true, false).is_empty(), "fresh farm has no fabricated historic trophies")
	game.hud._refs.trophy_toggle.pressed.emit()
	game.hud.close_panel()
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	game.state.coins = 1e16
	game.state.apply_debug(1, 100)
	game.state._grant_item("aurora_crown")
	game.state.travel_to(3)
	game.state.rng.seed = 19087
	game._on_action("roll")
	check(game.hud._refs.crown_offer.visible, "equipped Crown announces its free same-stake roll before purchase")
	var before: int = game.state.roll_count
	game.hud._act("roll:normal")
	check(game.state.roll_count == before + 2 and game.hud._batch_results.size() == 2, "single purchase presents both authoritative Crown results")
	check(game.hud._refs.trophy_toggle.disabled, "new trophy outcomes stay hidden during the reel")
	game.hud._spinner._process(5)
	check(game.hud._refs.batch_results.get_child_count() == 2 and game.hud._refs.roll_result_title.text.contains("1 PAID + AURORA BONUS"), "single Crown reveal shows one paid and one free card")
	check(game.hud._batch_bonus_count() == 1, "Crown reveal marks exactly one bonus outcome")
	await shot("crown-single")
	game.hud._act("roll_batch:normal:5")
	game.hud._spinner._process(5)
	check(game.hud._refs.batch_results.get_child_count() == 6 and game.hud._refs.roll_result_title.text.contains("5 PAID + AURORA BONUS"), "five-roll purchase shows all six real results")
	var bonus_cards: int = 0
	for card: Node in game.hud._refs.batch_results.get_children():
		if bool(card.get_meta("result", {}).get("bonus_roll", false)):
			bonus_cards += 1
	check(bonus_cards == 1, "six-card batch has only one Aurora bonus label")
	await shot("crown-batch")
	game.hud._refs.trophy_toggle.pressed.emit()
	var recorded: Array = game.state.trophy_info()
	var cards: Array[Node] = game.hud._refs.trophy_gallery.find_children("*", "PanelContainer", true, false)
	check(not recorded.is_empty() and cards.size() == recorded.size(), "cabinet displays real persistent trophy entries only")
	for index: int in range(cards.size()):
		var entry: Dictionary = cards[index].get_meta("trophy", {})
		check(entry == recorded[index] and bool(entry.debug), "trophy preserves actual tier odds, count, provenance and DEBUG flag")
	(game.hud._body.get_parent() as ScrollContainer).scroll_vertical = 430
	await shot("cabinet")
	game.hud.close_panel()
	game._on_action("inventory")
	game.hud._act("inventory_tab:gear")
	check(game.hud._refs.equipment_totals.text.contains("Bonus roll +1 / purchase"), "loadout summary explains the Crown's equipped gameplay bonus")
	await shot("round-farmer")
	if capture:
		root.size = Vector2i(960, 600)
		game._on_action("debug")
		await shot("compact-controls")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("DEBUG, TROPHY AND CROWN UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
