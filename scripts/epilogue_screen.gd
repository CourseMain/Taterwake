extends Control
## Cream ledger framing a live future farm. Simulation is budgeted across frames
## so native and single-threaded browser exports keep responding while it runs.
signal finished
signal new_run
const Type = preload("res://scripts/ui_type.gd")
const Epilogue = preload("res://scripts/epilogue.gd")
var simulation
var world
var result: Dictionary = {}
var veil: ColorRect
var progress: Label
var top: PanelContainer
var bottom: PanelContainer
var headlines_grid: GridContainer
var verdict_grid: GridContainer
var actions: HBoxContainer
var screenshot: Button
var status: Label
var pan_time: float = 0
var home: Vector3
var saved_camera_size: float
var saved_camera_transform: Transform3D
var ready_scene: bool = false

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
	pan_time += delta
	world.camera.position = home + Vector3(sin(pan_time * 0.055) * 4.0, 0, cos(pan_time * 0.055) * 2.0)
	world.camera.look_at(Vector3(0, 0, -1))
	world.animate(delta, false)

func present(ending: Dictionary) -> void:
	result = ending
	world.show_future(ending)
	home = Vector3(31, 40, 46)
	world.camera.position = home
	world.camera.size = 64
	world.camera.look_at(Vector3(0, 0, -1))
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
		headlines_grid.add_child(headline_label)
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
		verdict_grid.add_child(verdict_label)
	lower.add_child(_label("Farm value, 50 years on   " + _money(ending.farm_value), 23, true))
	actions = HBoxContainer.new()
	lower.add_child(actions)
	screenshot = _button("Screenshot", capture)
	actions.add_child(screenshot)
	actions.add_child(_button("Ten-year ledger", func(): finished.emit()))
	actions.add_child(_button("New Run", func(): new_run.emit()))
	status = _label("", 13)
	lower.add_child(status)
	resized.connect(_layout)
	bottom.minimum_size_changed.connect(_layout)
	top.minimum_size_changed.connect(_layout)
	_layout.call_deferred()
	veil.move_to_front()
	var tween := create_tween()
	tween.tween_property(veil, "color:a", 0.0, 2.0)
	tween.tween_callback(veil.hide)
	ready_scene = true

func _layout() -> void:
	if not is_instance_valid(bottom): return
	headlines_grid.columns = 5 if size.x >= 700 else 1
	verdict_grid.columns = 2 if size.y < 650 and size.x > 700 else 1
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
	if DisplayServer.get_name() == "headless":
		status.text = "Screenshots need a rendered window."
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
