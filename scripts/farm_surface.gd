extends RefCounted
## The Valley outline, height map, paths and walking all share world coordinates.
const EXTENT := Vector2(40.3 * 1.6, 30.7 * 1.4) * 1.2247448714
const CUT := Vector2(12.0, EXTENT.y * 0.5)
const TERRACE_RISE: float = 0.8
const TREAD_SPACING: float = 0.22
const TREAD_COUNT: int = 4
const STAIR_START: float = 0.18
const STEPS := [-12.5, -13.5, -14.5]
const PATH_X: float = -23.0

static var _xs: Array[float] = _x_samples()
static var _zs: Array[float] = _z_samples()

static func _x_samples() -> Array[float]:
	var values: Array[float] = [-EXTENT.x*0.5,EXTENT.x*0.5,PATH_X-1.2,PATH_X+1.2]
	for x in range(-34,35): values.append(float(x))
	values.sort()
	return values

static func _z_samples() -> Array[float]:
	var values: Array[float] = [-EXTENT.y*0.5,EXTENT.y*0.5]
	for z in range(-26,27): values.append(float(z))
	for edge: float in STEPS:
		for distance: float in [0.0,-0.25]: values.append(edge+distance)
		for tread in range(TREAD_COUNT):
			values.append(edge+STAIR_START-tread*TREAD_SPACING)
			values.append(edge+STAIR_START-tread*TREAD_SPACING-0.06)
	values.sort()
	return values

static func height_at(x: float, z: float) -> float:
	# Sample the same two triangles that rendering and picking use, including
	# the stair shoulders and Low's gradual dip. No separate collision slope.
	var i: int = clampi(_xs.bsearch(x)-1,0,_xs.size()-2)
	var j: int = clampi(_zs.bsearch(z)-1,0,_zs.size()-2)
	var u: float = clampf(inverse_lerp(_xs[i],_xs[i+1],x),0,1)
	var v: float = clampf(inverse_lerp(_zs[j],_zs[j+1],z),0,1)
	var a: float = _profile(_xs[i],_zs[j])
	var c: float = _profile(_xs[i+1],_zs[j+1])
	if u >= v:
		return a*(1-u)+_profile(_xs[i+1],_zs[j])*(u-v)+c*v
	return a*(1-v)+c*u+_profile(_xs[i],_zs[j+1])*(v-u)

static func _profile(x: float, z: float) -> float:
	var hill: float = 0.0
	for edge: float in STEPS:
		hill += TERRACE_RISE * clampf((edge - z) / 0.25, 0.0, 1.0)
	if absf(x - PATH_X) < 2.0:
		var stairs: float = 0.0
		for edge: float in STEPS:
			for tread in range(TREAD_COUNT):
				stairs += TERRACE_RISE / TREAD_COUNT * clampf((edge+STAIR_START-tread*TREAD_SPACING-z)/0.06,0,1)
		hill = lerpf(hill,stairs,clampf((2.0-absf(x-PATH_X))/0.8,0,1))
	var low: float = smoothstep(7.0, 10.0, x) * smoothstep(7.0, 10.0, z)
	return hill - 0.15 * low

static func half_width(z: float, margin: float = 0.0) -> float:
	return EXTENT.x * 0.5 - margin - maxf(0, absf(z) - (EXTENT.y * 0.5 - CUT.y)) * CUT.x / CUT.y

static func clamp_point(point: Vector3) -> Vector3:
	var z: float = clampf(point.z, -EXTENT.y * 0.5 + 0.7, EXTENT.y * 0.5 - 0.7)
	var x: float = clampf(point.x, -half_width(z, 0.7), half_width(z, 0.7))
	return Vector3(x, height_at(x, z), z)

static func move(from: Vector3, to: Vector3) -> Vector3:
	var result := clamp_point(to)
	for edge: float in STEPS:
		if (from.z > edge - 0.125) != (result.z > edge - 0.125):
			var fraction: float = (edge - 0.125 - from.z) / (result.z - from.z)
			if absf(lerpf(from.x, result.x, fraction) - PATH_X) > 1.0:
				result.z = edge + 0.04 if from.z > edge - 0.125 else edge - 0.29
	result.y = height_at(result.x, result.z)
	return result

static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var target := clamp_point(to)
	var crosses := false
	for edge: float in STEPS:
		if (from.z > edge - 0.125) != (target.z > edge - 0.125): crosses = true
	if not crosses: return [target]
	# Join the rail path at the current level before crossing any riser.
	return [clamp_point(Vector3(PATH_X, 0, from.z)), clamp_point(Vector3(PATH_X, 0, target.z)), target]

static func mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for z: float in _zs:
		var width: float = half_width(z)
		var row: Array[Vector3] = []
		for source_x: float in _xs:
			var x: float = clampf(source_x,-width,width)
			row.append(Vector3(x,_profile(x,z),z))
		rows.append(row)
	for j in range(rows.size() - 1):
		for i in range(rows[j].size() - 1):
			for triangle in [[rows[j][i],rows[j][i+1],rows[j+1][i+1]],[rows[j][i],rows[j+1][i+1],rows[j+1][i]]]:
				# Clipped columns converge along the six angled coast edges.
				var ab: Vector3 = triangle[1]-triangle[0]
				var ac: Vector3 = triangle[2]-triangle[0]
				if ab.cross(ac).length_squared() < 0.00000001: continue
				for point: Vector3 in triangle: surface.add_vertex(point)
	# Strata belong to the same closed prism, including the raised back coast.
	var outline: Array[Vector3] = []
	outline.append_array(rows[0])
	for row: Array in rows.slice(1): outline.append(row.back())
	var back: Array = rows.back().duplicate(); back.reverse()
	outline.append_array(back.slice(1))
	for j in range(rows.size() - 2, 0, -1): outline.append(rows[j][0])
	for i in range(outline.size()):
		var a: Vector3 = outline[i]; var b: Vector3 = outline[(i+1) % outline.size()]
		if a.is_equal_approx(b): continue
		var bottom_a := Vector3(a.x, -2.2, a.z); var bottom_b := Vector3(b.x, -2.2, b.z)
		for p: Vector3 in [b, a, bottom_a, bottom_b, b, bottom_a, bottom_a, Vector3(0,-2.2,0), bottom_b]: surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
