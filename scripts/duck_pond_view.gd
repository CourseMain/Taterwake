extends Control
## A small living pond for the local flock; no gameplay timers live here.
var count: int = 0
var capacity: int = 1
var _clock: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 156)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock += delta
	queue_redraw()

func _oval(at: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(at, 0, radius)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var shore := StyleBoxFlat.new()
	shore.bg_color = Color("f8eac6")
	shore.set_corner_radius_all(24)
	draw_style_box(shore, Rect2(Vector2.ZERO, size))
	_oval(Vector2(size.x * .5, 84), Vector2(size.x * .46, 53), Color("a2d8df"))
	_oval(Vector2(size.x * .5, 80), Vector2(size.x * .44, 44), Color("bde8e8"))
	for i in range(5):
		var at := Vector2(size.x * (.14 + i * .17), 103 + sin(_clock * 1.6 + i) * 3)
		draw_arc(at, 12, .15, PI - .15, 16, Color("7abcc8"), 2, true)
	for i in range(maxi(1, count)):
		var x: float = size.x * (.5 if count < 2 else (.25 + .5 * i / float(count - 1)))
		var at := Vector2(x, 75 + sin(_clock * 2 + i * 1.8) * 3)
		var feather := Color("fffdf2") if count > 0 else Color("e1ddd2")
		_oval(at + Vector2(0, 27) * 1.3, Vector2(32, 5) * 1.3, Color("89c6cc"))
		_oval(at + Vector2(-7, 7) * 1.3, Vector2(31, 22) * 1.3, feather)
		_oval(at + Vector2(-13, 8) * 1.3, Vector2(16, 12) * 1.3, Color("f2dfaf") if count > 0 else Color("cdc9bf"))
		draw_circle(at + Vector2(14, -13) * 1.3, 26, feather)
		_oval(at + Vector2(34, -7) * 1.3, Vector2(12, 6) * 1.3, Color("eea239"))
		draw_circle(at + Vector2(21, -18) * 1.3, 3.5, Color("343c3d"))
		draw_circle(at + Vector2(22, -19) * 1.3, 1.1, Color.WHITE)
		_oval(at + Vector2(22, -9) * 1.3, Vector2(5, 3) * 1.3, Color("edb4a1"))
		# Small green neckerchief, matching Pip's cap on the farm.
		draw_colored_polygon(PackedVector2Array([at + Vector2(2, -1) * 1.3, at + Vector2(22, 2) * 1.3, at + Vector2(12, 9) * 1.3]), Color("6eaa83"))
	for i in range(maxi(0, capacity - count)):
		_oval(Vector2(size.x - 25 - i * 19, 135), Vector2(6, 9), Color("fffaf0"))
	for at: Vector2 in [Vector2(24, 39), Vector2(size.x - 33, 104)]:
		_oval(at, Vector2(15, 7), Color("81ad73"))
		draw_circle(at + Vector2(1, -3), 4, Color("f4d17c"))
