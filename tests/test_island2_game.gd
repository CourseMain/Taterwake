extends SceneTree
## Exercises the actual travel, quest, crop, and export controls with isolated data.
const SAVE: String = "user://spud_valley_island2_scene_test.json"
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

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null, "visible button: " + action)
	if target == null:
		return
	check(not target.disabled, "enabled button: " + action)
	if not target.disabled:
		target.pressed.emit()

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "rendered " + filename)

func settle_world() -> void:
	await process_frame
	await physics_frame
	await physics_frame

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to isolate player saves.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle_world()
	game.set_process(false)
	game.state._event_in = 100000.0
	check(game.test_mode, "test cannot load or overwrite player save")
	game._on_action("island")
	check(button("island_unlock") != null and button("island_unlock").disabled, "new farms see actual gated travel requirements")
	game.state.mastery.russet = 500
	game.state.coins = 1300000.0
	game._on_state_changed()
	press("island_unlock")
	check(game.state.island2_unlocked and game.state.coins == 300000.0, "unlock button charges exactly $1M once")
	press("travel:2")
	await settle_world()
	check(game.world.current_island == 2 and game.state.current_island == 2, "travel button switches scene and state together")
	check(game.world.plot_positions.size() == 48 and game.state.plots.size() == 48, "Golden Shores has all 48 playable plots")
	check(not game.hud.is_panel_open(), "arrival returns control to the farmer")
	check(game.hud._toast_box.size.y < 160.0, "rapid unlock and travel notifications remain compact")
	game._select_tool("plant")
	check(button("crop:sunburst") != null, "exclusive Sunburst selection appears on Island 2")
	for index in range(48):
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(game.world.plot_positions[index]))
		check(int(hit.get("plot_index", -1)) == index, "tropical plot is clickable: %d" % index)
	for station in {"barn": Vector3(-15, 2, -10), "market": Vector3(-1, 1.8, -11), "roll": Vector3(13, 2, -10), "quests": Vector3(-12, 1.5, 11), "island": Vector3(16, 1.2, 7)}:
		var locations: Dictionary = {"barn": Vector3(-15, 2, -10), "market": Vector3(-1, 1.8, -11), "roll": Vector3(13, 2, -10), "quests": Vector3(-12, 1.5, 11), "island": Vector3(16, 1.2, 7)}
		var hit: Dictionary = game.world.pick(game.world.camera.unproject_position(locations[station]))
		check(str(hit.get("station", "")) == station, "tropical building can be clicked: " + station)
	await shot("golden-shores-arrival")
	for index in range(48):
		game.perform_plot(index, "hoe")
	check(game.state.quest_progress.ground == 48, "manual work on the real scene progresses first quest")
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_Q
	game._unhandled_input(event)
	check(game.hud.is_panel_open(), "Q opens the quest board")
	press("quest:ground")
	check(game.state.coins == 400000.0 and game.state.seed_inventory.sunburst == 5, "claim button pays $100K and five Sunburst seeds")
	check(button("quest:ground") == null or button("quest:ground").disabled, "claimed reward cannot be collected twice")
	game.hud.close_panel()
	press("crop:sunburst")
	game.state.pest_timer = 100.0
	for index in range(5):
		game.perform_plot(index, "plant")
		game.perform_plot(index, "water")
	game._process(45.1)
	check(game.state.plots[4].stage == 3, "new crop matures only after manual planting and watering")
	for index in range(5):
		game.perform_plot(index, "harvest")
	check(game.state.quest_progress.sunburst > 0 and game.state.quest_progress.sunburst < 10000, "first harvest progresses a longer farming quest")
	check(game.state.quest_progress.mutation == 1 and game.state.shores_first_mutation, "first manual Sunburst harvest produces the Golden discovery")
	check(game.state.coins == 400000.0, "one discovery no longer grants an immediate eight-figure windfall")
	game._on_action("quests")
	check((button("quest:sunburst") == null or button("quest:sunburst").disabled) and (button("quest:mutation") == null or button("quest:mutation").disabled), "larger quest goals cannot be claimed from one starter harvest")
	await shot("golden-shores-quests")
	await process_frame
	check(game.hud._reward_box.size.y < 240.0, "reward notices remain compact")
	game.hud.close_panel()
	# A late-game inventory fixture exercises a full-size export sale through the real UI.
	game.state.coins = 20000000000.0
	for upgrade in range(7):
		game.state.upgrade_barn()
	game.state.storage.sunburst = 1000000
	game._on_action("market")
	check(button("buy:sunburst:1") != null and button("sell:sunburst:-1") != null, "exclusive crop has live buy and sell controls")
	var seed_price: float = game.state.market.sunburst.seed
	game.state.export_timer = 0.05
	game._process(0.06)
	check(game.state.export_active and game.world._export_active, "randomly timed export arrival updates simulation and boat")
	check(game.state.export_timer <= 5.0 and game.state.export_factor >= 2.0 and game.state.export_factor <= 6.0, "export gives a five-second varied opportunity")
	check(is_equal_approx(game.state.market.sunburst.sell, game.state._market_core.sunburst.sell * game.state.export_factor), "displayed export factor controls the real quote")
	check(game.state.market.sunburst.seed > seed_price, "seed prices rise with the export sale quote")
	await shot("golden-shores-export-market")
	await process_frame
	var scroll: ScrollContainer = game.hud._body.get_parent() as ScrollContainer
	check(button("sell:sunburst:-1").get_global_rect().end.y <= scroll.get_global_rect().end.y, "Sunburst export sell button fits without scrolling")
	var before_coins: float = game.state.coins
	var held: int = game.state.storage.sunburst
	var sale_price: float = game.state.market.sunburst.sell
	press("sell:sunburst:-1")
	check(is_equal_approx(game.state.coins, before_coins + held * sale_price), "large sale pays the exact displayed export quote")
	check(game.state.quest_progress.export == 1.0, "real export sale supplies one distinct ship")
	for shipment in range(2):
		game.state._toggle_export()
		game.state._toggle_export()
		game.state.storage.sunburst = 100
		game._on_state_changed()
		press("sell:sunburst:-1")
	check(game.state.quest_progress.export == 3.0, "three distinct shipments complete the island activity")
	game.hud.close_panel()
	game.state.tools.harvest = 2
	for index in range(48):
		var crop: String = "sunburst" if index % 2 == 0 else "golden"
		game.state.plots[index].merge({"crop": crop, "stage": 3, "watered": true, "tilled": true, "elapsed": float(game.state.CROPS[crop].grow), "pending": 0}, true)
	game._on_state_changed()
	await shot("golden-shores-export-farm")
	game.perform_plot(8, "harvest")
	game.perform_plot(32, "harvest")
	check(game.state.quest_progress.combo == 48, "two manual wide scythe cuts produce the full-field chain")
	game._on_action("quests")
	press("quest:combo")
	press("quest:export")
	# Complete long challenge counters as a fixture; simulation tests verify their accounting.
	game.state.quest_progress.sunburst = 10000
	game.state.quest_progress.mutation = 3
	game._on_state_changed()
	press("quest:sunburst")
	press("quest:mutation")
	check(game.state.quest_claimed.size() == 5, "all five completed quests can be claimed through their buttons")
	check(game.state.golden_hat and game.world._golden_hat, "claimed cosmetic reaches the visible farmer")
	game.hud.close_panel()
	# Verify away-farm growth, cancellation of queued work, and collision cleanup.
	game.state.plots[47].merge({"crop": "sunburst", "stage": 1, "watered": true, "tilled": true, "elapsed": 0.0, "pending": 0}, true)
	game.queue_plot(47)
	var export_time: float = game.state.export_timer
	game._on_action("travel:1")
	await settle_world()
	check(game.world.plot_positions.size() == 24 and game.world.current_island == 1, "return trip restores original world")
	check(not game.walking and game.pending_plot == -1, "travel cancels work queued on another island")
	check(game.state.export_timer == export_time, "ferry cannot reset export countdown")
	check(game.state.selected_crop == "russet" and button("crop:sunburst") == null, "returning safely selects a starter crop")
	game._process(45.1)
	check(game.state.island_plots["2"][47].stage == 3, "watered Sunburst keeps growing while visiting starter farm")
	check(not game.state.export_active, "export boat departs while away")
	game._on_action("travel:2")
	await settle_world()
	check(game.state.plots[47].stage == 3, "returning preserves the remote harvest")
	game.state.coins = 8.4e71
	game.state._event_in = 8.0
	game._on_state_changed()
	check(game.hud._top.coins.text == "$8.4e71", "second-island HUD can show astronomical balances")
	check(game.state.save_game(SAVE), "complete island progress saves")
	game._on_action("reset")
	check(game.state.current_island == 1 and game.world.current_island == 1, "reset synchronizes both scene and farm")
	check(game.state.load_game(SAVE), "saved second island reloads")
	await settle_world()
	check(game.world.current_island == 2 and game.world.plot_positions.size() == 48, "loading rebuilds the saved island")
	check(game.state.quest_claimed.size() == 5 and game.state.golden_hat, "reload preserves rewards without duplicating claims")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await process_frame
	print("GOLDEN SHORES INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
