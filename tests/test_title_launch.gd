extends SceneTree
## Exercise production title initialization with an isolated integration farm.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(why)
func capture_view(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/v204-" + name + ".png")
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
	for size: Vector2i in [Vector2i(1440,900), Vector2i(390,844), Vector2i(2888,1804)]:
		root.size = size
		root.content_scale_size = size
		for attempt in range(2):
			game = load("res://scenes/main.tscn").instantiate()
			game.launch_title_in_tests = true
			root.add_child(game)
			game.set_process(false)
			# Reproduce a first-frame snapshot taken before the Web viewport fits.
			game.title_scene.saved_camera.origin = Vector3(1000,-200,1000)
			game.title_scene.saved_size = 9000.0
			for frame in range(6): await process_frame
			game.title_scene.walk.pressed.emit()
			game._process(1.2)
			var camera: Camera3D = game.world.camera
			check(is_equal_approx(camera.size,game.world.overview_size()),"fresh overview size ignores stale title snapshot at " + str(size))
			check(camera.position.y > 0 and camera.position.x < 100,"fresh overview position ignores stale title snapshot")
			check(game._camera_home_position.is_equal_approx(camera.global_position) and is_equal_approx(game._camera_home_size,camera.size),"fresh Home and zoom defaults adopt the fitted overview")
			var entered: Transform3D = camera.transform
			game._process(.1)
			check(camera.transform.is_equal_approx(entered),"the next gameplay frame cannot pull the camera back to its stale Home position")
			var center: Vector2 = camera.unproject_position(Vector3(0,0,0)) / game.farm_viewport.get_visible_rect().size
			check(center.x > .2 and center.x < .8 and center.y > .2 and center.y < .8,"the island remains centred after fresh Walk")
			if attempt == 0: await capture_view("fresh-farm-" + str(size.x))
			game.hud.close_panel()
			game.state.tutorial_progress.step = 5
			game.tutorial._enter_step()
			check(game.tutorial.current_id() == "grow", "returning farm retains the guided growing step")
			var home: Vector3 = game._camera_home_position
			# A returning farmer may have panned before the title. Home must stay
			# the overview, while Continue restores that farmer's actual view.
			camera.global_position += Vector3(2,0,1)
			game._stop_map_navigation()
			var returning_camera: Transform3D = camera.transform
			var returning_pan: Vector3 = game._camera_pan_offset
			game._show_title(true)
			game.title_scene.advance(6)
			root.focus_exited.emit()
			root.size_changed.emit()
			check(game._camera_pan_offset.is_equal_approx(returning_pan), "title focus and resize cannot become farm navigation")
			game.title_scene.walk.pressed.emit()
			for frame in range(60): game._process(1.0/60.0)
			check(camera.transform.is_equal_approx(returning_camera), "Continue stays on the island after title focus and resize at " + str(size))
			check(game._camera_home_position.is_equal_approx(home), "Continue does not promote a saved pan into the Home overview")
			center = camera.unproject_position(Vector3.ZERO) / game.farm_viewport.get_visible_rect().size
			check(center.x > .2 and center.x < .8 and center.y > .2 and center.y < .8, "returning growing farm stays centred on its first entry")
			check(not game.hud._tutorial_card.get_global_rect().intersects(game.hud._weather_button.get_global_rect()), "guided growing card leaves Weather clear at " + str(size))
			if attempt == 0: await capture_view("returning-farm-" + str(size.x))
			game.queue_free()
			for frame in range(6): await process_frame
	print("TITLE LAUNCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
