extends Control
const Type = preload("res://scripts/ui_type.gd")
var title: Label
var message: Label
var panel: PanelContainer
var remaining: float = 0.0
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
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
	title = text("", 48, Color("fff2d9"), true)
	column.add_child(title)
	message = text("", 21, Color("d9e6e9"))
	column.add_child(message)
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
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = 108
	panel.offset_bottom = 190
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 16
	style.content_margin_right = 16
	panel.get_child(0).add_theme_constant_override("separation", 4)
	title.add_theme_font_size_override("font_size", 25)
	message.add_theme_font_size_override("font_size", 14)
	remaining = 1.5 if kind == "impact" else 2.8
	if kind == "warning":
		title.text = "%s IN %ds" % [info.name, ceili(info.timer)]
		message.text = {"deep_freeze": "Sell stored tonnes and harvest Icecap before impact.", "blizzard": "Bring in Icecap and sell stored tonnes before the blizzard.", "freeze": "Ready your hoe to clear ice from crops.", "drought": "Save your harvest. The fields are drying out.", "flood": "Harvest now. Floodwater is on its way.", "storm": "Bring in your crops. A violent storm is coming."}.get(info.event, "Prepare your farm.")
	elif kind == "impact":
		title.text = {"freeze": "THE CROPS ARE FREEZING", "drought": "THE FIELDS ARE DRYING", "flood": "THE FLOOD HAS HIT", "storm": "THE STORM HAS HIT"}.get(info.event, info.name)
		message.text = {"deep_freeze": "Stored tonnes and Icecap took losses. Covered claims are paid.", "blizzard": "Check the loss notices for barn and Icecap damage.", "freeze": "Hoe [1] clears the ice. Frozen crops stop growing.", "drought": "Water reserves are on the line. Water [3] rescues thirsty beds.", "flood": "Puddles are rising. Hoe [1] drains beds; open your gates.", "storm": "Harvest the gold warning row before lightning. Windbreaks reduce storm losses across the field."}.get(info.event, "Protect your harvest.")
	else:
		title.text = "THE WEATHER IS EASING"
		message.text = "Replant. Rebuild. Prepare for the next storm."
	if is_instance_valid(_tween): _tween.kill()
	modulate.a = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	set_process(true)

func dismiss() -> void:
	if is_instance_valid(_tween): _tween.kill()
	hide()
	set_process(false)

func _process(delta: float) -> void:
	remaining -= delta
	modulate.a = clampf(remaining, 0.0, 1.0)
	if remaining <= 0.0: dismiss()
