extends PanelContainer
## Chunky paper, wood edge and inset cream rule from the kit.
const Kit = preload("res://scripts/ui_kit.gd")
var fill: Color = Kit.PAPER
var edge: Color = Kit.WOOD
var unit: float = 1
var tilt: Tween
var shine: GradientTexture2D
func _ready() -> void:
	shine = GradientTexture2D.new(); shine.width = 32; shine.height = 64
	shine.fill_from = Vector2(.5, 0); shine.fill_to = Vector2(.5, 1)
	shine.gradient = Gradient.new(); shine.gradient.colors = PackedColorArray([Color(Kit.CREAM, .22), Color(Kit.CREAM, 0)])
	add_theme_stylebox_override("panel", Kit.skin(fill, edge, 12, 12, unit))
	resized.connect(func(): pivot_offset = size * .5; queue_redraw())
	mouse_entered.connect(func(): _tilt(-2))
	mouse_exited.connect(func(): _tilt(0))
func _draw() -> void:
	if not get_meta("kit_screen", true): return
	if is_instance_valid(shine): draw_texture_rect(shine, Rect2(Vector2.ONE * 8 * unit, Vector2(size.x - 16 * unit, minf(size.y - 16 * unit, 72 * unit))), false)
	if fill == Kit.WOOD: return
	var rule := Kit.skin(Color.TRANSPARENT, Kit.CREAM, 0, 7, unit, false)
	rule.set_border_width_all(ceili(2 * unit))
	draw_style_box(rule, Rect2(Vector2.ONE * 6 * unit, size - Vector2.ONE * 12 * unit))
func _tilt(degrees: float) -> void:
	if not get_meta("kit_screen", true) or get_meta("kit_modal", false): return
	if is_instance_valid(tilt): tilt.kill()
	tilt = create_tween(); tilt.tween_property(self, "rotation", deg_to_rad(degrees), .15)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: _tilt(0 if event.pressed else -2)
