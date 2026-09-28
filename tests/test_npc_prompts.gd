extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames() -> void:
	for i in range(8): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.state.tutorial_progress.completed = true
	game.state.debug_unlock_island(3)
	game.state.coins = 1e18
	game.set_process(false)
	for island in [1, 2, 3]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		game.state.ClimateSystem.Lesson.finish(game.state)
		game._on_state_changed()
		await frames()
		game.hud.close_panel()
		for station in ["market", "barn", "tools", "quests", "activities", "duck_patrol"]:
			if station == "activities" and island == 1: continue
			var body: StaticBody3D
			for target in game.world._interaction_targets:
				# Pooled visitors have targets too, but only live shopkeepers and
				# open stations can be approached in this fixture.
				if target.get_meta("station") == station and target.is_visible_in_tree() and target.collision_layer != 0: body = target
			check(is_instance_valid(body), "target exists: %s island %d" % [station, island])
			if not is_instance_valid(body): continue
			game.world.player.global_position = body.global_position
			game.world.player.position.y = 0
			var nearby: Dictionary = game.world.nearby_station()
			check(nearby.get("station", "") == station, "nearest station %s island %d: %s" % [station,island,nearby])
			var key := InputEventKey.new()
			key.physical_keycode = KEY_E
			key.pressed = true
			game._unhandled_input(key)
			check(game.hud.is_panel_open(), "E opens %s" % station)
			game.touch_controls.update_interaction_prompt()
			check(not game.touch_controls.interaction_prompt.visible, "prompt hidden in menu")
			game.hud.close_panel()
		for point in game.world.plot_positions:
			game.world.player.position = point
			check(game.world.nearby_station().is_empty(), "no NPC prompt over field")
		game.world.player.position = Vector3(100,0,100)
		check(game.world.nearby_station().is_empty(), "no distant prompt")
	game.state.travel_to(1)
	game.state.climate.acknowledge(game.state)
	game.hud.close_panel()
	game.world.player.position = game.world.station_position("market") + Vector3(0, 0, 3.8)
	await frames()
	game.touch_controls.update_interaction_prompt()
	check(game.touch_controls.interaction_prompt.visible, "nearby NPC badge visible")
	var point: Vector2 = game.touch_controls.interaction_prompt.get_global_rect().get_center()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.pressed = true
	root.push_input(mouse, true)
	await frames()
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse, true)
	await frames()
	check(game.conversation.visible and game.conversation.npc_id == "mara", "held badge opens seed vendor conversation")
	game.conversation.choose(0)
	check(game.hud._panel_kind == "market", "seed service opens after talking")
	var badge: Button = game.touch_controls.interaction_prompt
	var badge_style: StyleBoxFlat = badge.get_theme_stylebox("normal")
	check(badge_style.bg_color == Color.WHITE and badge_style.border_color == Color("161916"), "white E with dark outline")
	check(is_equal_approx(badge.size.x,badge.size.y),"E remains square")
	game.state.barn_level = 0
	game.hud.show_panel("barn", game.state)
	check(not game.hud._refs.has("barn_tip"), "barn shelves omit the retired filler message")
	var expansion_card: Control = game.hud._refs["upgrade:barn:card"]
	check(game.hud._body.is_ancestor_of(expansion_card) and expansion_card.is_visible_in_tree(), "barn expansion is available inside the inventory page")
	var capacity: int = game.state.capacity
	game.hud._act("upgrade:barn")
	game.hud.update_state(game.state)
	check(game.state.capacity > capacity, "barn upgrade increases capacity")
	check(not game.hud._refs.has("barn_tip"), "upgrading does not restore the retired message")
	game.state.barn_level = 20
	game.hud.update_state(game.state)
	check(game.hud._refs["upgrade:barn"].disabled, "maximum barn cannot be upgraded")
	print("NPC PROMPTS: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await frames()
	quit(1 if failures else 0)
