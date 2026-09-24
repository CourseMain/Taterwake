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
	game.state.luck = 2.0
	for id: String in game.state.ITEM_CATALOG: game.state._grant_item(id)
	for crop: String in game.state.CROP_IDS:
		game.state.seed_inventory[crop] = 30
		game.state.storage[crop] = 10
	for id: String in game.builds.levels: game.builds.levels[id] = 5
	game.builds.build_crates = 4
	game.hud.update_state(game.state)
	game.hud.set_debug_session(true)
	for kind: String in ["market", "inventory", "tools", "roll", "pause", "dex", "island", "quests", "builds", "tracked_prices", "activities", "duck_patrol", "debug", "graphics", "help", "taxes", "climate"]:
		await page(kind)
	for tab: String in ["gear", "items", "builds"]:
		game.hud.show_panel("inventory", game.state)
		game.hud._act("inventory_tab:" + tab)
		await shot("inventory-" + tab + "-top")
		await shot("inventory-" + tab + "-bottom", true)
	game.hud.show_panel("dex", game.state)
	game.hud._act("dex_tab:crops")
	await shot("dex-crops-top")
	await shot("dex-crops-bottom", true)
	for pair: Array in [["taxes", "tax_details"], ["climate", "climate_details"], ["roll", "roll_math_section"]]:
		game.hud.show_panel(pair[0], game.state)
		var scroller: ScrollContainer = game.hud._body.get_parent()
		await settle()
		scroller.scroll_vertical = int(scroller.get_v_scroll_bar().max_value)
		game.hud._act("toggle_details:" + pair[1])
		await settle()
		check(game.hud._refs[pair[1]].visible and scroller.get_global_rect().intersects(game.hud._refs[pair[1]].get_global_rect()), pair[1] + " reveals after expansion")
		await shot(pair[1] + "-bottom", true)
	game.hud._preview_stake("stupid")
	check(game.hud._refs.roll_quality.text.contains("4.00×"), "300% stake is shown as 4x quality")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	await settle()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	check(game.hud._modal_card.get_global_rect().encloses(game.hud._refs.roll_luck_meter.get_global_rect()), "calculation remains visible at the bottom")
	game.hud.begin_roll("stupid")
	check(scroll.scroll_vertical == 0, "starting a roll returns to the intact reel")
	check(game.hud._refs.roll_luck_meter.playing and game.hud._refs.roll_luck_meter.values.stake_bonus == 300, "purchased stake is visibly calculated")
	var frozen: Dictionary = game.hud._refs.roll_luck_meter.values.duplicate(true)
	game.state.coins = 1e14
	game.hud.update_state(game.state)
	check(game.hud._refs.roll_luck_meter.values == frozen, "spending coins does not change purchased calculation")
	var results: Array = []
	for item: String in ["straw_hat", "farmer_shirt", "market_monocle", "aurora_crown", "loaded_dice", "harvest_gloves"]:
		results.append({"tier": game.state.ITEM_CATALOG[item].rarity, "title": game.state.ITEM_CATALOG[item].name, "item_id": item, "detail": game.state.ITEM_CATALOG[item].effect, "bet": 1e12})
	game.hud.spin_batch(results)
	await shot("roll-spinning")
	game.hud._refs.roll_luck_meter._process(5)
	game.hud._spinner._process(5)
	check(game.hud._refs.batch_results.get_child_count() == 6, "six real batch results render as six cards")
	await settle()
	await shot("roll-batch-cards", false, game.hud._refs.batch_results)
	await shot("roll-results-top")
	await shot("roll-results-bottom", true)
	game.hud._act("toggle_trophies")
	await shot("trophies-empty-bottom", true)
	game.hud.close_panel()
	game.state.coins = 223e15
	for _i: int in range(35): game.state.roll("normal")
	game.hud.show_panel("roll", game.state)
	game.hud._trophies_open = false
	game.hud._act("toggle_trophies")
	await shot("trophies-filled-bottom", true)
	game.hud.show_panel("roll", game.state, true)
	await shot("build-crate")
	for island: int in [1, 2]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		await page("activities", "activities-island-%d" % island)
	game.state.climate.begin_warning(game.state, "storm", 1.0)
	game.state.climate._impact(game.state)
	game.state._refresh_market(false)
	game.hud.update_state(game.state)
	await page("climate", "climate-disaster")
	check(game.hud._export_title.text.contains("CRASH") and game.hud._export_detail.text.contains("Booms paused"), "HUD explains the crash and stopped booms")
	root.size = Vector2i(960, 600)
	for kind: String in ["roll", "dex", "taxes", "climate", "help", "debug"]:
		await page(kind, "compact-" + kind)
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("UI AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
