extends PanelContainer
## Felt, brass and warm marquee bulbs for the Roll House interior.
var kind: String = "felt"
var _clock: float = 0
var _redraw_clock: float = 0

func configure(style_kind: String) -> void:
	kind = style_kind
	var style := StyleBoxFlat.new()
	style.bg_color = Color("8c2335") if kind == "reel" else Color("184d3a")
	style.border_color = Color("e5bb57")
	style.set_border_width_all(3 if kind == "reel" else 2)
	style.set_corner_radius_all(15)
	var inset: float = 20 if kind == "reel" else 14
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	add_theme_stylebox_override("panel", style)

func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(kind == "reel")

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock += delta
	_redraw_clock += delta
	if _redraw_clock >= .08:
		_redraw_clock = 0
		queue_redraw()

func _draw() -> void:
	if kind == "reel":
		var count: int = maxi(3, int((size.x - 24) / 25))
		for i in range(count + 1):
			var x: float = lerpf(12, size.x - 12, float(i) / count)
			var glow: float = .68 + .25 * sin(_clock * 2.5 + i * .8)
			for y: float in [10, size.y - 10]:
				draw_circle(Vector2(x, y), 6.5, Color(1, .7, .25, glow * .15))
				draw_circle(Vector2(x, y), 3.3, Color(1, .87, .49, glow))
		for side: float in [10, size.x - 10]:
			for i in range(1, 6):
				draw_circle(Vector2(side, lerpf(10, size.y - 10, i / 6.0)), 3.3, Color("fbe29d"))
	else:
		for y in range(18, int(size.y) - 12, 22):
			for x in range(18, int(size.x) - 12, 24):
				draw_line(Vector2(x, y), Vector2(x + 3, y - 2), Color(1, 1, .8, .04), 1)
