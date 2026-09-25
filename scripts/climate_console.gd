extends PanelContainer
signal operated(action: String)
signal opened
const Type = preload("res://scripts/ui_type.gd")
var equipment: String = ""
var story: Control
var title: Label
var reserves: Label
var hint: Label
var meter: ProgressBar
var primary: Button
var secondary: Button
var more: Button
var close: Button
var primary_action: String = ""
var secondary_action: String = ""
var targeting: String = ""
var tool: String = "hoe"
var _show_secondary: bool = false
var _layout_signature: String = ""

func _ready() -> void:
	name = "ClimateFieldConsole"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -314
	offset_right = -22
	offset_top = 112
	var skin := _skin(Color("193c33"), Color("6f9d83"), 14)
	skin.content_margin_left = 14
	skin.content_margin_right = 14
	skin.content_margin_top = 12
	skin.content_margin_bottom = 12
	skin.shadow_color = Color(0.02, 0.10, 0.06, 0.24)
	skin.shadow_size = 10
	skin.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = _label(17, Color("ffe4a5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close = _button(false)
	close.text = "×"
	close.tooltip_text = "Close · Esc"
	close.custom_minimum_size = Vector2(26, 26)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: operated.emit("close_equipment"))
	header.add_child(close)
	story = preload("res://scripts/water_story.gd").new()
	story.dark = true
	column.add_child(story)
	reserves = _label(13, Color("a9d6ca"))
	column.add_child(reserves)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 6
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", _skin(Color("102e2b"), Color.TRANSPARENT, 3))
	meter.add_theme_stylebox_override("fill", _skin(Color("7bd0d0"), Color.TRANSPARENT, 3))
	column.add_child(meter)
	hint = _label(14, Color("dce9da"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 260
	column.add_child(hint)
	primary = _button(true)
	primary.pressed.connect(func() -> void: operated.emit(primary_action))
	column.add_child(primary)
	secondary = _button(false)
	secondary.pressed.connect(func() -> void: operated.emit(secondary_action))
	column.add_child(secondary)
	more = _button(false)
	more.text = "Farm protection  ›"
	more.pressed.connect(func() -> void:
		if not equipment.is_empty(): operated.emit("close_equipment")
		else: opened.emit())
	column.add_child(more)
	hide()

func _skin(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = fill
	skin.border_color = edge
	skin.set_border_width_all(1 if edge.a > 0.0 else 0)
	skin.set_corner_radius_all(radius)
	return skin

func _button(emphasis: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 34
	button.add_theme_font_override("font", Type.face(Type.BODY, 700))
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := Color("e4c482") if emphasis else Color("244b3e")
		if state == "hover": fill = fill.lightened(0.12)
		elif state == "pressed": fill = fill.darkened(0.13)
		elif state == "disabled": fill = Color("315348")
		var skin := _skin(fill, Color("89b49a") if state == "focus" else Color.TRANSPARENT, 7)
		skin.content_margin_left = 8
		skin.content_margin_right = 8
		skin.content_margin_top = 5
		skin.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, skin)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("253e2e") if emphasis else Color("d8e7d6"))
	button.add_theme_color_override("font_disabled_color", Color("b8c9b8"))
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
	visible = not blocked and (not equipment.is_empty() or teaching or (island >= 2 and info.island == island and info.phase != "calm"))
	if not visible: return
	# Do not hide live buttons during refresh: doing so cancels a held mouse press.
	primary_action = ""
	_show_secondary = false
	primary.disabled = false
	secondary.disabled = false
	more.visible = not teaching
	close.visible = not equipment.is_empty()
	reserves.hide()
	meter.hide()
	var s: Dictionary = info.supply
	var p: Dictionary = info.projects[str(island)]
	story.visible = not equipment.is_empty() or teaching
	if not equipment.is_empty():
		story.concept = equipment
		more.hide()
		if equipment == "tank":
			title.text = "Rainwater tank"
			_water(s, info.water_capacity)
			reserves.text += "   ·   Can %d / %d" % [floori(s.can), int(info.can_capacity)]
			var drought: bool = info.event == "drought" and info.phase == "active" and int(info.island) == island
			hint.text = "The same tank fills your can and feeds the connected sprinklers." if int(p.get("irrigation", 0)) > 0 else "Rain fills the tank; carry its water to your crops in the can."
			if drought: hint.text = "Rain has stopped; the can and sprinklers share this stored water."
			if float(s.can) < 1.0: hint.text = "Can empty: refill here, then use Water [3] on your crops."
			_primary("Refill watering can", "refill")
			if float(s.can) >= float(info.can_capacity):
				primary.text = "Watering can is full"
				primary.disabled = true
			elif float(s.water) < 1.0:
				primary.text = "Waiting for rain"
				primary.disabled = true
				hint.text = "Rain returns after the dry spell; use the water already in your can." if drought else "Rain is refilling your tank; it will be ready in a moment."
		elif equipment.begins_with("sprinkler"):
			var cost: int = 8 - 2 * int(p.get("irrigation", 0))
			var patch: int = clampi(int(equipment.trim_prefix("sprinkler")), 0, 2)
			title.text = ["Far-bed sprinkler", "Middle-bed sprinkler", "Near-bed sprinkler"][patch]
			_water(s, info.water_capacity)
			hint.text = "Follow the pipe: your tank waters this fixed patch in any weather."
			_primary("Water these beds · %d water" % cost, "use_sprinkler")
			primary.disabled = float(s.water) < cost
			if primary.disabled: hint.text = "This patch needs %d tank water; rain replenishes the reserve after drought." % cost
		elif equipment == "drain":
			title.text = "Drain gate"
			hint.text = "Water follows these channels to the sea, clearing the puddles around your crops."
			_primary("Drain is open" if s.gates else "Open drain", "gates")
			primary.disabled = s.gates
		elif equipment == "trees":
			title.text = "Living wind shelter"
			hint.text = "Trees automatically calm the wind over the glowing far beds; lightning can still strike."
		else:
			title.text = "Reinforced barn"
			hint.text = "Automatic protection: shutters close at the weather warning to protect stored harvests."
		_finish_refresh()
		return
	more.text = "Farm protection  ›"
	if teaching:
		var practice_cost: int = int(info.lesson.cost)
		story.concept = "can" if lesson == "water" else "irrigation"
		title.text = {"offer": "Meet your sprinklers", "water": "First, water one bed", "area": "Now, water the patch", "success": "Watch the beds recover"}[lesson]
		hint.text = {"offer": "Your familiar tank now feeds sprinklers: try both ways to water in a short, safe practice.", "water": "Choose Water [3] and click the glowing bed; your real crops and bills are paused.", "area": "Click the near sprinkler, then Water these beds to spend %d tank water." % practice_cost, "success": "%d tank water rescued the whole patch; follow the pipes to use it on your own crops." % practice_cost}[lesson]
		if lesson == "offer": _primary("Try it · about 30 seconds", "lesson_start")
		elif lesson == "area": _primary("Show the near sprinkler", "show_sprinkler")
		_show_secondary = lesson != "success"
		secondary.text = "Not now" if lesson == "offer" else "Skip practice"
		secondary_action = "lesson_skip"
		if lesson != "offer": _water(s, info.water_capacity)
		if lesson == "water":
			reserves.text = "Can %d / %d water · 1 per bed" % [floori(s.can), int(info.can_capacity)]
			meter.max_value = info.can_capacity
			meter.value = s.can
	elif info.phase == "recovery":
		title.text = "WEATHER CLEARING"
		hint.text = "Rain replenishes your tank; markets recover in %ds." % ceili(info.timer)
		more.hide()
	else:
		title.text = "%s %s%ds" % [info.name, "IN " if info.phase == "warning" else "· ", ceili(info.timer)]
		match str(info.event):
			"drought":
				_water(s, info.water_capacity)
				hint.text = "Fill your can before rain stops; the can and sprinklers will share the tank reserve." if info.phase == "warning" else "Water [3] restores drooping crops and lowers their danger rings."
				if int(p.get("irrigation", 0)) > 0: _primary("Show sprinklers", "show_sprinkler")
			"flood":
				hint.text = "Hoe [1] clears water from a planted bed without removing its crop."
				if int(p.get("drainage", 0)) > 0:
					if s.gates: hint.text = "Drains are open; water flows to the sea while puddles shrink."
					else: _primary("Show drain gate", "show_drain")
			"storm":
				hint.text = "Harvest the gold warning row before lightning; trees automatically shelter the far beds from wind."
				if int(p.get("windbreaks", 0)) > 0: _primary("Show sheltered beds", "show_trees")
		if tool == "pest":
			reserves.show()
			reserves.text = "Sprayer · %d charges" % floori(s.spray)
	if not targeting.is_empty():
		hint.text = "Click the highlighted patch; its sprinkler draws water from the tank."
		_primary("Cancel selection · Esc", "cancel")
	_finish_refresh()

func _finish_refresh() -> void:
	primary.visible = not primary_action.is_empty()
	secondary.visible = _show_secondary
	# Shrink only when the content changes, keeping hit targets stable between ticks.
	var signature := str([title.text, hint.text, primary.text, primary.visible, secondary.visible, more.visible, story.visible, reserves.visible, meter.visible])
	if signature != _layout_signature:
		_layout_signature = signature
		reset_size()

func _primary(text: String, action: String) -> void:
	primary.text = text
	primary_action = action

func _water(supply: Dictionary, capacity: float) -> void:
	reserves.show()
	meter.show()
	reserves.text = "Tank %d / %d water" % [floori(supply.water), int(capacity)]
	meter.max_value = capacity
	meter.value = supply.water
