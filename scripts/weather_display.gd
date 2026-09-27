extends Control
## Vector instruments shared by the forecast console and equipment modules.
var kind: String = "radar"
var phase: String = "calm"
var clock: float = 0.0
const CYAN := Color("63dced")
const DIM := Color("244b60")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_visible_in_tree() or kind != "radar": return
	clock += delta
	queue_redraw()
func _draw() -> void:
	var extent: float = minf(size.x, size.y)
	draw_set_transform((size - Vector2.ONE * extent) * 0.5, 0, Vector2.ONE * extent / 100.0)
	if kind == "radar":
		var center := Vector2(50, 50)
		for radius: float in [16.0, 30.0, 44.0]: draw_arc(center, radius, 0, TAU, 80, DIM, 0.7, true)
		for angle: float in [0.0, PI / 2, PI, PI * 1.5]:
			draw_line(center + Vector2.from_angle(angle) * 4, center + Vector2.from_angle(angle) * 44, DIM, 0.7, true)
		for i in range(40):
			var a: float = clock * 0.55 - i * 0.015
			draw_line(center, center + Vector2.from_angle(a) * 43, Color(CYAN, 0.2 * (1.0 - i / 40.0)), 1, true)
		draw_line(center, center + Vector2.from_angle(clock * 0.55) * 44, CYAN, 1.2, true)
		for point: Vector2 in [Vector2(28, 35), Vector2(66, 59), Vector2(42, 77)]:
			draw_circle(point, 2, CYAN if phase == "calm" else Color("ffbb69"))
		draw_circle(center, 3, CYAN)
		return
	if kind == "irrigation":
		draw_polyline(PackedVector2Array([Vector2(15,70),Vector2(15,50),Vector2(85,50),Vector2(85,70)]), CYAN, 2, true)
		for x in [15,50,85]:
			draw_line(Vector2(x,70), Vector2(x,35), CYAN, 2, true)
			draw_arc(Vector2(x,35),15,PI,TAU,24,CYAN,1.5,true)
			draw_circle(Vector2(x,70),4,DIM)
	elif kind == "rainwater":
		draw_style_box(_tank_skin(), Rect2(23,16,54,68))
		draw_rect(Rect2(29,45,42,32),Color(CYAN,0.35))
		for y in [28,40,52,64]: draw_line(Vector2(65,y),Vector2(73,y),CYAN,1,true)
		draw_polyline(PackedVector2Array([Vector2(77,69),Vector2(89,69),Vector2(89,85)]),CYAN,3,true)
	elif kind == "drainage":
		for y in [22,40,58]: draw_line(Vector2(12,y),Vector2(49,75),DIM,5,true)
		draw_polyline(PackedVector2Array([Vector2(49,16),Vector2(49,76),Vector2(89,76)]),CYAN,3,true)
		draw_line(Vector2(79,67),Vector2(89,76),CYAN,2,true)
		draw_line(Vector2(79,85),Vector2(89,76),CYAN,2,true)
	elif kind == "barn":
		draw_polyline(PackedVector2Array([Vector2(12,38),Vector2(50,14),Vector2(88,38)]),CYAN,2,true)
		draw_rect(Rect2(21,38,58,47),CYAN,false,2)
		for y in [46,55,64,73]: draw_line(Vector2(29,y),Vector2(71,y),CYAN,2,true)
	else:
		for x in [45,64,83]:
			draw_line(Vector2(x,77),Vector2(x,22),CYAN,2,true)
			draw_polyline(PackedVector2Array([Vector2(x-11,46),Vector2(x,22),Vector2(x+11,46)]),CYAN,2,true)
		for y in [36,52,68]: draw_line(Vector2(7,y),Vector2(32,y),DIM,2,true)
func _tank_skin() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("102c41")
	skin.border_color = CYAN
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(8)
	return skin
