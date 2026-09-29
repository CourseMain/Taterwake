extends Node
const Stock = preload("res://scripts/graded_stock.gd")
## Disposable browser QA only. No player saves or production debug bridge.
var game
var callback
func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.state.tutorial_progress.completed = true
	game.state.coins = 400000
	game.state.capacity = 100000
	game.state.pest_timer = 1000
	for id in game.state.CROP_IDS:
		game.state.storage[id] = Stock.pile(500)
		game.state.seed_inventory[id] = 100
	game._on_state_changed()
	callback = JavaScriptBridge.create_callback(command)
	JavaScriptBridge.get_interface("window").mobileQA = callback
func _process(delta: float) -> void:
	if is_instance_valid(game) and not game.is_processing(): game._update_camera_zoom(delta)

func command(args: Array) -> void:
	var action: String = str(args[0])
	if action == "tutorial":
		game.tutorial.start(true)
	elif action == "tutorial_sale":
		game.set_process(false)
		game.state.reset_game()
		game.state.tutorial_progress = {"version": 3, "step": 8, "completed": false, "plot": 4}
		game.state.storage["russet"] = Stock.pile(9)
		game.hud._inventory_tab = "tools"
		game.tutorial.start()
		game._on_action("barn")
	elif action.begins_with("audit_state:"):
		game.set_process(false)
		game.conversation.finish()
		game.hud.close_panel()
		game.state.reset_game()
		game.state.tutorial_progress.completed = true
		game.hud._climate_alert.dismiss()
		var stocked: bool = action.get_slice(":", 1) == "stocked"
		game.state.coins = 400000 if stocked else -1000.0
		game.state.capacity = 100000 if stocked else 200
		for id in game.state.CROP_IDS:
			game.state.storage[id] = Stock.pile(500 if stocked else 0)
			game.state.seed_inventory[id] = 100 if stocked else 0
		game._on_state_changed()
	elif action == "tank": game._select_equipment("tank")
	elif action == "guide_shop": game.hud.show_panel("market", game.state)
	elif action == "near_market":
		game.hud.close_panel()
		game._cancel_walk()
		game.world.player.position = game.world.station_position("market") + Vector3(0, 0, 3.8)
	elif action.begins_with("layout:"):
		game.set_process(false)
		game.state.climate.data.phase = "calm"
		game.state.climate.data.event = ""
		game.state.climate.data.operations.ice.clear()
		for id in game.state.ClimateSystem.PROJECTS: game.state.climate.data.projects[id] = 2
		game.hud.close_panel()
		game._on_state_changed()
	elif action == "new_farm":
		game.set_process(false)
		game.state.climate.reset()
	elif action == "freeze":
		game.state.climate.data.phase = "calm"
		game.state.climate.data.event = ""
		for plot in game.state.plots: plot.merge({"stage":2,"crop":"icecap","tilled":true,"watered":true,"elapsed":0.0},true)
		game.state.climate.begin_warning(game.state,"freeze",1)
		game.state.climate._impact(game.state)
		game.hud._climate_alert.dismiss()
		game.hud.close_panel()
		game._on_state_changed()
	elif action.begins_with("user:"): game._on_user_action(action.trim_prefix("user:"))
	elif action.begins_with("hud:"): game.hud._act(action.trim_prefix("hud:"))
	elif action == "scroll_bottom": game.hud._body.get_parent().scroll_vertical = 100000
	elif action.begins_with("quality:"): game._on_action("graphics:" + action.get_slice(":",1))
	elif action == "status": pass
	else: game._on_action(action)
	var rect: Rect2 = game.hud._modal_card.get_global_rect()
	var report := {"touch":game.touch_controls.enabled,"logical":[game.hud.root.size.x,game.hud.root.size.y],"panel":game.hud._panel_kind,"modal":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"zoom":game._zoom_target_size,"walking":game.walking,"tool":game.selected_tool,"player":[game.world.player.position.x,game.world.player.position.z]}
	report.camera = [game.world.camera.position.x, game.world.camera.position.y, game.world.camera.position.z]
	report.version = ProjectSettings.get_setting("application/config/version")
	report.window_size = [get_tree().root.size.x,get_tree().root.size.y]
	var transform: Transform2D = game.conversation.get_screen_transform()
	report.screen_transform = [transform.x.x,transform.y.y,transform.origin.x,transform.origin.y]
	report.conversation = {"visible":game.conversation.visible,"npc":game.conversation.npc_id,"page":game.conversation.page,"text":game.conversation.speech.text,"clock":game.state.elapsed}
	var voice = game.conversation.voice
	report.voice = {"speaker":voice.speaker,"utterances":voice.utterances,"playing":voice.player.playing,"pitch":voice.player.pitch_scale,"take":voice.last_clip}
	report.frozen_crops = game.state.climate.data.operations.ice.size()
	report.equipment_visible = game.hud._climate_console.is_visible_in_tree()
	report.guide_visible = game.hud._tutorial_card.is_visible_in_tree()
	report.tutorial = {"active":game.tutorial.active,"completed":game.state.tutorial_progress.completed,"step":game.tutorial.current_id(),"tab":game.hud._inventory_tab,"russets":Stock.count(game.state.storage, "russet"),"coins":game.state.coins}
	report.labels = []
	collect_labels(game.hud._modal_card, report.labels)
	collect_labels(game.conversation, report.labels)
	var scroll: ScrollContainer = game.hud._body.get_parent()
	report.content_fits = game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 1
	report.content_bottom = game.hud._body.get_global_rect().end.y
	report.scroll_bottom = scroll.get_global_rect().end.y
	report.buttons = []
	collect_buttons(game.hud.root, report.buttons)
	collect_buttons(game.touch_controls.root, report.buttons)
	collect_buttons(game.conversation, report.buttons)
	JavaScriptBridge.eval("window.mobileReport=" + JSON.stringify(report),true)

func collect_buttons(node: Node, out: Array) -> void:
	if node is Button and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		out.append({"text":node.text,"action":node.get_meta("hud_action", ""),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"disabled":node.disabled})
	for child in node.get_children(): collect_buttons(child,out)

func collect_labels(node: Node, out: Array) -> void:
	if (node is Label or node is RichTextLabel) and node.is_visible_in_tree() and not node.text.is_empty():
		out.append(node.text)
	for child in node.get_children(): collect_labels(child, out)
