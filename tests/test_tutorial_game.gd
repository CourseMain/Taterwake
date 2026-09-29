extends SceneTree
## Real first lesson, independent crop, optional tour and old-guide migration.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func button(action: String) -> Button:
	for candidate: Node in game.hud.root.find_children("*", "Button", true, false):
		if candidate.get_meta("hud_action", "") == action and candidate.is_visible_in_tree(): return candidate
	return null

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null and not target.disabled, "visible enabled action " + action)
	if target != null and not target.disabled: target.pressed.emit()

func walk_plot(tool: String, index: int) -> void:
	game._on_action("tool:" + tool)
	game.queue_plot(index)
	for frame: int in range(400):
		game._process(0.04)
		if not game.walking: break

func lesson(id: String) -> void:
	check(game.tutorial.current_id() == id, "lesson " + id)

func settle() -> void:
	for _frame: int in range(8): await process_frame
	game.hud._process(0.1)

func shot(name: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/guide-" + name + ".png") == OK, "capture " + name)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Reproduce the same infestation and weather while exercising ordinary controls.
	game.state.rng.seed = 6
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	lesson("welcome")
	check(game.tutorial.STEPS.size() == 8, "eight compact stages replace the twenty-step tour")
	await shot("welcome")
	game._on_action("tools")
	check(not game.hud.is_panel_open() and not game.hud._tutorial_body.text.is_empty(), "blocked keyboard action explains current task")
	press("tutorial:next")
	lesson("market")
	game._on_action("market")
	await shot("seed")
	check(game.hud._tutorial_pointer.target == button("buy:russet:1"), "market cue targets actual buy control")
	press("buy:russet:1")
	lesson("hoe")
	await shot("hoe")
	check(game.hud._tutorial_pointer.target == null and game.world._tutorial_plot_outline.visible, "one farming cue points to bed, not equipped tool")
	walk_plot("hoe", 4)
	lesson("plant")
	check(game.state.tutorial_progress.plot == 4, "choosing another empty bed retargets lesson")
	game.perform_plot(5, "hoe")
	check(game.selected_tool == "plant" and game.hud._tutorial_body.text.contains("gold bed"), "wrong bed/tool gives recovery feedback")
	walk_plot("plant", 4)
	lesson("water")
	walk_plot("water", 4)
	lesson("grow")
	game._process(float(game.state.CropTable.CROPS.russet.grow) + 0.1)
	lesson("harvest")
	walk_plot("harvest", 4)
	lesson("sell")
	await shot("first-sale")
	game._on_action("sell_potatoes")
	await settle()
	check(not button("market_sell").disabled and not button("market_all").disabled, "first sale enables the new trade controls")
	press("market_all")
	press("market_sell")
	check(not game.tutorial.active and not game.state.tutorial_active and game.state.tutorial_progress.completed, "first sale ends all mandatory guidance")
	check(game.state.farm_help.data.enabled and game.state.farm_help.data.independent == 0, "first sale enables contextual help, not independent success")
	for tool: String in ["hoe", "plant", "water", "harvest", "pest"]:
		check(button("tool:" + tool) != null, "full control includes " + tool)
	game.hud._process(3.1)
	await shot("free-farm")
	check(not game.hud._farm_help_card.visible, "finishing the introduction does not add an extra help prompt")
	# Use ordinary controls on an unmarked bed. No controller lesson assists it.
	game._on_action("market")
	press("buy:russet:1")
	game._on_action("close")
	walk_plot("hoe", 5)
	walk_plot("plant", 5)
	walk_plot("water", 5)
	game._process(float(game.state.CropTable.CROPS.russet.grow) + 0.1)
	walk_plot("harvest", 5)
	game._on_action("quick_sell")
	check(game.state.farm_help.data.independent == 4, "second crop was planted, watered, harvested and sold independently")
	check(not game.tutorial.active and not game.world._tutorial_plot_outline.visible, "independent crop has no tutorial lock or target arrow")
	# Cover the full 15–90 second ripe-crop delay and 40 second minimum age.
	# The first natural pest group stays safe until dealt with.
	game.state.update(100.0)
	game.hud.update_state(game.state)
	await shot("first-pests")
	check(game.state.farm_help.data.pest_phase == 1, "first natural infestation is protected")
	var target: int = int(game.state.farm_help.data.protected[0])
	game.state.update(30.0)
	check(game.state.plots[target].pest_ticks == 0, "first pest cannot destroy its lesson crop")
	for key: String in game.state.farm_help.data.protected.duplicate():
		if game.state.climate.Operations.frozen(game.state, int(key)):
			game.perform_plot(int(key), "hoe")
			check(not game.state.climate.Operations.frozen(game.state, int(key)), "clear weather ice before spraying protected pests")
		game.perform_plot(int(key), "pest")
	check(game.state.farm_help.data.pest_phase == 2, "clearing first group returns to normal hazards")
	game._on_action("help")
	check(game.hud._modal_title.text == "Controls" and button("farm_help:details") == null, "controls page has no extra practice or help launcher")
	game.hud.close_panel()
	game.hud.update_state(game.state)
	game.hud.update_state(game.state)
	await shot("taxes")
	# Optional tour can advance without pretending a shop visit proves learning.
	game._on_action("help")
	game._on_action("tutorial:restart")
	var snapshot: Dictionary = game.state._save_data().duplicate(true)
	game._process(100.0)
	check(game.state._save_data() == snapshot, "tour preserves farm and help timers")
	press("tutorial:next")
	lesson("market")
	press("tutorial:next")
	lesson("sell")
	game._on_action("tools")
	await settle()
	press("tutorial:exit")
	press("tutorial:stay")
	lesson("sell")
	press("tutorial:exit")
	press("tutorial:skip")
	check(not game.tutorial.active, "tour can be left without visiting anyone")
	# Resume a current lesson at exactly its saved bed and stage.
	game.state.reset_game()
	game.tutorial.start()
	game.state.tutorial_progress.step = 3
	game.state.tutorial_progress.plot = 4
	game.state.plots[4].tilled = true
	game.tutorial._enter_step()
	var path: String = "user://tutorial-scene-%d.json" % OS.get_process_id()
	check(game.state.save_game(path), "new lesson saves")
	game.tutorial.finish()
	check(game.state.load_game(path), "new lesson reloads")
	game.tutorial.start()
	lesson("plant")
	check(game.state.tutorial_progress.plot == 4, "chosen bed survives reload")
	game.tutorial.finish()
	game.state.reset_game()
	game.state.tutorial_progress = {"version": 1, "step": 4, "completed": false, "plot": 5}
	game.tutorial.start()
	lesson("plant")
	game.tutorial.finish()
	game.state.reset_game()
	game.state.tutorial_progress = {"version": 1, "step": 10, "completed": false, "plot": 5}
	game.tutorial.start()
	check(not game.tutorial.active and game.state.tutorial_progress.completed and game.state.farm_help.data.enabled, "old post-sale tour retires without restarting farming")
	game.state.farm_help.data.enabled = false
	game.state.farm_help.data.hidden = false
	game._on_action("farm_help:toggle")
	check(game.state.farm_help.data.enabled and not game.state.farm_help.data.hidden, "established player can enable optional help in one click")
	game._on_action("farm_help:toggle")
	check(game.state.farm_help.data.hidden, "hide tips applies immediately")
	game._on_action("farm_help:toggle")
	check(not game.state.farm_help.data.hidden, "show tips restores help without resetting dismissals")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("TUTORIAL SCENE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
