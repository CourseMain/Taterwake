extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## Navigation must never masquerade as another visit to the seed seller.
const SAVE := "user://taterwake_market_dialogue_test_only.json"
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for _i in range(5): await process_frame

func navigate(action: String) -> void:
	check(game.hud._modal_market_nav.is_visible_in_tree() and game.hud._modal_market_nav.get_child_count() == 2, "Mara’s shop has two fixed trading tabs")
	for button: Node in game.hud._modal_market_nav.get_children():
		if str(button.get_meta("action", "")) == action:
			button.pressed.emit()
			return
	check(false, "shop tab exists: " + action)

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.climate.reset()
	game.state.season_clock.seconds = 1.0
	game.hud.set_process(false)
	var state = game.state
	state.tutorial_progress.completed = true
	state.npc_history.clear()
	state.coins = 400000
	state.storage["giant"] = Stock.pile(7)
	game.hud.close_panel()

	# The first ordinary Buy entry retains the intended introduction.
	game._on_user_action("market")
	check(game.conversation.visible and game.conversation.npc_id == "mara", "first Buy visit introduces Mara")
	check(game.conversation.speech.text == state.NpcRoster.PEOPLE.mara.first, "first greeting remains intact")
	game.conversation.choose(0)
	await settle()
	check(game.hud._panel_kind == "market", "Mara's service opens Buy Seeds")
	var memory: Dictionary = state.npc_history.duplicate(true)
	var inventory: Dictionary = state.storage.duplicate(true)
	var seeds: Dictionary = state.seed_inventory.duplicate(true)
	var cash: float = state.coins
	var prices: Dictionary = state.market.duplicate(true)
	await navigate("sell_potatoes")
	await settle()
	game.hud._refs.market_page.select_variety("giant")
	var selected: String = game.hud._refs.market_page.selected
	game.hud._refs.market_page.quantity.value = 2
	await navigate("sell_potatoes")
	check(game.hud._refs.market_page.quantity.value == 2 and game.hud._modal_market_nav.get_child(1).button_pressed, "active Sell tab keeps its selection and amount")
	for _i in range(3):
		await navigate("market")
		await settle()
		check(not game.conversation.visible and game.hud._panel_kind == "market", "Buy re-entry opens without replaying dialogue")
		await navigate("sell_potatoes")
		await settle()
		check(not game.conversation.visible and game.hud._panel_kind == "sell_potatoes", "Sell tab opens Mara’s selling counter")
		check(game.hud._refs.market_page.selected == selected, "page re-entry retains selected selling variety")
	check(state.npc_history == memory, "shop tabs do not record extra NPC visits")
	check(state.storage == inventory and state.seed_inventory == seeds and state.coins == cash, "navigation preserves inventory and wallet")
	check(state.market == prices, "navigation preserves the live quotes and history")

	# Ordinary re-entry uses the established save memory, not a transient flag.
	game.hud.close_panel()
	game._on_user_action("market")
	check(not game.conversation.visible and game.hud._panel_kind == "market", "reopening Buy does not repeat a completed greeting")
	check(state.save_game(SAVE), "save introduction using existing game save")
	state.npc_history.clear()
	check(state.load_game(SAVE), "restore existing NPC memory")
	game.hud.close_panel()
	game._on_user_action("market")
	check(not game.conversation.visible and state.npc_history == memory, "loaded introduction stays completed")

	# Both intentional paths to another conversation still work.
	game._on_action("talk:mara")
	check(game.conversation.visible and game.conversation.npc_id == "mara", "explicit Talk to Mara remains available")
	check(game.conversation.speech.text != state.NpcRoster.PEOPLE.mara.first, "intentional revisit uses remembered greeting")
	game.conversation.choose(0)
	check(game.hud._panel_kind == "market", "explicit conversation returns to its service")
	game.hud.close_panel()
	game._interact_station("market")
	check(game.conversation.visible and game.conversation.npc_id == "mara", "visiting Mara's stall deliberately talks again")
	game.conversation.choose(0)

	# Selling has no keeper introduction; the next seed visit still meets Mara.
	game.hud.close_panel()
	state.npc_history.clear()
	game._on_user_action("sell_potatoes")
	await settle()
	check(not game.conversation.visible and state.npc_history.is_empty(), "Sell does not fabricate a seed-counter introduction")
	await navigate("market")
	await settle()
	check(game.conversation.visible and game.conversation.speech.text == state.NpcRoster.PEOPLE.mara.first, "first seed entry still introduces Mara after selling")
	game.conversation.finish()
	state.reset_game()
	check(state.npc_history.is_empty(), "new farm keeps existing NPC reset behavior")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("MARKET DIALOGUE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
