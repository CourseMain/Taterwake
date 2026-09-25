extends Node3D
## One opaque wave mesh, one optional ice MultiMesh, and a batched moored ferry.
## No per-wave nodes, physics, texture reads or per-frame mesh rebuilds.
var world
var water: MeshInstance3D
var water_material: ShaderMaterial
var ice: MultiMeshInstance3D
var ice_material: ShaderMaterial
var ferry: Node3D
var ferry_origin: Vector3
var clock: float = 0.0
var water_enabled: bool = true
const WATER_Y: float = -0.78

func setup(w) -> void:
	world = w
	name = "Coast"
	_build_water()
	if world.current_island == 3: _build_ice()
	_build_ferry()
	animate(0)
	sync_light()

func _outline(distance: float) -> PackedVector3Array:
	var size: Vector2 = [Vector2(40.3, 30.7), Vector2(46.3, 36.3), Vector2(56.2, 44.2)][world.current_island - 1] * world.LAND_SPACING
	var x: float = size.x * 0.5 + distance
	var z: float = size.y * 0.5 + distance
	var cut: float = 2.3 * world.LAND_SPACING + distance * 0.35
	return PackedVector3Array([Vector3(-x + cut, WATER_Y, -z), Vector3(x - cut, WATER_Y, -z), Vector3(x, WATER_Y, -z + cut), Vector3(x, WATER_Y, z - cut), Vector3(x - cut, WATER_Y, z), Vector3(-x + cut, WATER_Y, z), Vector3(-x, WATER_Y, z - cut), Vector3(-x, WATER_Y, -z + cut)])

func _build_water() -> void:
	water = MeshInstance3D.new()
	water.name = "AnimatedCoastalWater"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/coastal_water.gdshader")
	var colors: Array = [Color("70bbae"), Color("377d90"), Color("e3efd5")]
	if world.current_island == 2: colors = [Color("79d6c6"), Color("2f9ca3"), Color("eef6d8")]
	if world.current_island == 3: colors = [Color("8bc6d7"), Color("355c80"), Color("e9f5f7")]
	for i in range(3): water_material.set_shader_parameter(["shallow_color", "deep_color", "foam_color"][i], colors[i])
	water_material.set_shader_parameter("icy", 1.0 if world.current_island == 3 else 0.0)
	water.material_override = water_material
	add_child(water)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distances: Array[float] = [-0.35, 0.4, 1.4, 3.2, 6.0, 9.0, 13.0]
	for band in range(distances.size() - 1):
		var inner: PackedVector3Array = _outline(distances[band])
		var outer: PackedVector3Array = _outline(distances[band + 1])
		var along: float = 0.0
		for edge in range(8):
			var next: int = (edge + 1) % 8
			var edge_length: float = _outline(0)[edge].distance_to(_outline(0)[next])
			for part in range(12):
				var a: float = part / 12.0
				var b: float = (part + 1) / 12.0
				var vertices: Array[Vector3] = [inner[edge].lerp(inner[next], a), outer[edge].lerp(outer[next], a), outer[edge].lerp(outer[next], b), inner[edge].lerp(inner[next], b)]
				var uv: Array[Vector2] = [Vector2(distances[band], along + edge_length * a), Vector2(distances[band + 1], along + edge_length * a), Vector2(distances[band + 1], along + edge_length * b), Vector2(distances[band], along + edge_length * b)]
				for index in [0, 1, 2, 0, 2, 3]:
					mesh.set_normal(Vector3.UP)
					mesh.set_uv(uv[index])
					mesh.add_vertex(vertices[index])
			along += edge_length
	water.mesh = mesh.commit()

func _build_ice() -> void:
	ice = MultiMeshInstance3D.new()
	ice.name = "ArcticDriftIce"
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ice)
	ice_material = ShaderMaterial.new()
	ice_material.shader = preload("res://scripts/coastal_ice.gdshader")
	ice.material_override = ice_material
	var shape := CylinderMesh.new()
	shape.top_radius = 1.0
	shape.bottom_radius = 0.84
	shape.height = 0.20
	shape.radial_segments = 6
	shape.rings = 1
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = shape
	instances.instance_count = 36
	var rng := RandomNumberGenerator.new()
	rng.seed = 37381
	for i in range(36):
		var ring: PackedVector3Array = _outline(rng.randf_range(1.2, 6.5))
		var edge: int = i % 8
		var point: Vector3 = ring[edge].lerp(ring[(edge + 1) % 8], rng.randf_range(0.12, 0.88))
		# Leave a clear channel for the ferry and the drain outfall.
		if point.x > 30 and point.z > 5 and point.z < 20: point.z = -point.z
		point.y += 0.12
		var size: float = rng.randf_range(1.25, 1.95) if i % 4 == 0 else rng.randf_range(0.4, 0.95)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size, 1, size * rng.randf_range(0.55, 0.85)))
		instances.set_instance_transform(i, Transform3D(basis, point))
		instances.set_instance_custom_data(i, Color(i / 36.0, 0, 0, 1))
	ice.multimesh = instances

func _build_ferry() -> void:
	var boarding: Vector3 = world.ferry_position()
	ferry_origin = boarding + Vector3(2.9, -0.52, 0)
	ferry = Node3D.new()
	ferry.name = "MooredFerry"
	add_child(ferry)
	ferry.position = ferry_origin
	var navy := Color("365b68") if world.current_island < 3 else Color("415771")
	var trim := Color("f1dfb4") if world.current_island < 3 else Color("e4eff0")
	var roof := Color("cf8c59") if world.current_island < 3 else Color("d9aa6e")
	world._sphere(ferry, Vector3(0, 0.13, 0), Vector3(1.40, 0.55, 2.8), navy)
	world._box(ferry, Vector3(0, 0.58, 0), Vector3(2.42, 0.20, 4.5), trim)
	world._box(ferry, Vector3(0, 0.71, 0), Vector3(2.17, 0.10, 4.15), Color("ba9971"))
	world._box(ferry, Vector3(0, 1.38, -0.85), Vector3(1.95, 1.32, 1.90), trim)
	world._box(ferry, Vector3(0, 2.10, -0.85), Vector3(2.25, 0.18, 2.15), roof)
	for x: float in [-0.98, 0.98]:
		world._box(ferry, Vector3(x, 1.55, -0.85), Vector3(0.04, 0.58, 1.05), Color("76aeb7"))
	world._box(ferry, Vector3(0, 1.58, 0.12), Vector3(1.28, 0.61, 0.055), Color("6aa5b3"))
	world._box(ferry, Vector3(0, 1.58, 0.16), Vector3(0.07, 0.65, 0.05), trim)
	world._cylinder(ferry, Vector3(0.46, 2.43, -1.16), 0.20, 0.20, 0.54, navy, 8)
	world._cylinder(ferry, Vector3(0.46, 2.73, -1.16), 0.25, 0.25, 0.10, roof, 8)
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.9, 0.55, 1.9]:
			world._cylinder(ferry, Vector3(side * 1.10, 0.98, z), 0.045, 0.045, 0.48, trim, 6)
		world._bar(ferry, Vector3(side * 1.10, 1.20, -1.9), Vector3(side * 1.10, 1.20, 1.9), 0.045, trim)
		for z: float in [-1.5, 1.3]:
			world._sphere(ferry, Vector3(side * 1.30, 0.46, z), Vector3(0.12, 0.25, 0.19), Color("314c55"))
	world._box(ferry, Vector3(0, 0.96, 1.2), Vector3(1.65, 0.14, 0.43), roof)
	world._target(ferry, Vector3(0, 1.0, 0), Vector3(2.8, 2.8, 5.4), "station", "island")
	# Short gangway and rope physically connect the boat to the end of the pier.
	world._box(self, boarding + Vector3(1.3, 0.16, 0), Vector3(1.65, 0.12, 1.0), Color("c6a67a"))
	world._bar(self, boarding + Vector3(0.8, 0.8, -0.7), ferry_origin + Vector3(-1.05, 1.0, -1.8), 0.025, Color("b8ab87"))
	world._shop_label(ferry, "Ferry", Vector3(0, 3.05, -0.4))
	world._geometry_batcher.batch_tree(ferry, {})
	world._geometry_batcher.batch_siblings(self, {})

func animate(delta: float) -> void:
	clock += delta
	water_material.set_shader_parameter("water_clock", clock if water_enabled else 0.0)
	if is_instance_valid(ice_material): ice_material.set_shader_parameter("water_clock", clock if water_enabled else 0.0)
	ferry.position.y = ferry_origin.y + sin(clock * 1.4) * 0.045
	ferry.rotation.z = sin(clock * 1.05) * 0.012

func sync_light() -> void:
	# Match the sky in the same frame, including travel and abrupt weather changes.
	water_material.set_shader_parameter("horizon_color", world._day_environment.background_color)
	var light: float = clampf(world._sun.light_energy / 0.65, 0.0, 1.0)
	water_material.set_shader_parameter("daylight", light)
	if is_instance_valid(ice_material): ice_material.set_shader_parameter("daylight", light)

func set_effects_enabled(enabled: bool) -> void:
	water_enabled = enabled
	water.visible = enabled
	if is_instance_valid(ice): ice.visible = enabled
