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
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.rng.seed = 6
	game.tutorial.start()
	lesson("welcome")
	game._show_year_start()
	check(game.year_intro.visible and game.year_intro.forecaster.text.begins_with("Iris"), "forecaster fronts the first year")
	var before: Dictionary = game.state._save_data().duplicate(true)
	game._process(1000)
	check(game.state._save_data() == before, "forecast pauses the guided year")
	await shot("forecast")
	game.year_intro.finish()
	press("tutorial:next")
	lesson("market")
	game._on_action("market")
	press("buy:russet:1")
	lesson("hoe")
	walk_plot("hoe", 4)
	lesson("plant")
	walk_plot("plant", 4)
	lesson("water")
	walk_plot("water", 4)
	lesson("grow")
	check(game._simulation_delta(1) == 10, "guided wait uses at most ten-times simulation")
	check(game.hud._tutorial_body.text.contains("10×") and game.hud._tutorial_next.text.contains("Summer in"), "Spring wait shows speed and remaining time")
	game._process(1000.0)
	check(game.state.tutorial_loss().is_empty() and game._simulation_delta(1) == 1, "accelerated Spring stops at the real-time storm warning")
	check(game.hud._tutorial_forecaster.visible and game.hud._tutorial_title.text.begins_with("Iris") and game.hud._tutorial_next.text.contains("Storm in 8s") and game.hud._tutorial_body.text.contains("1×"), "Iris appears with the live Summer countdown")
	await shot("iris-warning")
	var warning_snapshot: Dictionary = game.state._save_data().duplicate(true)
	game._process(8.0)
	lesson("loss")
	check(game.state.season_clock.season == 1 and game.state.climate.data.phase == "active", "large update stops at Summer cause card")
	var loss: Dictionary = game.state.tutorial_loss()
	check(loss.sacks == 1 and loss.saved == 1 and loss.missing == "Windbreak missing", "small disaster records real yield and prevention")
	check(game.state.ClimateSystem.Protection.remaining(game.state.plots[4]) == 2, "storm leaves a harvest")
	check(game.hud._panel_kind == "loss_notices" and game.hud._refs.tess_board.loss_notes.find_children("*", "Label", true, false).any(func(label): return label.text.contains("360")) and game.hud._refs.tess_board.loss_notes.find_children("*", "Label", true, false).any(func(label): return label.text.contains("1 t")), "farmhand reports the base-value loss and cause")
	game.tutorial.explain_block()
	check(not game.hud._tutorial_body.text.is_empty(), "blocked input retains cause-card guidance")
	await shot("cause-card")
	var stopped: Dictionary = game.state._save_data().duplicate(true)
	game._process(1000)
	check(game.state._save_data() == stopped, "reading loss card pauses hazards")
	var path: String = "user://first-year-%d.json" % OS.get_process_id()
	check(game.state.save_game(path) and game.state.load_game(path), "cause card and guided weather survive reload")
	game.tutorial.start()
	lesson("loss")
	press("tutorial:next")
	lesson("harvest")
	walk_plot("harvest", 4)
	lesson("sell")
	check(game.state.stock_count("russet") == 2, "harvest puts the actual survivor in the barn")
	var choice: Dictionary = game.state._save_data().duplicate(true)
	# Both choices start from the same earned harvest; neither completes early.
	for decision: String in ["sell", "store"]:
		if decision == "store":
			game.hud.close_panel()
			game.state.restore_snapshot(choice)
			game.tutorial.start()
		if decision == "sell":
			game._on_action("sell_potatoes")
			await settle()
			press("market_all")
			press("market_sell")
		else: press("tutorial:next")
		lesson("winter")
		check(not game.state.tutorial_progress.completed and game.state.tutorial_progress.choice == decision, "choice saved without ending guide: " + decision)
		game._process(1000)
		check(game.state.season_clock.year == 1 and game.state.season_clock.season == 3, "new player reaches first Winter: " + decision)
		check(game.state.accounts_open and game.hud._panel_kind == "accounts", "annual ledger is open: " + decision)
		check(game.state.tutorial_progress.completed and not game.tutorial.active, "guidance ends at accounts: " + decision)
		check(game.state.ledger.is_closed(1) and game.state.ledger.total(1) < -100000, "normal bills posted to honest negative ledger: " + decision)
		check(game.hud._refs.accountant.text == "Nell · Accountant" and game.hud._refs.accountant.tooltip_text == game.state.NpcRoster.ledger_lines(game.state), "accountant reads current ledger")
		check(game.state.stock_count("russet") == (2 if decision == "store" else 0), "choice determines stored stock")
		check(game.state._valid_save(game.state._save_data()), "first accounts save valid: " + decision)
		stopped = game.state._save_data().duplicate(true)
		game._process(1000)
		check(game.state._save_data() == stopped, "accounts pause year: " + decision)
		await shot("accounts-" + decision)
	game._on_action("close")
	game.tutorial.start(true)
	stopped = game.state._save_data().duplicate(true)
	game._process(1000)
	check(game.state._save_data() == stopped, "optional tour freezes the existing farm")
	game.tutorial.finish()
	check(game.state.farm_help.data.enabled, "later help available without compulsory stages")
	# Resume at a pre-controller Winter settlement checkpoint.
	game.state.restore_snapshot(choice)
	game.tutorial.start()
	game.tutorial.next()
	game.state.update(1000)
	game.state.tutorial_progress.completed = false
	game.state.tutorial_progress.step = 9
	game.state.set_tutorial_active(false)
	game.hud.close_panel()
	game.tutorial.start()
	check(game.state.tutorial_progress.completed and not game.tutorial.active, "Winter checkpoint resumes without redoing the guided year")
	# A saved step-six Summer with a started calm outlook must still progress.
	game.state.restore_snapshot(warning_snapshot)
	game.state.tutorial_progress.step = 5
	game.state.season_clock.seconds = 75
	game.state.climate.reset()
	game.state.climate.data.outlook.started = 1
	game.tutorial.start()
	check(game.state.climate.data.phase == "warning" and game.hud._tutorial_forecaster.visible, "mid-Summer resume starts the missing lesson warning and shows Iris")
	game._process(8)
	lesson("loss")
	check(game.state.tutorial_loss().sacks == 1 and game.state.ClimateSystem.Protection.remaining(game.state.plots[4]) == 2, "resumed Summer reaches the real cause card without changing the crop")
	# Old completed guides stay completed, unfinished bed work keeps its target.
	game.state.reset_game()
	game.state.tutorial_progress = {"version": 2, "step": 3, "completed": false, "plot": 4}
	game.state.plots[4].tilled = true
	game.tutorial.start()
	lesson("plant")
	check(game.state.tutorial_progress.version == 3 and game.state.tutorial_progress.plot == 4, "v2 bed and planting step migrate")
	game.tutorial.finish()
	game.state.tutorial_progress.version = 2
	game.tutorial.start()
	check(not game.tutorial.active and game.state.tutorial_progress.completed, "old completed introductions remain optional")
	game.state.reset_game()
	game.state.tutorial_progress = {"version": 1, "step": 10, "completed": false, "plot": 5}
	game.tutorial.start()
	check(not game.tutorial.active and game.state.tutorial_progress.completed, "retired compulsory tour does not restart farming")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("TUTORIAL SCENE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
