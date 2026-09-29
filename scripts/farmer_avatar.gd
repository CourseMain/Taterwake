extends Node3D
## One soft potato farmer, shared by the farmer and villagers.
const SKIN: Color = Color("dca86d")
const BODY_CENTER: float = 0.99
const BODY_RADII: Vector3 = Vector3(0.61, 0.78, 0.49)
var skin_color: Color = SKIN
var _mouth: Node3D
var _torso: MeshInstance3D
var _head: Node3D
var _rig: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _neutral_body: Node3D
var _neutral_pants: Node3D
var _neutral_feet: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _time: float = 0.0
var _stride: float = 0.0
var _walk_blend: float = 0.0
var carry_weight: float = 0.0
var pour_pose: float = 0.0
var harvest_pose: float = 0.0
var _run_blend: float = 0.0
var _built: bool = false

func setup() -> void:
	if _built:
		return
	_built = true
	name = "FarmerAvatar"
	_rig = _group(self, "PotatoBodyRig")
	_torso = _sphere(_rig, Vector3(0, BODY_CENTER, 0), BODY_RADII, skin_color)
	_torso.name = "RoundPotatoBody"
	_head = _group(_rig, "PotatoFace")
	for side: float in [-1.0, 1.0]:
		var eye: Node3D = _group(_head, "EyeLeft" if side < 0 else "EyeRight")
		eye.position = Vector3(side * 0.20, 1.36, 0.415)
		_sphere(eye, Vector3.ZERO, Vector3(0.108, 0.125, 0.045), Color("fff4dc"))
		_sphere(eye, Vector3(0.009, -0.003, 0.040), Vector3(0.052, 0.073, 0.025), Color("352d27"))
		_sphere(eye, Vector3(-0.008, 0.029, 0.062), Vector3(0.018, 0.022, 0.009), Color("ffffff"))
		_eyes.append(eye)
		_sphere(_head, Vector3(side * 0.34, 1.205, 0.390), Vector3(0.098, 0.048, 0.020), Color("e99b82"))
		for offset in range(2):
			_sphere(_head, Vector3(side * (0.315 + offset * 0.055), 1.49 - offset * 0.05, 0.279), Vector3(0.020, 0.022, 0.012), skin_color.darkened(0.17))
	_sphere(_head, Vector3(0, 1.245, 0.49), Vector3(0.072, 0.056, 0.053), skin_color.lightened(0.16))
	_mouth = _group(_head, "Smile")
	for index in range(8):
		var a: float = PI + index * PI / 8.0
		var b: float = PI + (index + 1) * PI / 8.0
		_bar(_mouth, Vector3(cos(a) * 0.087, 1.16 + sin(a) * 0.037, 0.49), Vector3(cos(b) * 0.087, 1.16 + sin(b) * 0.037, 0.49), 0.010, Color("81553d"))
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = _group(_rig, "ArmLeft" if side < 0 else "ArmRight")
		arm.position = Vector3(side * 0.575, 1.015, 0)
		arm.rotation.z = side * 0.16
		_arms.append(arm)
		_sphere(arm, Vector3(0, -0.17, 0.025), Vector3(0.137, 0.265, 0.157), skin_color)
		_sphere(arm, Vector3(0, -0.36, 0.047), Vector3(0.140, 0.14, 0.16), skin_color.lightened(0.025))
		var leg: Node3D = _group(_rig, "LegLeft" if side < 0 else "LegRight")
		leg.position = Vector3(side * 0.25, 0.35, 0)
		_legs.append(leg)
		_sphere(leg, Vector3(0, -0.07, 0), Vector3(0.159, 0.16, 0.168), Color("547e83"))
		_neutral_feet.append(_sphere(leg, Vector3(0, -0.22, 0.10), Vector3(0.195, 0.13, 0.28), Color("705441")))
	_neutral_pants = _group(_rig, "NeutralDungarees")
	_body_band(_neutral_pants, 0.215, 0.67, Color("547e83"), 1.018)
	_neutral_body = _group(_rig, "NeutralBib")
	_body_band(_neutral_body, 0.60, 0.91, Color("719798"), 1.025)
	_sphere(_neutral_body, _front(0, 0.91, 0.025), Vector3(0.245, 0.17, 0.023), Color("719798"))
	for side: float in [-1.0, 1.0]:
		_bar(_neutral_body, _front(side * 0.22, 0.96, 0.028), _front(side * 0.26, 1.13, 0.015), 0.033, Color("719798"))
		_sphere(_neutral_body, _front(side * 0.22, 0.965, 0.065), Vector3.ONE * 0.025, Color("e6c57d"))

func animate(delta: float, moving: bool = false, sprint: float = 0.0) -> void:
	if not _built or not is_finite(delta) or delta <= 0.0:
		return
	_time += delta
	_walk_blend = lerpf(_walk_blend, 1.0 if moving else 0.0, 1.0 - exp(-delta * 9.0))
	_run_blend = lerpf(_run_blend, sprint if moving else 0.0, 1.0 - exp(-delta * 10))
	_stride += delta * lerpf(2.0, lerpf(8.2, 12.0, _run_blend), _walk_blend)
	var breath: float = sin(_time * 2.05)
	_rig.position.y = breath * 0.015 * (1.0 - _walk_blend) + (1.0 - cos(_stride * 2.0)) * lerpf(0.026, 0.045, _run_blend) * _walk_blend
	_rig.rotation.z = sin(_stride) * 0.051 * _walk_blend
	_rig.rotation.x = -0.10 * _run_blend
	_rig.scale = Vector3(1.0 + breath * 0.004, 1.0 - breath * 0.003, 1.0 + breath * 0.003)
	for index in range(_legs.size()):
		var step: float = sin(_stride + index * PI)
		_legs[index].rotation.x = step * lerpf(0.29, 0.48, _run_blend) * _walk_blend
		_arms[index].rotation.x = -step * 0.23 * _walk_blend
		_arms[index].rotation.z = (-1.0 if index == 0 else 1.0) * (0.16 + absf(step) * 0.045 * _walk_blend)
	# Left hand carries the can; its reduced swing keeps the handle in the palm.
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -0.75 - pour_pose * 0.4 + sin(_stride) * 0.07 * _walk_blend, carry_weight)
	_arms[0].rotation.z = lerpf(_arms[0].rotation.z, -0.24 - pour_pose * 0.25, carry_weight)
	if harvest_pose > 0:
		_rig.rotation.x += harvest_pose * .26
		_rig.position.y -= harvest_pose * .10
		for arm in _arms: arm.rotation.x = lerpf(arm.rotation.x, -1.25, harvest_pose)
	var blink_phase: float = fmod(_time + 0.9, 4.7)
	var openness: float = 1.0
	if blink_phase > 4.50:
		openness = maxf(0.06, absf((blink_phase - 4.60) / 0.10))
	for eye in _eyes:
		eye.scale.y = openness

func hand_transform(left: bool = false) -> Transform3D:
	return _arms[0 if left else 1].global_transform.translated_local(Vector3(0, -0.34, 0.06))

func _front(x: float, y: float, extra: float = 0.0) -> Vector3:
	var remaining: float = maxf(0.0, 1.0 - pow(x / BODY_RADII.x, 2) - pow((y - BODY_CENTER) / BODY_RADII.y, 2))
	return Vector3(x, y, BODY_RADII.z * sqrt(remaining) + extra)

func _group(parent: Node3D, title: String) -> Node3D:
	var group := Node3D.new()
	group.name = title
	parent.add_child(group)
	return group

func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	_materials[key] = material
	return material

func _sphere(parent: Node3D, origin: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var node: MeshInstance3D = _mesh(parent, origin, mesh, color)
	node.scale = radii
	return node

func _cylinder(parent: Node3D, origin: Vector3, bottom: float, top: float, height_value: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height_value
	mesh.radial_segments = 32
	return _mesh(parent, origin, mesh, color)

func _torus(parent: Node3D, origin: Vector3, inner: float, outer: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	return _mesh(parent, origin, mesh, color)

func _bar(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = _cylinder(parent, (start + end) * 0.5, radius, radius, start.distance_to(end), color)
	var direction: Vector3 = (end - start).normalized()
	var axis: Vector3 = Vector3.UP.cross(direction)
	if axis.length_squared() > 0.000001:
		node.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0)))
	elif direction.y < 0:
		node.rotation.x = PI
	return node

func _mesh(parent: Node3D, origin: Vector3, shape: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = _material(color)
	node.position = origin
	parent.add_child(node)
	return node

func _body_band(parent: Node3D, bottom: float, top: float, color: Color, inflate: float) -> MeshInstance3D:
	# The fixed overalls follow a latitude band of the potato body. They have
	# no rectangular corners, and never changes the round belly silhouette.
	const SEGMENTS: int = 48
	const ROWS: int = 24
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		var y: float = lerpf(bottom, top, float(row) / ROWS)
		var vertical: float = (y - BODY_CENTER) / BODY_RADII.y
		var radius: float = sqrt(maxf(0.0, 1.0 - vertical * vertical))
		for column in range(SEGMENTS + 1):
			var angle: float = TAU * column / SEGMENTS
			var x: float = sin(angle) * BODY_RADII.x * radius * inflate
			var z: float = cos(angle) * BODY_RADII.z * radius * inflate
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3(x / pow(BODY_RADII.x, 2), (y - BODY_CENTER) / pow(BODY_RADII.y, 2), z / pow(BODY_RADII.z, 2)).normalized())
			if row < ROWS and column < SEGMENTS:
				var a: int = row * (SEGMENTS + 1) + column
				var b: int = a + SEGMENTS + 1
				# Godot uses clockwise front faces. Normals still point outwards.
				indices.append_array(PackedInt32Array([a, b + 1, a + 1, a, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, Vector3.ZERO, mesh, color)

var _season_outfits: Dictionary = {}
var outfit_season: int = -1
var _winter_sleeves: Array[Node3D] = []
func set_season(season: int) -> void:
	if not _built or outfit_season == season: return
	outfit_season=season
	if _season_outfits.is_empty():
		var summer:=_group(_rig,"SummerStrawHat")
		_cylinder(summer,Vector3(0,1.82,0),.88,.88,.075,Color("d7b96c"))
		_cylinder(summer,Vector3(0,1.97,0),.49,.39,.32,Color("dfc684"))
		_cylinder(summer,Vector3(0,1.86,0),.50,.49,.10,Color("867145"))
		var winter:=_group(_rig,"WinterCoatAndHat")
		_body_band(winter,.28,1.13,Color("477078"),1.06)
		_body_band(winter,1.03,1.17,Color("e4d8ba"),1.10)
		for y in [.48,.70,.92]: _sphere(winter,_front(0,y,.075),Vector3.ONE*.04,Color("d9bd7c"))
		_sphere(winter,Vector3(0,1.78,-.06),Vector3(.57,.25,.48),Color("a85f45"))
		_sphere(winter,Vector3(0,2.04,-.05),Vector3.ONE*.12,Color("e4d8ba"))
		for side in [-1,1]: _sphere(winter,Vector3(side*.46,1.61,-.04),Vector3(.13,.23,.27),Color("a85f45"))
		for arm in _arms:
			_winter_sleeves.append(_sphere(arm,Vector3(0,-.12,.025),Vector3(.151,.21,.17),Color("477078")))
		_season_outfits={1:summer,3:winter}
		var batcher=preload("res://scripts/world_geometry_batcher.gd").new()
		for outfit in _season_outfits.values():
			for mesh in outfit.find_children("*","MeshInstance3D",true,false): mesh.material_override.set_meta("static_colour",true)
			batcher.batch_tree(outfit,{})
	for key in _season_outfits: _season_outfits[key].visible=int(key)==season
	_neutral_body.visible=season!=3
	for sleeve in _winter_sleeves: sleeve.visible=season==3
