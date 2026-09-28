extends SceneTree
## Inspect every menu at both ends, including expanded sections and long rewards.
var game
var checks: int = 0
var failures: int = 0
var capture: bool
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for _i: int in range(6): await process_frame
func shot(tag: String, bottom: bool = false, focus: Control = null) -> void:
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud._purchase_box.hide()
	game.hud._climate_alert.dismiss()
	await settle()
	var scroll: ScrollContainer = game.hud._body.get_parent()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value) if bottom else 0
	if focus != null: scroll.ensure_control_visible(focus)
	await settle()
	check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), tag + " modal fits")
	check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, tag + " no horizontal overflow")
	if bottom:
		check(game.hud._body.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, tag + " bottom is reachable")
	for label: Node in game.hud._body.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			check(label.size.y + 1 >= label.get_minimum_size().y, tag + " wrapped text fits")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/audit-" + tag + ".png") == OK, "capture " + tag)
func page(kind: String, tag: String = "") -> void:
	game.hud.show_panel(kind, game.state)
	var name: String = kind if tag.is_empty() else tag
	await shot(name + "-top")
	await shot(name + "-bottom", true)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.debug_unlock_island(3)
	game.state.travel_to(3)
	game.state.climate.acknowledge(game.state)
	game.state.coins = 223e15
	for crop: String in game.state.CROP_IDS:
		game.state.seed_inventory[crop] = 30
		game.state.storage[crop] = 10
	game.hud.update_state(game.state)
	game.hud.set_debug_session(true)
	for kind: String in ["market", "inventory", "tools", "pause", "dex", "island", "quests", "activities", "duck_patrol", "debug", "graphics", "help", "climate"]:
		await page(kind)
	for tab: String in ["crops", "tools"]:
		game.hud.show_panel("inventory", game.state)
		game.hud._act("inventory_tab:" + tab)
		await shot("inventory-" + tab + "-top")
		await shot("inventory-" + tab + "-bottom", true)
	game.hud.show_panel("dex", game.state)
	await shot("dex-crops-top")
	await shot("dex-crops-bottom", true)
	for pair: Array in [["climate", "climate_details"]]:
		game.hud.show_panel(pair[0], game.state)
		var scroller: ScrollContainer = game.hud._body.get_parent()
		await settle()
		scroller.scroll_vertical = int(scroller.get_v_scroll_bar().max_value)
		game.hud._act("toggle_details:" + pair[1])
		await settle()
		check(game.hud._refs[pair[1]].visible and scroller.get_global_rect().intersects(game.hud._refs[pair[1]].get_global_rect()), pair[1] + " reveals after expansion")
		await shot(pair[1] + "-bottom", true)
	for island: int in [1, 2]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		await page("activities", "activities-island-%d" % island)
	game.state.climate.begin_warning(game.state, "storm", 1.0)
	game.state.climate._impact(game.state)
	game.state._refresh_market()
	game.hud.update_state(game.state)
	await page("climate", "climate-disaster")
	root.size = Vector2i(960, 600)
	for kind: String in ["dex", "climate", "help", "debug"]:
		await page(kind, "compact-" + kind)
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("UI AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
