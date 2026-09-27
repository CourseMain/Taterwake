extends Control
## The shared crop specimen, displayed in Mara's repaired sacks and farm crates.
const Icon = preload("res://scripts/item_icon.gd")
const INK := Color("30463a")
var crop: String = "russet"
var accent := Color("edb44c")
var seed_sack: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var side := minf(size.x, size.y)
	draw_set_transform(size * 0.5, 0, Vector2.ONE * side / 100.0)
	_oval(Vector2(1, 36), Vector2(41, 8), Color("172b23", 0.22))
	if seed_sack:
		_sack()
	else:
		# A mismatched slat ties the trading sample to the village's crates.
		_polygon([Vector2(-40, 18), Vector2(35, 15), Vector2(42, 25), Vector2(-33, 29)], Color("b9915d"))
		_polygon([Vector2(-33, 29), Vector2(42, 25), Vector2(42, 38), Vector2(-33, 41)], Color("957042"))
		draw_line(Vector2(-24, 33), Vector2(34, 30), Color("d1ae76"), 2, true)
		draw_line(Vector2(-18, 40), Vector2(-18, 30), Color("725939"), 2, true)
		Icon._potato(self, crop, Vector2(0, -3), 1.0)
		for point: Vector2 in [Vector2(-28, 33), Vector2(37, 29)]: draw_circle(point, 1.3, INK)
	draw_set_transform(Vector2.ZERO)

func _sack() -> void:
	var sack: Array[Vector2] = [Vector2(-23, -32), Vector2(-28, -18), Vector2(-36, 11), Vector2(-33, 30), Vector2(-19, 38), Vector2(22, 37), Vector2(34, 28), Vector2(32, 4), Vector2(25, -19), Vector2(24, -32)]
	_polygon(sack, Color("d6b98b"))
	draw_colored_polygon(PackedVector2Array([Vector2(19, -27), Vector2(27, 4), Vector2(29, 25), Vector2(19, 35), Vector2(29, 32), Vector2(35, 22), Vector2(31, 0), Vector2(24, -32)]), Color("a8865e"))
	# The repaired blue patch is the detail Mara points out in conversation.
	_polygon([Vector2(-31, 8), Vector2(-13, 5), Vector2(-10, 25), Vector2(-28, 29)], Color("779295"))
	for index: int in range(4):
		var y := 10.0 + float(index) * 5.0
		draw_line(Vector2(-32, y), Vector2(-26, y - 1), Color("e3d4a9"), 1.2, true)
		draw_line(Vector2(-14, y - 3), Vector2(-8, y - 4), Color("e3d4a9"), 1.2, true)
	_polygon([Vector2(-15, -19), Vector2(23, -16), Vector2(20, 17), Vector2(-18, 15)], Color("eee4c9"))
	Icon._potato(self, crop, Vector2(2, 0), 0.38)
	_oval(Vector2(0, -32), Vector2(24, 6), Color("9b7950"))
	for point: Vector2 in [Vector2(-12, -33), Vector2(-2, -34), Vector2(9, -32), Vector2(18, -34)]:
		_oval(point, Vector2(5, 3), Icon.CROP[crop])
		draw_circle(point + Vector2(1, 0), 0.7, Color("795738"))
	draw_line(Vector2(-24, -25), Vector2(25, -25), Color("eee0b7"), 2, true)
	draw_line(Vector2(22, -24), Vector2(30, -14), Color("eee0b7"), 1.7, true)
	draw_line(Vector2(-25, -9), Vector2(-28, 2), Color("f1d5a5"), 2, true)

func _polygon(points: Array[Vector2], fill: Color) -> void:
	var path := PackedVector2Array(points)
	draw_colored_polygon(path, fill)
	path.append(path[0])
	draw_polyline(path, INK, 1.6, true)

func _oval(center: Vector2, radius: Vector2, fill: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(28):
		points.append(center + Vector2.from_angle(float(index) * TAU / 28.0) * radius)
	draw_colored_polygon(points, fill)
