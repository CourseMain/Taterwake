extends RefCounted
## Shared grass and seasonal snow material for the continuous Valley prism.
const SURFACE = preload("res://scripts/island_terrain.gdshader")

static func material(is_snow: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("snow", is_snow)
	return result
