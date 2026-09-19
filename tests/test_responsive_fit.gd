extends SceneTree
## Keep every game control reachable when the exported canvas changes shape.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false
const SIZES: Array[Vector2i] = [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(800, 600), Vector2i(640, 360), Vector2i(600, 900)]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for _frame: int in range(4):
		await process_frame

func inside(control: Control, label: String) -> void:
	var bounds: Rect2 = game.hud.root.get_global_rect().grow(0.5)
	check(bounds.encloses(control.get_global_rect()), label + " remains inside the game canvas")

func shot(label: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/responsive-" + label + ".png") == OK, "capture " + label)

func check_menu(label: String) -> void:
	inside(game.hud._modal_card, label + " modal")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, label + " content needs no unavailable horizontal scrolling")
	var close: Control = game.hud._modal_card.get_child(0).get_child(0).get_child(1)
	inside(close, label + " close button")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.hud.set_process(false)
	game.state.coins = 1e20
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	game.state.travel_to(3)
	game.state.surge_timer = 8.0
	game.state.debug_luck_multiplier = 3000.0
	game.hud.update_state(game.state)
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud.set_context("")
	# Desktop minimums do not apply to an embedded web canvas. Exercise those
	# smaller sizes too without changing the saved project/window preference.
	root.min_size = Vector2i.ZERO
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "game keeps its complete layout at every canvas aspect ratio")
	for requested: Vector2i in SIZES:
		root.size = requested
		await settle()
		var tag: String = "%dx%d" % [requested.x, requested.y]
		print("FIT %s: actual window %s, logical canvas %s" % [tag, root.size, game.hud.root.size])
		check(game.hud.root.size.is_equal_approx(Vector2(1280, 800)), tag + " preserves the complete logical canvas")
		game.hud.close_panel()
		game.hud.set_tool("plant")
		game.hud._purchase_box.hide()
		await settle()
		for item: Control in [game.hud._top.coins.get_parent().get_parent().get_parent(), game.hud.root.get_node("MainMenuButton"), game.hud.root.get_node("ToolHotbar"), game.hud._export_box, game.hud._quick_sell, game.hud._crop_row, game.hud._tracked_box]:
			inside(item, tag + " " + item.name)
		check(not game.hud.root.get_node("ToolHotbar").get_global_rect().intersects(game.hud._quick_sell.get_global_rect()), tag + " sell button clears the hotbar")
		for button: Control in game.hud._crop_buttons.values():
			if button.visible:
				inside(button, tag + " seed choice")
		await shot(tag + "-farm")
		game.hud.show_panel("market", game.state)
		game.hud.show_purchase({"kind": "seeds", "id": "radioactive", "name": "Radioactive", "quantity": 12500, "cost": 125000000.0, "total": 12506})
		await settle()
		check_menu(tag + " market")
		inside(game.hud._purchase_box, tag + " purchase receipt")
		check(not game.hud._purchase_box.get_global_rect().intersects(game.hud._modal_card.get_global_rect()), tag + " receipt leaves every market button clear")
		check(not game.hud._crop_row.visible and not game.hud._tracked_box.visible, tag + " open menu hides the seed tray")
		await shot(tag + "-market")
		game.hud._purchase_remaining = 0.0
		game.hud._purchase_receipt.clear()
		game.hud._purchase_box.hide()
	# Every menu uses the same fixed canvas, but each can have its own minimum
	# width. Check the actual content after container layout, not a mock panel.
	for kind: String in ["inventory", "tools", "roll", "pause", "dex", "island", "quests", "builds", "tracked_prices", "activities", "duck_patrol", "debug", "graphics", "help"]:
		game.hud.show_panel(kind, game.state)
		await settle()
		check_menu(kind)
		if kind == "debug":
			game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
			game.hud._refs.debug_unlock.pressed.emit()
			await settle()
			check_menu("unlocked debug controls")
		if kind == "inventory":
			game.hud._act("inventory_tab:gear")
			await settle()
			check_menu("equipped gear")
			await shot("portrait-inventory")
	game.queue_free()
	await process_frame
	print("RESPONSIVE FIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
