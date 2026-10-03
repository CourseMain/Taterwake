extends Node
## Read-only observation of a fresh farm. Inputs come through the browser UI.
## No funding, clock jumps, forced weather or planted-bed shortcuts.
const SAVE := "user://stranger-playthrough-test-only.json"
var game
var callback
var epilogue_started: int = 0
var epilogue_wait_ms: float = -1

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.state.boundary_save_path = SAVE
	game.state.season_changed.connect(func():
		if game.state.season_clock.season == 0 and not game.state.run_over: game._show_year_start())
	game.tutorial.start()
	game._show_year_start.call_deferred()
	callback = JavaScriptBridge.create_callback(observe)
	JavaScriptBridge.get_interface("window").playthroughQA = callback
	observe(["status"])

func _process(_delta: float) -> void:
	if is_instance_valid(game.epilogue_screen):
		if epilogue_started == 0: epilogue_started = Time.get_ticks_usec()
		if game.epilogue_screen.ready_scene and epilogue_wait_ms < 0:
			epilogue_wait_ms = (Time.get_ticks_usec() - epilogue_started) / 1000.0

func observe(args: Array) -> void:
	if str(args[0]) == "snapshot":
		JavaScriptBridge.eval("window.playthroughSnapshot=" + JSON.stringify(game.state._save_data()), true)
		return
	if str(args[0]) != "status": return
	var farm = game.state
	var result := {"logical": [game.hud.root.size.x, game.hud.root.size.y], "year": farm.season_clock.year,
		"season": farm.season_clock.season, "seconds": farm.season_clock.seconds, "elapsed": farm.elapsed,
		"coins": farm.coins, "run_over": farm.run_over, "outcome": farm.run_outcome,
		"panel": game.hud._panel_kind if game.hud.is_panel_open() else "", "front_page": game.year_intro.visible,
		"tutorial": game.tutorial.current_id() if game.tutorial.active else "complete", "tool": game.selected_tool,
		"walking": game.walking, "hurry": game.hurry_active, "sleeping": game.sleeping_until_spring,
		"weather": farm.climate_info(), "seeds": farm.seed_inventory, "stock": farm.storage,
		"held": farm.trading.held, "tools": farm.tools, "businesses": farm.diversification.built,
		"projects": farm.climate.data.projects, "can": farm.ClimateSystem.Operations.local(farm).can,
		"tank": farm.ClimateSystem.Operations.local(farm).water, "zoom": game.world.camera.size,
		"conversation": game.conversation.visible, "buttons": [], "labels": [], "plots": [],
		"epilogue_wait_ms": epilogue_wait_ms, "is_test_fixture": true, "clock_acceleration": "only player pace controls"}
	collect(get_tree().root, result)
	for i in range(farm.plots.size()):
		var p: Dictionary = farm.plots[i].duplicate()
		var point: Vector2 = game.world.camera.unproject_position(game.world.plot_positions[i] + Vector3(0,.1,0)) * game.hud.root.size / Vector2(game.farm_viewport.size)
		p.index = i; p.screen = [point.x, point.y]
		result.plots.append(p)
	var tank: Vector2 = game.world.camera.unproject_position(game.world._climate_field.loop.tank_position() + Vector3(0,1.5,0)) * game.hud.root.size / Vector2(game.farm_viewport.size)
	result.tank_screen = [tank.x,tank.y]
	if is_instance_valid(game.epilogue_screen):
		result.epilogue = {"ready": game.epilogue_screen.ready_scene, "result": game.epilogue_screen.result, "reveal_complete": game.epilogue_screen.reveal_complete}
	JavaScriptBridge.eval("window.playthroughReport=" + JSON.stringify(result), true)

func collect(node: Node, result: Dictionary) -> void:
	if node is Button and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		result.buttons.append({"text": node.text, "action": node.get_meta("hud_action", ""), "rect": [rect.position.x,rect.position.y,rect.size.x,rect.size.y], "disabled": node.disabled})
	elif (node is Label or node is RichTextLabel) and node.is_visible_in_tree() and not node.text.is_empty(): result.labels.append(node.text)
	for child in node.get_children(): collect(child, result)
