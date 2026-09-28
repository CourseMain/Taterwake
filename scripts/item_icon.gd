extends Control
## Shared, hand-drawn item illustrations. Geometry remains crisp at every HUD scale.
var item: Dictionary = {}
const INK: Color = Color("30463a")
const LEAF: Color = Color("5e7b50")
const CROP: Dictionary = {"russet": Color("dfb36f"), "golden": Color("f5cc38"), "giant": Color("d7a37b"), "radioactive": Color("afff48"), "sunburst": Color("ffa629"), "icecap": Color("d8f1ff")}

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(62, 62)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	paint(self, item, Rect2(Vector2.ZERO, size))

static func paint(c: CanvasItem, data: Dictionary, rect: Rect2) -> void:
	var scale_value: float = minf(rect.size.x, rect.size.y) / 100.0
	c.draw_set_transform(rect.get_center(), 0, Vector2.ONE * scale_value)
	var id: String = str(data.get("id", "russet"))
	var kind: String = str(data.get("kind", "crop"))
	var crop: String = str(data.get("crop", id.get_slice(":", 1) if ":" in id else "russet"))
	if kind == "island":
		_island(c, int(data.get("island", 1)))
		c.draw_set_transform(Vector2.ZERO)
		return
	if kind != "metric":
		var wash: Color = Color(str(data.get("backdrop", "e5dec6")))
		var paper := PackedVector2Array()
		for i in range(28):
			var angle: float = i * TAU / 28.0
			paper.append(Vector2(0, 5) + Vector2.from_angle(angle) * (42.0 + sin(angle * 5.0) * 1.4))
		c.draw_colored_polygon(paper, wash)
		# Fixed paper grain and a short cast shadow keep every item in the same light.
		for mark: Vector2 in [Vector2(-30, 26), Vector2(29, 23), Vector2(-22, 36), Vector2(22, 35)]:
			c.draw_line(mark, mark + Vector2(4, -2), INK.lerp(wash, 0.8), 1, true)
		if kind in ["crop", "seed", "tool"]:
			c.draw_set_transform(rect.get_center() + Vector2(5, 35) * scale_value, 0, Vector2(scale_value, scale_value * 0.2))
			c.draw_circle(Vector2.ZERO, 27, Color("30463a", 0.13))
			c.draw_set_transform(rect.get_center(), 0, Vector2.ONE * scale_value)
	match kind:
		"metric": _metric(c, id)
		"tool": _tool(c, str(data.get("tool", id.trim_prefix("tool:"))))
		"activity": _activity(c, id)
		"empty":
			_poly(c, [Vector2(-17, -22), Vector2(-30, 18), Vector2(-22, 36), Vector2(22, 36), Vector2(30, 18), Vector2(17, -22)], Color("b5a792"))
			c.draw_style_box(_box(Color("766a59"), 8), Rect2(-23, -31, 46, 16))
			c.draw_arc(Vector2(0, 15), 9, PI, TAU, 16, Color("766a59"), 3, true)
		"seed":
			c.draw_style_box(_box(Color("cfac72"), 5), Rect2(-28, -38, 56, 78))
			c.draw_rect(Rect2(-28, -38, 56, 13), LEAF)
			c.draw_rect(Rect2(-23, -18, 46, 42), Color("fff9e8"))
			_potato(c, crop, Vector2(0, 3), 0.56)
			for x: int in [-21, -13, -5, 3, 11, 19]: c.draw_line(Vector2(x, 32), Vector2(x + 3, 35), INK, 1.5, true)
			c.draw_rect(Rect2(15, 18, 15, 12), Color("788167"))
			for y: int in [20, 26]: c.draw_line(Vector2(13, y), Vector2(18, y + 2), Color("f4e6bd"), 1.5, true)
		"crop": _potato(c, crop, Vector2.ZERO, 1.0)
		_: _symbol(c, id)
	c.draw_set_transform(Vector2.ZERO)

static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK.lerp(color, 0.27)
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

static func _metric(c: CanvasItem, id: String) -> void:
	match id:
		"coin":
			c.draw_circle(Vector2.ZERO, 34, Color("c59632"))
			c.draw_circle(Vector2(-2, -3), 27, Color("edc663"))
			c.draw_arc(Vector2(-2, -3), 20, 0, TAU, 32, Color("fff0ad"), 3, true)
			c.draw_line(Vector2(-2, -16), Vector2(-2, 10), Color("916827"), 6, true)
		"clock", "growth", "speed":
			c.draw_circle(Vector2.ZERO, 32, Color("e0e9df"))
			c.draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color("548374"), 6, true)
			c.draw_polyline(PackedVector2Array([Vector2(0, -22), Vector2.ZERO, Vector2(18, 9)]), INK, 5, true)
		"beds":
			for x: int in [-24, 4]:
				for y: int in [-25, 3]:
					c.draw_style_box(_box(Color("b3895d"), 4), Rect2(x, y, 22, 22))
		"weather":
			c.draw_circle(Vector2(14, -16), 18, Color("e8bc55"))
			for p: Vector2 in [Vector2(-20, 1), Vector2(-3, -5), Vector2(14, 3)]: c.draw_circle(p, 16, Color("83aab4"))
			for x: int in [-16, 0, 16]: c.draw_line(Vector2(x, 22), Vector2(x - 5, 32), Color("548da0"), 5, true)
		"yield", "seed", "crops":
			c.draw_line(Vector2(0, 31), Vector2(0, -16), LEAF, 6, true)
			_poly(c, [Vector2(0, 0), Vector2(-31, -9), Vector2(-28, -28), Vector2(-5, -23)], LEAF)
			_poly(c, [Vector2(0, 14), Vector2(29, 0), Vector2(28, -20), Vector2(7, -13)], Color("83a75b"))
		"lock":
			c.draw_arc(Vector2(0, -9), 20, PI, TAU, 24, Color("827a63"), 8, true)
			c.draw_style_box(_box(Color("b2a789"), 7), Rect2(-28, -9, 56, 43))
			c.draw_circle(Vector2(0, 9), 5, INK)
			c.draw_line(Vector2(0, 9), Vector2(0, 22), INK, 4, true)
		_: _spark(c, Vector2.ZERO, Color("c9a147"), 32)

static func _island(c: CanvasItem, island: int) -> void:
	var sky: Color = [Color("dce9d4"), Color("f4dfb4"), Color("d7e8ed")][clampi(island - 1, 0, 2)]
	c.draw_style_box(_box(sky, 14), Rect2(-49, -47, 98, 94))
	c.draw_circle(Vector2(27, -27), 10, Color("fff1bb"))
	for y: int in [22, 31, 39]:
		c.draw_line(Vector2(-39, y), Vector2(39, y), Color("96bbc0"), 3, true)
	_poly(c, [Vector2(-41, 15), Vector2(-29, -1), Vector2(27, -6), Vector2(43, 16), Vector2(24, 26), Vector2(-25, 27)], Color("bca777"))
	_poly(c, [Vector2(-41, 10), Vector2(-22, -15), Vector2(21, -17), Vector2(43, 11), Vector2(24, 20), Vector2(-24, 20)], Color("78a568") if island == 1 else (Color("e7c984") if island == 2 else Color("f0f6e9")))
	if island == 1:
		c.draw_rect(Rect2(-20, -17, 31, 30), Color("bd7051"))
		_poly(c, [Vector2(-25, -15), Vector2(-5, -33), Vector2(17, -15)], Color("43644a"))
		c.draw_rect(Rect2(-11, -3, 12, 16), Color("f5dfaa"))
		for x: int in [22, 31]:
			c.draw_line(Vector2(x, 13), Vector2(x, -10), LEAF, 3, true)
			c.draw_circle(Vector2(x, -8), 5, Color("dabb52"))
	elif island == 2:
		c.draw_line(Vector2(12, 10), Vector2(9, -26), Color("977347"), 6, true)
		for tip: Vector2 in [Vector2(-15, -23), Vector2(-4, -36), Vector2(23, -38), Vector2(34, -23)]:
			_poly(c, [Vector2(9, -26), tip, tip + Vector2(4, 8)], LEAF)
		_potato(c, "sunburst", Vector2(-20, 2), 0.32)
	else:
		_poly(c, [Vector2(-33, 8), Vector2(-11, -36), Vector2(12, 8)], Color("7698a3"))
		_poly(c, [Vector2(-20, -18), Vector2(-11, -36), Vector2(-1, -17), Vector2(-10, -22)], Color("fffdf2"))
		for x: int in [18, 31]:
			c.draw_line(Vector2(x, 14), Vector2(x, -19), Color("5b7765"), 4, true)
			_poly(c, [Vector2(x - 11, 2), Vector2(x, -26), Vector2(x + 11, 2)], Color("6f9d8b"))

static func _poly(c: CanvasItem, points: Array[Vector2], color: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(points), color)

static func _spark(c: CanvasItem, p: Vector2, color: Color, radius: float) -> void:
	_poly(c, [p + Vector2(0, -radius), p + Vector2(radius * 0.3, -radius * 0.3), p + Vector2(radius, 0), p + Vector2(radius * 0.3, radius * 0.3), p + Vector2(0, radius), p + Vector2(-radius * 0.3, radius * 0.3), p + Vector2(-radius, 0), p + Vector2(-radius * 0.3, -radius * 0.3)], color)

static func _potato(c: CanvasItem, crop: String, p: Vector2, factor: float, tint: Color = Color.TRANSPARENT) -> void:
	var color: Color = CROP.get(crop, CROP.russet) if tint.a == 0 else tint
	var radius: float = 27.0 * factor
	if crop == "giant": radius *= 1.22
	if crop == "sunburst":
		for index: int in range(10):
			var direction: Vector2 = Vector2.from_angle(index * TAU / 10.0)
			c.draw_line(p + direction * radius, p + direction * radius * 1.48, color, 4 * factor, true)
	var outline := PackedVector2Array()
	var lit_side := PackedVector2Array()
	for index in range(28):
		var angle: float = index * TAU / 28.0
		var lump: float = 1.0 + 0.065 * sin(angle * 3.0) + 0.035 * cos(angle * 5.0)
		var edge: Vector2 = Vector2(cos(angle) * 0.9, sin(angle) * 1.1) * radius * lump
		outline.append(p + edge + Vector2(0, 2) * factor)
		lit_side.append(p + edge * 0.86 + Vector2(-2.5, -3) * factor)
	c.draw_colored_polygon(outline, color.darkened(0.17))
	c.draw_colored_polygon(lit_side, color)
	outline.append(outline[0])
	c.draw_polyline(outline, INK.lerp(color, 0.16), maxf(0.8, 2.2 * factor), true)
	c.draw_arc(p + Vector2(-4, -6) * factor, radius * 0.58, -2.7, -1.5, 10, color.lightened(0.3), 2.8 * factor, true)
	for dot: Vector2 in [Vector2(-13, 10), Vector2(14, 13), Vector2(15, -11)]:
		c.draw_circle(p + dot * factor, 2 * factor, color.darkened(0.38))
		c.draw_line(p + (dot + Vector2(-2, 3)) * factor, p + (dot + Vector2(1, 3)) * factor, color.lightened(0.2), factor, true)
	for scratch: Vector2 in [Vector2(-9, 21), Vector2(9, 23), Vector2(20, 5)]:
		c.draw_line(p + scratch * factor, p + (scratch + Vector2(3, -2)) * factor, color.darkened(0.27), factor, true)
	_poly(c, [p + Vector2(-3, -28) * factor, p + Vector2(-18, -39) * factor, p + Vector2(1, -36) * factor], LEAF)
	_poly(c, [p + Vector2(-1, -28) * factor, p + Vector2(5, -41) * factor, p + Vector2(18, -35) * factor], LEAF.lightened(0.17))
	if crop == "golden": _spark(c, p + Vector2(20, -24) * factor, Color("fff8c1"), 10 * factor)
	if crop == "icecap":
		for angle: float in [0.0, PI / 3, PI * 2 / 3]: c.draw_line(p + Vector2.from_angle(angle) * -15 * factor, p + Vector2.from_angle(angle) * 15 * factor, Color("edfdff"), 3 * factor, true)
	if crop == "radioactive":
		c.draw_circle(p, 6 * factor, INK)
		for index: int in range(3):
			var angle: float = index * TAU / 3.0
			_poly(c, [p + Vector2.from_angle(angle) * 9 * factor, p + Vector2.from_angle(angle + 0.3) * 21 * factor, p + Vector2.from_angle(angle + 1.1) * 21 * factor], INK)

static func _tool(c: CanvasItem, id: String) -> void:
	match id:
		"hoe", "harvest":
			c.draw_line(Vector2(-22, 36), Vector2(13, -29), Color("895d3c"), 9, true)
			c.draw_line(Vector2(-22, 36), Vector2(13, -29), Color("d19b61"), 4, true)
			if id == "hoe": _poly(c, [Vector2(-9, -35), Vector2(35, -21), Vector2(33, -2), Vector2(4, -13)], Color("7b9d9e"))
			else:
				c.draw_arc(Vector2(3, -3), 34, -2.0, 0.7, 24, Color("c6d5c9"), 12, true)
				_poly(c, [Vector2(29, 14), Vector2(37, 22), Vector2(20, 27)], Color("c6d5c9"))
		"water":
			c.draw_arc(Vector2(-20, 2), 20, 0.5, 5.7, 24, Color("5488a1"), 7, true)
			c.draw_style_box(_box(Color("76b7ce"), 8), Rect2(-24, -17, 46, 48))
			_poly(c, [Vector2(17, -5), Vector2(34, -22), Vector2(42, -15), Vector2(22, 16)], Color("76b7ce"))
			for index: int in range(3): c.draw_circle(Vector2(35 + index * 5, -3 + index * 8), 2.7, Color("448aba"))
			c.draw_line(Vector2(-12, -21), Vector2(12, -21), Color("426d7c"), 6, true)
		"plant":
			c.draw_style_box(_box(Color("edc681"), 4), Rect2(-31, -28, 49, 65))
			c.draw_rect(Rect2(-31, -28, 49, 12), LEAF)
			c.draw_line(Vector2(-6, 23), Vector2(-6, -5), LEAF, 4, true)
			_poly(c, [Vector2(-6, 6), Vector2(-23, -4), Vector2(-4, -8)], LEAF)
			_poly(c, [Vector2(-6, 13), Vector2(11, 0), Vector2(-3, 1)], LEAF)
			for point: Vector2 in [Vector2(27, -12), Vector2(31, 6), Vector2(23, 22)]: c.draw_circle(point, 5, Color("986541"))
		"pest":
			# Trigger sprayer: broad bottle, dark grip and a visible mist jet.
			c.draw_style_box(_box(Color("64cdb0"), 10), Rect2(-25, -9, 43, 48))
			c.draw_rect(Rect2(-18, -22, 29, 16), Color("25414b"))
			_poly(c, [Vector2(-20, -32), Vector2(28, -32), Vector2(28, -21), Vector2(4, -18), Vector2(-18, -18)], Color("edc65e"))
			c.draw_line(Vector2(8, -20), Vector2(1, -8), Color("25414b"), 5, true)
			c.draw_style_box(_box(Color("fff5d5"), 4), Rect2(-18, 4, 29, 23))
			c.draw_circle(Vector2(-4, 15), 6, LEAF)
			c.draw_line(Vector2(-12, 23), Vector2(4, 7), Color("ca7554"), 3, true)
			for index: int in range(5):
				c.draw_circle(Vector2(33 + (index % 2) * 10, -29 + index * 5), 2.4, Color("5cbea8"))

static func _symbol(c: CanvasItem, id: String) -> void:
	match id:
		"book":
			c.draw_style_box(_box(Color("5e8b62"), 4), Rect2(-29, -37, 58, 75))
			c.draw_rect(Rect2(-25, 27, 50, 8), Color("fff3d2"))
			c.draw_line(Vector2(-18, -33), Vector2(-18, 22), Color("a9bb80"), 3, true)
			_spark(c, Vector2(5, -5), Color("e3c468"), 20)
		"magnify":
			c.draw_line(Vector2(10, 12), Vector2(33, 37), Color("845a40"), 10, true)
			c.draw_circle(Vector2(-7, -7), 27, Color("588594"))
			c.draw_circle(Vector2(-7, -7), 21, Color("99d1d7"))
			c.draw_arc(Vector2(-7, -7), 14, -2.7, -1.0, 14, Color("e4fcf2"), 4, true)
		"market":
			c.draw_circle(Vector2.ZERO, 34, Color("c49337"))
			c.draw_circle(Vector2.ZERO, 27, Color("edce73"))
			c.draw_line(Vector2(-18, 14), Vector2(15, -17), INK, 6, true)
			_poly(c, [Vector2(3, -17), Vector2(17, -20), Vector2(17, -5)], INK)
		"compass":
			c.draw_circle(Vector2.ZERO, 34, Color("c59b4a"))
			c.draw_circle(Vector2.ZERO, 27, Color("ecedd7"))
			_poly(c, [Vector2(-9, 7), Vector2(13, -25), Vector2(9, -7)], Color("bf6953"))
			_poly(c, [Vector2(9, -7), Vector2(-13, 25), Vector2(-9, 7)], Color("597d80"))
		_: _spark(c, Vector2.ZERO, Color("d1ac52"), 31)

static func _activity(c: CanvasItem, id: String) -> void:
	match id:
		"debug":
			for index: int in range(3):
				var y: float = -25 + index * 25
				c.draw_line(Vector2(-34, y), Vector2(34, y), Color("688979"), 7, true)
				var x: float = [-15.0, 17.0, -4.0][index]
				c.draw_circle(Vector2(x, y), 11, Color("edc267"))
				c.draw_circle(Vector2(x, y), 5, Color("fff2c0"))
		"duck":
			c.draw_circle(Vector2(0, 12), 26, Color("f7edd1"))
			c.draw_circle(Vector2(18, -12), 20, Color("f7edd1"))
			_poly(c, [Vector2(32, -17), Vector2(47, -10), Vector2(30, -5)], Color("e8a137"))
			c.draw_circle(Vector2(23, -17), 3, INK)
			c.draw_arc(Vector2(-4, 6), 17, 0.2, PI * 0.9, 20, Color("d4cbb5"), 5, true)
			for x: int in [-9, 10]: c.draw_line(Vector2(x, 34), Vector2(x + 10, 34), Color("e8a137"), 7, true)
		"contract":
			c.draw_style_box(_box(Color("aa794c"), 4), Rect2(-31, -38, 62, 79))
			c.draw_rect(Rect2(-24, -29, 48, 59), Color("fff6dd"))
			c.draw_rect(Rect2(-12, -42, 24, 15), Color("779294"))
			for y: int in [-12, 1, 14]: c.draw_line(Vector2(-15, y), Vector2(14, y), Color("a7b098"), 3, true)
			c.draw_circle(Vector2(25, 22), 15, Color("ddb350"))
			c.draw_polyline(PackedVector2Array([Vector2(17, 22), Vector2(23, 28), Vector2(33, 16)]), INK, 3, true)
		"furnace":
			c.draw_rect(Rect2(13, -43, 16, 30), Color("637d8b"))
			c.draw_style_box(_box(Color("7592a1"), 8), Rect2(-35, -20, 70, 61))
			c.draw_style_box(_box(Color("253d4b"), 12), Rect2(-23, -7, 46, 38))
			_poly(c, [Vector2(-16, 22), Vector2(-8, 0), Vector2(0, 9), Vector2(9, -10), Vector2(16, 22)], Color("f3a347"))
			_poly(c, [Vector2(-7, 23), Vector2(0, 8), Vector2(8, 23)], Color("fff0a9"))
		_: _spark(c, Vector2.ZERO, Color("d1ac52"), 31)
