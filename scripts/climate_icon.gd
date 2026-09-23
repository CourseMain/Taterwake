extends Control
var kind: String = "calm"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var scale_factor: float = minf(size.x, size.y) / 80.0
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var blue := Color("5da6b5")
	var ink := Color("234d48")
	var gold := Color("e6b15e")
	draw_circle(Vector2(40, 40), 36, Color("d0dfd7"))
	match kind:
		"rainwater":
			draw_style_box(_box(Color("588eaa")), Rect2(22, 27, 37, 36))
			draw_line(Vector2(20, 27), Vector2(61, 27), ink, 5, true)
			draw_line(Vector2(31, 43), Vector2(53, 43), Color("b8dce2"), 3, true)
			_drop(Vector2(41, 17), 8, blue)
		"drainage":
			draw_rect(Rect2(16, 40, 49, 24), Color("99714e"))
			draw_polyline(PackedVector2Array([Vector2(14,34),Vector2(30,34),Vector2(30,52),Vector2(55,52),Vector2(55,34),Vector2(67,34)]), ink, 5, true)
			draw_line(Vector2(33, 47), Vector2(53, 47), blue, 7, true)
			_drop(Vector2(44, 21), 8, blue)
		"barn":
			draw_rect(Rect2(19, 35, 43, 29), Color("bf7550"))
			draw_colored_polygon(PackedVector2Array([Vector2(13,37),Vector2(40,16),Vector2(68,37)]), ink)
			draw_rect(Rect2(33, 43, 16, 21), Color("f2d793"))
			draw_line(Vector2(41, 43), Vector2(41, 64), ink, 2, true)
		"windbreaks":
			for i in range(3):
				var x: float = 22 + i * 18
				draw_line(Vector2(x, 35), Vector2(x, 65), Color("846143"), 4, true)
				draw_circle(Vector2(x, 31 - (i % 2) * 7), 12, Color("44795c"))
			draw_line(Vector2(10, 13), Vector2(42, 13), Color("93baca"), 3, true)
		"drought":
			draw_circle(Vector2(40, 34), 15, gold)
			for i in range(8):
				var d := Vector2.from_angle(i * TAU / 8.0)
				draw_line(Vector2(40, 34) + d * 20, Vector2(40, 34) + d * 26, gold, 3, true)
			draw_polyline(PackedVector2Array([Vector2(17,66),Vector2(31,59),Vector2(42,67),Vector2(65,61)]), Color("966b45"), 3, true)
		_:
			if kind == "calm": draw_circle(Vector2(52, 25), 13, gold)
			var cloud: Color = Color("607c88") if kind == "storm" else Color("eef5e9")
			for c in [Vector3(24,38,12), Vector3(38,30,16), Vector3(53,38,13)]: draw_circle(Vector2(c.x,c.y),c.z,cloud)
			draw_rect(Rect2(24,38,31,12),cloud)
			if kind == "storm":
				draw_colored_polygon(PackedVector2Array([Vector2(40,44),Vector2(29,60),Vector2(39,60),Vector2(35,73),Vector2(52,54),Vector2(43,54),Vector2(49,44)]),gold)
			elif kind == "flood":
				for i in range(3): _drop(Vector2(25+i*14,62),6,blue)
func _drop(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at + Vector2(0, radius * 0.3), radius * 0.65, color)
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(-radius*.6,radius*.2),at+Vector2(radius*.6,radius*.2)]),color)
func _box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
