extends RefCounted
## Shared surfaces and interaction states for the farm's illustrated menus.
const INK: Color = Color("17382d")
const GREEN: Color = Color("377858")
const CREAM: Color = Color("fffbed")
const WOOD: Color = Color("79553d")
static var _paper_textures: Dictionary = {}

static func paper(fill: Color = CREAM, padding: int = 14, radius: int = 4, edge: Color = Color("c9bea0")) -> StyleBoxTexture:
	# One material for every sheet, board and painted frame. Build each 64 px
	# swatch once; nine-slice tiling keeps its grain and inner edge at 1 px.
	var curve: int = 12 if padding >= 8 else clampi(radius, 0, 30)
	var key: String = "%s:%s:%d" % [fill.to_html(), edge.to_html(), curve]
	if not _paper_textures.has(key):
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var hash_value: int = (x * 73 + y * 151 + x * y * 11) % 31
				var grain: float = (float(hash_value) / 30.0 - .5) * .025
				if fill == WOOD: grain += sin(float(y) * .8 + sin(float(x) * .12)) * .018
				var pixel: Color = fill.lightened(grain) if grain >= 0 else fill.darkened(-grain)
				var distance: int = mini(mini(x, 63 - x), mini(y, 63 - y))
				if distance == 0: pixel = edge if edge.a > 0 else fill.darkened(.2)
				elif distance == 1: pixel = fill.darkened(.13)
				elif distance == 2: pixel = fill.lightened(.035)
				if curve > 0:
					var corner := Vector2(clampf(x, curve, 63 - curve), clampf(y, curve, 63 - curve))
					pixel.a *= clampf(float(curve) + .5 - Vector2(x, y).distance_to(corner), 0, 1)
				image.set_pixel(x, y, pixel)
		_paper_textures[key] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = _paper_textures[key]
	style.set_texture_margin_all(maxi(8, curve))
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.set_content_margin_all(padding)
	style.set_meta("surface_fill", fill)
	style.set_meta("surface_material", "wood" if fill == WOOD else ("ink" if fill == INK else "paper"))
	return style

static func box(color: Color, padding: int = 14, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	return style

static func surface(_kind: String, accent: Color = GREEN, selected: bool = false) -> StyleBoxTexture:
	return paper(CREAM, 14, 12, accent if selected else Color("c9bea0"))

static func modal(_dark: bool = false) -> StyleBoxTexture:
	return paper(INK, 24, 12, WOOD)

static func button_style(state: String, primary: bool) -> StyleBoxFlat:
	var fill: Color = GREEN if primary else Color("f9f7e9")
	var border: Color = Color("24563e") if primary else Color("bdc8b0")
	match state:
		"hover": fill = Color("3d805b") if primary else Color("e5eddc")
		"pressed": fill = Color("254e39") if primary else Color("d4dfc9")
		"disabled":
			fill = Color("e7e7dc")
			border = Color("d3d7c7")
	var style := box(fill, 10, 999, border)
	style.border_width_bottom = 1 if state in ["pressed", "disabled"] else 3
	# Reserve the same space in every state to prevent layout movement.
	style.content_margin_bottom = 11
	style.content_margin_top = 9
	if state == "pressed":
		style.content_margin_bottom = 9
		style.content_margin_top = 11
	return style

static func badge(label: Label, text: String, tone: String = "neutral") -> void:
	var palettes: Dictionary = {
		"active": [Color("dcebd7"), Color("285b38")],
		"ready": [Color("f7e4aa"), Color("715017")],
		"locked": [Color("e9e4da"), Color("72644e")],
		"warning": [Color("f2dfd2"), Color("884b37")],
		"neutral": [Color("e5e9dd"), Color("50634f")],
	}
	var colors: Array = palettes.get(tone, palettes.neutral)
	label.text = text
	label.add_theme_color_override("font_color", colors[1])
	var style := box(colors[0], 7, 999)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", style)

static func toggle_texture(enabled: bool) -> ImageTexture:
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="42" height="24"><rect x="1" y="1" width="40" height="22" rx="11" fill="%s" stroke="%s"/><circle cx="%d" cy="12" r="8" fill="#fffbed"/></svg>' % ["#377858" if enabled else "#929e89", "#24563e" if enabled else "#7b8873", 30 if enabled else 12]
	var image := Image.new()
	image.load_svg_from_string(svg, 2.0)
	image.resize(42, 24, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
