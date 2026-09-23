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
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	lesson("welcome")
	check(game.tutorial.STEPS.size() == 8, "eight compact stages replace the twenty-step tour")
	await shot("welcome")
	game._on_action("roll")
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
	game._process(10.1)
	lesson("harvest")
	walk_plot("harvest", 4)
	lesson("sell")
	await shot("first-sale")
	game._on_action("quick_sell")
	check(not game.tutorial.active and not game.state.tutorial_active and game.state.tutorial_progress.completed, "first sale ends all mandatory guidance")
	check(game.state.farm_help.data.enabled and game.state.farm_help.data.independent == 0, "first sale enables contextual help, not independent success")
	check(game.state.surge_timer == 180.0, "normal stock schedule starts fresh")
	for tool: String in ["hoe", "plant", "water", "harvest", "pest"]:
		check(button("tool:" + tool) != null, "full control includes " + tool)
	await shot("free-farm")
	press("farm_help:act")
	check(game.state.farm_help.data.dismissed.has("repeat"), "optional prompt dismisses in one click")
	# Use ordinary controls on an unmarked bed. No controller lesson assists it.
	game._on_action("market")
	press("buy:russet:1")
	game._on_action("close")
	walk_plot("hoe", 5)
	walk_plot("plant", 5)
	walk_plot("water", 5)
	game._process(10.1)
	walk_plot("harvest", 5)
	game._on_action("quick_sell")
	check(game.state.farm_help.data.independent == 4, "second crop was planted, watered, harvested and sold independently")
	check(not game.tutorial.active and not game.world._tutorial_plot_outline.visible, "independent crop has no tutorial lock or target arrow")
	# The first natural pest group stays safe until dealt with.
	game.state.update(30.0)
	game.hud.update_state(game.state)
	await shot("first-pests")
	check(game.state.farm_help.data.pest_phase == 1, "first natural infestation is protected")
	var target: int = int(str(game.state.farm_help.data.protected[0]).get_slice(":", 1))
	game.state.update(30.0)
	check(game.state.plots[target].pest_ticks == 0, "first pest cannot destroy its lesson crop")
	for key: String in game.state.farm_help.data.protected.duplicate():
		game.perform_plot(int(key.get_slice(":", 1)), "pest")
	check(game.state.farm_help.data.pest_phase == 2, "clearing first group returns to normal hazards")
	# Hold a fresh harvest before opting into a practice sale.
	game.state.storage.russet = 10
	game.state.current_event = ""
	game.state.natural_remaining = 0.0
	game.state.surge_remaining = 0.0
	game.state.surge_timer = 180.0
	game.state._market_core.russet.sell = game.state.CROPS.russet.base
	game.state._refresh_market(false)
	game.hud._help_cooldown = 0.0
	game.hud.update_state(game.state)
	await shot("practice-offer")
	press("farm_help:act")
	check(game.state.farm_help.data.practice_remaining == 10.0 and game.state.blind_cycle.booms == 0, "practice starts ten-second quote without counting tax boom")
	await shot("practice-boom")
	press("farm_help:act")
	check(game.state.storage.russet == 0 and game.state.farm_help.data.dismissed.has("stocks"), "real practice sale completes timing lesson")
	game.state.surge_timer = 30.0
	game.hud.update_state(game.state)
	await shot("taxes")
	check(game.hud._farm_tip.id == "taxes", "tax explanation appears before first scheduled boom")
	# Optional tour can advance without pretending a shop visit proves learning.
	game._on_action("help")
	press("tutorial:restart")
	var snapshot: Dictionary = game.state._save_data().duplicate(true)
	game._process(100.0)
	check(game.state._save_data() == snapshot, "tour preserves farm and help timers")
	press("tutorial:next")
	lesson("market")
	press("tutorial:next")
	lesson("sell")
	game._on_action("roll:all_in")
	check(game.state.roll_count == 0, "optional tour cannot spend coins")
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
