extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
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
	if game.conversation.visible: game.conversation.choose(0)

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
		check(entry.kind in ["seed", "crop", "tool"], "inventory contains only crops and tools")
	game.state.quest_progress.starter_crash = 10
	game._on_action("quests")
	press("quest:starter_crash")
	check(game.state.quest_claimed.has("starter_crash"), "starter island activity reward is actually claimable")
	game.hud.close_panel()
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
	game.state.storage["russet"] = Stock.pile(20)
	game._on_action("inventory")
	await shot("illustrated-inventory-crops")
	press("inventory_tab:tools")
	await shot("illustrated-inventory-tools")
	game.hud.close_panel()
	game.state.coins = 200000000000.0
	game.state.harvested_total = 25000
	await settle()
	await settle()
	game._process(0.01)
	await create_timer(0.35).timeout
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
