extends Control
## A quiet editorial spread. Essential losses first; the full ledger is optional.
signal restart_requested
const Climate = preload("res://scripts/climate_system.gd")
const Type = preload("res://scripts/ui_type.gd")
const CREAM := Color("eee7d9")
const MUTED := Color("baa995")
const DEBT := Color("d07c6c")
var headline: Label
var detail: Label
var _balance: Label
var _event: Label
var _metrics: Dictionary = {}
var _context: Label
var _summary: Label
var _summary_button: Button
var _report: Dictionary = {}
var _font: Font = Type.face(Type.BODY, 500)
var _display: Font = Type.face(Type.EDITORIAL, 650)
var _ledger: VBoxContainer
var _tween: Tween

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
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 62)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 38)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)
	_event = label("", 14, MUTED)
	page.add_child(_event)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 65)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spread)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.05
	left.add_theme_constant_override("separation", 9)
	spread.add_child(left)
	headline = label("BANKRUPT", 96, CREAM, true)
	left.add_child(headline)
	left.add_child(label("FINAL BALANCE", 12, MUTED))
	_balance = label("", 43, DEBT, true)
	left.add_child(_balance)
	detail = label("", 21, CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(detail)
	_ledger = VBoxContainer.new()
	_ledger.add_theme_constant_override("separation", 10)
	left.add_child(_ledger)
	_context = label("", 15, MUTED)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_child(_context)
	_summary = label("", 15, CREAM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.add_child(_summary)
	_ledger.hide()
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 20)
	spread.add_child(right)
	right.add_child(label("BEYOND THIS FARM", 14, Color("cbab78")))
	var education := label(Climate.EDUCATION, 25, CREAM)
	education.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(education)
	var source := label("FAO · Disasters, agriculture & food security", 12, MUTED)
	source.tooltip_text = Climate.EDUCATION_SOURCE
	right.add_child(source)
	page.add_child(rule())
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 30)
	page.add_child(metrics)
	for id in ["FIELD LOST", "BARN LOST", "TAX BILL"]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_child(box)
		var caption := label(id, 13, MUTED)
		box.add_child(caption)
		var value: Label = label("", 40, Color("c6a986") if id != "TAX BILL" else CREAM, true)
		box.add_child(value)
		var note: Label = label("", 13, MUTED)
		box.add_child(note)
		note.hide()
		_metrics[id] = {"value": value, "note": note}
	page.add_child(rule())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	page.add_child(actions)
	var again: Button = button("TRY AGAIN", true)
	again.name = "TryAgain"
	actions.add_child(again)
	again.pressed.connect(func() -> void: restart_requested.emit())
	_summary_button = button("VIEW RUN SUMMARY")
	actions.add_child(_summary_button)
	_summary_button.pressed.connect(func() -> void:
		_ledger.visible = not _ledger.visible
		_summary_button.text = "HIDE RUN SUMMARY" if _ledger.visible else "VIEW RUN SUMMARY"
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
	result.custom_minimum_size = Vector2(215, 47)
	result.add_theme_font_override("font", _display)
	result.add_theme_font_size_override("font_size", 18)
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
	_event.text = "ISLAND %d   /   %s" % [int(report.island), event if not event.is_empty() else "A FARM LOST"]
	detail.text = "Recovery costs pushed your farm into debt." if str(report.cause).contains("Recovery") else "Your debt crossed the bankruptcy limit."
	for pair in [["FIELD LOST", "field"], ["BARN LOST", "barn"]]:
		var lost: float = float(report[pair[1] + "_lost"])
		var total: float = float(report[pair[1] + "_total"])
		_metrics[pair[0]].value.text = "%.0f%%" % (lost / total * 100.0) if total > 0.0 else "None"
		_metrics[pair[0]].note.text = "%s / %s" % [farm.format_number(lost), farm.format_number(total)]
	_metrics["TAX BILL"].value.text = farm.money(report.tax, true)
	_metrics["TAX BILL"].note.text = "Bankruptcy below " + farm.money(farm.bankruptcy_limit(), true)
	_context.text = "%s build · %s market %+.0f%%\nSeeds +%.0f%% · Weather sale prices %.0f%%" % [report.build, str(report.market_crop).capitalize(), float(report.market_change), (float(report.seed_factor) - 1.0) * 100.0, (float(report.sell_factor) - 1.0) * 100.0]
	_summary.text = "%.0f min farmed\n%s beds lost · %s stored potatoes lost\n%s tax collected\n%d protection upgrades funded" % [float(report.elapsed) / 60.0, farm.format_number(report.total_field_lost), farm.format_number(report.total_barn_lost), farm.money(report.tax_paid, true), project_count(report.projects)]
	_ledger.hide()
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
