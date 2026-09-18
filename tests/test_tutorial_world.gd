extends SceneTree
## Standalone world fixture; never loads or writes the player's farm.
const World = preload("res://scripts/farm_world.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func shot(filename: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "captured " + filename)

func _run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build_world(1)
	check(not world._tutorial_marker.visible, "normal farming has no tutorial marker")
	var visible_signs: int = 0
	for layer: Node3D in world._tutorial_label_layers:
		visible_signs += int(layer.is_visible_in_tree())
	check(visible_signs >= 9, "normal farm retains its station and island signs")
	world.set_tutorial_focus("")
	var hidden_signs: int = 0
	for layer: Node3D in world._tutorial_label_layers:
		hidden_signs += int(not layer.is_visible_in_tree())
	check(hidden_signs == visible_signs and not world._tutorial_marker.visible, "opening tutorial hides station clutter without an extra marker")
	for station: String in ["market", "barn", "tools", "roll", "builds", "duck_patrol", "quests", "island"]:
		world.set_tutorial_focus(station)
		check(world._tutorial_marker.visible and world._tutorial_marker.text.length() > 1, "%s gets one named destination marker" % station)
		var point: Vector3 = world.station_position(station)
		check(is_equal_approx(point.x, world._tutorial_marker.position.x) and is_equal_approx(point.z, world._tutorial_marker.position.z), "%s marker points at its station" % station)
	check(world.station_position("island").is_equal_approx(Vector3(11.5, 0.0, -14.0)), "ferry guidance points to reachable dock, not offshore miniature")
	world.set_tutorial_focus("market")
	var marker_y: float = world._tutorial_marker.position.y
	world.animate(0.3, false)
	check(absf(world._tutorial_marker.position.y - marker_y) > 0.01, "destination marker gently bobs")
	await shot("tutorial-marker-market")
	world.set_tutorial_focus("plot:4")
	check(world._tutorial_marker.visible and is_equal_approx(world._tutorial_marker.position.x, world.plot_positions[4].x) and is_equal_approx(world._tutorial_marker.position.z, world.plot_positions[4].z), "crop and pest lessons can mark the real target plot")
	check(world._tutorial_plot_outline.visible and world._tutorial_plot_outline.position.is_equal_approx(world.plot_positions[4]), "clear ground outline surrounds the exact lesson bed")
	check(world._tutorial_marker.position.y < 2.0 and world._tutorial_marker.font_size >= 60, "large plot arrow sits close to its outlined bed")
	await shot("tutorial-marker-plot")
	world.set_day_time(30.0)
	await shot("tutorial-marker-plot-night")
	for invalid: String in ["plot:-1", "plot:999", "plot:nope", "missing_station"]:
		world.set_tutorial_focus(invalid)
		check(not world._tutorial_marker.visible and not world._tutorial_plot_outline.visible, "invalid focus %s leaves no misleading marker" % invalid)
	world.set_tutorial_focus("duck_patrol")
	world.set_activity_state({"unlocked": true, "active": true})
	check(not world._duck_label.is_visible_in_tree(), "live station status refresh cannot restore distracting signs")
	world._roll_label.visible = false
	world.set_tutorial_focus("", true)
	check(world._duck_label.is_visible_in_tree() and not world._roll_label.is_visible_in_tree(), "ending tutorial restores labels without overriding their own visibility")
	check(not world._tutorial_marker.visible and not world._tutorial_plot_outline.visible, "ending tutorial removes guide marker and target outline")
	world.set_tutorial_focus("market")
	world.build_world(1)
	check(world._tutorial_marker.visible and world._tutorial_focus == "market", "world rebuild retains active lesson guidance")
	for layer: Node3D in world._tutorial_label_layers:
		check(not layer.is_visible_in_tree(), "rebuild keeps unintroduced signs hidden")
	world.set_tutorial_focus("", true)
	world.switch_island(2)
	check(not world._tutorial_marker.visible and world._duck_label.is_visible_in_tree(), "normal travel restores normal island appearance")
	world.queue_free()
	await process_frame
	print("TUTORIAL WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
