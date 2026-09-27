extends SceneTree
## Save-free visual consequences: real transactions drive pooled world props.
const World = preload("res://scripts/farm_world.gd")
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
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

func visible_loads(profession: Node3D) -> int:
	var count: int = 0
	for crate in profession.workshop_loads:
		if crate.is_visible_in_tree(): count += 1
	return count

func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	var builds = Builds.new()
	builds.state = farm
	farm.build_system = builds
	root.add_child(builds)
	farm.reset_game()
	var world := World.new()
	root.add_child(world)
	world.build_world(1)
	var profession = world.profession_world
	profession.refresh(builds, farm)
	check(visible_loads(profession) == 0 and not profession.buyer.visible, "idle farm has no imaginary loaded orders or buyers")
	var baseline: int = world.find_children("*", "", true, false).size()
	for id in builds.IDS: builds.levels[id] = 20
	farm.storage.russet = 100
	builds.select_build("industrialist")
	builds.professions.load_batch()
	profession.refresh(builds, farm)
	check(visible_loads(profession) == 1, "loading crops places one crate beside the workshop")
	builds.professions.load_batch()
	builds.professions.load_batch()
	profession.refresh(builds, farm)
	check(visible_loads(profession) == 3, "active batch and two queued batches each have a crate")
	world.set_processing(true, .2)
	world.animate(4.0, false)
	await capture(world, world.get_node("WashAndSortWorkshop").position, "identity-workshop")
	builds.update(100)
	profession.refresh(builds, farm)
	check(visible_loads(profession) == 0, "finished processing clears the loading area")
	builds.select_build("investor")
	builds.professions.reserve()
	profession.refresh(builds, farm)
	check(profession.buyer.visible and profession.buyer_expected, "reserving a quote brings a buyer onto the ferry path")
	profession.animate(3.0)
	var midway: Vector3 = profession.buyer.position
	profession.refresh(builds, farm)
	check(profession.buyer.position == midway, "state refresh does not teleport an arriving buyer")
	profession.animate(3.0)
	check(profession.buyer.position.is_equal_approx(profession.buyer_route.back()), "buyer arrives at the trading board")
	await physics_frame
	await physics_frame
	var hit: Dictionary = world.pick(world.camera.unproject_position(profession.buyer.position + Vector3(0,1,0)))
	check(hit.get("station", "") == "profession:investor", "arriving buyer opens the existing shipment action")
	await capture(world, profession.props.investor.position, "identity-buyer", 8.0)
	farm.storage.russet = 100
	builds.professions.deliver()
	profession.refresh(builds, farm)
	check(not profession.buyer_expected and profession.buyer_label.text == "All counted.", "a completed shipment sends the buyer home")
	profession.animate(6.0)
	check(not profession.buyer.visible, "buyer leaves after delivery")
	builds.professions.reserve()
	profession.refresh(builds, farm)
	profession.animate(6.0)
	builds.professions.update(181.0)
	profession.refresh(builds, farm)
	check(not profession.buyer_expected and profession.buyer_label.text == "Offer's gone.", "expired quote sends the buyer away without claiming a delivery")
	profession.animate(6.0)
	check(not profession.buyer.visible, "expired buyer has no lingering avatar")
	check(world.find_children("*", "", true, false).size() == baseline, "orders and buyer journeys reuse their scene nodes")
	# Loaded contract belongs to its actual island, including after rebuilding.
	builds.professions.reserve()
	for island in [1,2,3]:
		world.build_world(island)
		world.profession_world.refresh(builds, farm)
		check(world.profession_world.buyer.visible == (island == 1), "buyer waits only on the contracted island %d" % island)
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
	builds.queue_free()
	await process_frame
	print("VILLAGE IDENTITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
