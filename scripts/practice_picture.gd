extends Control
## Code-native drawings match the four practice mockups.
const Kit = preload("res://scripts/ui_kit.gd")
var kind: String = "sowing"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func ellipse(center: Vector2, radii: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40): points.append(center + Vector2.from_angle(i * TAU / 40) * radii)
	draw_colored_polygon(points, colour)
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / 84)
	match kind:
		"sowing":
			draw_style_box(Kit.skin(Color("8a6a3a"), Color("8a6a3a"), 0, 6, 1, false), Rect2(10,48,64,22))
			for x in [30,54]:
				ellipse(Vector2(x,44),Vector2(10,7),Kit.CROPS.golden); draw_line(Vector2(x,37),Vector2(x,23),Color("4f7034"),4,true); draw_circle(Vector2(x,20),6,Kit.KEEPERS.mara)
		"store":
			draw_style_box(Kit.skin(Kit.CROPS.icecap, Kit.KEEPERS.iris, 0, 8, 1, false), Rect2(14,26,56,44))
			draw_line(Vector2(14,40),Vector2(70,40),Kit.KEEPERS.iris,4,true); ellipse(Vector2(42,56),Vector2(12,8),Kit.CROPS.russet)
			draw_line(Vector2(42,12),Vector2(42,22),Kit.KEEPERS.iris,4,true); draw_polyline(PackedVector2Array([Vector2(34,16),Vector2(42,22),Vector2(50,16)]),Kit.KEEPERS.iris,4,true)
		"duck":
			ellipse(Vector2(40,52),Vector2(24,16),Color("f3d27a")); draw_circle(Vector2(58,36),11,Color("f3d27a"))
			draw_colored_polygon(PackedVector2Array([Vector2(66,36),Vector2(76,39),Vector2(66,42)]),Color("e8893a")); draw_circle(Vector2(60,33),2,Kit.INK)
			for center in [Vector2(18,70),Vector2(30,72)]: draw_circle(center,4,Kit.WOOD2)
		"pearl":
			ellipse(Vector2(42,48),Vector2(26,20),Color("9fd8f0")); draw_circle(Vector2(34,44),3,Kit.INK); draw_circle(Vector2(50,52),3,Kit.INK)
			for pair in [[Vector2(26,22),Vector2(32,30)],[Vector2(58,22),Vector2(52,30)],[Vector2(42,16),Vector2(42,26)]]: draw_line(pair[0],pair[1],Kit.KEEPERS.iris,4,true)
