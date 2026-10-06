extends RefCounted
## Shared paper stamps. Type is sized in logical UI pixels, then fitted for phones.
const Place = preload("res://scripts/place_ui.gd")
const Type = preload("res://scripts/ui_type.gd")
const COLORS := {"Table": Color("7a5a12"), "Standard": Color("2f5a3e"), "Feed": Color("6f3f2c")}
const FILLS := {"Table": Color("fbe6a6"), "Standard": Color("d9e8cf"), "Feed": Color("ecd3c3")}
const GLOSSES := {"Table": "best, sells for more", "Standard": "normal", "Feed": "damaged, half price"}
static func chip(grade: String, pressed: bool = false) -> StyleBoxFlat:
	var skin := preload("res://scripts/cozy_ui.gd").box(FILLS[grade].darkened(.04) if pressed else FILLS[grade], 6, 999, COLORS[grade])
	skin.set_border_width_all(2)
	return skin
static func apply(control: Control, grade: String, pixels: int = 22) -> void:
	control.set_meta("grade_stamp", grade)
	control.set_meta("kit_type", true)
	var font := Type.face(Type.BODY, 750)
	font.fallbacks = []
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", pixels)
	var ink: Color = COLORS[grade]
	if control is Button:
		for state in ["normal", "hover", "pressed", "disabled"]:
			control.add_theme_stylebox_override(state, chip(grade, state == "pressed"))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: control.add_theme_color_override(state, ink)
		control.add_theme_stylebox_override("focus", chip(grade))
	else:
		control.add_theme_stylebox_override("normal", chip(grade))
		control.add_theme_color_override("font_color", ink)
		if control is Label: control.autowrap_mode = TextServer.AUTOWRAP_OFF
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
