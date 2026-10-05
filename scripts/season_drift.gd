extends Node3D
## Six small opaque shapes at a time, independent of gameplay and input.
var season: int = -1
var elapsed: float = 0.0
var pieces: Array[MeshInstance3D] = []
func setup() -> void:
	name = "SeasonDrift"
	var mesh := SphereMesh.new(); mesh.radius = 1; mesh.height = 2; mesh.radial_segments = 8; mesh.rings = 4
	for index in range(6):
		var piece := MeshInstance3D.new(); piece.mesh = mesh; piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.material_override = StandardMaterial3D.new(); add_child(piece); pieces.append(piece)
func advance(delta: float, index: int) -> void:
	elapsed += maxf(0, delta)
	if season != index:
		season = index
		visible = season in [0, 2, 3]
		for piece in pieces:
			piece.material_override.albedo_color = {0: Color("f3c4d2"), 2: Color("c89859"), 3: Color("f2f1e8")}.get(season, Color.WHITE)
	if not visible: return
	for i in range(pieces.size()):
		var t: float = fmod(elapsed + i * 3.1, 21)
		pieces[i].position = Vector3(-20 + i * 6.8 + t * .23, 5.5 - t * .23, -7 + sin(t * .35 + i) * 2)
		pieces[i].rotation = Vector3(t * .25, t * .3 + i, sin(t * .4 + i) * .4)
		pieces[i].scale = Vector3(.06, .06, .06) if season == 3 else Vector3(.15, .025, .08)
