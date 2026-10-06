extends Node3D
## A timber forecast hut, with a working dish and a supported painted sign.
var world
var dish: Node3D
var clock: float = 0.0
var status: Label3D
var forecast_label: Label3D
var range_band: Node3D
var forecast_range := Vector2.ZERO
const WOOD := Color("79553d")
const PAPER := Color("f3efdf")
const IRIS := Color("5f9fd6")
func setup(w) -> void:
	world = w
	name = "WeatherStation"
	position = world.layout_point(Vector3(15, 0, -4) if world.current_island == 1 else (Vector3(18, 0, -5) if world.current_island == 2 else Vector3(22, 0, -7)))
	position.y = world.ground_height(position.x, position.z)
	world._box(self, Vector3(0,.12,0), Vector3(3.2,.24,2.5), WOOD.darkened(.18))
	world._box(self, Vector3(0,1.2,0), Vector3(2.8,2.2,2.1), WOOD)
	for x in [-1.4,1.4]:
		world._box(self, Vector3(x,1.25,0), Vector3(.14,2.5,2.2), WOOD.lightened(.16))
	for y in [.45,.8,1.15,1.5,1.85,2.2]:
		world._box(self, Vector3(0,y,1.065), Vector3(2.8,.025,.035), WOOD.darkened(.18))
	world._roof(self, 3.5, 2.8, 2.35, .8, WOOD.darkened(.25))
	# Recessed paper dial, framed in timber, receives the ordinary play light.
	world._box(self, Vector3(0,1.3,1.12), Vector3(1.7,1.05,.15), WOOD.darkened(.25))
	world._box(self, Vector3(0,1.3,1.21), Vector3(1.5,.85,.04), PAPER)
	forecast_label = world._label(self,"",Vector3(0,1.45,1.25),26,WOOD,false)
	world.bind_label(forecast_label, Vector2(1.35,.35))
	range_band = Node3D.new(); range_band.name = "ForecastRange"; add_child(range_band)
	range_band.position = Vector3(0,1.12,1.26)
	world._box(range_band, Vector3.ZERO, Vector3(1,.08,.035), IRIS)
	for x in [-.5,0,.5]: world._box(self,Vector3(x,1.0,1.25),Vector3(.025,.09,.035),WOOD)
	# A planted mast supports the small scanning dish beside the roof.
	world._cylinder(self,Vector3(1.05,1.9,-.55),.075,.075,4.0,WOOD,8)
	dish = Node3D.new(); dish.name = "ForecastDish"; add_child(dish)
	dish.position = Vector3(1.05,3.85,-.55)
	var bowl := Node3D.new(); dish.add_child(bowl); bowl.rotation.x = -.55
	world._sphere(bowl,Vector3.ZERO,Vector3(.72,.15,.72),IRIS)
	world._cylinder(bowl,Vector3(0,.1,0),.64,.64,.035,IRIS.darkened(.25),16)
	for side in [-1,1]: world._bar(bowl,Vector3(side*.5,.13,0),Vector3(0,.65,0),.025,WOOD)
	world._sphere(bowl,Vector3(0,.65,0),Vector3.ONE*.09,IRIS)
	status = world._hanging_sign(self,Vector3(0,0,2.0),"Weather station",IRIS,3.6)
	world._target(self,Vector3(0,1.5,0),Vector3(3.5,3.3,3.3),"station","climate")
	# Match other moving instruments; the hut, mast and sign cast solid shadows.
	for mesh: GeometryInstance3D in dish.find_children("*", "GeometryInstance3D", true, false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(dish): dish.rotation.y = sin(clock*.65)*.65
func set_forecast(forecast: Dictionary) -> void:
	if forecast.is_empty(): return
	forecast_range = Vector2(float(forecast.low),float(forecast.high))
	forecast_label.text = "%d–%d%%" % [roundi(forecast_range.x*100),roundi(forecast_range.y*100)]
	range_band.position.x = (forecast_range.x+forecast_range.y)*.5-.5
	range_band.scale.x = maxf(.015,forecast_range.y-forecast_range.x)
