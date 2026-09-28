extends SceneTree
## Village stalls retain their charm and leave every bed clickable.
const World = preload("res://scripts/farm_world.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func capture(world: Node3D, at: Vector3, filename: String, size: float = 11.0) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	var previous: Transform3D = world.camera.transform
	var previous_size: float = world.camera.size
	world.camera.size = size
	world.camera.position = at + Vector3(5.5, 6.0, 9.0)
	world.camera.look_at(at + Vector3(0, 1.0, 0))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
	world.camera.transform = previous
	world.camera.size = previous_size

func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	farm.reset_game()
	var world := World.new()
	root.add_child(world)
	for island in [1]:
		world.build_world()
		var stall: Node3D = world.get_node("MarketStall")
		var details: Node3D = stall.get_node("MaraRepairs")
		check(details.find_children("CompiledGeometry*", "MeshInstance3D", true, false).size() >= 5, "Mara's repair details compile on island %d" % island)
		await physics_frame
		await physics_frame
		check(world.pick(world.camera.unproject_position(stall.to_global(Vector3(0,1.6,1.3)))).get("station", "") == "market", "Mara's counter remains clickable on island %d" % island)
		for index in range(world.plot_positions.size()):
			check(world.pick(world.camera.unproject_position(world.plot_positions[index])).get("plot_index", -1) == index, "village details preserve island %d bed %d picking" % [island,index])
		await capture(world, stall.position, "identity-mara-%d" % island)
	world.queue_free()
	farm.queue_free()
	await process_frame
	print("VILLAGE IDENTITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
