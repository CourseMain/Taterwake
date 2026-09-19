extends SceneTree
## Reproducible standalone rendering fixture, never loads GameState or a save.
## Explicit draws bypass macOS occlusion throttling. Frame timings include the
## fixture loop/OS scheduling and are not browser FPS or GPU-only timings.
## godot --path . --resolution 1280x800 --disable-vsync --disable-render-loop --script tests/benchmark_world_rendering.gd -- --integration-test --capture --label=after
const World = preload("res://scripts/farm_world.gd")
var label: String = "run"
var world_script: Script = World
var capture: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--baseline-script="): world_script = load(arg.trim_prefix("--baseline-script="))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 800)
	# Pin quality so project/web quality changes cannot confound comparisons.
	root.msaa_3d = Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Array = []
	for island: int in [1, 2, 3]:
		var world = world_script.new()
		root.add_child(world)
		var begin: int = Time.get_ticks_usec()
		world.build_world(island)
		var build_ms: float = (Time.get_ticks_usec() - begin) / 1000.0
		for mode: String in ["empty", "ripe", "pests"]:
			var plots: Array = []
			for index: int in range(world.plot_positions.size()):
				plots.append({"unlocked": true, "tilled": true, "watered": true, "stage": 0 if mode == "empty" else 3, "crop": "icecap" if island == 3 else ("sunburst" if island == 2 else "russet"), "pests": mode == "pests", "pest_ticks": 0})
			begin = Time.get_ticks_usec()
			world.update_plots(plots)
			var plots_ms: float = (Time.get_ticks_usec() - begin) / 1000.0
			for frame: int in range(30):
				await process_frame
			var meshes: Dictionary = {}
			for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
				meshes[mesh.mesh.get_instance_id()] = true
			for batch: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
				meshes[batch.multimesh.mesh.get_instance_id()] = true
			var frames_ms: Array[float] = []
			var cpu_us: int = 0
			var calls: int = 0
			var objects: int = 0
			for frame: int in range(90):
				var tick: int = Time.get_ticks_usec()
				world.animate(1.0 / 60.0, false)
				world.set_day_time(frame / 60.0)
				cpu_us += Time.get_ticks_usec() - tick
				RenderingServer.force_draw(false, 1.0 / 60.0)
				await process_frame
				frames_ms.append((Time.get_ticks_usec() - tick) / 1000.0)
				calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			frames_ms.sort()
			var result: Dictionary = {"island": island, "mode": mode, "build_ms": build_ms, "plot_build_ms": plots_ms, "mesh_nodes": world.find_children("*", "MeshInstance3D", true, false).size(), "multimesh_nodes": world.find_children("*", "MultiMeshInstance3D", true, false).size(), "unique_meshes": meshes.size(), "draw_calls_mean": calls / 90.0, "render_objects_mean": objects / 90.0, "world_cpu_ms": cpu_us / 90000.0, "frame_median_ms": frames_ms[45], "frame_p95_ms": frames_ms[85]}
			results.append(result)
			print("WORLD_BENCHMARK " + JSON.stringify(result))
			if capture and mode == "ripe":
				world._time = 0.0
				world.animate(0.0, false)
				world.set_day_time(0.0)
				await process_frame
				RenderingServer.force_draw(false, 0.0)
				root.get_texture().get_image().save_png("res://artifacts/world-performance-%s-island-%d.png" % [label, island])
		world.queue_free()
		await process_frame
	var output := FileAccess.open("res://artifacts/world-performance-%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "msaa": "4x", "resolution": "1280x800", "samples_per_scenario": 90, "mode": "explicit RenderingServer.force_draw; includes fixture loop/OS scheduling, not browser FPS", "results": results}, "\t"))
	quit()
