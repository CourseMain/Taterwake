extends Control
## Small vector storybook scenes. No image downloads or extra 3D viewports.
const Type = preload("res://scripts/ui_type.gd")
var kind: String = "farmer":
	set(value):
		if kind != value:
			kind = value
			queue_redraw()
var grade: String = "S":
	set(value):
		if grade != value:
			grade = value
			queue_redraw()
var reward_text: String = "?":
	set(value):
		if reward_text != value:
			reward_text = value
			queue_redraw()
var grade_caption: String = "Expected grade":
	set(value):
		if grade_caption != value:
			grade_caption = value
			queue_redraw()
var result_serial: int = -1
var stamp_left: float = 0.0
var motion: bool = false
var t: float = 0.0
var tick: float = 0.0
var font: Font = Type.face(Type.BODY, 700)
const INK := Color("24493f")
const GOLD := Color("e5b75c")
const LEAF := Color("5a8d62")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var stamping: bool = stamp_left > 0
	stamp_left = maxf(0, stamp_left-delta)
	if stamping and stamp_left == 0: queue_redraw()
	t += delta
	tick += delta
	if tick >= 0.05 and (motion or stamp_left > 0):
		tick = 0
		queue_redraw()
func canvas_scale() -> float:
	return minf(size.x / 620.0, size.y / 152.0)
func canvas_origin() -> Vector2:
	return (size - Vector2(620, 152) * canvas_scale()) * 0.5
func base_transform() -> void:
	draw_set_transform(canvas_origin(), 0, Vector2.ONE * canvas_scale())
func label(at: Vector2, words: String, color: Color = INK, font_size: int = 14) -> void:
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
func box(rect: Rect2, color: Color, radius: int = 9) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
func spud(at: Vector2, scale_by: float = 1.0, color: Color = GOLD) -> void:
	draw_set_transform(canvas_origin() + at * canvas_scale(), -0.12, Vector2.ONE * canvas_scale() * scale_by)
	draw_circle(Vector2(0,3), 13, Color("23493e", 0.12))
	ellipse(Rect2(-14,-18,28,34), color)
	draw_circle(Vector2(-5,-2), 1.5, INK)
	draw_circle(Vector2(5,-2), 1.5, INK)
	draw_arc(Vector2(0,0), 5, 0.3, 2.8, 8, INK, 1.5, true)
	base_transform()
func ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24): points.append(rect.get_center() + Vector2(cos(i*TAU/24.0),sin(i*TAU/24.0))*rect.size*.5)
	draw_colored_polygon(points,color)
func crate(at: Vector2) -> void:
	box(Rect2(at-Vector2(35,22), Vector2(70,44)), Color("c39965"), 4)
	for x in [-24,0,24]: draw_line(at+Vector2(x,-20), at+Vector2(x,20), Color("986d4b"), 3)
	draw_line(at+Vector2(-34,-14),at+Vector2(34,-14),Color("e1bf88"),5)
	draw_line(at+Vector2(-34,14),at+Vector2(34,14),Color("e1bf88"),5)
func _draw() -> void:
	base_transform()
	for x in [5,211,417]: box(Rect2(x,5,198,142),Color("e7ecdc"),11)
	var bob: float = sin(t*2.5)*2 if motion else 0
	match kind:
		"farmer":
			box(Rect2(32,84,130,16),Color("a98259"))
			for x in [64,113]:
				draw_line(Vector2(x,86),Vector2(x,49),LEAF,4,true)
				ellipse(Rect2(x-20,48,22,12),LEAF)
				ellipse(Rect2(x,43,22,12),LEAF)
			box(Rect2(245,87,134,15),Color("a98259"))
			box(Rect2(255,39,39,47),Color("b79862"),8)
			box(Rect2(253,37,43,8),Color("e1c18a"),3)
			label(Vector2(267,69),"1",Color("fff5d8"),20)
			draw_line(Vector2(340,89),Vector2(340,52),LEAF,4,true)
			ellipse(Rect2(320,52,22,12),LEAF)
			ellipse(Rect2(340,45,22,12),LEAF)
			for i in range(5): draw_circle(Vector2(297+i*6,69+i*4+bob),3,Color("715a40"))
			box(Rect2(455,96,126,9),Color("a98259"))
			spud(Vector2(520,67+bob),1.8)
			for i in range(3):
				draw_line(Vector2(463+i*8,44),Vector2(460+i*8,52),Color("76bac2"),3,true)
			draw_circle(Vector2(566,36),10,GOLD)
			label(Vector2(58,131),"Plant a crop")
			label(Vector2(257,131),"Add 1 compost")
			label(Vector2(447,131),"Water, grow, harvest")
		"industrialist":
			crate(Vector2(100,74))
			for i in range(3): spud(Vector2(80+i*20,47),.60)
			box(Rect2(248,31,124,56),Color("548d84"))
			box(Rect2(238,84,144,14),INK)
			for i in range(5):
				var x: float = 248+fmod(i*26+(t*24 if motion else 0),128)
				draw_circle(Vector2(x,91),5,Color("a7bbb0"))
			label(Vector2(272,62),"GRADE",Color("f8efca"),17)
			var pop: float = sin((1-stamp_left)*PI)*7 if stamp_left > 0 else 0
			crate(Vector2(518,76-pop))
			box(Rect2(480,43-pop,76,45), GOLD if grade.begins_with("S") else Color("b8d4bb"))
			var grade_width: float = font.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			label(Vector2(518-grade_width*.5,74-pop),grade,INK,24)
			if stamp_left > 0:
				for i in range(8):
					var ray := Vector2(cos(i*TAU/8),sin(i*TAU/8))
					var centre := Vector2(518,65-pop)
					draw_line(centre+ray*46,centre+ray*(46+stamp_left*14),Color(GOLD,stamp_left),3,true)
			label(Vector2(53,131),"Load harvest")
			label(Vector2(258,131),"Match process")
			var caption_width: float = font.get_string_size(grade_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			label(Vector2(517 - caption_width * 0.5,131),grade_caption)
		"scientist":
			spud(Vector2(76,69),1.1)
			spud(Vector2(133,69),1.1,Color("9bd7da"))
			label(Vector2(99,74),"+",INK,19)
			box(Rect2(281,35,56,65),Color("a4ccc2"),16)
			box(Rect2(295,21,27,23),INK,3)
			box(Rect2(287,65+bob,44,27-bob),Color("84b899"),10)
			for i in range(4): draw_circle(Vector2(296+i*8,62-fmod(t*10+i*12,30)),2.5,Color("f8efca"))
			spud(Vector2(511,62),1.2,Color("b8d979"))
			box(Rect2(548,60,31,42),Color("e4bf78"),3)
			label(Vector2(43,131),"10 + 10 harvested crops")
			label(Vector2(272,131),"Crossbreed")
			label(Vector2(459,131),"Save a planting trait")
		"investor":
			box(Rect2(57,25,88,78),Color("b48d5e"),4)
			box(Rect2(65,33,72,61),Color("fff4d5"),3)
			label(Vector2(74,64),"LOCKED",INK,14)
			for i in range(3): draw_line(Vector2(77,75+i*5),Vector2(125,75+i*5),LEAF,2)
			crate(Vector2(285,84)); crate(Vector2(333,57))
			draw_colored_polygon(PackedVector2Array([Vector2(458,76+bob),Vector2(578,76+bob),Vector2(558,103+bob),Vector2(476,103+bob)]),INK)
			box(Rect2(502,39+bob,51,35),Color("deb473"),3)
			draw_line(Vector2(451,112),Vector2(582,112),Color("7daeb8"),3,true)
			label(Vector2(55,131),"Reserve price")
			label(Vector2(263,131),"Prepare cargo")
			label(Vector2(463,131),"Deliver for coins")
		"gambler":
			crate(Vector2(100,77))
			box(Rect2(66,47,67,27),Color("efe2b9"),4)
			label(Vector2(78,65),"STAKE",INK,13)
			for i in range(2):
				var x: float = 266+i*51
				box(Rect2(x,47+bob,42,42),Color("86699c"),8)
				for j in range(i+2): draw_circle(Vector2(x+12+j*8,61+bob+j*6),3,Color("fff1ce"))
			draw_circle(Vector2(515,68),29,GOLD)
			var reward_width: float = font.get_string_size(reward_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
			label(Vector2(515-reward_width*.5,77),reward_text,INK,23)
			label(Vector2(51,131),"Choose stake")
			label(Vector2(265,131),"Reveal result")
			label(Vector2(469,131),"Claim or charm")
	for x in [199,405]:
		draw_polyline(PackedVector2Array([Vector2(x-4,69),Vector2(x+3,76),Vector2(x-4,83)]),LEAF,3,true)
