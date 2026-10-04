extends RefCounted
## Shared paper stamps. Type is sized in logical UI pixels, then fitted for phones.
const Place = preload("res://scripts/place_ui.gd")
const Type = preload("res://scripts/ui_type.gd")
const COLORS := {"Table": Color("986817"), "Standard": Place.INK, "Feed": Color("86684f")}
static func apply(control: Control, grade: String, pixels: int = 22) -> void:
	control.set_meta("grade_stamp", grade)
	control.add_theme_font_override("font", Type.face(Type.BODY, 750))
	control.add_theme_font_size_override("font_size", pixels)
	var ink: Color = COLORS[grade]
	if control is Button:
		for state in ["normal", "hover", "pressed", "disabled"]:
			control.add_theme_stylebox_override(state, Place.skin(Place.PAPER.darkened(.04) if state == "pressed" else Place.PAPER, 6, 4, ink))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: control.add_theme_color_override(state, ink)
		control.add_theme_stylebox_override("focus", Place.skin(Place.PAPER, 6, 4, ink))
	else:
		control.add_theme_stylebox_override("normal", Place.skin(Place.PAPER, 6, 4, ink))
		control.add_theme_color_override("font_color", ink)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
