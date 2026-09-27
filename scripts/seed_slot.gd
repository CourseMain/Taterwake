extends Button
## A seed packet label with two ruled inventory compartments.
const Type = preload("res://scripts/ui_type.gd")
const Icon = preload("res://scripts/item_icon.gd")
const INK := Color("3e3023")
const RULE := Color("94764d")
const PAPER := Color("edcf98")
var seed_count: Label
var barn_count: Label
var crop_id: String
var selected: bool = false
var _hud
var _touch: bool = false

func setup(hud, id: String, touch: bool = false) -> void:
	_hud = hud
	crop_id = id
	_touch = touch
	text = ""
	set_meta("hud_action", "crop:" + id)
	set_meta("action", "crop:" + id)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(158, 114 if touch else 84)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10 if touch else 7)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 7)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var packet := Icon.new()
	packet.item = {"kind": "seed", "crop": id, "backdrop": PAPER.to_html(false)}
	packet.custom_minimum_size = Vector2(40, 40) if touch else Vector2(30, 30)
	heading.add_child(packet)
	var name_label := _label(hud._crop_name(id), 20 if touch else 14, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name_label)
	heading.add_child(_label("%ds" % hud._crop_grow(id), 16 if touch else 11))
	var rule := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = RULE
	line.thickness = 2
	rule.add_theme_stylebox_override("separator", line)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var quantities := HBoxContainer.new()
	quantities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantities.add_theme_constant_override("separation", 8)
	column.add_child(quantities)
	seed_count = _quantity(quantities, "Seeds")
	var divider := VSeparator.new()
	var vertical := StyleBoxLine.new()
	vertical.vertical = true
	vertical.color = RULE
	vertical.thickness = 2
	divider.add_theme_stylebox_override("separator", vertical)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantities.add_child(divider)
	barn_count = _quantity(quantities, "In barn")
	refresh(0, 0, false)

func _label(words: String, pixels: int, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_override("font", Type.face(Type.BODY, 800 if bold else 650))
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

func _quantity(parent: HBoxContainer, caption: String) -> Label:
	var cell := HBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	parent.add_child(cell)
	var name_label := _label(caption, 17 if _touch else 11)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(name_label)
	var value := _label("0", 22 if _touch else 16, true)
	cell.add_child(value)
	return value

func refresh(seeds: int, held: int, active: bool) -> void:
	seed_count.text = _hud._number(seeds)
	barn_count.text = _hud._number(held)
	tooltip_text = "%s: %s seeds, %s potatoes in barn. %ds to grow." % [_hud._crop_name(crop_id), seed_count.text, barn_count.text, _hud._crop_grow(crop_id)]
	if has_meta("styled") and active == selected: return
	selected = active
	set_meta("styled", true)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("f5e2b9") if state == "hover" else (Color("d9b97d") if state == "pressed" else PAPER)
		skin.border_color = INK if active else RULE
		skin.set_border_width_all(2 if active else 1)
		skin.border_width_top = 5 if active else 1
		skin.set_corner_radius_all(3)
		skin.shadow_color = Color("503e29")
		skin.shadow_offset = Vector2(0, 2)
		skin.shadow_size = 1
		add_theme_stylebox_override(state, skin)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("bd582f")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(3)
	add_theme_stylebox_override("focus", focus)
