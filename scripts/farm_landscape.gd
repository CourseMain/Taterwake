extends RefCounted
## Working lanes and farm details, all grounded on the single Valley surface.
const WOOD := Color("a1845e")
const STONE := Color("a49f8a")
const HEDGE := Color("718856")

static func build(w) -> void:
	_lanes(w)
	_steps(w)
	_orchard(w)
	_ridge(w)
	_yard(w)
	_low_shore(w)
	_verges(w)

static func _lanes(w) -> void:
	# The existing village avenue and Home lane join a straight working loop.
	for pair in [
		[Vector3(-27.5,0,-5.75),Vector3(-18,0,-5.75)],
		[Vector3(18.3,0,-5.75),Vector3(27,0,-5.75)],
		[Vector3(-27.5,0,-5.75),Vector3(-27.5,0,21)],
		[Vector3(8.6,0,9.4),Vector3(8.6,0,21)],
		[Vector3(27,0,-5.75),Vector3(27,0,21)],
		[Vector3(-27.5,0,21),Vector3(27,0,21)],
		[Vector3(-14.7,0,9.4),Vector3(-14.7,0,24.5)],
		[Vector3(0.375,0,9.4),Vector3(0.375,0,6.2)],
		[Vector3(18.375,0,21),Vector3(18.375,0,19.2)],
		[Vector3(-23,0,-5.75),Vector3(-23,0,-16.5)],
		[Vector3(-23,0,-15.7),Vector3(1.375,0,-15.7)],
		[Vector3(1.375,0,-15.7),Vector3(1.375,0,-17.0)],
	]:
		w._ground_path(pair[0],pair[1],1.8)
	# Paired wheel marks and occasional flat stones make the lanes worked-in.
	for x in range(-25,27,2):
		for z in [20.55,21.45]:
			w._box(w,Vector3(x,w.ground_height(x,z)+0.054,z),Vector3(1.1,0.018,0.09),Color("bea574"))
	for z in range(-4,20,3):
		for x in [-27.5,27.0]:
			w._box(w,Vector3(x,w.ground_height(x,z)+0.065,z),Vector3(0.55,0.035,0.48),Color("ccb98c")).rotation.y = 0.15

static func _steps(w) -> void:
	var root: Node3D = w._root("HillStairPath",Vector3.ZERO)
	for edge: float in w.Surface.STEPS:
		# Four shallow treads per raised terrace, with a level landing between flights.
		for tread in range(w.Surface.TREAD_COUNT):
			var z: float = edge+w.Surface.STAIR_START-tread*w.Surface.TREAD_SPACING-0.14
			w._box(root,Vector3(w.Surface.PATH_X,w.ground_height(w.Surface.PATH_X,z)+0.03,z),Vector3(2.15,0.06,0.16),WOOD)
		for side in [-1,1]:
			var a := Vector3(-23+side*1.3,w.ground_height(-23,edge+0.3),edge+0.3)
			var b := Vector3(a.x,w.ground_height(-23,edge-0.7),edge-0.7)
			w._cylinder(root,a+Vector3(0,0.5,0),0.065,0.065,1,WOOD,6)
			w._bar(root,a+Vector3(0,0.9,0),b+Vector3(0,0.9,0),0.065,WOOD)
			w._bar(root,a+Vector3(0,0.46,0),b+Vector3(0,0.46,0),0.04,WOOD)
	for side in [-1,1]:
		var z: float = w.Surface.STEPS.back()-0.7
		w._cylinder(root,Vector3(-23+side*1.3,w.ground_height(-23,z)+0.5,z),0.065,0.065,1,WOOD,6)

static func _hedge(w, a: Vector3, b: Vector3) -> void:
	var count: int = maxi(1,ceili(a.distance_to(b)/1.3))
	for i in range(count+1):
		var p: Vector3 = a.lerp(b,float(i)/count)
		p.x = clampf(p.x,-w.Surface.half_width(p.z,2.4),w.Surface.half_width(p.z,2.4))
		p.y = w.ground_height(p.x,p.z)+0.36
		w._sphere(w,p,Vector3(0.80,0.52,0.65),HEDGE)
		if i % 4 == 0: w._sphere(w,p+Vector3(0.12,0.23,0),Vector3(0.5,0.28,0.46),HEDGE.lightened(0.05))

static func _orchard(w) -> void:
	for x in [-30.0,-23.0]:
		for z in [-2.0,4.0,10.0,16.0]:
			w._tree(Vector3(x,0,z),0.90)
			# Dark mulch and a few windfalls tie each tree to the meadow.
			w._sphere(w,Vector3(x,0.022,z),Vector3(1.1,0.025,1.05),Color("939265"))
			for i in range(3): w._sphere(w,Vector3(x+0.45+i*0.16,0.1,z+0.65),Vector3.ONE*0.11,Color("be9157"))
	_hedge(w,Vector3(-35.4,0,-2),Vector3(-35.4,0,18.2))
	_hedge(w,Vector3(-34.5,0,18.2),Vector3(-29,0,18.2))
	_hedge(w,Vector3(-26,0,18.2),Vector3(-21.2,0,18.2))
	var store: Node3D = w._root("OrchardWorkCorner",Vector3(-23.5,0,19.2))
	w._crate(store,Vector3.ZERO,true)
	w._crate(store,Vector3(1.2,0,0),false)
	w._crate(store,Vector3(0.1,0.8,0),false)
	w._box(store,Vector3(2.5,0.7,0),Vector3(2.1,0.12,0.7),WOOD)
	for x in [1.65,3.35]: w._box(store,Vector3(x,0.35,0),Vector3(0.12,0.7,0.5),WOOD.darkened(0.18))

static func _ridge(w) -> void:
	for x in [-25,-19,-13,12,19,25]:
		var first: int = w.get_child_count()
		w._tree(Vector3(x,w.ground_height(x,-22.6),-22.6),0.85)
		w.get_child(first).rotation.z = -0.15
	for pair in [[Vector3(-25.5,0,-25.0),Vector3(25.5,0,-25.0)],[Vector3(-25.5,0,-25.0),Vector3(-30,0,-18)],[Vector3(25.5,0,-25.0),Vector3(30,0,-18)]]:
		var a: Vector3 = pair[0]; var b: Vector3 = pair[1]
		var count: int = ceili(a.distance_to(b)/1.15)
		for i in range(count):
			var p: Vector3 = a.lerp(b,float(i)/count)
			if a.z == b.z and p.x > -8.6 and p.x < 7.0: continue
			p.y = w.ground_height(p.x,p.z)+0.22
			w._box(w,p,Vector3(1.10,0.44,0.50),STONE).rotation.y = -atan2(b.z-a.z,b.x-a.x)
			w._box(w,p+Vector3(0,0.28,0),Vector3(1.02,0.16,0.58),STONE.lightened(0.06)).rotation.y = -atan2(b.z-a.z,b.x-a.x)

static func _yard(w) -> void:
	w._ground_path(Vector3(27,0,0),Vector3(33,0,0),1.8)
	var yard: Node3D = w._root("FarmServiceYard",Vector3(31,0,2.7))
	for bay in range(2):
		var x: float = bay*2.2
		w._box(yard,Vector3(x,0.24,0),Vector3(1.65,0.45,1.7),Color("756449"))
		for z in [-0.8,0.8]:
			for rail in range(3): w._box(yard,Vector3(x,0.2+rail*0.24,z),Vector3(1.85,0.12,0.1),WOOD)
		for end in [-0.86,0.86]: w._box(yard,Vector3(x+end,0.48,0),Vector3(0.12,0.96,1.8),WOOD)
	for p in [Vector3(30,0,-2),Vector3(31.3,0,-2)]:
		w._cylinder(w,p+Vector3(0,0.55,0),0.48,0.43,1.1,Color("738b81"),10)
		w._cylinder(w,p+Vector3(0,1.1,0),0.45,0.45,0.06,Color("536a61"),10)
	for i in range(4): w._sphere(w,Vector3(33+(i%2)*0.7,0.35+(i/2)*0.5,-2.5),Vector3(0.7,0.6,0.85),Color("bdb08a"))
	_hedge(w,Vector3(35.5,0,-7),Vector3(35.5,0,17))
	for p in [Vector3(31,0,-8),Vector3(32,0,13),Vector3(29,0,16)]:
		p.y = w.ground_height(p.x,p.z)
		w._tree(p,0.95)

static func _low_shore(w) -> void:
	# A single continuous drainage line discharges beyond the south road.
	w._box(w,Vector3(24.6,-0.12,15.7),Vector3(0.38,0.045,14),Color("617b6b"))
	for x in [24.25,24.95]:
		w._box(w,Vector3(x,-0.06,15.7),Vector3(0.16,0.14,14),Color("8c8f65"))
	for i in range(5): w._box(w,Vector3(24.6,-0.015,20.2+i*0.4),Vector3(1.5,0.16,0.34),WOOD)
	var rng := RandomNumberGenerator.new(); rng.seed=1718
	for i in range(65):
		var x: float = rng.randf_range(9,33)
		var z: float = rng.randf_range(23.1,25.0)
		x = minf(x,w.Surface.half_width(z,1.3))
		var p := Vector3(x,w.ground_height(x,z),z)
		var height: float = rng.randf_range(0.38,0.85)
		w._bar(w,p,p+Vector3(0.11,height,0),0.027,Color("7b905a"))
		if i % 3 == 0: w._bar(w,p+Vector3(0.11,height*0.65,0),p+Vector3(0.14,height+0.15,0),0.055,Color("8a7048"))
	_hedge(w,Vector3(10.2,0,22.4),Vector3(19,0,22.4))

static func _verges(w) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed=1772
	for i in range(180):
		var p := Vector3(rng.randf_range(-36,36),0,rng.randf_range(-24,23))
		# Meadow details occupy working margins, leaving beds and lanes legible.
		if p.x > -20 and p.x < 29 and p.z > -18 and p.z < 22: continue
		if absf(p.x+27.5)<1.4 or p.z < -24.5 or absf(p.x) > w.Surface.half_width(p.z,1.5): continue
		p.y=w.ground_height(p.x,p.z)+0.12
		for j in range(2): w._leaf(w,p+Vector3(j*0.14,0,0),Vector3(0.07,0.27,0.06),HEDGE.lightened(0.1),-0.25+j*0.5)
		if i % 5 == 0: w._sphere(w,p+Vector3(0,0.15,0),Vector3.ONE*0.085,Color("e3d3a1"))
