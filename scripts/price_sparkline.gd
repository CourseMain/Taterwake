extends Control
## A small live history chart. It redraws only when its samples change.
var samples: Array = []
var line_color: Color = Color("377858")
var _signature: String = ""
var expected_price: float = 0.0
var font: Font = preload("res://scripts/ui_type.gd").face(preload("res://scripts/ui_type.gd").BODY)

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

func chart_geometry() -> Dictionary:
	if samples.is_empty(): return {}
	var low: float = float(samples[0])
	var high: float = low
	for value: Variant in samples:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	# Zoom to actual recent quotes. A distant Winter target must not flatten them.
	var middle: float = (low + high) * 0.5
	var spread: float = maxf(high - low, maxf(absf(middle) * 0.005, 0.01))
	var limits := Vector2(middle - spread * 0.65, middle + spread * 0.65)
	var pixels: int = 14
	if is_inside_tree(): pixels = maxi(14, ceili(14 * get_viewport_rect().size.x / get_tree().root.size.x))
	var plot := Rect2(3, pixels + 7, maxf(1, size.x - 6), maxf(1, size.y - pixels - 11))
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(samples.size()):
		points.append(Vector2(plot.position.x + float(index) / float(maxi(1, samples.size() - 1)) * plot.size.x, plot.end.y - (float(samples[index]) - limits.x) / (limits.y - limits.x) * plot.size.y))
	if points.size() == 1: points.append(Vector2(plot.end.x, points[0].y))
	var off_scale: int = 1 if expected_price > limits.y else (-1 if expected_price < limits.x else 0)
	var winter_y: float = plot.end.y - clampf((expected_price - limits.x) / (limits.y - limits.x), 0, 1) * plot.size.y
	return {"range": limits, "plot": plot, "points": points, "font_size": pixels, "winter_y": winter_y, "winter_off_scale": off_scale}

func _draw() -> void:
	var chart: Dictionary = chart_geometry()
	if chart.is_empty(): return
	var plot: Rect2 = chart.plot
	var points: PackedVector2Array = chart.points
	var pixels: int = chart.font_size
	var limits: Vector2 = chart.range
	draw_line(Vector2(plot.position.x, plot.get_center().y), Vector2(plot.end.x, plot.get_center().y), Color(line_color, 0.16), 1.0)
	draw_polyline(points, line_color, 2.0, true)
	var range_text: String = "%s–%s/t" % [String.num(limits.x, 0), String.num(limits.y, 0)]
	draw_string(font, Vector2(3, pixels), range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color(line_color, 0.75))
	if expected_price > 0:
		var y: float = chart.winter_y
		for x in range(3, int(size.x) - 3, 8): draw_line(Vector2(x, y), Vector2(minf(x + 4, size.x - 3), y), Color(line_color, 0.65), 1.0)
		var arrow: String = "↑ " if chart.winter_off_scale > 0 else ("↓ " if chart.winter_off_scale < 0 else "")
		var label: String = "Winter %s%s/t" % [arrow, String.num(expected_price, 0)]
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		draw_string(font, Vector2(size.x - width - 3, pixels), label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, line_color)
	draw_circle(points[points.size() - 1], 3.0, line_color)
