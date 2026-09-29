extends SceneTree
const Surface = preload("res://scripts/farm_surface.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(note)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.tutorial_progress.completed = true
	game.hud.close_panel()
	game._on_state_changed()
	var world = game.world
	check(world.find_children("IslandTerrainShell", "MeshInstance3D", true, false).size() == 1, "one continuous island shell")
	check(world.find_children("GoldenShoresGround", "", true, false).is_empty() and world.find_children("FrosthollowGround", "", true, false).is_empty(), "no attached regional ground")
	check(Surface.half_width(0)-Surface.half_width(Surface.EXTENT.y*0.5) > 10, "coast has pronounced angled sides")
	check(is_equal_approx(Surface.half_width(10),Surface.half_width(0)-10*Surface.CUT.x/Surface.CUT.y), "hexagonal coast has straight sides")
	for entry in [[-12.9,0.8],[-13.9,1.6],[-18.0,2.4]]:
		check(is_equal_approx(Surface.height_at(0,entry[0]),entry[1]), "three distinct terrace levels")
	check(is_equal_approx(Surface.height_at(22,10),-0.15), "Low dips fifteen centimetres")
	for edge: float in Surface.STEPS:
		var before := Vector3(0,0,edge+0.3)
		var after := Surface.move(before,Vector3(0,0,edge-0.6))
		check(after.z > edge, "riser blocks direct uphill walking")
		check(Surface.move(Vector3(0,0,edge-0.6),before).z < edge, "riser blocks downhill shortcuts")
		check(Surface.move(Vector3(Surface.PATH_X,0,edge+0.3),Vector3(Surface.PATH_X,0,edge-0.6)).z < edge, "rail path crosses the terrace")
		var small_step := Vector3(0,0,edge+0.4)
		for step in range(30): small_step = Surface.move(small_step,small_step+Vector3(0,0,-0.04))
		check(small_step.z > edge-0.125, "small keyboard steps cannot climb the riser")
		var downhill := Vector3(0,0,edge-0.6)
		for step in range(30): downhill = Surface.move(downhill,downhill+Vector3(0,0,0.04))
		check(downhill.z < edge-0.125, "small keyboard steps cannot descend the riser")
		check(Surface.route(Vector3(0,0,edge-0.05),Vector3(0,0,edge-0.6)).size() == 3, "click on a half-riser still routes through stairs")
	for i in range(72):
		var point: Vector3 = world.plot_positions[i]
		check(Surface.clamp_point(point).is_equal_approx(point), "bed rests on continuous ground %d" % i)
	await physics_frame
	await physics_frame
	for x in [Surface.PATH_X-1.5,Surface.PATH_X+1.5,Surface.PATH_X]:
		for edge: float in Surface.STEPS:
			var z: float = edge+0.05
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,5,z),Vector3(x,-3,z))
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y-Surface.height_at(x,z)) < 0.001, "walking matches collision on stair shoulders")
	for index in [0,24,48]:
		var point: Vector3 = world.plot_positions[index]
		check(int(world.pick(world.camera.unproject_position(point)).get("plot_index", -1)) == index, "each field keeps its clickable beds")
		check(world._soil_meshes[index].mesh.size == Vector3(1.93,0.2,1.93), "common bed geometry")
	check(world._lease_boards.all(func(board): return board.visible), "unrented fields show To let")
	world.update_plots(game.state.plots)
	check(not world._furrow_roots[24].visible and not world._furrow_roots[48].visible, "unrented beds are rough grass")
	for size in [Vector2i(1440,900),Vector2i(390,844)]:
		root.min_size = Vector2i.ZERO
		root.size = size
		for frame in range(12): await process_frame
		game._recenter_camera()
		for frame in range(30): game._update_camera_zoom(0.1); await process_frame
		var view: Rect2 = world.camera.get_viewport().get_visible_rect()
		var sea := Plane(Vector3.UP,world.coast.WATER_Y)
		for corner in [Vector2(1,1),Vector2(view.size.x-1,1),view.size-Vector2.ONE,Vector2(1,view.size.y-1)]:
			var origin: Vector3 = world.camera.project_ray_origin(corner)
			var hit: Variant = sea.intersects_ray(origin,world.camera.project_ray_normal(corner))
			check(hit != null and origin.distance_to(hit) < world.camera.far, "portrait and desktop rays reach the ocean")
		for z in [-Surface.EXTENT.y*0.5, 0.0, Surface.EXTENT.y*0.5]:
			for x in [-Surface.half_width(z),Surface.half_width(z)]:
				check(view.has_point(world.camera.unproject_position(Vector3(x,0,z))), "default camera contains coastline at " + str(size))
		if "--capture" in OS.get_cmdline_user_args() and ((size.x < 600) == ("--touch-controls" in OS.get_cmdline_user_args())):
			for calendar in [[1,0],[1,1],[6,1]]:
				game.state.season_clock.year = calendar[0]
				game.state.season_clock.season = calendar[1]
				game.hud.update_state(game.state)
				world.set_calendar(calendar[0],calendar[1],75)
				world._process(1)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/island-year%d-season%d-%d.png" % [calendar[0],calendar[1],size.x])
	game.queue_free()
	await create_timer(0.4).timeout
	print("ISLAND LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
