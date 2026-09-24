extends Node3D
## One instanced water surface and two batched triangle surfaces; WebGL compatible.
var world
var info: Dictionary = {}
var water: MultiMeshInstance3D
var water_material: ShaderMaterial
var markings: MeshInstance3D
var bolts: MeshInstance3D
var time: float = 0.0
var redraw: float = 0.0
var vertices := PackedVector3Array()
var colors := PackedColorArray()

func setup(owner_world) -> void:
	world = owner_world
	name = "ClimateFieldVisuals"
	water = MultiMeshInstance3D.new()
	water.name = "InstancedFloodwater"
	water.multimesh = MultiMesh.new()
	water.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	water.multimesh.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.8, 2.8)
	plane.subdivide_width = 6
	plane.subdivide_depth = 6
	water.multimesh.mesh = plane
	water.multimesh.instance_count = world.plot_positions.size() + 8
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/flood_water.gdshader")
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	markings = _mesh("FieldDangerAndScorch")
	bolts = _mesh("LightningBranches")
	water.hide()

func _mesh(title: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func set_weather(weather: Dictionary) -> void:
	info = weather
	visible = world.current_island >= 2 and int(info.island) == world.current_island and info.phase != "calm"
	set_process(visible)
	if visible and redraw <= 0.0:
		_refresh()
		redraw = 0.1

func _process(delta: float) -> void:
	time += delta
	water_material.set_shader_parameter("weather_time", time)
	water_material.set_shader_parameter("walker", world.player.position)
	redraw -= delta
	if redraw <= 0:
		redraw = 0.1
		_refresh()

func _line(a: Vector3, b: Vector3, width: float, color: Color, vertical: bool = false) -> void:
	var side: Vector3 = (b - a).cross(Vector3.FORWARD if vertical else Vector3.UP).normalized() * width * 0.5
	for point in [a - side, a + side, b + side, a - side, b + side, b - side]:
		vertices.append(point)
		colors.append(color)

func _finish_mesh(node: MeshInstance3D) -> void:
	if vertices.is_empty():
		node.hide()
		return
	node.show()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	vertices = PackedVector3Array()
	colors = PackedColorArray()

func _refresh() -> void:
	if info.is_empty() or not visible: return
	var op: Dictionary = info.operations
	var active: bool = info.phase == "active"
	var recovery: float = float(info.timer) / 75.0 if info.phase == "recovery" else 1.0
	water.visible = info.event == "flood" and info.phase in ["active", "recovery"]
	var columns: int = 10 if world.current_island == 3 else 8
	var supply: Dictionary = info.supply
	var projects: Dictionary = info.projects[str(world.current_island)]
	for i in range(world.plot_positions.size()):
		var pos: Vector3 = world.plot_positions[i] + Vector3(0, 0.24, 0)
		var stress: float = float(op.stress.get(str(i), 0.0))
		if water.visible:
			var depth: float = (0.16 + stress * 0.84) * recovery
			if supply.gates and int(projects.get("drainage", 0)) > 0: depth *= 0.55
			water.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.95 + depth * 0.85)), pos + Vector3(0, 0.12 + depth * 0.38, 0)))
			water.multimesh.set_instance_custom_data(i, Color(depth, float(i % 13) / 13.0, 0, 1))
		if stress > 0.03 and active:
			var tint := Color("f1be59").lerp(Color("ef6e4b"), stress)
			for j in range(ceili(stress * 24)):
				var a: float = float(j) / 24.0 * TAU
				var b: float = float(j + 1) / 24.0 * TAU
				_line(pos + Vector3(cos(a), 0.62, sin(a)) * 1.02, pos + Vector3(cos(b), 0.62, sin(b)) * 1.02, 0.06, tint)
		if info.event == "drought" and stress > 0.15:
			for j in range(3):
				var start: Vector3 = pos + Vector3(-0.75 + j * 0.6, 0.025, -0.65)
				_line(start, start + Vector3(0.15, 0, 0.8), 0.04 + stress * 0.04, Color("9b623e"))
		if info.event == "storm" and op.scars.has(str(i)):
			_line(pos + Vector3(-0.8, 0.035, -0.4), pos + Vector3(0.75, 0.035, 0.25), 0.26, Color("47352e"))
			_line(pos + Vector3(-0.1, 0.036, 0), pos + Vector3(0.45, 0.036, -0.7), 0.12, Color("594239"))
		if info.event == "storm" and i / columns == int(op.strike_row) and float(op.strike_in) <= 2.5:
			var pulse: float = 0.65 + sin(time * 12.0) * 0.25
			_line(pos + Vector3(-1.1, 1.15, 0), pos + Vector3(1.1, 1.15, 0), 0.16, Color(1, 0.78, 0.3, pulse))
		var zone: int = preload("res://scripts/climate_operations.gd").zone(i, world.current_island)
		if int(projects.get("irrigation", 0)) > 0 and zone == int(supply.zone) and int(supply.mode) > 0:
			_line(pos + Vector3(-0.87, 0.13, -0.9), pos + Vector3(-0.87, 0.13, 0.9), 0.07, Color("8ce7ee") if float(supply.water) > 0 else Color("8e8b73"))
		if int(projects.get("windbreaks", 0)) > 0 and zone == int(supply.shelter) and i % columns == 0:
			# Deployable fabric screens attached to the living windbreak system.
			var base: Vector3 = pos + Vector3(-1.28, 0, 0)
			_line(base + Vector3(0, 0, -1.0), base + Vector3(0, 1.35, -1.0), 0.09, Color("d9c48b"), true)
			_line(base + Vector3(0, 0.6, -1.0), base + Vector3(0, 0.6, 1.0), 0.85, Color("72b79b"))
	if water.visible:
		var first: Vector3 = world.plot_positions[0]
		var last: Vector3 = world.plot_positions[-1]
		for i in range(8):
			var side: float = first.x - 1.8 if i < 4 else last.x + 1.8
			var point := Vector3(side, 0.25, lerpf(first.z - 0.3, last.z + 0.6, float(i % 4) / 3.0))
			var size: float = recovery * (0.9 if supply.gates else 1.4)
			water.multimesh.set_instance_transform(world.plot_positions.size() + i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, 1, size * 1.4)), point))
			water.multimesh.set_instance_custom_data(world.plot_positions.size() + i, Color(recovery * 0.8, i / 8.0, 0, 1))
	if active and info.event == "drought" and int(projects.get("irrigation", 0)) > 0 and int(supply.mode) > 0 and float(supply.water) > 0:
		for i in range(0, world.plot_positions.size(), 2):
			if preload("res://scripts/climate_operations.gd").zone(i, world.current_island) != int(supply.zone): continue
			var base: Vector3 = world.plot_positions[i] + Vector3(-0.85, 0.45, 0)
			for j in range(8):
				var a: float = j / 8.0
				var b: float = (j + 1) / 8.0
				_line(base + Vector3(a * 1.5, sin(a * PI) * 1.5, 0), base + Vector3(b * 1.5, sin(b * PI) * 1.5, 0), 0.045, Color(0.55, 0.91, 1, 0.75), true)
	_finish_mesh(markings)
	if info.event == "storm" and float(op.flash) > 0 and int(op.strike_row) >= 0:
		var row: int = int(op.strike_row)
		var hit: Vector3 = world.plot_positions[row * columns + columns / 2] + Vector3(0, 0.45, 0)
		var start: Vector3 = hit + Vector3(-3, 13, -1)
		var previous: Vector3 = start
		for j in range(1, 10):
			var point: Vector3 = start.lerp(hit, j / 9.0)
			if j < 9: point.x += sin(j * 17.0 + row) * 0.8
			_line(previous, point, 0.44, Color(0.49, 0.75, 1, 0.42), true)
			_line(previous, point, 0.13, Color("fff8cf"), true)
			previous = point
		for j in range(columns - 1):
			var a: Vector3 = world.plot_positions[row * columns + j] + Vector3(0, 0.6, 0)
			_line(a, a + Vector3(1.15, 0.45, 0.25), 0.08, Color("e7f5ff"), true)
			_line(a + Vector3(1.15, 0.45, 0.25), a + Vector3(2.3, 0, 0), 0.08, Color("e7f5ff"), true)
	_finish_mesh(bolts)
