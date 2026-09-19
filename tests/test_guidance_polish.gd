extends SceneTree
## Real scene interactions; never touches the player's save.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for _frame: int in range(8):
		game.world.animate(0.04, false)
		await process_frame
	game.hud._process(0.1)

func shot(name: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/polish-" + name + ".png") == OK, "capture " + name)

func lesson(index: int) -> void:
	game.state.tutorial_progress.step = index
	game.tutorial._enter_step()

func press(action: String) -> void:
	for node: Node in game.hud.root.find_children("*", "Button", true, false):
		if node.get_meta("hud_action", "") == action and node.is_visible_in_tree():
			check(not node.disabled, "enabled " + action)
			if not node.disabled:
				node.pressed.emit()
			return
	check(false, "visible " + action)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	await shot("welcome")
	check(game.hud._tutorial_pointer.target == game.hud._tutorial_next, "welcome highlights Start, never Exit")
	press("tutorial:exit")
	await shot("exit-choice")
	check(game.tutorial.current_id() == "welcome" and game.hud._tutorial_exit_box.visible, "first exit click leaves lesson intact")
	press("tutorial:stay")
	lesson(2)
	game.world.set_player_position(Vector3(-7, 0, 7))
	await shot("market-trail")
	check(game.world._tutorial_trail.size() == 6 and game.world._tutorial_trail[0].visible, "gold trail leads from farmer to destination")
	game._on_action("market")
	await shot("buy-seed")
	check(game.hud._tutorial_pointer.target == game.hud._refs["buy:russet:1"], "shop arrow follows exact buy button")
	press("buy:russet:1")
	await shot("hoe")
	check(game.hud._tutorial_pointer.target == game.hud._tool_buttons.hoe, "next arrow follows the newly introduced hoe")
	game.tutorial.finish()
	check(game.world._tutorial_trail.all(func(node: Node3D): return not node.visible), "finishing hides all trail markers")
	game.state.coins = 1e16
	game.state.mastery.russet = 30000
	game.state.unlock_island2()
	game.state.unlock_island3()
	for island: int in [1, 2, 3]:
		game.state.travel_to(island)
		game._on_action("duck_patrol")
		check(game.hud._refs.has("activity:duck") and game.hud._refs.has("activity:duck:speed"), "two distinct duck controls on island %d" % island)
		check(game.hud._refs["activity:duck:speed"].disabled, "empty flock cannot buy speed")
		await shot("ducks-%d-empty" % island)
		for count: int in range(island):
			var previous: float = game.state.coins
			var cost: float = game.activities.duck_hire_cost()
			press("activity:duck")
			check(game.activities.duck_count() == count + 1 and is_equal_approx(previous - game.state.coins, cost), "hire commits one duck and exact cost")
		check(game.hud._refs["activity:duck"].disabled, "cap disables hiring")
		var capped: float = game.state.coins
		game._on_action("activity:duck")
		check(game.activities.duck_count() == island and game.state.coins == capped, "cap also enforced beneath UI")
		press("activity:duck:speed")
		check(game.activities.duck_count() == island and game.activities.duck_interval() == 3.0, "speed changes time without adding ducks")
		await shot("ducks-%d-trained" % island)
	game.state.travel_to(2)
	game.state.selected_crop = "sunburst"
	game.state.market.sunburst.sell = 90000
	game.state.storage.sunburst = 100
	game._on_action("activities")
	await shot("buyer-choices")
	var shop_scroll: Control = game.hud._body.get_parent()
	for kind: String in ["bulk", "mutation"]:
		check(shop_scroll.get_global_rect().encloses(game.hud._refs["activity:contract:" + kind].get_global_rect()), "both buyer choice buttons fit without scrolling")
	check(game.hud._refs.contract_choices.visible and not game.hud._refs.contract_delivery.visible, "buyer starts with two offers, no irrelevant delivery form")
	check(game.activities.contract_offer("bulk").target == 400 and game.activities.contract_offer("mutation").target == 1, "choices preview their real requirements")
	press("activity:contract:bulk")
	check(not game.hud._refs.contract_choices.visible and game.hud._refs.contract_delivery.visible, "accepted offer changes to delivery view")
	var balance: float = game.state.coins
	press("activity:deliver")
	check(game.activities.contract.delivered == 100 and game.state.coins == balance, "partial shipment banks credit without premature payment")
	check(is_equal_approx(game.hud._refs.contract_progress.value, 25.0), "progress bar reflects actual shipment")
	await shot("buyer-progress")
	var snapshot: Dictionary = game.activities.save_data()
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.duck_counts["1"] = 2
	check(not game.activities.load_data(invalid) and game.activities.save_data() == snapshot, "invalid count is rejected atomically")
	invalid = snapshot.duplicate(true)
	invalid.duck_speeds["2"] = 3
	check(not game.activities.valid_data(invalid), "invalid speed is rejected")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 2
	legacy.duck_level = 2
	legacy.erase("duck_counts")
	legacy.erase("duck_speeds")
	check(game.activities.load_data(legacy), "v1.0.0 flock save migrates")
	for island: String in ["1", "2", "3"]:
		check(game.activities.duck_counts[island] == int(island) and game.activities.duck_speeds[island] == 1, "migration preserves paid flock and training on island " + island)
	check(game.activities.load_data(snapshot), "new save resumes exactly")
	root.size = Vector2i(960, 600)
	game._on_action("duck_patrol")
	await shot("ducks-compact")
	game._on_action("activities")
	await shot("buyer-compact")
	game.state.travel_to(1)
	game.tutorial.start(true)
	await shot("guide-compact")
	game.tutorial.finish()
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("GUIDANCE POLISH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
