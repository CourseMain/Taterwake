extends SceneTree
var checks := 0
var failures := 0
const SAVE := "user://keeper-greeting-test-only.json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	game.state.tutorial_progress.completed = true
	var tap := InputEventMouseButton.new(); tap.button_index = MOUSE_BUTTON_LEFT; tap.pressed = true
	for service in ["market:sell","climate","tools","quests","accounts","duck_patrol"]:
		game._on_user_action(service)
		check(game.conversation.visible, "first visit greets " + service)
		game.conversation._gui_input(tap)
		check(not game.conversation.visible and game.hud._panel_kind == service.get_slice(":",0), "one greeting tap opens " + service)
		game.hud.close_panel(); game._on_user_action(service)
		check(not game.conversation.visible and game.hud._panel_kind == service.get_slice(":",0), "no second greeting this season " + service)
		game.hud.close_panel()
	game._on_user_action("barn")
	check(not game.conversation.visible and game.hud._panel_kind == "barn", "Nell shares one greeting across accounts and barn")
	game.hud.close_panel()
	check(game.state.save_game(SAVE) and game.state.load_game(SAVE), "greeting stamps survive a save reload")
	game._on_user_action("market")
	check(not game.conversation.visible and game.hud._panel_kind == "market", "Buy and Sell share Mara's remembered greeting after reload")
	game.hud.close_panel(); game.state.season_clock.season = 1
	game._on_user_action("market")
	check(game.conversation.visible, "a new season has a new greeting")
	game._on_user_action("market")
	check(not game.conversation.visible and game.hud._panel_kind == "market", "same entrance tap dismisses and opens the service")
	game.hud.close_panel(); game.state.reset_game()
	game.state.tutorial_progress.completed = true; game._on_user_action("market")
	check(game.conversation.visible, "a new farm resets seasonal meetings")
	game.conversation.finish(); game.queue_free(); await process_frame
	for suffix in ["", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("KEEPER GREETINGS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
