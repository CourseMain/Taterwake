extends SceneTree
const Avatar = preload("res://scripts/farmer_avatar.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var avatar = Avatar.new()
	root.add_child(avatar)
	avatar.setup()
	var setup_count: int = _descendants(avatar).size()
	avatar.setup()
	check(_descendants(avatar).size() == setup_count, "setting up the shared avatar twice does not duplicate its body")
	check(avatar._torso.mesh is SphereMesh and avatar._torso.scale.x / avatar._torso.scale.y > 0.75, "farmer has a wide continuous potato oval instead of separate rectangular head and torso")
	check(avatar._eyes.size() == 2 and avatar._arms.size() == 2 and avatar._legs.size() == 2, "round character has two blinking eyes and two pairs of articulated stubby limbs")
	var has_boxes: bool = false
	var invalid_normals: bool = false
	var inside_out: bool = false
	for mesh in _meshes(avatar):
		has_boxes = has_boxes or mesh.mesh is BoxMesh
		if mesh.mesh is ArrayMesh:
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(0, triangles.size(), 3):
				var a: int = triangles[offset]
				var b: int = triangles[offset + 1]
				var c: int = triangles[offset + 2]
				inside_out = inside_out or (points[b] - points[a]).cross(points[c] - points[a]).dot(normals[a]) > 0.0
			for normal in normals:
				invalid_normals = invalid_normals or not normal.is_normalized()
	check(not has_boxes, "farmer body avoid block-shaped geometry")
	check(not invalid_normals, "curved body surfaces have normalized smooth surface normals")
	check(not inside_out, "body surfaces use Godot clockwise front faces so the belly and back remain clothed")
	var node_ids: Array[int] = _ids(avatar)
	avatar.animate(1.0 / 60.0, true)
	check(avatar._walk_blend > 0 and avatar._walk_blend < 0.2, "walking eases in rather than snapping to the full stride")
	for frame in range(90):
		avatar.animate(1.0 / 60.0, true)
	var moving_angle: float = avatar._legs[0].rotation.x
	avatar.animate(1.0 / 60.0, false)
	check(avatar._walk_blend > 0.8 and absf(avatar._legs[0].rotation.x - moving_angle) < 0.12, "stopping eases the stride without a one-frame limb reset")
	for frame in range(120):
		avatar.animate(1.0 / 60.0, false)
	check(avatar._walk_blend < 0.0001 and _ids(avatar) == node_ids, "animation settles into breathing without allocating new nodes or meshes")
	avatar._time = 3.7 - 1.0 / 60.0
	avatar.animate(1.0 / 60.0)
	check(avatar._eyes[0].scale.y < 0.08 and avatar._eyes[1].scale.y < 0.08, "both eyes make a gentle synchronized blink")
	avatar.animate(0.21)
	check(avatar._eyes[0].scale.y > 0.99, "blink reopens without replacing eye geometry")
	var old_time: float = avatar._time
	avatar.animate(NAN, true)
	check(avatar._time == old_time, "invalid animation delta cannot corrupt body transforms")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(avatar)
	avatar.free()
	print("ROUND AVATAR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result

func _capture(avatar) -> void:
	root.size = Vector2i(960, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("e8e3d5")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("fff4df")
	world.ambient_light_energy = 0.65
	environment.environment = world
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.15
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	stage.add_child(camera)
	camera.current = true
	for view in ["front", "back"]:
		camera.position = Vector3(2.8, 1.6, 4.5) if view == "front" else Vector3(-2.8, 1.6, -4.5)
		camera.look_at(Vector3(0, 1.03, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/round-avatar-" + view + ".png") == OK, "capture farmer from " + view)
	stage.free()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in _descendants(node):
		if child is MeshInstance3D:
			result.append(child)
	return result

func _ids(node: Node) -> Array[int]:
	var result: Array[int] = []
	for child in _descendants(node):
		result.append(child.get_instance_id())
		if child is MeshInstance3D:
			result.append(child.mesh.get_instance_id())
	return result
