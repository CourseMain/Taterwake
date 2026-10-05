extends VBoxContainer
const Display = preload("res://scripts/weather_display.gd")
const Place = preload("res://scripts/place_ui.gd")
const ACCENT := Color("588da5")
const SHELL := Place.INK
var hud
var _grid: GridContainer
var _hero: HBoxContainer
var _instrument: Control
var _range: Control
var _levels: Dictionary = {}
var _values: Dictionary = {}
func setup(owner_hud) -> void:
	hud = owner_hud; set_meta("market_responsive", true)
	add_theme_constant_override("separation", 12)
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(SHELL, 18, 3, Place.WOOD))
	hud._modal_card.offset_left = -500; hud._modal_card.offset_right = 500
	hud._modal_card.offset_top = -380; hud._modal_card.offset_bottom = 380
	Place.header(hud, self, "WEATHER STATION", ACCENT, "iris")
	var instrument := _panel(self); instrument.name = "ForecastInstrument"
	_hero = HBoxContainer.new(); _hero.add_theme_constant_override("separation", 16); instrument.add_child(_hero)
	_instrument = Display.new(); _instrument.name = "ForecastDrawing"; _instrument.custom_minimum_size = Vector2(128, 128); _hero.add_child(_instrument)
	var forecast: VBoxContainer = hud._vbox(5); forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _hero.add_child(forecast)
	hud._refs.forecast_range = hud._wrap("", 23, Place.INK, true); forecast.add_child(hud._refs.forecast_range)
	_range = preload("res://scripts/paper_detail.gd").new(); _range.kind = "range"; _range.name = "ForecastBracket"
	_range.custom_minimum_size = Vector2(140, 68); forecast.add_child(_range)
	hud._refs.climate_status = hud._wrap("", 14, Place.MUTED); forecast.add_child(hud._refs.climate_status)
	hud._refs.climate_market = hud._wrap("", 14, Place.INK); forecast.add_child(hud._refs.climate_market)
	var fields := HFlowContainer.new(); fields.name = "FieldExposureChips"; fields.add_theme_constant_override("h_separation", 8); add_child(fields)
	for entry in [["home", "Home · sheltered"], ["low", "Low · floods first"], ["hill", "Hill · dries first"]]:
		var chip := _panel(fields); chip.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 8, 100))
		var row := HBoxContainer.new(); chip.add_child(row)
		row.add_child(hud._icon({"kind": "metric", "id": entry[0]}, 28)); row.add_child(hud._wrap(entry[1], 14, Place.INK))
	_grid = GridContainer.new(); _grid.name = "ProtectionTiles"; _grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12); _grid.add_theme_constant_override("v_separation", 12); add_child(_grid)
	for id in ["rainwater", "drainage", "windbreaks", "frost", "irrigation"]:
		var tile := _panel(_grid); tile.name = "Protection_" + id
		tile.add_theme_stylebox_override("panel", Place.skin(Place.WOOD, 12, 5, Place.WOOD.darkened(.25)))
		var body: VBoxContainer = hud._vbox(8); tile.add_child(body)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); body.add_child(row)
		var drawing := Display.new(); drawing.kind = id; drawing.dark = true; drawing.custom_minimum_size = Vector2(42, 42); row.add_child(drawing)
		var title: Label = hud._wrap(hud._state.ClimateSystem.PROJECTS[id].name, 20, Place.PAPER, true); row.add_child(title)
		var level: Label = hud._label("", 16, Place.PAPER); row.add_child(level); _levels[id] = level
		var effect: Label = hud._wrap("", 15, Place.PAPER.darkened(.1)); body.add_child(effect); hud._refs["climate_effect:" + id] = effect
		var button: Button = hud._button("", "")
		button.pressed.connect(func(): hud._act("project_site:" + id if hud._state.climate.data.protection.pending.has(id) else "climate_fund:" + id))
		Place.pill(button, ACCENT, true); body.add_child(button); hud._refs["climate_fund:" + id] = button
	var practice: Button = hud._button("Water practice", "climate_operate:lesson_start")
	add_child(practice); hud._refs.climate_practice = practice
	var insurance := _panel(self); insurance.name = "InsuranceToggleRow"
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); insurance.add_child(row)
	hud._refs.insurance = hud._button("", "insure"); hud._refs.insurance.toggle_mode = true
	hud._refs.insurance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Place.pill(hud._refs.insurance, ACCENT); row.add_child(hud._refs.insurance)
	Place.help(hud, row, "Spring insurance pays 40%% of lost tonnes at base prices. Field claims settle at Winter start; Winter crop and barn claims pay on loss. Protections must be paid for and built with three visits in Winter. Their upkeep is %s each year." % hud._state.money(hud._state.ClimateSystem.Protection.UPKEEP))
	var station := HBoxContainer.new(); station.add_theme_constant_override("separation", 8); add_child(station)
	hud._refs.station_upgrade = hud._button("", "station_upgrade"); hud._refs.station_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Place.pill(hud._refs.station_upgrade, ACCENT); station.add_child(hud._refs.station_upgrade)
	_values.water = hud._wrap("", 13, Place.PAPER); station.add_child(_values.water)
	resized.connect(_layout); refresh(); _layout.call_deferred()
func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Place.skin()); parent.add_child(panel); return panel
func refresh() -> void:
	if not is_instance_valid(_instrument): return
	var farm = hud._state; var info: Dictionary = farm.climate_info(); var forecast: Dictionary = info.forecast
	_instrument.phase = info.phase
	hud._refs.climate_status.text = "Clear skies" if info.phase == "calm" else "%s · %ds" % [str(info.name).capitalize(), ceili(info.timer)]
	if info.phase == "recovery": hud._refs.climate_status.text = "Recovering · %ds" % ceili(info.timer)
	var alerts := {"drought":"Water dry beds", "flood":"Open drainage gates", "storm":"Harvest the lightning row", "freeze":"Hoe clears ice", "blizzard":"Sell stores before impact", "deep_freeze":"Harvest ripe Icecap"}
	hud._refs.climate_market.visible = info.phase == "warning"
	hud._refs.climate_market.text = alerts.get(info.event, "")
	_values.water.text = "%d / %d water" % [int(info.supply.water), int(info.water_capacity)]
	var events := PackedStringArray()
	for event in forecast.events: events.append(str(event).replace("_", " ").capitalize())
	hud._refs.forecast_range.text = "Next %s\n%s" % [farm.SeasonClock.NAMES[int(forecast.season)], " or ".join(events)]
	_range.low = forecast.low; _range.high = forecast.high; _range.queue_redraw()
	for id in _levels:
		var level: int = int(info.projects.get(id, 0)); var full: bool = level >= 2
		var pending: bool = info.protection.pending.has(id)
		_levels[id].text = Place.pips(level, 2)
		var effect: String = {"rainwater":"Drought", "drainage":"Flood", "windbreaks":"Storm", "frost":"Covered Spring freeze", "irrigation":"Water"}[id]
		hud._refs["climate_effect:" + id].text = "%d tank water per patch" % (4 if level == 2 else 6) if id == "irrigation" else "%s loss −%d%%" % [effect, 75 if level == 2 else 50]
		hud._refs["climate_effect:" + id].tooltip_text = "At level %d. " % maxi(1, level) + farm.ClimateSystem.PROJECTS[id].detail
		var button: Button = hud._refs["climate_fund:" + id]
		var cost: float = farm.ClimateSystem.PROJECTS[id].cost * (level + 1)
		button.text = "Work %d / 3 →" % info.protection.pending[id] if pending else ("Built" if full else "Build%s · %s" % [" level 2" if level == 1 else "", farm.money(cost)])
		button.set_meta("action", "project_site:" + id if pending else "climate_fund:" + id)
		button.set_meta("hud_action", button.get_meta("action"))
		button.disabled = farm.run_over or full or (farm.season_clock.season != 3 and id != "irrigation") or (not pending and not farm.can_purchase(cost))
	hud._refs.climate_practice.visible = info.projects.get("irrigation", 0) > 0
	hud._refs.climate_practice.disabled = farm.run_over or farm.climate.data.phase != "calm"
	var insured: bool = farm.ClimateSystem.Protection.insured(farm)
	hud._refs.insurance.text = "● Insured this year" if insured else "○ Insurance this year · " + farm.money(farm.ClimateSystem.Protection.PREMIUM)
	hud._refs.insurance.set_pressed_no_signal(insured)
	hud._refs.insurance.disabled = insured or farm.season_clock.season != 0 or farm.run_over or not farm.can_purchase(farm.ClimateSystem.Protection.PREMIUM)
	var level: int = info.protection.station
	hud._refs.station_upgrade.text = "Station %s · ±%d" % [Place.pips(level, 2), [20,10,5][level]] + ("  Upgrade " + farm.money(farm.ClimateSystem.Protection.STATION_COST * (level + 1)) if level < 2 else "")
	hud._refs.station_upgrade.disabled = level >= 2 or farm.run_over or not farm.can_purchase(farm.ClimateSystem.Protection.STATION_COST * (level + 1))
func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	Place.compact(self)
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	_grid.columns = 1 if size.x < 650 else 2
	var scale: float = float(get_tree().root.size.x) / hud.root.size.x
	_range.custom_minimum_size.y = 68 / minf(1, maxf(.1, scale))
	_instrument.custom_minimum_size = Vector2(84, 110) if size.x < 650 else Vector2(128, 128)
	for button in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = hud.touch_target() if touch else 44
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, hud.touch_target() if touch else 44)
		button.add_theme_font_size_override("font_size", 22 if touch else 15)
	for label in find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(20, label.get_theme_font_size("font_size")))
