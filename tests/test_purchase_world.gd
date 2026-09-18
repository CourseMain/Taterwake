extends SceneTree
## Standalone world fixture; never loads or writes the player's farm.
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

func expect_pick(world: Node3D, point: Vector3, station: String, description: String) -> void:
	var screen: Vector2 = world.camera.unproject_position(point)
	var hit: Dictionary = world.pick(screen)
	check(str(hit.get("station", "")) == station, "%s: expected %s at %s, got %s" % [description, station, screen, hit])

func shot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "captured " + filename)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var world := World.new()
	root.add_child(world)
	for island in [1, 2, 3]:
		world.build_world(island)
		await physics_frame
		await physics_frame
		var shop: Node3D = world.get_node("IceForge" if island == 3 else "ToolUpgradeWorkshop")
		var smith: Node3D = shop.get_node("PotatoToolsmith")
		check(world._toolsmiths.size() == 1, "one toolsmith on island %d, including after travel" % island)
		check(smith.visible and smith.get_child_count() > 0, "island %d has a visible dressed potato toolsmith" % island)
		var tool_labels: Array[Node] = []
		for label: Label3D in shop.find_children("*", "Label3D", true, false):
			if label.text.begins_with("TOOL UPGRADES"):
				tool_labels.append(label)
		check(tool_labels.size() == 1, "island %d has one clear tool-upgrade sign" % island)
		var default_zoom: float = world.camera.size
		for zoom: float in [default_zoom, 18.0, 74.0 if island == 3 else (64.0 if island == 2 else 56.0)]:
			world.camera.size = zoom
			expect_pick(world, shop.global_position + Vector3(0, 1.2, 0.5), "tools", "island %d workshop, zoom %.0f" % [island, zoom])
			expect_pick(world, smith.global_position + Vector3(0, 1.25, 0.35), "tools", "island %d toolsmith face, zoom %.0f" % [island, zoom])
			expect_pick(world, smith.global_position + Vector3(0.25, 0.18, 0.1), "tools", "island %d toolsmith boots, zoom %.0f" % [island, zoom])
			expect_pick(world, world._duck_home + Vector3(0, 0.9, 0.25), "duck_patrol", "island %d duck coop, zoom %.0f" % [island, zoom])
			expect_pick(world, world._duck_label.global_position, "duck_patrol", "island %d duck sign, zoom %.0f" % [island, zoom])
			for label: Label3D in tool_labels:
				expect_pick(world, label.global_position, "tools", "island %d tool sign, zoom %.0f" % [island, zoom])
		world.camera.size = default_zoom
		if island == 2:
			expect_pick(world, world.get_node("BuyerContracts").global_position + Vector3(0, 1.5, 0.3), "activities", "island 2 buyer keeps its own contract interaction")
		if island == 3:
			expect_pick(world, world.get_node("FrostFurnace").global_position + Vector3(0, 1.4, 0.3), "activities", "island 3 furnace keeps its own activity interaction")
		for index in range(world.plot_positions.size()):
			var hit: Dictionary = world.pick(world.camera.unproject_position(world.plot_positions[index]))
			check(int(hit.get("plot_index", -1)) == index, "island %d plot %d remains selectable past new workshop" % [island, index])
		world.animate(0.25, false)
		await shot("tool-stations-island-%d" % island)
		if capture:
			world.camera.size = 9.5
			world.camera.position = shop.global_position + Vector3(5.5, 6.5, 9)
			world.camera.look_at(shop.global_position + Vector3(0, 1.2, 0))
			await shot("toolsmith-closeup-island-%d" % island)
	world.queue_free()
	await process_frame
	print("PURCHASE WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
