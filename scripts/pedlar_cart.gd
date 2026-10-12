extends Node3D
## One physical home: the cart. A first-year passer has no interaction target.
const Kit = preload("res://scripts/ui_kit.gd")
const Audio = preload("res://scripts/farm_audio.gd")
const PARK := Vector3(-1.0,0,11.4)
const ROUTE: Array[Vector3] = [Vector3(-12,0,20),Vector3(-12,0,14),Vector3(-5.5,0,11),Vector3(-12,0,14),Vector3(-12,0,22)]
var game
var world
var cart: Node3D
var actor: Node3D
var target: StaticBody3D
var pack_backs: Dictionary = {}
var superstition_hooks: Array[Node3D] = []
var _gate_signature: String = ""
var _wheels: Array[Node3D] = []
var bell_count: int = 0

func setup(owner_game) -> void:
	game = owner_game; world = game.world; name = "Pedlar"
	cart = Node3D.new(); cart.name = "FennicksCart"; add_child(cart)
	world._box(cart, Vector3(0,.76,0),Vector3(2.0,.24,1.2),Kit.WOOD)
	for x: float in [-.94,.94]: world._box(cart,Vector3(x,1.08,0),Vector3(.12,.65,1.2),Kit.WOOD2)
	world._box(cart,Vector3(0,1.08,-.55),Vector3(2.0,.65,.12),Kit.WOOD2)
	for x: float in [-1.04,1.04]:
		var wheel: Node3D = world._cylinder(cart,Vector3(x,.46,0),.45,.45,.14,Kit.WOOD2,12)
		wheel.rotation.z = PI*.5; _wheels.append(wheel)
		world._cylinder(cart,Vector3(x,.46,0),.12,.12,.19,Kit.KEEPERS.fennick,8).rotation.z = PI*.5
	for x: float in [-.7,.7]: world._bar(cart,Vector3(x,.7,-.55),Vector3(x,.6,-2.15),.055,Kit.WOOD)
	world._bar(cart,Vector3(-.7,.6,-2.15),Vector3(.7,.6,-2.15),.055,Kit.WOOD)
	world._bar(cart,Vector3(.88,1.25,-.45),Vector3(.88,2.2,-.45),.035,Kit.WOOD2)
	world._cylinder(cart,Vector3(.88,2.02,-.45),.13,.23,.28,Kit.KEEPERS.fennick,8)
	world._sphere(cart,Vector3(.88,1.83,-.45),Vector3.ONE*.06,Kit.INK)
	actor = preload("res://scripts/npc_avatar.gd").new(); cart.add_child(actor); actor.configure("fennick")
	actor.position = Vector3(0,0,-2.0); actor.rotation.y = PI
	world._staff_by_station.pedlar = actor
	for i in range(3):
		var pack := Node3D.new(); pack.name = ["SeedPackBack", "SuperstitionPackBack", "MysteryPackBack"][i]; cart.add_child(pack)
		pack.position = Vector3(-.65+i*.65,1.33,0)
		world._box(pack,Vector3.ZERO,Vector3(.53,.66,.10),Kit.PAPER)
		world._box(pack,Vector3(0,0,.061),Vector3(.46,.57,.025),Kit.PAPER2)
		if i == 0:
			world._sphere(pack,Vector3(0,-.05,.09),Vector3(.15,.19,.035),Kit.KEEPERS.fennick)
			world._bar(pack,Vector3(-.11,.12,.095),Vector3(.11,.12,.095),.018,Kit.INK)
		elif i == 1:
			for x: float in [-.11,0,.11]: world._cylinder(pack,Vector3(x,.03,.095),.07,0,.30,Kit.KEEPERS.fennick,5).rotation.x = -.15
		else: world._label(pack,"?",Vector3(0,0,.09),42,Kit.INK,false)
		pack_backs[game.state.Pedlar.PACK_IDS[i]] = pack
	world._target(cart,Vector3(0,1,0),Vector3(2.6,2.2,3.5),"station","pedlar")
	target = cart.get_child(cart.get_child_count()-1)
	sync_state()

func sync_state() -> void:
	if not is_instance_valid(game): return
	var state = game.state
	var presence: String = state.pedlar.presence(state)
	cart.visible = presence != "absent" and not game.title_active()
	target.visible = presence == "parked" and cart.visible
	target.collision_layer = 1 if target.visible else 0
	if presence == "parked": cart.position = PARK; cart.rotation.y = 0
	elif presence == "passing": _place_on_route(float(state.pedlar.data.passing_seconds))
	for id in pack_backs: pack_backs[id].visible = presence == "passing" or state.pedlar.unbought(state,id)
	var signature: String = state.farm_name() + str(state.pedlar.data.hooks)
	if signature != _gate_signature:
		_gate_signature = signature
		var sign: Label3D = world.title_gate.find_child("GateWordmark",true,false)
		if is_instance_valid(sign):
			sign.text = state.farm_name()
			sign.pixel_size = minf(.11,7.1/maxf(1,sign.font.get_string_size(sign.text,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x))
		_refresh_hooks()

func _refresh_hooks() -> void:
	for slot in superstition_hooks: slot.queue_free()
	superstition_hooks.clear()
	for i in range(5):
		var slot := Node3D.new(); slot.name = "GateSuperstitionHook" + str(i+1)
		world.title_gate.add_child(slot); slot.position = Vector3(-1.8+i*.9,2.02,.22)
		var id: String = str(game.state.pedlar.data.hooks[i]) if i < game.state.pedlar.data.hooks.size() else ""
		slot.set_meta("superstition",id)
		world._bar(slot,Vector3(0,.48,0),Vector3(0,.33,.10),.025,Kit.INK)
		world._bar(slot,Vector3(0,.33,.10),Vector3(0,.43,.16),.025,Kit.INK)
		if not id.is_empty():
			world._box(slot,Vector3.ZERO,Vector3(.65,.72,.035),Kit.PAPER)
			world._box(slot,Vector3(0,0,.024),Vector3(.53,.60,.015),Kit.PAPER2)
		if not id.is_empty():
			var edge: Color = Kit.RARITIES.common
			for rarity in game.state.Pedlar.SUPERSTITIONS:
				if id in game.state.Pedlar.SUPERSTITIONS[rarity]: edge = Kit.RARITIES[rarity]
			for x: float in [-.29,.29]: world._box(slot,Vector3(x,0,.04),Vector3(.055,.67,.025),edge)
			world._sphere(slot,Vector3(0,-.04,.06),Vector3(.14,.18,.025),Kit.KEEPERS.fennick)
			world._sphere(slot,Vector3(-.045,0,.087),Vector3.ONE*.02,Kit.PAPER)
			world._sphere(slot,Vector3(.045,0,.087),Vector3.ONE*.02,Kit.PAPER)
		superstition_hooks.append(slot)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(cart): return
	sync_state()
	if not cart.visible: return
	var state = game.state
	var passing: bool = state.pedlar.presence(state) == "passing"
	if passing:
		if game.hud.is_panel_open() or game.conversation.visible: return
		if state.pedlar.tick_pass(state,delta):
			bell_count += 1
			game.feedback_audio._play(preload("res://assets/audio/pedlar-bell.wav"),"pedlar:bell")
		_place_on_route(float(state.pedlar.data.passing_seconds))
		for wheel in _wheels: wheel.rotation.x += delta*2.4
	actor.animate(delta,passing)
	if passing:
		actor._arms[1].rotation.z = -1.35 + sin(float(state.pedlar.data.passing_seconds)*8)*.18

func _place_on_route(seconds: float) -> void:
	var progress: float = seconds / game.state.Pedlar.PASS_SECONDS * (ROUTE.size()-1)
	var index: int = mini(ROUTE.size()-2, floori(progress))
	cart.position = ROUTE[index].lerp(ROUTE[index+1],progress-index)
	var direction: Vector3 = ROUTE[index+1]-ROUTE[index]
	cart.rotation.y = atan2(-direction.x,-direction.z)
