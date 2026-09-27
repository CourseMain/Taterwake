extends PanelContainer
## Solid painted timber and canvas frames for the village shops.
var chalkboard: bool = false
var plain_frame: bool = false

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	if plain_frame: return
	var edge := Color("795a3c")
	if chalkboard:
		# The ledge holds the chalk. The middle stays clean for the live quote.
		draw_line(Vector2(8, size.y - 7), Vector2(size.x - 8, size.y - 7), edge, 5, true)
		draw_line(Vector2(size.x - 44, size.y - 11), Vector2(size.x - 24, size.y - 12), Color("eee7cf"), 4, true)
		draw_line(Vector2(18, 10), Vector2(44, 11), Color("bdc9ad", 0.16), 2, true)
	else:
		for y: float in [7.0, size.y - 8.0]:
			draw_line(Vector2(5, y), Vector2(size.x - 5, y), edge, 3, true)
		# Short grain marks along the counter lip, not underneath any text.
		for index: int in range(4):
			var start := 29.0 + float(index) * (size.x - 60.0) / 4.0
			draw_line(Vector2(start, size.y - 15), Vector2(start + 22, size.y - 14), Color(edge, 0.28), 1, true)
	for point: Vector2 in [Vector2(9, 8), Vector2(size.x - 9, 8), Vector2(9, size.y - 8), Vector2(size.x - 9, size.y - 8)]:
		draw_circle(point, 2.1, Color("544c3e"), true, -1, true)
		draw_line(point - Vector2(1, 0), point + Vector2(1, 0), Color("d0bc92"), 1, true)


static func framed_skin(base: Color, frame: Color, secondary: Color = Color.TRANSPARENT, padding: int = 20, radius: int = 3) -> StyleBoxFlat:
	# Kept as the shared skin entry point. Colours occupy separate, solid areas;
	# no blended textures, translucent lighting, or cached gradient images.
	var skin := StyleBoxFlat.new()
	skin.bg_color = base
	skin.border_color = frame if secondary.a == 0.0 else secondary
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(clampi(radius, 2, 5))
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_content_margin(edge, padding)
	return skin

static func apply_modal_frame(modal: PanelContainer, base: Color, frame: Color, secondary: Color = Color.TRANSPARENT) -> void:
	var previous: StyleBox = modal.get_theme_stylebox("panel")
	var skin: StyleBoxFlat = framed_skin(base, frame, secondary, 24, 4)
	skin.set_border_width_all(3)
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_content_margin(edge, previous.get_content_margin(edge))
	modal.add_theme_stylebox_override("panel", skin)
