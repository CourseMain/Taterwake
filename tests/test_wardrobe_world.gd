extends SceneTree
## Full scene checks for matching character gear and independently working flocks.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func shot(label: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/wardrobe-" + label + ".png") == OK, "capture " + label)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 2e14
	game.state.mastery.russet = 30000
	game.state.unlock_island2()
	game.state.unlock_island3()
	for id in ["straw_hat", "lucky_cap", "farmer_shirt", "farmer_pants", "farmer_boots", "harvest_gloves", "market_monocle", "investor_shirt", "scientist_coat", "gambler_shirt", "industrialist_overalls", "industrialist_pants", "industrialist_boots"]:
		game.state._grant_item(id)
	game._on_action("gear:equip:straw_hat")
	game._on_action("gear:equip:farmer_shirt")
	game._on_state_changed()
	check(game.world._player_body.loadout == game.state.equipment_loadout(), "field farmer uses actual equipped items")
	game._on_action("gear:equip:lucky_cap")
	check(game.world._gear_hat_id == "lucky_cap" and game.state.equipment_loadout().head == "lucky_cap", "equipping another hat replaces the first in world and simulation")
	game._on_action("gear:unequip:head")
	check(game.world._gear_hat == null and not game.world._player_body.gear_parts.has("head"), "removing a hat removes its model")
	game._on_action("gear:equip:straw_hat")
	for island in [1, 2, 3]:
		game.state.travel_to(island)
		for _duck in range(island):
			game.activities.hire_duck()
		game.state.pest_timer = 100.0
		game.state._event_in = 100.0
		for plot in game.state.plots:
			game.state._clear_crop(plot)
		for index in range(island):
			var plot: Dictionary = game.state.plots[index * 4]
			plot.merge({"unlocked": true, "crop": "russet", "stage": 3, "tilled": true, "watered": true, "elapsed": 10.0, "pests": true}, true)
		game._on_state_changed()
		check(game.world._ducks.size() == island and game.activities.info().ducks.size() == island, "island%d has exactly%d visible and simulated ducks" % [island, island])
		check(game.world._player_body.loadout == game.state.equipment_loadout(), "full outfit survives travel to island%d" % island)
		var before: int = game.activities.duck_clears
		game._process(0.1)
		game._process(2.0)
		await shot("flock-island%d" % island)
		game._process(2.0)
		check(game.activities.duck_clears - before == island, "every island%d duck clears its own infested bed" % island)
		for index in range(island):
			check(not game.state.plots[index * 4].pests and game.state.plots[index * 4].stage == 3, "patrol removes pests without destroying crops")
	game.state.storage.icecap = 200
	game.state.select_crop("icecap")
	game.builds.levels.industrialist = 1
	game.builds.select_build("industrialist")
	for id in ["industrialist_overalls", "industrialist_pants", "industrialist_boots"]:
		game._on_action("gear:equip:" + id)
	game.builds.use_ability()
	game.activities.charge_furnace()
	game.activities.furnace_remaining = 0.5
	var gear_factor: float = game.state.equipment_processing_factor()
	game._process(1.0)
	check(gear_factor > 1.0 and is_equal_approx(float(game.builds.processing.elapsed), 2.0 * gear_factor), "equipped clothes and furnace multiply processing once with exact heat expiry")
	game._on_action("inventory")
	game.hud._act("inventory_tab:gear")
	await shot("equipment-industrialist")
	game._on_action("gear:equip:scientist_coat")
	await shot("equipment-mixed-build")
	if capture:
		root.size = Vector2i(960, 600)
		await shot("equipment-compact")
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("WARDROBE AND FLOCK WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
