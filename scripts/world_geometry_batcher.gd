extends RefCounted
## Combine only sibling leaf geometry. Moving/hidden parents, collision bodies,
## labels and every gameplay-owned mesh remain in their original hierarchy.
var _box := BoxMesh.new()
var _cylinders: Dictionary = {}
var _compiler := preload("res://scripts/static_mesh_compiler.gd").new()

func batch_tree(parent: Node3D, mutable_meshes: Dictionary) -> void:
	for child: Node in parent.get_children():
		# Scripted avatars own and animate their mesh children themselves.
		if child is Node3D and not child is MeshInstance3D and child.get_script() == null:
			batch_tree(child, mutable_meshes)
	batch_siblings(parent, mutable_meshes)

func batch_siblings(parent: Node3D, mutable_meshes: Dictionary = {}) -> void:
	_compiler.merge_siblings(parent, mutable_meshes)
	var groups: Dictionary = {}
	for child: Node in parent.get_children():
		if not child is MeshInstance3D or mutable_meshes.has(child.get_instance_id()):
			continue
		var instance := child as MeshInstance3D
		if not instance.visible or instance.get_child_count() > 0 or instance.material_override == null or instance.get_script() != null:
			continue
		var mesh: Mesh = instance.mesh
		var transform: Transform3D = instance.transform
		if mesh is BoxMesh:
			transform.basis = transform.basis.scaled_local(mesh.size)
			mesh = _box
		elif mesh is CylinderMesh and mesh.bottom_radius > 0.0:
			var shape := Vector3(mesh.top_radius / mesh.bottom_radius, mesh.radial_segments, mesh.rings)
			if not _cylinders.has(shape):
				var cylinder := CylinderMesh.new()
				cylinder.bottom_radius = 1.0
				cylinder.top_radius = shape.x
				cylinder.height = 1.0
				cylinder.radial_segments = int(shape.y)
				cylinder.rings = int(shape.z)
				_cylinders[shape] = cylinder
			transform.basis = transform.basis.scaled_local(Vector3(mesh.bottom_radius, mesh.height, mesh.bottom_radius))
			mesh = _cylinders[shape]
		elif not mesh is SphereMesh:
			continue
		var key: String = "%d/%d/%d/%d" % [mesh.get_instance_id(), instance.material_override.get_instance_id(), instance.cast_shadow, instance.layers]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "instances": [], "transforms": []}
		groups[key].instances.append(instance)
		groups[key].transforms.append(transform)
	for group: Dictionary in groups.values():
		var instances: Array = group.instances
		if instances.size() < 2:
			continue
		var first: MeshInstance3D = instances[0]
		var batch := MultiMeshInstance3D.new()
		batch.name = "BatchedGeometry"
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group.mesh
		multimesh.instance_count = instances.size()
		for index: int in range(instances.size()):
			multimesh.set_instance_transform(index, group.transforms[index])
		batch.multimesh = multimesh
		parent.add_child(batch)
		for instance: MeshInstance3D in instances:
			instance.free()
