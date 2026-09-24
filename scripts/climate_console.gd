extends PanelContainer
signal operated(action: String)
signal opened
const Type = preload("res://scripts/ui_type.gd")
var title: Label
var reserves: Label
var hint: Label
var meter: ProgressBar
var controls: Dictionary = {}

func _ready() -> void:
	name = "ClimateFieldConsole"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -322
	offset_right = -22
	offset_top = 112
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("173632")
	skin.border_color = Color("72c5b6")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(12)
	skin.content_margin_left = 14
	skin.content_margin_right = 14
	skin.content_margin_top = 12
	skin.content_margin_bottom = 12
	add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	title = _label(17, Color("ffe2a3"))
	column.add_child(title)
	reserves = _label(14, Color("e4f3e8"))
	column.add_child(reserves)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 7
	meter.show_percentage = false
	column.add_child(meter)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for id in ["zone", "mode", "burst", "hand", "gates", "shelter"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(132, 30)
		button.add_theme_font_override("font", Type.face(Type.BODY, 600))
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(func() -> void: operated.emit(id))
		grid.add_child(button)
		controls[id] = button
	hint = _label(12, Color("bed9ce"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 260
	column.add_child(hint)
	var more := Button.new()
	more.text = "Equipment & shutters  ›"
	more.pressed.connect(func() -> void: opened.emit())
	column.add_child(more)
	hide()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", Type.face(Type.BODY, 650))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func refresh(info: Dictionary, island: int, blocked: bool) -> void:
	visible = not blocked and island >= 2 and info.island == island and info.phase != "calm"
	if not visible: return
	var s: Dictionary = info.supply
	var p: Dictionary = info.projects[str(island)]
	title.text = "%s · %ds%s" % [info.name, ceili(info.timer), " TO PREPARE" if info.phase == "warning" else ""]
	reserves.text = "WATER %d/%d   ·   SPRAY %d/18" % [floori(s.water), int(info.water_capacity), floori(s.spray)]
	meter.max_value = info.water_capacity
	meter.value = s.water
	controls.zone.text = "Zone: " + ["Far", "Middle", "Near"][int(s.zone)]
	controls.mode.text = "Flow: " + ["Off", "Ration", "Burst"][int(s.mode)]
	controls.mode.disabled = int(p.get("irrigation", 0)) == 0
	controls.burst.text = "Release · 8 water"
	controls.burst.disabled = int(p.get("rainwater", 0)) == 0 or info.phase != "active" or info.event != "drought" or float(s.water) < 8
	controls.hand.text = "Well · +4 water"
	controls.hand.disabled = info.phase != "active" or float(info.operations.pulse) > 0 or float(s.water) >= float(info.water_capacity)
	controls.gates.text = "Gates: " + ("Open" if s.gates else "Closed")
	controls.gates.disabled = int(p.get("drainage", 0)) == 0
	controls.shelter.text = "Shelter: " + ["Far", "Middle", "Near"][int(s.shelter)]
	controls.shelter.disabled = int(p.get("windbreaks", 0)) == 0
	hint.text = {"drought": "Water [3] rescues thirsty beds. Rings fill as danger rises.", "flood": "Hoe [1] drains flooded beds. Open gates to lower the water.", "storm": "Gold row = next strike: harvest it. Screens reduce wind damage."}.get(info.event, "")
	if info.phase == "recovery": hint.text = "%d beds tended in danger. Reserves are refilling." % int(info.rescued)
