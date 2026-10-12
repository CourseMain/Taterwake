extends Control
## Paper-and-ink drawings for pack backs, inert superstitions and the three oddities.
const Kit = preload("res://scripts/ui_kit.gd")
var kind: String = "seed"
var id: String = ""
var colour: Color = Kit.MUTED
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var u: float = minf(size.x,size.y)/100.0
	draw_set_transform(size*.5,0,Vector2.ONE*u)
	draw_circle(Vector2(0,5),42,Kit.PAPER2)
	match kind:
		"unfound_card":
			draw_rect(Rect2(-25,-35,50,70),Kit.MUTED)
			draw_rect(Rect2(-25,-35,50,70),Kit.INK,false,3)
		"unfound_potato":
			draw_ellipse_silhouette()
		"seed", "seeds":
			draw_colored_polygon(PackedVector2Array([Vector2(-20,-26),Vector2(-31,27),Vector2(-20,35),Vector2(22,35),Vector2(31,25),Vector2(19,-26)]),colour)
			draw_polyline(PackedVector2Array([Vector2(-20,-26),Vector2(-31,27),Vector2(-20,35),Vector2(22,35),Vector2(31,25),Vector2(19,-26),Vector2(-20,-26)]),Kit.INK,3,true)
			draw_line(Vector2(-23,-19),Vector2(23,-19),Kit.INK,4,true)
			draw_circle(Vector2(0,6),13,Kit.PAPER); draw_arc(Vector2(0,6),13,0,TAU,24,Kit.INK,2,true)
			draw_line(Vector2(0,-7),Vector2(0,-15),Kit.INK,2,true)
		"superstition":
			var points := PackedVector2Array([Vector2(-32,24),Vector2(-34,-24),Vector2(-13,-9),Vector2(0,-34),Vector2(13,-9),Vector2(34,-24),Vector2(32,24)])
			draw_colored_polygon(points,colour); points.append(points[0]); draw_polyline(points,Kit.INK,3,true)
			for point in [Vector2(-34,-24),Vector2(0,-34),Vector2(34,-24)]: draw_circle(point,5,Kit.PAPER); draw_arc(point,5,0,TAU,12,Kit.INK,2,true)
			draw_line(Vector2(-32,24),Vector2(32,24),Kit.INK,5,true)
		"superstition_card": _superstition()
		"mystery":
			draw_arc(Vector2(0,-13),16,PI,TAU*1.25,24,colour,7,true)
			draw_polyline(PackedVector2Array([Vector2(16,-13),Vector2(14,-2),Vector2(0,8),Vector2(0,17)]),colour,7,true)
			draw_circle(Vector2(0,31),5,colour)
		"stone":
			var points := PackedVector2Array([Vector2(-32,20),Vector2(-23,-16),Vector2(8,-29),Vector2(30,-8),Vector2(35,22),Vector2(1,34)])
			draw_colored_polygon(points,Kit.MUTED); points.append(points[0]); draw_polyline(points,Kit.INK,3,true)
			draw_line(Vector2(-10,-9),Vector2(2,-16),Kit.PAPER,3,true)
		"refund":
			draw_circle(Vector2.ZERO,29,colour); draw_arc(Vector2.ZERO,29,0,TAU,36,Kit.INK,3,true)
			draw_arc(Vector2.ZERO,20,0,TAU,36,Kit.PAPER,2,true)
			draw_line(Vector2(-8,7),Vector2(8,-7),Kit.INK,5,true)
		"oddity":
			var potato: Color = Kit.CROPS.get(id,Kit.MUTED)
			if get_meta("oddity_name", "") == "the Twin":
				for x: float in [-15,15]: _spud(Vector2(x,0),Vector2(.7,.85),potato)
			else:
				_spud(Vector2.ZERO,Vector2.ONE,potato)
				if get_meta("oddity_name", "") == "the Heart": draw_polyline(PackedVector2Array([Vector2(-16,15),Vector2(-8,6),Vector2(0,13),Vector2(8,6),Vector2(16,15),Vector2(0,28),Vector2(-16,15)]),Kit.INK,3,true)
				if get_meta("oddity_name", "") == "the Glow Spud":
					for a in range(8): draw_line(Vector2.from_angle(a*TAU/8)*37,Vector2.from_angle(a*TAU/8)*44,potato,3,true)
		_:
			preload("res://scripts/item_icon.gd").paint(self,{"kind":"crop","crop":id},Rect2(Vector2.ZERO,size))
	draw_set_transform(Vector2.ZERO)
func draw_ellipse_silhouette() -> void:
	var outline := PackedVector2Array()
	for i in range(32): outline.append(Vector2(cos(i*TAU/32)*26,sin(i*TAU/32)*33))
	draw_colored_polygon(outline,Kit.MUTED)
	outline.append(outline[0]); draw_polyline(outline,Kit.INK,2,true)
func _spud(at: Vector2, scale_value: Vector2, paint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32): points.append(at+Vector2(cos(i*TAU/32)*26,sin(i*TAU/32)*33)*scale_value)
	draw_colored_polygon(points,paint); points.append(points[0]); draw_polyline(points,Kit.INK,2,true)
	for x: float in [-8,8]: draw_circle(at+Vector2(x,-3)*scale_value,3,Kit.INK)
	draw_arc(at+Vector2(0,8)*scale_value,8,0,PI,16,Kit.INK,2,true)

func _superstition() -> void:
	match id:
		"Second Sowing", "Seed Saver":
			for x: float in [-22,0,22]:
				draw_circle(Vector2(x,22),7,colour); draw_arc(Vector2(x,22),7,0,TAU,16,Kit.INK,2,true)
				draw_line(Vector2(x,14),Vector2(x,-18),Kit.INK,3,true)
				draw_colored_polygon(PackedVector2Array([Vector2(x,-9),Vector2(x-15,-22),Vector2(x-14,-8)]),colour)
			if id == "Seed Saver": draw_arc(Vector2(0,3),36,0,PI,30,Kit.INK,3,true)
		"Early Riser":
			draw_circle(Vector2(0,-10),20,colour)
			for i in range(8): draw_line(Vector2(0,-10)+Vector2.from_angle(i*TAU/8)*25,Vector2(0,-10)+Vector2.from_angle(i*TAU/8)*34,Kit.INK,3,true)
			draw_line(Vector2(-35,29),Vector2(35,29),Kit.INK,4,true)
		"Windbreak Rows":
			for x: float in [-26,0,26]:
				draw_line(Vector2(x,30),Vector2(x,-30),Kit.INK,3,true)
				draw_colored_polygon(PackedVector2Array([Vector2(x,-34),Vector2(x-14,12),Vector2(x+14,12)]),colour)
			draw_arc(Vector2(-25,-6),35,-.45,.45,16,Kit.INK,2,true)
		"Oda's Spare Hoe":
			draw_line(Vector2(-24,32),Vector2(21,-31),Kit.WOOD,7,true)
			draw_line(Vector2(4,-31),Vector2(34,-15),Kit.INK,10,true)
		"Nell's Cat":
			draw_colored_polygon(PackedVector2Array([Vector2(-25,16),Vector2(-25,-30),Vector2(-10,-16),Vector2(10,-16),Vector2(25,-30),Vector2(25,16)]),colour)
			for x: float in [-10,10]: draw_circle(Vector2(x,-1),4,Kit.INK)
			for side: float in [-1,1]:
				draw_line(Vector2(side*8,10),Vector2(side*37,3),Kit.INK,2,true)
				draw_line(Vector2(side*8,14),Vector2(side*37,18),Kit.INK,2,true)
		"Lucky Boot":
			var shape := PackedVector2Array([Vector2(-19,-32),Vector2(8,-32),Vector2(8,9),Vector2(30,16),Vector2(30,31),Vector2(-19,31)])
			draw_colored_polygon(shape,colour); shape.append(shape[0]); draw_polyline(shape,Kit.INK,3,true)
			draw_line(Vector2(-19,23),Vector2(30,23),Kit.INK,3,true)
		"Cold Store":
			draw_rect(Rect2(-29,-30,58,63),colour); draw_rect(Rect2(-29,-30,58,63),Kit.INK,false,3)
			draw_line(Vector2(-29,-9),Vector2(29,-9),Kit.INK,3,true)
			for x: float in [-20,0,20]: draw_line(Vector2(x,3),Vector2(x,23),Kit.PAPER,3,true)
		"Iris's Mug":
			draw_rect(Rect2(-23,-16,40,48),colour); draw_rect(Rect2(-23,-16,40,48),Kit.INK,false,3)
			draw_arc(Vector2(20,5),16,-PI*.5,PI*.5,24,Kit.INK,5,true)
			for x: float in [-12,3]: draw_arc(Vector2(x,-25),9,PI*.5,PI*1.5,16,Kit.INK,2,true)
		"Fennick's Thumb":
			var shape := PackedVector2Array([Vector2(-27,8),Vector2(-10,8),Vector2(0,-27),Vector2(10,-31),Vector2(17,-23),Vector2(12,0),Vector2(30,0),Vector2(25,29),Vector2(-27,29)])
			draw_colored_polygon(shape,colour); shape.append(shape[0]); draw_polyline(shape,Kit.INK,3,true)
		"Haunted Scarecrow":
			draw_line(Vector2(0,-5),Vector2(0,38),Kit.WOOD,6,true); draw_line(Vector2(-34,5),Vector2(34,5),Kit.WOOD,5,true)
			_spud(Vector2(0,-20),Vector2(.5,.5),colour)
			draw_colored_polygon(PackedVector2Array([Vector2(-21,2),Vector2(21,2),Vector2(27,29),Vector2(-27,29)]),Kit.PAPER)
		"The Cursed One":
			_spud(Vector2.ZERO,Vector2.ONE,colour)
			for x: float in [-8,8]:
				draw_line(Vector2(x-4,-7),Vector2(x+4,1),Kit.PAPER,3,true)
				draw_line(Vector2(x+4,-7),Vector2(x-4,1),Kit.PAPER,3,true)
