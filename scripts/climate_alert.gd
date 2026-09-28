extends Control
signal continue_requested
const Type = preload("res://scripts/ui_type.gd")
var title: Label
var message: Label
var footer: Label
var action: Button
var panel: PanelContainer
var shade: ColorRect
var remaining: float = 0.0
var introduction: bool = false
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	shade = ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.11, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -165
	panel.offset_bottom = 165
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172c38")
	style.border_color = Color("dda965")
	style.border_width_left = 7
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var kicker := text("GOLDEN SHORES / CLIMATE ALERT", 13, Color("e6b578"))
	column.add_child(kicker)
	title = text("", 48, Color("fff2d9"), true)
	column.add_child(title)
	message = text("", 21, Color("d9e6e9"))
	column.add_child(message)
	footer = text("", 15, Color("e6b578"))
	column.add_child(footer)
	action = Button.new()
	action.text = "I'M READY · PROTECT MY FARM"
	action.custom_minimum_size.y = 48
	action.add_theme_font_override("font", Type.face(Type.DISPLAY))
	action.add_theme_font_size_override("font_size", 18)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("e6b578")
	button_style.set_corner_radius_all(5)
	for state in ["normal", "hover", "pressed"]: action.add_theme_stylebox_override(state, button_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: action.add_theme_color_override(state, Color("172c38"))
	column.add_child(action)
	action.pressed.connect(func() -> void: dismiss(); continue_requested.emit())
	hide()
	set_process(false)

func text(value: String, size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Type.face(Type.EDITORIAL, 650) if display else Type.face(Type.BODY, 600))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func present(kind: String, info: Dictionary, farm) -> void:
	# The field card already explains recovery; keep the player's view on the farm.
	if kind == "recovery":
		dismiss()
		return
	introduction = kind == "introduction"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER if introduction else Control.PRESET_CENTER_TOP)
	panel.offset_left = -350 if introduction else -220
	panel.offset_right = 350 if introduction else 220
	panel.offset_top = -165 if introduction else 108
	panel.offset_bottom = 165 if introduction else 190
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.content_margin_top = 24 if introduction else 10
	style.content_margin_bottom = 24 if introduction else 10
	style.content_margin_left = 32 if introduction else 16
	style.content_margin_right = 32 if introduction else 16
	panel.get_child(0).add_theme_constant_override("separation", 13 if introduction else 4)
	panel.get_child(0).get_child(0).visible = introduction
	title.add_theme_font_size_override("font_size", 48 if introduction else 25)
	message.add_theme_font_size_override("font_size", 21 if introduction else 14)
	footer.visible = introduction
	shade.visible = introduction
	action.visible = introduction
	mouse_filter = Control.MOUSE_FILTER_STOP if introduction else Control.MOUSE_FILTER_IGNORE
	remaining = 0.0 if introduction else (1.5 if kind == "impact" else 2.8)
	panel.get_child(0).get_child(0).text = "ISLAND %d / A CHANGING CLIMATE" % (farm.current_island if introduction else int(info.island))
	if introduction:
		title.text = "THE WEATHER IS CHANGING"
		message.text = "Storms can destroy your harvest and empty your barn.\nProtect what remains."
		footer.text = "Stock your reserves. Operate equipment. Rescue stressed crops."
	elif kind == "warning":
		title.text = "%s IN %ds" % [info.name, ceili(info.timer)]
		message.text = {"freeze": "Visit the furnace. Heat your hoe before the crops freeze.", "drought": "Save your harvest. The fields are drying out.", "flood": "Harvest now. Floodwater is on its way.", "storm": "Bring in your crops. A violent storm is coming."}.get(info.event, "Prepare your farm.")
		footer.text = "Protect your crops and stored harvest."
	elif kind == "impact":
		title.text = {"freeze": "THE CROPS ARE FREEZING", "drought": "THE FIELDS ARE DRYING", "flood": "THE FLOOD HAS HIT", "storm": "THE STORM HAS HIT"}.get(info.event, info.name)
		message.text = {"freeze": "Heat the hoe at the furnace, then Hoe [1] melts the ice. Frozen crops stop growing.", "drought": "Water reserves are on the line. Water [3] rescues thirsty beds.", "flood": "Puddles are rising. Hoe [1] drains beds; open your gates.", "storm": "Harvest the gold warning row before lightning. Trees shelter the far beds from wind."}.get(info.event, "Protect your harvest.")
		footer.text = "Protect your crops and stored harvest."
	else:
		title.text = "THE WEATHER IS EASING"
		message.text = "Replant. Rebuild. Prepare for the next storm."
		footer.text = "Protect your crops and stored harvest."
	if is_instance_valid(_tween): _tween.kill()
	modulate.a = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	set_process(true)

func dismiss() -> void:
	if is_instance_valid(_tween): _tween.kill()
	introduction = false
	hide()
	set_process(false)

func _process(delta: float) -> void:
	if introduction: return
	remaining -= delta
	modulate.a = clampf(remaining, 0.0, 1.0)
	if remaining <= 0.0: dismiss()
