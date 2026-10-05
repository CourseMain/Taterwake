extends Node3D
## Hands-on farming, a live fictional crop exchange, and changing weather.

const StateScript = preload("res://scripts/game_state.gd")
const WorldScript = preload("res://scripts/farm_world.gd")
const HudScript = preload("res://scripts/game_hud.gd")
const ActivitiesScript = preload("res://scripts/island_activities.gd")
const PestAlert = preload("res://scripts/pest_alert.gd")
const TutorialScript = preload("res://scripts/first_island_tutorial.gd")
const GraphicsPreferences = preload("res://scripts/graphics_preferences.gd")
const SoundMix = preload("res://scripts/sound_mix.gd")
const FarmViewport = preload("res://scripts/farm_viewport.gd")
const WALK_SPEED: float = 7.0
const SPRINT_MULTIPLIER: float = 1.65
const NO_TILES: Array[int] = []
const CAMERA_ZOOM_MIN: float = 18.0
const CAMERA_ZOOM_RESPONSE: float = 14.0
const CAMERA_PAN_RESPONSE: float = 24.0
const CAMERA_SCROLL_STEP: float = 0.035
const CAMERA_TRACKPAD_PAN: float = 24.0
# Local convenience gate only; no session access or speed is written to saves.
const DEBUG_ACCESS_CODE: String = "ORIGINALLYSPUDREPUBLIC"
const DEBUG_TIME_SPEEDS: Array[float] = [1.0, 2.0, 5.0, 10.0, 30.0]
const MAX_ACCELERATED_STEP: float = 1.0

var state
var world
var hud
var activities
var selected_tool: String = "hoe"
var destination: Vector3 = Vector3.ZERO
var walking: bool = false
var sprint_blend: float = 0.0
var pending_plot: int = -1
var walk_waypoints: Array[Vector3] = []
var pending_tool: String = "hoe"
var pending_project: String = ""
var project_work_left: float = 0.0
var hover_plot: int = -1
var hover_elapsed: float = 0.0
var ui_elapsed: float = 0.0
var _hud_update_frame: int = -1
var _updating_simulation: bool = false
var _simulation_changed: bool = false
var _working_plot: bool = false
var save_elapsed: float = 0.0
var test_mode: bool = false
var launch_title_in_tests := false
var _launch_ready := false
var _title_returned := false
var feedback_audio: Node
var seasonal_ambience: Node
var sleeping_until_spring: bool = false
var _accounts_camera_from: float = -1.0
var _accounts_camera_elapsed: float = 0.0
var pest_alert: Node
var _zoom_target_size: float = 38.0
var _camera_home_position := Vector3.ZERO
var _camera_home_size: float = 38.0
var _camera_home_id: int = 0
var _camera_pan_offset := Vector3.ZERO
var _map_drag_origin := Vector2.ZERO
var _map_drag_distance := Vector2.ZERO
var _map_drag_moved := false
var _map_drag_button: int = 0
var _map_drag_window_size := Vector2i.ZERO
var tutorial: Node
var tutorial_notes: Array[float] = []
var tutorial_note_clock: float = 0.0
var weather_shake_clock: float = 0.0
var debug_unlocked: bool = false
var debug_time_multiplier: float = 1.0
var graphics_quality: String = "balanced"
var shadow_size: int = 4096
var frame_recorder: Node
var climate_audio: Node
var climate_target: String = ""
var pending_refill: bool = false
var year_intro: Control
var empty_can_prompted: bool = false
var equipment_prompt_time: float = 0.0
var climate_shake: float = 0.0
var farm_viewport: SubViewport
var touch_controls
var conversation
var epilogue_screen: Control
var epilogue_result: Dictionary = {}
var title_scene: CanvasLayer

func _ready() -> void:
	test_mode = "--integration-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()
	_register_inputs()
	state = StateScript.new()
	state.name = "FarmState"
	if not test_mode: state.boundary_save_path = StateScript.DEFAULT_SAVE_PATH
	add_child(state)
	activities = ActivitiesScript.new()
	activities.name = "IslandActivities"
	activities.setup(state)
	state.activity_system = activities
	add_child(activities)
	var returning: bool = false
	if not test_mode:
		returning = state.load_game()
	pest_alert = PestAlert.new()
	pest_alert.name = "PestAlerts"
	add_child(pest_alert)
	world = WorldScript.new()
	world.name = "FarmWorld"
	farm_viewport = FarmViewport.new()
	farm_viewport.name = "FarmViewport"
	add_child(farm_viewport)
	farm_viewport.attach_picture()
	farm_viewport.add_child(world)
	world.build_world()
	_reset_camera_view()
	get_tree().root.size_changed.connect(_stop_map_navigation)
	get_tree().root.focus_exited.connect(_stop_map_navigation)
	world.set_calendar(state.season_clock.year, state.season_clock.season, state.calendar_light_seconds(), state.climate.data.outlook.signal)
	world.pest_warning.connect(_on_pest_warning)
	hud = HudScript.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.build_ui()
	touch_controls = preload("res://scripts/touch_controls.gd").new()
	touch_controls.game = self
	add_child(touch_controls)
	var conversation_layer := CanvasLayer.new()
	conversation_layer.name = "Conversations"
	conversation_layer.layer = 25 # Native fullscreen stays above the conversation.
	add_child(conversation_layer)
	conversation = preload("res://scripts/npc_conversation.gd").new()
	conversation_layer.add_child(conversation)
	hud._conversation = conversation
	conversation.finished.connect(_finish_conversation)
	_apply_graphics_quality("balanced" if test_mode else GraphicsPreferences.load_mode())
	_set_shadow_size((2048 if touch_controls.enabled else 4096) if test_mode else GraphicsPreferences.load_shadow_size(touch_controls.enabled))
	frame_recorder = preload("res://scripts/frame_time_recorder.gd").new()
	frame_recorder.game = self
	add_child(frame_recorder)
	frame_recorder.finished.connect(func(): hud.show_panel.call_deferred("measurement", state))
	frame_recorder.copied.connect(func(ok):
		if hud._panel_kind == "measurement" and hud._refs.has("measurement_copy_status"):
			hud._refs.measurement_copy_status.text = "Copied" if ok else "Copy unavailable here. Select the report text to copy it."
	)
	hud.action_requested.connect(_on_user_action)
	hud.panel_opened.connect(_on_panel_opened)
	state.contract_collected.connect(func(receipts): world.visuals.collect_order(receipts))
	state.changed.connect(_on_state_changed)
	state.notified.connect(_on_notification)
	state.purchase_completed.connect(_on_purchase_completed)
	state.purchase_rejected.connect(_on_purchase_rejected)
	state.reward_received.connect(_on_reward)
	state.run_ended.connect(_on_run_ended)
	state.climate_changed.connect(_on_climate_changed)
	state.season_changed.connect(_on_season_changed)
	if not test_mode: SoundMix.load_preference()
	_setup_sound()
	climate_audio = load("res://scripts/climate_audio.gd").new()
	add_child(climate_audio)
	tutorial = TutorialScript.new()
	tutorial.name = "FirstIslandTutorial"
	add_child(tutorial)
	tutorial.setup(self)
	_on_state_changed()
	hud.set_tool(selected_tool)
	year_intro = load("res://scripts/climate_intro.gd").new()
	var report_layer := CanvasLayer.new()
	report_layer.layer = 40
	add_child(report_layer)
	report_layer.add_child(year_intro)
	year_intro.finished.connect(func():
		state.climate_report_open = false
		state.climate.data.outlook.seen_year = state.season_clock.year
		_save_checkpoint.call_deferred()
	)
	get_tree().auto_accept_quit = false
	if not test_mode or launch_title_in_tests: _show_title(returning)
	_launch_ready = true

func title_active() -> bool:
	return is_instance_valid(title_scene) and title_scene.active

func _show_title(returning: bool) -> void:
	if not is_instance_valid(title_scene):
		title_scene = preload("res://scripts/farm_title.gd").new()
		title_scene.name = "FarmTitle"
		title_scene.game = self
		add_child(title_scene)
	title_scene.start(returning)

func _enter_title_farm(fresh: bool) -> void:
	if not title_active(): return
	title_scene.finish()
	_resume_loaded_farm(not fresh)

func _resume_loaded_farm(returning: bool) -> void:
	_title_returned = returning
	hud.update_state(state)
	hud.close_panel()
	if state.run_over:
		_on_run_ended()
	elif not bool(state.tutorial_progress.get("completed", false)):
		tutorial.start()
		if returning: hud.close_panel()
	world._player_body.apply_appearance(state.farmer_appearance)
	if not returning and not state.farmer_appearance.chosen:
		hud.show_panel("farmer", state)

func _register_inputs() -> void:
	var bindings: Dictionary = {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if not _launch_ready: return
	SoundMix.advance(delta)
	if is_instance_valid(epilogue_screen): return
	if world == null or hud == null:
		return
	climate_audio.guided = state.guided_first_year()
	if title_active():
		title_scene.advance(delta)
		seasonal_ambience.set_season(state.season_clock.season, false)
		world.animate(delta, false)
		return
	_update_accounts_camera(delta)
	seasonal_ambience.set_environment(state.climate_info(), world.player.position.distance_to(world._duck_home) < 10)
	seasonal_ambience.set_season(state.season_clock.season, state.run_over)
	if sleeping_until_spring:
		_advance_winter_sleep()
		world.animate(delta, false)
		return
	if is_instance_valid(year_intro) and year_intro.visible:
		world.animate(delta, false)
		return
	if not test_mode and not state.run_over and not _title_returned and not state.tutorial_active and state.season_clock.season == 0 and int(state.climate.data.outlook.seen_year) < state.season_clock.year:
		_show_year_start()
		return
	if state.run_over:
		hud.update_state(state)
		world.animate(delta, false)
		return
	if state.accounts_open or (is_instance_valid(conversation) and conversation.visible):
		world.animate(delta, false)
		return
	state.ClimateSystem.Lesson.tick(state, delta)
	if not climate_target.is_empty() and (not state.ClimateSystem.Lesson.active(state) and state.climate.data.phase not in ["warning", "active"]):
		climate_target = ""
		hud._climate_console.targeting = ""
	# Scale only the simulation. A capped accelerated step keeps farming
	# responsive after a slow frame; presentation stays in real time.
	var simulation_delta: float = _simulation_delta(delta)
	_updating_simulation = true
	_advance_simulation(simulation_delta)
	_updating_simulation = false
	if _simulation_changed:
		_simulation_changed = false
		_on_state_changed()
	if state.run_over:
		return
	if project_work_left > 0 and not hud.is_panel_open() and not state.accounts_open and not state.run_over:
		project_work_left = maxf(0, project_work_left - delta)
		if project_work_left == 0:
			var project: String = pending_project
			pending_project = ""
			if world.player.position.distance_to(world.ClimateProjects.site_position(world, project)) <= 1.5:
				hud.show_farm_hint(state.ClimateSystem.Protection.work(state, project))
			_save_checkpoint.call_deferred()

	_update_equipment_card(delta)
	var climate_info: Dictionary = state.climate_info()
	world.set_climate(climate_info)
	world.set_calendar(state.season_clock.year, state.season_clock.season, state.calendar_light_seconds(), state.climate.data.outlook.signal)
	climate_audio.set_weather(climate_info, (state.tutorial_active and not state.guided_first_year()) or state.run_over)
	_update_camera_zoom(delta)
	_update_weather_shake(delta)
	var infested: int = 0
	for plot in state.plots:
		if bool(plot.get("pests", false)) and int(plot.stage) > 0:
			infested += 1
	pest_alert.update(delta, infested if not _tutorial_active() else 0)
	var moving: bool = false
	sprint_blend = lerpf(sprint_blend, 1.0 if (Input.is_action_pressed("sprint") or touch_controls.sprinting) and not hud.is_panel_open() else 0.0, 1.0 - exp(-delta * 10.0))
	var pace: float = lerpf(1.0, SPRINT_MULTIPLIER, sprint_blend)
	if not hud.is_panel_open():
		var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if touch_controls.movement.length() > 0.05:
			input_vector = touch_controls.movement
		if input_vector.length() > 0.05:
			walking = false
			pending_plot = -1
			pending_refill = false
			walk_waypoints.clear()
			var right: Vector3 = world.camera.global_basis.x
			var forward: Vector3 = world.camera.global_basis.z
			right.y = 0.0
			forward.y = 0.0
			var direction: Vector3 = (right.normalized() * input_vector.x + forward.normalized() * input_vector.y).normalized()
			var next_position: Vector3 = world.player.position + direction * WALK_SPEED * pace * delta
			world.set_player_position(_clamp_destination(next_position))
			moving = true
		elif walking:
			var current: Vector3 = world.player.position
			current.y = 0.0
			var target: Vector3 = destination
			target.y = 0.0
			if current.distance_to(target) < 0.32:
				world.set_player_position(target)
				if not walk_waypoints.is_empty():
					destination = walk_waypoints.pop_front()
				else:
					walking = false
				if not walking and pending_refill:
					pending_refill = false
					var before_water: float = float(state.ClimateSystem.Operations.local(state).can)
					hud.show_farm_hint(state.ClimateSystem.Operations.refill(state))
					if float(state.ClimateSystem.Operations.local(state).can) > before_water:
						world._climate_field.loop.refill_time = 1.6
						_close_equipment()
					_save_checkpoint.call_deferred()
				elif not walking and not pending_project.is_empty():
					project_work_left = 0.6
					world.play_farm_effect([], "hoe")
				elif not walking and pending_plot >= 0:
					perform_plot(pending_plot, pending_tool)
					pending_plot = -1
			else:
				var move_speed: float = (WALK_SPEED + float(state.tools.get("harvest", 0)) * 0.8) * pace
				world.set_player_position(current.move_toward(target, move_speed * delta))
				moving = true
		hover_elapsed += delta
		if hover_elapsed > 0.08:
			hover_elapsed = 0.0
			_update_hover()
	world.animate(delta, moving, sprint_blend if moving else 0.0)
	if _tutorial_active():
		tutorial.update(delta)
	ui_elapsed += delta
	if ui_elapsed > 0.2:
		ui_elapsed = 0.0
		if _hud_update_frame != Engine.get_process_frames():
			hud.update_state(state)
		world.set_activity_state(activities.info())
		world.visuals.sync_state(state)
	save_elapsed += delta
	if save_elapsed >= 10.0 and not test_mode:
		state.save_game()
		save_elapsed = 0.0
	if not tutorial_notes.is_empty():
		tutorial_note_clock -= delta
		if tutorial_note_clock <= 0.0:
			_play_tone(tutorial_notes.pop_front(), 0.11)
			tutorial_note_clock = 0.14

func _apply_graphics_quality(mode: String, persist: bool = false) -> void:
	if mode not in GraphicsPreferences.MODES:
		return
	graphics_quality = mode
	world.set_graphics_quality(mode)
	farm_viewport.set_quality(mode)
	hud.set_graphics_quality(mode)
	if persist and not test_mode:
		if GraphicsPreferences.save_mode(mode) != OK:
			hud.show_toast("Graphics changed. This browser could not save the preference.")

func _set_shadow_size(size: int, persist: bool = false) -> void:
	if size not in [2048, 4096]: return
	if is_instance_valid(touch_controls) and touch_controls.enabled: size = mini(size, 2048)
	shadow_size = size
	# Keep Compatibility filtering stable when the editor drops default overrides.
	for key in ["rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile"]:
		ProjectSettings.set_setting(key, RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	if persist and not test_mode: GraphicsPreferences.save_shadow_size(size)
	if hud._panel_kind == "graphics": hud._refresh_graphics()

func _simulation_delta(delta: float) -> float:
	if not is_finite(delta) or delta <= 0.0: return 0.0
	if is_instance_valid(hud) and hud.is_panel_open() and hud._panel_kind == "debug": return 0.0
	var multiplier: float = debug_time_multiplier if debug_unlocked else 1.0
	if state.guided_first_year():
		# Draw the Summer warning before choosing the frame's speed.
		if state.season_clock.seconds == 0.0 and state._tutorial_clock_running(): state.climate.start_season(state)
		multiplier = 1.0
	return minf(delta * multiplier, MAX_ACCELERATED_STEP if debug_unlocked and debug_time_multiplier > 1.0 else 3600.0)

func _advance_simulation(delta: float) -> void:
	if state.run_over or state.accounts_open or state.climate_report_open or state.ClimateSystem.Lesson.active(state): return
	var remaining: float = delta
	while remaining >= 0.000001:
		var season_before: int = state.season_clock.season
		var fast_guide: bool = state.guided_first_year() and tutorial.current_id() == "grow" and state.climate.data.phase == "calm"
		var step: float = minf(remaining, state.season_clock.remaining(state.season_seconds()))
		if state.climate.clock_running(state): step = minf(step, state.climate.next_boundary())
		state.update(step)
		if state.run_over or state.accounts_open or state.climate_report_open or not state._tutorial_clock_running(): return
		# Excess accelerated time cannot spill into the first storm warning.
		if fast_guide and season_before != state.season_clock.season: return
		remaining = maxf(0.0, remaining - step)

func _advance_winter_sleep() -> void:
	var started: int = Time.get_ticks_usec()
	_updating_simulation = true
	for iteration in range(256):
		if not state.can_sleep_until_spring():
			sleeping_until_spring = false
			break
		if state.winter_sleep_step(3.0):
			sleeping_until_spring = false
			break
		if Time.get_ticks_usec() - started >= 4000: break
	_updating_simulation = false
	if _simulation_changed:
		_simulation_changed = false
		_on_state_changed()

func _on_panel_opened(kind: String) -> void:
	var keeper: String = state.NpcRoster.for_station(kind)
	if not keeper.is_empty() and is_instance_valid(conversation): conversation.voice.begin_page(keeper)
	if kind == "accounts":
		feedback_audio.play_paper()
		if _accounts_camera_from < 0: _accounts_camera_from = world.camera.size
		_accounts_camera_elapsed = 0.0

func _update_accounts_camera(delta: float) -> void:
	if _accounts_camera_from < 0: return
	if not state.accounts_open:
		world.camera.size = _zoom_target_size
		_accounts_camera_from = -1.0
		return
	_accounts_camera_elapsed = minf(0.6, _accounts_camera_elapsed + maxf(0.0, delta))
	var progress: float = _accounts_camera_elapsed / 0.6
	world.camera.size = lerpf(_accounts_camera_from, maxf(CAMERA_ZOOM_MIN, _accounts_camera_from * 0.965), smoothstep(0.0, 1.0, progress))

func _set_debug_session(unlocked: bool, error: String = "") -> void:
	debug_unlocked = unlocked
	if not unlocked:
		debug_time_multiplier = 1.0
	hud.set_debug_session(debug_unlocked, debug_time_multiplier, error)

func _debug_action(parts: PackedStringArray) -> void:
	if parts[1] == "unlock":
		if ":".join(parts.slice(2)) == DEBUG_ACCESS_CODE:
			_set_debug_session(true)
		else:
			_set_debug_session(false, "Incorrect code.")
		return
	if not debug_unlocked:
		return
	match parts[1]:
		"lock":
			_set_debug_session(false)
		"time":
			if parts.size() != 3 or not parts[2].is_valid_float():
				return
			var speed: float = float(parts[2])
			if speed not in DEBUG_TIME_SPEEDS:
				return
			debug_time_multiplier = speed
			hud.set_debug_session(true, speed)
		"apply":
			if parts.size() != 3:
				return
			# Invalid text must not silently become a zero-money multiplier.
			var parsed_money: Dictionary = HudScript.DebugMoneyInput.parse_number(parts[2])
			if parsed_money.has("error"):
				hud.show_toast(str(parsed_money.get("error", "Enter a valid money multiplier.")))
				return
			state.apply_debug(float(parsed_money["value"]))
			if not test_mode:
				state.save_game()
		"set_balance", "recover":
			if parts.size() != 3: return
			var amount: Dictionary = HudScript.DebugMoneyInput.parse_number(parts[2], state.MAX_MONEY)
			if amount.has("error"):
				hud.show_toast("Enter a non-negative test balance up to 1e300.")
				return
			if parts[1] == "recover":
				var ended: bool = state.run_over
				hud.show_toast(state.debug_recover(float(amount.value)))
				if ended and not state.run_over:
					debug_time_multiplier = 1.0
					hud.set_debug_session(true, 1.0)
					hud.close_panel()
					_on_state_changed()
			else:
				hud.show_toast(state.debug_set_balance(float(amount.value)))
			if not test_mode: state.save_game()
		"weather":
			if parts.size() == 3 and parts[2] in ["drought", "flood", "storm", "freeze"]:
				if state.climate.begin_warning(state, parts[2], 1.0): hud.close_panel()
				else: state._finish("Finish the current weather or lesson first.")
		"reset":
			debug_time_multiplier = 1.0
			hud.set_debug_session(true, 1.0)
			state.reset_debug()
			if not test_mode:
				state.save_game()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch:
		if not title_active() and not hud.is_panel_open(): world.tap_actor_at(farm_viewport.to_farm_position(event.position), event.pressed)
		elif not event.pressed: world.tap_actor_at(Vector2.ZERO, false)
	# Keep ownership when a drag crosses HUD controls or is released over them.
	if _map_drag_button == 0: return
	if not _map_navigation_allowed() or _map_drag_window_size != get_tree().root.size:
		_cancel_map_drag()
		if event is InputEventMouse: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		# The press owns this gesture until release (or focus/menu/resize
		# cancellation). A missing motion mask must not require another click.
		_map_drag_distance += event.relative
		if _map_drag_button != MOUSE_BUTTON_LEFT or _map_drag_moved:
			_pan_camera_by(event.relative)
		elif _map_drag_distance.length() >= 6.0:
			_map_drag_moved = true
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			_pan_camera_by(_map_drag_distance)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == _map_drag_button and not event.pressed:
			var tap: bool = _map_drag_button == MOUSE_BUTTON_LEFT and not _map_drag_moved and event.position.distance_to(_map_drag_origin) < 6.0
			var origin: Vector2 = _map_drag_origin
			_cancel_map_drag()
			if tap: _tap_world(origin)
		# A second mouse button during a pan must not farm or open a shop.
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if title_active(): return
	if is_instance_valid(epilogue_screen) or sleeping_until_spring: return
	if is_instance_valid(year_intro) and year_intro.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		touch_controls.toggle_fullscreen()
		return
	if is_instance_valid(conversation) and conversation.visible: return
	if touch_controls.enabled and event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if hud == null:
		return
	if state.run_over and state.run_outcome != "completed":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if not climate_target.is_empty() or not hud._climate_console.equipment.is_empty():
					_climate_action("cancel")
					return
				if hud.is_panel_open():
					hud.close_panel()
				else:
					_on_user_action("menu")
			KEY_I: _on_user_action("inventory")
			KEY_P: _on_user_action("dex")
			KEY_F: _on_user_action("barn")
			KEY_F1: _on_user_action("help")
			KEY_F5: _on_user_action("save")
			KEY_F9: _on_user_action("load")
			KEY_1: _select_tool("hoe")
			KEY_2: _select_tool("plant")
			KEY_3: _select_tool("water")
			KEY_4: _select_tool("harvest")
			KEY_5: _select_tool("pest")
			KEY_E, KEY_SPACE:
				if not hud.is_panel_open():
					_interact_nearby()
	if not _map_navigation_allowed():
		return
	if _handle_map_pan(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_map_zoom(event):
		get_viewport().set_input_as_handled()
		return
	if touch_controls.enabled:
		touch_controls.world_input(event)

func _tap_world(point: Vector2) -> void:
	var hit: Dictionary = world.pick(farm_viewport.to_farm_position(point))
	if hit.has("plot_index"):
		queue_plot(int(hit.plot_index))
	elif hit.has("duck_index"):
		feedback_audio.play_action("quack")
	elif hit.has("station"):
		_interact_station(str(hit.station))

func _interact_station(station: String) -> void:
	if title_active(): return
	hud.set_panel_source(station)
	if station.begins_with("project:"):
		_queue_project(station.trim_prefix("project:"))
	elif station.begins_with("equipment:"):
		_select_equipment(station.trim_prefix("equipment:"))
		if station == "equipment:tank": _queue_refill()
	else:
		_on_user_action(station)

func _on_user_action(action: String) -> void:
	if title_active() or conversation.visible: return
	if action in ["market", "barn", "tools", "duck_patrol", "climate", "quests", "accounts"]:
		if _tutorial_active() and not tutorial.allows_action(action): return
		var keeper: String = {"market":"mara", "barn":"nell", "tools":"bram", "duck_patrol":"pip", "climate":"iris", "quests":"tess", "accounts":"nell"}[action]
		_start_conversation(keeper, action, true)
		return
	_on_action(action)

func _start_conversation(id: String, requested_service: String = "", before_shop: bool = false) -> void:
	if title_active(): return
	if not state.NpcRoster.available(id, state) or (_tutorial_active() and not before_shop) or state.run_over: return
	var return_service: String = requested_service if not requested_service.is_empty() else state.NpcRoster.PEOPLE[id].service
	if id == "nell" and requested_service.is_empty(): return_service = "accounts"
	if id == "edwin": return_service = "accounts"
	hud.set_panel_source(return_service)
	_cancel_walk()
	_close_equipment()
	climate_target = ""
	hud._climate_console.targeting = ""
	touch_controls.release_all()
	touch_controls.drawer.hide()
	hud.close_panel()
	hud._climate_alert.dismiss()
	conversation.start(id, state, return_service, touch_controls.enabled, before_shop)
	_save_checkpoint.call_deferred()

func _finish_conversation(service: String) -> void:
	farm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	touch_controls.release_all()
	_save_checkpoint.call_deferred()
	if not service.is_empty(): _on_action(service)
	else: hud.update_state(state)

func _camera_zoom_max() -> float:
	return 90.0 * world.LAND_SPACING * maxf(1.0, world.overview_size() / 76.0)

func _reset_camera_zoom() -> void:
	_zoom_target_size = clampf(world.camera.size, CAMERA_ZOOM_MIN, _camera_zoom_max())

func _reset_camera_view(new_overview: bool = false) -> void:
	_cancel_map_drag()
	if is_instance_valid(touch_controls): touch_controls.release_all()
	# Loading a save on the current island reuses its camera. Do not promote
	# the player's current pan/zoom into the new default overview.
	if not new_overview and _camera_home_id == world.camera.get_instance_id():
		_recenter_camera()
		world.camera.size = _camera_home_size
		return
	_camera_home_id = world.camera.get_instance_id()
	_camera_home_position = world.camera.global_position
	_camera_home_size = world.camera.size
	_camera_pan_offset = Vector3.ZERO
	_reset_camera_zoom()

func _recenter_camera() -> void:
	_cancel_map_drag()
	_camera_pan_offset = Vector3.ZERO
	world.camera.global_position = _camera_home_position
	world.fit_camera_depth()
	_zoom_target_size = clampf(_camera_home_size, CAMERA_ZOOM_MIN, _camera_zoom_max())

func _map_navigation_allowed() -> bool:
	return not title_active() and is_instance_valid(hud) and not hud.is_panel_open() and not state.run_over and not (is_instance_valid(conversation) and conversation.visible) and not (is_instance_valid(touch_controls) and touch_controls.drawer.visible)

func _stop_map_navigation() -> void:
	_cancel_map_drag()
	if is_instance_valid(world) and is_instance_valid(world.camera):
		_camera_pan_offset = world.camera.global_position - _camera_home_position

func _cancel_map_drag() -> void:
	if _map_drag_button != 0: Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_map_drag_button = 0

func _handle_map_pan(event: InputEvent) -> bool:
	if not _map_navigation_allowed(): return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_HOME:
		_recenter_camera()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_map_drag_button = event.button_index
		_map_drag_origin = event.position
		_map_drag_distance = Vector2.ZERO
		_map_drag_moved = false
		_map_drag_window_size = get_tree().root.size
		if event.button_index != MOUSE_BUTTON_LEFT: Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return true
	if event is InputEventPanGesture:
		if not event.delta.is_finite(): return false
		_pan_camera_by(-event.delta * CAMERA_TRACKPAD_PAN)
		return true
	return false

func _camera_pan_limit() -> Vector2:
	# The view's focus stays over the island, even at the closest zoom.
	return (Vector2(28, 22) if world.current_island == 3 else (Vector2(23, 18) if world.current_island == 2 else Vector2(39, 17))) * world.LAND_SPACING

func _pan_camera_by(screen_delta: Vector2) -> void:
	if not screen_delta.is_finite() or screen_delta.is_zero_approx() or not is_instance_valid(world.camera): return
	# Ground-plane projection preserves the angle/height and tracks the pointer
	# exactly, including when the 3D viewport renders below display resolution.
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var from: Vector2 = farm_viewport.to_farm_position(center)
	var to: Vector2 = farm_viewport.to_farm_position(center + screen_delta)
	var ground := Plane(Vector3.UP, 0.0)
	var start: Variant = ground.intersects_ray(world.camera.project_ray_origin(from), world.camera.project_ray_normal(from))
	var finish: Variant = ground.intersects_ray(world.camera.project_ray_origin(to), world.camera.project_ray_normal(to))
	if start == null or finish == null: return
	_camera_pan_offset += Vector3(start) - Vector3(finish)
	var limit: Vector2 = _camera_pan_limit()
	_camera_pan_offset.x = clampf(_camera_pan_offset.x, -limit.x, limit.x)
	_camera_pan_offset.y = 0.0
	_camera_pan_offset.z = clampf(_camera_pan_offset.z, -limit.y, limit.y)

func _update_camera_pan(delta: float) -> void:
	if not is_instance_valid(world.camera) or not is_finite(delta) or delta <= 0.0: return
	if not _map_navigation_allowed():
		_stop_map_navigation()
		return
	# Input sets the destination; rendered frames follow it smoothly. Exponential
	# damping is frame-rate independent and cannot overshoot a release or reversal.
	var target: Vector3 = _camera_home_position + _camera_pan_offset
	world.camera.global_position = world.camera.global_position.lerp(target, 1.0 - exp(-CAMERA_PAN_RESPONSE * minf(delta, 0.1)))
	if world.camera.global_position.distance_squared_to(target) < 0.00000001:
		world.camera.global_position = target
	world.fit_camera_depth()

func _handle_map_zoom(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture:
		if not is_finite(event.factor) or event.factor <= 0.0:
			return false
		# A spread-out pinch magnifies the map, reducing its orthographic span.
		_zoom_by_log_amount(-log(event.factor))
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not is_finite(event.factor):
			return false
		# High-resolution wheels/trackpads supply fractions; older mice use 0.
		var amount: float = absf(event.factor) if event.factor != 0.0 else 1.0
		_zoom_by_log_amount(amount * CAMERA_SCROLL_STEP * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
		return true
	return false

func _zoom_by_log_amount(amount: float) -> void:
	if not is_finite(amount):
		return
	_zoom_target_size = clampf(_zoom_target_size * exp(clampf(amount, -3.0, 3.0)), CAMERA_ZOOM_MIN, _camera_zoom_max())

func _update_camera_zoom(delta: float) -> void:
	if is_instance_valid(world.camera):
		var overview: float = world.overview_size()
		if not is_equal_approx(overview, _camera_home_size):
			var ratio: float = overview / _camera_home_size
			world.camera.size *= ratio
			_zoom_target_size *= ratio
			_camera_home_size = overview
	_update_camera_pan(delta)
	# Letterboxing can resize the window without changing logical viewport size.
	if _map_drag_button != 0 and (not _map_navigation_allowed() or _map_drag_window_size != get_tree().root.size): _cancel_map_drag()
	if not is_instance_valid(world.camera) or not is_finite(delta) or delta <= 0.0:
		return
	_zoom_target_size = clampf(_zoom_target_size, CAMERA_ZOOM_MIN, _camera_zoom_max())
	world.camera.size = lerpf(world.camera.size, _zoom_target_size, 1.0 - exp(-CAMERA_ZOOM_RESPONSE * minf(delta, 0.25)))
	if absf(world.camera.size - _zoom_target_size) < 0.0001:
		world.camera.size = _zoom_target_size

func _clamp_destination(point: Vector3) -> Vector3:
	return world.clamp_walk_position(point)

func _start_walk(point: Vector3) -> void:
	walk_waypoints = world.walk_route(world.player.position, point)
	destination = walk_waypoints.pop_front()
	walking = true

func _cancel_walk() -> void:
	sprint_blend = 0.0
	pending_tool = selected_tool
	pending_refill = false
	pending_project = ""
	project_work_left = 0.0
	walking = false
	pending_plot = -1
	walk_waypoints.clear()
	hover_plot = -1
	if world != null:
		world.highlight_tiles(NO_TILES)

func _select_tool(tool: String) -> void:
	world.set_meta("water_tool", tool == "water")
	climate_target = ""
	hud._climate_console.targeting = ""
	hud._climate_console.tool = tool
	if _tutorial_active() and not tutorial.allows_tool(tool):
		tutorial.explain_block()
		return
	if tool not in ["hoe", "plant", "water", "harvest", "pest"]:
		return
	selected_tool = tool
	hud.set_tool(tool)
	if not hud.is_panel_open():
		_update_hover()

func queue_plot(index: int) -> void:
	_close_equipment()
	pending_refill = false
	if state.run_over: return
	if not climate_target.is_empty():
		_climate_choose(index)
		return
	if _tutorial_active() and not tutorial.allows_plot(index, selected_tool):
		tutorial.explain_block()
		return
	if index < 0 or index >= state.plots.size():
		return
	hud.note_farm_action()
	if not state.plots[index].unlocked and not state.ClimateSystem.Lesson.active(state):
		hud.show_farm_hint(preload("res://scripts/farm_advice.gd").locked(state, index))
		return
	var bed: Dictionary = state.plots[index]
	if int(bed.stage) in [1, 2]:
		var speed: float = state.crop_growth_speed(str(bed.crop)) * (1.0 if bed.watered else state.DRY_GROWTH_SPEED)
		var remaining: int = ceili(maxf(0, float(state.CropTable.CROPS[bed.crop].grow) - float(bed.elapsed)) / speed)
		hud.show_farm_hint("Ready in %d s" % remaining)
	pending_plot = index
	pending_tool = selected_tool
	_start_walk(world.plot_positions[index] + Vector3(0.0, 0.0, 0.65))
	_preview_area(index, pending_tool)

func perform_plot(index: int, tool: String = "hoe") -> void:
	if state.run_over:
		return
	if _tutorial_active() and not tutorial.allows_plot(index, tool):
		tutorial.explain_block()
		return
	if index < 0 or index >= state.plots.size():
		return
	var action: String = tool
	var indices: Array[int] = state.affected_tiles(index, action)
	var before: Array[Dictionary] = []
	var lesson_before: String = state.climate.data.lesson.stage
	var ice_before: Dictionary = state.climate.data.operations.ice.duplicate()
	var danger_before: Dictionary = state.climate.data.operations.stress.duplicate()
	for tile in indices:
		before.append(state.plots[tile].duplicate(true))
	hud.note_farm_action()
	_working_plot = true
	var result: String = state.interact_plot(index, tool)
	_working_plot = false
	var changed_indices: Array[int] = []
	var harvest_snapshots: Dictionary = {}
	for step in range(indices.size()):
		var tile: int = indices[step]
		if ice_before.has(str(tile)) != state.climate.data.operations.ice.has(str(tile)) or before[step] != state.plots[tile] or float(danger_before.get(str(tile), 0.0)) != float(state.climate.data.operations.stress.get(str(tile), 0.0)):
			changed_indices.append(tile)
			if action == "hoe" and (ice_before.has(str(tile)) or bool(before[step].get("winter_ice",false))) and not (state.climate.data.operations.ice.has(str(tile)) or bool(state.plots[tile].get("winter_ice",false))):
				world.visuals.break_ice(tile)
			if action == "harvest" and int(before[step].stage) == 3:
				harvest_snapshots[tile] = before[step]
	if lesson_before == "water" and state.climate.data.lesson.stage == "area": changed_indices.append(index)
	if changed_indices.is_empty():
		if _tutorial_active(): hud.show_tutorial_feedback(result)
		else: hud.show_farm_hint(result)
	if not changed_indices.is_empty():
		hud.clear_farm_hint()
		if tool == "harvest" and state.storage_used() >= state.capacity:
			hud.show_farm_hint("Barn full. Open the barn to sell.")
		world.play_farm_effect(changed_indices, action, int(state.tools.get("hoe" if action == "plant" else action, 0)), harvest_snapshots)
	if _tutorial_active():
		tutorial.update(0.0)
	if not harvest_snapshots.is_empty():
		state.graded_harvests += 1
		if state.graded_harvests == 1:
			hud.show_panel("grades", state)
		_save_checkpoint.call_deferred()

func _interact_nearby() -> void:
	if hud.is_panel_open() or state.run_over: return
	if world.player.position.distance_to(world._climate_field.loop.tank_position() + Vector3(-0.4, 0, 2.3)) <= 2.0:
		_select_equipment("tank")
		_queue_refill()
		return
	var station: Dictionary = world.nearby_station()
	if not station.is_empty() and climate_target.is_empty():
		_interact_station(str(station.station))
		return

	var nearest: int = -1
	var distance: float = 2.8
	for index in range(world.plot_positions.size()):
		var candidate: float = world.player.position.distance_to(world.plot_positions[index])
		if candidate < distance:
			distance = candidate
			nearest = index
	if nearest >= 0:
		_cancel_walk()
		if not climate_target.is_empty(): _climate_choose(nearest)
		elif state.ClimateSystem.Protection.can_cover(state, nearest): _on_action("cover_bed:%d" % nearest)
		else: perform_plot(nearest, selected_tool)
	else:
		hud.show_farm_hint("Click a bed, or move closer to use E")

func bed_context() -> Dictionary:
	var nearest: int = -1
	var distance: float = 2.8
	for index in range(world.plot_positions.size()):
		var candidate: float = world.player.position.distance_to(world.plot_positions[index])
		if candidate < distance:
			distance = candidate
			nearest = index
	if state.ClimateSystem.Protection.can_cover(state, nearest):
		return {"plot_index": nearest, "point": world.plot_positions[nearest] + Vector3(0, 1.4, 0)}
	return {}

func _preview_area(index: int, tool: String) -> void:
	if not hud._climate_console.equipment.is_empty():
		var id: String = hud._climate_console.equipment
		var tiles: Array[int] = []
		if id.begins_with("sprinkler") or id == "trees":
			var patch: int = 0 if id == "trees" else int(id.trim_prefix("sprinkler"))
			for i in range(state.plots.size()):
				if state.ClimateSystem.Operations.zone(i) == patch: tiles.append(i)
		world.highlight_tiles(tiles)
		return
	if not climate_target.is_empty():
		var target_index: int = 35 if state.ClimateSystem.Lesson.active(state) or index < 0 else index
		var chosen: int = state.ClimateSystem.Operations.zone(target_index)
		var tiles: Array[int] = []
		for i in range(state.plots.size()):
			if state.ClimateSystem.Operations.zone(i) == chosen: tiles.append(i)
		world.highlight_tiles(tiles)
		return
	if state.ClimateSystem.Lesson.active(state):
		var practice_tiles: Array[int] = []
		practice_tiles.assign([34] if state.climate.data.lesson.stage == "water" else ([35, 36] if state.climate.data.lesson.stage == "area" else []))
		world.highlight_tiles(practice_tiles)
		return
	if index >= 0:
		world.highlight_tiles(state.affected_tiles(index, tool))
	else:
		world.highlight_tiles(NO_TILES)

func _update_hover() -> void:
	_update_hover_at(get_viewport().get_mouse_position())

func _update_hover_at(screen_position: Vector2) -> void:
	var hit: Dictionary = world.pick(farm_viewport.to_farm_position(screen_position))
	hover_plot = int(hit.get("plot_index", -1))
	_preview_area(pending_plot if walking and pending_plot >= 0 else hover_plot, pending_tool if walking else selected_tool)
	if not climate_target.is_empty():
		hud.set_context("Click the highlighted beds · Esc cancels")
		return
	if state.ClimateSystem.Lesson.active(state):
		hud.set_context("Water the glowing practice bed [3]" if state.climate.data.lesson.stage == "water" else "Click the near sprinkler to water its connected beds")
		return
	var context_text: String = ""
	if hover_plot >= 0:
		var plot: Dictionary = state.plots[hover_plot]
		var action: String = selected_tool
		if state.climate.data.phase == "active" and float(state.climate.data.operations.stress.get(str(hover_plot), 0)) > 0.1:
			context_text = "Danger %d%% · %s" % [roundi(float(state.climate.data.operations.stress[str(hover_plot)]) * 100), "Water [3] rescues this bed" if state.climate.data.event == "drought" else ("Hoe [1] drains this bed" if state.climate.data.event == "flood" else "Hoe [1] clears ice" if state.climate.data.event == "freeze" else "Harvest ripe crops before the next strike")]
		elif bool(plot.get("frozen", false)):
			context_text = "Frozen bed · Press 1, then click to break ice"
		elif state.ClimateSystem.Protection.can_cover(state, hover_plot):
			context_text = "Cleared bed · Walk beside it, then E / Cover bed to place a frost cover"
		elif bool(plot.get("pests", false)):
			context_text = "Tap the sprayer, then the bed with bugs."
		elif not plot.unlocked:
			context_text = preload("res://scripts/farm_advice.gd").locked(state, hover_plot)
		elif int(plot.stage) == 3:
			context_text = "%s is ripe · Click to %s" % [str(plot.crop).capitalize(), action]
		elif int(plot.stage) in [1, 2] and not bool(plot.watered):
			context_text = "Dry · growing slowly"
		elif int(plot.stage) > 0 and bool(plot.watered):
			var seconds: float = maxf(0.0, (float(state.CropTable.CROPS[str(plot.crop)].grow) - float(plot.elapsed)) / state.crop_growth_speed(str(plot.crop)))
			context_text = "Ready in %d s" % ceili(seconds)
		else:
			var area: int = state.affected_tiles(hover_plot, action).size()
			context_text = "%s · Click to work %d bed%s" % [action.capitalize(), area, "" if area == 1 else "s"]
	elif hit.has("station"):
		if str(hit.station).begins_with("project:"):
			hud.set_context("Winter construction · Click to walk and work")
			return
		if str(hit.station).begins_with("equipment:"):
			var id: String = str(hit.station).trim_prefix("equipment:")
			hud.set_context("Tank · Click to walk over and refill" if id == "tank" else ("Sprinkler · Click to see its connected beds" if id.begins_with("sprinkler") else "Click to see how this protects your farm"))
			return
		var descriptions: Dictionary = {"market": "Mara’s stall · Tap to buy seeds", "barn": "Barn · Tap to sell or store", "quests": "Quests · Click for challenges", "tools": "Tools · Tap to upgrade", "climate": "Farm protection · Click to view upgrades"}
		descriptions["duck_patrol"] = "Ducks · Click to hire pest patrol"
		descriptions["tools"] = "Tools · Click to upgrade"
		context_text = descriptions.get(str(hit.station), "TATERLAND")
	else:
		context_text = ""
	var quality_index: int = hover_plot
	if quality_index < 0:
		var near_distance: float = 2.8
		for i in range(state.plots.size()):
			var distance: float = world.player.position.distance_to(world.plot_positions[i])
			if int(state.plots[i].stage) > 0 and distance < near_distance:
				near_distance = distance; quality_index = i
	world.show_grade(quality_index, state.plots[quality_index] if quality_index >= 0 else {})
	if quality_index >= 0 and int(state.plots[quality_index].stage) > 0:
		var quality: String = state.Quality.description(state.plots[quality_index])
		context_text = (context_text + " · " if hover_plot >= 0 else "") + "Grade: " + quality
	hud.set_context(context_text)

func _on_state_changed() -> void:
	# Activity boundaries and market ticks can signal within the same update.
	# Paint their final result once; direct player actions still refresh at once.
	if _updating_simulation:
		_simulation_changed = true
		return
	# Loading/resetting state can end a guide session without completing it.
	# Drop its controller/UI lock too, so an older winter save remains playable.
	if is_instance_valid(tutorial) and tutorial.active and not state.tutorial_active:
		tutorial.active = false
		hud.set_tutorial({})
		world.set_tutorial_focus("", true)
	if world != null:
		world.set_bank_visit(state.NpcRoster.available("edwin", state))
		world.update_plots(state.ClimateSystem.Lesson.preview(state) if state.ClimateSystem.Lesson.active(state) else state.plots)
		world.set_decorations(state.decorations)
		world.set_climate(state.climate_info())
		world.set_activity_state(activities.info())
		world.visuals.sync_state(state)
		world.set_calendar(state.season_clock.year, state.season_clock.season, state.calendar_light_seconds(), state.climate.data.outlook.signal)
	if hud != null:
		hud.update_state(state)
		_hud_update_frame = Engine.get_process_frames()

func _update_weather_shake(delta: float) -> void:
	weather_shake_clock += delta
	var amplitude: float = 0.0
	climate_shake = move_toward(climate_shake, 0.0, delta * 0.25)
	var weather: Dictionary = state.climate_info()
	if weather.phase == "active" and weather.event == "storm":
		amplitude += float(weather.severity) * 0.075 * (0.2 + 0.8 * pow(maxf(0.0, sin(weather_shake_clock * 1.7)), 3.0))
	amplitude = minf(0.26, amplitude + climate_shake)
	world.camera.h_offset = sin(weather_shake_clock * 43.0) * amplitude
	world.camera.v_offset = sin(weather_shake_clock * 57.0 + 0.8) * amplitude * 0.6

func _climate_choose(index: int) -> void:
	var action: String = climate_target
	var before: float = float(state.ClimateSystem.Operations.local(state).water)
	var result: String = state.ClimateSystem.Operations.target(state, index, action)
	if action == "shelter" or float(state.ClimateSystem.Operations.local(state).water) < before:
		climate_target = ""
		hud._climate_console.targeting = ""
		if action == "water":
			var tiles: Array[int] = []
			for i in range(state.plots.size()):
				if state.ClimateSystem.Operations.zone(i) == state.ClimateSystem.Operations.zone(index): tiles.append(i)
			world.play_farm_effect(tiles, "water")
	world.set_climate(state.climate_info())
	hud.show_farm_hint(result)
	hud.update_state(state)
	_save_checkpoint.call_deferred()

func _climate_action(action: String) -> void:
	match action:
		"refill": _queue_refill()
		"close_equipment": _close_equipment()
		"show_sprinkler": _select_equipment("sprinkler2")
		"show_trees": _select_equipment("trees")
		"show_drain": _select_equipment("drain")
		"use_sprinkler":
			var patch: int = int(hud._climate_console.equipment.trim_prefix("sprinkler"))
			for i in range(state.plots.size()):
				if state.ClimateSystem.Operations.zone(i) != patch: continue
				var before: float = float(state.ClimateSystem.Operations.local(state).water)
				hud.show_farm_hint(state.ClimateSystem.Operations.target(state, i, "water"))
				if float(state.ClimateSystem.Operations.local(state).water) < before:
					world._climate_field.loop.flow_patch = patch
					world._climate_field.loop.flow_time = 2.5
					_close_equipment()
				break
		"lesson_start":
			_close_equipment()
			_cancel_walk()
			state.ClimateSystem.Lesson.start(state)
			_select_tool("water")
			hud.close_panel()
		"lesson_skip":
			_close_equipment()
			state.ClimateSystem.Lesson.finish(state)
			climate_target = ""
		"target_water", "target_shelter":
			climate_target = "water" if action == "target_water" else "shelter"
			_cancel_walk()
			hud.close_panel()
		"cancel":
			climate_target = ""
			_close_equipment()
		_:
			state.ClimateSystem.Operations.operate(state, action)
			if action == "gates": _close_equipment()
	hud._climate_console.targeting = climate_target
	world.set_climate(state.climate_info())
	_preview_area(-1, selected_tool)
	hud.update_state(state)
	_save_checkpoint.call_deferred()

func _on_action(action: String) -> void:
	if title_active():
		return
	if action.begins_with("debug:"): epilogue_result.clear()
	if is_instance_valid(year_intro) and year_intro.visible: return
	if is_instance_valid(conversation) and conversation.visible: return
	if state.ClimateSystem.Lesson.active(state) and not action.begins_with("climate_operate:") and action not in ["save", "pause", "help", "menu", "measure_year", "measurement", "measurement_copy"] and not action.begins_with("graphics"):
		state.ClimateSystem.Lesson.finish(state)
		climate_target = ""
	if not action.begins_with("climate_operate:"):
		_close_equipment()
		climate_target = ""
		hud._climate_console.targeting = ""
	if state.run_over and action not in (["reset", "debug", "close", "menu", "pause", "accounts", "run_summary", "epilogue", "measurement", "measurement_copy"] if state.run_outcome == "completed" else ["reset", "debug", "close", "measurement", "measurement_copy"]) and not action.begins_with("debug:"):
		return
	if action.begins_with("farm_help:"):
		_farm_help_action(action.get_slice(":", 1))
		return
	if action.begins_with("tutorial:"):
		match action.get_slice(":", 1):
			"next": tutorial.next()
			"skip": tutorial.finish()
			"restart": tutorial.start(true)
		return
	if _tutorial_active() and not tutorial.allows_action(action):
		tutorial.explain_block()
		return
	var parts: PackedStringArray = action.split(":")
	match parts[0]:
		"measure_year":
			if frame_recorder.start():
				hud.close_panel()
				hud.show_toast("Recording until the next Winter accounts close.")
		"measurement_copy": frame_recorder.copy_report()
		"measurement":
			if not frame_recorder.report_text.is_empty(): hud.show_panel("measurement", state)
		"shadows":
			if parts.size() == 2: _set_shadow_size(int(parts[1]), true)
		"sleep_spring":
			if state.can_sleep_until_spring(): hud.show_panel("sleep_confirm", state)
		"confirm_sleep_spring":
			if hud._panel_kind == "sleep_confirm" and state.can_sleep_until_spring():
				hud.close_panel()
				_cancel_walk()
				touch_controls.release_all()
				sleeping_until_spring = true
				hud.show_farm_hint("Sleeping until Spring…")
		"talk":
			if parts.size() == 2: _start_conversation(parts[1])
		"decorate":
			if hud._panel_kind == "tools" and parts.size() == 3:
				state.buy_decoration(parts[1], int(parts[2]))
				_save_checkpoint.call_deferred()
		"farmer": hud.show_panel("farmer", state)
		"quieter":
			SoundMix.quieter = not SoundMix.quieter
			if not test_mode: SoundMix.save_preference()
			hud.show_panel("pause", state)
		"graphics":
			if parts.size() == 2:
				_apply_graphics_quality(parts[1], true)
			elif parts.size() == 1:
				_cancel_walk()
				hud.show_panel("graphics", state)
		"menu", "calendar", "grades", "market", "barn", "inventory", "tools", "help", "pause", "dex", "quests", "duck_patrol", "debug", "climate", "accounts", "run_summary":
			if parts[0] == "debug" and parts.size() > 1:
				_debug_action(parts)
				return
			if parts[0] == "run_summary" and state.run_outcome != "completed": return
			_cancel_walk()
			hud.show_panel(parts[0], state)
		"activity":
			if parts.size() < 2:
				return
			match parts[1]:
				"duck":
					if parts.size() == 3 and parts[2] == "speed":
						activities.train_ducks()
					else:
						activities.hire_duck()
			if not test_mode:
				state.save_game()
		"climate_operate":
			if parts.size() == 2:
				_climate_action(parts[1])
				_save_checkpoint.call_deferred()
		"insure": state.ClimateSystem.Protection.insure(state)
		"cover_all":
			state.ClimateSystem.Protection.cover_all(state)
			_save_checkpoint.call_deferred()
		"cover_bed":
			var target: Dictionary = bed_context()
			if parts.size() == 2 and not target.is_empty() and int(parts[1]) == int(target.plot_index):
				state.ClimateSystem.Protection.cover(state, int(target.plot_index))
				_save_checkpoint.call_deferred()
		"station_upgrade": state.ClimateSystem.Protection.upgrade_station(state)
		"winter_walk":
			if state.season_clock.season != 3 or state.accounts_open: return
			for index in range(state.plots.size()):
				if not state.plots[index].unlocked: continue
				var match_bed: bool = state.ClimateSystem.Operations.frozen(state, index) if parts[1] == "ice" else state.plots[index].crop == "icecap" and state.plots[index].stage == 3
				if match_bed:
					hud.close_panel()
					_select_tool("hoe" if parts[1] == "ice" else "harvest")
					queue_plot(index)
					break
		"project_site": _queue_project(parts[1])
		"climate_fund":
			if parts.size() == 2:
				state.climate.fund(state, parts[1])
				_save_checkpoint.call_deferred()

		"stored_sell":
			if hud._panel_kind == "barn" and hud._refs.market_page.stored_mode:
				state.trading.sell_stored(state, parts[1], int(parts[2]), parts[3])
				_save_checkpoint.call_deferred()
		"keep_seed":
			if hud._panel_kind == "barn": state.trading.keep_seed(state, parts[1], parts[2])
			_save_checkpoint.call_deferred()
		"contract_accept":
			state.trading.accept(state, int(parts[1]) if parts.size() > 1 else 0)
			_save_checkpoint.call_deferred()
		"diversify":
			if parts.size() == 2:
				state.diversification.buy(state, parts[1])
				hud.update_state(state)
				_save_checkpoint.call_deferred()
		"quest": state.claim_quest(parts[1])
		"epilogue": _show_epilogue()
		"close": hud.close_panel()
		"crop":
			state.select_crop(parts[1])
			_select_tool("plant")

		"tool": _select_tool(parts[1])
		"buy": state.buy_seeds(parts[1], int(parts[2]))
		"sell":
			if hud._panel_kind == "barn": state.sell_crop(parts[1], int(parts[2]), parts[3] if parts.size() > 3 else "")
		"upgrade":
			match parts[1]:
				"barn": state.upgrade_barn()
				"expansion":
					state.expand_field(parts[2] if parts.size() > 2 else "home")
					if hud._panel_kind == "accounts": hud.show_panel("accounts", state)
				_: state.upgrade_tool(parts[1])
		"lease":
			state.rent_field(parts[1], not state.land[parts[1]].rented)
			hud.show_panel("accounts", state)
		"save":
			if not test_mode:
				hud.show_toast("Farm saved. Your crops are tucked away." if state.save_game() else "Could not save. Check the available disk space.")
		"load":
			if not test_mode:
				_cancel_walk()
				hud.close_panel()
				var loaded: bool = state.load_game()
				if loaded:
					epilogue_result.clear()
					if state.run_outcome == "completed": hud.show_panel("run_summary", state)
					elif not state.run_over and state.season_clock.season == 3:
						if not state.tutorial_progress.completed: tutorial.start()
						hud.show_panel("accounts", state)
					elif not state.run_over and not bool(state.tutorial_progress.get("completed", false)):
						tutorial.start()
				hud.show_toast("Farm restored. The exchange is open." if loaded else "No readable farm save yet.")
		"reset":
			epilogue_result.clear()
			_cancel_walk()
			state.reset_game()
			_set_debug_session(false)
			world.set_player_position(Vector3(0, 0, 9))
			_select_tool("hoe")
			hud.close_panel()
			tutorial.start()
			if not test_mode:
				state.save_game()
	if _tutorial_active():
		tutorial.observe_action(action)

func _on_purchase_completed(receipt: Dictionary) -> void:
	if receipt.get("kind") == "climate" or (receipt.get("kind") == "tool" and receipt.get("id") == "water"):
		var id: String = {"rainwater": "tank", "irrigation": "sprinkler0", "drainage": "drain", "windbreaks": "trees", "water": "tank"}.get(str(receipt.id), "barn")
		_select_equipment.call_deferred(id, true)
	hud.show_purchase(receipt)
	_play_tone(740.0, 0.12)
	if _tutorial_active():
		tutorial.observe_purchase(receipt)

func _on_climate_changed(phase: String) -> void:
	if phase in ["calm", "recovery"]:
		climate_target = ""
		hud._climate_console.targeting = ""
	var info: Dictionary = state.climate_info()
	if phase in ["warning", "impact", "recovery"]:
		if phase == "warning" and state.guided_first_year():
			# Iris's persistent guide already gives this warning on small screens.
			hud._climate_alert.dismiss()

		else:
			hud._climate_alert.present(phase, info, state)
		_play_tone(164.81 if phase == "impact" else 220.0, 0.6)
	if is_instance_valid(climate_audio):
		climate_audio.set_weather(info, state.run_over)
		if phase in ["impact", "strike"]: climate_audio.impact()
	if phase == "impact":
		climate_shake = 0.22 if info.event != "drought" else 0.08
	world.set_climate(info)
	_save_checkpoint.call_deferred()

func _on_season_changed() -> void:
	_title_returned = false
	if state.season_clock.season == 0 and not state.run_over and not test_mode: _show_year_start()
	if state.season_clock.season == 3 and not state.run_over:
		state.accounts_open = true
		if _tutorial_active(): tutorial.update(0.0)
	_cancel_walk()
	_close_equipment()
	if (state.season_clock.season == 3):
		hud._climate_alert.dismiss()
	_on_state_changed()


func _on_run_ended() -> void:
	_cancel_walk()
	hud._climate_alert.dismiss()
	climate_shake = 0.0
	if is_instance_valid(climate_audio): climate_audio.guided = state.guided_first_year()
	if is_instance_valid(climate_audio): climate_audio.set_weather(state.climate_info(), true)
	pest_alert.update(0.0, 0)
	world.camera.h_offset = 0.0
	world.camera.v_offset = 0.0
	if state.run_outcome == "foreclosed": feedback_audio.play_foreclosure()
	seasonal_ambience.set_season(state.season_clock.season, true)
	_save_checkpoint.call_deferred()

func _save_checkpoint() -> void:
	if not test_mode and not title_active():
		state.save_game()

func _on_purchase_rejected(message: String) -> void:
	hud.show_toast(message)

func _on_notification(message: String) -> void:
	# Routine work, quotes and shipments are already visible in the field and HUD.
	# Keep interruptions for problems and milestones that need the player's attention.
	var lower: String = message.to_lower()
	if _working_plot:
		# Plot results use one quiet footer slot, never a second central toast.
		return
	for marker in ["quest complete", "could not", "couldn't", "cannot", "can't", "not enough", "need ", "needs ", "full", "seeds left", "no potatoes", "no readable", "damaged", "failed", "already collected", "emergency"]:
		if lower.contains(marker):
			hud.show_toast(message)
			return

func _on_reward(title: String, detail: String, rarity: String) -> void:
	if _tutorial_active():
		return
	hud.show_reward(title, detail, rarity)
	world.play_reward(rarity)
	feedback_audio.play_tone(880.0, 0.85, true)

func _on_pest_warning(_index: int, destroyed: bool) -> void:
	if _tutorial_active():
		return
	if is_instance_valid(pest_alert):
		pest_alert.notify_attack(destroyed)

func _tutorial_active() -> bool:
	return is_instance_valid(tutorial) and tutorial.active

func play_tutorial_cue(kind: String) -> void:
	# Short, warm notes guide progress without interrupting the field audio.
	match kind:
		"finish": tutorial_notes.assign([523.25, 659.25, 783.99, 1046.50])
		_: tutorial_notes.assign([523.25, 659.25])
	tutorial_note_clock = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_map_navigation()
		if is_instance_valid(touch_controls): touch_controls.release_all()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null and not test_mode and not title_active():
			state.save_game()
		get_tree().quit()

func _setup_sound() -> void:
	feedback_audio = preload("res://scripts/farm_audio.gd").new()
	feedback_audio.name = "FarmCues"
	add_child(feedback_audio)
	seasonal_ambience = preload("res://scripts/farm_ambience.gd").new()
	seasonal_ambience.name = "SeasonAmbience"
	add_child(seasonal_ambience)
	seasonal_ambience.set_season(state.season_clock.season, state.run_over)

func _play_tone(frequency: float, duration: float) -> void:
	feedback_audio.play_tone(frequency, duration)

func _farm_help_action(action: String) -> void:
	if _tutorial_active(): return
	var help = state.farm_help
	if action == "toggle":
		help.data.hidden = not bool(help.data.hidden) if help.data.enabled else false
		help.enable()
	elif action in ["act", "dismiss"]:
		var tip: Dictionary = hud._opened_farm_tip if hud._panel_kind == "farm_tip" else hud._farm_tip
		if tip.is_empty(): return
		if hud._panel_kind == "farm_tip": hud.close_panel()
		if action == "dismiss" or tip.action == "dismiss":
			help.dismiss(str(tip.id))
			hud._help_cooldown = 12.0
		else:
			# Browsing dismisses the suggestion; it never certifies understanding.
			if tip.id not in ["pests"]:
				help.dismiss(str(tip.id))
				hud._help_cooldown = 12.0
			_on_action(str(tip.action))
	hud.update_state(state)
	if action == "toggle" and hud.is_panel_open(): hud.show_panel("help", state)
	if not test_mode: state.save_game()

func _close_equipment() -> void:
	equipment_prompt_time = 0.0
	hud._climate_console.equipment = ""
	if is_instance_valid(world._climate_field): world._climate_field.loop.selected = ""

func _select_equipment(id: String, brief: bool = false) -> void:
	equipment_prompt_time = 10.0 if brief else 0.0
	_cancel_walk()
	hud.close_panel()
	hud._climate_console.equipment = id
	world._climate_field.loop.selected = id
	hud.update_state(state)
	_preview_area(-1, selected_tool)

func _queue_refill() -> void:
	_cancel_walk()
	pending_refill = true
	_start_walk(world._climate_field.loop.tank_position() + Vector3(-0.4, 0, 2.3))

func _update_equipment_card(delta: float = 0.0) -> void:
	if equipment_prompt_time > 0:
		equipment_prompt_time = maxf(0, equipment_prompt_time - delta)
		if equipment_prompt_time == 0 and not pending_refill: _close_equipment()
	var card = hud._climate_console
	var supply: Dictionary = state.ClimateSystem.Operations.local(state)
	if float(supply.can) < 1 and not supply.refilled and not empty_can_prompted and not hud.is_panel_open():
		empty_can_prompted = true
		_select_equipment("tank", true)
		hud.show_farm_hint("Can empty · Click the glowing tank to refill.")
	if touch_controls.enabled: return # Touch equipment lives in a scrollable drawer.
	if not card.equipment.is_empty():
		var point: Vector3 = world._climate_field.loop.equipment_position(card.equipment) + Vector3(0, 2.5, 0)
		var screen: Vector2 = world.camera.unproject_position(point) * get_viewport().get_visible_rect().size / Vector2(farm_viewport.size)
		var view: Vector2 = get_viewport().get_visible_rect().size
		var field_left: float = view.x
		for point_on_field in world.plot_positions:
			field_left = minf(field_left, world.camera.unproject_position(point_on_field).x * view.x / float(farm_viewport.size.x))
		# Keep the connected beds visible: card occupies the margin beside the farm.
		var left: float = clampf(minf(screen.x - card.size.x - 24, field_left - card.size.x - 18), 12, view.x - card.size.x - 12)
		var minimum_top: float = 112.0
		var maximum_top: float = view.y - card.size.y - 110
		if minimum_top > maximum_top:
			left = view.x - card.size.x - 22
			minimum_top = 112
		var top: float = clampf(screen.y - 45, minimum_top, maxf(minimum_top, maximum_top))
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = Vector2(left, top)
	else:
		card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		card.position = Vector2(get_viewport().get_visible_rect().size.x - card.size.x - 22, 112)

func _queue_project(id: String) -> void:
	if not state.climate.data.protection.pending.has(id) or state.season_clock.season != 3 or state.run_over: return
	hud.close_panel()
	_cancel_walk()
	pending_project = id
	_start_walk(world.ClimateProjects.site_position(world, id))
	hud.show_farm_hint("Walk to %s · one work action on arrival" % state.ClimateSystem.PROJECTS[id].name)

func _show_year_start() -> void:
	if not is_instance_valid(year_intro) or state.run_over or (state.tutorial_active and tutorial.current_id() != "welcome"): return
	_stop_map_navigation()
	_cancel_walk()
	hud.close_panel()
	state.climate_report_open = true
	year_intro.present(state)

func _show_epilogue() -> void:
	if state.run_outcome != "completed" or is_instance_valid(epilogue_screen): return
	_cancel_walk()
	seasonal_ambience.set_season(state.season_clock.season, true)
	hud.close_panel()
	hud.hide()
	touch_controls.hide()
	var layer := CanvasLayer.new()
	layer.name = "EpilogueLayer"
	layer.layer = 60
	add_child(layer)
	epilogue_screen = preload("res://scripts/epilogue_screen.gd").new()
	layer.add_child(epilogue_screen)
	epilogue_screen.setup(state, world, epilogue_result)
	epilogue_screen.finished.connect(func(): _close_epilogue(false))
	epilogue_screen.new_run.connect(func(): _close_epilogue(true))

func _close_epilogue(restart: bool) -> void:
	epilogue_result = epilogue_screen.result
	var old_camera: Transform3D = epilogue_screen.saved_camera_transform
	var old_size: float = epilogue_screen.saved_camera_size
	var layer: Node = epilogue_screen.get_parent()
	epilogue_screen = null
	remove_child(layer)
	layer.queue_free()
	world.restore_present()
	world.camera.transform = old_camera
	world.camera.size = old_size
	world.fit_camera_depth()
	_reset_camera_view()
	hud.show()
	touch_controls.show()
	_on_state_changed()
	if restart: _on_user_action("reset")
	else: hud.show_panel("run_summary", state)
