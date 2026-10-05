extends Control
## Shared, hand-drawn item illustrations. Geometry remains crisp at every HUD scale.
var item: Dictionary = {}
const INK: Color = Color("30463a")
const LEAF: Color = Color("5e7b50")
const CROP: Dictionary = {"russet": Color("dfb36f"), "golden": Color("f5cc38"), "giant": Color("d7a37b"), "sunburst": Color("ffa629"), "icecap": Color("d8f1ff")}

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
		"place": _place(c, id)
		"control": _control(c, id)
		"forecast": _forecast(c, id, bool(data.get("warning", false)))
		"event": _event(c, id)
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

static func _place(c: CanvasItem, id: String) -> void:
	# The same warm outlines, soft cast shadows and lumpy geometry as the
	# potatoes: pictures name the place before its text needs to be read.
	match id:
		"barn":
			_poly(c, [Vector2(-31, -10), Vector2(31, -10), Vector2(31, 33), Vector2(-31, 33)], Color("b07750"))
			_poly(c, [Vector2(-37, -10), Vector2(0, -38), Vector2(38, -10)], Color("79553d"))
			_poly(c, [Vector2(-27, -9), Vector2(-2, -29), Vector2(26, -9)], Color("d5a06a"))
			c.draw_rect(Rect2(-15, 5, 30, 28), Color("17382d"))
			for x: int in [-24, 22]: c.draw_line(Vector2(x, -5), Vector2(x, 28), Color("e3bb87"), 2, true)
			c.draw_line(Vector2(-14, 7), Vector2(14, 30), Color("d5a06a"), 3, true)
			c.draw_line(Vector2(14, 7), Vector2(-14, 30), Color("d5a06a"), 3, true)
			c.draw_style_box(_box(Color("d8ba77"), 6), Rect2(17, 20, 23, 17))
			c.draw_line(Vector2(18, 26), Vector2(39, 26), Color("967148"), 2, true)
		"ledger":
			c.draw_style_box(_box(Color("17382d"), 5), Rect2(-37, -31, 74, 67))
			_poly(c, [Vector2(-31, -28), Vector2(-4, -24), Vector2(-4, 30), Vector2(-31, 26)], Color("fffbed"))
			_poly(c, [Vector2(1, -24), Vector2(31, -28), Vector2(31, 26), Vector2(1, 30)], Color("f0e5c9"))
			c.draw_line(Vector2(-1, -23), Vector2(-1, 30), Color("79553d"), 3, true)
			for y: int in [-12, -2, 8, 18]:
				c.draw_line(Vector2(-25, y), Vector2(-10, y + 1), Color("728575"), 1.5, true)
				c.draw_line(Vector2(7, y + 1), Vector2(25, y), Color("728575"), 1.5, true)
			c.draw_line(Vector2(20, -19), Vector2(20, 21), Color("a56443"), 1, true)
			c.draw_line(Vector2(18, -37), Vector2(-9, 10), Color("bf913e"), 5, true)
			_poly(c, [Vector2(-9, 10), Vector2(-13, 18), Vector2(-5, 13)], INK)
		"forecast":
			c.draw_circle(Vector2(15, -17), 19, Color("e2b254"))
			c.draw_arc(Vector2(15, -17), 25, -.8, 3.4, 22, Color("e2b254"), 2, true)
			for point: Vector2 in [Vector2(-20, 1), Vector2(-6, -7), Vector2(10, 2)]:
				c.draw_circle(point + Vector2(1, 3), 17, Color("547e83"))
				c.draw_circle(point, 15, Color("9db9b3"))
			for x: int in [-20, -4, 12]: c.draw_line(Vector2(x, 23), Vector2(x - 5, 33), Color("527e95"), 4, true)
		_: _symbol(c, id)

static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK.lerp(color, 0.27)
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

static func _metric(c: CanvasItem, id: String) -> void:
	match id:
		"home":
			_poly(c, [Vector2(-32,0), Vector2(0,-32), Vector2(32,0)], INK)
			c.draw_rect(Rect2(-23,0,46,32), Color("b99d6c"))
		"low": _event(c, "flood")
		"hill": _poly(c, [Vector2(-38,30),Vector2(0,-32),Vector2(38,30)], INK)
		"drop":
			_poly(c, [Vector2(0, -33), Vector2(-22, 4), Vector2(-18, 24), Vector2(0, 32), Vector2(18, 24), Vector2(22, 4)], Color("508ba0"))
		"sun":
			c.draw_circle(Vector2.ZERO, 18, Color("bd783a"))
			for i in range(8): c.draw_line(Vector2.from_angle(i * TAU / 8) * 23, Vector2.from_angle(i * TAU / 8) * 34, INK, 4, true)
		"snowflake":
			for i in range(6):
				var direction := Vector2.from_angle(i * TAU / 6)
				c.draw_line(Vector2.ZERO, direction * 32, Color("638396"), 4, true)
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
		_: _spark(c, Vector2.ZERO, Color("d1ac52"), 31)

static func _event(c: CanvasItem, event: String) -> void:
	if event == "drought" or event == "dry_bed": _metric(c, "sun")
	elif event in ["freeze", "autumn_cold", "deep_freeze", "blizzard"]:
		_metric(c, "snowflake")
		if event == "deep_freeze": c.draw_arc(Vector2.ZERO, 40, 0, TAU, 32, INK, 3, true)
		if event == "blizzard": c.draw_line(Vector2(-40, 31), Vector2(40, 20), INK, 4, true)
	elif event == "storm": _poly(c, [Vector2(12,-40), Vector2(-22,4), Vector2(5,0), Vector2(-10,40), Vector2(25,-5), Vector2(0,0)], INK)
	elif event == "flood":
		for y in [-22, 0, 22]: c.draw_polyline(PackedVector2Array([Vector2(-40,y), Vector2(-20,y-8), Vector2(0,y+3), Vector2(20,y-8), Vector2(40,y)]), Color("638396"), 5, true)
	else: _metric(c, "weather")

static func forecast_picture(climate: Dictionary) -> Dictionary:
	var event: String = str(climate.get("event", ""))
	if str(climate.get("phase", "calm")) == "calm": event = str(climate.get("signal", ""))
	var sky: String = {"drought":"sun", "flood":"rain", "storm":"storm", "freeze":"snow", "deep_freeze":"snow", "blizzard":"snow"}.get(event, "cloud" if float(climate.get("forecast", {}).get("high", 0)) >= .4 else "sun")
	return {"kind":"forecast", "id":sky, "warning":climate.get("phase", "calm") == "warning"}

static func control_picture(action: String, words: String) -> Dictionary:
	var text: String = (action + " " + words).to_lower()
	if "sell" in text or action == "barn": return {"kind":"control", "id":"sack"}
	for tool: String in ["hoe", "water", "harvest", "pest", "sprayer", "plant"]:
		if tool in text: return {"kind":"tool", "id":"pest" if tool == "sprayer" else tool}
	if "tools" in text or "upgrade" in text: return {"kind":"tool", "id":"hoe"}
	if "seed" in text or "crop" in text: return {"kind":"seed", "crop":"russet"}
	if "weather" in text or "forecast" in text or "climate" in text: return {"kind":"place", "id":"forecast"}
	if "menu" in text or "help" in text or "dex" in text: return {"kind":"symbol", "id":"book"}
	if "accounts" in text or "ledger" in text or "bill" in text: return {"kind":"place", "id":"ledger"}
	if "duck" in text: return {"kind":"activity", "id":"duck"}
	if "spring" in text or "calendar" in text or "year" in text: return {"kind":"control", "id":"calendar"}
	if "talk" in text or "chat" in text or "story" in text or "news" in text: return {"kind":"control", "id":"talk"}
	if "sleep" in text: return {"kind":"control", "id":"moon"}
	if "sound" in text or "quiet" in text: return {"kind":"control", "id":"sound"}
	if "graphics" in text or "resolution" in text or "smooth" in text or "crisp" in text or "balanced" in text or "shadow" in text: return {"kind":"control", "id":"eye"}
	if "save" in text or "continue" in text or "keep" in text: return {"kind":"control", "id":"save"}
	if "close" in text or "skip" in text or "return" in text or "leave" in text: return {"kind":"control", "id":"door"}
	if "hat" in text or "farmer" in text or "look" in text or "seasonal" in text or "straw" in text or "cap" in text: return {"kind":"control", "id":"hat"}
	if "shirt" in text: return {"kind":"control", "id":"shirt"}
	if "quest" in text or "board" in text or "job" in text: return {"kind":"control", "id":"board"}
	if "rent" in text or "bed" in text or "land" in text or "expand" in text: return {"kind":"metric", "id":"beds"}
	if "buy" in text or "purchase" in text or "order" in text: return {"kind":"control", "id":"sack"}
	return {"kind":"control", "id":"hand"}

static func _forecast(c: CanvasItem, sky: String, warning: bool) -> void:
	if sky == "sun": _metric(c, "sun")
	else:
		if sky == "cloud": c.draw_circle(Vector2(18,-20), 17, Color("f4c860"))
		for point: Vector2 in [Vector2(-23,0),Vector2(0,-11),Vector2(23,0)]:
			c.draw_circle(point+Vector2(0,3),18,Color("597582"))
			c.draw_circle(point,16,Color("a9c4cd") if sky != "storm" else Color("718e9f"))
		if sky == "rain":
			for x in [-22,0,22]: c.draw_line(Vector2(x,23),Vector2(x-6,35),Color("6bbbd4"),5,true)
		elif sky == "storm":
			_poly(c,[Vector2(7,12),Vector2(-13,28),Vector2(0,28),Vector2(-9,42),Vector2(18,20),Vector2(5,20)],Color("ffcf62"))
		elif sky == "snow":
			for x in [-22,0,22]:
				for i in range(3):
					var d := Vector2.from_angle(i*PI/3.)*7
					c.draw_line(Vector2(x,29)-d,Vector2(x,29)+d,Color("eff8ff"),2.5,true)
	if warning:
		c.draw_circle(Vector2(31,-31),10,Color("fff4d3"))
		c.draw_circle(Vector2(31,-31),7,Color("d96c43"))

static func _control(c: CanvasItem, id: String) -> void:
	match id:
		"sack":
			_poly(c,[Vector2(-16,-28),Vector2(-9,-14),Vector2(-31,11),Vector2(-29,32),Vector2(0,40),Vector2(29,32),Vector2(31,11),Vector2(9,-14),Vector2(16,-28)],Color("d7ae74"))
			c.draw_line(Vector2(-15,-14),Vector2(15,-14),INK,5,true)
			c.draw_arc(Vector2(0,14),16,.1,2.9,14,Color("916846"),3,true)
			for p in [Vector2(-9,2),Vector2(9,3)]: c.draw_circle(p,4,Color("efce93"))
		"calendar", "board":
			c.draw_style_box(_box(Color("fff3d6"),5),Rect2(-30,-29,60,65))
			c.draw_rect(Rect2(-30,-29,60,16),Color("cf7953"))
			for x in [-15,15]: c.draw_line(Vector2(x,-37),Vector2(x,-22),INK,5,true)
			for x in [-17,0,17]:
				for y in [-1,16]: c.draw_circle(Vector2(x,y),4,Color("688a60"))
		"talk":
			c.draw_style_box(_box(Color("fff3d6"),14),Rect2(-34,-28,68,48))
			_poly(c,[Vector2(-15,14),Vector2(-21,35),Vector2(3,18)],Color("fff3d6"))
			for x in [-18,0,18]: c.draw_circle(Vector2(x,-4),4,INK)
		"moon":
			c.draw_circle(Vector2(0,0),31,Color("edcf85"))
			c.draw_circle(Vector2(15,-10),27,Color("e5dec6"))
			_spark(c,Vector2(26,28),Color("f0b955"),9)
		"save":
			c.draw_style_box(_box(Color("6f9d8e"),5),Rect2(-30,-32,60,65))
			c.draw_rect(Rect2(-19,-31,38,23),Color("fff3d6"))
			c.draw_rect(Rect2(-19,5,38,28),Color("fff3d6"))
			c.draw_rect(Rect2(7,-27,7,16),INK)
		"door":
			c.draw_style_box(_box(Color("b28457"),3),Rect2(-23,-33,46,68))
			c.draw_circle(Vector2(12,4),4,Color("ffe19b"))
			c.draw_line(Vector2(-37,30),Vector2(32,30),INK,4,true)
		"eye":
			_poly(c,[Vector2(-39,0),Vector2(-20,-22),Vector2(18,-22),Vector2(39,0),Vector2(18,22),Vector2(-20,22)],Color("fff3d6"))
			c.draw_circle(Vector2.ZERO,15,Color("75aab7")); c.draw_circle(Vector2.ZERO,7,INK)
		"sound":
			_poly(c,[Vector2(-31,-12),Vector2(-14,-12),Vector2(8,-29),Vector2(8,29),Vector2(-14,12),Vector2(-31,12)],Color("789b92"))
			for r in [22,34]: c.draw_arc(Vector2(4,0),r,-.8,.8,14,INK,3,true)
		"hat":
			c.draw_style_box(_box(Color("d6b474"),8),Rect2(-23,-25,46,38))
			c.draw_line(Vector2(-23,7),Vector2(23,7),Color("6c9277"),8,true)
			c.draw_style_box(_box(Color("f0cf8d"),7),Rect2(-40,12,80,14))
		"shirt":
			_poly(c,[Vector2(-15,-29),Vector2(-35,-18),Vector2(-25,2),Vector2(-17,-1),Vector2(-17,34),Vector2(17,34),Vector2(17,-1),Vector2(25,2),Vector2(35,-18),Vector2(15,-29),Vector2(0,-19)],Color("75a28a"))
		"hand":
			c.draw_style_box(_box(Color("edc993"),9),Rect2(-17,-6,36,40))
			c.draw_style_box(_box(Color("edc993"),5),Rect2(-16,-34,12,39))
			c.draw_line(Vector2(-27,7),Vector2(-9,27),Color("edc993"),12,true)
			for x in [0,12]: c.draw_line(Vector2(x,-8),Vector2(x,15),Color("edc993"),10,true)
