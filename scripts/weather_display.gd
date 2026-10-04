extends Control
## Painted weather and equipment sketches; the same ink as the seed packets.
var kind: String = "radar"
var phase: String = "calm"
const CYAN := Color("5a93a4")
const DIM := Color("17382d")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var extent: float = minf(size.x, size.y)
	if kind == "radar":
		preload("res://scripts/item_icon.gd").paint(self, {"kind":"place", "id":"forecast"}, Rect2(Vector2.ZERO, size))
		return
	draw_set_transform((size - Vector2.ONE * extent) * 0.5, 0, Vector2.ONE * extent / 100.0)
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
	elif kind == "frost":
		for x in [28, 70]: draw_arc(Vector2(x, 72), 25, PI, TAU, 24, CYAN, 2, true)
		draw_rect(Rect2(3, 47, 92, 25), Color(CYAN, 0.25))
		draw_line(Vector2(3,72), Vector2(95,72), CYAN, 2, true)
	else:
		for x in [45,64,83]:
			draw_line(Vector2(x,77),Vector2(x,22),CYAN,2,true)
			draw_polyline(PackedVector2Array([Vector2(x-11,46),Vector2(x,22),Vector2(x+11,46)]),CYAN,2,true)
		for y in [36,52,68]: draw_line(Vector2(7,y),Vector2(32,y),DIM,2,true)
func _tank_skin() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("b2c8be")
	skin.border_color = CYAN
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(8)
	return skin
