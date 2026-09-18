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
	check(int(game.activities.save_data().get("duck_level", 0)) == 1, "duck purchase reaches persistent simulation")
	await shot("ducks-panel")
	game.hud.close_panel()
	var plot: Dictionary = game.state.plots[0]
	plot.pests = true
	plot.pest_elapsed = 0.0
	game._on_state_changed()
	game._process(4.1)
	check(not plot.pests and int(plot.stage) > 0, "live duck patrol clears a crop before destruction")
	await shot("ducks-world")
	game.state.coins = 2.0e14
	game.state.mastery.russet = 30000
	game.state.unlock_island2()
	game.state.travel_to(2)
	game._on_action("activities")
	press("activity:contract:bulk")
	check(str(game.activities.contract.get("kind", "")) == "bulk", "Shores supply choice reaches backend")
	await shot("contracts")
	game.hud.close_panel()
	game.state._grant_item("traders_visor")
	game.state._grant_item("lucky_cap")
	game.state._grant_item("harvest_gloves")
	game._on_action("inventory")
	press("inventory_tab:gear")
	game._on_action("gear:equip:lucky_cap")
	check(game.state.effective_luck() > game.state.luck, "gear changes effective luck")
	game._on_action("gear:equip:traders_visor")
	check(game.state.item_stock_factor() > 1.0, "gear changes permanent stock value")
	await shot("gear")
	game.hud.close_panel()
	game.state.unlock_island3()
	game.state.travel_to(3)
	game.state.select_crop("icecap")
	game.state.storage.icecap = 125
	game.builds.levels.industrialist = 1
	game.builds.select_build("industrialist")
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
	game._on_action("roll")
	await shot("winter-rolls")
	var count_before: int = game.state.roll_count
	game._on_action("roll_batch:normal:5")
	check(game.hud.is_roll_animating() and game.state.roll_count == count_before + 5, "winter five-roll request grants five actual results")
	var paid_balance: float = game.state.coins
	game._on_action("roll_batch:normal:5")
	game._on_action("travel:1")
	check(game.state.roll_count == count_before + 5 and game.state.coins == paid_balance and game.state.current_island == 3, "reel blocks overlapping charges and island travel")
	await shot("batch-reel")
	game.hud._spinner._process(5.0)
	check(not game.hud.is_roll_animating(), "batch reveal unlocks controls")
	await shot("batch-results")
	game.hud.close_panel()
	game.state.travel_to(1)
	game._on_action("roll_batch:normal:3")
	check(game.state.roll_count == count_before + 5 and not game.hud.is_roll_animating(), "batch requests on a retired island cannot roll or lock HUD")
	if capture:
		root.size = Vector2i(960, 600)
		game._on_action("activities")
		await shot("compact-activities")
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("ISLAND FEATURE INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
