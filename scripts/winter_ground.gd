extends RefCounted
## An opaque snow skin follows the Valley triangles, including stairs and coast.
const Surface = preload("res://scripts/farm_surface.gd")
const HEIGHT := 0.13
const PATH_HEIGHT := 0.178

static func build() -> MeshInstance3D:
	var source: Array = Surface.mesh().surface_get_arrays(0)
	var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,positions.size(),3):
		if normals[i].y <= 0.0: continue
		for j in range(3):
			surface.set_normal(normals[i+j])
			surface.add_vertex(positions[i+j]+Vector3(0,HEIGHT,0))
	var ground := MeshInstance3D.new()
	ground.name = "WinterGroundSnow"
	ground.mesh = surface.commit()
	ground.material_override = _material()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ground

static func paths(lanes: Array) -> MeshInstance3D:
	# Clip the real terrain triangles to each lane so even stair treads stay
	# continuous. The compacted surface sits above the pillows and below tracks.
	var source: Array = Surface.mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lane in lanes:
		var side: Vector3=(lane.b-lane.a).normalized().cross(Vector3.UP)*float(lane.width)*.5
		var low: Vector3=(lane.a-side).min(lane.a+side).min(lane.b-side).min(lane.b+side)
		var high: Vector3=(lane.a-side).max(lane.a+side).max(lane.b-side).max(lane.b+side)
		for i in range(0,vertices.size(),3):
			if normals[i].y<=0: continue
			var a: Vector3=vertices[i]; var b: Vector3=vertices[i+1]; var c: Vector3=vertices[i+2]
			if a.max(b).max(c).x<low.x or a.min(b).min(c).x>high.x or a.max(b).max(c).z<low.z or a.min(b).min(c).z>high.z: continue
			var polygon: Array[Vector3]=[a,b,c]
			for edge in [[0,low.x,1],[0,high.x,-1],[2,low.z,1],[2,high.z,-1]]:
				polygon=_clip(polygon,edge[0],edge[1],edge[2])
			for j in range(1,polygon.size()-1):
				for p: Vector3 in [polygon[0],polygon[j],polygon[j+1]]:
					surface.set_normal(normals[i])
					surface.add_vertex(p+Vector3(0,PATH_HEIGHT,0))
	var strip:=MeshInstance3D.new()
	strip.name="CompactedSnowPaths"
	strip.mesh=surface.commit()
	var material:=_material()
	material.set_shader_parameter("ground_surface",false)
	material.set_shader_parameter("snow_color",Color("dce1e0"))
	strip.material_override=material
	strip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return strip

static func _clip(points: Array[Vector3], axis: int, edge: float, direction: int) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if points.is_empty(): return result
	var previous: Vector3=points.back()
	var was_inside: bool=(previous[axis]-edge)*direction>=0
	for point in points:
		var inside: bool=(point[axis]-edge)*direction>=0
		if inside!=was_inside:
			result.append(previous.lerp(point,(edge-previous[axis])/(point[axis]-previous[axis])))
		if inside: result.append(point)
		previous=point; was_inside=inside
	return result

static func _material() -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=preload("res://scripts/winter_ground.gdshader")
	return material
