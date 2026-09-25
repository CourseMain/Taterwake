extends "res://scripts/farmer_avatar.gd"
## Shared close-up/world appearance. No portrait-only costume swaps.
const Roster = preload("res://scripts/npc_roster.gd")
var npc_id: String = ""
var speaking: bool = false
var expression: String = "warm"
var talk_mouth: MeshInstance3D
var _speech_blend: float = 0.0
var _brows: Array[Node3D] = []
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
	var body: String = "industrialist_overalls" if id in ["bram", "ada", "oren"] else ("investor_shirt" if id in ["edwin", "hollis"] else "gambler_shirt" if id == "rook" else "farmer_shirt")
	set_equipment({"head":p.hat, "body":body, "legs":"farmer_pants", "feet":"farmer_boots"}, {body:{"color":p.color}, "farmer_pants":{"color":"454f50"}, "farmer_boots":{"color":"695347"}})
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
