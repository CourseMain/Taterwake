extends SceneTree
## Actual shop buttons and world clicks; never loads or writes the player's save.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func press(action: String) -> void:
	for node: Node in game.hud.find_children("*", "Button", true, false):
		if node.get_meta("action", "") == action and node.is_visible_in_tree():
			check(not node.disabled, "usable purchase button " + action)
			if not node.disabled:
				node.pressed.emit()
			return
	check(false, "missing visible button " + action)

func click_station(point: Vector3, expected: String) -> void:
	game.hud.close_panel()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.world.camera.unproject_position(point)
	check(game.world.pick(event.position).get("station", "") == expected, "ray hits " + expected)
	event.position *= root.get_visible_rect().size / Vector2(game.farm_viewport.size)
	game._unhandled_input(event)
	check(game.hud._panel_kind == expected, "world click opens " + expected)

func shot(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "capture " + filename)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args() and not "--capture" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.hud.set_process(false)
	game.state.coins = 1e15
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	game._on_action("market")
	var starting_seeds: int = game.state.seed_inventory.russet
	var seed_price: float = game.state.market.russet.seed
	press("buy:russet:1")
	press("buy:russet:5")
	check(game.state.seed_inventory.russet == starting_seeds + 6, "market buttons add six real seeds")
	check(game.hud._purchase_title.text == "+6 Russet seeds", "live state signal delivers aggregated seed receipt")
	check(game.hud._purchase_receipt.total == starting_seeds + 6 and is_equal_approx(game.hud._purchase_receipt.cost, seed_price * 6), "receipt matches actual inventory and live spend")
	check(game.hud._purchase_box.visible and game.hud.is_panel_open(), "buying keeps exchange open and receipt visible")
	await shot("purchase-live-seeds")
	game.hud._process(game.hud.PURCHASE_SECONDS + 0.1)
	game.state.coins = 0.0
	game._on_action("buy:russet:5")
	check(not game.hud._purchase_box.visible and game.hud._toast_box.visible, "rejected purchase shows explanation without success popup")
	check(game.state.seed_inventory.russet == starting_seeds + 6, "rejection preserves inventory")
	game.hud._toast_box.hide()
	game.state.coins = 1e15
	var shop_points: Array[Vector3] = [Vector3(-6.4, 1.5, -8.5), Vector3(-8, 1.5, -10.6), Vector3(18, 1.9, 2)]
	for island: int in [1, 2, 3]:
		game.state.travel_to(island)
		await process_frame
		await physics_frame
		await physics_frame
		click_station(shop_points[island - 1], "tools")
		var rank: int = game.state.tools.hoe
		press("upgrade:hoe")
		check(game.state.tools.hoe == rank + 1, "toolsmith upgrades hoe on island %d" % island)
		check(game.hud._purchase_receipt.kind == "tool" and game.hud._purchase_receipt.level == rank + 1, "toolsmith receipt reflects committed rank on island %d" % island)
		if island == 1:
			await shot("purchase-live-toolsmith")
		click_station(game.world._duck_home + Vector3(0, 0.8, 0.1), "duck_patrol")
		check(game.hud._refs.has("activity:duck") and not game.hud._refs.has("activity:contract:bulk") and not game.hud._refs.has("activity:furnace:icecap"), "island %d coop only offers duck training" % island)
		if island == 2:
			press("activity:duck")
			check(game.activities.duck_level == 1 and game.hud._purchase_receipt.kind == "duck", "duck training applies and confirms at the Shores coop")
			await shot("purchase-live-ducks-island2")
			click_station(Vector3(13.5, 1.35, 3.2), "activities")
			check(game.hud._refs.has("activity:contract:bulk") and not game.hud._refs.has("activity:duck"), "buyer booth still opens its separate contract page")
		if island == 3:
			click_station(Vector3(17.8, 1.3, 10), "activities")
			check(game.hud._refs.has("activity:furnace:icecap") and not game.hud._refs.has("activity:duck"), "furnace still has its own page")
	game.queue_free()
	await process_frame
	print("PURCHASE GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
