extends Control
## Small, code-drawn field lessons. Only redraw when the selected concept changes.
const Type = preload("res://scripts/ui_type.gd")
const WATER := Color("76c8d8")
const LEAF := Color("85b778")
const GOLD := Color("e6bd71")
var dark: bool = false:
	set(value):
		if dark != value:
			dark = value
			queue_redraw()
var concept: String = "tank":
	set(value):
		if concept != value:
			concept = value
			queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(260, 91)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var text := Color("d8e8dc") if dark else Color("526d61")
	var surface := Color("224840") if dark else Color("e8eee0")
	var edge := Color("3e6658") if dark else Color("d3deca")
	var offset: float = maxf(0.0, (size.x - 260.0) * 0.5)
	draw_set_transform(Vector2(offset, 0))
	for x in [0.0, 91.0, 182.0]:
		_round(Rect2(x, 0, 78, 66), surface, 10)
		draw_line(Vector2(x + 9, 58), Vector2(x + 69, 58), edge, 1)
	for x in [84.5, 175.5]:
		draw_line(Vector2(x - 3, 29), Vector2(x + 3, 33), GOLD, 2, true)
		draw_line(Vector2(x + 3, 33), Vector2(x - 3, 37), GOLD, 2, true)
	var labels: Array[String] = []
	match concept:
		"tank":
			_rain_roof(Vector2(39, 37))
			_tank(Vector2(130, 43), 0.72)
			_can(Vector2(214, 42))
			_crop(Vector2(244, 56), false, 0.58)
			labels.assign(["Catch rain", "Store water", "Fill your can"])
		"drain":
			_puddle(Vector2(39, 54), 25)
			_crop(Vector2(37, 52), true, 0.8)
			_channel(Vector2(130, 36))
			_crop(Vector2(219, 54), false, 0.86)
			labels.assign(["Flooded", "Open drain", "Water leaves"])
		"trees":
			_wind(Vector2(13, 18), 30)
			_crop(Vector2(38, 54), true, 0.88)
			_tree(Vector2(130, 56))
			_wind(Vector2(107, 18), 10)
			_crop(Vector2(212, 55), false, 0.74)
			_crop(Vector2(233, 55), false, 0.74)
			labels.assign(["Strong wind", "Trees shelter", "Calmer beds"])
		"can":
			_crop(Vector2(39, 54), true, 0.85)
			_can(Vector2(124, 33))
			for i in range(3): _drop(Vector2(145 + i * 4, 43 + i * 2), 2)
			_crop(Vector2(221, 54), false, 0.9)
			labels.assign(["Dry soil", "Water [3]", "Growing"])
		_:
			_crop(Vector2(39, 54), true, 0.86)
			_sprinkler(Vector2(130, 51))
			_crop(Vector2(208, 54), false, 0.7)
			_crop(Vector2(232, 54), false, 0.86)
			labels.assign(["Dry beds", "Tank & pipe", "Watered patch"])
	var font: Font = Type.face(Type.BODY, 650)
	for i in range(3):
		draw_string(font, Vector2(i * 91, 83), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 78, 10, text)

func _round(rect: Rect2, color: Color, radius: int = 5) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)

func _drop(pos: Vector2, radius: float) -> void:
	draw_circle(pos, radius, WATER)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-radius, 0), pos + Vector2(0, -radius * 2.2), pos + Vector2(radius, 0)]), WATER)

func _crop(pos: Vector2, dry: bool, scale_factor: float = 1.0) -> void:
	_round(Rect2(pos + Vector2(-23, -1) * scale_factor, Vector2(46, 9) * scale_factor), Color("ab8a5c") if dry else Color("655643"), 5)
	var top: Vector2 = pos + Vector2(8 if dry else 0, -19 if dry else -30) * scale_factor
	draw_line(pos, top, Color("a9b879") if dry else LEAF, 3 * scale_factor, true)
	var leaf := Color("bdac73") if dry else LEAF
	draw_set_transform(top + Vector2(maxf(0.0, (size.x - 260.0) * 0.5), 0), -0.5 if dry else -0.7, Vector2(1.3, 0.7) * scale_factor)
	draw_circle(Vector2(-5, 0), 7, leaf)
	draw_set_transform(top + Vector2(maxf(0.0, (size.x - 260.0) * 0.5), 0), 0.6 if dry else 0.7, Vector2(1.3, 0.7) * scale_factor)
	draw_circle(Vector2(5, -4), 7, leaf.lightened(0.13))
	draw_set_transform(Vector2(maxf(0.0, (size.x - 260.0) * 0.5), 0))
	if not dry: _drop(pos + Vector2(17, -6) * scale_factor, 2 * scale_factor)

func _tank(pos: Vector2, fill: float) -> void:
	_round(Rect2(pos.x - 22, pos.y - 25, 44, 37), Color("527f85"), 6)
	for y in [-16.0, -5.0, 6.0]: draw_line(pos + Vector2(-21, y), pos + Vector2(21, y), Color("86a8a6"), 1)
	_round(Rect2(pos.x - 24, pos.y - 28, 48, 6), Color("bdd1c3"), 3)
	_round(Rect2(pos.x + 9, pos.y - 20, 6, 27), Color("2d555e"), 2)
	_round(Rect2(pos.x + 10, pos.y + 6 - 24 * fill, 4, 24 * fill), WATER, 1)
	draw_line(pos + Vector2(-15, 10), pos + Vector2(-15, 16), GOLD, 4)
	draw_line(pos + Vector2(-15, 16), pos + Vector2(-8, 16), GOLD, 3)

func _rain_roof(pos: Vector2) -> void:
	for i in range(4):
		var point: Vector2 = pos + Vector2(-19 + i * 13, -22 + (i % 2) * 5)
		draw_line(point, point + Vector2(-3, 7), WATER, 2, true)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-28, 8), pos + Vector2(-8, -6), pos + Vector2(23, 8)]), Color("bb795d"))
	draw_line(pos + Vector2(-29, 10), pos + Vector2(25, 10), Color("b6cec4"), 3)
	draw_line(pos + Vector2(25, 10), pos + Vector2(25, 19), Color("b6cec4"), 3)
	_drop(pos + Vector2(25, 24), 2)

func _can(pos: Vector2) -> void:
	draw_arc(pos + Vector2(-10, -8), 11, PI * 0.5, PI * 1.65, 16, Color("a3bfa6"), 3, true)
	_round(Rect2(pos.x - 13, pos.y - 15, 28, 27), Color("6c9884"), 5)
	_round(Rect2(pos.x - 8, pos.y - 2, 17, 8), WATER, 2)
	draw_line(pos + Vector2(13, -4), pos + Vector2(27, -15), Color("98b795"), 5, true)
	draw_line(pos + Vector2(24, -18), pos + Vector2(29, -12), GOLD, 3, true)

func _sprinkler(pos: Vector2) -> void:
	draw_line(pos + Vector2(-30, 4), pos + Vector2(18, 4), Color("568e88"), 4)
	draw_line(pos + Vector2(0, 4), pos + Vector2(0, -23), Color("94b4a9"), 4)
	_round(Rect2(pos.x - 9, pos.y - 25, 18, 5), GOLD, 2)
	for side in [-1.0, 1.0]:
		var spray := PackedVector2Array()
		for step in range(9):
			var t: float = step / 8.0
			spray.append(pos + Vector2(side * (3 + 23 * t), -25 - 13 * sin(t * PI) + 15 * t))
		draw_polyline(spray, WATER, 1.4, true)
		_drop(pos + Vector2(side * 27, -7), 2)
	for x in [-23.0, -11.0]:
		draw_line(pos + Vector2(x, 1), pos + Vector2(x + 4, 4), WATER, 1.5, true)
		draw_line(pos + Vector2(x + 4, 4), pos + Vector2(x, 7), WATER, 1.5, true)

func _puddle(pos: Vector2, width: float) -> void:
	_round(Rect2(pos.x - width, pos.y - 3, width * 2, 9), Color("649daf"), 5)
	draw_line(pos + Vector2(-width * 0.5, 1), pos + Vector2(width * 0.6, 1), WATER, 1, true)

func _channel(pos: Vector2) -> void:
	draw_line(pos + Vector2(-28, -4), pos + Vector2(25, 17), Color("789f97"), 12, true)
	draw_line(pos + Vector2(-28, -4), pos + Vector2(25, 17), WATER, 6, true)
	for x in [-6.0, 5.0, 16.0]:
		var y: float = x * 0.4 + 7
		draw_line(pos + Vector2(x - 3, y - 4), pos + Vector2(x + 3, y), Color("dcf4e7"), 1.5, true)
		draw_line(pos + Vector2(x + 3, y), pos + Vector2(x - 1, y + 2), Color("dcf4e7"), 1.5, true)
	for x in [-11.0, 2.0]: draw_line(pos + Vector2(x, -19), pos + Vector2(x, 10), Color("b9c8af"), 3)
	_round(Rect2(pos.x - 13, pos.y - 20, 18, 10), GOLD, 2)
	draw_line(pos + Vector2(-4, -22), pos + Vector2(-4, -27), GOLD, 2)

func _tree(pos: Vector2) -> void:
	draw_line(pos, pos + Vector2(0, -24), Color("aa8560"), 6)
	draw_circle(pos + Vector2(-8, -29), 14, Color("588f6a"))
	draw_circle(pos + Vector2(7, -28), 13, Color("639d73"))
	draw_circle(pos + Vector2(0, -41), 12, Color("82b17f"))

func _wind(pos: Vector2, length: float) -> void:
	for i in range(3):
		var start: Vector2 = pos + Vector2(i % 2 * 4, i * 6)
		draw_line(start, start + Vector2(length, 0), Color("a1beb4"), 1.5, true)

func _crate(pos: Vector2, scale_factor: float = 1.0) -> void:
	_round(Rect2(pos + Vector2(-11, -14) * scale_factor, Vector2(22, 18) * scale_factor), Color("c6a476"), 2)
	for y in [-9.0, -3.0]: draw_line(pos + Vector2(-10, y) * scale_factor, pos + Vector2(10, y) * scale_factor, Color("8f724d"), 1)
	draw_line(pos + Vector2(-7, -13) * scale_factor, pos + Vector2(-7, 4) * scale_factor, Color("e0bf8c"), 2)
