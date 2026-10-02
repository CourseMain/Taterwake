extends PanelContainer
## Painted frames and stock-bin joinery. Every line follows a structural edge.
var base := Color("eee1c5")
var edge := Color("405a6b")
var radius: int = 3
var padding: int = 16
var frame: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var skin := StyleBoxFlat.new()
	skin.bg_color = base
	skin.border_color = edge
	skin.set_border_width_all(2 if frame else 1)
	skin.set_corner_radius_all(radius)
	skin.set_content_margin_all(padding)
	add_theme_stylebox_override("panel", skin)
	resized.connect(queue_redraw)

func _draw() -> void:
	if not frame: return
	for y: float in [8.0, size.y - 8.0]: draw_line(Vector2(4, y), Vector2(size.x - 4, y), Color(edge, .25), 2, true)
	# Corner straps tie the rack together; the middle stays clear for stock.
	for x: float in [4.0, size.x - 4.0]:
		var direction := 1.0 if x < size.x / 2.0 else -1.0
		for y: float in [4.0, size.y - 4.0]:
			draw_line(Vector2(x, y), Vector2(x + direction * 14.0, y), edge, 2, true)
