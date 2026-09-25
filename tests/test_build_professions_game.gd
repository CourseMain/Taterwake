extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func frames() -> void:
	for i in range(5): await process_frame
func capture(id: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await frames()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/profession-" + id + ".png")
func click(button: Button) -> void:
	await frames()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = button.get_global_rect().get_center()
	e.pressed = true
	root.push_input(e,true)
	for i in range(3):
		game.hud.update_state(game.state)
		await process_frame
	e = e.duplicate()
	e.pressed = false
	root.push_input(e,true)
	await frames()
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	for id in game.builds.IDS: game.builds.levels[id] = 20
	for id in game.state.CROP_IDS: game.state.storage[id] = 20
	game._on_state_changed()
	game.hud._build_selection = ""
	game.hud.show_panel("builds",game.state)
	await capture("overview")
	for id in game.builds.IDS:
		game.builds.select_build(id)
		game.hud._act("build:inspect:" + id)
		await frames()
		check(game.hud._refs.has("prof_status"), "detail opens for " + id)
		check(not game.hud._refs.build_details.visible, "passive details folded for " + id)
		check(game.hud._refs.build_art.is_visible_in_tree(), "illustration visible for " + id)
		await capture(id)
		if id == "scientist":
			game.state.storage.russet = 20
			game.state.storage.golden = 20
			game._on_state_changed()
			await click(game.hud._refs.prof_breed)
			check(game.builds.professions.data.seedbank == ["hearty"], "held mouse click breeds once across refreshes")
	game.builds.select_build("industrialist")
	game.state.storage.russet = 100
	var profession: Dictionary = game.builds.professions.data
	profession.seedbank = ["hearty", "dry"]
	game.builds.professions.mark_fresh("russet", 100)
	profession.method = "cure"
	game.builds.professions.load_batch()
	game.builds.update(10)
	game.hud.update_state(game.state)
	check(game.hud._refs.build_art.grade == "SSS" and game.hud._refs.build_art.stamp_left > 0 and game.world.profession_world.celebration.visible, "SSS completion animates its illustrated stamp and world celebration")
	await capture("sss")
	game.builds.professions.load_batch()
	game.builds.professions.load_batch()
	game.builds.select_build("gambler")
	game.builds.professions.stake_harvest()
	game.hud.show_panel("inventory", game.state)
	await frames()
	check(game.hud._refs["item:queued:0:action"].text == "View queue", "queued inventory opens production instead of offering a sale")
	check(game.hud._refs["item:harvest_stake:action"].text == "View stake result", "reserved stake has an accurate inventory action")
	game.hud._refs["item:harvest_stake:action"].pressed.emit()
	check(game.hud._build_selection == "gambler" and game.hud._refs.has("prof_claim"), "inventory stake opens its claim controls directly")
	game.hud.close_panel()
	game.builds.select_build("farmer")
	game._on_action("profession:giant")
	game.queue_plot(0)
	game._select_tool("water")
	check(not game.prize_target and game.pending_tool != "cultivate", "changing tools cancels queued compost action")
	game._on_action("profession:giant")
	game.queue_plot(0)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	check(not game.prize_target and not game.walking, "Escape cancels prize-bed targeting and walk")
	game.state.plots[0].elapsed = 0.0
	game.state.plots[0].stage = 2
	game.state.plots[0].watered = true
	game._on_action("profession:giant")
	game.queue_plot(0)
	for i in range(300):
		game._process(.03)
		if not game.walking: break
	check(game.state.plots[0].get("cultivated",false), "world click walks to selected prize bed")
	game.state.plots[0].stage = 3
	game._on_state_changed()
	game.world.set_day_time(0)
	await capture("farm")
	game.state.blind_cycle.booms = 3
	game.state.blind_cycle.due_in = 10.0
	game.world.profession_world.refresh(game.builds,game.state)
	game.world.profession_world.animate(.01)
	check(game.world.profession_world.visitor.visible, "tax collector arrives on due day")
	var coins: float = game.state.coins
	var bill: float = game.state.blind_info().tax
	game.state.coins = bill * 2
	game._advance_simulation(10)
	check(is_equal_approx(game.state.coins,bill), "visitor preserves one exact tax collection")
	check(game.world.profession_world.tax_exit > 0, "collector departs with receipt")
	game.world.profession_world.animate(.1)
	await capture("tax")
	game.world.profession_world.animate(6)
	game.world.profession_world.animate(.01)
	check(not game.world.profession_world.visitor.visible, "collector leaves without lingering collider")
	game.state.debug_unlock_island(2)
	game.state.travel_to(2)
	game.state.climate.acknowledge(game.state)
	await frames()
	check(not game.world.profession_world.result_sign.visible, "travelling cannot replay an old profession result over the new farm")
	game.state.plots[0].stage = 1
	game.builds.professions.cultivate(0)
	check(game.world.profession_world.result_sign.visible, "a fresh action on the new island still gets its world feedback")
	game.queue_free()
	await frames()
	print("BUILD PROFESSIONS GAME: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
