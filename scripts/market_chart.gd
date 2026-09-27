extends Control
## Price-change history, in quote order. Numeric ticks live on the right only.
signal window_changed
const State = preload("res://scripts/game_state.gd")
const Type = preload("res://scripts/ui_type.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const INK := Color("17382d")
const MUTED := Color("707a74")
const GREEN := Color("18886b")
const BERRY := Color("c55065")
const NEUTRAL := Color("687699")
const PAPER := Color("fffcf3")
var samples: Array = []
var base_price: float = 1.0
var history_offset: int = 0
var font: Font = Type.face(Type.BODY, 600)
var font_size: int = 15
var money: Callable
var _signature: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		queue_redraw()
		window_changed.emit())

static func percent_label(price: float, base: float) -> String:
	var percent: int = roundi(State.price_change(price, base))
	return "(0%)" if percent == 0 else "(%s%d%%)" % ["+" if percent > 0 else "−", absi(percent)]

## Monotone Hermite interpolation preserves every quote and cannot invent peaks.
## Its tangents flatten at changes of direction and flat runs; each segment stays
## between its two recorded endpoints. The returned vertices are drawing only.
static func smooth_points(points: PackedVector2Array, steps: int = 20) -> PackedVector2Array:
	if points.size() < 2: return points.duplicate()
	steps = maxi(2, steps)
	var slopes: Array[float] = []
	var tangents: Array[float] = []
	for index: int in range(points.size() - 1):
		var width: float = points[index + 1].x - points[index].x
		slopes.append((points[index + 1].y - points[index].y) / width if width > 0.0 else 0.0)
	tangents.append(slopes[0])
	for index: int in range(1, points.size() - 1):
		var before: float = slopes[index - 1]
		var after: float = slopes[index]
		# The harmonic mean is bounded by the adjacent slopes. Opposite signs
		# and zeros must have a horizontal tangent at the recorded extremum.
		tangents.append(2.0 * before * after / (before + after) if before * after > 0.0 else 0.0)
	tangents.append(slopes.back())
	var result := PackedVector2Array([points[0]])
	for index: int in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var width: float = end.x - start.x
		for step: int in range(1, steps + 1):
			if step == steps:
				result.append(end)
				continue
			var t: float = float(step) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			var y: float = (2.0 * t3 - 3.0 * t2 + 1.0) * start.y + (t3 - 2.0 * t2 + t) * width * tangents[index] + (-2.0 * t3 + 3.0 * t2) * end.y + (t3 - t2) * width * tangents[index + 1]
			result.append(Vector2(lerpf(start.x, end.x, t), clampf(y, minf(start.y, end.y), maxf(start.y, end.y))))
	return result

func set_history(history: Array, base: float, format_money: Callable) -> void:
	var signature := str(history) + str(base)
	money = format_money
	if signature == _signature: return
	_signature = signature
	samples = history.duplicate()
	base_price = base
	history_offset = mini(history_offset, maxi(0, samples.size() - visible_count()))
	queue_redraw()
	window_changed.emit()

func label_width() -> float:
	var width: float = 56.0
	for value: float in samples:
		width = maxf(width, font.get_string_size(percent_label(value, base_price), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0)
	return width

func axis_width() -> float:
	var width: float = 50.0
	for value: float in samples + [base_price]:
		width = maxf(width, font.get_string_size(_money(value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return width + 16.0

func visible_count() -> int:
	# Every point has its own horizontal pill space, even a +100000% rocket.
	return clampi(int((size.x - axis_width() - label_width() - 20.0) / (label_width() + 22.0)) + 1, 2, 8)

func window_bounds() -> Vector2i:
	var end: int = maxi(0, samples.size() - history_offset)
	return Vector2i(maxi(0, end - visible_count()), end)

func move_window(direction: int) -> void:
	history_offset = clampi(history_offset + direction * maxi(1, visible_count() - 1), 0, maxi(0, samples.size() - visible_count()))
	queue_redraw()
	window_changed.emit()

func _money(value: float) -> String:
	return str(money.call(value)) if money.is_valid() else "\uE000 %.2f" % value

func chart_layout() -> Dictionary:
	var bounds := window_bounds()
	var visible: Array = samples.slice(bounds.x, bounds.y)
	var low: float = base_price
	var high: float = base_price
	for value: float in visible:
		low = minf(low, value)
		high = maxf(high, value)
	var span: float = maxf(high - low, maxf(base_price * 0.12, 0.01))
	low = maxf(0.0, low - span * 0.18)
	high += span * 0.18
	var left: float = label_width() * 0.5 + 8.0
	var plot := Rect2(left, 40, maxf(1.0, size.x - left - axis_width() - label_width() * 0.5 - 10.0), maxf(1.0, size.y - 82.0))
	var points := PackedVector2Array()
	var labels: Array[Rect2] = []
	for index: int in visible.size():
		var x: float = plot.position.x + plot.size.x * (float(index) / float(visible.size() - 1) if visible.size() > 1 else 0.5)
		var y: float = plot.end.y - (float(visible[index]) - low) / (high - low) * plot.size.y
		points.append(Vector2(x, y))
		var width: float = font.get_string_size(percent_label(visible[index], base_price), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0
		var label_y: float = y - font_size - 21 if index % 2 == 0 else y + 12
		labels.append(Rect2(x - width * 0.5, clampf(label_y, 5.0, size.y - font_size - 33.0), width, font_size + 10))
	return {"plot": plot, "low": low, "high": high, "points": points, "labels": labels, "visible": visible}

func _tone(price: float) -> Color:
	if is_equal_approx(price, base_price): return NEUTRAL
	return GREEN if price > base_price else BERRY

## Split at each baseline crossing so gains/losses use truthful shaded areas.
func _draw_run(run: PackedVector2Array, baseline: float, color: Color) -> void:
	if run.size() < 2: return
	var area := PackedVector2Array(run)
	if absf(run[-1].y - baseline) > 0.01: area.append(Vector2(run[-1].x, baseline))
	if absf(run[0].y - baseline) > 0.01: area.append(Vector2(run[0].x, baseline))
	# A flat run at the base has no area to triangulate.
	var has_area: bool = false
	for point: Vector2 in run:
		if absf(point.y - baseline) > 0.01:
			has_area = true
			break
	if has_area: draw_colored_polygon(area, Color(color, 0.095))
	else: color = NEUTRAL
	draw_polyline(run, color, 3.0, true)
	draw_circle(run[0], 1.5, color, true, -1, true)
	draw_circle(run[-1], 1.5, color, true, -1, true)

func _draw_curve(points: PackedVector2Array, baseline: float) -> void:
	var curve := smooth_points(points)
	if curve.size() < 2: return
	var run := PackedVector2Array([curve[0]])
	var above: bool = curve[0].y <= baseline
	for index: int in range(1, curve.size()):
		var point: Vector2 = curve[index]
		var next_above: bool = point.y <= baseline
		if next_above != above:
			var previous: Vector2 = curve[index - 1]
			var crossing := Vector2(lerpf(previous.x, point.x, (baseline - previous.y) / (point.y - previous.y)), baseline)
			run.append(crossing)
			_draw_run(run, baseline, GREEN if above else BERRY)
			run = PackedVector2Array([crossing])
			above = next_above
		run.append(point)
	_draw_run(run, baseline, GREEN if above else BERRY)

func _draw() -> void:
	if size.x < 80: return
	var layout := chart_layout()
	var plot: Rect2 = layout.plot
	var low: float = layout.low
	var high: float = layout.high
	var tick_count: int = 3 if plot.size.y < 130 else 5
	for index: int in range(tick_count):
		var fraction: float = float(index) / float(tick_count - 1)
		var y: float = plot.end.y - fraction * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(NEUTRAL, 0.10), 1, true)
		draw_string(font, Vector2(plot.end.x + label_width() * 0.5 + 12, y + font_size * 0.35), _money(lerpf(low, high, fraction)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, MUTED)
	var base_y: float = plot.end.y - (base_price - low) / (high - low) * plot.size.y
	draw_string(font, Vector2(plot.position.x, size.y - 8), "0% · Base price", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, MUTED)
	if samples.is_empty():
		draw_dashed_line(Vector2(plot.position.x, base_y), Vector2(plot.end.x, base_y), Color(NEUTRAL, 0.38), 1.2, 5, true)
		draw_string(font, Vector2(plot.position.x, plot.get_center().y), "First quote coming soon", HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, font_size, MUTED)
		return
	var points: PackedVector2Array = layout.points
	_draw_curve(points, base_y)
	# Keep the zero reference visible above the translucent area fill.
	draw_dashed_line(Vector2(plot.position.x, base_y), Vector2(plot.end.x, base_y), Color(NEUTRAL, 0.38), 1.2, 5, true)
	for index: int in points.size():
		var label: Rect2 = layout.labels[index]
		var color: Color = _tone(layout.visible[index])
		if index == points.size() - 1 and history_offset == 0:
			draw_circle(points[index], 10.0, Color(color, 0.12), true, -1, true)
		draw_circle(points[index], 6.0, PAPER, true, -1, true)
		draw_circle(points[index], 4.0, color, true, -1, true)
		draw_style_box(Cozy.box(PAPER.lerp(color, 0.09), 0, 10, Color(color, 0.12)), label)
		draw_string(font, label.position + Vector2(8, font_size + 2), percent_label(layout.visible[index], base_price), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.darkened(0.16))
