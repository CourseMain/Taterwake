extends SceneTree
const Stock=preload("res://scripts/graded_stock.gd")
var game
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(note)
func frames(count: int=8) -> void:
	for i in range(count): await process_frame
func shot(label: String, point: Vector3=Vector3.ZERO, zoom: float=0) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	var camera: Camera3D=game.world.camera
	var transform: Transform3D=camera.transform
	var size: float=camera.size
	if zoom>0:
		camera.position=point+Vector3(14,19,25)
		camera.look_at(point)
		camera.size=zoom
	game.hud._toast_box.hide(); game.hud._purchase_box.hide()
	game.hud._climate_alert.dismiss()
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/farm-corrections-native-"+label+".png")
	camera.transform=transform; camera.size=size
func plant_colors(node: Node) -> PackedColorArray:
	var result := PackedColorArray()
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			result.append_array(mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR])
	return result
func unused_ground(w, winter: bool) -> void:
	for index in [12,24,48]:
		var patch: MeshInstance3D=w._soil_meshes[index]
		check(is_equal_approx(patch.scale.y,.12),"locked and unrented beds are flat ground patches")
		check(w._crop_roots[index].get_meta("unused_blades")== (0 if winter else 3),"unused ground has at most three thin blades, none in Winter")
		check(not w._ice_roots[index].visible,"locked and unrented beds never draw an ice glaze")
		check(not w._furrow_roots[index].visible,"unused ground never shows tilled furrows")
		var vertices:=0
		for mesh in w._crop_roots[index].find_children("*","MeshInstance3D",true,false):
			vertices+=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			check(mesh.mesh.get_aabb().size.y<.36,"unused blades stay low instead of crop-shaped tufts")
		check(vertices<=18,"unused grass contains only thin blades, without stone lumps")
		if winter:
			var color: Color=patch.material_override.albedo_color
			check(minf(color.r,minf(color.g,color.b))>.85 and absf(color.b-color.r)<.08,"unused Winter ground is near-white snow")
func plant(index: int, quality: int=100) -> void:
	var plot: Dictionary=game.state.plots[index]
	game.state._clear_crop(plot)
	plot.merge({"unlocked":true,"tilled":true,"stage":2,"crop":"russet","watered":true,"quality":quality,"elapsed":45.0},true)
func calendar(season: int) -> void:
	game.state.season_clock.season=season
	game.state.season_clock.seconds=75
	game._on_state_changed()
	game.hud.close_panel()
	game.world._process(1)
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames()
	game.set_process(false)
	game.state.tutorial_progress.completed=true
	game.state.set_tutorial_active(false)
	game.hud.close_panel()
	game.state.coins=1200000
	var w=game.world
	var art=w.visuals
	var farm=game.state
	for plot in farm.plots: farm._clear_crop(plot)
	for i in range(3): plant(i,[100,60,20][i])
	game._on_state_changed()
	game._recenter_camera()
	for i in range(30): game._update_camera_zoom(.1)
	for i in range(3):
		w.show_grade(i,farm.plots[i])
		check(art.grades[i]==farm.Quality.grade(farm.plots[i].quality) and w.grade_tag.text.ends_with(art.grades[i]),"grade marker matches hover and saved quality")
	farm.plots[0].quality=30; game._on_state_changed()
	check(art.grades[0]=="Feed","marker updates within the same crop stage")
	farm._clear_crop(farm.plots[0]); game._on_state_changed()
	check(not art.grades.has(0),"empty bed has no grade marker")
	w.grade_tag.hide()
	unused_ground(w,false)
	for season in range(4):
		calendar(season)
		check(art.snow.visible==(season==3),"snow accumulations follow Winter")
		check(w._player_body.outfit_season==season,"fixed farmer outfit follows season")
		check(w._tree_specs.all(func(tree): return tree.canopy.visible==(season!=3)),"fruit trees are bare only in Winter")
		check(art.snow.find_children("*","MeshInstance3D",true,false).size()<=30,"snow uses compiled surfaces plus bounded flakes")
		if season==3: unused_ground(w,true)
		await frames()
		var calls: int=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if DisplayServer.get_name()!="headless": check(calls<=1800,"season draw calls stay near 1538/1585 baseline: %d" % calls)
		print("FARM ART season ",season," draw calls ",calls)
		if season<3: await shot("season%d" % season)
	check(is_instance_valid(art.snow_ground) and art.snow_ground.visible,"Winter has a continuous snow ground mesh")
	check(art.snow_ground.mesh.get_aabb().size.y>2,"snow follows all three terraces rather than forming a flat sheet")
	check(is_instance_valid(art.snow_paths) and art.snow_paths.mesh.get_aabb().size.z>30,"Winter keeps the compacted path network visible")
	check(art.drift_specs.size()>0 and art.drift_specs.size()<=10,"Winter has no more than ten corner drifts")
	for drift in art.drift_specs:
		check(drift.corner in ["barn","terrace","gate"],"drifts are restricted to building, terrace and gate corners")
	# A stale saved or weather ice flag must not put glaze on unopened land.
	farm.plots[12].winter_ice=true
	farm.climate.data.operations.ice["24"]=true
	game._on_state_changed()
	unused_ground(w,true)
	farm.plots[12].winter_ice=false
	farm.climate.data.operations.ice.erase("24")
	game._on_state_changed()
	# Footprints originate only from real movement along lanes and stay bounded.
	w.player.position=Vector3(-14.7,0,15)
	for i in range(240):
		var z: float=15+(i%12)*.5
		w.set_player_position(Vector3(-14.7,0,z))
	check(art.print_count==art.PRINT_LIMIT,"Winter walking uses a bounded footprint pool")
	var prints: int=art.print_count
	art.walked(Vector3(0,0,0),Vector3(0,0,.6))
	check(art.print_count==prints,"walking off paths does not stamp road footprints")
	# Live forecast values, including the narrower upgraded interval, reach the face.
	var old_range: Vector2=w.weather_station.forecast_range
	farm.ClimateSystem.Protection.upgrade_station(farm)
	game._on_state_changed()
	var forecast: Dictionary=farm.climate_info().forecast
	check(w.weather_station.forecast_range==Vector2(forecast.low,forecast.high),"instrument displays real forecast bounds")
	check(w.weather_station.forecast_range.y-w.weather_station.forecast_range.x<old_range.y-old_range.x,"station upgrade narrows the face range")
	# Build each protection through its ordinary three actions.
	for id in ["rainwater","drainage","windbreaks","frost"]:
		farm.climate.fund(farm,id)
		game._on_state_changed()
		check(w._work_nodes.has(id),"unfinished project has a construction site "+id)
		for step in range(3): farm.ClimateSystem.Protection.work(farm,id)
		check(not w._work_nodes.has(id) and w._project_nodes.has(id),"completed project replaces its work site "+id)
	for crown in w._project_nodes.windbreaks.get_meta("crowns"):
		check(absf(crown.x)<w.Surface.half_width(crown.z,.4) and absf(crown.z)<w.Surface.EXTENT.y*.5-.4,"every planted windbreak stays on the coast")
	# Tank upgraded on the island, plus real Winter stores and kept seed.
	Stock.add(farm.storage,"russet",80,90)
	farm.trading.keep_seed(farm,"russet","Table",3)
	farm.trading.begin_winter(farm)
	game._on_state_changed()
	check(art.stored_count==farm.storage_used() and art.stores.visible,"stored sacks track actual Winter stock")
	check(art.seed_count==3 and art.seed_crate.get_child_count()>0,"kept seed has its own crate")
	check(art.spoiled_count>0 and art.spoiled.visible,"actual spoilage appears as a dark heap")
	var spoil_scale: Vector3=art.spoiled.scale
	art.animate(2)
	check(art.spoiled.scale.x<spoil_scale.x,"spoilage heap shrinks without changing inventory")
	farm.plots[4].winter_ice=true; game._on_state_changed()
	check(w._ice_roots[4].visible,"saved bed ice draws a cracked glaze")
	w.player.position=w.plot_positions[4]
	game.perform_plot(4,"hoe")
	check(not w._ice_roots[4].visible and art.flying_ice.size()==8,"successful Hoe clears ice and throws visible shards")
	art.animate(2)
	check(art.flying_ice.is_empty(),"ice shards retire after breaking")
	w.player.position=w.ClimateProjects.barn_position(w)+Vector3(0,0,5)
	w.player.rotation.y=.3
	await shot("winter")
	await shot("tank",w.ClimateProjects.tank_position(w)+Vector3(1,1,0),17)
	await shot("winter-barn",w.ClimateProjects.barn_position(w)+Vector3(0,1,1),14)
	# Different hazards change plant geometry and colour, not only the danger ring.
	calendar(1)
	plant(0); plant(1,60); plant(2,20)
	game._on_state_changed()
	var healthy: PackedColorArray=plant_colors(w._crop_tubers[0].node)
	for event in ["drought","flood","freeze"]:
		farm.climate.data.event=event
		farm.climate.data.phase="active"
		farm.climate.data.operations.stress={"0":.85,"1":.6,"2":.9}
		game._on_state_changed()
		w._climate_field._refresh()
		check(w._crop_tubers[0].event==event,"plant follows live "+event+" stress")
		var changed: PackedColorArray=plant_colors(w._crop_tubers[0].node)
		var recolored:=0
		for i in range(mini(changed.size(),healthy.size())):
			if changed[i]!=healthy[i]: recolored+=1
		check(recolored>healthy.size()*.65,"overview stress tints most plant vertices, including the potato body: "+event)
		var border_colors: PackedColorArray=w._climate_field.markings.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		check(border_colors.has(w.STRESS_BORDER_TINTS[event]),"overview stress has a strong existing border: "+event)
		farm.climate.data.operations.stress={"0":.3,"1":.31}
		game._on_state_changed()
		check(not w._crop_tubers[0].overview_stress and w._crop_tubers[1].overview_stress,"overview stress starts above .3 without waiting for a quantized half-step: "+event)
		farm.climate.data.phase="recovery"
		w._climate_field.set_weather(farm.climate_info()); w._climate_field._refresh()
		border_colors=w._climate_field.markings.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		check(border_colors.has(w.STRESS_BORDER_TINTS[event]),"remaining stress stays readable during recovery: "+event)
		farm.climate.data.operations.stress={"0":.85,"1":.6,"2":.9}
		game._on_state_changed()
		await shot("stress-"+event,w.plot_positions[1]+Vector3(0,.7,0),9)
	farm.climate.data.event=""; farm.climate.data.operations.stress.clear(); game._on_state_changed()
	check(w._crop_tubers[0].event=="" and is_zero_approx(w._crop_tubers[0].node.rotation.z),"rescued plant loses hazard deformation")
	# Accepted orders persist as tagged crates; real settlement dispatches one cart.
	calendar(0)
	farm.trading.accept(farm)
	game._on_state_changed()
	check(art.order_crates.get_child_count()>0,"accepted buyer order creates roadside crate and chalk tag")
	calendar(3)
	farm.trading.settle(farm); game._on_state_changed()
	check(art.collections==1 and art.cart_time==0,"contract settlement starts collection")
	art.animate(7.5)
	check(art.cart.visible and art.cart_load.visible,"collection cart arrives and loads")
	art.animate(10)
	check(not art.cart.visible,"loaded cart leaves the island road")
	art.sync_state(farm); art.sync_state(farm)
	check(art.collections==1,"repeated state refresh never replays collection")
	var meshes: int=w.find_children("*","MeshInstance3D",true,false).size()
	check(meshes<=1150,"mesh budget includes all seasons and built protections: %d" % meshes)
	var count: int=w.find_children("*","",true,false).size()
	for i in range(10): game._on_state_changed()
	check(w.find_children("*","",true,false).size()==count,"unchanged state reuses all static art")
	calendar(0)
	check(not art.snow.visible and art.print_count==0,"Spring clears snow and tracks")
	var saved_plots: Array=farm.plots.duplicate(true)
	w.build_world(); game._on_state_changed()
	check(farm.plots==saved_plots,"rebuilding visual batches never mutates live plots")
	game.queue_free(); await frames(); await create_timer(.4).timeout
	print("FARM VISUALS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
