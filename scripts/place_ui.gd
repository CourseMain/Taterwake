extends RefCounted
## The shared paper, pill and keeper details; each place supplies its own object.
const Cozy = preload("res://scripts/cozy_ui.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const PAPER := Kit.PAPER
const INK := Cozy.INK
const WOOD := Cozy.WOOD
const MUTED := Kit.MUTED
const Type = preload("res://scripts/ui_type.gd")
static func skin(fill: Color = PAPER, padding: int = 12, radius: int = 8, edge: Color = Color("d7c9aa")) -> StyleBoxTexture:
	return Cozy.paper(fill, padding, radius, edge)
static func pill(button: Button, accent: Color, primary: bool = false) -> void:
	button.custom_minimum_size.x = maxf(44, button.custom_minimum_size.x)
	button.custom_minimum_size.y = maxf(44, button.custom_minimum_size.y)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = accent if primary else PAPER
		if state == "hover": fill = fill.lightened(.08)
		if state == "pressed": fill = fill.darkened(.07)
		if state == "disabled": fill = Color("e6dfcd")
		button.add_theme_stylebox_override(state, Cozy.box(fill, 10, 999, accent if primary else Color("cfc3aa")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("focus", Cozy.box(Color.TRANSPARENT, 10, 999, INK))
static func header(hud, parent: Control, title: String, accent: Color, keeper: String = "", line: String = "") -> HBoxContainer:
	hud._modal_title.hide(); hud._modal_subtitle.hide()
	var u: float = Kit.unit(hud)
	var panel := PanelContainer.new(); panel.name = "PlaceHeader"
	panel.add_theme_stylebox_override("panel", Kit.skin(Kit.KEEPERS.get(keeper, accent), Kit.KEEPERS.get(keeper, accent), 10, 12, u, false))
	parent.add_child(panel)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", ceili(12 * u)); panel.add_child(row)
	if not keeper.is_empty():
		var portrait = preload("res://scripts/npc_portrait.gd").new()
		portrait.name = "KeeperPortrait_" + keeper
		portrait.custom_minimum_size = Vector2.ONE * (76 if Kit.desktop(hud) else 56) * u; row.add_child(portrait)
		portrait.set_meta("kit_portrait", true)
		portrait.show_person(keeper); portrait.set_expression(hud._state.NpcRoster.expression(keeper, hud._state, line))
	var words := VBoxContainer.new(); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(words)
	words.add_child(Kit.label(hud, title if keeper.is_empty() else hud._state.NpcRoster.PEOPLE[keeper].name, 22, Kit.CREAM, true))
	if not keeper.is_empty():
		words.add_child(Kit.label(hud, line if not line.is_empty() else hud._state.NpcRoster.service_greeting(keeper, hud._state), 16, Kit.CREAM))
		if hud._tutorial.is_empty():
			var talk: Button = Kit.button(hud, "Talk", "talk:" + keeper, Kit.CREAM)
			talk.set_meta("text_tier", 14)
			talk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for variant in ["normal", "hover", "pressed", "disabled"]: talk.add_theme_stylebox_override(variant, Kit.skin(Kit.CREAM, Kit.CREAM, 6, 999, u, false))
			row.add_child(talk)
	return row
static func tab(button: Button, selected: bool) -> void:
	# Navigation stays cream; ink outlines identify the visible shelf or board.
	pill(button, INK)
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	var active := Cozy.box(Color("e9e6d5"), 10, 999, INK)
	active.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed", active)
static func help(hud, parent: Control, words: String) -> Button:
	var button: Button = Kit.button(hud, "?", "", Kit.PAPER) if hud._modal_card.get_meta("kit_screen", false) else hud._button("?", "")
	button.tooltip_text = words
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(44, 44) * Kit.unit(hud) if hud._modal_card.get_meta("kit_screen", false) else Vector2(44, 44)
	pill(button, INK)
	parent.add_child(button)
	button.pressed.connect(func():
		var dialog := AcceptDialog.new()
		dialog.title = "Field notes"; dialog.dialog_text = words; dialog.dialog_autowrap = true
		dialog.borderless = true; dialog.exclusive = true
		dialog.get_ok_button().set_script(preload("res://scripts/illustrated_button.gd"))
		var font := Type.face(Type.BODY, 500); font.fallbacks = [Type.SPUDION]
		dialog.add_theme_font_override("font", font)
		dialog.add_theme_font_size_override("font_size", 22)
		dialog.get_label().add_theme_font_override("font", font)
		dialog.get_label().add_theme_font_size_override("font_size", 22)
		dialog.get_label().add_theme_color_override("font_color", INK)
		dialog.get_ok_button().text = "Close"
		dialog.get_ok_button().add_theme_font_override("font", font)
		dialog.get_ok_button().add_theme_font_size_override("font_size", 22)
		dialog.add_theme_stylebox_override("panel", skin())
		dialog.get_ok_button().custom_minimum_size = Vector2(hud.touch_target(), hud.touch_target())
		pill(dialog.get_ok_button(), INK)
		# AcceptDialog resets the button minimum while laying out its children.
		# Put the required height in the pill’s margins as well.
		var padding: float = maxf(10, ceilf((hud.touch_target() - font.get_height(22)) / 2))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = dialog.get_ok_button().get_theme_stylebox(state).duplicate()
			style.content_margin_top = padding; style.content_margin_bottom = padding
			dialog.get_ok_button().add_theme_stylebox_override(state, style)
		dialog.get_ok_button().refresh_picture()
		hud.root.add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(mini(480, int(hud.root.size.x) - 32), 240))
	)
	return button
static func pips(level: int, count: int = 3) -> String:
	return "●".repeat(clampi(level, 0, count)) + "○".repeat(maxi(0, count - level))
static func compact(parent: Node) -> void:
	for node in parent.find_children("*", "Control", true, false):
		if not (node is Label or node is Button): continue
		var existing: Font = node.get_theme_font("font")
		var source: Font = Type.DISPLAY if existing is FontVariation and existing.base_font == Type.DISPLAY else Type.BODY
		var signature := str([source.get_instance_id(), Type.uses_symbols(node.text)])
		if node.has_meta("compact_font") and node.get_meta("compact_font") == existing and node.get_meta("compact_font_signature", "") == signature: continue
		var font: FontVariation = Type.face(source, 650 if node is Button else 500)
		font.fallbacks = [Type.SPUDION, Type.SYMBOLS, Type.SYMBOLS_2] if Type.uses_symbols(node.text) else [Type.SPUDION]
		node.set_meta("compact_font", font)
		node.set_meta("compact_font_signature", signature)
		node.add_theme_font_override("font", font)
