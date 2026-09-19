extends SceneTree
const Compiler = preload("res://scripts/static_mesh_compiler.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var compiler := Compiler.new()
	var first_mesh: ArrayMesh
	for iteration: int in range(2):
		var parent := Node3D.new()
		root.add_child(parent)
		var expected_vertices := PackedVector3Array()
		var expected_normals := PackedVector3Array()
		var expected_colours := PackedColorArray()
		var mutable: MeshInstance3D
		var box: BoxMesh = BoxMesh.new()
		# One resource across both fixtures exercises the mesh cache.
		if iteration == 0: root.set_meta("compiler_box",box)
		else: box = root.get_meta("compiler_box")
		for index: int in range(3):
			var item := MeshInstance3D.new()
			item.mesh = box
			item.position = Vector3(index, index * 0.2, -index)
			item.rotation = Vector3(0.2,0.8,0.1)
			item.scale = Vector3(0.5,2.0,0.3)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.2 + index * 0.2,0.3,0.8)
			material.set_meta("static_colour",true)
			item.material_override = material
			parent.add_child(item)
			if index == 2:
				mutable = item
				continue
			var arrays: Array = box.surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: expected_vertices.append(item.transform * vertex)
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: expected_normals.append((item.basis.inverse().transposed() * normal).normalized())
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: expected_colours.append(material.albedo_color)
		compiler.merge_siblings(parent,{mutable.get_instance_id():true})
		var combined: MeshInstance3D = parent.get_node("CompiledGeometry")
		var actual: Array = combined.mesh.surface_get_arrays(0)
		check(parent.get_child_count() == 2 and is_instance_valid(mutable), "mutable references stay live; ordinary siblings become one surface")
		check(actual[Mesh.ARRAY_VERTEX].size() == expected_vertices.size(), "same vertex count")
		for index: int in range(expected_vertices.size()):
			check(actual[Mesh.ARRAY_VERTEX][index].distance_to(expected_vertices[index]) < 0.0001, "baked vertex keeps exact parent-space position")
			check(actual[Mesh.ARRAY_NORMAL][index].distance_to(expected_normals[index]) < 0.001, "nonuniform scale keeps correct normal")
			check(absf(actual[Mesh.ARRAY_COLOR][index].r - expected_colours[index].r) <= 1.0/255.0 and absf(actual[Mesh.ARRAY_COLOR][index].g - expected_colours[index].g) <= 1.0/255.0 and absf(actual[Mesh.ARRAY_COLOR][index].b - expected_colours[index].b) <= 1.0/255.0, "material colour preserved within the GPU vertex format precision")
		if iteration == 0: first_mesh = combined.mesh
		else: check(combined.mesh == first_mesh, "identical plants reuse compiled GPU geometry")
		parent.free()
	root.remove_meta("compiler_box")
	print("STATIC MESH COMPILER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
