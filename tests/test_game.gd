extends SceneTree
## Runs the actual scene and button wiring without loading or modifying player saves.
var checks: int = 0
var failures: int = 0
var game
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
		if str(candidate.get_meta("action", "")) == action and candidate.is_visible_in_tree():
			return candidate as Button
	return null

func press(action: String) -> bool:
	var target: Button = button(action)
	check(target != null, "visible button: " + action)
	if target == null:
		return false
	check(not target.disabled, "enabled button: " + action)
	if target.disabled:
		return false
	target.pressed.emit()
	return true

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "rendered " + filename)

func finish_spin() -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while game.hud.is_roll_animating() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.hud.is_roll_animating(), "reward reel reaches its result and unlocks controls")

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to isolate player save data.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	check(game.test_mode, "isolated fresh session")
	check(game.world.plot_positions.size() == 24, "original 24 farm plots preserved")
	check(is_instance_valid(game.world.player) and game.world.camera.current, "original farmer and camera active")
	check(not game.hud.is_panel_open(), "farm available immediately")
	check(game.state.available_crops().size() == 4, "four crop varieties available")
	await shot("spud-valley")
	for station in {"barn": Vector3(-12, 2, -8), "market": Vector3(0, 1.8, -9), "roll": Vector3(10, 2, -8)}:
		var location: Vector3 = {"barn": Vector3(-12, 2, -8), "market": Vector3(0, 1.8, -9), "roll": Vector3(10, 2, -8)}[station]
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(location))
		check(str(hit.get("station", "")) == station, "click reaches " + station + " building")
	var plot_hit: Dictionary = game.world.pick(game.world.camera.unproject_position(game.world.plot_positions[5]))
	check(int(plot_hit.get("plot_index", -1)) == 5, "mouse picking identifies exact plot")
	var starting_position: Vector3 = game.world.player.position
	Input.action_press("move_right")
	game._process(0.1)
	Input.action_release("move_right")
	check(game.world.player.position.distance_to(starting_position) > 0.1, "WASD movement responds")
	game._on_action("market")
	check(game.hud.is_panel_open(), "market screen opens")
	await shot("market")
	var before_coins: float = game.state.coins
	var seed_cost: float = game.state.market.russet.seed
	var before_seeds: int = game.state.seed_inventory.russet
	press("buy:russet:1")
	check(is_equal_approx(game.state.coins, before_coins - seed_cost), "buy button pays current seed price")
	check(game.state.seed_inventory.russet == before_seeds + 1, "seed purchase reaches farm inventory")
	var before_time: float = game.state.elapsed
	game._process(5.2)
	check(game.state.elapsed > before_time + 5.0, "world continues while market is open")
	check(game.state.market.russet.history.size() >= 2, "live graph records market movement")
	game.hud.close_panel()
	check(not game.hud.is_panel_open(), "close returns to world")
	game._select_tool("harvest")
	game.queue_plot(0)
	for step in range(100):
		game._process(0.05)
	check(game.state.storage.russet > 0, "click walks to plot and stores harvested potatoes")
	check(int(game.state.plots[0].stage) == 0, "harvest changes the plot mesh state")
	var held: int = game.state.storage.russet
	game._process(4.0)
	check(game.state.storage.russet == held, "market movement never automatically sells stored crops")
	game._on_action("barn")
	await shot("barn")
	before_coins = game.state.coins
	var sale_price: float = game.state.market.russet.sell
	press("sell:russet:-1")
	check(game.state.storage.russet == 0, "barn sell button consumes held crops")
	check(game.state.coins > before_coins, "barn sale pays farming proceeds")
	game.hud.close_panel()
	# Farming needs separate player actions to prepare, plant and water.
	game.state.pest_timer = 100.0
	game.perform_plot(5, "hoe")
	check(game.state.plots[5].tilled, "manual hoe prepares soil")
	game.perform_plot(5, "plant")
	check(game.state.plots[5].stage == 1 and not game.state.plots[5].watered, "manual planting leaves a thirsty crop")
	game._process(12.0)
	check(game.state.plots[5].stage != 3, "unwatered crops do not grow unattended")
	game.perform_plot(5, "water")
	game._process(10.1)
	check(game.state.plots[5].stage == 3, "watered crop matures on continuous time")
	game.state.coins = 100000.0
	game._on_action("tools")
	await shot("tools")
	press("upgrade:water")
	check(game.state.tools.water == 1, "tool upgrade purchases manual area watering")
	press("upgrade:expansion")
	check(game.state.plots[23].unlocked, "field expansion opens lower plots")
	check(game.state.affected_tiles(7, "water").size() == 9, "watering can works a 3-by-3 area")
	press("upgrade:harvest")
	check(game.state.tools.harvest == 1, "row harvest tool is equipped")
	game.hud.close_panel()
	game.state.capacity = 2000
	for index in range(6):
		game.state.plots[index].stage = 3
		game.state.plots[index].crop = "russet"
		game.state.plots[index].pending = 0
	game.state.update(4.0)
	game.perform_plot(0, "harvest")
	var cleared: int = 0
	for index in range(6):
		if game.state.plots[index].stage == 0:
			cleared += 1
	check(cleared == 6, "one manual scythe action clears an entire row")
	check(game.state.combo_multiplier == 16, "row harvest builds an x16 combo")
	await shot("harvest-combo")
	game._on_action("roll")
	await shot("roll-house")
	var odds_total: float = 0.0
	for tier in game.state.roll_odds():
		odds_total += float(tier.get("chance", tier.get("probability", tier.get("percent", 0.0))))
	check(is_equal_approx(odds_total, 100.0), "displayed roll tier odds total exactly 100 percent")
	# The scene verifies that all-in needs two separate presses, then resolves once.
	var prior_all_in_rolls: int = game.state.roll_count
	var prior_all_in_coins: float = game.state.coins
	press("roll:all_in")
	check(game.state.roll_count == prior_all_in_rolls and game.state.coins == prior_all_in_coins, "all-in first press only asks for confirmation")
	press("roll:all_in")
	check(game.state.roll_count == prior_all_in_rolls + 1, "all-in confirmation resolves exactly one roll")
	check(game.hud.is_roll_animating(), "real reward is revealed by the animated reel")
	game._on_action("roll:normal")
	game._on_action("reset")
	check(game.state.roll_count == prior_all_in_rolls + 1, "spinning blocks duplicate wagers and reset")
	await create_timer(0.4).timeout
	await shot("roll-spinner")
	await finish_spin()
	game.state.coins = 500.0
	game.hud.update_state(game.state)
	var previous_rolls: int = game.state.roll_count
	var expected_pulls: int = 1 + int(game.state.crown_bonus_active())
	press("roll:normal")
	check(game.state.roll_count == previous_rolls + expected_pulls, "Roll House button resolves its real roll and any equipped crown bonus")
	check(game.state.coins >= 0.0, "roll balance never becomes negative")
	await finish_spin()
	game.hud.close_panel()
	game.state._try_mutation("russet", true)
	check(not game.state.mutations.is_empty() and not game.state.dex.is_empty(), "rare harvest enters held mutation storage and PotatoDex")
	await shot("mutation")
	game._on_action("dex")
	check(game.hud.is_panel_open(), "PotatoDex opens")
	await shot("potatodex")
	game.hud.close_panel()
	game._on_action("island")
	check(game.hud.is_panel_open(), "locked second island is inspectable")
	await shot("golden-shores")
	game.hud.close_panel()
	game._on_action("help")
	await shot("guide")
	if capture:
		game.hud.close_panel()
		game.state.update(21.0)
		game.state._start_event("shortage")
		game._on_state_changed()
		game._on_action("market")
		await shot("market-spike")
	game.hud.close_panel()
	game.queue_free()
	await process_frame
	print("SPUD VALLEY INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
