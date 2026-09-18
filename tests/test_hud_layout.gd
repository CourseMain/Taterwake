extends SceneTree
## Compact left stock banner and clean farming view at both supported window sizes.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/hud-layout-" + name + ".png") == OK, "render " + name)

func stock_fits(description: String) -> void:
	var box: Rect2 = game.hud._export_box.get_global_rect()
	check(box.position.x == 28 and box.end.x <= 340 and box.size.y <= 100, description + ": compact left stock card stays under the brand")
	check(not box.intersects(Rect2(350, 100, 560, 140)), description + ": stock card clears the centre above the barn")
	check(game.hud._export_title.get_minimum_size().x <= 278 and game.hud._export_detail.get_minimum_size().x <= 278, description + ": timer and details fit without clipped text")

func noninteractive(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not noninteractive(child):
			return false
	return true

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.hud.set_process(false)
	game.hud.close_panel()
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud.set_context("")
	check(not game.hud._context_box.visible, "empty farm context leaves no dark empty bar")
	game.hud.set_context("Russet · Ready to harvest · E")
	check(game.hud._context_box.visible, "actual crop interactions retain their context")
	game.hud.set_context("")
	var hint_removed: bool = true
	for label: Node in game.hud.root.find_children("*", "Label", true, false):
		if label.text == "WASD walk · Wheel zoom · I inventory":
			hint_removed = false
	check(hint_removed, "persistent movement/zoom/inventory hint is removed")
	check(not game.hud._tool_caption.visible, "equipped-tool control hint is absent from the persistent HUD")
	check(game.hud._tool_buttons.size() == 5 and game.hud.root.get_node("MainMenuButton").visible, "five tools and menu remain available")
	check(game.hud._top.coins.is_visible_in_tree() and game.hud._top.price.is_visible_in_tree() and game.hud._top.luck.is_visible_in_tree(), "money, selected market and luck remain visible")
	check(noninteractive(game.hud._export_box), "countdown and all children pass camera gestures through")
	check(noninteractive(game.hud._top.coins.get_parent().get_parent().get_parent()), "noninteractive stats pass camera gestures through")
	var hotbar: Control = game.hud.root.get_node("ToolHotbar")
	await process_frame
	check(game.hud._top.coins.get_parent().get_parent().get_parent().size.y <= 74.0, "numeric stats keep their compact height without symbol-font padding")
	check(absf(game.hud._quick_sell.get_global_rect().end.y - hotbar.get_global_rect().end.y) < 1.0, "sell action aligns with the bottom of the tool hotbar")
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	for island: int in [1, 2, 3]:
		game.state.travel_to(island)
		game.state.surge_remaining = 0.0
		game.state.surge_timer = 180.0
		game.state.export_active = false
		game.state.frost_active = false
		game.state.thaw_remaining = 0.0
		game.state._refresh_market(false)
		game.hud.update_state(game.state)
		game.hud._process(0.01)
		game.hud._market_impact.set_quote(island, 0.0)
		game.hud._market_impact._process(6.0)
		game.hud._toast_box.hide()
		game.hud._context_box.hide()
		await process_frame
		stock_fits("Island%d calm" % island)
		check(game.hud._export_title.text.contains("3:00") and game.hud._export_detail.text.contains("3,000%"), "calm countdown shows actual new range on island%d" % island)
		await shot("island-" + str(island))
		game.state.surge_timer = 10.0
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
		stock_fits("Island%d last10seconds" % island)
		check(game.hud._surge_urgent and game.hud._export_detail.text.contains("GET READY"), "last ten seconds keep visual urgency")
		game.state.surge_timer = 0.01
		game.state.update(0.02)
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
		stock_fits("Island%d active" % island)
		check(game.hud._surge_active and game.hud._export_title.text.contains("SELL [F]"), "active stock keeps the direct sell prompt")
		await shot("island-" + str(island) + "-surge")
	game.state.surge_remaining = 0.0
	game.state.surge_timer = 180.0
	game.state._refresh_market(false)
	game.hud.update_state(game.state)
	game.hud._process(0.01)
	game.hud._market_impact.set_quote(3, 0.0)
	game.hud._market_impact._process(6.0)
	root.size = Vector2i(960, 600)
	await process_frame
	stock_fits("Compact window")
	await shot("compact")
	game.hud.set_tool("plant")
	check(game.hud._crop_row.visible and game.hud._tracked_box.visible, "seed tool still reveals the intentional seed controls")
	await shot("compact-seeds")
	game.hud.set_tool("water")
	check(not game.hud._crop_row.visible and not game.hud._tracked_box.visible, "leaving seeds returns to the clean farm view")
	game._on_action("help")
	var gestures_explained: bool = false
	for label: Node in game.hud._body.find_children("*", "Label", true, false):
		gestures_explained = gestures_explained or (label.text.contains("Two-finger scroll") and label.text.contains("pinch"))
	check(gestures_explained, "camera gestures are explained inside How to play")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("HUD LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
