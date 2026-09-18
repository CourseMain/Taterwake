extends Control
## A small live history chart. It redraws only when its samples change.
var samples: Array = []
var line_color: Color = Color("377858")
var _signature: String = ""

func set_history(history: Array, color: Color) -> void:
	var signature: String = str(history) + str(color)
	if signature == _signature:
		return
	_signature = signature
	samples = history.duplicate()
	line_color = color
	queue_redraw()

func _draw() -> void:
	if samples.size() < 2:
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), line_color, 2.0, true)
		return
	var low: float = float(samples[0])
	var high: float = low
	for value: Variant in samples:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	var spread: float = maxf(high - low, maxf(1.0, high * 0.02))
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(samples.size()):
		points.append(Vector2(3.0 + float(index) / float(samples.size() - 1) * (size.x - 6.0), size.y - 4.0 - (float(samples[index]) - low) / spread * (size.y - 8.0)))
	draw_line(Vector2(0, size.y - 3), Vector2(size.x, size.y - 3), Color(line_color, 0.16), 1.0)
	draw_polyline(points, line_color, 2.0, true)
	draw_circle(points[points.size() - 1], 3.0, line_color)
