extends Node
## Disposable browser QA only. No player saves or production debug bridge.
var game
var callback
func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.state.debug_unlock_island(3)
	game.state.travel_to(1)
	game.state.climate.acknowledge(game.state)
	game.state.tutorial_progress.completed = true
	game.state.coins = 1e18
	game.state.capacity = 100000
	game.state.pest_timer = 1000
	game.state.surge_timer = 1000
	for id in game.builds.IDS: game.builds.levels[id] = 20
	for id in game.state.CROP_IDS:
		game.state.storage[id] = 500
		game.state.seed_inventory[id] = 100
	game._on_state_changed()
	callback = JavaScriptBridge.create_callback(command)
	JavaScriptBridge.get_interface("window").mobileQA = callback
func command(args: Array) -> void:
	var action: String = str(args[0])
	if action == "tutorial":
		game.state.travel_to(1)
		game.tutorial.start(true)
	elif action.begins_with("build:"):
		game.hud._build_selection = action.get_slice(":",1)
		game._on_action("builds")
	elif action == "island2":
		game.state.travel_to(2)
		game.state.climate.acknowledge(game.state)
	elif action == "tank": game._select_equipment("tank")
	elif action == "guide_shop": game.hud.show_panel("market", game.state)
	elif action == "intro":
		game.state.climate.data.lesson.stage = "off"
		game.state.climate.data.intro_pending = true
		game._on_state_changed()
	elif action == "status": pass
	else: game._on_action(action)
	var rect: Rect2 = game.hud._modal_card.get_global_rect()
	var report := {"touch":game.touch_controls.enabled,"logical":[game.hud.root.size.x,game.hud.root.size.y],"panel":game.hud._panel_kind,"modal":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"zoom":game._zoom_target_size,"walking":game.walking,"tool":game.selected_tool,"player":[game.world.player.position.x,game.world.player.position.z]}
	report.equipment_visible = game.hud._climate_console.is_visible_in_tree()
	report.guide_visible = game.hud._tutorial_card.is_visible_in_tree()
	report.buttons = []
	collect_buttons(game.hud.root, report.buttons)
	collect_buttons(game.touch_controls.root, report.buttons)
	JavaScriptBridge.eval("window.mobileReport=" + JSON.stringify(report),true)

func collect_buttons(node: Node, out: Array) -> void:
	if node is Button and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		out.append({"text":node.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"disabled":node.disabled})
	for child in node.get_children(): collect_buttons(child,out)
