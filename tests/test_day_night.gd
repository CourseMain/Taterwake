extends SceneTree
## The sky is a seasonal labour clock. All state and captures are disposable.
const World = preload("res://scripts/farm_world.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle_sun(world) -> void:
	world._animate_sun(3.0)
	world._animate_sun(0.4)
func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.set_day_time(75)
	world.build_world()
	check(world.day_cycle_info().duration == 150 and world.day_cycle_info().phase == 0.5, "saved mid-season time restores before world construction")
	var environment_id: int = world._day_environment.get_instance_id()
	var sun_id: int = world._sun.get_instance_id()
	var children: int = world.get_child_count()
	var previous: float = 0.25
	var previous_color: Color
	for step in range(151):
		world.set_day_time(step)
		var light: float = world.day_cycle_info().daylight
		check(light >= previous - 0.00001 if step <= 75 else light <= previous + 0.00001, "sun rises then falls across working season")
		var color: Color = world._day_environment.background_color
		if step > 0: check(Vector3(color.r, color.g, color.b).distance_to(Vector3(previous_color.r, previous_color.g, previous_color.b)) < 0.04, "seasonal sky changes smoothly")
		previous = light
		previous_color = color
	check(world.day_cycle_info().phase == 1 and is_equal_approx(previous, 0.25), "season ends at dusk without wrapping to morning")
	check(world._day_environment.ambient_light_energy >= 0.35 and world._sun.light_energy > 0, "dusk remains readable for the final harvest")
	check(world._day_environment.get_instance_id() == environment_id and world._sun.get_instance_id() == sun_id and world.get_child_count() == children, "sky changes reuse existing lights and environment")
	world.set_day_time(0)
	settle_sun(world)
	var dawn: Vector3 = world._sun.rotation_degrees
	world.set_day_time(75)
	settle_sun(world)
	var noon: Vector3 = world._sun.rotation_degrees
	world.set_day_time(150)
	settle_sun(world)
	check(dawn.y < noon.y and noon.y < world._sun.rotation_degrees.y and noon.x < dawn.x, "sun direction shows progress from dawn through noon to dusk")
	check(dawn.is_equal_approx(Vector3(-40,160,0)) and noon.is_equal_approx(Vector3(-60,180,0)) and world._sun.rotation_degrees.is_equal_approx(Vector3(-40,200,0)), "working-season arc has the requested bounds")
	for invalid in [NAN, INF, -1.0]:
		world.set_day_time(invalid)
		check(world.day_cycle_info().phase == 1, "invalid time cannot corrupt lighting")
	world.set_day_time(0, true)
	settle_sun(world)
	check(world.day_cycle_info().phase == 0, "Winter starts at dawn instead of holding at dusk")
	var winter_dawn: Vector3 = world._sun.rotation_degrees
	world.set_day_time(75, true)
	settle_sun(world)
	check(world.day_cycle_info().phase == 0.5 and world._sun.rotation_degrees.x > noon.x and world._sun.rotation_degrees.y > winter_dawn.y, "Winter sun moves across a lower arc")
	check(winter_dawn.is_equal_approx(Vector3(-30,160,0)) and world._sun.rotation_degrees.is_equal_approx(Vector3(-55,180,0)), "Winter has a 30 degree floor and 55 degree peak")
	check(world._sun.light_color.b > 0.95 and world._sun.light_energy < 0.65, "Winter sunlight is pale and weaker")
	world.set_day_time(150, true)
	settle_sun(world)
	check(world.day_cycle_info().phase == 1 and world._sun.rotation_degrees.y > winter_dawn.y, "Winter reaches dusk at the season end")
	check(world._winter_cover.visible and world._snowflakes.size() == 16, "Winter builds accumulated snow and falling flakes")
	var flake_y: float = world._snowflakes[0].position.y
	world._process(0.1)
	check(world._snowflakes[0].position.y != flake_y, "Winter snowfall animates independently of paused farm time")
	world.set_day_time(0, false)
	check(not world._winter_cover.visible and world.day_cycle_info().phase == 0, "next Spring reveals the Valley at dawn")
	settle_sun(world)
	world._sun_step_elapsed = 0.0
	var held: Vector3 = world._sun.rotation_degrees
	world.set_day_time(75)
	var sky_at_noon: Color = world._day_environment.background_color
	world._animate_sun(2.99)
	check(world._sun.rotation_degrees.is_equal_approx(held), "sun direction is held between three-second steps")
	world.set_day_time(76)
	check(world._day_environment.background_color != sky_at_noon, "sky still follows continuous calendar time")
	world._animate_sun(0.02)
	check(world._sun.rotation_degrees.is_equal_approx(held), "new sun target begins without a jump")
	world._animate_sun(0.2)
	check(not world._sun.rotation_degrees.is_equal_approx(held) and not world._sun.rotation_degrees.is_equal_approx(world._sun_target), "sun eases between poses")
	world._animate_sun(0.2)
	check(world._sun.rotation_degrees.is_equal_approx(world._sun_target), "sun arrives after 0.4 seconds")
	world.set_day_time(77)
	var writes: int = world.lighting_updates
	for i in range(5): world.set_day_time(77.0+float(i)*.016)
	check(world.lighting_updates==writes and world.day_cycle_info().seconds>77,"fractional clock advances without rewriting the environment every frame")
	world.set_day_time(77.12)
	check(world.lighting_updates==writes+1,"lighting refreshes at a tenth of a simulated second")
	if "--capture" in OS.get_cmdline_user_args():
		for moment in [0, 75, 150]:
			world.set_day_time(moment)
			settle_sun(world)
			await create_timer(0.2).timeout
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/season-sky-%d.png" % moment)
	world.queue_free()
	await process_frame
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.season_clock.seconds = 74
	game.state.elapsed = 3000
	game._process(1)
	check(game.world.day_cycle_info().seconds == 75 and game.world.day_cycle_info().daylight == 1, "main reads season time rather than cumulative elapsed time")
	check(game.state._valid_save(JSON.parse_string(JSON.stringify(game.state._save_data()))), "fractional calendar persists in the current schema")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("SEASON SKY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
