extends RefCounted
## Shared paper stamps. Type is sized in logical UI pixels, then fitted for phones.
const Place = preload("res://scripts/place_ui.gd")
const Type = preload("res://scripts/ui_type.gd")
const COLORS := {"Table": Color("986817"), "Standard": Place.INK, "Feed": Color("86684f")}
const FILLS := {"Table": Color("f7e4aa"), "Standard": Color("dce8d7"), "Feed": Color("ead5c7")}
const GLOSSES := {"Table": "best, sells for more", "Standard": "normal", "Feed": "damaged, half price"}
static func apply(control: Control, grade: String, pixels: int = 22) -> void:
	control.set_meta("grade_stamp", grade)
	var font := Type.face(Type.BODY, 750)
	font.fallbacks = []
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", pixels)
	var ink: Color = COLORS[grade]
	if control is Button:
		for state in ["normal", "hover", "pressed", "disabled"]:
			control.add_theme_stylebox_override(state, preload("res://scripts/cozy_ui.gd").box(FILLS[grade].darkened(.04) if state == "pressed" else FILLS[grade], 6, 999, ink))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: control.add_theme_color_override(state, ink)
		control.add_theme_stylebox_override("focus", preload("res://scripts/cozy_ui.gd").box(FILLS[grade], 6, 999, ink))
	else:
		control.add_theme_stylebox_override("normal", preload("res://scripts/cozy_ui.gd").box(FILLS[grade], 6, 999, ink))
		control.add_theme_color_override("font_color", ink)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
