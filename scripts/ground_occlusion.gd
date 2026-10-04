extends RefCounted
## A small build-only spatial grid. No occlusion scans run in the frame loop.
const CELL := 4.0
var cells: Dictionary = {}
var samples := 0

func add_patch(center: Vector3, span: Vector2, amount: float = .18) -> void:
	_add({"center":center, "span":span, "amount":clampf(amount,.1,.2)}, Vector2(center.x,center.z)-span, Vector2(center.x,center.z)+span)

func add_fence(a: Vector3, b: Vector3) -> void:
	_add({"a":a,"b":b,"amount":.12}, Vector2(minf(a.x,b.x)-.6,minf(a.z,b.z)-.6), Vector2(maxf(a.x,b.x)+.6,maxf(a.z,b.z)+.6))

func _add(patch: Dictionary, low: Vector2, high: Vector2) -> void:
	for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
		for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
			var key := Vector2i(x,z)
			if not cells.has(key): cells[key] = []
			cells[key].append(patch)

func factor(point: Vector3) -> float:
	samples += 1
	var strength := 0.0
	var ground: float = preload("res://scripts/farm_surface.gd").height_at(point.x, point.z)
	var low: float = 1.0-smoothstep(.1,2.0,maxf(0,point.y-ground))
	for patch: Dictionary in cells.get(Vector2i(floori(point.x/CELL),floori(point.z/CELL)), []):
		var distance: float
		if patch.has("center"):
			distance = Vector2((point.x-patch.center.x)/patch.span.x,(point.z-patch.center.z)/patch.span.y).length()
		else:
			var a := Vector2(patch.a.x,patch.a.z)
			var b := Vector2(patch.b.x,patch.b.z)
			var p := Vector2(point.x,point.z)
			var closest: Vector2 = a+(b-a)*clampf((p-a).dot(b-a)/maxf(.001,(b-a).length_squared()),0,1)
			distance = p.distance_to(closest)/.6
		strength = maxf(strength,patch.amount*(1.0-smoothstep(.25,1.0,distance))*low)
	return 1.0-strength

func bake(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var colours := PackedColorArray()
	var cache: Dictionary = {}
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		if not cache.has(point): cache[point] = factor(point)
		colours.append(Color.WHITE * float(cache[point]))
	arrays[Mesh.ARRAY_COLOR] = colours
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return baked
