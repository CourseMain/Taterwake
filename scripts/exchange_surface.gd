extends PanelContainer
## Reused stall timber and chalkboard, with wear kept clear of the figures.
var chalkboard: bool = false

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
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
