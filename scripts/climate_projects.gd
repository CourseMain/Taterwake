extends RefCounted
## Local, purchased infrastructure. All geometry is rebuilt only on level changes.

static func build(world: Node3D, id: String, level: int) -> Node3D:
	var root: Node3D = world._root("Climate_" + id, Vector3.ZERO)
	root.set_meta("project", id)
	root.set_meta("level", level)
	match id:
		"irrigation": _irrigation(world, root, level)
		"rainwater": _rainwater(world, root, level)
		"drainage": _drainage(world, root, level)
		"barn": _barn(world, root, level)
		"windbreaks": _windbreaks(world, root, level)
	return root

static func _rainwater(w, root: Node3D, level: int) -> void:
	root.position = Vector3(-19.5, 0, -4.5) if w.current_island == 3 else Vector3(-16.2, 0, -4.8)
	var steel := Color("527f8a")
	var rim := Color("b8d1c9")
	# A full-height corrugated tank, concrete plinth, downpipe and front gauge.
	w._box(root, Vector3(0, 0.16, 0), Vector3(3.7, 0.32, 3.6), Color("9ba79b"))
	w._cylinder(root, Vector3(0, 1.85, 0), 1.5, 1.5, 3.15, steel, 20)
	for y: float in [0.42, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.25]:
		w._cylinder(root, Vector3(0, y, 0), 1.54, 1.54, 0.07, rim, 20)
	w._cylinder(root, Vector3(0, 3.48, 0), 1.58, 0.9, 0.25, Color("d0ded4"), 20)
	w._cylinder(root, Vector3(0, 3.67, 0), 0.34, 0.34, 0.17, steel, 12)
	w._box(root, Vector3(0.65, 1.86, 1.39), Vector3(0.24, 2.05, 0.10), Color("244e5b"))
	w._box(root, Vector3(0.65, 1.67, 1.46), Vector3(0.12, 1.57, 0.05), Color("8ce0e2"))
	for y: float in [1.0, 1.5, 2.0, 2.5]:
		w._box(root, Vector3(0.9, y, 1.44), Vector3(0.19, 0.045, 0.045), Color("edf0ce"))
	w._bar(root, Vector3(-0.4, 0.65, 1.45), Vector3(-0.4, 0.65, 1.95), 0.10, rim)
	w._bar(root, Vector3(-0.4, 0.65, 1.95), Vector3(-0.4, 0.36, 1.95), 0.10, rim)
	w._box(root, Vector3(-0.4, 0.86, 1.77), Vector3(0.46, 0.07, 0.1), Color("b97b55"))
	w._bar(root, Vector3(-1.45, 0.4, -0.6), Vector3(-1.45, 3.85, -0.6), 0.12, rim)
	w._bar(root, Vector3(-1.45, 3.85, -0.6), Vector3(-0.3, 3.85, -0.6), 0.12, rim)
	if level >= 2:
		# Level two adds a connected collector, pump and larger gutter.
		w._cylinder(root, Vector3(1.95, 1.03, -0.6), 0.67, 0.67, 1.7, steel, 16)
		w._cylinder(root, Vector3(1.95, 1.93, -0.6), 0.72, 0.45, 0.18, rim, 16)
		w._bar(root, Vector3(1.1, 0.6, -0.6), Vector3(2.0, 0.6, -0.6), 0.12, rim)
		w._box(root, Vector3(1.7, 0.47, 1.0), Vector3(0.9, 0.6, 0.7), Color("cead69"))
		w._box(root, Vector3(-0.6, 3.88, -0.6), Vector3(2.3, 0.18, 0.65), rim)
	w._target(root, Vector3(0, 1.8, 0), Vector3(3.6, 3.6, 3.6), "station", "climate")

static func _channel(w, root: Node3D, pos: Vector3, length: float, sideways: bool = false) -> void:
	var segment := Node3D.new()
	root.add_child(segment)
	segment.position = pos
	if sideways: segment.rotation.y = PI * 0.5
	w._box(segment, Vector3(0, 0.04, 0), Vector3(0.64, 0.07, length), Color("45656a"))
	w._box(segment, Vector3(0, 0.085, 0), Vector3(0.32, 0.025, length), Color("77bbc5"))
	for x: float in [-0.28, 0.28]:
		w._box(segment, Vector3(x, 0.15, 0), Vector3(0.12, 0.24, length), Color("a5b2aa"))
	for index: int in range(int(length / 1.0)):
		w._box(segment, Vector3(0, 0.23, -length * 0.5 + 0.5 + index), Vector3(0.65, 0.07, 0.11), Color("839891"))

static func _drainage(w, root: Node3D, level: int) -> void:
	var winter: bool = w.current_island == 3
	var left: float = -12.6 if winter else -10.2
	var right: float = 11.7 if winter else 9.2
	var front: float = 12.4 if winter else 9.5
	var back: float = -7.1 if winter else -5.55
	_channel(w, root, Vector3(left, 0, (front + back) * 0.5), front - back)
	_channel(w, root, Vector3((left + right) * 0.5, 0, front), right - left, true)
	if level >= 2:
		_channel(w, root, Vector3(right, 0, (front + back) * 0.5), front - back)
		_channel(w, root, Vector3((left + right) * 0.5, 0, back), right - left, true)
		w._box(root, Vector3(left, 0.15, front), Vector3(1.05, 0.3, 1.05), Color("6b817c"))
		for offset: float in [-0.3, 0.0, 0.3]:
			w._box(root, Vector3(left + offset, 0.33, front), Vector3(0.09, 0.07, 0.9), Color("c3cdc2"))
	w._target(root, Vector3(left, 0.3, front), Vector3(1.2, 0.65, 1.2), "station", "climate")

static func _barn(w, root: Node3D, level: int) -> void:
	root.position = Vector3(-18, 0, -12) if w.current_island == 3 else Vector3(-15, 0, -10)
	var metal := Color("537783")
	# Steel corner posts and side cross-braces reinforce the actual storage barn.
	for x: float in [-2.72, 2.72]:
		for z: float in [-2.04, 2.04]:
			w._box(root, Vector3(x, 1.95, z), Vector3(0.25, 3.9, 0.25), metal)
		w._bar(root, Vector3(x, 0.45, -1.9), Vector3(x, 3.4, 1.9), 0.09, metal)
		w._bar(root, Vector3(x, 0.45, 1.9), Vector3(x, 3.4, -1.9), 0.09, metal)
	w._box(root, Vector3(0, 3.16, 2.32), Vector3(5.65, 0.22, 0.16), metal)
	if level >= 2:
		for x: float in [-2.0, 0.0, 2.0]:
			w._bar(root, Vector3(x, 3.89, 2.57), Vector3(x, 5.36, 0), 0.10, metal)
			w._bar(root, Vector3(x, 5.36, 0), Vector3(x, 3.89, -2.57), 0.10, metal)
		for x: float in [-1.8, 1.8]:
			w._box(root, Vector3(x, 2.55, 2.34), Vector3(0.7, 0.87, 0.13), metal)
			for y: float in [2.3, 2.55, 2.8]:
				w._box(root, Vector3(x, y, 2.42), Vector3(0.55, 0.06, 0.04), Color("b5ccc4"))

static func _windbreaks(w, root: Node3D, level: int) -> void:
	var winter: bool = w.current_island == 3
	root.position = Vector3(-10.8, 0, -18.8) if winter else Vector3(-9.2, 0, -15.7)
	var count: int = 10 if level >= 2 else 6
	for index: int in range(count):
		var x: float = index * 2.25
		w._cylinder(root, Vector3(x, 1.1, 0), 0.13, 0.10, 2.2, Color("82664e"), 7)
		w._sphere(root, Vector3(x, 2.3, 0), Vector3(1.1, 1.5 if level >= 2 else 1.1, 0.85), Color("407e68") if index % 2 == 0 else Color("5e946a"))
		w._sphere(root, Vector3(x - 0.15, 3.08, 0), Vector3(0.75, 0.65, 0.65), Color("73a77c"))
		if winter:
			w._sphere(root, Vector3(x - 0.15, 3.5, 0), Vector3(0.65, 0.18, 0.55), Color("e5efec"))
		if index > 0:
			w._box(root, Vector3(x - 1.12, 0.75, 0.25), Vector3(2.25, 0.1, 0.1), Color("a68c65"))
	w._target(root, Vector3((count - 1) * 1.125, 1.5, 0), Vector3(count * 2.25, 3, 1.8), "station", "climate")

static func _irrigation(w, root: Node3D, level: int) -> void:
	var columns: int = 10 if w.current_island == 3 else 8
	for index in range(w.plot_positions.size()):
		var pos: Vector3 = w.plot_positions[index]
		if index % columns == 0:
			w._bar(root, pos + Vector3(-0.95, 0.28, -0.9), pos + Vector3((columns - 1) * 2.3 + 0.9, 0.28, -0.9), 0.04, Color("387776"))
		w._bar(root, pos + Vector3(-0.88, 0.28, -0.9), pos + Vector3(-0.88, 0.28, 0.85), 0.035, Color("387776"))
		if level >= 2:
			w._cylinder(root, pos + Vector3(-0.88, 0.36, 0), 0.12, 0.08, 0.15, Color("eac271"), 6)
