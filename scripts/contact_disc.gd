extends RefCounted
## Shared feathered ground contact; static contacts use one instanced draw.
static var mesh: ArrayMesh
static var material: StandardMaterial3D

static func make() -> MeshInstance3D:
	prepare()
	var disc := MeshInstance3D.new()
	disc.name = "SoftContactDisc"
	disc.mesh = mesh
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc

static func prepare() -> void:
	if mesh != null: return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a := Vector3(cos(i*TAU/16),0,sin(i*TAU/16))
		var b := Vector3(cos((i+1)*TAU/16),0,sin((i+1)*TAU/16))
		for pair: Array in [[Vector3.ZERO,.19],[b,0.0],[a,0.0]]:
			surface.set_color(Color(.08,.13,.17,pair[1]))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(pair[0])
	mesh = surface.commit()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
