extends Control
## A small live history chart. It redraws only when its samples change.
var samples: Array = []
var line_color: Color = Color("377858")
var _signature: String = ""
var expected_price: float = 0.0

func set_expected_price(value: float) -> void:
	if is_equal_approx(expected_price, value): return
	expected_price = value
	queue_redraw()

func set_history(history: Array, color: Color) -> void:
	var signature: String = str(history) + str(color)
	if signature == _signature:
		return
	_signature = signature
	samples = history.duplicate()
	line_color = color
	queue_redraw()

func _draw() -> void:
	if samples.is_empty(): return
	var low: float = float(samples[0])
	var high: float = low
	for value: Variant in samples:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	if expected_price > 0:
		low = minf(low, expected_price)
		high = maxf(high, expected_price)
	var spread: float = maxf(high - low, maxf(1.0, high * 0.02))
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(samples.size()):
		points.append(Vector2(3.0 + float(index) / float(maxi(1, samples.size() - 1)) * (size.x - 6.0), size.y - 4.0 - (float(samples[index]) - low) / spread * (size.y - 8.0)))
	draw_line(Vector2(0, size.y - 3), Vector2(size.x, size.y - 3), Color(line_color, 0.16), 1.0)
	if points.size() == 1: points.append(Vector2(size.x - 3, points[0].y))
	draw_polyline(points, line_color, 2.0, true)
	if expected_price > 0:
		var y: float = size.y - 4.0 - (expected_price - low) / spread * (size.y - 8.0)
		for x in range(3, int(size.x) - 3, 8): draw_line(Vector2(x, y), Vector2(minf(x + 4, size.x - 3), y), Color(line_color, 0.85), 2.0)
	draw_circle(points[points.size() - 1], 3.0, line_color)
