extends Control
## An honest final receipt; details scroll while recovery/new-run actions stay reachable.
signal restart_requested
signal debug_requested
const Climate = preload("res://scripts/climate_system.gd")
const Type = preload("res://scripts/ui_type.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const INK := Color("17382d")
const MUTED := Color("667569")
const DEBT := Color("a63529")
var headline: Label
var detail: Label
var _balance: Label
var _event: Label
var _threshold: Label
var _calculation: Label
var _metrics: Dictionary = {}
var _context: Label
var _final_rows: VBoxContainer
var _summary_button: Button
var _report: Dictionary = {}
var _font: Font = Type.face(Type.BODY, 500)
var _display: Font = Type.face(Type.EDITORIAL, 650)
var _ledger: VBoxContainer
var _scroll: ScrollContainer

func _init() -> void:
	_font.fallbacks = [Type.SPUDION]
	_display.fallbacks = [Type.SPUDION]
	name = "ClimateCollapse"
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", Cozy.paper(Cozy.INK, 0, 0, Cozy.WOOD))
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 26)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	_event = label("", 14, MUTED)
	page.add_child(_event)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)
	headline = label("BANKRUPT", 80, INK, true)
	content.add_child(headline)
	var amount_row := HFlowContainer.new()
	amount_row.add_theme_constant_override("h_separation", 28)
	amount_row.add_theme_constant_override("v_separation", 8)
	content.add_child(amount_row)
	var balance_box := VBoxContainer.new()
	balance_box.custom_minimum_size.x = 265
	amount_row.add_child(balance_box)
	balance_box.add_child(label("FINAL BALANCE", 12, MUTED))
	_balance = label("", 40, DEBT, true)
	balance_box.add_child(_balance)
	var reason := VBoxContainer.new()
	reason.custom_minimum_size.x = 265
	amount_row.add_child(reason)
	detail = label("", 19, INK)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_child(detail)
	_threshold = label("", 15, Color("896221"))
	_threshold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_child(_threshold)
	_calculation = label("", 18, INK)
	_calculation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_calculation)
	content.add_child(rule())
	var metrics := HFlowContainer.new()
	metrics.add_theme_constant_override("h_separation", 28)
	metrics.add_theme_constant_override("v_separation", 18)
	content.add_child(metrics)
	for id in ["FIELD LOST", "DEBT LIMIT"]:
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 200
		metrics.add_child(box)
		var caption := label(id, 12, MUTED)
		box.add_child(caption)
		var value: Label = label("", 34, Color("896221") if id != "DEBT LIMIT" else INK, true)
		box.add_child(value)
		var note: Label = label("", 13, MUTED)
		box.add_child(note)
		_metrics[id] = {"value": value, "note": note, "caption": caption}
	_ledger = VBoxContainer.new()
	_ledger.add_theme_constant_override("separation", 12)
	content.add_child(_ledger)
	_context = label("", 15, MUTED)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_child(_context)
	_final_rows = VBoxContainer.new()
	_final_rows.name = "FinalLedgerRows"
	_final_rows.add_theme_constant_override("separation", 2)
	var ledger_leaf := PanelContainer.new()
	ledger_leaf.add_theme_stylebox_override("panel", Cozy.paper(Cozy.CREAM, 16, 4))
	_ledger.add_child(ledger_leaf)
	ledger_leaf.add_child(_final_rows)
	_ledger.add_child(rule())
	_ledger.add_child(label("BEYOND THIS FARM", 12, Color("896221")))
	var education := label(Climate.EDUCATION, 18, INK)
	education.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_child(education)
	var source := label("FAO · Disasters, agriculture & food security", 12, MUTED)
	source.tooltip_text = Climate.EDUCATION_SOURCE
	_ledger.add_child(source)
	_ledger.hide()
	page.add_child(rule())
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 9)
	page.add_child(actions)
	var again: Button = button("TRY AGAIN", true)
	again.name = "TryAgain"
	again.tooltip_text = "Start a new farm. The ended farm's progress is replaced."
	actions.add_child(again)
	again.pressed.connect(func() -> void: restart_requested.emit())
	_summary_button = button("VIEW RUN SUMMARY")
	actions.add_child(_summary_button)
	_summary_button.pressed.connect(func() -> void:
		_ledger.visible = not _ledger.visible
		_summary_button.text = "HIDE RUN SUMMARY" if _ledger.visible else "VIEW RUN SUMMARY"
		if _ledger.visible: _scroll.ensure_control_visible.call_deferred(_ledger)
	)
	var debug: Button = button("DEBUG ACCESS")
	debug.name = "DebugAccess"
	debug.tooltip_text = "Access code required. Recover a test farm without resetting its progress."
	actions.add_child(debug)
	debug.pressed.connect(func() -> void: debug_requested.emit())
	resized.connect(func() -> void:
		if not is_inside_tree(): return
		headline.add_theme_font_size_override("font_size", clampi(int(size.x * 0.068), 36, 80))
		var scale: float = minf(float(get_tree().root.size.x) / size.x, float(get_tree().root.size.y) / size.y)
		for control in actions.get_children(): control.custom_minimum_size.y = maxf(45, ceilf(44 / maxf(scale, 0.1)))
	)
	hide()

func label(text: String, pixels: int, color: Color, display: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", _display if display else _font)
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", color.lightened(.65) if color.get_luminance() < .62 else color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color("5b5144")
	line.custom_minimum_size.y = 1
	return line

func button(text: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(190, 45)
	result.add_theme_font_override("font", _display)
	result.add_theme_font_size_override("font_size", 16)
	for key in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e1c495") if primary else (Color("e7e2d2") if key != "normal" else Color.TRANSPARENT)
		style.border_color = MUTED
		style.set_border_width_all(1)
		result.add_theme_stylebox_override(key, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]: result.add_theme_color_override(key, Color("241e19") if primary else INK)
	preload("res://scripts/place_ui.gd").pill(result, INK, primary)
	return result

func show_report(farm) -> void:
	var report: Dictionary = farm.climate.data.collapse
	if report.is_empty():
		farm.climate.capture_collapse(farm)
		report = farm.climate.data.collapse
	if visible and _report == report: return
	_report = report.duplicate(true)
	headline.text = "FORECLOSED"
	_balance.text = farm.money(farm.coins, true)
	_event.text = "SPUD VALLEY   /   YEAR %d ACCOUNTS" % farm.season_clock.year
	detail.text = farm.run_title() + " · " + str(report.cause)
	_threshold.text = "Foreclosure below " + farm.money(farm.bankruptcy_limit(), true)
	_calculation.text = "Year %d net: %s. The complete Winter bill of %s has been posted." % [farm.season_clock.year, farm.money(farm.ledger.total(farm.season_clock.year)), farm.money(farm.ledger.fixed_cost_total())]
	for pair in [["FIELD LOST", "field"]]:
		var lost: float = float(report[pair[1] + "_lost"])
		var total: float = float(report[pair[1] + "_total"])
		_metrics[pair[0]].value.text = "%.0f%%" % (lost / total * 100.0) if total > 0.0 else "None"
		_metrics[pair[0]].note.text = "%s / %s" % [farm.format_number(lost), farm.format_number(total)]
		_metrics[pair[0]].note.visible = total > 0.0
		_metrics[pair[0]].value.get_parent().visible = lost > 0
	_metrics["DEBT LIMIT"].caption.text = "OVERDRAFT LIMIT"
	_metrics["DEBT LIMIT"].value.text = farm.money(farm.bankruptcy_limit())
	_metrics["DEBT LIMIT"].note.text = ""
	_metrics["DEBT LIMIT"].note.hide()
	_context.text = "Year %d · Category totals" % farm.season_clock.year
	for child in _final_rows.get_children():
		_final_rows.remove_child(child); child.queue_free()
	for category in farm.Ledger.CATEGORIES:
		if is_zero_approx(farm.ledger.total(farm.season_clock.year, category)): continue
		var row := preload("res://scripts/ledger_row.gd").new()
		_final_rows.add_child(row)
		row.setup(get_parent().get_parent(), farm.Ledger.LABELS[category], farm.money(farm.ledger.total(farm.season_clock.year, category)))
	_context.text += "\nThe books close here. The farm’s future starts with the state you leave behind."
	_ledger.show()
	_scroll.scroll_vertical = 0
	_summary_button.text = "HIDE RUN SUMMARY"
	show()
	modulate.a = 1.0
