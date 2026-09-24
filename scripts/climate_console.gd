extends PanelContainer
signal operated(action: String)
signal opened
const Type = preload("res://scripts/ui_type.gd")
var title: Label
var reserves: Label
var hint: Label
var meter: ProgressBar
var primary: Button
var secondary: Button
var more: Button
var primary_action: String = ""
var secondary_action: String = ""
var targeting: String = ""
var tool: String = "hoe"

func _ready() -> void:
	name = "ClimateFieldConsole"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -314
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
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	title = _label(17, Color("ffe2a3"))
	column.add_child(title)
	reserves = _label(14, Color("e4f3e8"))
	column.add_child(reserves)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 7
	meter.show_percentage = false
	column.add_child(meter)
	hint = _label(14, Color("d2e8dd"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 260
	column.add_child(hint)
	primary = _button()
	primary.pressed.connect(func() -> void: operated.emit(primary_action))
	column.add_child(primary)
	secondary = _button()
	secondary.pressed.connect(func() -> void: operated.emit(secondary_action))
	column.add_child(secondary)
	more = _button()
	more.text = "Farm protection  ›"
	more.pressed.connect(func() -> void: opened.emit())
	column.add_child(more)
	hide()

func _button() -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 34
	button.add_theme_font_override("font", Type.face(Type.BODY, 650))
	button.add_theme_font_size_override("font_size", 14)
	return button

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", Type.face(Type.BODY, 650))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func refresh(info: Dictionary, island: int, blocked: bool) -> void:
	var lesson: String = str(info.lesson.stage)
	var teaching: bool = island == 2 and lesson in ["offer", "water", "area", "success"]
	visible = not blocked and (teaching or (island >= 2 and info.island == island and info.phase != "calm"))
	if not visible: return
	primary.hide()
	secondary.hide()
	primary.disabled = false
	secondary.disabled = false
	more.visible = not teaching
	reserves.hide()
	meter.hide()
	var s: Dictionary = info.supply
	var p: Dictionary = info.projects[str(island)]
	if teaching:
		var practice_cost: int = int(info.lesson.cost)
		title.text = "YOUR FIRST DRY SPELL" if lesson == "offer" else "WATER PRACTICE · " + ("1 / 2" if lesson == "water" else "2 / 2")
		hint.text = {"offer": "A warmer climate raises risks from extreme weather. Cutting emissions limits warming; storing water helps farms cope.\n\nTry a tank on practice crops. Keep a starter tank afterward.", "water": "Click the glowing bed with Water [3]. Watch its danger ring fall.\n\nYour real crops and bills are paused.", "area": "The can rescued one bed. The tank can rescue an area for %d water. Choose the glowing beds." % practice_cost, "success": "Both beds recovered for %d water. Your tank refills in normal weather. It is yours to keep." % practice_cost}[lesson]
		if lesson == "success": title.text = "AREA RESCUED · %d WATER" % practice_cost
		if lesson == "offer": _primary("Try it · about 30 seconds", "lesson_start")
		elif lesson == "area": _primary("Water an area · %d water" % practice_cost, "target_water")
		secondary.visible = lesson != "success"
		secondary.text = "Not now" if lesson == "offer" else "Skip practice"
		secondary_action = "lesson_skip"
		if lesson != "offer": _water(s, info.water_capacity)
	elif info.phase == "recovery":
		title.text = "WEATHER CLEARING"
		hint.text = "Crops are safe from this disaster. Supplies refill automatically; prices recover in %ds." % ceili(info.timer)
		more.hide()
	else:
		title.text = "%s %s%ds" % [info.name, "IN " if info.phase == "warning" else "· ", ceili(info.timer)]
		match str(info.event):
			"drought":
				_water(s, info.water_capacity)
				hint.text = "The tank fills before the dry spell. Harvest ripe crops; save water for the beds still growing." if info.phase == "warning" else "Water [3] lowers a bed's danger ring. A full ring means the crop is lost."
				if info.phase == "active":
					var cost: int = 8 - 2 * int(p.get("irrigation", 0))
					if float(s.water) >= cost:
						if int(p.get("rainwater", 0)) > 0: _primary("Water an area · %d water" % cost, "target_water")
					else:
						_primary("Draw emergency water · +4", "hand")
						primary.disabled = float(info.operations.pulse) > 0
						if primary.disabled: primary.text = "Well refilling · %ds" % ceili(info.operations.pulse)
			"flood":
				hint.text = "Hoe [1] drains planted beds without removing crops. Drain the beds with the fullest rings."
				if int(p.get("drainage", 0)) > 0:
					if s.gates: hint.text = "Drains are open and lowering the water. Use Hoe [1] on beds still in danger."
					else: _primary("Open drains", "gates")
			"storm":
				hint.text = "Harvest the gold warning row before lightning hits. Shelter screens reduce wind damage."
				if int(p.get("windbreaks", 0)) > 0: _primary("Move wind shelter", "target_shelter")
		if tool == "pest":
			reserves.show()
			reserves.text = "SPRAYER · %d charges" % floori(s.spray)
	if not targeting.is_empty():
		hint.text = "Click the highlighted area on your farm. Water is spent only when you choose it." if targeting == "water" else "Click an area to move its wind shelter. The highlighted beds will be protected from wind."
		_primary("Cancel selection · Esc", "cancel")
	# PanelContainer otherwise retains the size of its longer previous lesson.
	size.y = 0

func _primary(text: String, action: String) -> void:
	primary.show()
	primary.text = text
	primary_action = action

func _water(supply: Dictionary, capacity: float) -> void:
	reserves.show()
	meter.show()
	reserves.text = "STORED WATER · %d / %d" % [floori(supply.water), int(capacity)]
	meter.max_value = capacity
	meter.value = supply.water
