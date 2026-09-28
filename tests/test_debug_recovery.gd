extends SceneTree
## Real authenticated routes, existing debt semantics and disposable save roundtrips.
const SAVE := "user://tater_debug_recovery_test_only.json"
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func settle() -> void:
	for _i in range(8): await process_frame
func click(button: Button) -> void:
	if game.hud._body.is_ancestor_of(button):
		(game.hud._body.get_parent() as ScrollContainer).ensure_control_visible(button)
	await settle()
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
	await settle()
func shot(name: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.75).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/debug-recovery-" + name + ".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	var farm = game.state
	game._on_action("debug:set_balance:15e9")
	check(farm.coins == 240, "locked route cannot set positive funds")
	game._on_action("debug:unlock:" + game.DEBUG_ACCESS_CODE)
	game._on_action("debug:island:2")
	check(farm.coins == 240 and farm.current_island == 1 and farm.blind_cycle.island == 1, "unlocking does not silently fund or promote tax")
	farm.travel_to(2)
	farm.climate.acknowledge(farm)
	check(farm.blind_info().tax == 5e9 and farm.coins == 240, "first actual visit promotes the explicit Island2 tax")
	farm.plots[0].merge({"stage": 2, "crop": "russet", "elapsed": 2.0, "tilled": true, "watered": true}, true)
	farm.seed_inventory.russet = 37
	farm.storage.russet = 40
	farm.tools.water = 1
	game.builds.levels.farmer = 3
	farm.coins = 0.0
	farm._resolve_blind()
	check(farm.coins == -5e9 and not farm.run_over, "exact debt boundary survives first unpaid bill")
	farm._resolve_blind()
	check(farm.coins == -10e9 and farm.run_over, "second unpaid bill crosses the same limit once")
	await settle()
	var collapse = game.hud._run_end
	check(collapse.visible and collapse._threshold.text.contains("-\uE000 5B"), "collapse shows actual bankruptcy threshold")
	check(collapse._calculation.text.contains("-\uE000 5B before") and collapse._calculation.text.contains("\uE000 5B tax") and collapse._calculation.text.contains("-\uE000 10B after"), "receipt explains the user's negative balance arithmetic")
	check(not collapse._ledger.visible, "optional climate education does not cover the tax cause")
	await shot("receipt")
	game._on_action("debug:lock")
	check(not game.debug_unlocked, "test session can lock while collapsed")
	var frozen: Dictionary = farm._save_data().duplicate(true)
	game._on_action("debug:recover:15e9")
	game._on_action("debug:set_balance:15e9")
	game._on_action("quick_sell")
	check(farm._save_data() == frozen, "locked recovery/funding and ordinary rewards cannot revive run")
	await click(collapse.find_child("DebugAccess", true, false))
	await settle()
	check(game.hud._panel_kind == "debug" and game.hud.is_panel_open() and game.hud._modal.z_index > collapse.z_index, "collapse opens code-gated Debug above receipt")
	game.hud._refs.debug_code.text = "incorrect"
	await click(game.hud._refs.debug_unlock)
	check(not game.debug_unlocked and farm.run_over, "wrong code cannot recover farm")
	game.hud._refs.debug_code.text = game.DEBUG_ACCESS_CODE
	await click(game.hud._refs.debug_unlock)
	await settle()
	check(game.debug_unlocked and game.hud._refs.debug_recover.visible and not game.hud._refs.debug_set_balance.visible, "authenticated collapsed farm exposes explicit recovery")
	check(not game.hud._refs.debug_advanced.visible, "multiplier and luck start folded")
	game.hud._act("debug_balance_preset:15e9")
	check(farm.coins == -10e9 and game.hud._refs.debug_balance_input.value == 15e9, "funding preset only fills input")
	await shot("recover-funds")
	for invalid: String in ["bad", "-1", "1e301", "1e-999", "0"]:
		game._on_action("debug:recover:" + invalid)
		check(farm.run_over and farm.coins == -10e9, "invalid recovery remains atomic: " + invalid)
	game._on_action("debug:set_balance:15e9")
	check(farm.run_over and farm.coins == -10e9, "ordinary set-balance cannot silently resume ended run")
	var plots: Dictionary = farm.island_plots.duplicate(true)
	var seeds: Dictionary = farm.seed_inventory.duplicate(true)
	var storage: Dictionary = farm.storage.duplicate(true)
	var tools_before: Dictionary = farm.tools.duplicate(true)
	var builds_before: Dictionary = game.builds.save_data().duplicate(true)
	var activities_before: Dictionary = game.activities.save_data().duplicate(true)
	game._on_action("debug:time:30")
	game.hud._refs.debug_balance_input.text = "15e9"
	await click(game.hud._refs.debug_recover)
	await settle()
	check(not farm.run_over and farm.coins == 15e9 and farm.debug_money_modified, "explicit action restores funded test farm and provenance")
	check(farm.island_plots == plots and farm.seed_inventory == seeds and farm.storage == storage and farm.tools == tools_before and farm.current_island == 2 and farm.island2_unlocked, "recovery preserves field, seeds, inventory, tools and island progress")
	check(game.builds.save_data() == builds_before and game.activities.save_data() == activities_before, "recovery keeps actual build levels, profession tasks and island activities")
	check(farm.blind_cycle.booms == 0 and farm.blind_cycle.due_in == 0 and farm.surge_timer == farm.SURGE_INTERVAL and game.debug_time_multiplier == 1.0, "recovery resets tax and stock countdown at normal speed")
	check(not collapse.visible and not game.hud.is_panel_open() and game.hud._top.coins.is_visible_in_tree(), "farm HUD returns and collapse Debug closes after recovery")
	check(farm.climate.data.collapse.is_empty() and not farm.blind_cycle.last_result.is_empty(), "past tax receipt kept without a stale collapse")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and not farm.run_over and farm.debug_money_modified, "recovered test state roundtrips in a dedicated save only")
	game._on_action("debug")
	game.hud._refs.debug_balance_input.text = "0"
	game.hud._act("debug_set_balance")
	check(farm.coins == 0 and not farm.run_over, "explicit set to zero leaves test farm running")
	game.hud._refs.debug_balance_input.text = "15e9"
	game.hud._act("debug_set_balance")
	check(farm.coins == 15e9, "exact funding works from zero")
	farm.coins = -4e9
	game.hud._refs.debug_balance_input.text = "15e9"
	game.hud._act("debug_set_balance")
	check(farm.coins == 15e9 and not farm.run_over, "exact funding clears surviving debt without multiplying it")
	for invalid: float in [-1.0, INF, NAN]:
		farm.debug_set_balance(invalid)
		check(farm.coins == 15e9, "state rejects nonfinite/negative exact balance")
	game._on_action("debug:time:30")
	var before: Dictionary = farm._save_data().duplicate(true)
	var cooldown: float = game.builds.cooldown
	game._process(1.0)
	check(farm._save_data() == before and game.builds.cooldown == cooldown, "Debug editing pauses all saved simulation at30x")
	await shot("healthy-workshop")
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360)]:
		root.min_size = Vector2i.ZERO
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = game.hud._body.get_parent()
		check(game.hud.root.get_global_rect().grow(1).encloses(game.hud._modal_card.get_global_rect()), "Debug modal fits " + str(dimensions))
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 1, "Debug quick tools have no horizontal overflow " + str(dimensions))
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		check(game.hud._body.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "Debug last action reachable " + str(dimensions))
	game.hud.close_panel()
	farm.coins = -4e9
	farm.apply_debug(2.5)
	await settle()
	check(farm.coins == -10e9 and collapse._calculation.text == "No tax was collected at this moment." and not farm.blind_cycle.last_result.is_empty(), "Debug bankruptcy matching an old receipt is not misreported as new tax; receipt is kept")
	for node: Node in collapse.find_children("*", "Button", true, false):
		check(game.hud.root.get_global_rect().grow(1).encloses(node.get_global_rect()), "collapse action stays reachable at640: " + node.text)
	collapse._summary_button.pressed.emit()
	await shot("compact-summary")
	for node: Node in collapse.find_children("*", "Button", true, false):
		check(game.hud.root.get_global_rect().grow(1).encloses(node.get_global_rect()), "summary does not displace action: " + node.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await settle()
	print("DEBUG RECOVERY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
