extends "res://scripts/farmer_avatar.gd"
## Shared close-up/world appearance. No portrait-only costume swaps.
const Roster = preload("res://scripts/npc_roster.gd")
var npc_id: String = ""
var speaking: bool = false
var expression: String = "warm"
var talk_mouth: MeshInstance3D
var _speech_blend: float = 0.0
var _brows: Array[Node3D] = []
var _followers: Array[Dictionary] = []
var costume: Node3D
var _personality: float = 0.0

func configure(id: String) -> void:
	if _built: return
	npc_id = id
	var p: Dictionary = Roster.PEOPLE[id]
	skin_color = Color(p.skin)
	setup()
	name = p.name.replace(" ", "")
	scale = p.shape
	_personality = float(Roster.PEOPLE.keys().find(id)) * .71
	_time = _personality
	var style: String = "workshop" if id in ["bram", "ada", "oren"] else ("vest" if id in ["edwin", "hollis"] else "field")
	dress(style, Color(p.color), str(p.hat))
	var accessories := _group(_rig, "CharacterDetails")
	for side: float in [-1.0, 1.0]:
		var brow := _group(_head, "Brow")
		brow.position = Vector3(side*.20, 1.515, .35)
		_bar(brow, Vector3(-.075,0,0), Vector3(.075,.008,0), .023 if id in ["bram","oren"] else .014, Color("69503e"))
		_brows.append(brow)
	match str(p.detail):
		"glasses", "spectacles", "goggles":
			var goggles: bool = p.detail == "goggles"
			var y: float = 1.67 if goggles else 1.36
			var z: float = .31 if goggles else .489
			for side: float in [-1,1]:
				var rim := _torus(accessories,Vector3(side*.20,y,z),.12,.151 if goggles else .135,Color("665b50"))
				rim.rotation.x = PI*.5
			_bar(accessories,Vector3(-.07,y,z),Vector3(.07,y,z),.015,Color("bda977"))
			if not goggles:
				for side: float in [-1,1]: _bar(accessories,Vector3(side*.34,y,z),Vector3(side*.52,y,.12),.014,Color("665b50"))
		"flower":
			for i in range(5):
				var a: float = i*TAU/5
				_sphere(accessories,Vector3(.35+cos(a)*.065,1.84+sin(a)*.065,.32),Vector3(.055,.055,.02),Color("efb2a5"))
			_sphere(accessories,Vector3(.35,1.84,.35),Vector3(.034,.035,.015),Color("ffe3a0"))
		"scarf":
			_sphere(accessories,Vector3(0,1.08,.37),Vector3(.42,.07,.07),Color("f2cd88"))
			_sphere(accessories,Vector3(.28,.91,.48),Vector3(.065,.19,.035),Color("f2cd88"))
		"duck":
			_sphere(accessories,_front(-.23,.9,.07),Vector3(.09,.06,.025),Color("fff2c8"))
			_sphere(accessories,_front(-.18,.96,.10),Vector3(.044,.043,.02),Color("fff2c8"))
			_sphere(accessories,_front(-.13,.96,.10),Vector3(.035,.015,.02),Color("e29449"))
		"bow":
			for side: float in [-1,1]: _sphere(accessories,_front(side*.07,1.07,.075),Vector3(.08,.045,.023),Color("eac578"))
		"captain":
			_sphere(accessories,Vector3(0,1.78,0),Vector3(.44,.17,.35),Color("e6e5d5"))
			_sphere(accessories,Vector3(0,1.68,.3),Vector3(.39,.035,.24),Color("384d60"))
			_sphere(accessories,Vector3(0,1.79,.33),Vector3(.065,.05,.018),Color("e6c67d"))
		"beanie":
			_sphere(accessories,Vector3(0,1.73,-.02),Vector3(.44,.26,.35),Color("9da9a0"))
			var brim := _torus(accessories,Vector3(0,1.65,-.02),.34,.43,Color("ccd0b4"))
			brim.scale.z = .8
			_sphere(accessories,Vector3(0,2.0,-.02),Vector3.ONE*.11,Color("ccd0b4"))
		"headset":
			var band := _torus(accessories,Vector3(0,1.47,0),.43,.475,Color("41555a"))
			band.rotation.x = PI*.5
			for side: float in [-1,1]: _sphere(accessories,Vector3(side*.47,1.44,.03),Vector3(.095,.13,.10),Color("41555a"))
			_bar(accessories,Vector3(.49,1.39,.06),Vector3(.30,1.22,.49),.017,Color("41555a"))
			_sphere(accessories,Vector3(.29,1.22,.49),Vector3(.065,.028,.03),Color("41555a"))
	talk_mouth = _sphere(_head,Vector3(0,1.137,.493),Vector3(.081,.055,.014),Color("644638"))
	talk_mouth.hide()
	# Combine static costume parts; keep the mouth and articulated parent nodes live.
	preload("res://scripts/world_geometry_batcher.gd").new().batch_tree(self, {talk_mouth.get_instance_id():true})

func animate(delta: float, moving: bool = false, sprint: float = 0.0) -> void:
	super.animate(delta, moving, sprint)
	_update_followers()
	if not is_instance_valid(talk_mouth): return
	_speech_blend = lerpf(_speech_blend,1.0 if speaking else 0.0,1.0-exp(-delta*15.0))
	var syllable: float = .24 + .76*absf(sin(_time*15.0+_personality)*cos(_time*5.3))
	talk_mouth.visible = _speech_blend > .08
	_mouth.visible = not talk_mouth.visible
	talk_mouth.scale = Vector3(.081,.055,.014) * Vector3(.82+.18*syllable,maxf(.05,syllable*_speech_blend),1)
	_rig.rotation.y = sin(_time*1.8+_personality)*.045*_speech_blend
	_rig.rotation.x += sin(_time*3.2)*.018*_speech_blend
	_arms[1].rotation.z += (.14+sin(_time*2.5)*.13)*_speech_blend
	_arms[1].rotation.x -= .25*_speech_blend
	for i in range(_brows.size()):
		_brows[i].rotation.z = (-1 if i == 0 else 1) * (.14 if expression == "concerned" else -.03) + sin(_time*2)*.035*_speech_blend
	_update_followers()

func _limb_part(parent: Node3D, limb: Node3D) -> Node3D:
	var part: Node3D = _group(parent, "Fitted_" + limb.name)
	part.transform = limb.transform
	_followers.append({"node": part, "limb": limb})
	return part

func _build_body(parent: Node3D, id: String, palette: Dictionary) -> void:
	_body_band(parent, 0.60, 1.065, palette.main, 1.042)
	for index in range(_arms.size()):
		var sleeve: Node3D = _limb_part(parent, _arms[index])
		_sphere(sleeve, Vector3(0, -0.11, 0.025), Vector3(0.153, 0.16, 0.171), palette.main)
		_sphere(sleeve, Vector3(0, -0.21, 0.025), Vector3(0.155, 0.036, 0.174), palette.trim)
	for side: float in [-1.0, 1.0]:
		_sphere(parent, _front(side * 0.245, 0.80, 0.035), Vector3(0.113, 0.102, 0.021), palette.main.darkened(0.14))
		_bar(parent, _front(side * 0.245 - 0.075, 0.85, 0.061), _front(side * 0.245 + 0.075, 0.85, 0.061), 0.010, palette.trim)
	if id == "workshop":
		_sphere(parent, _front(0, 0.95, 0.043), Vector3(0.25, 0.145, 0.025), palette.main.lightened(0.14))
		for side: float in [-1.0, 1.0]:
			_bar(parent, _front(side * 0.215, 0.94, 0.065), _front(side * 0.25, 1.13, 0.024), 0.038, palette.trim)
			_sphere(parent, _front(side * 0.215, 0.98, 0.095), Vector3.ONE * 0.024, Color("e7dbc4"))
	elif id == "vest":
		for side: float in [-1.0, 1.0]:
			_bar(parent, _front(side * 0.15, 1.055, 0.033), _front(side * 0.075, 0.86, 0.044), 0.032, Color("fff0d0"))
	for y: float in [0.79, 0.89, 0.99]:
		_sphere(parent, _front(0, y, 0.051), Vector3(0.021, 0.021, 0.015), palette.trim)

func _build_pants(parent: Node3D, palette: Dictionary) -> void:
	_body_band(parent, 0.215, 0.67, palette.main, 1.039)
	_body_band(parent, 0.63, 0.69, palette.trim.darkened(0.15), 1.047)
	_sphere(parent, _front(0, 0.663, 0.037), Vector3(0.053, 0.037, 0.022), palette.trim)
	for index in range(_legs.size()):
		var leg: Node3D = _limb_part(parent, _legs[index])
		_sphere(leg, Vector3(0, -0.065, 0), Vector3(0.17, 0.175, 0.18), palette.main)
		_sphere(leg, Vector3(0, -0.09, 0.164), Vector3(0.075, 0.055, 0.015), palette.main.lightened(0.2))

func _build_boots(parent: Node3D, palette: Dictionary) -> void:
	for limb in _legs:
		var boot: Node3D = _limb_part(parent, limb)
		var sole_color: Color = palette.main.darkened(0.35)
		_sphere(boot, Vector3(0, -0.274, 0.11), Vector3(0.215, 0.068, 0.302), sole_color)
		_sphere(boot, Vector3(0, -0.21, 0.115), Vector3(0.208, 0.136, 0.288), palette.main)
		_sphere(boot, Vector3(0, -0.13, 0.015), Vector3(0.184, 0.13, 0.195), palette.main)
		_sphere(boot, Vector3(0, -0.04, 0.015), Vector3(0.188, 0.035, 0.20), palette.trim)

func _build_hat(parent: Node3D, id: String, color: Color, trim: Color) -> void:
	if id == "visor":
		var band: MeshInstance3D = _torus(parent, Vector3(0, 1.655, -0.008), 0.325, 0.378, color)
		band.scale.z = 0.85
		_sphere(parent, Vector3(0, 1.65, 0.29), Vector3(0.43, 0.038, 0.285), color)
		_sphere(parent, Vector3(0, 1.66, 0.44), Vector3(0.35, 0.020, 0.115), trim)
		return
	if id == "cap":
		_sphere(parent, Vector3(0, 1.755, -0.045), Vector3(0.43, 0.218, 0.36), color)
		_sphere(parent, Vector3(0, 1.695, 0.30), Vector3(0.36, 0.035, 0.29), color.darkened(0.09))
		_sphere(parent, Vector3(0, 1.825, 0.293), Vector3(0.089, 0.070, 0.016), trim)
		for offset: Vector3 in [Vector3(-0.023, 0.0, 0), Vector3(0.023, 0.0, 0), Vector3(0, 0.030, 0)]:
			_sphere(parent, Vector3(0, 1.825, 0.312) + offset, Vector3(0.027, 0.029, 0.009), color.darkened(0.25))
		_sphere(parent, Vector3(0, 1.963, -0.045), Vector3(0.045, 0.020, 0.045), trim)
		return
	var brim: MeshInstance3D = _cylinder(parent, Vector3(0, 1.70, -0.02), 0.67 if id == "straw" else 0.55, 0.66 if id == "straw" else 0.54, 0.055, color)
	brim.scale.z = 0.84
	_sphere(parent, Vector3(0, 1.79, -0.03), Vector3(0.395, 0.213, 0.325), color.lightened(0.08))
	var ribbon: MeshInstance3D = _torus(parent, Vector3(0, 1.755, -0.03), 0.363, 0.403, Color("9b7048") if id == "straw" else trim)
	ribbon.scale.z = 0.84
	if id == "worklamp":
		_sphere(parent, Vector3(0, 1.82, 0.31), Vector3(0.101, 0.083, 0.045), Color("6d6b57"))
		_sphere(parent, Vector3(0, 1.82, 0.35), Vector3(0.072, 0.058, 0.018), Color("fff4bc"))

func _update_followers() -> void:
	for attachment in _followers:
		(attachment.node as Node3D).transform = (attachment.limb as Node3D).transform


func dress(style: String, color: Color, hat_style: String) -> void:
	_neutral_body.hide()
	_neutral_pants.hide()
	for foot in _neutral_feet: foot.hide()
	costume = _group(_rig, "VillageCostume")
	var trim: Color = {"workshop": Color("484f58"), "vest": Color("edc671"), "field": Color("ebcb7b")}[style]
	_build_body(costume, style, {"main": color, "trim": trim})
	_build_pants(costume, {"main": Color("454f50"), "trim": Color("ebcb7b")})
	_build_boots(costume, {"main": Color("695347"), "trim": Color("ebcb7b")})
	if not hat_style.is_empty():
		var tint: Color = {"straw": Color("e8c06c"), "cap": Color("6da067"), "visor": Color("73aec6"), "worklamp": Color("e0a34f")}[hat_style]
		_build_hat(costume, hat_style, tint, Color("f3da92"))
