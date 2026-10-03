extends RefCounted
## Compatibility has no geometry transparency. Temporary material variants
## supply the one-second fade; the usual opaque materials resume afterwards.
var entries: Array[Dictionary] = []
var materials: Dictionary = {}
var opacity := -1.0
# Snow is rebuilt when protection structures change. Share its fade shader so
# those meshes reuse the program already compiled for the first snowfall.
static var _shaders: Dictionary = {}

func collect(root: Node3D) -> void:
	entries.clear()
	materials.clear()
	opacity = -1.0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var original: Material = node.material_override
		if original == null: continue
		var id: int = original.get_instance_id()
		if not materials.has(id):
			var faded: Material = original.duplicate()
			if faded is ShaderMaterial:
				var code: String = original.shader.code
				if not _shaders.has(code):
					var shader := Shader.new()
					shader.code = code.replace("void fragment() {", "uniform float season_opacity = 1.0;\nvoid fragment() {\n\tALPHA = season_opacity;")
					_shaders[code] = shader
				faded.shader = _shaders[code]
			elif faded is StandardMaterial3D:
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			materials[id] = faded
		entries.append({"node": node, "original": original, "fade": materials[id]})

func set_opacity(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, opacity): return
	opacity = value
	for entry in entries:
		if not is_instance_valid(entry.node): continue
		entry.node.material_override = entry.original if value >= 1.0 or value <= 0.0 else entry.fade
	for material: Material in materials.values():
		if material is ShaderMaterial:
			material.set_shader_parameter("season_opacity", value)
		elif material is StandardMaterial3D:
			var tint: Color = material.albedo_color
			tint.a = value
			material.albedo_color = tint
