extends Button
## Pictures sit above the existing caption, within the same single hit target.
## Native Button text, focus, disabled state and accessibility remain intact.
const Art = preload("res://scripts/item_icon.gd")
var picture: Dictionary = {}
var picture_pixels: float = 32.0
var picture_scale: float = 1.0
var _signature: String = ""
var _fitting: bool = false

func _ready() -> void:
	resized.connect(queue_redraw)
	refresh_picture()

func _process(_delta: float) -> void:
	if is_visible_in_tree(): refresh_picture()

func has_picture() -> bool:
	return not get_meta("plain_control", false) and not text.is_empty() and text not in ["×", "?", "E", "+", "−", "←", "→"] and not text.is_valid_float() and not text.begins_with("×")

func refresh_picture() -> void:
	fit_picture(self)

func _draw() -> void:
	paint_picture(self)

static func fit_picture(button: Button) -> void:
	if button._fitting: return
	button._fitting = true
	var pixels: float = button.picture_pixels / maxf(.1, button.picture_scale) if button.has_picture() else 0.0
	var signature: String = button.text + str(button.picture) + str(pixels)
	for variant in ["normal", "hover", "pressed", "disabled"]:
		var skin: StyleBox = button.get_theme_stylebox(variant)
		if not button.has_theme_stylebox_override(variant):
			skin = skin.duplicate()
			button.add_theme_stylebox_override(variant, skin)
		if not skin.has_meta("caption_top"): skin.set_meta("caption_top", skin.content_margin_top)
		var top: float = float(skin.get_meta("caption_top")) + (pixels + 3.0 / maxf(.1, button.picture_scale) if pixels > 0 else 0.0)
		if not is_equal_approx(skin.content_margin_top, top): skin.content_margin_top = top
	if button._signature != signature:
		button._signature = signature
		button.queue_redraw()
	button._fitting = false

static func paint_picture(button: Button) -> void:
	if not button.has_picture(): return
	var side: float = button.picture_pixels / maxf(.1, button.picture_scale)
	var skin: StyleBox = button.get_theme_stylebox("pressed" if button.is_pressed() else "normal")
	var top: float = float(skin.get_meta("caption_top", 3.0))
	var data: Dictionary = button.picture if not button.picture.is_empty() else Art.control_picture(str(button.get_meta("action", "")), button.text)
	Art.paint(button, data, Rect2((button.size.x-side)*.5, top, side, side))
