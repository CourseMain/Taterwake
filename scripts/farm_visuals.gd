extends Node3D
## State-driven island art. Static layers compile together; bounded pools move.
const Quality = preload("res://scripts/crop_quality.gd")
const SNOW := Color("f0f1f0")
const WOOD := Color("a78150")
const PRINT_LIMIT := 96
const SHARD_LIMIT := 48
const Fade = preload("res://scripts/season_fade.gd")
var world
var snow: Node3D
var snow_material: ShaderMaterial
var sparkles: MultiMeshInstance3D
var sparkle_points: Array[Vector3] = []
var sparkle_time := 0.0
var winter_charm: Node3D
var bed_snow: MultiMeshInstance3D
var snow_ground: MeshInstance3D
var snow_paths: MeshInstance3D
var drift_specs: Array[Dictionary] = []
var winter_dirty := true
var winter := false
var snow_opacity := 0.0
var snow_builds := 0
var _snow_fade := Fade.new()
var _charm_fade := Fade.new()
var water_markers: MultiMeshInstance3D
var dry_beds: Array[int] = []
var _water_marker_scale := -1.0
var grades: Dictionary = {}
var grade_batches: Dictionary = {}
var footprints: MultiMeshInstance3D
var print_count := 0
var print_cursor := 0
var walked_distance := 0.0
var print_ages := PackedFloat32Array()
const PRINT_SECONDS := 60.0
var shards: MultiMeshInstance3D
var flying_ice: Array[Dictionary] = []
var stores: Node3D
var seed_crate: Node3D
var spoiled: Node3D
var stored_count := 0
var seed_count := 0
var spoiled_count := 0
var _stock_key := ""
var _seed_key := -1
var _spoil_key := ""
var spoil_seconds := 0.0
var order_crates: Node3D
var _order_key := ""
var cart: Node3D
var cart_load: Node3D
var wheels: Array[Node3D] = []
var cart_time := -1.0
var collections := 0
var cart_delivered := 0

func setup(w) -> void:
	world = w
	name = "FarmVisuals"
	snow = _group("WinterSnow")
	snow.hide()
	snow_material = ShaderMaterial.new()
	snow_material.shader = preload("res://scripts/winter_ground.gdshader")
	snow_material.set_shader_parameter("ground_surface",false)
	var ridge_shape:=SphereMesh.new(); ridge_shape.radius=1; ridge_shape.height=2; ridge_shape.radial_segments=12; ridge_shape.rings=6
	bed_snow=_instances("SnowFurrowRidges",ridge_shape,snow_material,world.plot_positions.size()*3)
	for grade in Quality.GRADES:
		var prototype := _group("GradePrototype")
		world._box(prototype,Vector3(0,.31,0),Vector3(.07,.60,.07),WOOD)
		world._box(prototype,Vector3(0,.65,0),Vector3(.48,.36,.08),Color("efe5c3"))
		if grade != "Standard":
			world._leaf(prototype,Vector3(0,.67,.075),Vector3(.20,.13,.035),Color("4b854d") if grade == "Table" else Color("90643e"),.4)
			world._bar(prototype,Vector3(-.09,.63,.113),Vector3(.11,.72,.113),.011,Color("c0ca8f"))
		var compiled: MeshInstance3D = _compile_prototype(prototype)
		grade_batches[grade] = _instances("Grade"+grade,compiled.mesh,compiled.material_override,world.plot_positions.size())
		prototype.free()
	var print_shape := SphereMesh.new(); print_shape.radius=.13; print_shape.height=.014; print_shape.radial_segments=8; print_shape.rings=3
	var print_material: StandardMaterial3D=world._mat(Color("7b939a")).duplicate()
	print_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	print_material.vertex_color_use_as_albedo=true
	footprints = _instances("SnowFootprints",print_shape,print_material,PRINT_LIMIT,true)
	print_ages.resize(PRINT_LIMIT); print_ages.fill(PRINT_SECONDS)
	var shard_shape := CylinderMesh.new(); shard_shape.bottom_radius=.15; shard_shape.top_radius=.04; shard_shape.height=.045; shard_shape.radial_segments=3
	shards = _instances("BrokenBedIce",shard_shape,world._mat(Color("e2e6e5")),SHARD_LIMIT)
	_build_sparkles()
	_build_winter_charm()
	_charm_fade.collect(winter_charm)
	# Loading prepares the meshes. Calendar boundaries only change materials.
	prepare_snow()
	_build_water_markers()
	stores = _group("WinterBarnSacks")
	seed_crate = _group("KeptSeedCrate")
	spoiled = _group("SpoiledSacks")
	order_crates = _group("BuyerOrderCrates")
	_build_cart()

func _group(title: String, parent: Node3D = self) -> Node3D:
	var node := Node3D.new(); node.name=title; parent.add_child(node)
	return node

func _clear(node: Node3D) -> void:
	for child in node.get_children(): child.free()

func _compile_prototype(node: Node3D) -> MeshInstance3D:
	world._geometry_batcher.batch_siblings(node)
	return node.get_child(0) as MeshInstance3D

func _instances(title: String, mesh: Mesh, material: Material, count: int, instance_colors: bool=false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new(); node.name=title
	node.multimesh=MultiMesh.new(); node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors=instance_colors
	node.multimesh.mesh=mesh; node.multimesh.instance_count=count; node.multimesh.visible_instance_count=0
	node.material_override=material
	add_child(node)
	return node

func update_grades(plots: Array) -> void:
	grades.clear()
	var counts := {"Table":0,"Standard":0,"Feed":0}
	for i in range(mini(plots.size(),world.plot_positions.size())):
		if not plots[i].get("unlocked",true) or int(plots[i].get("stage",0)) <= 0: continue
		var word: String = Quality.grade(int(plots[i].get("quality",100)))
		grades[i]=word
		var p: Vector3 = world.plot_positions[i]+Vector3(.70,.23,.73)
		grade_batches[word].multimesh.set_instance_transform(counts[word],Transform3D(Basis.IDENTITY,p))
		counts[word]+=1
	for word in counts: grade_batches[word].multimesh.visible_instance_count=counts[word]
	update_water_markers(plots)

func _build_water_markers() -> void:
	# A filled teardrop and dark rim share one billboard batch for every bed.
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = [Vector2(0,.72),Vector2(.19,.35),Vector2(.32,.03),Vector2(.29,-.24),Vector2(.16,-.42),Vector2(0,-.48),Vector2(-.16,-.42),Vector2(-.29,-.24),Vector2(-.32,.03),Vector2(-.19,.35)]
	for layer in range(2):
		var scale_value: float = 1.16 if layer == 0 else 1.0
		var tint := Color("325b67") if layer == 0 else Color("9fdef0")
		for i in range(points.size()):
			for p: Vector2 in [Vector2.ZERO,points[i],points[(i+1)%points.size()]]:
				surface.set_color(tint)
				surface.add_vertex(Vector3(p.x*scale_value,p.y*scale_value,float(layer)*.01))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 20
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_markers = _instances("BedsNeedingWater",surface.commit(),material,world.plot_positions.size())
	water_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_water_markers(plots: Array) -> void:
	if not is_instance_valid(water_markers): return
	dry_beds.clear()
	for i in range(mini(plots.size(),world.plot_positions.size())):
		var plot: Dictionary = plots[i]
		if not plot.get("unlocked",true) or int(plot.get("stage",0)) not in [1,2] or plot.get("watered",false): continue
		dry_beds.append(i)
	water_markers.multimesh.visible_instance_count = dry_beds.size()
	water_markers.visible = not dry_beds.is_empty()
	_water_marker_scale = -1.0
	_fit_water_markers()

func _fit_water_markers() -> void:
	if dry_beds.is_empty() or not is_instance_valid(world.camera): return
	# Orthographic portrait views see more land: keep the droplet at least 16px.
	var height: float = maxf(1.0,get_viewport().get_visible_rect().size.y)
	var marker_scale: float = maxf(1.0,world.camera.size/height*16.0/1.2)
	if is_equal_approx(marker_scale,_water_marker_scale): return
	_water_marker_scale = marker_scale
	for j in range(dry_beds.size()):
		var p: Vector3 = world.plot_positions[dry_beds[j]]+Vector3(.75,2.25,.4)
		water_markers.multimesh.set_instance_transform(j,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*marker_scale),p))

func prepare_snow() -> void:
	if not winter_dirty: return
	_build_snow()
	_snow_fade.collect(snow)
	set_shadow_mode(world.graphics_quality!="smooth")
	_snow_fade.set_opacity(snow_opacity)

func set_winter(enabled: bool, opacity: float = -1.0) -> void:
	var changed: bool = winter != enabled
	winter = enabled
	var amount: float = (1.0 if enabled else 0.0) if opacity < 0.0 else clampf(opacity,0.0,1.0)
	if changed: update_bed_snow(world._live_plots)
	set_snow_opacity(amount)
	footprints.visible=winter
	stores.visible=winter and stored_count>0
	spoiled.visible=winter and spoiled_count>0 and spoil_seconds<14
	if is_instance_valid(water_markers): water_markers.visible = not dry_beds.is_empty()
	if changed and not winter:
		print_count=0; print_cursor=0; walked_distance=0
		print_ages.fill(PRINT_SECONDS)
		footprints.multimesh.visible_instance_count=0

func set_snow_opacity(amount: float) -> void:
	snow_opacity = clampf(amount,0.0,1.0)
	snow.visible=snow_opacity>0
	sparkles.visible=snow_opacity>0
	winter_charm.visible=snow_opacity>0
	_snow_fade.set_opacity(snow_opacity)
	_charm_fade.set_opacity(snow_opacity)

func set_shadow_mode(enabled: bool) -> void:
	for material in [snow_material, snow_ground.material_override if is_instance_valid(snow_ground) else null, snow_paths.material_override if is_instance_valid(snow_paths) else null]:
		if material!=null: material.set_shader_parameter("single_light_pass",not enabled)
	# A quality change during a fade must survive restoration of opaque art.
	for entry in _snow_fade.entries:
		for material in [entry.original,entry.fade]:
			if material is ShaderMaterial: material.set_shader_parameter("single_light_pass",not enabled)

func _build_winter_charm() -> void:
	winter_charm=_group("WinterCharm")
	winter_charm.hide()
	var pond:=_group("FrozenPond",winter_charm)
	pond.position=world._duck_home+Vector3(0,0,1)
	world._cylinder(pond,Vector3(0,.20,0),1.86,1.86,.045,Color("b4cecf"),20)
	for i in range(3):
		var x: float=-.9+i*.64
		world._bar(pond,Vector3(x-.25,.228,.05),Vector3(x+.40,.228,.86),.018,Color("e2ebeb"))
	var snowman:=_group("Snowman",winter_charm)
	snowman.position=world._duck_home+Vector3(3.2,0,1.5)
	var snowballs:=_group("Snowballs",snowman)
	world._sphere(snowballs,Vector3(0,.77,0),Vector3(.68,.70,.64),SNOW)
	world._sphere(snowballs,Vector3(0,1.70,0),Vector3(.46,.45,.44),SNOW)
	_flatten_static(snowballs)
	world._cylinder(snowman,Vector3(0,2.09,0),.56,.56,.085,Color("354349"),12)
	world._cylinder(snowman,Vector3(0,2.29,0),.36,.34,.36,Color("354349"),10)
	world._cylinder(snowman,Vector3(0,1.35,0),.39,.37,.15,Color("af5749"),12)
	world._box(snowman,Vector3(.22,1.08,.52),Vector3(.18,.51,.10),Color("af5749"))
	for x in [-.16,.16]: world._sphere(snowman,Vector3(x,1.81,.395),Vector3(.045,.052,.035),Color("33413e"))
	world._bar(snowman,Vector3(0,1.66,.4),Vector3(0,1.63,.83),.075,Color("df9647"))
	for y in [.67,.94]: world._sphere(snowman,Vector3(0,y,.63),Vector3(.052,.052,.028),Color("46514a"))
	for side in [-1,1]:
		world._bar(snowman,Vector3(side*.49,1.12,0),Vector3(side*1.12,1.46,0),.042,Color("75614c"))
		world._bar(snowman,Vector3(side*.93,1.36,0),Vector3(side*1.03,1.61,0),.031,Color("75614c"))
	var robin:=_group("Robin",winter_charm)
	robin.position=snowman.position+Vector3(1.14,1.48,0)
	for x in [-.07,.07]: world._bar(robin,Vector3(x,0,0),Vector3(x,.15,0),.021,Color("614e3d"))
	world._sphere(robin,Vector3(0,.31,0),Vector3(.26,.26,.28),Color("81705a"))
	world._sphere(robin,Vector3(0,.30,.19),Vector3(.20,.19,.14),Color("ce6c49"))
	world._sphere(robin,Vector3(0,.55,.04),Vector3(.19,.18,.18),Color("8c7c64"))
	for side in [-1,1]:
		world._sphere(robin,Vector3(side*.245,.31,-.055),Vector3(.045,.18,.19),Color("685f50"))
		world._sphere(robin,Vector3(side*.15,.60,.14),Vector3(.028,.032,.025),Color("293b36"))
	world._bar(robin,Vector3(0,.54,.17),Vector3(0,.53,.32),.034,Color("b29964"))
	world._sphere(robin,Vector3(0,.26,-.32),Vector3(.12,.065,.23),Color("685f50")).rotation.x=-.25
	world._geometry_batcher.batch_tree(winter_charm,{})

func update_bed_snow(plots: Array) -> void:
	var count:=0
	if winter:
		for i in range(mini(plots.size(),world.plot_positions.size())):
			if not plots[i].get("unlocked",true) or not world._ice_roots[i].visible: continue
			for x in [-.56,0,.56]:
				var p: Vector3=world.plot_positions[i]+Vector3(x,.32,0)
				bed_snow.multimesh.set_instance_transform(count,Transform3D(Basis.IDENTITY.scaled(Vector3(.18,.11,.84)),p))
				count+=1
	bed_snow.multimesh.visible_instance_count=count

func _flatten_static(root: Node3D) -> void:
	# Bake all snow together, including roof-local transforms, into one surface.
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.get_parent()!=root: mesh.reparent(root,true)
	for child in root.get_children():
		if not child is MeshInstance3D: child.free()
	world._geometry_batcher.batch_siblings(root)
	for mesh: MeshInstance3D in root.get_children(): mesh.material_override=snow_material

func _build_snow() -> void:
	_clear(snow)
	winter_dirty=false
	snow_builds+=1
	for spec in world._roof_specs:
		if not is_instance_valid(spec.parent): continue
		var cap := _group("RoofSnow",snow); cap.global_transform=spec.parent.global_transform
		world._snow_roof(cap,spec.width,spec.depth,spec.base,spec.rise)
	# Canvas stall and the conical windmill roof are not gabled roofs.
	var market: Node3D = world.get_node("MarketStall")
	var canvas := _group("CanvasSnow",snow); canvas.global_transform=market.global_transform
	world._sphere(canvas,Vector3(0,3.44,-.23),Vector3(2.72,.29,1.65),SNOW)
	var mill: Node3D = world.get_node("Windmill")
	var peak := _group("MillSnow",snow); peak.global_transform=mill.global_transform
	world._cylinder(peak,Vector3(0,4.08,0),.87,0,1.12,SNOW,8)
	for tree in world._tree_specs:
		if not is_instance_valid(tree.parent): continue
		var cap := _group("BranchSnow",snow); cap.global_transform=tree.parent.global_transform
		for branch in range(5):
			var tip := Vector3(sin(branch*2.1)*1.05,2.5+float(branch%2)*.65,cos(branch*2.1)*.9)
			world._bar(cap,Vector3(0,1.6,0),tip+Vector3(0,.075,0),.085,SNOW)
			world._sphere(cap,tip+Vector3(0,.13,0),Vector3(.50,.23,.40),SNOW)
	for fence in world._fence_specs:
		if not is_instance_valid(fence.parent): continue
		var a: Vector3 = fence.parent.to_global(fence.a)
		var b: Vector3 = fence.parent.to_global(fence.b)
		_snow_lip(a,b,.20,.18,a.y+.82)
		for i in range(int(fence.segments)+1):
			world._sphere(snow,a.lerp(b,float(i)/fence.segments)+Vector3(0,1.03,0),Vector3(.29,.18,.27),SNOW)
	for cap in world.get_meta("ridge_wall_caps",[]):
		world._box(snow,cap.position,Vector3(1.05,.09,.61),SNOW).rotation.y=cap.angle
	_build_scalloped_edges()
	# Wind only heaps snow into sheltered corners, never strings of lane blobs.
	drift_specs.clear()
	var barn: Vector3=world.get_node("RedBarn").position
	_corner_drift(barn+Vector3(-2.95,0,2.15),Vector2(1.20,.75),.36,"barn")
	_corner_drift(barn+Vector3(2.95,0,-1.8),Vector2(.85,1.1),.29,"barn")
	for i in range(world.Surface.STEPS.size()):
		_corner_drift(Vector3(-24.8 if i%2==0 else -21.2,0,world.Surface.STEPS[i]+.41),Vector2(.88,.35),.25,"terrace")
	for field_offset in [Vector3.ZERO,Vector3(18,0,13),Vector3(1,0,-23)]:
		_corner_drift(field_offset+Vector3(-1.25,0,6.25),Vector2(.85,.58),.24,"gate")
	var tank: Vector3=world.ClimateProjects.tank_position(world)
	var tank_scale: Vector3=world.ClimateProjects.tank_scale(int(world._project_levels.get("rainwater",1)))
	world._cylinder(snow,tank+Vector3(0,3.57,0),1.30*tank_scale.x,1.30*tank_scale.x,.07,Color("d8dedf"),20)
	for i in range(5): world._bar(snow,tank+Vector3(-1.0+i*.4,3.615,-.6),tank+Vector3(-.7+i*.4,3.615,.65),.023,Color("f3f4f2"))
	world._sphere(snow,tank+Vector3(0,3.63,0),Vector3(1.60*tank_scale.x,.25,1.60*tank_scale.z),SNOW)
	# Evergreen protection trees keep their crowns and collect snow on top.
	if world._project_nodes.has("windbreaks"):
		for p in world._project_nodes.windbreaks.get_meta("crowns",[]):
			world._sphere(snow,p,Vector3(.60,.17,.46),SNOW)
	_flatten_static(snow)
	# One opaque near-white surface follows every upper terrain triangle.
	snow_ground=preload("res://scripts/winter_ground.gd").build()
	snow.add_child(snow_ground)
	snow_paths=preload("res://scripts/winter_ground.gd").paths(world._path_segments)
	snow.add_child(snow_paths)
	snow.set_meta("drift_count",drift_specs.size())
	snow.set_meta("drift_specs",drift_specs)
	world._snowflakes.clear()
	world._falling_snow(snow,world.Surface.EXTENT*.48)
	sparkle_points.clear()
	for spec in world._roof_specs:
		if is_instance_valid(spec.parent): sparkle_points.append(spec.parent.to_global(Vector3(spec.width*.2,spec.base+spec.rise*.65+.3,spec.depth*.2)))
	for p in [Vector3(-19,0,1),Vector3(21,0,18),Vector3(-6,0,-18),Vector3(9,0,8)]:
		p.y=world.ground_height(p.x,p.z)+.25; sparkle_points.append(p)
	sparkles.multimesh.visible_instance_count=mini(14,sparkle_points.size())

func _build_sparkles() -> void:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a: float=TAU*i/8; var b: float=TAU*(i+1)/8
		for p in [Vector3.ZERO,Vector3(cos(a),sin(a),0)*(1.0 if i%2==0 else .18),Vector3(cos(b),sin(b),0)*(.18 if i%2==0 else 1.0)]: surface.add_vertex(p)
	var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo=true; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	sparkles=_instances("SlowSnowSparkles",surface.commit(),mat,14,true)
	sparkles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparkles.hide()

func _build_scalloped_edges() -> void:
	# Continuous rounded ribbons make a lip, not rows of separate snow balls.
	for lane in world._path_segments:
		var side: Vector3=(lane.b-lane.a).normalized().cross(Vector3.UP)*float(lane.width)*.5
		for sign_value in [-1,1]: _snow_lip(lane.a+side*sign_value,lane.b+side*sign_value,.20,.17)
	for p in world.plot_positions:
		for corners in [[Vector3(-1,0,-1),Vector3(1,0,-1)],[Vector3(1,0,-1),Vector3(1,0,1)],[Vector3(1,0,1),Vector3(-1,0,1)],[Vector3(-1,0,1),Vector3(-1,0,-1)]]:
			_snow_lip(p+corners[0],p+corners[1],.095,.10)
	for cap in world.get_meta("ridge_wall_caps",[]):
		var direction:=Vector3(cos(cap.angle),0,-sin(cap.angle))*.54
		_snow_lip(cap.position-direction,cap.position+direction,.31,.08,cap.position.y)

func _snow_lip(a: Vector3,b: Vector3,width: float,rise: float,fixed_height: float=-100) -> void:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=maxi(2,ceili(a.distance_to(b)/.28))
	var side: Vector3=(b-a).normalized().cross(Vector3.UP)
	var rows: Array=[]
	for i in range(count+1):
		var p: Vector3=a.lerp(b,float(i)/count)
		var scallop: float=1.0+.28*cos(i*TAU/4)
		var row: Array[Vector3]=[]
		for j in range(7):
			var angle: float=PI*j/6
			var v: Vector3=p+side*cos(angle)*width*scallop
			v.y=(world.ground_height(v.x,v.z)+.125 if fixed_height< -99 else fixed_height)+sin(angle)*rise
			row.append(v)
		rows.append(row)
	for i in range(count):
		for j in range(6):
			for p: Vector3 in [rows[i][j],rows[i+1][j+1],rows[i+1][j],rows[i][j],rows[i][j+1],rows[i+1][j+1]]: surface.add_vertex(p)
	surface.generate_normals()
	var lip:=MeshInstance3D.new(); lip.mesh=surface.commit(); lip.material_override=world._mat(SNOW)
	snow.add_child(lip)

func _corner_drift(point: Vector3, extent: Vector2, height: float, corner: String) -> void:
	point.y=world.ground_height(point.x,point.z)
	drift_specs.append({"position":point,"extent":extent,"height":height,"corner":corner})
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=9
	var ridge: Vector3=point+Vector3(-extent.x*.18,.13+height,extent.y*.08)
	var rim: Array[Vector3]=[]
	for i in range(count):
		var angle: float=TAU*i/count
		var radius: float=.80+.20*sin(i*3.17+drift_specs.size())
		var p: Vector3=point+Vector3(cos(angle)*extent.x*radius,0,sin(angle)*extent.y*radius)
		p.y=world.ground_height(p.x,p.z)+.132
		rim.append(p)
	for i in range(count):
		for p in [ridge,rim[i],rim[(i+1)%count]]: surface.add_vertex(p)
	surface.generate_normals()
	var drift:=MeshInstance3D.new(); drift.mesh=surface.commit()
	drift.name="CornerSnow"
	drift.material_override=world._mat(SNOW)
	snow.add_child(drift)

func on_path(point: Vector3) -> bool:
	var p := Vector2(point.x,point.z)
	for lane in world._path_segments:
		var a := Vector2(lane.a.x,lane.a.z); var b := Vector2(lane.b.x,lane.b.z)
		if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p) <= float(lane.width)*.5: return true
	return false

func walked(before: Vector3, after: Vector3) -> void:
	if not winter: return
	var distance: float=before.distance_to(after)
	if distance>2: walked_distance=0; return # Recenter/load is not a trail.
	walked_distance+=distance
	if walked_distance<.48 or not on_path(after): return
	walked_distance=0
	var direction: Vector3=(after-before).normalized()
	for foot in [-1,1]:
		var p: Vector3=after+direction.cross(Vector3.UP)*.18*foot+direction*.07*foot
		p.y=world.ground_height(p.x,p.z)+.19
		footprints.multimesh.set_instance_transform(print_cursor,Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.z)).scaled_local(Vector3(.65,1,1.15)),p))
		footprints.multimesh.set_instance_color(print_cursor,Color.WHITE)
		print_ages[print_cursor]=0
		print_cursor=(print_cursor+1)%PRINT_LIMIT
		print_count=mini(PRINT_LIMIT,print_count+1)
	footprints.multimesh.visible_instance_count=PRINT_LIMIT

func break_ice(index: int) -> void:
	for i in range(8):
		if flying_ice.size()>=SHARD_LIMIT: flying_ice.pop_front()
		var angle: float=i*TAU/8
		flying_ice.append({"p":world.plot_positions[index]+Vector3(0,.3,0),"v":Vector3(cos(angle)*1.6,1.6+float(i%3)*.25,sin(angle)*1.6),"age":0.0})

func _sack(parent: Node3D, p: Vector3, tint: Color) -> void:
	world._sphere(parent,p+Vector3(0,.31,0),Vector3(.31,.38,.26),tint)
	world._cylinder(parent,p+Vector3(0,.68,0),.11,.07,.16,tint.darkened(.08),7)
	world._bar(parent,p+Vector3(-.10,.62,.04),p+Vector3(.10,.62,.04),.03,Color("675742"))

func sync_state(farm) -> void:
	var count: int=farm.storage_used()
	var seeds: int=0
	for value in farm.trading.kept_seed.values(): seeds+=int(value)
	var barn: Vector3=world.get_node("RedBarn").position
	var key: String="%s/%d" % [farm.storage,count]
	if key!=_stock_key:
		_stock_key=key; stored_count=count; _clear(stores)
		for i in range(mini(18,count)):
			_sack(stores,barn+Vector3(-.72+(i%3)*.68,.22+(i/6)*.57,1.45+(i/3%2)*.59),Color("c4aa78"))
		world._geometry_batcher.batch_siblings(stores)
	if seeds!=_seed_key:
		_seed_key=seeds; seed_count=seeds; _clear(seed_crate)
		if seeds>0:
			world._crate(seed_crate,barn+Vector3(3.5,.30,3.2),false)
			for i in range(mini(4,seeds)): _sack(seed_crate,barn+Vector3(3.2+(i%2)*.45,.40+(i/2)*.5,3.2),Color("b9bd82"))
			var label: Label3D=world._label(seed_crate,"SEED",barn+Vector3(3.5,1.75,3.2),24,world.CREAM,false)
			label.pixel_size=.02
			world.bind_label(label, Vector2(1.3, .6))
			world._geometry_batcher.batch_siblings(seed_crate)
	var report: Dictionary=farm.trading.winters.get(str(farm.season_clock.year),{})
	var loss: int=0
	for value in report.get("spoiled",{}).values(): loss+=int(value)
	var spoil_key: String="%d/%d" % [farm.season_clock.year,loss]
	if spoil_key!=_spoil_key:
		_spoil_key=spoil_key; spoiled_count=loss; spoil_seconds=0; _clear(spoiled)
		spoiled.position=barn+Vector3(-2.8,0,4.8); spoiled.scale=Vector3.ONE
		for i in range(mini(8,loss)): _sack(spoiled,Vector3((i%3)*.42,0,(i/3)*.33),Color("695843"))
		world._geometry_batcher.batch_siblings(spoiled)
	var orders: String=str(farm.trading.contracts)
	if orders!=_order_key:
		_order_key=orders; _clear(order_crates)
		for i in range(farm.trading.contracts.size()):
			var order: Dictionary=farm.trading.contracts[i]
			var p:=Vector3(9+i*2.0,0,-7.3)
			world._crate(order_crates,p+Vector3(0,.38,0),true)
			world._box(order_crates,p+Vector3(0,1.16,.25),Vector3(1.85,.76,.12),Color("344b43"))
			var tag: Label3D=world._label(order_crates,"%s\n%d t · AUTUMN" % [str(order.crop).capitalize(),int(order.quantity)],p+Vector3(0,1.19,.33),24,world.CREAM,false)
			tag.pixel_size=.013
			world.bind_label(tag, Vector2(1.69, .60))
		world._geometry_batcher.batch_siblings(order_crates)
	# The world's calendar fade owns snow opacity; stock sync cannot snap it.
	stores.visible=winter and stored_count>0
	spoiled.visible=winter and spoiled_count>0 and spoil_seconds<14

func collect_order(receipts: Array) -> void:
	if receipts.is_empty(): return
	cart_time=0; collections+=1; cart_load.hide()
	cart_delivered=0
	for receipt in receipts: cart_delivered+=int(receipt.delivered)
	_clear(cart_load)
	for i in range(mini(6,cart_delivered)): _sack(cart_load,Vector3(-.4+(i%2)*.8,.83,-.8+(i/2)*.72),Color("c7ad7d"))
	world._geometry_batcher.batch_siblings(cart_load)

func _build_cart() -> void:
	cart=_group("BuyerCollectionCart"); cart.hide()
	world._box(cart,Vector3(0,.72,0),Vector3(1.65,.16,2.5),WOOD)
	for side in [-1,1]:
		for y in [.95,1.25]: world._box(cart,Vector3(side*.85,y,0),Vector3(.12,.17,2.5),WOOD.lightened(.10))
		world._bar(cart,Vector3(side*.6,.7,1.1),Vector3(side*.6,.6,2.6),.07,WOOD)
		for z in [-.85,.85]:
			var wheel:=_group("CartWheel",cart); wheel.position=Vector3(side*.95,.48,z)
			world._cylinder(wheel,Vector3.ZERO,.43,.43,.15,Color("594b3b"),12).rotation.z=PI*.5
			for spoke in range(4):
				var angle: float=spoke*PI/4
				world._bar(wheel,Vector3(0,cos(angle)*.36,sin(angle)*.36),Vector3(0,-cos(angle)*.36,-sin(angle)*.36),.035,WOOD)
			wheels.append(wheel)
	world._potato_person(cart,Vector3(0,.03,2.25),Color("d7aa70"),Color("798b7b"),true)
	cart_load=_group("CollectedSacks",cart)
	world._geometry_batcher.batch_tree(cart,{})

func _process(delta: float) -> void:
	animate(delta)

func footprint_alpha(index: int) -> float:
	return 1.0-print_ages[index]/PRINT_SECONDS

func animate(delta: float) -> void:
	_fit_water_markers()
	if snow_opacity>0:
		sparkle_time+=delta
		for i in range(mini(14,sparkle_points.size())):
			var pulse: float=pow(maxf(0,sin(sparkle_time*.55+i*1.8)),8)
			sparkles.multimesh.set_instance_transform(i,Transform3D(world.camera.global_basis.scaled(Vector3.ONE*(.03+.13*pulse)),sparkle_points[i]))
			sparkles.multimesh.set_instance_color(i,Color(1,1,1,pulse*.8*snow_opacity))
	if winter and print_count>0:
		print_count=0
		for i in range(PRINT_LIMIT):
			print_ages[i]=minf(PRINT_SECONDS,print_ages[i]+delta)
			footprints.multimesh.set_instance_color(i,Color(1,1,1,footprint_alpha(i)))
			if print_ages[i]<PRINT_SECONDS: print_count+=1
	for i in range(flying_ice.size()-1,-1,-1):
		var bit: Dictionary=flying_ice[i]; bit.age+=delta; bit.v.y-=delta*4; bit.p+=bit.v*delta
		if bit.age>1: flying_ice.remove_at(i)
	for i in range(flying_ice.size()):
		var bit: Dictionary=flying_ice[i]
		shards.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.FORWARD,bit.age*3),bit.p))
	shards.multimesh.visible_instance_count=flying_ice.size()
	if winter and spoiled_count>0:
		spoil_seconds+=delta
		spoiled.scale=Vector3.ONE*maxf(.001,1-spoil_seconds/14)
		spoiled.visible=spoil_seconds<14
	if cart_time>=0:
		cart_time+=delta; cart.visible=cart_time<16
		# Collection runs along the village road from the western working lane.
		var t: float=clampf(cart_time/6,0,1) if cart_time<8 else 1-clampf((cart_time-8)/8,0,1)
		cart.position=Vector3(lerpf(-26,9,t),0,-5.75)
		cart.rotation.y=PI*.5 if cart_time<8 else -PI*.5
		cart_load.visible=cart_time>=7 and cart_delivered>0
		for wheel in wheels: wheel.rotation.x+=delta*5
		if cart_time>=16: cart_time=-1; cart.hide()
