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
	check(game.hud._top.coins.is_visible_in_tree() and game.hud._top.price.is_visible_in_tree(), "money, selected market and luck remain visible")
	check(noninteractive(game.hud._top.coins.get_parent().get_parent().get_parent()), "noninteractive stats pass camera gestures through")
	var hotbar: Control = game.hud.root.get_node("ToolHotbar")
	await process_frame
	check(game.hud._top.coins.get_parent().get_parent().get_parent().size.y <= 74.0, "numeric stats keep their compact height without symbol-font padding")
	check(absf(game.hud._quick_sell.get_global_rect().end.y - hotbar.get_global_rect().end.y) < 1.0, "sell action aligns with the bottom of the tool hotbar")
	for island in [1]:
		game.state._refresh_market()
		game.hud.update_state(game.state)
		game.hud._process(0.01)
		game.hud._toast_box.hide()
		game.hud._context_box.hide()
		await process_frame
		await shot("island-" + str(island))
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
		game.state.update(0.02)
		game.hud.update_state(game.state)
		game.hud._process(0.1)
		await process_frame
	game.state._refresh_market()
	game.hud.update_state(game.state)
	game.hud._process(0.01)
	root.size = Vector2i(960, 600)
	await process_frame
	await shot("compact")
	game.hud.set_tool("plant")
	check(game.hud._crop_row.visible, "seed tool reveals seed controls without the extra tracked-price strip")
	await shot("compact-seeds")
	game.hud.set_tool("water")
	check(not game.hud._crop_row.visible, "leaving seeds returns to the clean farm view")
	game._on_action("help")
	var drag_explained: bool = false
	var zoom_explained: bool = false
	for label: Node in game.hud._body.find_children("*", "Label", true, false):
		drag_explained = drag_explained or label.text.contains("Hold click + drag")
		zoom_explained = zoom_explained or label.text.contains("Mouse wheel / pinch")
	check(drag_explained and zoom_explained, "controls explain held-click camera dragging and wheel or pinch zoom")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("HUD LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
