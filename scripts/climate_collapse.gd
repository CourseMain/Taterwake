extends Control
## An honest final receipt; details scroll while recovery/new-run actions stay reachable.
signal restart_requested
signal debug_requested
const Climate = preload("res://scripts/climate_system.gd")
const Type = preload("res://scripts/ui_type.gd")
const CREAM := Color("eee7d9")
const MUTED := Color("baa995")
const DEBT := Color("d07c6c")
var headline: Label
var detail: Label
var _balance: Label
var _event: Label
var _threshold: Label
var _calculation: Label
var _metrics: Dictionary = {}
var _context: Label
var _summary: Label
var _summary_button: Button
var _report: Dictionary = {}
var _font: Font = Type.face(Type.BODY, 500)
var _display: Font = Type.face(Type.EDITORIAL, 650)
var _ledger: VBoxContainer
var _tween: Tween
var _scroll: ScrollContainer

func _init() -> void:
	name = "ClimateCollapse"
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear; void fragment(){vec3 c=texture(screen_texture,SCREEN_UV).rgb; float g=dot(c,vec3(0.299,0.587,0.114)); COLOR=vec4(mix(vec3(g)*vec3(0.32,0.29,0.24),vec3(0.082,0.075,0.064),0.82),1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	background.material = material
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
	headline = label("BANKRUPT", 80, CREAM, true)
	content.add_child(headline)
	var amount_row := HFlowContainer.new()
	amount_row.add_theme_constant_override("h_separation", 28)
	amount_row.add_theme_constant_override("v_separation", 8)
	content.add_child(amount_row)
	var balance_box := VBoxContainer.new()
	amount_row.add_child(balance_box)
	balance_box.add_child(label("FINAL BALANCE", 12, MUTED))
	_balance = label("", 40, DEBT, true)
	balance_box.add_child(_balance)
	var reason := VBoxContainer.new()
	reason.custom_minimum_size.x = 265
	amount_row.add_child(reason)
	detail = label("", 19, CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_child(detail)
	_threshold = label("", 15, Color("e0b27d"))
	_threshold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_child(_threshold)
	_calculation = label("", 18, CREAM)
	_calculation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_calculation)
	content.add_child(rule())
	var metrics := HFlowContainer.new()
	metrics.add_theme_constant_override("h_separation", 28)
	metrics.add_theme_constant_override("v_separation", 18)
	content.add_child(metrics)
	for id in ["FIELD LOST", "BARN LOST", "TAX BILL"]:
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 200
		metrics.add_child(box)
		var caption := label(id, 12, MUTED)
		box.add_child(caption)
		var value: Label = label("", 34, Color("c6a986") if id != "TAX BILL" else CREAM, true)
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
	_summary = label("", 15, CREAM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_child(_summary)
	_ledger.add_child(rule())
	_ledger.add_child(label("BEYOND THIS FARM", 12, Color("cbab78")))
	var education := label(Climate.EDUCATION, 18, CREAM)
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
		headline.add_theme_font_size_override("font_size", clampi(int(size.x * 0.068), 36, 80))
	)
	hide()

func label(text: String, pixels: int, color: Color, display: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", _display if display else _font)
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", color)
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
		style.bg_color = Color("e1c495") if primary else (Color("423a30") if key != "normal" else Color.TRANSPARENT)
		style.border_color = MUTED
		style.set_border_width_all(1)
		result.add_theme_stylebox_override(key, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]: result.add_theme_color_override(key, Color("241e19") if primary else CREAM)
	return result

func show_report(farm) -> void:
	var report: Dictionary = farm.climate.data.collapse
	if report.is_empty():
		farm.climate.capture_collapse(farm)
		report = farm.climate.data.collapse
	if visible and _report == report: return
	_report = report.duplicate(true)
	headline.text = "BANKRUPT" if farm.blind_cycle.reason == "bankrupt" else "RUN ENDED"
	_balance.text = farm.money(report.balance, true)
	var event: String = str(Climate.EVENTS.get(report.event, {}).get("name", ""))
	if event.is_empty() and str(report.cause).contains("Recovery"):
		event = "AFTER THE " + str(Climate.EVENTS.get(report.get("last_event", ""), {}).get("name", "DISASTER"))
	_event.text = "ISLAND %d   /   %s" % [int(report.island), event if not event.is_empty() else "FINAL RECEIPT"]
	var receipt: Dictionary = farm.blind_cycle.last_result
	var tax_caused: bool = str(report.cause).to_lower().contains("tax") and not receipt.is_empty() and float(receipt.after) == float(report.balance) and float(receipt.tax) > 0.0
	detail.text = "This tax bill crossed the debt limit." if tax_caused else "Your debt crossed the bankruptcy limit."
	_threshold.text = "Bankruptcy below " + farm.money(farm.bankruptcy_limit(), true)
	_calculation.text = "%s before − %s tax = %s after" % [farm.money(receipt.balance, true), farm.money(receipt.tax, true), farm.money(receipt.after, true)] if tax_caused else "No tax was collected at this moment."
	for pair in [["FIELD LOST", "field"], ["BARN LOST", "barn"]]:
		var lost: float = float(report[pair[1] + "_lost"])
		var total: float = float(report[pair[1] + "_total"])
		_metrics[pair[0]].value.text = "%.0f%%" % (lost / total * 100.0) if total > 0.0 else "None"
		_metrics[pair[0]].note.text = "%s / %s" % [farm.format_number(lost), farm.format_number(total)]
		_metrics[pair[0]].note.visible = total > 0.0
	_metrics["TAX BILL"].caption.text = "TAX COLLECTED" if tax_caused else "NEXT BASE TAX"
	_metrics["TAX BILL"].value.text = farm.money(receipt.tax if tax_caused else farm.blind_info().base_tax, true)
	_metrics["TAX BILL"].note.text = "Island %d tax tier" % int(farm.blind_cycle.island)
	_context.text = "%s build" % report.build
	_summary.text = "%.0f min farmed\n%s beds lost · %s stored potatoes lost\n%s tax collected\n%d protection upgrades funded" % [float(report.elapsed) / 60.0, farm.format_number(report.total_field_lost), farm.format_number(report.total_barn_lost), farm.money(report.tax_paid, true), project_count(report.projects)]
	_ledger.hide()
	_scroll.scroll_vertical = 0
	_summary_button.text = "VIEW RUN SUMMARY"
	show()
	modulate.a = 0.0
	if is_instance_valid(_tween): _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.65)

func project_count(projects: Dictionary) -> int:
	var total: int = 0
	for island in projects.values():
		for value in island.values(): total += int(value)
	return total
