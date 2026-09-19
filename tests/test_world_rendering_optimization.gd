extends SceneTree
## Structural rendering regression checks. No GameState or player saves.
const World = preload("res://scripts/farm_world.gd")
const Rocket = preload("res://scripts/stock_rocket_cutscene.gd")
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
	for island: int in [1, 2, 3]:
		world.build_world(island)
		check(world.find_children("*", "MultiMeshInstance3D", true, false).size() > 100, "island %d batches repeated static geometry" % island)
		var plots: Array = []
		for index: int in range(world.plot_positions.size()):
			plots.append({"unlocked": true, "stage": 3, "crop": "icecap" if island == 3 else "russet", "tilled": true, "watered": true, "pests": true, "frozen": island == 3})
		world.update_plots(plots)
		check(world._crop_roots[0].find_children("*", "MultiMeshInstance3D", false, false).size() >= 6, "crop geometry is batched within its shaking parent")
		check(world._pest_roots[0].get_child_count() == 3, "three beetle parents remain independently animated")
		var meshes: int = world.find_children("*", "MeshInstance3D", true, false).size()
		world.update_plots(plots)
		check(world.find_children("*", "MeshInstance3D", true, false).size() == meshes, "unchanged plots reuse their geometry")
		world.set_processing(true, 0.5)
		world.set_export_state(true, 10.0)
		world.set_roll_available(false)
		world.animate(0.5, false)
		check(world._processing_light.material_override.albedo_color.is_equal_approx(Color("bade87").srgb_to_linear()), "processing light retains its mutable mesh")
		check(world._processing_potatoes[0].visible and world._processing_steam[0].visible, "moving conveyor produce and steam remain available")
		check(not world._rare_gem.visible and world._roll_gate.visible, "batched child geometry still follows gate and gem visibility")
		for collection: Array in [world._soil_meshes, world._snowflakes, world._processing_potatoes, world._processing_steam, world._furnace_steam, world._export_flags]:
			for node: Node3D in collection:
				check(is_instance_valid(node) and node.is_inside_tree(), "runtime mesh reference remains live")
		world.set_tutorial_focus("island")
		world.animate(0.1, true)
		check(world._tutorial_marker.visible and world._tutorial_trail.size() == 6, "tutorial ferry guide keeps its scene roots")
		await physics_frame
		await physics_frame
		check(int(world.pick(world.camera.unproject_position(world.plot_positions[4])).get("plot_index", -1)) == 4, "batched infested crops retain exact plot picking")
		if island == 3:
			check(world._ice_roots[4].visible and not world._ice_roots[4].get_children().is_empty(), "frozen crop ice is visible after batching")
		for plot: Dictionary in plots:
			plot.pests = false
			plot.stage = 0
		world.update_plots(plots)
		world.animate(0.1, false)
		check(world._crop_roots[4].rotation.is_zero_approx() and world._pest_labels[4].scale.is_equal_approx(Vector3.ONE), "clearing pests resets animated crop and warning transforms")
	var sound: AudioStreamWAV = Rocket.LAUNCH_SOUND
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(sound.data)
	check(sound.format == AudioStreamWAV.FORMAT_16_BITS and sound.mix_rate == 22050 and sound.stereo, "import keeps original uncompressed stereo PCM")
	check(hash.finish().hex_encode() == "c401ba3ac808e5b1f399c2da1985a9b0d8df8423ca379e20c5b3aaa92e888918", "baked crowded-spud launch score matches the deterministic offline PCM")
	world.queue_free()
	await process_frame
	print("WORLD RENDERING OPTIMIZATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
