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

	game._on_user_action("market")
	check(game.conversation.visible and game.conversation.service == "market", "first visit meets Mara before seeds")
	game.conversation.choose(0)
	check(not game.hud._modal_card.find_children("*", "Button", true, false).any(func(b): return b.get_meta("hud_action", "") in ["market", "barn"]), "Mara has no selling tab")
	check(game.hud._body.find_children("*", "Button", true, false).any(func(button): return button.text == "Talk"), "flavour conversation has one small Talk entrance")
	var inventory: Dictionary = state.storage.duplicate(true)
	var seeds: Dictionary = state.seed_inventory.duplicate(true)
	var cash: float = state.coins
	var prices: Dictionary = state.market.duplicate(true)
	for _i in range(3):
		game._on_user_action("barn")
		check(game.conversation.visible and game.conversation.service == "barn", "selling meets the barn keeper")
		game.conversation.choose(0)
		check(game.hud._panel_kind == "barn", "barn greeting opens the canonical sell page")
		game._on_user_action("market")
		check(game.conversation.visible and game.conversation.service == "market", "seed re-entry meets Mara again")
		game.conversation.choose(0)
	check(state.npc_history.is_empty(), "short seasonal shop greetings preserve intentional conversation memory")
	check(state.storage == inventory and state.seed_inventory == seeds and state.coins == cash and state.market == prices, "service navigation changes no farm amounts")
	game._on_action("talk:mara")
	check(game.conversation.visible and game.conversation.npc_id == "mara", "Talk opens Mara’s personal greeting")
	game.conversation.choose(1)
	check(game.conversation.speech.text == state.NpcRoster.PEOPLE.mara.story, "bag-mending story remains available")
	game.conversation.finish(true)
	check(game.hud._panel_kind == "market" and not game.conversation.visible, "the single conversation exit returns to seeds")
	var memory: Dictionary = state.npc_history.duplicate(true)
	check(state.save_game(SAVE), "save intentional conversation memory")
	state.npc_history.clear()
	check(state.load_game(SAVE) and state.npc_history == memory, "conversation memory survives reload")
	game.hud.close_panel()
	game._interact_station("market")
	check(game.conversation.visible and game.conversation.service == "market" and state.npc_history == memory, "walking to the stall meets Mara with the saved conversation memory")
	game.conversation.choose(0)
	state.reset_game()
	check(state.npc_history.is_empty(), "new farm keeps existing NPC reset behavior")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("MARKET DIALOGUE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
