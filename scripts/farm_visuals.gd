extends Node3D
## State-driven island art. Static layers compile together; bounded pools move.
const Quality = preload("res://scripts/crop_quality.gd")
const SNOW := Color("e7eef0")
const WOOD := Color("a78150")
const PRINT_LIMIT := 96
const SHARD_LIMIT := 48
var world
var snow: Node3D
var winter_dirty := true
var winter := false
var grades: Dictionary = {}
var grade_batches: Dictionary = {}
var footprints: MultiMeshInstance3D
var print_count := 0
var print_cursor := 0
var walked_distance := 0.0
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
	var print_shape := BoxMesh.new(); print_shape.size = Vector3(.16,.014,.31)
	footprints = _instances("SnowFootprints",print_shape,world._mat(Color("7b939a")),PRINT_LIMIT)
	var shard_shape := CylinderMesh.new(); shard_shape.bottom_radius=.15; shard_shape.top_radius=.04; shard_shape.height=.045; shard_shape.radial_segments=3
	shards = _instances("BrokenBedIce",shard_shape,world._mat(Color("d2e9ed")),SHARD_LIMIT)
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

func _instances(title: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new(); node.name=title
	node.multimesh=MultiMesh.new(); node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
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

func set_winter(enabled: bool) -> void:
	winter = enabled
	if winter and winter_dirty: _build_snow()
	snow.visible=winter
	footprints.visible=winter
	stores.visible=winter and stored_count>0
	spoiled.visible=winter and spoiled_count>0 and spoil_seconds<14
	if not winter:
		print_count=0; print_cursor=0; walked_distance=0
		footprints.multimesh.visible_instance_count=0

func _flatten_static(root: Node3D) -> void:
	# Bake all snow together, including roof-local transforms, into one surface.
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.get_parent()!=root: mesh.reparent(root,true)
	for child in root.get_children():
		if not child is MeshInstance3D: child.free()
	world._geometry_batcher.batch_siblings(root)

func _build_snow() -> void:
	_clear(snow)
	winter_dirty=false
	for spec in world._roof_specs:
		if not is_instance_valid(spec.parent): continue
		var cap := _group("RoofSnow",snow); cap.global_transform=spec.parent.global_transform
		world._snow_roof(cap,spec.width,spec.depth,spec.base,spec.rise)
	# Canvas stall and the conical windmill roof are not gabled roofs.
	var market: Node3D = world.get_node("MarketStall")
	var canvas := _group("CanvasSnow",snow); canvas.global_transform=market.global_transform
	world._box(canvas,Vector3(0,3.39,-.23),Vector3(5.0,.16,2.9),SNOW)
	var mill: Node3D = world.get_node("Windmill")
	var peak := _group("MillSnow",snow); peak.global_transform=mill.global_transform
	world._cylinder(peak,Vector3(0,4.08,0),.87,0,1.12,SNOW,8)
	for tree in world._tree_specs:
		if not is_instance_valid(tree.parent): continue
		var cap := _group("BranchSnow",snow); cap.global_transform=tree.parent.global_transform
		world._sphere(snow,tree.parent.position+Vector3(.55,.08,-.3),Vector3(1.6,.22,1.0),SNOW)
		for branch in range(5):
			var tip := Vector3(sin(branch*2.1)*1.05,2.5+float(branch%2)*.65,cos(branch*2.1)*.9)
			world._bar(cap,Vector3(0,1.6,0),tip+Vector3(0,.075,0),.085,SNOW)
			world._sphere(cap,tip+Vector3(0,.07,0),Vector3(.32,.12,.24),SNOW)
	for fence in world._fence_specs:
		if not is_instance_valid(fence.parent): continue
		var a: Vector3 = fence.parent.to_global(fence.a)
		var b: Vector3 = fence.parent.to_global(fence.b)
		for i in range(maxi(1,ceili(a.distance_to(b)/1.65))):
			var p: Vector3 = a.lerp(b,float(i)/maxf(1,ceili(a.distance_to(b)/1.65)))
			var drift: MeshInstance3D=world._sphere(snow,p+Vector3(.13,.09,.18),Vector3(1.25,.30,.45),SNOW)
			drift.rotation.y=-atan2((b-a).z,(b-a).x)
		world._bar(snow,a+Vector3(0,.82,0),b+Vector3(0,.82,0),.10,SNOW)
	for edge: float in world.Surface.STEPS:
		for x in [-29,-20,-10,0,10,20,29]:
			var p:=Vector3(x,world.ground_height(x,edge+.24)+.04,edge+.24)
			world._sphere(snow,p,Vector3(4.1,.24,.45),SNOW)
	for x in range(-25,27,2):
		var p := Vector3(x,world.ground_height(x,-24.6),-24.6)
		world._sphere(snow,p+Vector3(0,.18,0),Vector3(1.5,.40,.65),SNOW)
	# Small overlapping banks leave exposed grass and the coast visible.
	for lane in world._path_segments:
		var a: Vector3=lane.a; var b: Vector3=lane.b
		var side: Vector3=(b-a).normalized().cross(Vector3.UP)
		for i in range(ceili(a.distance_to(b)/2.5)):
			var p: Vector3=a.lerp(b,float(i)/maxf(1,ceili(a.distance_to(b)/2.5)))
			for sign_value in [-1,1]:
				var edge: Vector3=p+side*(float(lane.width)*.5+.18)*sign_value
				edge+=side*sin(i*1.8)*.12
				edge.y=world.ground_height(edge.x,edge.z)+.09
				var drift: MeshInstance3D=world._sphere(snow,edge,Vector3(1.8,.20+float(i%3)*.025,.27+float(i%4)*.055),SNOW)
				drift.rotation.y=-atan2((b-a).z,(b-a).x)
		_packed_path(a,b,float(lane.width)*.68)
	for index in range(world.plot_positions.size()):
		world._sphere(snow,world.plot_positions[index]+Vector3(-.89,.24,0),Vector3(.12,.12,.85),SNOW)
	var tank: Vector3=world.ClimateProjects.tank_position(world)
	var tank_scale: Vector3=world.ClimateProjects.tank_scale(int(world._project_levels.get("rainwater",1)))
	world._cylinder(snow,tank+Vector3(0,3.57,0),1.30*tank_scale.x,1.30*tank_scale.x,.07,Color("afcdd7"),20)
	for i in range(5): world._bar(snow,tank+Vector3(-1.0+i*.4,3.615,-.6),tank+Vector3(-.7+i*.4,3.615,.65),.023,Color("eef7f6"))
	# Evergreen protection trees keep their crowns and collect snow on top.
	if world._project_nodes.has("windbreaks"):
		for p in world._project_nodes.windbreaks.get_meta("crowns",[]):
			world._sphere(snow,p,Vector3(.60,.17,.46),SNOW)
	_flatten_static(snow)
	world._snowflakes.clear()
	world._falling_snow(snow,world.Surface.EXTENT*.48)

func _packed_path(a: Vector3, b: Vector3, width: float) -> void:
	# A continuous top avoids overlapping tile faces flickering in WebGL.
	var count: int=ceili(a.distance_to(b)/.6)
	var side: Vector3=(b-a).normalized().cross(Vector3.UP)*width*.5
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		var start: Vector3=a.lerp(b,float(i)/count)
		var finish: Vector3=a.lerp(b,float(i+1)/count)
		var middle: Vector3=(start+finish)*.5
		if middle.z< -12 and middle.z> -16 and absf(middle.x+23)<2: continue
		for p: Vector3 in [start-side,finish+side,start+side,start-side,finish-side,finish+side]:
			p.y=world.ground_height(p.x,p.z)+.13
			surface.add_vertex(p)
	surface.generate_normals()
	var path:=MeshInstance3D.new(); path.mesh=surface.commit()
	path.material_override=world._mat(Color("d0d8cf"))
	snow.add_child(path)

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
	var side: Vector3=direction.cross(Vector3.UP)*(.16 if print_cursor%2==0 else -.16)
	var p: Vector3=after+side
	p.y=world.ground_height(p.x,p.z)+.165
	footprints.multimesh.set_instance_transform(print_cursor,Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.z)),p))
	print_cursor=(print_cursor+1)%PRINT_LIMIT
	print_count=mini(PRINT_LIMIT,print_count+1)
	footprints.multimesh.visible_instance_count=print_count

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
		world._geometry_batcher.batch_siblings(order_crates)
	set_winter(farm.season_clock.season==3)

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

func animate(delta: float) -> void:
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
