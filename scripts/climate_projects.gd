extends RefCounted
## Local infrastructure. Rebuilt and merged by material only on purchase/upgrade.
const Ops = preload("res://scripts/climate_operations.gd")

static func tank_position(w) -> Vector3:
	return barn_position(w) + Vector3(-5.0, 0, 3.0)

static func tank_scale(level: int) -> Vector3:
	# Capacity upgrades widen the barrel without lifting its inlet above the gutter.
	return Vector3(1.0 + 0.14 * (level - 1), 1, 1.0 + 0.14 * (level - 1))

static func barn_position(w) -> Vector3:
	return w.layout_point(Vector3(-18, 0, -12) if w.current_island == 3 else (Vector3(-15, 0, -10) if w.current_island == 2 else Vector3(-12, 0, -8)))

static func drain_position(w) -> Vector3:
	return Vector3(-12.6, 0, 12.4) if w.current_island == 3 else Vector3(-10.2, 0, 9.5)

static func outlet_position(w) -> Vector3:
	return Vector3(drain_position(w).x, 0.13, (22.45 if w.current_island == 3 else 18.5) * w.LAND_SPACING)

static func trees_position(w) -> Vector3:
	return Vector3((w.plot_positions[0].x + w.plot_positions[-1].x) * 0.5, 0, w.plot_positions[0].z - 1.65)

static func sprinkler_position(w, patch: int) -> Vector3:
	for i in range(w.plot_positions.size()):
		if Ops.zone(i) == patch:
			return Vector3(w.plot_positions[0].x - 1.5, 0, w.plot_positions[i].z)
	return Vector3.ZERO

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
	root.position = tank_position(w)
	root.scale = tank_scale(level)
	var steel := Color("527f8a")
	var rim := Color("b8d1c9")
	w._box(root, Vector3(0, 0.16, 0), Vector3(3.7, 0.32, 3.6), Color("9ba79b"))
	w._cylinder(root, Vector3(0, 1.85, 0), 1.5, 1.5, 3.15, steel, 20)
	for y: float in [0.42, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.25]:
		w._cylinder(root, Vector3(0, y, 0), 1.54, 1.54, 0.07, rim, 20)
	w._cylinder(root, Vector3(0, 3.48, 0), 1.58, 0.9, 0.25, Color("d0ded4"), 20)
	w._cylinder(root, Vector3(0, 3.67, 0), 0.34, 0.34, 0.17, steel, 12)
	# A contrasting sight glass remains readable in both sunlight and rain.
	w._box(root, Vector3(0.65, 1.86, 1.40), Vector3(0.36, 2.16, 0.13), Color("dce0c7"))
	w._box(root, Vector3(0.65, 1.86, 1.49), Vector3(0.25, 2.03, 0.055), Color("244e5b"))
	for y: float in [0.88, 1.37, 1.86, 2.35, 2.84]:
		w._box(root, Vector3(0.98, y, 1.46), Vector3(0.18, 0.04, 0.06), Color("edf0ce"))
	w._bar(root, Vector3(-0.4, 1.33, 1.45), Vector3(-0.4, 1.33, 1.95), 0.10, rim)
	w._bar(root, Vector3(-0.4, 1.33, 1.95), Vector3(-0.4, 1.05, 1.95), 0.10, rim)
	w._box(root, Vector3(-0.4, 1.52, 1.77), Vector3(0.46, 0.07, 0.1), Color("d8ad65"))
	# A permanent pipe fitting makes the source of the irrigation line tangible.
	w._bar(root, Vector3(1.35, 0.39, 0), Vector3(1.9, 0.28, 0), 0.10, rim)
	if level >= 2:
		w._box(root, Vector3(-0.75, 2.5, 1.32), Vector3(0.63, 0.38, 0.09), Color("cfaf6e"))
		for i in range(level - 1):
			w._cylinder(root, Vector3(-0.89 + i * 0.28, 2.52, 1.40), 0.07, 0.07, 0.04, Color("f9e7ad"), 8).rotation.x = PI * 0.5
	if level >= 3:
		w._cylinder(root, Vector3(-1.85, 1.03, -0.6), 0.60, 0.60, 1.7, steel, 16)
		w._cylinder(root, Vector3(-1.85, 1.93, -0.6), 0.64, 0.43, 0.18, rim, 16)
		w._bar(root, Vector3(-1.1, 0.6, -0.6), Vector3(-1.85, 0.6, -0.6), 0.12, rim)
	w._target(root, Vector3(0, 1.8, 0), Vector3(3.6, 3.6, 3.6), "station", "equipment:tank")

static func _channel(w, root: Node3D, pos: Vector3, length: float, sideways: bool = false) -> void:
	var segment := Node3D.new()
	root.add_child(segment)
	segment.position = pos
	if sideways: segment.rotation.y = PI * 0.5
	w._box(segment, Vector3(0, 0.04, 0), Vector3(0.60, 0.07, length), Color("45656a"))
	w._box(segment, Vector3(0, 0.085, 0), Vector3(0.32, 0.025, length), Color("668f8a"))
	for x: float in [-0.27, 0.27]:
		w._box(segment, Vector3(x, 0.15, 0), Vector3(0.12, 0.24, length), Color("b9bfa9"))
	for index: int in range(int(length)):
		w._box(segment, Vector3(0, 0.23, -length * 0.5 + 0.5 + index), Vector3(0.65, 0.06, 0.11), Color("839891"))

static func _drainage(w, root: Node3D, level: int) -> void:
	var gate: Vector3 = drain_position(w)
	var right: float = w.plot_positions[-1].x + 1.5
	var back: float = w.plot_positions[0].z - 1.15
	_channel(w, root, Vector3(gate.x, 0, (gate.z + back) * 0.5), gate.z - back)
	_channel(w, root, Vector3((gate.x + right) * 0.5, 0, gate.z), right - gate.x, true)
	if level >= 2:
		_channel(w, root, Vector3(right, 0, (gate.z + back) * 0.5), gate.z - back)
		_channel(w, root, Vector3((gate.x + right) * 0.5, 0, back), right - gate.x, true)
	var outlet: Vector3 = outlet_position(w)
	_channel(w, root, Vector3(gate.x, 0, (gate.z + outlet.z) * 0.5), outlet.z - gate.z)
	# Timber guides and a brass handwheel give the opening gate a clear silhouette.
	for x: float in [-0.47, 0.47]:
		w._box(root, gate + Vector3(x, 0.78, 0), Vector3(0.15, 1.56, 0.29), Color("718b80"))
	w._box(root, gate + Vector3(0, 1.53, 0), Vector3(1.15, 0.14, 0.3), Color("d5d6b2"))
	w._bar(root, gate + Vector3(0, 0.9, 0), gate + Vector3(0, 1.98, 0), 0.065, Color("c5cdb1"))
	w._cylinder(root, gate + Vector3(0, 2.02, 0), 0.33, 0.33, 0.1, Color("e8c879"), 12)
	w._box(root, outlet + Vector3(0, -0.2, 0), Vector3(0.8, 0.5, 0.65), Color("bcc4ae"))
	w._target(root, gate + Vector3(0, 1.0, 0), Vector3(1.35, 2.1, 1.1), "station", "equipment:drain")

static func _barn(w, root: Node3D, level: int) -> void:
	root.position = barn_position(w)
	w._target(root, Vector3(0, 2, 2.65), Vector3(4.5, 2.8, 0.4), "station", "equipment:barn")
	var metal := Color("537783")
	for x: float in [-2.72, 2.72]:
		for z: float in [-2.04, 2.04]:
			w._box(root, Vector3(x, 1.95, z), Vector3(0.25, 3.9, 0.25), metal)
		w._bar(root, Vector3(x, 0.45, -1.9), Vector3(x, 3.4, 1.9), 0.09, metal)
		w._bar(root, Vector3(x, 0.45, 1.9), Vector3(x, 3.4, -1.9), 0.09, metal)
	w._box(root, Vector3(0, 3.08, 2.46), Vector3(5.65, 0.20, 0.2), metal)
	if level >= 2:
		for x: float in [-2.0, 0.0, 2.0]:
			w._bar(root, Vector3(x, 3.89, 2.57), Vector3(x, 5.36, 0), 0.10, metal)
			w._bar(root, Vector3(x, 5.36, 0), Vector3(x, 3.89, -2.57), 0.10, metal)

static func _windbreaks(w, root: Node3D, level: int) -> void:
	root.position = trees_position(w)
	var winter: bool = w.current_island == 3
	var width: float = w.plot_positions[-1].x - w.plot_positions[0].x + 0.6
	var count: int = (10 if winter else 8) if level >= 2 else (8 if winter else 6)
	for index: int in range(count):
		var x: float = -width * 0.5 + width * index / float(count - 1)
		var height: float = 1.0 + sin(index * 2.3) * 0.12
		w._cylinder(root, Vector3(x, 0.91, 0), 0.14, 0.10, 1.8, Color("82664e"), 7)
		w._sphere(root, Vector3(x, 2.0 * height, 0), Vector3(0.94, 1.12 if level >= 2 else 0.90, 0.59), Color("407e68") if index % 2 == 0 else Color("5e946a"))
		w._sphere(root, Vector3(x - 0.14, 2.64 * height, 0.02), Vector3(0.63, 0.58, 0.48), Color("80ab76"))
		if winter:
			w._sphere(root, Vector3(x - 0.14, 3.04 * height, 0.02), Vector3(0.57, 0.15, 0.43), Color("e5efec"))
		if index > 0:
			w._box(root, Vector3(x - width / float(count - 1) * 0.5, 0.6, 0.08), Vector3(width / float(count - 1), 0.09, 0.08), Color("a68c65"))
	w._target(root, Vector3(0, 1.6, 0), Vector3(width + 1.0, 3.1, 1.1), "station", "equipment:trees")

static func _irrigation(w, root: Node3D, level: int) -> void:
	var columns: int = 10 if w.current_island == 3 else (8 if w.current_island == 2 else 6)
	var source: Vector3 = tank_position(w) + Vector3(0, 0.28, 0)
	var left: float = w.plot_positions[0].x - 1.5
	var end_z: float = w.plot_positions[-1].z
	w._bar(root, source, Vector3(left, 0.28, source.z), 0.085, Color("387776"))
	w._bar(root, Vector3(left, 0.28, minf(source.z, w.plot_positions[0].z - 0.9)), Vector3(left, 0.28, end_z), 0.085, Color("387776"))
	for patch in range(3):
		var point: Vector3 = sprinkler_position(w, patch)
		w._cylinder(root, point + Vector3(0, 0.52, 0), 0.13, 0.13, 0.9, Color("547f80"), 8)
		w._cylinder(root, point + Vector3(0, 0.98, 0), 0.39, 0.31, 0.17, Color("eac271"), 10)
		w._bar(root, point + Vector3(-0.32, 1.10, 0), point + Vector3(0.32, 1.10, 0), 0.055, Color("cde2d5"))
		w._box(root, point + Vector3(0, 0.64, 0.17), Vector3(0.46, 0.36, 0.06), Color("e9e0b4"))
		for mark in range(patch + 1):
			w._box(root, point + Vector3(-patch * 0.065 + mark * 0.13, 0.64, 0.21), Vector3(0.06, 0.17, 0.03), Color("527f80"))
		if level >= 2:
			w._cylinder(root, point + Vector3(0, 0.23, 0), 0.27, 0.23, 0.22, Color("cdad69"), 10)
		w._target(root, point + Vector3(0, 0.8, 0), Vector3(1.25, 1.65, 1.25), "station", "equipment:sprinkler%d" % patch)
	for index in range(w.plot_positions.size()):
		var pos: Vector3 = w.plot_positions[index]
		if index % columns == 0:
			# Every row reaches the main pipe; no floating, unconnected hoses.
			w._bar(root, Vector3(left, 0.28, pos.z - 0.9), pos + Vector3((columns - 1) * 2.3 + 0.9, 0.28, -0.9), 0.046, Color("477f77"))
		w._bar(root, pos + Vector3(-0.88, 0.28, -0.9), pos + Vector3(-0.88, 0.28, 0.85), 0.035, Color("477f77"))
		w._cylinder(root, pos + Vector3(-0.88, 0.35, 0), 0.12 if level >= 2 else 0.085, 0.08, 0.13, Color("eac271") if level >= 2 else Color("a6c5ac"), 6)
