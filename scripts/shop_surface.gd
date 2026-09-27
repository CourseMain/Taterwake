extends PanelContainer
## Static, cached lighting keeps the workbench and barn soft on native and web.
const Lighting = preload("res://scripts/exchange_surface.gd")
var base := Color("304753")
var light := Color("dfa772")
var radius: int = 22
var padding: int = 20

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", Lighting.soft_skin(base, light, base.darkened(0.13), padding, radius))
