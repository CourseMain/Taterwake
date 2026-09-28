extends SceneTree
## Structural rendering regression checks. No player saves.
const World = preload("res://scripts/farm_world.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := World.new()
	root.add_child(world)
	for island in [1]:
		world.build_world()
		check(world.find_children("CompiledGeometry*", "MeshInstance3D", true, false).size() > 30, "island %d compiles static geometry into shared-colour surfaces" % island)
		var plots: Array = []
		for index: int in range(world.plot_positions.size()):
			plots.append({"unlocked": true, "stage": 3, "crop": "russet", "tilled": true, "watered": true, "pests": true})
		world.update_plots(plots)
		check(world._crop_tubers[0].node.find_children("CompiledGeometry*", "MeshInstance3D", false, false).size() == 1, "all crop colours share one compiled surface within the growing plant")
		check(world._pest_roots[0].get_child_count() == 3, "three beetle parents remain independently animated")
		var meshes: int = world.find_children("*", "MeshInstance3D", true, false).size()
		world.update_plots(plots)
		check(world.find_children("*", "MeshInstance3D", true, false).size() == meshes, "unchanged plots reuse their geometry")
		world.animate(0.5, false)
		for collection: Array in [world._soil_meshes, world._snowflakes]:
			for node: Node3D in collection:
				check(is_instance_valid(node) and node.is_inside_tree(), "runtime mesh reference remains live")
		world.set_tutorial_focus("market")
		world.animate(0.1, true)
		check(world._tutorial_marker.visible and world._tutorial_trail.size() == 6, "tutorial market guide keeps its scene roots")
		await physics_frame
		await physics_frame
		check(int(world.pick(world.camera.unproject_position(world.plot_positions[4])).get("plot_index", -1)) == 4, "batched infested crops retain exact plot picking")
		var farm = preload("res://scripts/game_state.gd").new()
		var weather: Dictionary = farm.climate_info()
		weather.operations.ice["4"] = true
		weather.phase = "active"
		weather.event = "freeze"
		weather.severity = 1.0
		world.set_climate(weather)
		check(world._ice_roots[4].visible and not world._ice_roots[4].get_children().is_empty(), "Valley freeze ice stays visible after batching")
		world.set_climate(farm.climate_info())
		farm.free()
		check(not world._ice_roots[4].visible, "cleared climate ice disappears immediately")
		for plot: Dictionary in plots:
			plot.pests = false
			plot.stage = 0
		world.update_plots(plots)
		world.animate(0.1, false)
		check(world._crop_roots[4].rotation.is_zero_approx() and world._pest_labels[4].scale.is_equal_approx(Vector3.ONE), "clearing pests resets animated crop and warning transforms")
	world.queue_free()
	await process_frame
	print("WORLD RENDERING OPTIMIZATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
