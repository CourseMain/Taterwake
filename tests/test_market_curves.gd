extends SceneTree
## Drawing geometry must never invent prices between two recorded quotes.
const Chart = preload("res://scripts/market_chart.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func verify_curve(values: Array, name: String) -> void:
	var points := PackedVector2Array()
	for index: int in values.size(): points.append(Vector2(index * 95.0, values[index]))
	const STEPS: int = 24
	var curve: PackedVector2Array = Chart.smooth_points(points, STEPS)
	check(curve.size() == (points.size() - 1) * STEPS + 1, name + " drawing density")
	for index: int in points.size():
		check(curve[index * STEPS] == points[index], name + " preserves recorded point " + str(index))
	for index: int in range(points.size() - 1):
		var low: float = minf(points[index].y, points[index + 1].y)
		var high: float = maxf(points[index].y, points[index + 1].y)
		var rising: bool = values[index + 1] >= values[index]
		for step: int in range(1, STEPS + 1):
			var point: Vector2 = curve[index * STEPS + step]
			var previous: Vector2 = curve[index * STEPS + step - 1]
			check(point.y >= low and point.y <= high, name + " remains between recorded quotes")
			check(point.y >= previous.y if rising else point.y <= previous.y, name + " no false local peaks")
			check(point.x > previous.x, name + " time always advances")

func run() -> void:
	verify_curve([100.0, 182.0, 75.0, 100.0], "gain and loss")
	verify_curve([38.0, 38.0, 38.0, 38.0], "flat base")
	verify_curve([38.0, 38.0, 82.0, 82.0, 85.0, 41.0, 39.0], "plateaus and steep fall")
	verify_curve([1.0, 1.0001, 1000000.0, 0.0, 5.0], "extreme volatility")
	verify_curve([0.0, 10.0, 11.0, 1000.0, 1001.0], "unequal rising slopes")
	verify_curve([1000.0, 999.0, 10.0, 9.0, 0.0], "unequal falling slopes")
	check(Chart.smooth_points(PackedVector2Array()).is_empty(), "missing history has no fabricated quotes")
	check(Chart.smooth_points(PackedVector2Array([Vector2(3, 7)])) == PackedVector2Array([Vector2(3, 7)]), "single quote stays a single point")
	check(Chart.percent_label(182.0, 100.0) == "(+82%)", "182 compares with fixed 100 base")
	check(Chart.percent_label(75.0, 100.0) == "(−25%)", "75 compares with base, never prior 182 quote")
	check(Chart.percent_label(100.0, 100.0) == "(0%)", "base is zero percent")
	check(Chart.percent_label(99.999, 100.0) == "(0%)", "rounded zero is unsigned")
	check(Chart.percent_label(18200.0, 100.0) == "(+18100%)", "large price changes remain signed")
	var chart := Chart.new()
	chart.size = Vector2(1080, 400)
	root.add_child(chart)
	var recorded: Array = [100.0, 182.0, 75.0, 100.0, 100.0, 90.0, 120.0, 118.0, 70.0, 88.0, 99.0, 103.0]
	chart.set_history(recorded, 100.0, func(value: float) -> String: return "\uE000 %.2f" % value)
	for dimensions: Vector2 in [Vector2(1080, 400), Vector2(620, 280), Vector2(290, 230)]:
		chart.size = dimensions
		await process_frame
		var layout: Dictionary = chart.chart_layout()
		check(layout.points.size() == layout.visible.size() and layout.labels.size() == layout.points.size(), "one label per actual quote at " + str(dimensions))
		for index: int in layout.labels.size():
			check(Rect2(Vector2.ZERO, chart.size).encloses(layout.labels[index]), "pill within chart at " + str(dimensions))
			for other: int in range(index + 1, layout.labels.size()):
				check(not layout.labels[index].intersects(layout.labels[other]), "pills do not overlap at " + str(dimensions))
			var point: Vector2 = layout.points[index]
			var price: float = layout.low + (layout.plot.end.y - point.y) / layout.plot.size.y * (layout.high - layout.low)
			check(is_equal_approx(price, layout.visible[index]), "plotted marker is true recorded price")
		check(layout.low < 100.0 and layout.high > 100.0, "fixed base remains in visible range")
	chart.move_window(1)
	check(chart.window_bounds().y < recorded.size(), "older exact quotes remain accessible")
	check(chart.samples == recorded and chart.base_price == 100.0, "drawing and paging do not alter stored prices or base")
	# Exercise drawing of baseline crossings and zero-area plateaus as well.
	for quotes: Array in [[100.0, 100.0, 100.0], [100.0, 80.0, 100.0, 120.0], [80.0, 100.0, 100.0, 80.0], [120.0, 100.0, 100.0, 120.0]]:
		chart.set_history(quotes, 100.0, Callable())
		await process_frame
	chart.set_history([], 100.0, Callable())
	check(chart.chart_layout().points.is_empty(), "empty-history chart has no fake points")
	chart.free()
	print("MARKET CURVES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
