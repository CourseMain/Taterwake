extends Control
## Cream ledger framing a live future farm. Simulation is budgeted across frames
## so native and single-threaded browser exports keep responding while it runs.
signal finished
signal new_run
const Type = preload("res://scripts/ui_type.gd")
const Epilogue = preload("res://scripts/epilogue.gd")
const WORLD_FADE_SECONDS: float = 2.0
const HEADLINE_FADE_SECONDS: float = 0.85
const HEADLINE_STEP_SECONDS: float = 1.0
const VERDICT_CHARACTERS_PER_SECOND: float = 36.0
const VERDICT_GAP_SECONDS: float = 0.3
const VALUE_FADE_SECONDS: float = 0.6
var simulation
var world
var result: Dictionary = {}
var veil: ColorRect
var progress: Label
var top: PanelContainer
var bottom: PanelContainer
var headlines_grid: GridContainer
var verdict_grid: GridContainer
var headline_labels: Array[Label] = []
var verdict_labels: Array[Label] = []
var value_line: Label
var actions: HBoxContainer
var screenshot: Button
var status: Label
var pan_time: float = 0
var home: Vector3
var saved_camera_size: float
var saved_camera_transform: Transform3D
var ready_scene: bool = false
var presentation_time: float = 0
var reveal_complete: bool = false

func setup(farm, farm_world, cached: Dictionary = {}) -> void:
	name = "FiftyYearEpilogue"
	world = farm_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	home = world.camera.position
	saved_camera_transform = world.camera.transform
	saved_camera_size = world.camera.size
	veil = ColorRect.new()
	veil.color = Color("f6edda")
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress = _label("Forty more years…\nThe caretaker keeps your crops and investments.", 24)
	veil.add_child(progress)
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	progress.position -= Vector2(220, 40)
	progress.size = Vector2(440, 100)
	if cached.is_empty():
		simulation = Epilogue.new()
		simulation.begin(farm._save_data())
	else: present(cached)

func _process(delta: float) -> void:
	if simulation != null and result.is_empty():
		if simulation.advance_year(80): present(simulation.result)
		else: progress.text = "Year %d of 50\nThe caretaker keeps your crops and investments." % simulation.farm.season_clock.year
	if not ready_scene: return
	if not reveal_complete:
		presentation_time += delta
		_update_reveal()
	pan_time += delta
	world.camera.position = home + Vector3(sin(pan_time * 0.055) * 4.0, 0, cos(pan_time * 0.055) * 2.0)
	world.camera.look_at(Vector3(0, 0, -1))
	world.fit_camera_depth()
	world.animate(delta, false)

func present(ending: Dictionary) -> void:
	result = ending
	world.show_future(ending)
	home = Vector3(31, 40, 46)
	world.camera.position = home
	world.camera.size = 64
	world.camera.look_at(Vector3(0, 0, -1))
	world.fit_camera_depth()
	progress.hide()
	top = _paper()
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16; top.offset_right = -16; top.offset_top = 12
	var upper := VBoxContainer.new()
	top.add_child(upper)
	upper.add_child(_label("50 years on · " + str(ending.outcome), 28, true))
	var strip = preload("res://scripts/climate_strip.gd").new()
	strip.setup_future(ending.records)
	upper.add_child(strip)
	headlines_grid = GridContainer.new()
	headlines_grid.columns = 5 if size.x >= 700 else 1
	upper.add_child(headlines_grid)
	for headline in ending.headlines:
		var headline_label: Label = _label("%d  /  %s" % [headline.year, headline.text], 14)
		headline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		headline_label.modulate.a = 0
		headlines_grid.add_child(headline_label)
		headline_labels.append(headline_label)
	bottom = _paper()
	add_child(bottom)
	var lower := VBoxContainer.new()
	bottom.add_child(lower)
	verdict_grid = GridContainer.new()
	verdict_grid.columns = 2 if size.y < 650 and size.x > 700 else 1
	lower.add_child(verdict_grid)
	for line in ending.verdicts:
		var verdict_label: Label = _label(line, 16)
		verdict_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		verdict_label.visible_characters = 0
		verdict_grid.add_child(verdict_label)
		verdict_labels.append(verdict_label)
	value_line = _label("Farm value, 50 years on   " + _money(ending.farm_value), 23, true)
	value_line.modulate.a = 0
	lower.add_child(value_line)
	actions = HBoxContainer.new()
	lower.add_child(actions)
	screenshot = _button("Screenshot", capture)
	actions.add_child(screenshot)
	actions.add_child(_button("Ten-year ledger", func(): finished.emit()))
	actions.add_child(_button("New Run", func(): new_run.emit()))
	status = _label("", 13)
	status.hide()
	lower.add_child(status)
	resized.connect(_layout)
	bottom.minimum_size_changed.connect(_layout)
	top.minimum_size_changed.connect(_layout)
	_layout.call_deferred()
	veil.move_to_front()
	ready_scene = true
	_update_reveal()

func verdict_start_time() -> float:
	return WORLD_FADE_SECONDS + maxf(0, headline_labels.size() - 1) * HEADLINE_STEP_SECONDS + HEADLINE_FADE_SECONDS + VERDICT_GAP_SECONDS

func reveal_duration() -> float:
	var seconds: float = verdict_start_time()
	for line in verdict_labels:
		seconds += float(line.text.length()) / VERDICT_CHARACTERS_PER_SECOND + VERDICT_GAP_SECONDS
	return seconds + VALUE_FADE_SECONDS

func _update_reveal() -> void:
	veil.color.a = 1.0 - clampf(presentation_time / WORLD_FADE_SECONDS, 0, 1)
	if presentation_time >= WORLD_FADE_SECONDS: veil.hide()
	for i in range(headline_labels.size()):
		var start: float = WORLD_FADE_SECONDS + i * HEADLINE_STEP_SECONDS
		headline_labels[i].modulate.a = clampf((presentation_time - start) / HEADLINE_FADE_SECONDS, 0, 1)
	_fit_headlines()
	var start: float = verdict_start_time()
	for line in verdict_labels:
		var letters: int = mini(line.text.length(), maxi(0, floori((presentation_time - start) * VERDICT_CHARACTERS_PER_SECOND)))
		line.visible_characters = -1 if letters == line.text.length() else letters
		start += float(line.text.length()) / VERDICT_CHARACTERS_PER_SECOND + VERDICT_GAP_SECONDS
	value_line.modulate.a = clampf((presentation_time - start) / VALUE_FADE_SECONDS, 0, 1)
	reveal_complete = presentation_time >= reveal_duration()

func finish_reveal() -> void:
	if not ready_scene: return
	presentation_time = reveal_duration()
	_update_reveal()

func _fit_headlines() -> void:
	var compact: bool = size.y < 650 and size.x > 700
	var decade: int = clampi(floori((presentation_time - WORLD_FADE_SECONDS) / HEADLINE_STEP_SECONDS), 0, headline_labels.size() - 1)
	# A short landscape phone reads one decade at a time, leaving room for the
	# future farm and all four verdicts. The fifty-year strip stays visible.
	for i in range(headline_labels.size()): headline_labels[i].visible = not compact or i == decade

func _layout() -> void:
	if not is_instance_valid(bottom): return
	var physical: Vector2 = Vector2(get_tree().root.size)
	if OS.has_feature("web"):
		physical = Vector2(float(JavaScriptBridge.eval("document.getElementById('canvas').clientWidth", true)), float(JavaScriptBridge.eval("document.getElementById('canvas').clientHeight", true)))
	var scale: float = minf(physical.x / size.x, physical.y / size.y)
	var compact: bool = size.y < 650 and size.x > 700
	for text in find_children("*", "Label", true, false):
		if text.has_meta("base_font_size"):
			var points: float = float(text.get_meta("base_font_size"))
			if compact and points > 20: points = 22 if points == 28 else 20
			text.add_theme_font_size_override("font_size", ceili(points / minf(1.0, maxf(scale, 0.1))))
	for button in actions.get_children():
		button.custom_minimum_size.y = maxf(44, ceilf(44 / maxf(scale, 0.1)))
		button.add_theme_font_size_override("font_size", ceili(15 / minf(1.0, maxf(scale, 0.1))))
	for panel in [top, bottom]:
		var paper: StyleBoxFlat = panel.get_theme_stylebox("panel")
		paper.content_margin_top = 4 if compact else 10
		paper.content_margin_bottom = 4 if compact else 10
	headlines_grid.columns = 5 if size.x >= 700 and size.y >= 650 else 1
	verdict_grid.columns = 2 if size.y < 650 and size.x > 700 else 1
	_fit_headlines()
	top.offset_bottom = top.offset_top + top.get_combined_minimum_size().y
	var height: float = bottom.get_combined_minimum_size().y
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16; bottom.offset_right = -16
	bottom.offset_top = -height - 12; bottom.offset_bottom = -12
	var scene_height: float = maxf(80, bottom.position.y - top.get_global_rect().end.y)
	world.camera.size = maxf(64 if size.x >= 700 else 84, 30.0 * size.y / scene_height)
	var scene_center: float = (bottom.position.y + top.get_global_rect().end.y) / 2.0
	world.camera.v_offset = (scene_center / size.y - 0.5) * world.camera.size

func _paper() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f6edda")
	style.set_content_margin_all(10)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, points: int, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", Type.face(Type.DISPLAY if heading else Type.BODY))
	label.set_meta("base_font_size", points)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", Color("493d2b"))
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", Type.face(Type.BODY))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("493d2b"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e4d7b7")
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(action)
	return button

func _money(value: float) -> String:
	var digits: String = str(roundi(value))
	var formatted: String = ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0: formatted += ","
		formatted += digits[i]
	return formatted + " Spudions"

func capture() -> void:
	# A saved ending always contains the complete verdict, even during its reveal.
	finish_reveal()
	if DisplayServer.get_name() == "headless":
		status.text = "Screenshots need a rendered window."
		status.show()
		return
	actions.hide()
	status.hide()
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var bytes: PackedByteArray = picture.save_png_to_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, "taterland-50-years.png", "image/png")
		status.text = "Screenshot downloaded."
	else:
		var path: String = "user://taterland-50-years.png"
		var error: Error = picture.save_png(path)
		status.text = "Saved: " + ProjectSettings.globalize_path(path) if error == OK else "Could not save the screenshot."
	actions.show()
	status.show()

func _exit_tree() -> void:
	if simulation != null and is_instance_valid(simulation.farm):
		if is_instance_valid(simulation.farm.activity_system): simulation.farm.activity_system.free()
		simulation.farm.free()
		simulation.farm = null
