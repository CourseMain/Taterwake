extends SceneTree
## Real inventory controls, live shared-avatar rendering, and all-island duck training.
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
	check(root.get_texture().get_image().save_png("res://artifacts/equipment-" + name + ".png") == OK, "render " + name)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 1e15
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	for item: String in ["straw_hat", "farmer_shirt", "farmer_pants", "farmer_boots", "harvest_gloves", "market_monocle", "investor_shirt", "scientist_coat", "industrialist_overalls", "gambler_shirt", "almanac"]:
		game.state._grant_item(item)
	game.builds.levels.investor = 1
	game._on_action("inventory")
	game.hud._act("inventory_tab:gear")
	await process_frame
	var preview = game.hud._refs.equipment_preview
	check(preview.is_visible_in_tree() and preview.avatar.gear_parts.size() == 6, "gear tab shows live fully equipped 3D farmer")
	check(preview.avatar.loadout.body == "farmer_shirt", "portrait uses authoritative body-slot equipment")
	check(game.hud._refs.equipment_build.text.ends_with("FARMER") and game.hud._refs.equipment_totals.text.contains("Yield +30%"), "loadout names active Farmer build and includes matching clothing bonus")
	check(game.hud._inventory_sections.gear.visible and not game.hud._inventory_sections.items.visible, "wearable gear has its own uncluttered inventory tab")
	check(game.hud._refs["item:almanac:title"].get_parent().get_parent().get_parent().get_parent() == game.hud._inventory_sections.items, "legacy passive treasures stay in the items tab")
	for slot: String in ["head", "body", "legs", "feet", "hands", "charm"]:
		check(not game.hud._refs["equipment:" + slot].disabled, "occupied %s slot is removable" % slot)
	await shot("farmer-loadout")
	game.hud._refs["item:investor_shirt:action"].pressed.emit()
	check(game.state.equipment_loadout().body == "investor_shirt", "equip button replaces one body item")
	check(preview.avatar.loadout.body == "investor_shirt" and preview.avatar.loadout.legs == "farmer_pants", "portrait updates replacement while preserving other slots")
	check(game.state.inventory_items.farmer_shirt == 1 and not game.hud._refs["item:farmer_shirt:action"].disabled, "replaced clothing stays owned and can be equipped again")
	game._on_action("build:select:investor")
	check(game.hud._refs.equipment_build.text.ends_with("INVESTOR") and game.hud._refs.equipment_totals.text.contains("Stocks +22.5%"), "changing build refreshes header and combined matching stock bonus")
	game.hud._refs["equipment:body"].pressed.emit()
	check(game.state.equipment_loadout().body.is_empty() and not preview.avatar.gear_parts.has("body"), "clicking occupied slot removes garment from state and portrait")
	check(game.hud._refs["equipment:body"].disabled and game.hud._refs["equipment:body:name"].text == "Empty", "empty slots display clearly and cannot unequip twice")
	check(game.hud._refs.equipment_totals.text.contains("Stocks +10%") and not game.hud._refs.equipment_totals.text.contains("22.5%"), "unequipping immediately removes clothing from combined totals")
	game.hud._refs["item:scientist_coat:action"].pressed.emit()
	check(preview.avatar.loadout.body == "scientist_coat", "another clothing style appears immediately")
	await shot("mixed-loadout")
	game.hud._act("inventory_tab:items")
	check(not preview.is_visible_in_tree() and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden portrait stops rendering")
	game.hud._act("inventory_tab:gear")
	check(preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "gear tab resumes live portrait rendering")
	if capture:
		root.size = Vector2i(960, 600)
		await shot("compact-loadout")
		root.size = Vector2i(1280, 800)
	game.hud.close_panel()
	for island: int in [1, 2, 3]:
		game.state.travel_to(island)
		game._on_action("duck_patrol")
		check(game.hud._refs.has("activity:duck") and not game.hud._refs["activity:duck"].disabled, "island %d offers duck hiring" % island)
		check(game.hud._refs["activity:duck:detail"].text.begins_with("0 / %d ducks" % island), "island %d shows correct flock size" % island)
		game.hud._refs["activity:duck"].pressed.emit()
		check(game.activities.duck_count() == 1 and game.activities.duck_speed() == 0, "island %d hiring adds one duck without speed training" % island)
		await shot("ducks-island-%d" % island)
		game.hud.close_panel()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("EQUIPMENT UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
