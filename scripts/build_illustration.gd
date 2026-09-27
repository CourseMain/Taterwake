extends Control
## Inked field-guide diagrams. The same crop silhouettes appear in the inventory.
const Items = preload("res://scripts/item_icon.gd")
const HAND = preload("res://assets/fonts/PatrickHand.ttf")
var specimen: bool = false
var compact_layout: bool = false
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
const INK := Color("30463a")
const GOLD := Color("cda359")
const LEAF := Color("668153")
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
func canvas_dimensions() -> Vector2:
	if specimen: return Vector2(110, 128)
	return Vector2(320, 128) if compact_layout or size.x < 440 else Vector2(620, 152)
func canvas_scale() -> float:
	var dimensions: Vector2 = canvas_dimensions()
	return minf(size.x / dimensions.x, size.y / dimensions.y)
func canvas_origin() -> Vector2:
	return (size - canvas_dimensions() * canvas_scale()) * 0.5
func base_transform() -> void:
	draw_set_transform(canvas_origin(), 0, Vector2.ONE * canvas_scale())
func label(at: Vector2, words: String, color: Color = INK, font_size: int = 14) -> void:
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
func box(rect: Rect2, color: Color, radius: int = 9) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(mini(radius, 5))
	style.border_color = INK.lerp(color, 0.35)
	style.set_border_width_all(1)
	draw_style_box(style, rect)
	if rect.size.y > 20:
		draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(rect.size.x - 5, 3), color.lightened(0.22), 2, true)
func spud(at: Vector2, scale_by: float = 1.0, color: Color = GOLD) -> void:
	draw_set_transform(canvas_origin() + at * canvas_scale(), -0.12, Vector2.ONE * canvas_scale() * scale_by)
	var crop: String = "icecap" if color == Color("9bd7da") else "russet"
	var tint: Color = Color("b8c38b") if color == Color("b8d979") else Color.TRANSPARENT
	Items._potato(self, crop, Vector2.ZERO, 0.52, tint)
	base_transform()
func ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24): points.append(rect.get_center() + Vector2(cos(i*TAU/24.0),sin(i*TAU/24.0))*rect.size*.5)
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points, INK.lerp(color, 0.42), 1, true)
func crate(at: Vector2) -> void:
	box(Rect2(at-Vector2(35,22), Vector2(70,44)), Color("c39965"), 4)
	for x in [-24,0,24]: draw_line(at+Vector2(x,-20), at+Vector2(x,20), Color("986d4b"), 2)
	# One replacement slat; two bent nails. A crate has had a working life.
	draw_line(at+Vector2(-20,-19), at+Vector2(-20,19), Color("849273"), 9)
	for nail in [Vector2(-28,-14), Vector2(27,14)]: draw_line(at+nail,at+nail+Vector2(3,1), INK, 1.5, true)
	draw_line(at+Vector2(-34,-14),at+Vector2(34,-14),Color("e1bf88"),5)
	draw_line(at+Vector2(-34,14),at+Vector2(34,14),Color("e1bf88"),5)
func _specimen() -> void:
	# Drawings sit directly on the notebook stock, with measured pencil ticks.
	for y in [24, 39, 54, 69, 84]:
		draw_line(Vector2(8, y), Vector2(13 if y != 54 else 18, y), Color("82907a"), 1, true)
	draw_line(Vector2(8, 21), Vector2(8, 88), Color("82907a"), 1, true)
	match kind:
		"farmer":
			ellipse(Rect2(21, 85, 69, 9), Color("c3b99c"))
			spud(Vector2(54, 57), 2.35)
			draw_string(HAND, Vector2(32, 115), "3× harvest", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		"industrialist":
			box(Rect2(25, 32, 63, 42), Color("668778"), 4)
			box(Rect2(18, 68, 74, 13), INK, 3)
			for x in [27, 46, 65, 84]: draw_circle(Vector2(x, 75), 4, Color("b5b8a0"))
			spud(Vector2(44, 25), 0.7)
			box(Rect2(66, 37, 16, 14), Color("b18c5c"), 2)
			for y in [40, 46]: draw_line(Vector2(67,y), Vector2(71,y+2), INK, 1, true)
			draw_string(HAND, Vector2(24, 112), "grade by grade", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		"scientist":
			spud(Vector2(34, 35), 1.0)
			spud(Vector2(79, 36), 1.0, Color("9bd7da"))
			label(Vector2(53, 42), "+", INK, 17)
			draw_polyline(PackedVector2Array([Vector2(34,58),Vector2(34,67),Vector2(78,67),Vector2(78,58)]), LEAF, 1.5, true)
			box(Rect2(39, 77, 34, 23), Color("e4bf78"), 2)
			draw_line(Vector2(57, 69), Vector2(55, 84), INK, 1, true)
			draw_string(HAND, Vector2(26, 121), "keep the trait", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		"investor":
			crate(Vector2(57, 68))
			box(Rect2(35, 17, 44, 52), Color("f5efd9"), 2)
			for y in [33, 42, 51]: draw_line(Vector2(42, y), Vector2(70,y+1), LEAF, 1.4, true)
			draw_circle(Vector2(60, 58), 6, Color("b76c50"))
			draw_string(HAND, Vector2(28, 112), "get it in ink", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		"gambler":
			spud(Vector2(33, 35), 1.05)
			box(Rect2(45, 38, 43, 43), Color("b7a294"), 5)
			for point in [Vector2(56,49),Vector2(77,70),Vector2(66,59)]: draw_circle(point, 3, INK)
			draw_line(Vector2(26, 88), Vector2(90, 86), INK, 1, true)
			draw_string(HAND, Vector2(23, 112), "half can go", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)

func _compact_story() -> void:
	_specimen()
	var steps: Array = {
		"farmer": ["Plant a crop", "Add 1 compost", "Water, grow, harvest"],
		"industrialist": ["Load harvested crops", "Match the process", "Grade " + grade],
		"scientist": ["10 + 10 harvested crops", "Crossbreed", "Keep the planting trait"],
		"investor": ["Reserve a price", "Fill the order", "Deliver for coins"],
		"gambler": ["Choose a stake", "Reveal the result", "Claim or use a charm"],
	}[kind]
	for index in range(3):
		var y: float = 36 + index * 29
		label(Vector2(113, y), str(index + 1), LEAF, 12)
		label(Vector2(132, y), str(steps[index]), INK, 14)
		if index < 2: draw_line(Vector2(132, y + 10), Vector2(309, y + 10), Color("b5b6a0"), 1, true)

func _draw() -> void:
	base_transform()
	if specimen:
		_specimen()
		return
	if compact_layout or size.x < 440:
		_compact_story()
		return
	# One continuous sheet replaces the three interchangeable cream cards.
	draw_line(Vector2(13, 117), Vector2(607, 117), Color("b0b19a"), 1, true)
	for index in range(3):
		var left: int = 8 + index * 206
		label(Vector2(left + 2, 22), "%02d" % (index + 1), Color("79866b"), 11)
		for mark in range(3): draw_line(Vector2(left + 28 + mark * 7, 16), Vector2(left + 32 + mark * 7, 16), Color("b2b59e"), 1, true)
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
			# The compost sack has been patched, as at Mara’s stall.
			box(Rect2(255,69,14,12), Color("708067"), 1)
			for stitch in [0,5,10]: draw_line(Vector2(255+stitch,70),Vector2(257+stitch,73),Color("e5d6ae"),1,true)
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
		draw_line(Vector2(x-10,76),Vector2(x+3,76),INK,1.5,true)
		draw_polyline(PackedVector2Array([Vector2(x-2,71),Vector2(x+3,76),Vector2(x-2,81)]),INK,1.5,true)
