extends SceneTree
## Real-scene wiring checks. Never reads or writes the player's farm.
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

func button(action: String) -> Button:
	for node in game.hud.find_children("*", "Button", true, false):
		if node.get_meta("action", "") == action and node.is_visible_in_tree():
			return node as Button
	return null

func press(action: String) -> void:
	var target := button(action)
	check(target != null and not target.disabled, "usable button " + action)
	if target != null and not target.disabled:
		target.pressed.emit()
		if game.conversation.visible: game.conversation.choose(0)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/features-" + name + ".png") == OK, "render " + name)

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
	game.state.coins = 300000.0
	game._on_action("menu")
	press("activities")
	check(game.hud._modal_title.text.to_lower().contains("duck"), "starter menu opens duck patrol")
	press("activity:duck")
	check(game.activities.duck_count() == 1, "duck purchase reaches persistent simulation")
	await shot("ducks-panel")
	game.hud.close_panel()
	var plot: Dictionary = game.state.plots[0]
	plot.pests = true
	plot.pest_elapsed = 0.0
	game._on_state_changed()
	game._advance_simulation(4.1)
	check(not plot.pests and int(plot.stage) > 0, "live duck patrol clears a crop before destruction")
	await shot("ducks-world")
	game.state.coins = 2.0e14
	game.state.mastery.russet = 30000
	game.state.unlock_island2()
	game.state.travel_to(2)
	game.state.climate.acknowledge(game.state)
	game._on_action("activities")
	press("activity:contract:bulk")
	check(str(game.activities.contract.get("kind", "")) == "bulk", "Shores supply choice reaches backend")
	await shot("contracts")
	game.hud.close_panel()
	game.state._grant_item("traders_visor")
	game.state._grant_item("patchwork_cap")
	game.state._grant_item("harvest_gloves")
	game._on_action("inventory")
	press("inventory_tab:gear")
	game._on_action("gear:equip:patchwork_cap")
	check(game.state.equipment.head == "patchwork_cap", "chosen cosmetic gear equips")
	game._on_action("gear:equip:traders_visor")
	check(game.state.item_stock_factor() > 1.0, "gear changes permanent stock value")
	await shot("gear")
	game.hud.close_panel()
	game.state.unlock_island3()
	game.state.travel_to(3)
	game.state.climate.acknowledge(game.state)
	game.state.select_crop("icecap")
	game.state.storage.icecap = 125
	game.builds.levels.industrialist = 1
	game.builds.select_build("industrialist")
	game.builds.professions.action("batch", "100")
	game.builds.use_ability()
	game._on_action("activities")
	press("activity:furnace:icecap")
	check(game.state.storage.icecap == 0, "furnace consumes exactly its fuel alongside loaded processor")
	check(game.activities.furnace_remaining > 0, "furnace action starts heat")
	game._process(1.0)
	check(is_equal_approx(float(game.builds.processing.get("elapsed", 0)), 3.0), "main loop applies furnace processing speed exactly once")
	await shot("furnace-panel")
	game.activities.furnace_remaining = 0.5
	game._process(1.0)
	check(is_equal_approx(float(game.builds.processing.get("elapsed", 0)), 5.0), "processing integrates only remaining half-second of heat")
	game.hud.close_panel()
	game.state.coins = 1.0e16
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("ISLAND FEATURE INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
