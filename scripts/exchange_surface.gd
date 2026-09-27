extends PanelContainer
## Painted stall surfaces and readable chalkboards, with light baked once per palette.
var chalkboard: bool = false
var soft: bool = false
static var _light_textures: Dictionary = {}

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	if soft: return
	var edge := Color("795a3c")
	if chalkboard:
		# The ledge holds the chalk. The middle stays clean for the live quote.
		draw_line(Vector2(8, size.y - 7), Vector2(size.x - 8, size.y - 7), edge, 5, true)
		draw_line(Vector2(size.x - 44, size.y - 11), Vector2(size.x - 24, size.y - 12), Color("eee7cf"), 4, true)
		draw_line(Vector2(18, 10), Vector2(44, 11), Color("bdc9ad", 0.16), 2, true)
	else:
		for y: float in [7.0, size.y - 8.0]:
			draw_line(Vector2(5, y), Vector2(size.x - 5, y), edge, 3, true)
		# Short grain marks along the counter lip, not underneath any text.
		for index: int in range(4):
			var start := 29.0 + float(index) * (size.x - 60.0) / 4.0
			draw_line(Vector2(start, size.y - 15), Vector2(start + 22, size.y - 14), Color(edge, 0.28), 1, true)
	for point: Vector2 in [Vector2(9, 8), Vector2(size.x - 9, 8), Vector2(9, size.y - 8), Vector2(size.x - 9, size.y - 8)]:
		draw_circle(point, 2.1, Color("544c3e"), true, -1, true)
		draw_line(point - Vector2(1, 0), point + Vector2(1, 0), Color("d0bc92"), 1, true)


static func soft_skin(base: Color, glow: Color, secondary: Color = Color.TRANSPARENT, padding: int = 20, radius: int = 24) -> StyleBoxTexture:
	# One small cached texture supplies the blended light. Nine-patch margins
	# preserve rounded corners at every shop size without a per-frame shader.
	var key := "%s:%s:%s:%d" % [base.to_html(), glow.to_html(), secondary.to_html(), radius]
	if not _light_textures.has(key):
		var other: Color = base if secondary.a == 0.0 else secondary
		var source := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><defs><linearGradient id="base" x2="0.7" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient><radialGradient id="light" cx="0.16" cy="0.05" r="0.92"><stop stop-color="#%s" stop-opacity="0.38"/><stop offset="1" stop-color="#%s" stop-opacity="0"/></radialGradient></defs><rect x="0.75" y="0.75" width="254.5" height="254.5" rx="%d" fill="url(#base)"/><rect x="0.75" y="0.75" width="254.5" height="254.5" rx="%d" fill="url(#light)"/><rect x="0.75" y="0.75" width="254.5" height="254.5" rx="%d" fill="none" stroke="#%s" stroke-opacity="0.28" stroke-width="1.5"/></svg>' % [base.to_html(false), other.to_html(false), glow.to_html(false), glow.to_html(false), radius, radius, radius, glow.to_html(false)]
		var light := Image.new()
		light.load_svg_from_string(source)
		_light_textures[key] = ImageTexture.create_from_image(light)
	var skin := StyleBoxTexture.new()
	skin.texture = _light_textures[key]
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(edge, radius + 2)
		skin.set_content_margin(edge, padding)
	return skin

static func apply_modal_lighting(modal: PanelContainer, base: Color, glow: Color, secondary: Color = Color.TRANSPARENT) -> void:
	var previous: StyleBox = modal.get_theme_stylebox("panel")
	var skin: StyleBoxTexture = soft_skin(base, glow, secondary, 24, 30)
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_content_margin(edge, previous.get_content_margin(edge))
	modal.add_theme_stylebox_override("panel", skin)
