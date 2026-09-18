extends SceneTree
## Winter mechanics and real scene controls, isolated from the player's save.
const SAVE: String = "user://spud_valley_winter_test_only.json"
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func button(action: String) -> Button:
	for candidate in game.hud.find_children("*", "Button", true, false):
		if candidate.get_meta("action", "") == action and candidate.is_visible_in_tree():
			return candidate as Button
	return null

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null, "visible control: " + action)
	if target != null:
		check(not target.disabled, "enabled control: " + action)
		if not target.disabled:
			target.pressed.emit()

func settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "rendered " + filename)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to isolate player saves.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.rng.seed = 79431
	check(game.test_mode, "winter test never loads or overwrites the player farm")
	game.state.travel_to(3)
	check(game.state.current_island == 1, "winter farm is earned before travel")
	game.state.coins = 151000000000.0
	game.state.mastery.russet = 25000
	game.state.unlock_island2()
	game.state.travel_to(2)
	game._on_action("island")
	press("island3_unlock")
	check(game.state.island3_unlocked, "winter unlock is wired to real requirements")
	press("travel:3")
	await settle()
	check(game.state.current_island == 3 and game.world.current_island == 3, "ferry switches state and winter scene together")
	check(game.state.plots.size() == 80 and game.world.plot_positions.size() == 80, "larger winter field has 80 manual beds")
	check(game.state.field_columns() == 10 and game.state.field_rows() == 8, "winter tools use a ten-column eight-row field")
	game._select_tool("plant")
	check(game.state.available_crops().has("icecap") and button("crop:icecap") != null, "winter crop is selectable")
	for index in range(80):
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(game.world.plot_positions[index]))
		check(int(hit.get("plot_index", -1)) == index, "snowy plot target: %d" % index)
	var stations: Dictionary = {"barn": Vector3(-18, 2, -12), "market": Vector3(-3, 1.8, -14), "roll": Vector3(15, 2, -12), "quests": Vector3(-15, 1.5, 14), "island": Vector3(22, 1.2, 10), "tools": Vector3(18, 1.5, 2)}
	for station in stations:
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(stations[station]))
		check(hit.get("station", "") == station, "winter station target: " + station)
	await shot("frosthollow-arrival")
	for index in range(80):
		game.perform_plot(index, "hoe")
	game._on_action("quests")
	press("quest:winter_ground")
	check(game.state.seed_inventory.icecap == 5, "preparing the winter field supplies five starter seeds")
	game.hud.close_panel()
	press("crop:icecap")
	game.state.pest_timer = 100.0
	game.perform_plot(0, "plant")
	game._process(5.1)
	check(game.state.plots[0].elapsed == 0.0, "winter crop needs manual watering")
	game.perform_plot(0, "water")
	game._process(59.9)
	check(game.state.plots[0].stage != 3, "market timing changes do not shorten crop growth")
	game._process(0.11)
	check(game.state.plots[0].stage == 3, "Icecap matures after its actual sixty seconds")
	game.perform_plot(0, "harvest")
	check(game.state.storage.icecap > 0, "winter farming stores its valuable harvest")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	game._unhandled_input(key)
	check(game.hud.is_panel_open(), "I opens the combined inventory")
	await shot("inventory-winter")
	game.hud.close_panel()
	# No passive reward: leaving an entire frost challenge unattended melts it away.
	game.state.frost_timer = 0.05
	game._process(0.06)
	check(game.state.frost_active, "winter storm creates a timed manual challenge")
	var frozen_count: int = 0
	for plot in game.state.plots:
		if plot.get("frozen", false):
			frozen_count += 1
	check(frozen_count == 12, "Frostbreak freezes exactly twelve field beds")
	await shot("frosthollow-frostbreak")
	var coins_before: float = game.state.coins
	game._process(20.1)
	check(not game.state.frost_active and game.state.thaw_remaining == 0.0, "waiting out the storm cannot earn its auction")
	check(game.state.coins == coins_before, "snowfall does not award passive coins")
	for round_index in range(3):
		game.state.frost_timer = 0.05
		game._process(0.06)
		var frozen: Array[int] = []
		for index in range(80):
			if game.state.plots[index].get("frozen", false):
				frozen.append(index)
		for index in frozen:
			game.perform_plot(index, "hoe")
		check(not game.state.frost_active and game.state.thaw_remaining > 0.0, "manual ice breaking opens the thaw auction")
		check(game.state.thaw_remaining <= 5.0, "thaw sale multiplier is temporary")
		game._process(5.1)
		check(game.state.thaw_remaining == 0.0, "winter auction multiplier is removed after five seconds")
	game._on_action("quests")
	press("quest:winter_frost")
	game.hud.close_panel()
	# Expensive manual tools provide a concrete use for winter profits.
	game.state.coins = 10000000000000.0
	game.state.tools.hoe = 2
	game.state.tools.water = 2
	game.state.tools.harvest = 2
	game._on_action("forge")
	press("upgrade:hoe")
	press("upgrade:water")
	press("upgrade:harvest")
	check(game.state.tools.hoe == 3 and game.state.tools.water == 3 and game.state.tools.harvest == 3, "winter workshop purchases all three expensive tool grades")
	check(game.state.affected_tiles(34, "hoe").size() == 25 and game.state.affected_tiles(34, "water").size() == 49, "winter upgrades expand one manual action")
	check(game.state.affected_tiles(34, "harvest").size() == 50, "winter scythe handles five full rows")
	await shot("winter-workshop")
	game.hud.close_panel()
	game.state.coins = 2.5e15
	game._on_state_changed()
	check(game.hud._top.coins.text.contains("Qa"), "winter fortunes display in quadrillions")
	game.state.frost_timer = 0.05
	game._process(0.06)
	check(game.state.save_game(SAVE), "winter field and active challenge save")
	game._on_action("reset")
	check(game.world.current_island == 1 and not game.state.island3_unlocked, "reset restores starter world")
	check(game.state.load_game(SAVE), "winter save reloads without losing crops or challenges")
	await settle()
	check(game.world.current_island == 3 and game.state.frost_active, "reload rebuilds the snowy field and frozen beds")
	game._on_action("travel:1")
	await settle()
	check(game.world.plot_positions.size() == 24, "winter round trip preserves original farm")
	game._on_action("travel:2")
	await settle()
	check(game.world.plot_positions.size() == 48, "winter round trip preserves Golden Shores")
	game._on_action("travel:3")
	await settle()
	check(game.world.plot_positions.size() == 80, "all three islands remain visitable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await process_frame
	print("FROSTHOLLOW INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
