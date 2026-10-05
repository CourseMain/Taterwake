extends Node3D
## One opaque wave mesh follows the continuous Valley coastline.
## No per-wave nodes, physics, texture reads or per-frame mesh rebuilds.
var world
var water: MeshInstance3D
var water_material: ShaderMaterial
var clock: float = 0.0
var water_enabled: bool = true
var title_mode: bool = false
const WATER_Y: float = -0.78
const SEA_CLIP_DEPTH: float = -0.9999

func setup(w) -> void:
	world = w
	name = "Coast"
	_build_water()
	animate(0)
	sync_light()

func _outline(distance: float) -> PackedVector3Array:
	var size: Vector2 = world.Surface.EXTENT
	var x: float = size.x * 0.5 + distance
	var z: float = size.y * 0.5 + distance
	var cut: float = world.Surface.CUT.x + distance * 0.35
	return PackedVector3Array([Vector3(-x+cut,WATER_Y,-z),Vector3(x-cut,WATER_Y,-z),Vector3(x,WATER_Y,0),Vector3(x-cut,WATER_Y,z),Vector3(-x+cut,WATER_Y,z),Vector3(-x,WATER_Y,0)])

func _build_water() -> void:
	water = MeshInstance3D.new()
	water.name = "AnimatedCoastalWater"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/coastal_water.gdshader")
	water_material.set_shader_parameter("sea_clip_depth", SEA_CLIP_DEPTH)
	water_material.set_shader_parameter("title_mode", title_mode)
	var colors: Array = [Color("8cc7bb"), Color("326d8a"), Color("e3efd5")]
	for i in range(3): water_material.set_shader_parameter(["shallow_color", "deep_color", "foam_color"][i], colors[i])
	water.material_override = water_material
	add_child(water)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distances: Array[float] = [-0.35, 0.4, 1.4, 3.2, 6.0, 12.0, 600.0]
	for band in range(distances.size() - 1):
		var inner: PackedVector3Array = _outline(distances[band])
		var outer: PackedVector3Array = _outline(distances[band + 1])
		var along: float = 0.0
		for edge in range(inner.size()):
			var next: int = (edge + 1) % inner.size()
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

func animate(delta: float) -> void:
	clock += delta
	water_material.set_shader_parameter("water_clock", clock if water_enabled else 0.0)

func sync_light() -> void:
	# Match the sky in the same frame, including travel and abrupt weather changes.
	water_material.set_shader_parameter("horizon_color", world._day_environment.background_color)
	var light: float = clampf(world._sun.light_energy / 1.4, 0.0, 1.0)
	water_material.set_shader_parameter("daylight", light)
	if is_instance_valid(world.camera): water_material.set_shader_parameter("camera_world", world.camera.global_position)
	var sun: Dictionary = world.sun_sky_info()
	water_material.set_shader_parameter("sun_screen", sun.screen)
	water_material.set_shader_parameter("sun_direction", sun.direction)
	water_material.set_shader_parameter("sun_colour", sun.colour)
	water_material.set_shader_parameter("sky_top", world._day_environment.background_color.darkened(.22))
	water_material.set_shader_parameter("sun_visibility", 1.0 - minf(.9, world._weather_strength * .8) if not world._weather_drought else 1.0)
	water_material.set_shader_parameter("view_aspect", float(world.get_viewport().size.x) / maxf(1, world.get_viewport().size.y))

func set_effects_enabled(enabled: bool) -> void:
	water_enabled = enabled
	water.visible = enabled

func set_title_mode(enabled: bool) -> void:
	# Keep the live sea, palette and clock; only the welcome's surface calms.
	title_mode = enabled
	if is_instance_valid(water_material):
		water_material.set_shader_parameter("title_mode", enabled)
