extends Node3D
## Compact sensor tower; cyan instruments stay distinct from the village shops.
var world
var dish: Node3D
var clock: float = 0.0
var status: Label3D
const STEEL := Color("263b51")
const DARK := Color("101e31")
const CYAN := Color("67e4fa")
const WHITE := Color("c6dcea")
func setup(w) -> void:
	world = w
	name = "WeatherStation"
	position = world.layout_point(Vector3(18, 0, -5) if world.current_island == 2 else Vector3(22, 0, -7))
	world._cylinder(self, Vector3(0,0.14,0), 1.9,1.9,0.28,DARK,6)
	world._cylinder(self, Vector3(0,0.31,0), 1.7,1.7,0.08,STEEL,6)
	for side in [-1,1]:
		_glow(world._box(self,Vector3(side*1.4,0.38,0),Vector3(0.06,0.06,1.8),CYAN))
		world._box(self,Vector3(side*0.78,1.08,0.12),Vector3(0.18,1.4,1.15),WHITE)
	world._box(self, Vector3(0,1.1,0), Vector3(1.5,1.6,1.2), STEEL)
	world._box(self, Vector3(0,1.25,0.66), Vector3(1.3,0.94,0.14), DARK)
	# Glass display, waveform and physical input strip.
	for i in range(7):
		var height: float = 0.15 + float((i*3)%5)*0.095
		_glow(world._box(self,Vector3(-0.5+i*0.165,1.08+height*0.5,0.75),Vector3(0.045,height,0.025),CYAN))
	_glow(world._box(self,Vector3(0,0.92,0.76),Vector3(1.05,0.025,0.025),CYAN))
	var console = world._box(self,Vector3(0,0.68,0.83),Vector3(1.4,0.16,0.48),DARK)
	console.rotation.x = -0.2
	for x in [-0.36,0,0.36]: _glow(world._box(self,Vector3(x,0.78,0.88),Vector3(0.18,0.03,0.12),CYAN))
	world._cylinder(self,Vector3(0,2.1,0),0.13,0.2,0.6,WHITE,10)
	_glow(world._cylinder(self,Vector3(0,1.94,0),0.34,0.34,0.08,CYAN,16))
	dish = Node3D.new()
	add_child(dish)
	dish.position = Vector3(0,2.3,0)
	var bowl := Node3D.new()
	dish.add_child(bowl)
	bowl.position.y = 0.35
	bowl.rotation.x = -0.55
	world._sphere(bowl,Vector3.ZERO,Vector3(1.05,0.19,1.05),WHITE)
	world._cylinder(bowl,Vector3(0,0.13,0),0.97,0.97,0.04,DARK,24)
	for i in range(16):
		var angle: float = TAU * i / 16.0
		_glow(world._sphere(bowl,Vector3(cos(angle)*0.95,0.16,sin(angle)*0.95),Vector3.ONE*0.045,CYAN))
	for side in [-1,1]: world._bar(bowl,Vector3(side*0.8,0.16,0),Vector3(0,0.95,0),0.035,WHITE)
	_glow(world._sphere(bowl,Vector3(0,0.95,0),Vector3.ONE*0.14,CYAN))
	# Independent sensor mast and photovoltaic fins fit inside the old footprint.
	world._bar(self,Vector3(1.15,0.35,-0.55),Vector3(1.15,2.55,-0.55),0.055,WHITE)
	_glow(world._sphere(self,Vector3(1.15,2.65,-0.55),Vector3.ONE*0.11,Color("ffbf69")))
	var solar = world._box(self,Vector3(-1.25,1.5,-0.2),Vector3(0.78,0.08,1.55),DARK)
	solar.rotation.z = -0.35
	for i in range(5):
		world._box(solar,Vector3(0,0.045,-0.61+i*0.3),Vector3(0.66,0.015,0.015),CYAN)
	status = world._shop_label(self,"Weather station",Vector3(0,4.35,0))
	world._target(self,Vector3(0,1.5,0),Vector3(3.5,3.3,3.3),"station","climate")
	world._geometry_batcher.batch_tree(dish,{})
func _glow(mesh: MeshInstance3D) -> void:
	var mat: StandardMaterial3D = mesh.material_override.duplicate()
	mat.emission_enabled = true
	mat.emission = CYAN
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(dish): dish.rotation.y = sin(clock*0.65)*0.65
