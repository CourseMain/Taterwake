extends Node3D
## Persistent equipment plus lightweight flow ribbons in the field's 10 Hz mesh.
const Ops = preload("res://scripts/climate_operations.gd")
const Projects = preload("res://scripts/climate_projects.gd")
const AQUA := Color("91e0df")
const CREAM := Color("f2f3c4")
var world
var selected: String = ""
var flow_patch: int = -1
var flow_time: float = 0.0
var refill_time: float = 0.0
var clock: float = 0.0
var gate: MeshInstance3D
var gauge: MeshInstance3D
var gauge_surface: MeshInstance3D
var can: Node3D
var can_water: MeshInstance3D
var tank_label: Label3D
var can_label: Label3D
var practice_label: Label3D
var barn_label: Label3D
var shutters: Array[Node3D] = []
var info: Dictionary = {}
var displayed_can: float = -1.0
var displayed_water: float = -1.0
var gate_open: float = 0.0
var carry_offset := Vector3(-0.80, 0.46, 0.28)
var refill_blend: float = 0.0
var pour_blend: float = 0.0
var gutter_start: Vector3
var gutter_end: Vector3
var inlet: Vector3

func tank_position() -> Vector3:
	return Projects.tank_position(world)

func equipment_position(id: String) -> Vector3:
	if id.begins_with("sprinkler"):
		return Projects.sprinkler_position(world, int(id.trim_prefix("sprinkler")))
	if id == "drain": return Projects.drain_position(world)
	if id == "trees": return Projects.trees_position(world)
	if id == "barn": return Projects.barn_position(world) + Vector3(0, 0, 2.7)
	return tank_position()

func _label(parent: Node3D, point: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	parent.add_child(label)
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = world._shop_font
	label.font_size = size
	label.pixel_size = 0.026
	label.outline_size = 5
	label.outline_modulate = Color("244d48")
	label.modulate = Color("fff0cc")
	return label

func setup(w) -> void:
	world = w
	name = "ConnectedWaterLoop"
	gauge = world._box(self, tank_position() + Vector3(0.65, 1, 1.54), Vector3(0.22, 2, 0.035), AQUA)
	gauge.material_override = world._bright_material(AQUA)
	gauge_surface = world._box(self, Vector3.ZERO, Vector3(0.24, 0.045, 0.05), CREAM)
	gauge_surface.material_override = world._bright_material(CREAM)
	tank_label = _label(self, tank_position() + Vector3(0, 4.35, 0.45), 28)
	var barn: Vector3 = Projects.barn_position(world)
	# The long gutter follows the actual low eave, then falls into the lid inlet.
	gutter_start = barn + Vector3(-3.09, 3.88, -2.48)
	gutter_end = barn + Vector3(-3.09, 3.88, 2.48)
	inlet = tank_position() + Vector3(0, 3.72, 0)
	world._bar(self, gutter_start, gutter_end, 0.105, Color("b8d1c9"))
	world._bar(self, gutter_end, inlet + Vector3(0, 0.13, 0), 0.105, Color("b8d1c9"))
	world._bar(self, inlet + Vector3(0, 0.13, 0), inlet - Vector3(0, 0.15, 0), 0.12, Color("b8d1c9"))
	for side: int in [-1, 1]:
		var shutter := Node3D.new()
		add_child(shutter)
		shutter.position = barn + Vector3(side * 1.84, 1.58, 2.49)
		world._box(shutter, Vector3.ZERO, Vector3(1.12, 2.69, 0.12), Color("537783"))
		for y: float in [-1.1, -0.66, -0.22, 0.22, 0.66, 1.1]:
			world._box(shutter, Vector3(0, y, 0.09), Vector3(1.0, 0.075, 0.06), Color("95b2ac"))
		world._box(shutter, Vector3(-side * 0.34, 0, 0.16), Vector3(0.07, 0.42, 0.09), Color("e9d28e"))
		shutters.append(shutter)
	barn_label = _label(self, barn + Vector3(1.85, 3.32, 2.55), 22)
	barn_label.text = "AUTO"
	gate = world._box(self, equipment_position("drain") + Vector3(0, 0.59, 0), Vector3(0.78, 0.91, 0.16), Color("bd8c58"))
	for y: float in [-0.32, 0.32]:
		world._box(gate, Vector3(0, y, 0.11), Vector3(0.77, 0.07, 0.055), Color("dfce99"))
	can = Node3D.new()
	can.name = "CarriedWateringCan"
	add_child(can)
	world._cylinder(can, Vector3.ZERO, 0.30, 0.33, 0.51, Color("598e8b"), 12)
	world._cylinder(can, Vector3(0, 0.27, 0), 0.34, 0.34, 0.055, Color("d7d5aa"), 12)
	world._cylinder(can, Vector3(0, 0.30, 0), 0.22, 0.22, 0.012, Color("244e5b"), 12)
	world._bar(can, Vector3(0.20, -0.04, 0), Vector3(0.62, 0.30, 0), 0.075, Color("d7d5aa"))
	world._cylinder(can, Vector3(0.63, 0.32, 0), 0.145, 0.145, 0.07, Color("e8cc81"), 8)
	world._bar(can, Vector3(-0.27, 0.20, 0), Vector3(-0.27, 0.54, 0), 0.045, Color("d7d5aa"))
	world._bar(can, Vector3(-0.27, 0.54, 0), Vector3(0.16, 0.54, 0), 0.045, Color("d7d5aa"))
	world._box(can, Vector3(0, -0.015, 0.319), Vector3(0.23, 0.41, 0.045), Color("244e5b"))
	can_water = world._box(can, Vector3(0, -0.015, 0.347), Vector3(0.18, 0.37, 0.016), AQUA)
	can_water.material_override = world._bright_material(AQUA)
	can_label = _label(self, Vector3.ZERO, 25)
	practice_label = _label(self, Vector3.ZERO, 26)
	practice_label.name = "PracticeDestination"
	practice_label.no_depth_test = true
	practice_label.modulate = Color("fff0a3")
	practice_label.hide()
	# Merge decorative can/gutter/shutter details; keep the two liquid gauges mutable.
	world._geometry_batcher.batch_tree(can, {can_water.get_instance_id(): true})
	for shutter: Node3D in shutters: world._geometry_batcher.batch_tree(shutter, {})

func animate(data: Dictionary, delta: float) -> void:
	if data.is_empty(): return
	info = data
	clock += delta
	flow_time = maxf(0, flow_time - delta)
	refill_time = maxf(0, refill_time - delta)
	var p: Dictionary = info.projects
	var local_weather: bool = true
	var storm: bool = local_weather and info.event == "storm" and info.phase == "active"
	var scale_tank: Vector3 = Projects.tank_scale(int(p.get("rainwater", 0)) + 1)
	if displayed_water < 0: displayed_water = float(info.supply.water)
	if displayed_can < 0: displayed_can = float(info.supply.can)
	# Easing makes the transferred quantity visible instead of changing instantly.
	displayed_water = move_toward(displayed_water, float(info.supply.water), delta * 24)
	if refill_time <= 1.35:
		displayed_can = move_toward(displayed_can, float(info.supply.can), delta * (float(info.can_capacity) / 0.95 if refill_time > 0 else 12))
	var ratio: float = clampf(displayed_water / float(info.water_capacity), 0, 1)
	gauge.position = tank_position() + Vector3(0.65, 0.86 + ratio, 1.54) * scale_tank
	gauge.scale = Vector3(scale_tank.x, maxf(0.002, ratio), scale_tank.z)
	gauge_surface.position = tank_position() + Vector3(0.65, 0.87 + ratio * 2.0, 1.55) * scale_tank
	gauge_surface.scale = scale_tank
	tank_label.text = "Tank  %d / %d" % [floori(info.supply.water), int(info.water_capacity)]
	tank_label.modulate = Color("ffe18a") if selected == "tank" else Color("fff0cc")
	var pouring: bool = world._tool_time > 0 and world._tool_action == "water"
	var pour_target: float = pow(sin((1.0 - world._tool_time / world._tool_duration) * PI), 2) if pouring else 0.0
	pour_blend = lerpf(pour_blend, pour_target, 1.0 - exp(-delta * 22))
	var size_can: float = 0.85 + (float(info.can_capacity) - 16) / 192.0
	can.scale = Vector3.ONE * size_can
	var hand: Vector3 = world._player_body.hand_transform(true).origin
	var held: Vector3 = world.player.to_local(hand) + Vector3(-0.02, -0.43 * size_can, 0.02)
	carry_offset = carry_offset.lerp(held, 1.0 - exp(-delta * 18))
	var carry: Vector3 = world.player.to_global(carry_offset)
	var under_tap: Vector3 = tank_position() + Vector3(-0.4, 0.48, 1.95) * scale_tank
	# Ease into the tap and back to the hand, including if the player walks away.
	var near_tank: bool = world.player.position.distance_to(under_tap) < 3.2
	var refill_target: float = smoothstep(0, 0.32, refill_time) if near_tank else 0.0
	refill_blend = lerpf(refill_blend, refill_target, 1.0 - exp(-delta * 12))
	can.position = carry.lerp(under_tap, refill_blend)
	can.rotation = Vector3(0, world.player.rotation.y + PI, -pour_blend * 0.85).lerp(Vector3.ZERO, refill_blend)
	var fill: float = clampf(displayed_can / float(info.can_capacity), 0.001, 1)
	can_water.scale.y = fill
	can_water.position.y = -0.20 + 0.185 * fill
	can_label.position = world.player.position + Vector3(0, 2.95, 0)
	can_label.text = "%d / %d water" % [floori(info.supply.can), int(info.can_capacity)]
	can_label.visible = selected == "tank" or refill_time > 0 or world.get_meta("water_tool", false)
	can_label.modulate = Color("ffe18a") if float(info.supply.can) < 1 else Color("fff0cc")
	var lesson: String = str(info.lesson.stage)
	practice_label.visible = lesson in ["water", "area"] and selected.is_empty()
	if practice_label.visible:
		var target: Vector3 = world.plot_positions[18] if lesson == "water" else equipment_position("sprinkler2")
		practice_label.position = target + Vector3(0, 2.2 + sin(clock * 2.8) * 0.12, 0)
		practice_label.text = "Water this bed [3]" if lesson == "water" else "Click this sprinkler"
	gate.visible = int(p.get("drainage", 0)) > 0
	gate_open = move_toward(gate_open, 1.0 if info.supply.gates else 0.0, delta * 1.4)
	gate.position.y = 0.59 + gate_open * 0.9
	if world._project_nodes.has("windbreaks"):
		world._project_nodes.windbreaks.rotation.z = sin(clock * 2.5) * 0.012 if storm else 0.0
	var closed: bool = local_weather and info.phase in ["warning", "active"]
	for i in range(shutters.size()):
		shutters[i].visible = int(p.get("barn", 0)) > 0
		var side: float = -1.0 if i == 0 else 1.0
		var target_x: float = Projects.barn_position(world).x + side * (0.57 if closed else 1.84)
		shutters[i].position.x = move_toward(shutters[i].position.x, target_x, delta * 1.1)
	barn_label.visible = int(p.get("barn", 0)) > 0 and (selected == "barn" or closed)
	barn_label.text = "AUTO"
	# The saved hazard belongs to one island, never the same-numbered bed elsewhere.
	for i in range(world._crop_roots.size()):
		var crop: Node3D = world._crop_roots[i]
		var stress: float = float(info.operations.stress.get(str(i), 0)) if local_weather else 0.0
		var sheltered: bool = Ops.zone(i) == 0 and int(p.get("windbreaks", 0)) > 0
		var lean: float = stress * 0.45 if local_weather and info.event == "drought" else 0.0
		if storm: lean = sin(clock * 5 + i * 0.6) * (0.14 * (1.0 - 0.3 * int(p.get("windbreaks", 0))) if sheltered else 0.14)
		crop.rotation.z = lerpf(crop.rotation.z, lean, minf(1, delta * 7))

func _flow(v, a: Vector3, b: Vector3, teaching: bool = false, width: float = 0.085) -> void:
	v._line(a, b, width, Color(0.40, 0.83, 0.82, 0.85))
	var length: float = a.distance_to(b)
	if length < 0.05: return
	var dir: Vector3 = (b - a) / length
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var count: int = clampi(ceili(length / 2.0), 1, 7)
	for j in range(count):
		var point: Vector3 = a.lerp(b, fposmod(clock * 1.8 / length + float(j) / count, 1.0))
		if teaching:
			v._line(point - dir * 0.25 + side * 0.16, point, 0.055, CREAM, true)
			v._line(point - dir * 0.25 - side * 0.16, point, 0.055, CREAM, true)
		else:
			v._line(point - dir * minf(0.28, length * 0.3), point, width * 0.68, CREAM, absf(dir.y) > 0.8)

func _bed_outline(v, pos: Vector3, color: Color) -> void:
	# Four quiet corners identify a complete fixed bed, without covering its crop.
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var corner: Vector3 = pos + Vector3(x * 1.02, 0.27, z * 1.02)
			v._line(corner, corner - Vector3(x * 0.36, 0, 0), 0.07, color)
			v._line(corner, corner - Vector3(0, 0, z * 0.36), 0.07, color)

func _ring(v, center: Vector3, radius: float, color: Color) -> void:
	for i in range(24):
		var a: float = i * TAU / 24.0
		var b: float = (i + 1) * TAU / 24.0
		v._line(center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, 0.065, color)

func draw_connections(v) -> void:
	if info.is_empty(): return
	var projects: Dictionary = info.projects
	var scale_tank: Vector3 = Projects.tank_scale(int(projects.get("rainwater", 0)) + 1)
	var source: Vector3 = tank_position() + Vector3(1.5 * scale_tank.x, 0.39, 0)
	var left: float = world.plot_positions[0].x - 1.5
	var local_weather: bool = true
	var storm: bool = local_weather and info.event == "storm" and info.phase == "active"
	var choosing_patch: bool = selected.begins_with("sprinkler")
	if selected == "tank" or choosing_patch:
		_ring(v, tank_position() + Vector3(0, 0.35, 0), 1.95 * scale_tank.x, Color("e8df9b"))
	if practice_label.visible:
		var target: Vector3 = world.plot_positions[18] if info.lesson.stage == "water" else equipment_position("sprinkler2")
		_ring(v, target + Vector3(0, 0.32, 0), 0.95, Color("ffe899"))
		var tip: Vector3 = target + Vector3(0, 1.15 + sin(clock * 2.8) * 0.12, 0)
		v._line(tip + Vector3(-0.23, 0.3, 0), tip, 0.075, CREAM, true)
		v._line(tip + Vector3(0.23, 0.3, 0), tip, 0.075, CREAM, true)
	if int(projects.get("irrigation", 0)) > 0:
		var relevant: bool = selected == "tank" or choosing_patch or flow_time > 0
		if relevant:
			_flow(v, source, Vector3(left, 0.39, source.z), selected != "")
		for patch in range(3):
			var highlighted: bool = selected == "sprinkler%d" % patch
			var active: bool = flow_time > 0 and patch == flow_patch
			var point: Vector3 = equipment_position("sprinkler%d" % patch)
			if selected == "tank" or highlighted or active:
				_ring(v, point + Vector3(0, 0.32, 0), 0.64, Color("d5e4ad"))
				_flow(v, Vector3(left, 0.39, source.z), point + Vector3(0, 0.39, 0), selected != "")
			for i in range(world.plot_positions.size()):
				if Ops.zone(i) != patch: continue
				if not highlighted and not active and selected != "tank": continue
				var pos: Vector3 = world.plot_positions[i]
				var columns: int = 10 if world.current_island == 3 else (8 if world.current_island == 2 else 6)
				if i % columns == 0:
					_flow(v, point + Vector3(0, 0.39, 0), Vector3(left, 0.39, pos.z - 0.9), highlighted)
					_flow(v, Vector3(left, 0.39, pos.z - 0.9), pos + Vector3((columns - 1) * 2.3 + 0.8, 0.39, -0.9), highlighted)
				if highlighted or active: _bed_outline(v, pos, Color("b6e5b6"))
				if active:
					_flow(v, pos + Vector3(-0.88, 0.33, -0.9), pos + Vector3(-0.88, 0.33, 0.82))
					for j in range(7):
						var a: float = j / 7.0
						var b: float = (j + 1) / 7.0
						v._line(pos + Vector3(-0.88 + a * 1.6, 0.4 + sin(a * PI) * 1.2, 0), pos + Vector3(-0.88 + b * 1.6, 0.4 + sin(b * PI) * 1.2, 0), 0.04, Color(0.63, 0.91, 0.96, 0.8), true)
	if int(projects.get("windbreaks", 0)) > 0 and (selected == "trees" or storm):
		for i in range(world.plot_positions.size()):
			if Ops.zone(i) == 0 and selected == "trees":
				_bed_outline(v, world.plot_positions[i], Color("c6dfaa"))
		# Wind streams shorten and soften after crossing the living barrier.
		var trees: Vector3 = Projects.trees_position(world)
		for i in range(7):
			var x: float = lerpf(world.plot_positions[0].x, world.plot_positions[-1].x, i / 6.0)
			var advance: float = fposmod(clock * 1.6 + i * 0.47, 2.0)
			var p: Vector3 = Vector3(x, 1.6 + sin(i) * 0.12, trees.z - 2.8 + advance)
			v._line(p, p + Vector3(0.06, 0.05, 0.65), 0.045, Color(0.92, 0.95, 0.79, 0.7), true)
			var calm: Vector3 = Vector3(x, 0.92, trees.z + 1.05 + advance * 0.45)
			v._line(calm, calm + Vector3(0, 0.025, 0.22), 0.035, Color(0.73, 0.88, 0.73, 0.5), true)
	if pour_blend > 0.18:
		var spout: Vector3 = can.to_global(Vector3(0.63, 0.32, 0))
		var landing: Vector3 = spout + can.global_basis.x * 0.36
		landing.y = 0.30
		_flow(v, spout, landing, false, 0.065 * pour_blend)
	if refill_time > 0.30 and refill_blend > 0.80:
		var tap: Vector3 = tank_position() + Vector3(-0.4, 1.05, 1.95) * scale_tank
		_flow(v, tap, can.position + Vector3(0, 0.30 * can.scale.y, 0), false, 0.10)
	# Rain falls onto the roof, then travels along the same visible gutter to storage.
	var raining: bool = float(info.supply.water) < float(info.water_capacity) - 0.1 and not (local_weather and info.phase == "active" and info.event == "drought")
	if raining:
		var barn: Vector3 = Projects.barn_position(world)
		for i in range(14):
			var x: float = -2.95 + float(i % 3) * 0.57
			var roof_y: float = 3.95 + (3.0 - absf(x)) * 0.47
			var p: Vector3 = barn + Vector3(x, roof_y + 0.35 + fposmod(1.8 - clock * 2.8 + i * 0.37, 1.8), -2.1 + (i % 7) * 0.68)
			v._line(p, p - Vector3(0.035, 0.29, 0), 0.035, Color("b4e0e5"), true)
		_flow(v, gutter_start + Vector3(0, 0.10, 0), gutter_end + Vector3(0, 0.10, 0), selected == "tank", 0.055)
		_flow(v, gutter_end + Vector3(0, 0.1, 0), inlet + Vector3(0, 0.15, 0), selected == "tank", 0.055)
	if int(projects.get("drainage", 0)) > 0:
		var draining: bool = info.supply.gates and local_weather and info.event == "flood" and info.phase in ["active", "recovery"]
		if selected == "drain" or draining:
			var g: Vector3 = equipment_position("drain") + Vector3(0, 0.29, 0)
			var outlet: Vector3 = Projects.outlet_position(world) + Vector3(0, 0.16, 0)
			_flow(v, Vector3(g.x, 0.29, world.plot_positions[0].z - 1.15), g, selected == "drain", 0.20)
			_flow(v, Vector3(world.plot_positions[-1].x + 1.5, 0.29, g.z), g, selected == "drain", 0.20)
			if int(projects.get("drainage", 0)) >= 2:
				_flow(v, Vector3(world.plot_positions[-1].x + 1.5, 0.29, world.plot_positions[0].z - 1.15), Vector3(world.plot_positions[-1].x + 1.5, 0.29, g.z), selected == "drain", 0.20)
			if draining:
				_flow(v, g, outlet, selected == "drain", 0.24)
				_flow(v, outlet, outlet + Vector3(0, -1.43, 0.45), false, 0.26)
				_ring(v, outlet + Vector3(0, -1.43, 0.48), 0.4 + fposmod(clock * 0.7, 0.8), Color(0.82, 0.96, 0.86, 0.6))
