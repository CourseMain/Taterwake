extends Node3D
## One opaque wave mesh, one optional ice MultiMesh.
## No per-wave nodes, physics, texture reads or per-frame mesh rebuilds.
var world
var water: MeshInstance3D
var water_material: ShaderMaterial
var ice: MultiMeshInstance3D
var ice_material: ShaderMaterial
var clock: float = 0.0
var water_enabled: bool = true
const WATER_Y: float = -0.78

func setup(w) -> void:
	world = w
	name = "Coast"
	_build_water()
	if world.current_island == 3: _build_ice()
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
	var colors: Array = [Color("91d8ca"), Color("5298a5"), Color("e3efd5")]
	if world.current_island == 2: colors = [Color("9de6d4"), Color("49a5b1"), Color("eef6d8")]
	if world.current_island == 3: colors = [Color("b2dfdf"), Color("5482a8"), Color("e9f5f7")]
	for i in range(3): water_material.set_shader_parameter(["shallow_color", "deep_color", "foam_color"][i], colors[i])
	water_material.set_shader_parameter("icy", 1.0 if world.current_island == 3 else 0.0)
	water.material_override = water_material
	add_child(water)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distances: Array[float] = [-0.35, 0.4, 1.4, 3.2, 6.0, 12.0, 220.0]
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
		# Leave a clear channel for the drain outfall.
		if point.x > 30 and point.z > 5 and point.z < 20: point.z = -point.z
		point.y += 0.12
		var size: float = rng.randf_range(1.25, 1.95) if i % 4 == 0 else rng.randf_range(0.4, 0.95)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size, 1, size * rng.randf_range(0.55, 0.85)))
		instances.set_instance_transform(i, Transform3D(basis, point))
		instances.set_instance_custom_data(i, Color(i / 36.0, 0, 0, 1))
	ice.multimesh = instances

func animate(delta: float) -> void:
	clock += delta
	water_material.set_shader_parameter("water_clock", clock if water_enabled else 0.0)
	if is_instance_valid(ice_material): ice_material.set_shader_parameter("water_clock", clock if water_enabled else 0.0)

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
