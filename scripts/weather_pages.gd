extends VBoxContainer
const Display = preload("res://scripts/weather_display.gd")
const Type = preload("res://scripts/ui_type.gd")
const BG := Color("f5ebd3")
const PANEL := Color("eee0bd")
const CYAN := Color("547351")
const WHITE := Color("3f2c1c")
const MUTED := Color("705236")
const AMBER := Color("986c31")
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
	_font.fallbacks = [Type.SPUDION]
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
	for entry: Array in [["water","TANK"]]:
		var col : VBoxContainer = hud._vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_metrics.add_child(col)
		col.add_child(_label(entry[1], 10, MUTED))
		_values[entry[0]] = _label("", 19, WHITE)
		col.add_child(_values[entry[0]])
	hud._refs.forecast_range = _label("", 18, WHITE)
	add_child(hud._refs.forecast_range)
	hud._refs.station_upgrade = _button("", "station_upgrade")
	add_child(hud._refs.station_upgrade)
	hud._refs.insurance = _button("", "insure")
	add_child(hud._refs.insurance)
	add_child(_button("This season's loss notices", "loss_notices"))
	hud._refs.cover_all = _button("Cover all cleared beds", "cover_all")
	add_child(hud._refs.cover_all)
	var protection := _panel(self)
	var protections : VBoxContainer = hud._vbox(8)
	protection.add_child(protections)
	protections.add_child(_label("DAMAGE REDUCTION", 11, CYAN))
	protections.add_child(_label("Tonne losses round to the nearest whole tonne after protection.", 13, MUTED))
	_protection = GridContainer.new()
	_protection.columns = 2
	_protection.add_theme_constant_override("h_separation", 12)
	_protection.add_theme_constant_override("v_separation", 5)
	protections.add_child(_protection)
	hud._refs.protection_summary = protection
	for words: String in ["", "FIELD LOSS REDUCTION"]: _protection.add_child(_label(words, 11, MUTED))
	for event: String in ["drought","flood","storm","freeze"]:
		_protection.add_child(_label(event.capitalize(), 14, WHITE))
		for metric: String in ["field"]:
			_values[event + metric] = _label("", 14, WHITE)
			_protection.add_child(_values[event + metric])
	add_child(_label("EQUIPMENT", 12, CYAN))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)
	var titles := {"irrigation":"Sprinklers", "rainwater":"Rainwater tank", "drainage":"Drainage", "frost":"Frost cover", "windbreaks":"Windbreak"}
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
		if id != "irrigation":
			var work_button := _button("Walk to construction site", "project_site:" + id)
			column.add_child(work_button)
			hud._refs["project_site:" + id] = work_button
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	hud._refs.climate_practice = _button("Water practice", "climate_operate:lesson_start")
	actions.add_child(hud._refs.climate_practice)
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
		var fill: Color = CYAN if primary else Color("d9c99f")
		if state == "hover": fill = fill.lightened(0.1)
		elif state == "pressed": fill = fill.darkened(0.15)
		elif state == "disabled": fill = Color("dfd4b8")
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
	var alerts := {"drought":"Water dry beds", "flood":"Open drainage gates", "storm":"Harvest the lightning row", "freeze":"Hoe clears ice from crops"}
	hud._refs.climate_market.visible = info.phase != "calm"
	hud._refs.climate_market.text = alerts.get(info.event, "") if info.phase == "warning" else "Prepare before the next weather warning."
	_values.water.text = "%d / %d" % [int(info.supply.water), int(info.water_capacity)]
	for event: String in ["drought", "flood", "storm", "freeze"]:
		for metric: String in ["field"]:
			if _values.has(event + metric): _values[event + metric].text = "%d%%" % roundi(farm.climate.protection(event)*100) + (" · covered Spring beds" if event == "freeze" else "")
	for id: String in farm.ClimateSystem.PROJECTS:
		var level: int = int(info.projects.get(id, 0))
		var full: bool = level >= farm.ClimateSystem.MAX_PROJECT_LEVEL
		var cost: float = float(farm.ClimateSystem.PROJECTS[id].cost) * (level + 1)
		var pending: bool = info.protection.pending.has(id)
		hud._refs["climate_effect:" + id].text = farm.ClimateSystem.PROJECTS[id].detail
		if id != "irrigation": hud._refs["climate_effect:" + id].text += " Annual upkeep: " + farm.money(farm.ClimateSystem.Protection.UPKEEP)
		if pending: hud._refs["climate_effect:" + id].text += "\nPaid · Work %d / 3. Unfinished work carries to next Winter." % int(info.protection.pending[id])
		var winter_only: bool = id != "irrigation"
		var caption: String = "Fully built" if full else ("Paid · Finish at site" if pending else ("Reserve" if winter_only else "Install") + " · " + farm.money(cost))
		hud._set_purchase_button("climate_fund:" + id, caption, cost, full or pending or (winter_only and farm.season_clock.season != 3))
		if winter_only:
			hud._refs["project_site:" + id].visible = pending
			hud._refs["project_site:" + id].disabled = farm.season_clock.season != 3
	var forecast: Dictionary = info.forecast
	hud._refs.cover_all.disabled = farm.ClimateSystem.Protection.coverable_beds(farm).is_empty()
	hud._refs.cover_all.tooltip_text = "Winter only · build frost covers, then clear bed ice with Hoe."
	hud._refs.forecast_range.text = "Next %s: disaster chance %d to %d%%." % [farm.SeasonClock.NAMES[int(forecast.season)], roundi(forecast.low * 100), roundi(forecast.high * 100)]
	if not forecast.events.is_empty():
		for event in forecast.events:
			var risk: Dictionary = forecast.events[event]
			hud._refs.forecast_range.text += "\n%s %d to %d%%" % [str(event).replace("_", " ").capitalize(), roundi(risk.low * 100), roundi(risk.high * 100)]
	var station: int = int(info.protection.station)
	hud._refs.station_upgrade.text = "Station level %d · ±%d points" % [station, [20, 10, 5][station]] + (" · Upgrade " + farm.money(farm.ClimateSystem.Protection.STATION_COST * (station + 1)) if station < 2 else "")
	hud._refs.station_upgrade.disabled = station >= 2 or farm.run_over or not farm.can_purchase(farm.ClimateSystem.Protection.STATION_COST * (station + 1))
	var insured: bool = farm.ClimateSystem.Protection.insured(farm)
	hud._refs.insurance.text = "Insured this year · 40% at base prices · field losses paid at Winter start; Winter crop and barn claims paid on loss" if insured else "Spring insurance · " + farm.money(farm.ClimateSystem.Protection.PREMIUM) + " · 40% at base prices · field losses paid at Winter start; Winter crop and barn claims paid on loss"
	hud._refs.insurance.disabled = insured or farm.season_clock.season != 0 or farm.run_over or not farm.can_purchase(farm.ClimateSystem.Protection.PREMIUM)

	if hud._refs.has("climate_practice"):
		hud._refs.climate_practice.disabled = int(info.projects.get("irrigation", 0)) == 0
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
