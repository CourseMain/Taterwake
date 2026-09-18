extends Node3D
## One soft potato farmer, shared by the field and the wardrobe portrait.
const SLOTS: Array[String] = ["head", "body", "legs", "feet", "hands", "charm"]
const SKIN: Color = Color("dca86d")
const BODY_CENTER: float = 0.99
const BODY_RADII: Vector3 = Vector3(0.61, 0.78, 0.49)
var loadout: Dictionary = {}
var hat: Node3D
var gear_parts: Dictionary = {}
var _torso: MeshInstance3D
var _head: Node3D
var _rig: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _neutral_body: Node3D
var _neutral_pants: Node3D
var _neutral_feet: Array[MeshInstance3D] = []
var _followers: Array[Dictionary] = []
var _materials: Dictionary = {}
var _slot_signatures: Dictionary = {}
var _aurora_materials: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _stride: float = 0.0
var _walk_blend: float = 0.0
var _built: bool = false
var _golden_hat: bool = false
var _catalog: Dictionary = {}

func setup() -> void:
	if _built:
		return
	_built = true
	name = "FarmerAvatar"
	_rig = _group(self, "PotatoBodyRig")
	_torso = _sphere(_rig, Vector3(0, BODY_CENTER, 0), BODY_RADII, SKIN)
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
			_sphere(_head, Vector3(side * (0.315 + offset * 0.055), 1.49 - offset * 0.05, 0.279), Vector3(0.020, 0.022, 0.012), SKIN.darkened(0.17))
	_sphere(_head, Vector3(0, 1.245, 0.49), Vector3(0.072, 0.056, 0.053), SKIN.lightened(0.16))
	for index in range(8):
		var a: float = PI + index * PI / 8.0
		var b: float = PI + (index + 1) * PI / 8.0
		_bar(_head, Vector3(cos(a) * 0.087, 1.16 + sin(a) * 0.037, 0.49), Vector3(cos(b) * 0.087, 1.16 + sin(b) * 0.037, 0.49), 0.010, Color("81553d"))
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = _group(_rig, "ArmLeft" if side < 0 else "ArmRight")
		arm.position = Vector3(side * 0.575, 1.015, 0)
		arm.rotation.z = side * 0.16
		_arms.append(arm)
		_sphere(arm, Vector3(0, -0.17, 0.025), Vector3(0.137, 0.265, 0.157), SKIN)
		_sphere(arm, Vector3(0, -0.36, 0.047), Vector3(0.140, 0.14, 0.16), SKIN.lightened(0.025))
		var leg: Node3D = _group(_rig, "LegLeft" if side < 0 else "LegRight")
		leg.position = Vector3(side * 0.25, 0.35, 0)
		_legs.append(leg)
		_sphere(leg, Vector3(0, -0.07, 0), Vector3(0.159, 0.16, 0.168), Color("547e83"))
		_neutral_feet.append(_sphere(leg, Vector3(0, -0.22, 0.10), Vector3(0.195, 0.13, 0.28), Color("705441")))
	_neutral_pants = _group(_rig, "NeutralDungarees")
	_shell(_neutral_pants, 0.215, 0.67, Color("547e83"), 1.018)
	_neutral_body = _group(_rig, "NeutralBib")
	_shell(_neutral_body, 0.60, 0.91, Color("719798"), 1.025)
	_sphere(_neutral_body, _front(0, 0.91, 0.025), Vector3(0.245, 0.17, 0.023), Color("719798"))
	for side: float in [-1.0, 1.0]:
		_bar(_neutral_body, _front(side * 0.22, 0.96, 0.028), _front(side * 0.26, 1.13, 0.015), 0.033, Color("719798"))
		_sphere(_neutral_body, _front(side * 0.22, 0.965, 0.065), Vector3.ONE * 0.025, Color("e6c57d"))
	set_equipment({}, {})

static func colors_for(id: String, data: Dictionary = {}) -> Dictionary:
	var role: String = str(data.get("role", data.get("build", data.get("specialty", id.get_slice("_", 0)))))
	var color: Color = {"farmer": Color("669653"), "gambler": Color("875bad"), "investor": Color("347e8e"), "scientist": Color("d3e8e4"), "industrialist": Color("d58b45")}.get(role, Color("7ba39b"))
	var accents: Dictionary = {"farmer": Color("ebcb7b"), "gambler": Color("e9bf6b"), "investor": Color("edc671"), "scientist": Color("51aea9"), "industrialist": Color("484f58")}
	var special: Dictionary = {"straw_hat": Color("e8c06c"), "lucky_cap": Color("6da067"), "traders_visor": Color("73aec6"), "prospectors_hat": Color("e0a34f"), "aurora_crown": Color("93dce7"), "harvest_gloves": Color("b47b45"), "market_monocle": Color("e7c45d"), "loaded_dice": Color("caa2ed")}
	color = special.get(id, color)
	if data.has("color"):
		color = Color(str(data.color))
	return {"main": color, "trim": accents.get(role, Color("f3da92")), "build": role}

func set_equipment(next_loadout: Dictionary, catalog: Dictionary) -> void:
	if not _built:
		setup()
	_catalog = catalog
	loadout = next_loadout.duplicate(true)
	for slot: String in SLOTS:
		var id: String = str(loadout.get(slot, ""))
		var quest_hat: bool = slot == "head" and id.is_empty() and _golden_hat
		if quest_hat:
			id = "straw_hat"
		var palette: Dictionary = colors_for(id, catalog.get(id, {}))
		if quest_hat:
			palette.main = Color("efbe53")
			palette.trim = Color("fff0ad")
		var signature: String = id + str(palette) + str(quest_hat)
		if str(_slot_signatures.get(slot, "")) == signature:
			continue
		_slot_signatures[slot] = signature
		_clear_slot(slot)
		if id.is_empty():
			continue
		var part: Node3D = _group(_rig, "Equipped_" + slot)
		part.set_meta("item_id", id)
		part.set_meta("slot", slot)
		gear_parts["quest_hat" if quest_hat else slot] = part
		match slot:
			"head":
				hat = part
				_build_hat(part, id, palette.main, palette.trim)
			"body": _build_body(part, id, palette)
			"legs": _build_pants(part, id, palette)
			"feet": _build_boots(part, id, palette)
			"hands": _build_gloves(part, palette)
			"charm": _build_charm(part, id, palette)
	_neutral_body.visible = str(loadout.get("body", "")).is_empty()
	_neutral_pants.visible = str(loadout.get("legs", "")).is_empty()
	for foot in _neutral_feet:
		foot.visible = str(loadout.get("feet", "")).is_empty()
	_update_followers()

func _clear_slot(slot: String) -> void:
	for index in range(_followers.size() - 1, -1, -1):
		if str(_followers[index].slot) == slot:
			_followers.remove_at(index)
	if slot == "head":
		_aurora_materials.clear()
		hat = null
	for key: String in [slot, "quest_hat"] if slot == "head" else [slot]:
		if gear_parts.has(key):
			var part: Node3D = gear_parts[key]
			gear_parts.erase(key)
			part.free()

func _limb_part(parent: Node3D, limb: Node3D, slot: String) -> Node3D:
	var part: Node3D = _group(parent, "Fitted_" + limb.name)
	part.transform = limb.transform
	_followers.append({"node": part, "limb": limb, "slot": slot})
	return part

func _build_body(parent: Node3D, id: String, palette: Dictionary) -> void:
	var coat: bool = "coat" in id
	_shell(parent, 0.35 if coat else 0.60, 1.065, palette.main, 1.075 if coat else 1.042)
	for index in range(_arms.size()):
		var sleeve: Node3D = _limb_part(parent, _arms[index], "body")
		_sphere(sleeve, Vector3(0, -0.11, 0.025), Vector3(0.153, 0.205 if coat else 0.16, 0.171), palette.main)
		_sphere(sleeve, Vector3(0, -0.26 if coat else -0.21, 0.025), Vector3(0.155, 0.036, 0.174), palette.trim)
	for side: float in [-1.0, 1.0]:
		_sphere(parent, _front(side * 0.245, 0.80, 0.035), Vector3(0.113, 0.102, 0.021), palette.main.darkened(0.14))
		_bar(parent, _front(side * 0.245 - 0.075, 0.85, 0.061), _front(side * 0.245 + 0.075, 0.85, 0.061), 0.010, palette.trim)
	if id == "industrialist_overalls":
		_sphere(parent, _front(0, 0.95, 0.043), Vector3(0.25, 0.145, 0.025), palette.main.lightened(0.14))
		for side: float in [-1.0, 1.0]:
			_bar(parent, _front(side * 0.215, 0.94, 0.065), _front(side * 0.25, 1.13, 0.024), 0.038, palette.trim)
			_sphere(parent, _front(side * 0.215, 0.98, 0.095), Vector3.ONE * 0.024, Color("e7dbc4"))
	elif id in ["gambler_shirt", "investor_shirt", "scientist_coat"]:
		for side: float in [-1.0, 1.0]:
			_bar(parent, _front(side * 0.15, 1.055, 0.033), _front(side * 0.075, 0.86, 0.044), 0.032, Color("fff0d0") if id == "investor_shirt" else palette.trim)
		if id == "gambler_shirt":
			for side: float in [-1.0, 1.0]:
				_sphere(parent, _front(side * 0.047, 1.06, 0.077), Vector3(0.049, 0.032, 0.025), palette.trim)
		elif id == "scientist_coat":
			var flask: Vector3 = _front(-0.245, 0.83, 0.085)
			_sphere(parent, flask, Vector3(0.046, 0.055, 0.030), Color("75dca8"))
			_cylinder(parent, flask + Vector3(0, 0.064, 0), 0.018, 0.018, 0.052, Color("e2fff3"))
	for y: float in [0.79, 0.89, 0.99]:
		_sphere(parent, _front(0, y, 0.051), Vector3(0.021, 0.021, 0.015), palette.trim)

func _build_pants(parent: Node3D, id: String, palette: Dictionary) -> void:
	_shell(parent, 0.215, 0.67, palette.main, 1.039)
	_shell(parent, 0.63, 0.69, palette.trim.darkened(0.15), 1.047)
	_sphere(parent, _front(0, 0.663, 0.037), Vector3(0.053, 0.037, 0.022), palette.trim)
	for index in range(_legs.size()):
		var leg: Node3D = _limb_part(parent, _legs[index], "legs")
		_sphere(leg, Vector3(0, -0.065, 0), Vector3(0.17, 0.175, 0.18), palette.main)
		if id in ["scientist_pants", "industrialist_pants"]:
			_sphere(leg, Vector3((-1 if index == 0 else 1) * 0.137, -0.045, 0.057), Vector3(0.051, 0.075, 0.097), palette.main.lightened(0.15))
		elif id == "gambler_pants":
			_bar(leg, Vector3(0, -0.03, 0.178), Vector3(0, -0.14, 0.153), 0.014, palette.trim)
		elif id == "farmer_pants":
			_sphere(leg, Vector3(0, -0.09, 0.164), Vector3(0.075, 0.055, 0.015), palette.main.lightened(0.2))

func _build_boots(parent: Node3D, id: String, palette: Dictionary) -> void:
	for limb in _legs:
		var boot: Node3D = _limb_part(parent, limb, "feet")
		var sole_color: Color = Color("f0e6d1") if id == "gambler_boots" else palette.main.darkened(0.35)
		_sphere(boot, Vector3(0, -0.274, 0.11), Vector3(0.215, 0.068, 0.302), sole_color)
		_sphere(boot, Vector3(0, -0.21, 0.115), Vector3(0.208, 0.136, 0.288), palette.main)
		if id in ["farmer_boots", "scientist_boots", "industrialist_boots"]:
			_sphere(boot, Vector3(0, -0.13, 0.015), Vector3(0.184, 0.13, 0.195), palette.main)
			_sphere(boot, Vector3(0, -0.04, 0.015), Vector3(0.188, 0.035, 0.20), palette.trim)
		if id == "industrialist_boots":
			_sphere(boot, Vector3(0, -0.18, 0.30), Vector3(0.182, 0.098, 0.113), Color("99a5a7"))
		elif id == "gambler_boots":
			for offset in range(3):
				_bar(boot, Vector3(-0.075, -0.10, 0.12 + offset * 0.045), Vector3(0.075, -0.10, 0.12 + offset * 0.045), 0.011, sole_color)
		elif id == "scientist_boots":
			_sphere(boot, Vector3(0, -0.085, 0.21), Vector3(0.045, 0.035, 0.019), Color("b8ffb0"))
		elif id == "investor_shoes":
			_sphere(boot, Vector3(0, -0.09, 0.18), Vector3(0.105, 0.024, 0.045), palette.trim)

func _build_gloves(parent: Node3D, palette: Dictionary) -> void:
	for limb in _arms:
		var glove: Node3D = _limb_part(parent, limb, "hands")
		_sphere(glove, Vector3(0, -0.35, 0.05), Vector3(0.156, 0.161, 0.179), palette.main)
		_sphere(glove, Vector3(-0.102, -0.31, 0.13), Vector3(0.058, 0.082, 0.067), palette.main.lightened(0.08))
		_sphere(glove, Vector3(0, -0.255, 0.038), Vector3(0.16, 0.041, 0.175), palette.trim)
		for x: float in [-0.055, 0.0, 0.055]:
			_bar(glove, Vector3(x, -0.33, 0.22), Vector3(x, -0.39, 0.218), 0.008, palette.main.darkened(0.22))

func _build_hat(parent: Node3D, id: String, color: Color, trim: Color) -> void:
	if id == "aurora_crown":
		var band: MeshInstance3D = _torus(parent, Vector3(0, 1.70, -0.015), 0.34, 0.405, Color("ebda92"))
		band.scale.z = 0.87
		for index in range(8):
			var angle: float = TAU * index / 8.0
			var origin: Vector3 = Vector3(sin(angle) * 0.365, 1.81, cos(angle) * 0.315 - 0.015)
			_cylinder(parent, origin, 0.067, 0.009, 0.25 + (0.045 if index % 2 == 0 else 0.0), Color("ebda92"))
			var jewel_color: Color = [color, Color("be9cff"), Color("9cf6d3")][index % 3]
			var jewel: MeshInstance3D = _cylinder(parent, origin + Vector3(0, 0.09, 0), 0.055, 0.0, 0.14, jewel_color)
			(jewel.mesh as CylinderMesh).radial_segments = 6
			var jewel_base: MeshInstance3D = _cylinder(parent, origin + Vector3(0, -0.0025, 0), 0.0, 0.055, 0.045, jewel_color)
			(jewel_base.mesh as CylinderMesh).radial_segments = 6
			var glow: StandardMaterial3D = (jewel.material_override as StandardMaterial3D).duplicate()
			glow.emission_enabled = true
			glow.emission = glow.albedo_color
			glow.emission_energy_multiplier = 0.8
			jewel.material_override = glow
			jewel_base.material_override = glow
			_aurora_materials.append(glow)
		return
	if id == "traders_visor":
		var band: MeshInstance3D = _torus(parent, Vector3(0, 1.655, -0.008), 0.325, 0.378, color)
		band.scale.z = 0.85
		_sphere(parent, Vector3(0, 1.65, 0.29), Vector3(0.43, 0.038, 0.285), color)
		_sphere(parent, Vector3(0, 1.66, 0.44), Vector3(0.35, 0.020, 0.115), trim)
		return
	if id == "lucky_cap":
		_sphere(parent, Vector3(0, 1.755, -0.045), Vector3(0.43, 0.218, 0.36), color)
		_sphere(parent, Vector3(0, 1.695, 0.30), Vector3(0.36, 0.035, 0.29), color.darkened(0.09))
		_sphere(parent, Vector3(0, 1.825, 0.293), Vector3(0.089, 0.070, 0.016), trim)
		for offset: Vector3 in [Vector3(-0.023, 0.0, 0), Vector3(0.023, 0.0, 0), Vector3(0, 0.030, 0)]:
			_sphere(parent, Vector3(0, 1.825, 0.312) + offset, Vector3(0.027, 0.029, 0.009), color.darkened(0.25))
		_sphere(parent, Vector3(0, 1.963, -0.045), Vector3(0.045, 0.020, 0.045), trim)
		return
	var brim: MeshInstance3D = _cylinder(parent, Vector3(0, 1.70, -0.02), 0.67 if id == "straw_hat" else 0.55, 0.66 if id == "straw_hat" else 0.54, 0.055, color)
	brim.scale.z = 0.84
	_sphere(parent, Vector3(0, 1.79, -0.03), Vector3(0.395, 0.213, 0.325), color.lightened(0.08))
	var ribbon: MeshInstance3D = _torus(parent, Vector3(0, 1.755, -0.03), 0.363, 0.403, Color("9b7048") if id == "straw_hat" else trim)
	ribbon.scale.z = 0.84
	if id == "prospectors_hat":
		_sphere(parent, Vector3(0, 1.82, 0.31), Vector3(0.101, 0.083, 0.045), Color("6d6b57"))
		_sphere(parent, Vector3(0, 1.82, 0.35), Vector3(0.072, 0.058, 0.018), Color("fff4bc"))

func _build_charm(parent: Node3D, id: String, palette: Dictionary) -> void:
	if id == "market_monocle":
		var ring: MeshInstance3D = _torus(parent, Vector3(0.20, 1.36, 0.48), 0.104, 0.122, palette.main)
		ring.rotation.x = PI * 0.5
		for index in range(5):
			var y: float = 1.25 - index * 0.067
			_bar(parent, _front(0.31, y, 0.032), _front(0.31, y - 0.052, 0.032), 0.009, palette.main)
		return
	_bar(parent, _front(0.32, 0.95, 0.065), _front(0.35, 0.76, 0.070), 0.012, palette.trim)
	var charm: Vector3 = _front(0.35, 0.69, 0.089)
	_sphere(parent, charm, Vector3(0.118, 0.123, 0.085), palette.main)
	for xy: Vector2 in [Vector2(-0.045, -0.045), Vector2(0.045, -0.045), Vector2.ZERO, Vector2(-0.045, 0.045), Vector2(0.045, 0.045)]:
		_sphere(parent, charm + Vector3(xy.x, xy.y, 0.078), Vector3(0.014, 0.014, 0.010), Color("fff5df"))

func set_golden_hat(enabled: bool) -> void:
	if _golden_hat == enabled:
		return
	_golden_hat = enabled
	set_equipment(loadout, _catalog)

func animate(delta: float, moving: bool = false) -> void:
	if not _built or not is_finite(delta) or delta <= 0.0:
		return
	_time += delta
	_walk_blend = lerpf(_walk_blend, 1.0 if moving else 0.0, 1.0 - exp(-delta * 9.0))
	_stride += delta * lerpf(2.0, 8.2, _walk_blend)
	var breath: float = sin(_time * 2.05)
	_rig.position.y = breath * 0.015 * (1.0 - _walk_blend) + (1.0 - cos(_stride * 2.0)) * 0.026 * _walk_blend
	_rig.rotation.z = sin(_stride) * 0.051 * _walk_blend
	_rig.scale = Vector3(1.0 + breath * 0.004, 1.0 - breath * 0.003, 1.0 + breath * 0.003)
	for index in range(_legs.size()):
		var step: float = sin(_stride + index * PI)
		_legs[index].rotation.x = step * 0.29 * _walk_blend
		_arms[index].rotation.x = -step * 0.23 * _walk_blend
		_arms[index].rotation.z = (-1.0 if index == 0 else 1.0) * (0.16 + absf(step) * 0.045 * _walk_blend)
	var blink_phase: float = fmod(_time + 0.9, 4.7)
	var openness: float = 1.0
	if blink_phase > 4.50:
		openness = maxf(0.06, absf((blink_phase - 4.60) / 0.10))
	for eye in _eyes:
		eye.scale.y = openness
	for material in _aurora_materials:
		material.emission_energy_multiplier = 0.65 + (sin(_time * 2.2) + 1.0) * 0.22
	_update_followers()

func _update_followers() -> void:
	for attachment in _followers:
		(attachment.node as Node3D).transform = (attachment.limb as Node3D).transform

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

func _shell(parent: Node3D, bottom: float, top: float, color: Color, inflate: float) -> MeshInstance3D:
	# A garment is a latitude band of the same ellipsoid as the potato. It has
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
