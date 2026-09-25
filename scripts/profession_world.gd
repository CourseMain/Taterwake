extends Node3D
## Persistent small props, pooled result sign, and a tax visitor on the actual path.
var world
var props: Dictionary = {}
var jars: Array[Node3D] = []
var machine_tiers: Array[Node3D] = []
var charm: Node3D
var cargo: Node3D
var grade_sign: Label3D
var celebration: Node3D
var result_sign: Label3D
var visitor: Node3D
var visitor_avatar: Node3D
var visitor_label: Label3D
var tax_due: float = 0.0
var tax_exit: float = 0.0
var result_left: float = 0.0
var seen_event: int = 0
var clock: float = 0.0
var ship_left: float = 0.0
var tax_route: Array[Vector3] = []
var tax_length: float = 0.0
var cargo_route: Array[Vector3] = []
var cargo_length: float = 0.0

func group(id: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = id.capitalize()
	add_child(root)
	root.position = at
	props[id] = root
	return root

func setup(w) -> void:
	world = w
	name = "Professions"
	var compost := group("farmer", Vector3(-14.0 if world.current_island == 3 else -10.2,0,6.2))
	world._crate(compost, Vector3.ZERO, true)
	world._sphere(compost, Vector3(0,.66,0), Vector3(.65,.18,.5), Color("645440"))
	world._shop_label(compost,"Compost",Vector3(0,1.7,0))
	world._target(compost,Vector3(0,.7,0),Vector3(1.7,1.7,1.6),"station","profession:farmer")
	var bench := group("scientist", Vector3(-16.0 if world.current_island == 3 else -11.8,0,2.6))
	world._box(bench,Vector3(0,.85,0),Vector3(2.6,.20,1.3),Color("bd9b71"))
	for x in [-1.1,1.1]: world._box(bench,Vector3(x,.42,0),Vector3(.16,.85,1.1),Color("806343"))
	for i in range(3):
		var jar := Node3D.new()
		bench.add_child(jar)
		jar.position = Vector3(-.85+i*.85,1.1,0)
		world._cylinder(jar,Vector3(0,.2,0),.26,.26,.58,Color(["d8bd64","93bc77","89cbd5"][i]),8)
		world._cylinder(jar,Vector3(0,.53,0),.29,.29,.1,Color("496f63"),8)
		jars.append(jar)
	world._shop_label(bench,"Seed bank",Vector3(0,2.3,0))
	world._target(bench,Vector3(0,1,0),Vector3(2.8,2.3,1.8),"station","profession:scientist")
	var investor := group("investor", world.layout_point(Vector3(11.1,0,5)))
	world._box(investor,Vector3(0,1.1,0),Vector3(.18,2.2,.18),Color("947649"))
	world._box(investor,Vector3(0,1.55,0),Vector3(1.6,1.1,.15),Color("c3a16f"))
	world._box(investor,Vector3(0,1.55,.1),Vector3(1.25,.8,.04),Color("f0e3b8"))
	world._shop_label(investor,"Buyers",Vector3(0,2.7,0))
	world._target(investor,Vector3(0,1,0),Vector3(2,2.8,1),"station","profession:investor")
	cargo = Node3D.new()
	investor.add_child(cargo)
	cargo.position = Vector3(1.7,0,0)
	world._box(cargo,Vector3(0,-.02,0),Vector3(1.5,.15,1.2),Color("577b70"))
	for x in [-.65,.65]: world._sphere(cargo,Vector3(x,.06,0),Vector3(.16,.20,.28),Color("3e514e"))
	world._crate(cargo,Vector3.ZERO,true)
	world._crate(cargo,Vector3(0,.8,0),true)
	var table := group("gambler", world.layout_point(Vector3(10,0,-8) if world.current_island == 1 else (Vector3(13,0,-10) if world.current_island == 2 else Vector3(17,0,-12))) + Vector3(-2.7,0,3))
	world._cylinder(table,Vector3(0,.8,0),.9,.9,.16,Color("79618a"),12)
	world._box(table,Vector3(0,.35,0),Vector3(.4,.7,.4),Color("806343"))
	world._die(table,Vector3(-.23,1.05,0),.35,.3)
	world._die(table,Vector3(.25,1.05,.1),.35,-.4)
	charm = world._gem(table,Vector3(0,1.45,0),Color("efc968"),.18)
	world._shop_label(table,"Harvest stakes",Vector3(0,2,0))
	world._target(table,Vector3(0,.7,0),Vector3(2,1.8,2),"station","profession:gambler")
	var workshop: Node3D = world.get_node("WashAndSortWorkshop")
	var machine := group("industrialist", workshop.position)
	world._target(machine,Vector3(0,1.2,0),Vector3(4.8,2.5,3.0),"station","profession:industrialist")
	for i in range(2):
		var upgrade := Node3D.new()
		machine.add_child(upgrade)
		upgrade.position = Vector3(2.0+i*.6,.8,-.75)
		world._cylinder(upgrade,Vector3.ZERO,.23,.23,1.3,Color("c5a16b"),8)
		world._bar(upgrade,Vector3(0,.6,0),Vector3(-.9,.6,0),.08,Color("789f9b"))
		world._sphere(upgrade,Vector3(0,.77,0),Vector3(.25,.1,.25),Color("f0d786"))
		machine_tiers.append(upgrade)
	grade_sign = world._shop_label(self,"",workshop.position + Vector3(2,2.4,1.3))
	grade_sign.modulate = Color("f0cf7c")
	result_sign = world._shop_label(self,"",Vector3(0,3,5))
	result_sign.modulate = Color("fff0b8")
	result_sign.hide()
	celebration = Node3D.new()
	add_child(celebration)
	for i in range(10):
		var angle: float = i*TAU/10
		world._gem(celebration, Vector3(cos(angle)*1.8, sin(angle)*1.25,0),Color("f5d584"),.13 if i%2 else .2)
	world._geometry_batcher.batch_tree(celebration,{})
	celebration.hide()
	visitor = Node3D.new()
	visitor.name = "TaxCollector"
	add_child(visitor)
	visitor_avatar = world.FarmerAvatar.new()
	visitor.add_child(visitor_avatar)
	visitor_avatar.setup()
	visitor_avatar.set_equipment({"head":"traders_visor", "body":"scientist_coat", "feet":"industrialist_boots"}, {})
	world._box(visitor,Vector3(.8,.75,.15),Vector3(.5,.7,.16),Color("a78153"))
	world._box(visitor,Vector3(.8,.78,.25),Vector3(.4,.52,.025),Color("f3e5bd"))
	visitor_label = world._shop_label(visitor,"Tax collector",Vector3(0,2.7,0))
	world._target(visitor,Vector3(0,1,0),Vector3(1.8,2.4,1.5),"station","taxes")
	visitor.hide()
	for child in visitor.get_children():
		if child is StaticBody3D: child.collision_layer = 0
	tax_route = world.ferry_route()
	tax_route.reverse()
	if world.current_island == 1: tax_route.pop_back()
	cargo_route = world.walk_route(investor.position + Vector3(1.7,0,0), world.ferry_position(), true)
	cargo_route.push_front(investor.position + Vector3(1.7,0,0))
	for i in range(cargo_route.size()-1): cargo_length += cargo_route[i].distance_to(cargo_route[i+1])
	for i in range(tax_route.size()-1): tax_length += tax_route[i].distance_to(tax_route[i+1])
	for prop in props.values(): world._geometry_batcher.batch_tree(prop,{})

func refresh(builds, state) -> void:
	for id in props:
		var visible_prop: bool = int(builds.levels[id]) > 0
		props[id].visible = visible_prop
		for child in props[id].get_children():
			if child is StaticBody3D: child.collision_layer = 1 if visible_prop else 0
	var d: Dictionary = builds.professions.data
	for i in range(machine_tiers.size()): machine_tiers[i].visible = int(builds.levels.industrialist) >= (i+1)*10
	charm.visible = bool(d.charm)
	for i in range(jars.size()): jars[i].visible = ["hearty","dry","frost"][i] in d.seedbank
	cargo.visible = not d.contract.is_empty() or d.shipping > 0
	ship_left = d.shipping
	grade_sign.text = d.last_grade
	grade_sign.visible = int(builds.levels.industrialist) > 0 and not str(d.last_grade).is_empty()
	tax_due = float(state.blind_cycle.due_in)
	if tax_due > 0:
		visitor.show()
		visitor_label.text = "Tax collector · " + state.money(state.blind_info().tax)
	if seen_event != builds.professions.event_serial:
		seen_event = builds.professions.event_serial
		var event: Dictionary = builds.professions.event
		if not event.is_empty():
			result_sign.text = event.title
			var anchor: Vector3 = props[event.kind].position if props.has(event.kind) else world.get_node("WashAndSortWorkshop").position
			result_sign.position = anchor + Vector3(0,3.8,0)
			result_left = 3.5
			result_sign.show()
			celebration.position = anchor + Vector3(0,3.4,0)
			celebration.visible = event.kind == "scientist" or (event.kind == "industrialist" and str(d.last_grade).begins_with("S"))

func tax_collected(result: Dictionary, farm) -> void:
	tax_due = 0
	tax_exit = 5.0
	visitor.show()
	visitor_label.text = "Receipt · " + farm.money(result.tax)

func route_point(progress: float) -> Vector3:
	var distance: float = clampf(progress,0,1)*tax_length
	for i in range(tax_route.size()-1):
		var length: float = tax_route[i].distance_to(tax_route[i+1])
		if distance <= length: return tax_route[i].lerp(tax_route[i+1],distance/maxf(.001,length))
		distance -= length
	return tax_route.back()

func animate(delta: float) -> void:
	clock += delta
	if result_left > 0:
		result_left = maxf(0,result_left-delta)
		result_sign.modulate.a = minf(1,result_left)
		result_sign.scale = Vector3.ONE * (1 + maxf(0,result_left-3)*.25)
		result_sign.visible = result_left > 0
		celebration.scale = Vector3.ONE * ((3.5-result_left)*.35+.5)
		celebration.rotation.y += delta*.6
		if result_left < .7: celebration.hide()
	if visitor.visible:
		var before: Vector3 = visitor.position
		if tax_due > 0:
			tax_due = maxf(.001,tax_due-delta)
			visitor.position = route_point((10.0-tax_due)/10.0)
		elif tax_exit > 0:
			tax_exit = maxf(0,tax_exit-delta)
			visitor.position = route_point(tax_exit/5.0)
		else: visitor.hide()
		var direction: Vector3 = visitor.position-before
		if direction.length_squared() > .0001: visitor.rotation.y = lerp_angle(visitor.rotation.y, atan2(direction.x,direction.z), minf(1,delta*12))
		visitor_avatar.animate(delta,direction.length_squared()>.0001)
		for child in visitor.get_children():
			if child is StaticBody3D: child.collision_layer = 1 if visitor.visible else 0
	if ship_left > 0:
		ship_left = maxf(0,ship_left-delta)
		var distance: float = (1-ship_left/8.0)*cargo_length
		for i in range(cargo_route.size()-1):
			var length: float = cargo_route[i].distance_to(cargo_route[i+1])
			if distance <= length:
				cargo.global_position = cargo_route[i].lerp(cargo_route[i+1],distance/maxf(.001,length)) + Vector3(0,absf(sin(clock*8))*.035,0)
				break
			distance -= length
	else: cargo.position = Vector3(1.7,0,0)
	if is_instance_valid(charm): charm.rotation.y += delta*.8
	if grade_sign.visible: grade_sign.scale = Vector3.ONE*(1+sin(clock*2)*.025)
