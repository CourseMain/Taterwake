extends SceneTree
## Native Compatibility fixture; no GameState/save access and no browser FPS claim.
## --disable-render-loop --script tests/benchmark_shadow_modes.gd -- --integration-test --mode=balanced
## Optional --source=/absolute/old_farm_world.gd captures an original snapshot.
var mode: String = "balanced"
var world_script: Script = preload("res://scripts/farm_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--source="): world_script = load(arg.trim_prefix("--source="))
	root.size = Vector2i(1280, 800)
	root.msaa_3d = Viewport.MSAA_2X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world = world_script.new()
	root.add_child(world)
	if world.has_method("set_graphics_quality"):
		world.set_graphics_quality(mode)
	world.build_world(2)
	var plots: Array = []
	for index: int in range(world.plot_positions.size()):
		plots.append({"unlocked": true, "stage": 3, "crop": "sunburst", "watered": true, "tilled": true})
	world.update_plots(plots)
	for frame: int in range(20):
		world.set_day_time(14.5)
		RenderingServer.force_draw(false, 1.0 / 60.0)
		await process_frame
	var samples: Array[float] = []
	var draw_calls: int = 0
	for frame: int in range(90):
		var start: int = Time.get_ticks_usec()
		world.set_day_time(14.5 + frame / 60.0)
		world.animate(1.0 / 60.0, false)
		RenderingServer.force_draw(false, 1.0 / 60.0)
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort()
	var result: Dictionary = {"mode": mode, "island": 2, "field": "48 ripe sunburst beds", "renderer": RenderingServer.get_video_adapter_name(), "resolution": "1280x800", "msaa": "2x", "samples": 90, "draw_calls_mean": draw_calls / 90.0, "native_fixture_median_ms": samples[45], "native_fixture_p95_ms": samples[85]}
	print("SHADOW_BENCHMARK " + JSON.stringify(result))
	var output := FileAccess.open("res://artifacts/shadow-modes-%s.json" % mode, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	for shot: Dictionary in [{"name": "noon", "time": 0.0, "zoom": 43.0}, {"name": "dusk", "time": 15.0, "zoom": 43.0}, {"name": "wide", "time": 15.0, "zoom": 64.0}, {"name": "night", "time": 30.0, "zoom": 43.0}]:
		world.camera.size = shot.zoom
		world.set_day_time(shot.time)
		await process_frame
		RenderingServer.force_draw(false, 0.0)
		root.get_texture().get_image().save_png("res://artifacts/shadow-modes-%s-%s.png" % [mode, shot.name])
	world.queue_free()
	await process_frame
	quit()
