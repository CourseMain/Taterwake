extends RefCounted
## Bake opaque, immutable siblings into vertex-coloured surfaces. Parent roots,
## mutable meshes, labels and collisions retain their identities and animation.
var _cache: Dictionary = {}
var _materials: Dictionary = {}

func merge_siblings(parent: Node3D, mutable: Dictionary) -> void:
	var groups: Dictionary = {}
	for node: Node in parent.get_children():
		if not node is MeshInstance3D or mutable.has(node.get_instance_id()):
			continue
		var item := node as MeshInstance3D
		var mat := item.material_override as StandardMaterial3D
		if not item.visible or item.get_child_count() > 0 or item.get_script() != null or item.has_meta("terrain_shell"):
			continue
		# Mirrored transforms need winding changes; keep their original renderer.
		if item.transform.basis.determinant() <= 0.0: continue
		if mat == null or not mat.get_meta("static_colour", false) or mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if item.mesh == null or item.mesh.get_surface_count() != 1:
			continue
		if not item.mesh is PrimitiveMesh and not (item.mesh is ArrayMesh and item.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES):
			continue
		var key: String = "%d/%d/%d/%d" % [mat.cull_mode, mat.shading_mode, item.cast_shadow, item.layers]
		if not groups.has(key): groups[key] = []
		groups[key].append(item)
	for key: String in groups:
		var items: Array = groups[key]
		if items.size() < 2: continue
		var signature: Array = [key]
		for item: MeshInstance3D in items:
			signature.append([item.mesh.get_rid(), item.transform, item.material_override.albedo_color])
		# Array equality checks the complete geometry signature, not just a hash.
		var mesh: ArrayMesh = _cache.get(signature)
		if mesh == null:
			mesh = _compile(items)
			if _cache.size() >= 128: _cache.erase(_cache.keys()[0])
			_cache[signature] = mesh
		if not _materials.has(key):
			var material: StandardMaterial3D = items[0].material_override.duplicate()
			material.albedo_color = Color.WHITE
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false
			_materials[key] = material
		var combined := MeshInstance3D.new()
		combined.name = "CompiledGeometry"
		combined.mesh = mesh
		combined.material_override = _materials[key]
		combined.cast_shadow = items[0].cast_shadow
		combined.layers = items[0].layers
		parent.add_child(combined)
		for item: MeshInstance3D in items: item.free()

func _compile(items: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for item: MeshInstance3D in items:
		var arrays: Array = item.mesh.surface_get_arrays(0)
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var transform: Transform3D = item.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var offset: int = vertices.size()
		for index: int in range(source.size()):
			vertices.append(transform * source[index])
			normals.append((normal_basis * source_normals[index]).normalized())
			colours.append(item.material_override.albedo_color)
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if source_indices.is_empty():
			for index: int in range(source.size()): indices.append(offset + index)
		else:
			for index: int in source_indices: indices.append(offset + index)
	var output: Array = []
	output.resize(Mesh.ARRAY_MAX)
	output[Mesh.ARRAY_VERTEX] = vertices
	output[Mesh.ARRAY_NORMAL] = normals
	output[Mesh.ARRAY_COLOR] = colours
	output[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output)
	return mesh
