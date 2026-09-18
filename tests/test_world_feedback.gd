extends SceneTree
## Isolated world rendering: no farm save is read or written.
const World = preload("res://scripts/farm_world.gd")
var checks: int = 0
var failures: int = 0
var warnings: Array = []
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
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "rendered " + filename)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var world := World.new()
	root.add_child(world)
	world.build_world(3)
	world.pest_warning.connect(func(index: int, destroyed: bool): warnings.append([index, destroyed]))
	var plots: Array = []
	for index in range(80):
		plots.append({"unlocked": true, "stage": 3, "crop": "icecap", "tilled": true, "watered": true, "pests": index in [3, 17, 25, 36, 44, 58, 62, 76], "pest_ticks": 0, "pest_damage": 0.0, "frozen": index in [3, 17, 25, 36]})
	world.update_plots(plots)
	await physics_frame
	await physics_frame
	check(warnings.size() == 8, "new infestations emit warning audio signal once each")
	check(world._pest_labels[3].text == "! PESTS\nYIELD 3/3", "start of attack visibly shows full original yield")
	check(world._pest_roots[3].get_child_count() == 3, "three recognizable animated beetles per infested bed")
	world.animate(0.15, false)
	check(absf(world._crop_roots[3].rotation.z) > 0.01, "infested crops visibly shake")
	world.update_plots(plots)
	check(warnings.size() == 8, "redraw does not repeat warning audio")
	for index in [17, 25, 36]:
		plots[index]["pest_ticks"] = 1 if index == 17 else 2
		plots[index]["pest_damage"] = float(plots[index]["pest_ticks"]) / 3.0
	world.update_plots(plots)
	check(world._pest_labels[17].text.ends_with("2/3"), "first damage tick visibly shows two thirds")
	check(world._pest_labels[25].text.ends_with("1/3"), "second damage tick visibly shows one third")
	check(world._effect_particles.size() == 18, "damage ticks create bounded bite debris")
	for index in range(80):
		var hit: Dictionary = world.pick(world.camera.unproject_position(world.plot_positions[index]))
		check(int(hit.get("plot_index", -1)) == index, "pest indicators preserve winter ray target %d" % index)
	check(world._ice_roots[3].visible and world._pest_roots[3].visible, "ice and pests are independently visible")
	await shot("world-pest-yield-stages")
	plots[17]["pests"] = false
	world.update_plots(plots)
	check(not world._pest_roots[17].visible and world._ice_roots[17].visible, "clearing pests leaves frozen layer intact")
	check(world._crop_roots[17].rotation == Vector3.ZERO, "clearing pests stops crop shake")
	check(world._pest_labels[17].text == "YIELD 2/3", "remaining damage is visible after pests are brushed away")
	plots[25].merge({"stage": 0, "pests": false, "pest_ticks": 3, "pest_damage": 1.0, "pest_destroyed": true}, true)
	world.update_plots(plots)
	check(world._pest_labels[25].text == "CROP LOST", "destruction briefly announces the lost crop")
	check(warnings.back() == [25, true], "destruction emits a distinct sound signal")
	check(not world._pest_roots[25].visible, "destroyed crops do not retain an active pest swarm")
	await shot("world-pest-destroyed")
	world.animate(4.1, false)
	check(world._pest_labels[25].text.is_empty() and not world._pest_labels[25].visible, "destruction label fully disappears instead of leaving a zero-yield marker")
	world.update_plots(plots)
	check(not world._pest_labels[25].visible, "state refresh cannot resurrect the expired destroyed-crop label")
	plots[25].merge({"stage": 1, "pests": false, "pest_ticks": 0, "pest_damage": 0.0, "pest_destroyed": false}, true)
	world.update_plots(plots)
	check(not world._pest_labels[25].visible, "replanting clears destroyed marker")
	for island in [1, 2, 3]:
		world.switch_island(island)
		world.play_reward("jackpot")
		world.animate(2.0, false)
		check(world._effect_particles.size() == 44, "major island %d reward remains visible for longer than two seconds" % island)
		await shot("world-reward-island-%d" % island)
		world.animate(2.0, false)
		await process_frame
		check(world._effect_particles.is_empty(), "reward particles expire cleanly on island %d" % island)
	world.queue_free()
	await process_frame
	print("WORLD FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
