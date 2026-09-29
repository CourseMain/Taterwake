extends RefCounted
## One snow skin follows the exact Valley triangles, including stairs and coast.
const Surface = preload("res://scripts/farm_surface.gd")
const EXPOSED_FRACTION := 0.15
const HEIGHT := 0.13

static func build() -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 18301
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.19
	noise.fractal_octaves = 3
	var source: Array = Surface.mesh().surface_get_arrays(0)
	var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Array[Vector2] = []
	var area := 0.0
	for i in range(0,positions.size(),3):
		# The closed terrain prism also has strata and underside faces.
		if normals[i].y <= 0.0 or minf(positions[i].y,minf(positions[i+1].y,positions[i+2].y)) < -0.2: continue
		var a: Vector3 = positions[i]
		var b: Vector3 = positions[i+1]
		var c: Vector3 = positions[i+2]
		var triangle_area: float = absf((b-a).cross(c-a).y)*0.5
		var mask := Vector3(
			noise.get_noise_2d(a.x,a.z)*0.5+0.5,
			noise.get_noise_2d(b.x,b.z)*0.5+0.5,
			noise.get_noise_2d(c.x,c.z)*0.5+0.5)
		# Area weighting prevents the tightly sampled terrace/stair rows from
		# biasing the percentage. These four points sample the shader's mask.
		for weight in [Vector3(1,1,1)/3,Vector3(4,1,1)/6,Vector3(1,4,1)/6,Vector3(1,1,4)/6]:
			samples.append(Vector2(mask.dot(weight),triangle_area*0.25))
		area += triangle_area
		for j in range(3):
			surface.set_color(Color(mask[j],0,0,1))
			surface.set_normal(normals[i+j])
			surface.add_vertex(positions[i+j]+Vector3(0,HEIGHT,0))
	samples.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var exposed := 0.0
	var threshold := 0.5
	for sample in samples:
		exposed += sample.y
		threshold = sample.x
		if exposed >= area*EXPOSED_FRACTION: break
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/winter_ground.gdshader")
	material.set_shader_parameter("exposure_threshold",threshold)
	var ground := MeshInstance3D.new()
	ground.name = "WinterGroundSnow"
	ground.mesh = surface.commit()
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.set_meta("exposed_fraction",exposed/area)
	ground.set_meta("snow_height",HEIGHT)
	return ground
