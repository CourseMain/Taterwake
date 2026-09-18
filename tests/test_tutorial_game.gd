extends SceneTree
## Exercises the real tutorial/controller/HUD without opening player save data.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func button(action: String) -> Button:
	for candidate: Node in game.hud.find_children("*", "Button", true, false):
		if str(candidate.get_meta("action", "")) == action and candidate.is_visible_in_tree():
			return candidate as Button
	return null

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null, "visible action " + action)
	if target == null:
		return
	check(not target.disabled, "enabled action " + action)
	if not target.disabled:
		target.pressed.emit()

func walk_plot(tool: String, index: int) -> void:
	game._on_action("tool:" + tool)
	game.queue_plot(index)
	for frame: int in range(250):
		game._process(0.04)
		if not game.walking:
			break

func lesson(id: String) -> void:
	check(game.tutorial.current_id() == id, "lesson " + id)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to isolate player saves")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	lesson("welcome")
	check(game.state.tutorial_active, "calm simulation starts with guide")
	check(button("tool:hoe") == null and button("menu") == null, "first screen hides tool and menu clutter")
	game._on_action("roll")
	game._on_action("debug:apply:100:100")
	check(not game.hud.is_panel_open() and game.state.coins == 240.0, "keyboard/debug bypasses blocked")
	press("tutorial:next")
	lesson("walk")
	game.world.set_player_position(game.world.player.position + Vector3(2, 0, 0))
	game._process(0.01)
	lesson("market")
	game._on_action("market")
	check(button("buy:russet:1") != null and not button("buy:russet:1").disabled, "one-seed purchase available")
	var before: float = game.state.coins
	press("buy:russet:1")
	check(game.state.coins < before, "real seed purchase pays coins")
	lesson("hoe")
	game._select_tool("pest")
	check(game.selected_tool == "hoe", "unintroduced tool shortcut blocked")
	game.perform_plot(0, "harvest")
	check(game.state.plots[0].stage == 3, "unrelated crops cannot skip lesson")
	walk_plot("hoe", 5)
	lesson("plant")
	walk_plot("plant", 5)
	lesson("water")
	walk_plot("water", 5)
	lesson("grow")
	game._process(10.1)
	lesson("harvest")
	walk_plot("harvest", 5)
	lesson("sell")
	game._on_action("barn")
	press("sell:russet:-1")
	lesson("inventory")
	for pair: Array in [["inventory", "inventory"], ["tools", "tools"], ["builds", "builds"], ["quests", "quests"], ["roll", "roll"]]:
		lesson(str(pair[0]))
		check(button("tutorial:next") == null or button("tutorial:next").disabled, "must visit " + str(pair[0]) + " before continuing")
		game._on_action(str(pair[1]))
		check(game.hud.is_panel_open(), "NPC panel opens: " + str(pair[1]))
		if pair[1] == "roll":
			var rolls: int = game.state.roll_count
			game._on_action("roll:all_in")
			check(game.state.roll_count == rolls, "tour never forces/permits a wager")
		press("tutorial:next")
	lesson("pest_intro")
	game._process(400.0)
	var pests: int = 0
	for plot: Dictionary in game.state.plots:
		pests += int(bool(plot.pests))
	check(pests == 0 and game.state.surge_remaining == 0.0 and game.surge_band == 0, "long tutorial has no random pests or stock jackpot")
	press("tutorial:next")
	lesson("pest")
	var target: int = int(game.state.tutorial_progress.pest_plot)
	check(game.state.plots[target].pests, "one practice pest starts only after introduction")
	game._process(100.0)
	check(game.state.plots[target].pest_ticks == 0 and game.state.plots[target].stage > 0, "practice crop protected indefinitely")
	walk_plot("pest", target)
	lesson("ducks")
	game._on_action("duck_patrol")
	press("tutorial:next")
	lesson("stocks")
	check(game.state.surge_timer == 180.0, "stock clock still paused at full interval")
	press("tutorial:next")
	lesson("dock")
	game._on_action("island")
	press("tutorial:next")
	lesson("finish")
	press("tutorial:next")
	check(not game.tutorial.active and not game.state.tutorial_active, "finish restores normal simulation")
	check(game.state.tutorial_progress.completed and game.state.surge_timer == 180.0, "completion saved with fresh surge countdown")
	check(not game.state.island2_unlocked and game.state.total_mastery() < 500, "tutorial does not finish island one")
	check(game.tutorial.cue_count >= 18 and not game.tutorial_notes.is_empty(), "tutorial transitions queue sound cues")
	for tool: String in ["hoe", "plant", "water", "harvest", "pest"]:
		check(button("tool:" + tool) != null, "completion reveals " + tool)
	game._on_action("menu")
	press("tutorial:restart")
	lesson("welcome")
	check(game.state.tutorial_progress.tour_only, "replay is an informational tour")
	press("tutorial:next")
	lesson("market")
	game._on_action("market")
	press("tutorial:next")
	lesson("sell")
	game._on_action("barn")
	press("tutorial:next")
	lesson("inventory")
	press("tutorial:skip")
	check(not game.tutorial.active and game.state.tutorial_progress.completed, "skip safely restores normal play")
	# Save/resume uses test-only paths and resumes the exact protected pest stage.
	game.state.reset_game()
	game.state.tutorial_progress.step = 15
	game.tutorial.start()
	var path: String = "user://tutorial-scene-test-save.json"
	check(game.state.save_game(path), "mid-tutorial save succeeds")
	game.tutorial.finish()
	check(game.state.load_game(path), "mid-tutorial reload succeeds")
	game.tutorial.start()
	lesson("pest")
	check(game.state.plots[int(game.state.tutorial_progress.pest_plot)].pests, "reload restores practice pest")
	game.tutorial.finish()
	DirAccess.remove_absolute(path)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("TUTORIAL SCENE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
