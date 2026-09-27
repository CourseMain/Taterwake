extends VBoxContainer
const Display = preload("res://scripts/weather_display.gd")
const Type = preload("res://scripts/ui_type.gd")
const BG := Color("0a1424")
const PANEL := Color("11263a")
const CYAN := Color("68dceb")
const WHITE := Color("edf6ff")
const MUTED := Color("9bb2c9")
const AMBER := Color("ffc579")
var hud
var _grid: GridContainer
var _metrics: GridContainer
var _hero: BoxContainer
var _instrument: Control
var _protection: GridContainer
var _values: Dictionary = {}
var _font: FontVariation = Type.face(Type.BODY, 650)
func setup(owner_hud) -> void:
	hud = owner_hud
	_font.fallbacks = []
	set_meta("market_responsive", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	hud._heading("WEATHER STATION", "")
	hud._modal_title.add_theme_font_override("font", _font)
	hud._modal_title.add_theme_color_override("font_color", WHITE)
	var skin: StyleBoxFlat = hud.Cozy.box(BG, 18, 24, Color("355870"))
	skin.set_border_width_all(2)
	hud._modal_card.add_theme_stylebox_override("panel", skin)
	hud._modal_card.offset_left = -530
	hud._modal_card.offset_right = 530
	hud._modal_card.offset_top = -380
	hud._modal_card.offset_bottom = 380
	if hud._island_id() < 2:
		add_child(_label("Available on Golden Shores", 20, WHITE))
		add_child(_button("Explore islands", "island"))
		return
	var hero := _panel(self)
	var hero_body : VBoxContainer = hud._vbox(9)
	hero.add_child(hero_body)
	_hero = BoxContainer.new()
	_hero.add_theme_constant_override("separation", 20)
	hero_body.add_child(_hero)
	_instrument = Display.new()
	_instrument.custom_minimum_size = Vector2(142, 142)
	_hero.add_child(_instrument)
	var status : VBoxContainer = hud._vbox(8)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero.add_child(status)
	hud._refs.climate_status = _label("", 27, WHITE)
	hud._refs.climate_market = _label("", 14, AMBER)
	status.add_child(hud._refs.climate_status)
	status.add_child(hud._refs.climate_market)
	_metrics = GridContainer.new()
	_metrics.columns = 3
	_metrics.add_theme_constant_override("h_separation", 18)
	status.add_child(_metrics)
	for entry: Array in [["water","TANK"],["market","SALE PRICES"],["tax","RECOVERY TAX"]]:
		var col : VBoxContainer = hud._vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_metrics.add_child(col)
		col.add_child(_label(entry[1], 10, MUTED))
		_values[entry[0]] = _label("", 19, WHITE)
		col.add_child(_values[entry[0]])
	var protection := _panel(self)
	var protections : VBoxContainer = hud._vbox(8)
	protection.add_child(protections)
	protections.add_child(_label("DAMAGE REDUCTION", 11, CYAN))
	_protection = GridContainer.new()
	_protection.columns = 4
	_protection.add_theme_constant_override("h_separation", 12)
	_protection.add_theme_constant_override("v_separation", 5)
	protections.add_child(_protection)
	hud._refs.protection_summary = protection
	for words: String in ["", "CROPS", "BARN", "TAX"]: _protection.add_child(_label(words, 11, MUTED))
	for event: String in (["drought","flood","storm","freeze"] if hud._island_id() == 3 else ["drought","flood","storm"]):
		_protection.add_child(_label(event.capitalize(), 14, WHITE))
		for metric: String in ["field", "barn", "tax"]:
			_values[event + metric] = _label("", 14, WHITE)
			_protection.add_child(_values[event + metric])
	add_child(_label("EQUIPMENT", 12, CYAN))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)
	var titles := {"irrigation":"Irrigation array", "rainwater":"Water reserve", "drainage":"Drain network", "barn":"Barn shutters", "windbreaks":"Windbreaks"}
	for id: String in hud._state.ClimateSystem.PROJECTS:
		var panel := _panel(_grid)
		panel.tooltip_text = hud._state.ClimateSystem.PROJECTS[id].detail
		var column : VBoxContainer = hud._vbox(9)
		panel.add_child(column)
		var row : BoxContainer = hud._hbox(12)
		column.add_child(row)
		var schematic := Display.new()
		schematic.kind = id
		schematic.custom_minimum_size = Vector2(70,70)
		row.add_child(schematic)
		var heading : VBoxContainer = hud._vbox(3)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(heading)
		heading.add_child(_label(titles[id], 19, WHITE))
		var effect := _label("", 14, MUTED)
		column.add_child(effect)
		hud._refs["climate_effect:" + id] = effect
		var buy := _button("", "climate_fund:" + id, true)
		column.add_child(buy)
		hud._refs["climate_fund:" + id] = buy
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	if hud._island_id() == 2:
		hud._refs.climate_practice = _button("Water practice", "climate_operate:lesson_start")
		actions.add_child(hud._refs.climate_practice)
	else: actions.add_child(_button("Heat thawing hoe", "climate_operate:heat_hoe"))
	actions.add_child(_button("Tax forecast", "taxes"))
	# Optional reference for the duration of each weather phase.
	var details: VBoxContainer = hud._details_section("climate_details", "weather timings")
	hud._refs.climate_details.reparent(self)
	hud._refs["climate_details:toggle"].reparent(self)
	move_child(hud._refs["climate_details:toggle"], get_child_count() - 2)
	_style_button(hud._refs["climate_details:toggle"], false)
	hud._refs.climate_details.add_theme_stylebox_override("panel", hud.Cozy.box(PANEL, 10, 14, Color("355870")))
	details.add_child(_label("Warning 45s · Impact 30s · Recovery 75s", 13, MUTED))
	resized.connect(_layout)
	refresh()
	_layout.call_deferred()
func _label(words: String, pixels: int, color: Color) -> Label:
	var label: Label = hud._wrap(words, pixels, color)
	label.add_theme_font_override("font", _font)
	label.set_meta("weather_font", pixels)
	return label
func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", hud.Cozy.box(PANEL, 12, 16, Color("2a4b63")))
	parent.add_child(panel)
	return panel
func _button(words: String, action: String, primary: bool = false) -> Button:
	var button: Button = hud._button(words, action)
	_style_button(button, primary)
	return button
func _style_button(button: Button, primary: bool) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 45
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = CYAN if primary else Color("17344a")
		if state == "hover": fill = fill.lightened(0.1)
		elif state == "pressed": fill = fill.darkened(0.15)
		elif state == "disabled": fill = Color("203346")
		button.add_theme_stylebox_override(state, hud.Cozy.box(fill, 8, 10, Color("355870")))
	for state: String in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state, BG if primary else WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("focus", hud.Cozy.box(Color.TRANSPARENT,8,0,AMBER))
func refresh() -> void:
	if not is_instance_valid(_instrument): return
	var farm = hud._state
	var info: Dictionary = farm.climate_info()
	_instrument.phase = info.phase
	hud._refs.climate_status.text = "Clear skies" if info.phase == "calm" else "%s · %ds" % [str(info.name).capitalize(), ceili(info.timer)]
	if info.phase == "recovery": hud._refs.climate_status.text = "Recovering · %ds" % ceili(info.timer)
	var alerts := {"drought":"Water dry beds", "flood":"Open drainage gates", "storm":"Harvest the lightning row", "freeze":"Heat the hoe to thaw crops"}
	hud._refs.climate_market.visible = info.phase != "calm"
	hud._refs.climate_market.text = alerts.get(info.event, "") if info.phase == "warning" else "Next tax " + farm.money(farm.blind_info().tax)
	_values.water.text = "%d / %d" % [int(info.supply.water), int(info.water_capacity)]
	_values.market.text = "%d%%" % roundi(float(info.sell_factor) * 100.0)
	_values.tax.text = "+%d%%" % roundi(float(info.pressure) * 100.0)
	for event: String in ["drought", "flood", "storm", "freeze"]:
		for metric: String in ["field", "barn", "tax"]:
			if _values.has(event + metric): _values[event + metric].text = "%d%%" % roundi(farm.climate.protection(event, hud._island_id(), metric)*100)
	for id: String in farm.ClimateSystem.PROJECTS:
		var level: int = int(info.projects[str(hud._island_id())].get(id, 0))
		var full: bool = level >= farm.ClimateSystem.MAX_PROJECT_LEVEL
		var cost: float = float(farm.BlindRules.PROGRESSION_BASELINES[2 if id == "irrigation" else hud._island_id()]) * float(farm.ClimateSystem.PROJECTS[id].cost) * (level + 1)
		var stats := {"irrigation":"4 water / patch" if full else ("6 → 4 water / patch" if level == 1 else "3 patches · 6 water each"), "rainwater":"%d water capacity" % int(info.water_capacity) if full else "%d → %d water capacity" % [int(info.water_capacity), int(info.water_capacity)+36], "drainage":"Flood: −30% crop damage / level", "barn":"−35% stored crop loss / level", "windbreaks":"Shelters far beds · wind only"}
		hud._refs["climate_effect:" + id].text = stats[id]
		hud._set_purchase_button("climate_fund:" + id, "Fully upgraded" if full else farm.purchase_caption(("Install" if level == 0 else "Upgrade") + " · " + farm.money(cost), cost), cost, full)
	if hud._refs.has("climate_practice"):
		hud._refs.climate_practice.disabled = int(info.projects["2"].get("irrigation", 0)) == 0
func _layout() -> void:
	if not is_instance_valid(_grid): return
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	_grid.columns = 1 if size.x < 650 else 2
	_hero.vertical = size.x < 540
	_instrument.visible = size.x >= 540
	_metrics.columns = 1 if size.x < 330 else 3
	for label: Node in find_children("*", "Label", true, false):
		var font_size: int = int(label.get_meta("weather_font", 14))
		label.add_theme_font_size_override("font_size", maxi(22, font_size) if touch else font_size)
	for button: Node in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 68 if touch else 45
		button.add_theme_font_size_override("font_size", 24 if touch else 15)
