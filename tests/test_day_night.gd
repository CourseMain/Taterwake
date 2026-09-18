extends SceneTree
## A standalone farm fixture: never reads or writes the player's save.
const World = preload("res://scripts/farm_world.gd")
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "captured " + filename)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Use -- --integration-test to protect player saves.")
		quit(1)
		return
	var world := World.new()
	root.add_child(world)
	world.set_day_time(56.25)
	world.build_world(1)
	check(is_equal_approx(float(world.day_cycle_info().phase), 0.25), "time can be restored before the first world build")
	var environment_id: int = world._day_environment.get_instance_id()
	var sun_id: int = world._sun.get_instance_id()
	var moon_id: int = world._moon.get_instance_id()
	var child_count: int = world.get_child_count()
	var last_daylight: float = 1.0
	var last_color: Color
	var monotonic_daylight: bool = true
	var continuous_sky: bool = true
	for step in range(181):
		world.set_day_time(float(step) * 0.125)
		var daylight: float = world.day_cycle_info().daylight
		monotonic_daylight = monotonic_daylight and daylight <= last_daylight + 0.00001
		if step > 0:
			var color: Color = world._day_environment.background_color
			continuous_sky = continuous_sky and absf(color.r - last_color.r) < 0.025 and absf(color.g - last_color.g) < 0.025 and absf(color.b - last_color.b) < 0.025
		last_daylight = daylight
		last_color = world._day_environment.background_color
	check(monotonic_daylight, "daylight declines continuously until midnight across 180 transition samples")
	check(continuous_sky, "all twilight color transitions remain smooth across 180 transition samples")
	check(is_zero_approx(last_daylight), "midnight is reached at 22.5 seconds")
	check(is_zero_approx(world._sun.light_energy) and world._moon.light_energy >= 0.3, "night replaces sunlight with readable moonlight")
	check(world._day_environment.ambient_light_energy >= 0.35, "night retains ambient light for farming")
	check(world._day_environment.get_instance_id() == environment_id and world._sun.get_instance_id() == sun_id and world._moon.get_instance_id() == moon_id and world.get_child_count() == child_count, "frame updates reuse the same environment and lights")
	world.set_day_time(0.0)
	var noon_sky: Color = world._day_environment.background_color
	var noon_rotation: Vector3 = world._sun.rotation
	world.set_day_time(45.0)
	check(world._day_environment.background_color.is_equal_approx(noon_sky) and world._sun.rotation.is_equal_approx(noon_rotation), "one complete loop returns to matching midday light and sun direction")
	world.set_day_time(45.0 - 0.001)
	var before_wrap: Color = world._day_environment.background_color
	var before_rotation: Vector3 = world._sun.rotation
	world.set_day_time(45.0 + 0.001)
	check(world._day_environment.background_color.is_equal_approx(before_wrap) and world._sun.rotation.distance_to(before_rotation) < 0.001, "loop boundary remains smooth")
	world.set_day_time(45.0 * 20000.0 + 11.25)
	check(is_equal_approx(float(world.day_cycle_info().phase), 0.25), "long-running saves retain an accurate cycle")
	for invalid_time in [NAN, INF, -1.0]:
		world.set_day_time(invalid_time)
		check(is_equal_approx(float(world.day_cycle_info().phase), 0.25), "invalid time cannot corrupt light properties")
	var dusk_colors: Array[Color] = []
	for island in [1, 2, 3]:
		world.set_day_time(11.25)
		world.switch_island(island)
		check(is_equal_approx(float(world.day_cycle_info().phase), 0.25), "island %d travel keeps the saved cycle phase" % island)
		dusk_colors.append(world._day_environment.background_color)
		var forbidden_title: bool = false
		var has_barn: bool = false
		var has_navigation: bool = false
		for label in world.find_children("*", "Label3D", true, false):
			for title in ["ICECAP FIELDS", "SUNBURST FIELDS", "THE POTATO PATCH"]:
				forbidden_title = forbidden_title or title in label.text
			has_barn = has_barn or "BARN" in label.text
			has_navigation = has_navigation or "RETURN" in label.text or "LOCKED" in label.text
		check(not forbidden_title, "island %d removes floating decorative field titles" % island)
		check(has_barn and has_navigation, "island %d retains functional station and travel labels" % island)
		var plots: Array = []
		for index in range(world.plot_positions.size()):
			plots.append({"unlocked": true, "stage": 3, "crop": "icecap" if island == 3 else ("sunburst" if island == 2 else "russet"), "tilled": true, "watered": true, "pests": index == 4, "pest_ticks": 0, "pest_damage": 0.0, "frozen": island == 3 and index == 5})
		world.update_plots(plots)
		for moment in [{"name": "day", "time": 0.0}, {"name": "dusk", "time": 11.25}, {"name": "night", "time": 22.5}]:
			world.set_day_time(moment.time)
			await shot("day-cycle-island-%d-%s" % [island, moment.name])
		await physics_frame
		await physics_frame
		var hit: Dictionary = world.pick(world.camera.unproject_position(world.plot_positions[4]))
		check(int(hit.get("plot_index", -1)) == 4, "nighttime pest plot remains selectable on island %d" % island)
		check(world._pest_roots[4].visible and world._pest_labels[4].visible, "nighttime pest feedback remains visible on island %d" % island)
	check(not dusk_colors[0].is_equal_approx(dusk_colors[1]) and not dusk_colors[1].is_equal_approx(dusk_colors[2]), "all three islands retain distinct dusk palettes")
	world.queue_free()
	await process_frame
	await _check_main_integration()
	print("DAY / NIGHT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_main_integration() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.test_mode, "real main scene uses the isolated test farm")
	game.state.elapsed = 22.5
	game._process(0.125)
	check(is_equal_approx(float(game.world.day_cycle_info().seconds), 22.625), "main updates the sky directly from the live state clock")
	check(float(game.world.day_cycle_info().daylight) < 0.001, "main integration actually renders nighttime at the saved midnight phase")
	var save_data: Dictionary = game.state._save_data()
	var restored: Dictionary = JSON.parse_string(JSON.stringify(save_data))
	check(game.state._valid_save(restored) and is_equal_approx(float(restored.elapsed), 22.625), "existing save schema preserves fractional day phase without new mandatory fields")
	game.state.current_island = 2
	game.state.island2_unlocked = true
	game._on_island_changed(2)
	check(is_equal_approx(float(game.world.day_cycle_info().seconds), float(restored.elapsed)), "real island travel reapplies the same saved day phase")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
