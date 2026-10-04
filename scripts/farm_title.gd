extends CanvasLayer
## The actual farm is the welcome: no menu card, and no advancing a saved year.
const Type = preload("res://scripts/ui_type.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const PULLBACK_SECONDS := 8.0
var game: Node
var active := false
var confirming := false
var has_saved_farm := false
var root: Control
var walk: Button
var resume: Button
var elapsed := 0.0
var saved_camera: Transform3D
var saved_size := 0.0
var saved_hud_visible := true
var saved_player_position := Vector3.ZERO
var hidden_world_items: Array[Dictionary] = []
var saved_background: int
var saved_sky: Sky
var dusk_sky: Sky

func _ready() -> void:
	layer = 45
	process_priority = 1000
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	walk = _button("Walk to the farm", true)
	resume = _button("", false)
	walk.pressed.connect(_walk_in)
	resume.pressed.connect(func():
		if has_saved_farm: game._enter_title_farm(false)
	)
	get_tree().root.size_changed.connect(_layout, CONNECT_DEFERRED)
	root.hide()

func _button(words: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Type.face(Type.BODY, 750))
	button.add_theme_font_size_override("font_size", 17)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		if primary:
			var fill := Cozy.INK.lightened(.08) if state == "hover" else Cozy.INK.darkened(.08) if state == "pressed" else Cozy.INK
			button.add_theme_stylebox_override(state, Cozy.box(fill, 12, 4, Cozy.WOOD))
		else:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for property: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(property, Cozy.CREAM)
	button.add_theme_color_override("font_disabled_color", Color("c6c2a8"))
	if not primary:
		button.add_theme_color_override("font_outline_color", Cozy.INK)
		button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("focus", Cozy.box(Color.TRANSPARENT, 0, 3, Color("eebd6b")))
	root.add_child(button)
	return button

func start(returning: bool) -> void:
	if active: return
	active = true
	confirming = false
	has_saved_farm = returning
	elapsed = 0
	saved_camera = game.world.camera.transform
	saved_size = game.world.camera.size
	saved_player_position = game.world.player.position
	saved_hud_visible = game.hud.root.visible
	saved_background = game.world._day_environment.background_mode
	saved_sky = game.world._day_environment.sky
	_hide_world_text()
	if is_instance_valid(game.world.coast) and game.world.coast.has_method("set_title_mode"): game.world.coast.set_title_mode(true)
	game._cancel_walk()
	game._cancel_map_drag()
	game.touch_controls.release_all()
	game.hud.close_panel()
	game.hud.root.hide()
	game.touch_controls.root.hide()
	resume.text = "Continue · Year %d, %s" % [game.state.season_clock.year, game.state.season_clock.NAMES[game.state.season_clock.season]]
	resume.disabled = not returning
	resume.tooltip_text = "" if returning else "Your first farm starts at the gate."
	walk.tooltip_text = "Start a new farm. You'll be asked before replacing this one." if returning else ""
	root.show()
	_layout()
	advance(0)
	game.world.set_player_position(game.world.title_gate.global_position + Vector3(2.2, 0, 2.1))

func _hide_world_text() -> void:
	hidden_world_items.clear()
	for label: Label3D in game.world.find_children("*", "Label3D", true, false):
		if label.name == "GateWordmark": continue
		hidden_world_items.append({"node": label, "visible": label.visible})
		label.hide()
	for board: Node3D in game.world._lease_boards:
		hidden_world_items.append({"node": board, "visible": board.visible})
		board.hide()
	var markers: Array = game.world.visuals.grade_batches.values()
	markers.append(game.world.visuals.water_markers)
	for marker: Node3D in markers:
		hidden_world_items.append({"node": marker, "visible": marker.visible})
		marker.hide()

func _process(_delta: float) -> void:
	if not active: return
	# Reapply after world weather/material updates without changing their state.
	for entry: Dictionary in hidden_world_items:
		if is_instance_valid(entry.node): entry.node.hide()
	_light()

func _light() -> void:
	# Warm low sun and cool fill belong to this camera, never to farm history.
	var world = game.world
	if world._sun.light_color == Color("ffb76a") and is_equal_approx(world._sun.light_energy, 1.12) and world._sun.rotation_degrees.is_equal_approx(Vector3(-15, -32, 0)) and is_equal_approx(world._day_environment.ambient_light_energy, .4) and world._day_environment.sky == dusk_sky: return
	world._sun_desired = Vector3(-15, -32, 0)
	world._sun_from = world._sun_desired
	world._sun_target = world._sun_desired
	world._sun.rotation_degrees = world._sun_desired
	world._sun.light_color = Color("ffb76a")
	world._sun.light_energy = 1.12
	world._moon.light_energy = .04
	world._day_environment.ambient_light_color = Color("789f93")
	world._day_environment.ambient_light_energy = .4
	world._day_environment.background_color = Color("e3a16d")
	if dusk_sky == null:
		var gradient := ProceduralSkyMaterial.new()
		gradient.sky_top_color = Color("5f7781")
		gradient.sky_horizon_color = Color("e8ac77")
		gradient.ground_horizon_color = Color("e8ac77")
		gradient.ground_bottom_color = Color("344e43")
		gradient.sky_curve = .35
		dusk_sky = Sky.new()
		dusk_sky.sky_material = gradient
	world._day_environment.sky = dusk_sky
	world._day_environment.background_mode = Environment.BG_SKY
	if is_instance_valid(world.coast): world.coast.sync_light()

func _layout() -> void:
	if not is_instance_valid(walk): return
	var viewport_size := get_viewport().get_visible_rect().size
	var touch: bool = game.touch_controls.enabled
	var width: float = minf(520 if touch else 420, viewport_size.x - 40)
	var height: float = 84 if touch else 56
	var continue_height: float = 68 if touch else 44
	var gap: float = 14 if touch else 10
	var left: float = (viewport_size.x - width) * .5
	var bottom: float = viewport_size.y - 28
	walk.position = Vector2(left, bottom - height - continue_height - gap)
	walk.size = Vector2(width, height)
	resume.position = Vector2(left, bottom - continue_height)
	resume.size = Vector2(width, continue_height)
	walk.add_theme_font_size_override("font_size", 28 if touch else 22)
	resume.add_theme_font_size_override("font_size", 22 if touch else 16)
	if active: _pan()

func advance(delta: float) -> void:
	if not active: return
	elapsed += maxf(0, delta)
	if confirming and (not game.hud.is_panel_open() or not game.hud._reset_pending):
		confirming = false
		game.hud.close_panel()
		game.hud.root.hide()
		root.show()
	_pan()
	# Keep the real season's field and snow, but let the gate catch dusk light.
	game.world.set_day_time(game.world.DAY_CYCLE_SECONDS * .94, game.state.season_clock.season == 3)
	_light()

func _pan() -> void:
	var world = game.world
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait: bool = viewport_size.x < viewport_size.y
	var gate: Vector3 = world.title_gate.global_position
	var pullback: float = smoothstep(0, PULLBACK_SECONDS, elapsed)
	var drift: float = sin(elapsed * .045) * 1.8
	var close_focus := Vector3(0, 5.0 if portrait else 4.8, -1.5)
	var wide_focus := Vector3(-.25, 2.4, -5.5)
	var focus: Vector3 = gate + close_focus.lerp(wide_focus, pullback)
	world.camera.size = lerpf(20.0 if portrait else 10.5, 29.0 if portrait else 26.0, pullback)
	world.camera.position = focus + Vector3(lerpf(.5, 2.8, pullback) + drift, lerpf(6.5, 12.0, pullback), 36.0)
	world.camera.look_at(focus + Vector3(drift * .20, 0, 0))
	world.camera.position += world.camera.basis.z * 190.0
	world.fit_camera_depth()

func _walk_in() -> void:
	if not active: return
	if not has_saved_farm:
		game._enter_title_farm(true)
		return
	confirming = true
	root.hide()
	game.hud.root.show()
	game.hud._run_end.hide()
	# Reuse the existing two-choice reset confirmation; no save changes yet.
	game.hud.show_panel("pause", game.state)
	game.hud._reset_pending = true
	game.hud.show_panel("pause", game.state)

func finish() -> void:
	if not active: return
	active = false
	confirming = false
	root.hide()
	game.hud.close_panel()
	game.world.camera.transform = saved_camera
	game.world.camera.size = saved_size
	game.world.set_player_position(saved_player_position)
	for entry: Dictionary in hidden_world_items:
		if is_instance_valid(entry.node): entry.node.visible = entry.visible
	hidden_world_items.clear()
	game.world._day_environment.background_mode = saved_background
	game.world._day_environment.sky = saved_sky
	if is_instance_valid(game.world.coast) and game.world.coast.has_method("set_title_mode"): game.world.coast.set_title_mode(false)
	game.world.fit_camera_depth()
	game.world._applied_day_time = -1.0
	game.world.set_calendar(game.state.season_clock.year, game.state.season_clock.season, game.state.calendar_light_seconds(), game.state.climate.data.outlook.signal)
	game.world._sun_from = game.world._sun_desired
	game.world._sun_target = game.world._sun_desired
	game.world._sun.rotation_degrees = game.world._sun_desired
	game.hud.root.visible = saved_hud_visible
	game.touch_controls.root.show()
	game.touch_controls.release_all()
	game._reset_camera_zoom()
