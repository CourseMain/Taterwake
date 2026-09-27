extends RefCounted
## Static terrain details; no per-frame mesh work, collision or gameplay changes.
const SURFACE = preload("res://scripts/island_terrain.gdshader")

static func material(is_snow: bool, extent: Vector2) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("snow", is_snow)
	result.set_shader_parameter("half_extent", extent * 0.5)
	return result

static func snowbanks(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SoftSnowbanks"
	parent.add_child(root)
	# Wind deposits collect around the edge and tree line, clear of farm paths.
	var banks: Array[Vector4] = [
		Vector4(-22.5, 19.6, 3.3, 0.21), Vector4(-17.5, 20.0, 3.5, 0.27),
		Vector4(-8.8, 20.3, 4.0, 0.20), Vector4(0.0, 20.4, 3.7, 0.17),
		Vector4(9.2, 20.0, 3.4, 0.24), Vector4(20.8, 19.5, 3.2, 0.26),
		Vector4(-25.5, 14.0, 3.4, 0.26), Vector4(-26.0, 5.5, 3.0, 0.22),
		Vector4(-25.6, -6.5, 3.6, 0.25), Vector4(-24.9, -16.9, 3.2, 0.23),
		Vector4(25.4, -13.8, 3.5, 0.24), Vector4(26.0, 0.0, 3.2, 0.20),
		Vector4(-16.0, -20.1, 3.6, 0.18), Vector4(-7.0, -20.2, 3.4, 0.19),
		Vector4(6.0, -20.0, 4.0, 0.25), Vector4(18.0, -19.9, 3.5, 0.24),
	]
	# One continuous powder surface lets the banks meet the level ground
	# without separate oval rims or a change of material at their edges.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Dictionary = {}
	for z in range(45):
		for x in range(57):
			var point := Vector2(lerpf(-28.1, 28.1, float(x) / 56.0), lerpf(-22.1, 22.1, float(z) / 44.0))
			var corner_cut: float = maxf(0.0, absf(point.x) + absf(point.y) - 47.9) * 0.5
			point -= Vector2(signf(point.x), signf(point.y)) * corner_cut
			var height: float = 0.024
			var slope := Vector2.ZERO
			for i in range(banks.size()):
				var bank: Vector4 = banks[i]
				var angle: float = 1.3 if absf(bank.x) > 24 else -0.1 + float(i % 3) * 0.14
				var width := Vector2(bank.z, bank.z * (0.42 if absf(bank.x) < 24 else 0.56))
				var local: Vector2 = (point - Vector2(bank.x, bank.y)).rotated(-angle) / width
				var falloff: float = maxf(0.0, 1.0 - local.length_squared())
				height += bank.w * falloff * falloff
				# Soft powder scatters light across these shallow slopes.
				slope += (0.9 * bank.w * falloff * local / width).rotated(angle)
			samples[Vector2i(x, z)] = [Vector3(point.x, height, point.y), Vector3(slope.x, 1, slope.y).normalized()]
	for z in range(44):
		for x in range(56):
			for corner: Vector2i in [Vector2i(x,z), Vector2i(x+1,z), Vector2i(x+1,z+1), Vector2i(x,z), Vector2i(x+1,z+1), Vector2i(x,z+1)]:
				surface.set_normal(samples[corner][1])
				surface.add_vertex(samples[corner][0])
	var drift := MeshInstance3D.new()
	drift.name = "WindPackedSnow"
	drift.mesh = surface.commit()
	drift.material_override = material(true, Vector2(56.2, 44.2))
	drift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(drift)

static func beach_shells(world: Node3D) -> void:
	var shore := Node3D.new()
	shore.name = "ShorelineShells"
	world.add_child(shore)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44028
	# A few tide-line clusters, with gaps at the ferry and working farm paths.
	for cluster: Vector2 in [Vector2(-13.5, 16.9), Vector2(-4.5, 17.1), Vector2(6.5, 16.8), Vector2(17.5, 16.3), Vector2(-21.3, 3.0), Vector2(21.5, -4.3)]:
		for i in range(3):
			var root := Node3D.new()
			root.name = "ScallopShell" if i != 1 else "SpiralShell"
			shore.add_child(root)
			root.position = Vector3(cluster.x + rng.randf_range(-1.3, 1.3), 0.035, cluster.y + rng.randf_range(-0.4, 0.3))
			root.rotation.y = rng.randf_range(0, TAU)
			root.scale = Vector3.ONE * rng.randf_range(0.65, 1.0)
			if i == 1:
				world._sphere(root, Vector3(0, 0.055, 0), Vector3(0.20, 0.115, 0.31), Color("eed4bc"))
				world._sphere(root, Vector3(0, 0.11, -0.12), Vector3(0.14, 0.11, 0.18), Color("f6e5ce"))
				world._sphere(root, Vector3(0, 0.14, -0.23), Vector3(0.08, 0.07, 0.12), Color("e1bda0"))
				world._sphere(root, Vector3(0.12, 0.08, 0.13), Vector3(0.08, 0.04, 0.12), Color("a77664"))
			else:
				_scallop(world, root, Color("f1d0bd") if i == 0 else Color("f4e9d1"))
	world._geometry_batcher.batch_tree(shore, {})

static func _scallop(world: Node3D, parent: Node3D, color: Color) -> void:
	# Fan ribs form the shell silhouette rather than drawing an oval pebble.
	for rib in range(7):
		var angle: float = -1.06 + float(rib) * 0.353
		var length: float = 0.38 + sin(float(rib) / 6.0 * PI) * 0.08
		var tip := Vector3(sin(angle) * length, 0.065, cos(angle) * length)
		world._bar(parent, Vector3(0, 0.03, -0.04), tip, 0.061, color.lightened(0.075) if rib % 2 == 0 else color.darkened(0.07))
	world._sphere(parent, Vector3(0, 0.025, -0.035), Vector3(0.16, 0.055, 0.10), color)
