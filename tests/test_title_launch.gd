extends SceneTree
## Exercise production title initialization with an isolated integration farm.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(why)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.launch_title_in_tests = true
	root.add_child(game)
	game.set_process(false)
	check(game.title_active() and game.title_scene.walk.text == "Walk to the farm", "fresh farm already owns the title before the first process frame")
	check(not game.hud.root.visible and not game.hud.is_panel_open() and not game.year_intro.visible and not game.tutorial.active,"no HUD, panel, annual page or guide precedes the title")
	check(game.farm_viewport.picture.is_inside_tree() and game.farm_viewport.size.x > 1,"farm picture is attached synchronously for the first render")
	await process_frame
	check(game.title_active() and not game.title_scene.resume.is_visible_in_tree(),"first launch has exactly one visible title action")
	game.title_scene.walk.pressed.emit()
	game._process(.6)
	check(game.title_active() and not game.tutorial.active,"walk-in has no guide card halfway through")
	game._process(.6)
	check(not game.title_active() and game.tutorial.current_id() == "welcome","first guide card follows the finished walk-in")
	game._show_title(true)
	game.title_scene.walk.pressed.emit()
	check(game.tutorial.current_id() == "welcome" and game.state.tutorial_active and not game.hud.is_panel_open(), "Continue preserves an unfinished guide without opening a modal")
	game.tutorial.finish()
	game.year_intro.stop()
	game.state.tutorial_progress.completed = true
	game.state.season_clock.year = 2
	game.state.season_clock.season = 3
	game._on_state_changed()
	game._show_title(true)
	check(game.title_scene.walk.text == "Continue · Year 2, Winter" and game.title_scene.resume.text == "Start a new farm","returning title puts the saved farm on the main action")
	game.title_scene.walk.pressed.emit()
	check(not game.title_active() and not game.hud.is_panel_open(),"Continue enters the saved Winter farm directly without opening accounts")
	game.queue_free()
	for i in range(6): await process_frame
	print("TITLE LAUNCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
