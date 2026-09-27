extends Control
var burning: bool = false
var clock: float = 0.0
func _ready() -> void:
	custom_minimum_size = Vector2(0, 164)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()
func _draw() -> void:
	if size.x < 100 or size.y < 100: return
	var c := Vector2(size.x * 0.5, size.y - 12)
	# A low, broad brick hearth with copper hood and a banked fire.
	draw_style_box(_skin(Color("38231e"), 18), Rect2(Vector2.ZERO, size))
	for side: float in [-1.0, 1.0]:
		var lamp := Vector2(c.x + side * minf(180, size.x * 0.39), 47)
		draw_circle(lamp, 22, Color(1, 0.61, 0.24, 0.08))
		draw_line(lamp - Vector2(0, 47), lamp, Color("886047"), 3)
		draw_style_box(_skin(Color("ffcf79"), 6), Rect2(lamp - Vector2(8, 10), Vector2(16, 23)))
	var width: float = minf(116, size.x * 0.28)
	for row in range(3):
		for side: float in [-1, 1]:
			draw_style_box(_skin(Color("a46146") if row % 2 == 0 else Color("8d4d39"), 3), Rect2(c + Vector2(side * width - 17, -28 - row * 30), Vector2(34, 28)))
	draw_style_box(_skin(Color("170f10"), 25), Rect2(c + Vector2(-width + 17, -103), Vector2(width * 2 - 34, 96)))
	draw_polygon(PackedVector2Array([c + Vector2(-width - 10, -108), c + Vector2(-width + 18, -143), c + Vector2(width - 18, -143), c + Vector2(width + 10, -108)]), PackedColorArray([Color("c78a56")]))
	draw_line(c + Vector2(-width - 9, -106), c + Vector2(width + 9, -106), Color("efbd7d"), 4)
	for index in range(5):
		var x: float = (index - 2) * width * 0.25
		var height: float = (53 if burning else 31) + sin(clock * 4 + index * 1.7) * 8
		var tip := c + Vector2(x + sin(clock * 2 + index) * 5, -height - 16)
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 16, -16), tip, c + Vector2(x + 15, -16)]), Color("e67834"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 8, -16), tip.lerp(c + Vector2(x, -16), 0.3), c + Vector2(x + 8, -16)]), Color("ffcf73"))
	for index in range(3):
		var start := c + Vector2(-width * 0.65, -10 - index * 4)
		draw_line(start, c + Vector2(width * 0.65, -15 + index * 4), Color("663a27"), 7, true)
	draw_line(c + Vector2(-width - 25, 0), c + Vector2(width + 25, 0), Color("c39268"), 7, true)
func _skin(color: Color, radius: int) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.set_corner_radius_all(radius)
	return skin
