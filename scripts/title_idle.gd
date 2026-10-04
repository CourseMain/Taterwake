extends Node
## Presentation at the gate only; every pose is restored when the title closes.
var actors: Array[Dictionary] = []
var petals: Array[MeshInstance3D] = []
var petal_root: Node3D
var gate: Vector3

func start(world, spring: bool) -> void:
	stop()
	var people: Array = [world._npc_actors.mara, world._npc_actors.bram, world._player_body]
	for person in people:
		var eyes: Array[Vector3] = []
		for eye: Node3D in person._eyes: eyes.append(eye.scale)
		actors.append({"person":person, "rig":person._rig.transform, "eyes":eyes})
	if not spring: return
	gate = world.title_gate.global_position
	petal_root = Node3D.new()
	petal_root.name = "TitleBlossomPetals"
	world.add_child(petal_root)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("efb2ba")
	paper.roughness = .9
	for i in range(6):
		var petal := MeshInstance3D.new()
		petal.mesh = mesh
		petal.material_override = paper
		petal.scale = Vector3(.13, .025, .085)
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		petal_root.add_child(petal)
		petals.append(petal)
	advance(0)

func advance(seconds: float) -> void:
	for i in range(actors.size()):
		var record: Dictionary = actors[i]
		var person = record.person
		if not is_instance_valid(person): continue
		var breath: float = sin(seconds * TAU / 4.8 + i * 1.4)
		person._rig.transform = record.rig
		person._rig.position.y += breath * .035
		person._rig.scale *= Vector3(1.0 + breath * .004, 1.0 + breath * .008, 1.0 + breath * .004)
		var interval: float = 3.4 + i * .7
		var phase: float = fmod(seconds, interval)
		var openness: float = maxf(.06, absf((phase - (interval - .09)) / .09)) if phase > interval - .18 else 1.0
		for j in range(person._eyes.size()):
			person._eyes[j].scale = record.eyes[j] * Vector3(1, openness, 1)
	for i in range(petals.size()):
		var age: float = fmod(seconds + i * 2.1, 13.0)
		petals[i].position = gate + Vector3(-6.0 + age * .9, 7.0 - age * .35 + sin(age * .8 + i) * .22, 1.0 + i * .65)
		petals[i].rotation = Vector3(age * .5 + i, age * .3, sin(age + i) * .7)

func stop() -> void:
	for record: Dictionary in actors:
		var person = record.person
		if not is_instance_valid(person): continue
		person._rig.transform = record.rig
		for i in range(person._eyes.size()): person._eyes[i].scale = record.eyes[i]
	actors.clear()
	if is_instance_valid(petal_root):
		petal_root.hide()
		petal_root.queue_free()
	petal_root = null
	petals.clear()
