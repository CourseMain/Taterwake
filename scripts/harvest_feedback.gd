extends Node3D
## Visual receipts for committed harvests; animation never owns crop inventory.
const MAX_HARVESTS: int = 12
const MAX_CLODS: int = 64
var world
var active: Array[Dictionary] = []
var clods: Array[Dictionary] = []
var audio: Node
var pull_pose: float = 0

func setup(owner_world) -> void:
	world = owner_world
	name = "HarvestFeedback"
	audio = preload("res://scripts/farm_audio.gd").new()
	add_child(audio)

func harvest(snapshots: Dictionary) -> void:
	var heavy_sound: bool = false
	for raw_index in snapshots:
		var index: int = int(raw_index)
		var plot: Dictionary = snapshots[raw_index]
		if index < 0 or index >= world.plot_positions.size() or int(plot.get("stage", 0)) != 3: continue
		var heavy: bool = plot.get("crop") == "giant"
		heavy_sound = heavy_sound or heavy
		# Repeated partial harvests replace their own receipt. Big tools have a
		# hard visual budget, independent of field size and stored crop count.
		for i in range(active.size() - 1, -1, -1):
			if int(active[i].index) == index: _remove(i)
		if active.size() >= MAX_HARVESTS: _remove(0)
		var body := Node3D.new()
		body.name = "GiantHarvest" if heavy else "PotatoHarvest"
		add_child(body)
		# Match the planted tuber's silhouette, color and size at the instant of
		# harvest. The wrapper supplies the pull/flight pivot at its body center.
		var size: float = world._crop_tuber_size(plot)
		var tuber: Node3D = world._create_crop_tuber(body, plot)
		tuber.scale = Vector3.ONE * size
		tuber.position.y = -.58 * size
		var origin: Vector3 = world.plot_positions[index] + Vector3(0,.25 + .58 * size,0)
		var tag := Label3D.new()
		tag.text = preload("res://scripts/crop_quality.gd").grade(int(plot.get("quality", 100)))
		tag.name = "HarvestGrade"
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 42
		tag.pixel_size = 0.026
		tag.no_depth_test = true
		tag.position.y = 0.9
		body.add_child(tag)
		body.position = origin
		active.append({"node":body, "index":index, "origin":origin, "age":0.0, "heavy":heavy, "size":size, "popped":false, "landed":false})
	if not snapshots.is_empty(): audio.play_action("giant" if heavy_sound else "harvest")

func _remove(index: int) -> void:
	var node: Node3D = active[index].node
	node.hide()
	node.queue_free()
	active.remove_at(index)

func _scatter(at: Vector3, count: int, heavy: bool) -> void:
	for i in range(count):
		if clods.size() >= MAX_CLODS: break
		var angle: float = i * 2.39996
		var spread: float = (1.6 if heavy else 1.0) + float(i % 3) * .35
		var size: Vector3 = Vector3(.095,.065,.08) * (1.4 if heavy else 1.0)
		var piece: Node3D = world._sphere(self, at, size, Color("715239") if i % 2 else Color("a07b51"))
		clods.append({"node":piece, "age":0.0, "size":size, "velocity":Vector3(cos(angle)*spread,1.6+float(i%3)*.4,sin(angle)*spread)})

func animate(delta: float) -> void:
	pull_pose = 0
	for i in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[i]
		entry.age += delta
		var t: float = entry.age
		var pull: float = .32 if entry.heavy else .18
		var flight: float = .48 if entry.heavy else .36
		var body: Node3D = entry.node
		var origin: Vector3 = entry.origin
		if t < pull:
			var tension: float = t / pull
			body.position = origin + Vector3(sin(tension*PI*5)*.035, tension*.11,0)
			body.scale = Vector3(1-tension*.08,1+tension*.16,1-tension*.08)
			body.rotation.z = sin(tension*PI*4)*.09
			pull_pose = maxf(pull_pose, sin(tension*PI)*.9)
		elif t < pull + flight:
			var arc: float = (t-pull)/flight
			body.position = origin + Vector3(.22*arc, sin(arc*PI)*(2.0 if entry.heavy else 1.15), .16*arc)
			body.scale = Vector3.ONE
			body.rotation.z = sin(arc*TAU)*(.18 if entry.heavy else .35)
		else:
			var settle: float = t-pull-flight
			var squash: float = sin(minf(1,settle/.20)*PI) * (.26 if entry.heavy else .13)
			body.position = origin + Vector3(.22, -.05,.16)
			body.scale = Vector3(1+squash,1-squash,1+squash)
			body.rotation.z = -.07
			if settle > .22: body.scale *= maxf(.001, 1-(settle-.22)/.18)
			if settle >= .4:
				_remove(i)
				continue
		if t >= pull and not entry.popped:
			entry.popped = true
			_scatter(origin, 7 if entry.heavy else 4, entry.heavy)
		if t >= pull+flight and not entry.landed:
			entry.landed = true
			_scatter(origin + Vector3(.22,-.1,.16), 9 if entry.heavy else 3, entry.heavy)
	for i in range(clods.size() - 1, -1, -1):
		var entry: Dictionary = clods[i]
		entry.age += delta
		var node: Node3D = entry.node
		if entry.age >= .7:
			node.queue_free()
			clods.remove_at(i)
			continue
		node.position += Vector3(entry.velocity)*delta
		entry.velocity.y -= delta*9
		if node.position.y < .24:
			node.position.y = .24
			entry.velocity = Vector3.ZERO
		node.rotation.z += delta*3
		node.scale = Vector3(entry.size)*minf(1,(.7-float(entry.age))/.2)
