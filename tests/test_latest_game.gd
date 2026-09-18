extends SceneTree
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

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

func key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "rendered " + name)

func spike(percent: float) -> void:
	game.state.market.russet.change = percent
	game.state.market.russet.sell = game.state.CROPS.russet.base * (1 + percent / 100.0)
	game._on_state_changed()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	await shot("clean-farm")
	check(game.selected_tool == "hoe", "a real tool is selected at startup")
	var tools: Array[String] = ["hoe", "plant", "water", "harvest", "pest"]
	for index in range(tools.size()):
		var action: String = tools[index]
		check(button("tool:" + action) != null, "hotbar tool is available: " + action)
		press("tool:" + action)
		check(game.selected_tool == action and game.hud._selected_tool == action, "mouse equips exactly one hotbar tool: " + action)
		var selected_style: StyleBoxFlat = button("tool:" + action).get_theme_stylebox("normal") as StyleBoxFlat
		var other: Button = button("tool:" + tools[(index + 1) % tools.size()])
		check(selected_style.bg_color != (other.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, "selected slot is visibly highlighted: " + action)
		key(KEY_1 + ((index + 1) % tools.size()))
		check(game.selected_tool == tools[(index + 1) % tools.size()], "keyboard equips matching numbered slot")
	for entry in game.state.inventory_info():
		check(entry.kind != "tool", "tools cannot leak into main inventory")
	game._on_action("tracked_prices")
	await settle()
	var tracked_toggle: CheckButton
	for toggle in game.hud.find_children("*", "CheckButton", true, false):
		if toggle.get_meta("tracked_seed", "") == "golden":
			tracked_toggle = toggle
	check(tracked_toggle != null and tracked_toggle.button_pressed, "seed tracking menu exposes saved checkboxes")
	if tracked_toggle != null:
		tracked_toggle.button_pressed = false
	check(not game.state.tracked_seeds.has("golden") and not game.hud._tracked_labels.has("golden"), "checkbox removes exactly that seed from top HUD")
	await shot("tracked-prices-menu")
	game.hud.close_panel()
	check(game.hud._top.surge.text.contains("3:00"), "visible surge timer begins at three minutes")
	game.state.quest_progress.starter_crash = 10
	game._on_action("quests")
	press("quest:starter_crash")
	check(game.state.quest_claimed.has("starter_crash"), "starter island activity reward is actually claimable")
	game.hud.close_panel()
	var no_crate_rng: int = game.state.rng.state
	game._on_action("build:open_crate")
	check(not game.hud.is_roll_animating() and game.state.rng.state == no_crate_rng, "empty crate UI request cannot start RNG or reward reel")
	game.world.set_player_position(game.world.plot_positions[4] + Vector3(0, 0, 0.65))
	key(KEY_1)
	key(KEY_E)
	check(game.state.plots[4].tilled, "explicit hoe prepares the nearby bed")
	key(KEY_2)
	key(KEY_E)
	key(KEY_E)
	check(game.state.plots[4].stage == 1 and not game.state.plots[4].watered, "repeating E with Plant cannot automatically water the crop")
	key(KEY_3)
	key(KEY_E)
	check(game.state.plots[4].watered, "watering requires selecting the watering tool")
	game.state.plots[4].pests = true
	game.state.plots[4].pest_damage = 1.0 / 3.0
	game.state.plots[4].pest_ticks = 1
	game._on_state_changed()
	key(KEY_5)
	game.queue_plot(4)
	game._process(0.05)
	check(game.selected_tool == "pest" and not game.state.plots[4].pests, "fifth hotbar tool walks over and removes pests")
	check(is_equal_approx(game.state.plots[4].pest_damage, 1.0 / 3.0), "brushing stops further decay without duplicating lost yield")
	await shot("tools-hotbar")
	# Only the selected ticker may trigger its island-colored overlay.
	game.state.select_crop("russet")
	game.state.market.golden.change = 1600.0
	spike(100.0)
	check(game.surge_band == 0, "an unselected booming crop does not activate screen effects")
	spike(300.0)
	check(game.surge_band == 0, "300 percent itself remains below the effect threshold")
	spike(350.0)
	check(game.surge_band == 1 and game.fanfare_remaining > 0.0, "selected crop above300 triggers rhythmic edges and a fanfare")
	await shot("market-green-pulse")
	spike(1100.0)
	check(game.surge_band == 2, "selected crop above1000 triggers the stronger flash mode")
	await shot("market-green-flash")
	spike(0.0)
	check(game.surge_band == 0, "effects stop when the selected quote returns to ordinary levels")
	game.state._grant_item("aurora")
	game.state._grant_item("sunstone")
	game.state.storage.russet = 20
	game.builds.build_crates = 1
	game._on_action("inventory")
	await shot("illustrated-inventory-crops")
	press("inventory_tab:items")
	await shot("illustrated-inventory-items")
	var before: float = game.state.coins
	var total_before: int = 0
	for value in game.builds.levels.values():
		total_before += int(value)
	press("inventory_tab:builds")
	await shot("illustrated-inventory-builds")
	press("build:open_crate")
	check(game.hud.is_roll_animating() and game.builds.build_crates == 0, "opening a build crate starts the reward reel and consumes it")
	check(game.state.coins == before, "build crate does not charge an extra wager")
	await create_timer(0.45).timeout
	await shot("build-crate-reel")
	var deadline: int = Time.get_ticks_msec() + 10000
	while game.hud.is_roll_animating() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.hud.is_roll_animating(), "build-only reel reaches its result")
	var total_after: int = 0
	for value in game.builds.levels.values():
		total_after += int(value)
	check(total_after == total_before + 1, "crate reveal grants exactly one build level")
	await shot("build-crate-result")
	game.hud.close_panel()
	key(KEY_R)
	check(button("roll:normal") != null, "opening paid Roll House after a crate restores wager controls")
	game.hud.close_panel()
	for id in game.builds.IDS:
		game.builds.levels[id] = 8
	key(KEY_C)
	check(game.hud.is_panel_open(), "C opens all five build choices")
	await shot("player-builds")
	press("build:select:scientist")
	check(game.builds.active == "scientist", "build panel equips the chosen gameplay specialization")
	game.hud.close_panel()
	game.state.coins = 200000000000.0
	game.state.mastery.russet = 25000
	game.state.unlock_island2()
	check(not game.state.roll_available(), "starter Roll House retires when the second island is unlocked")
	game.state.travel_to(2)
	await settle()
	spike(1200.0)
	await shot("market-golden-flash")
	game.state.unlock_island3()
	check(not game.state.roll_available(), "second Roll House retires when the winter island is unlocked")
	game.state.travel_to(3)
	await settle()
	spike(1400.0)
	await shot("market-winter-flash")
	check(game.state.roll_available(), "newest island remains open for its appropriately priced wagers")
	game.state.surge_timer = 0.01
	game._process(0.01)
	check(game.state.surge_remaining > 0.0 and game.hud._top.surge.text.contains("SELL"), "countdown activates a real sale opportunity in the HUD")
	await create_timer(0.35).timeout
	await shot("guaranteed-stock-surge")
	game._on_action("menu")
	await settle()
	check(game.hud.is_panel_open() and button("inventory") != null and button("market") != null, "three-line menu contains inventory and market navigation")
	await shot("main-menu")
	game.hud.close_panel()
	if capture:
		root.size = Vector2i(960, 600)
		await settle()
		await shot("compact-farm-960x600")
		game._on_action("inventory")
		await settle()
		await shot("compact-inventory-960x600")
		game.hud.close_panel()
	game.queue_free()
	await process_frame
	print("LATEST GAME FEATURES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
