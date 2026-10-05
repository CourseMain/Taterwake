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
	# An immutable unlit material cannot use transformed normals at runtime.
	# Its fallback must visibly distinguish opposite faces, and changing the
	# baked sun direction must invalidate the compiled mesh cache.
	var paint_root := Node3D.new(); root.add_child(paint_root)
	for direction in [Vector3.RIGHT, Vector3.LEFT]:
		compiler.sun_direction = direction
		for x in range(2):
			var item := MeshInstance3D.new(); item.mesh = BoxMesh.new(); item.position.x = x*2
			var material := StandardMaterial3D.new(); material.albedo_color=Color.WHITE
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.set_meta("static_colour",true)
			item.material_override = material; paint_root.add_child(item)
		compiler.merge_siblings(paint_root,{})
		var combined: MeshInstance3D = paint_root.get_node("CompiledGeometry")
		var arrays: Array = combined.mesh.surface_get_arrays(0)
		var bright: float = 0; var dark: float = 1
		for i in range(arrays[Mesh.ARRAY_NORMAL].size()):
			var facing: float = arrays[Mesh.ARRAY_NORMAL][i].dot(direction)
			if facing > .99: bright = maxf(bright, arrays[Mesh.ARRAY_COLOR][i].r)
			if facing < -.99: dark = minf(dark, arrays[Mesh.ARRAY_COLOR][i].r)
		check(bright > .99 and dark > .64 and dark < .66, "unlit paint bakes the sun-facing and opposite faces")
		combined.free()
	paint_root.free()
	root.remove_meta("compiler_box")
	print("STATIC MESH COMPILER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
