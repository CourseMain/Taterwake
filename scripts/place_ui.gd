extends RefCounted
## The shared paper, pill and keeper details; each place supplies its own object.
const PAPER := Color("fff8e7")
const INK := Color("34362c")
const MUTED := Color("786c56")
const Type = preload("res://scripts/ui_type.gd")
static func skin(fill: Color = PAPER, padding: int = 12, radius: int = 8, edge: Color = Color("d7c9aa")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill; s.border_color = edge
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: s.set_content_margin(side, padding)
	return s
static func pill(button: Button, accent: Color, primary: bool = false) -> void:
	button.custom_minimum_size.y = maxf(44, button.custom_minimum_size.y)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = accent if primary else PAPER
		if state == "hover": fill = fill.lightened(.08)
		if state == "pressed": fill = fill.darkened(.07)
		if state == "disabled": fill = Color("e6dfcd")
		button.add_theme_stylebox_override(state, skin(fill, 10, 100, accent if primary else Color("cfc3aa")))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: button.add_theme_color_override(state, PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("focus", skin(Color.TRANSPARENT, 10, 100, INK))
static func header(hud, parent: Control, title: String, accent: Color, keeper: String = "") -> HBoxContainer:
	hud._modal_title.hide(); hud._modal_subtitle.hide()
	var panel := PanelContainer.new()
	panel.name = "PlaceHeader"
	panel.add_theme_stylebox_override("panel", skin(accent, 12, 3, accent))
	parent.add_child(panel)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); panel.add_child(row)
	var label: Label = hud._wrap(title, 27, PAPER, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	if not keeper.is_empty():
		var portrait = preload("res://scripts/npc_portrait.gd").new()
		portrait.name = "KeeperPortrait_" + keeper
		portrait.custom_minimum_size = Vector2(52, 64); row.add_child(portrait)
		portrait.show_person(keeper)
	return row
static func help(hud, parent: Control, words: String) -> Button:
	var button: Button = hud._button("?", "")
	button.tooltip_text = words
	button.custom_minimum_size = Vector2(44, 44)
	pill(button, INK)
	parent.add_child(button)
	button.pressed.connect(func():
		var dialog := AcceptDialog.new()
		dialog.title = "Field notes"; dialog.dialog_text = words
		dialog.add_theme_stylebox_override("panel", skin())
		dialog.get_ok_button().custom_minimum_size.y = hud.touch_target()
		hud.root.add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(mini(480, hud.get_tree().root.size.x - 24), 180))
	)
	return button
static func pips(level: int, count: int = 3) -> String:
	return "●".repeat(clampi(level, 0, count)) + "○".repeat(maxi(0, count - level))
