extends Node3D
## A visible forecast terminal and protection supplier, separate from tax collection.
var world
var dish: Node3D
var clock: float = 0.0
var status: Label3D
func setup(w) -> void:
	world = w
	name = "WeatherStation"
	position = world.layout_point(Vector3(18, 0, -5) if world.current_island == 2 else Vector3(22, 0, -7))
	world._box(self, Vector3(0,0.12,0), Vector3(3.5,0.24,3.3), Color("8ca7a4"))
	world._box(self, Vector3(0,0.9,0), Vector3(1.6,1.6,1.4), Color("496d7c"))
	world._box(self, Vector3(0,1.1,0.74), Vector3(1.25,0.75,0.09), Color("193d42"))
	for i in range(4):
		world._box(self,Vector3(-0.42+i*0.28,0.94+i*0.1,0.81),Vector3(0.13,0.1+i*0.14,0.035),Color("a6e3c4"))
	dish = Node3D.new()
	add_child(dish)
	dish.position = Vector3(0,2.1,0)
	world._cylinder(dish,Vector3.ZERO,0.13,0.2,0.8,Color("b2c7c4"),8)
	var bowl := Node3D.new()
	dish.add_child(bowl)
	bowl.position.y = 0.55
	bowl.rotation.x = -0.6
	world._sphere(bowl,Vector3.ZERO,Vector3(1.15,0.19,1.15),Color("e1e9dc"))
	world._cylinder(bowl,Vector3(0,0.12,0),1.05,1.05,0.035,Color("8eafba"),20)
	for side in [-1,1]: world._bar(bowl,Vector3(side*0.9,0.16,0),Vector3(0,1.1,0),0.045,Color("e8e7c6"))
	world._sphere(bowl,Vector3(0,1.1,0),Vector3.ONE*0.15,Color("eec776"))
	status = world._shop_label(self,"Weather & protection",Vector3(0,4.5,0))
	world._target(self,Vector3(0,1.5,0),Vector3(3.5,3.3,3.3),"station","climate")
	world._geometry_batcher.batch_tree(dish,{})
func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(dish): dish.rotation.y = sin(clock*0.65)*0.65
