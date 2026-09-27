extends Node3D
## Hands-on farming, a live fictional crop exchange, and local earned-currency rolls.

const StateScript = preload("res://scripts/game_state.gd")
const WorldScript = preload("res://scripts/farm_world.gd")
const HudScript = preload("res://scripts/game_hud.gd")
const BuildsScript = preload("res://scripts/player_builds.gd")
const ActivitiesScript = preload("res://scripts/island_activities.gd")
const PestAlert = preload("res://scripts/pest_alert.gd")
const RewardFeedback = preload("res://scripts/reward_feedback.gd")
const TutorialScript = preload("res://scripts/first_island_tutorial.gd")
const GraphicsPreferences = preload("res://scripts/graphics_preferences.gd")
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
const FANFARE_NOTES: Array[float] = [523.25, 659.25, 783.99, 1046.5]
const STOCK_NOTES: Array[float] = [523.25, 659.25, 783.99, 1046.50, 783.99, 659.25, 1174.66, 1046.50]

var state
var world
var hud
var builds
var prize_target: bool = false
var activities
var selected_tool: String = "hoe"
var destination: Vector3 = Vector3.ZERO
var walking: bool = false
var sprint_blend: float = 0.0
var pending_plot: int = -1
var pending_ferry: bool = false
var walk_waypoints: Array[Vector3] = []
var pending_tool: String = "hoe"
var hover_plot: int = -1
var hover_elapsed: float = 0.0
var ui_elapsed: float = 0.0
var _hud_update_frame: int = -1
var _updating_simulation: bool = false
var _simulation_changed: bool = false
var _working_plot: bool = false
var save_elapsed: float = 0.0
var test_mode: bool = false
var sound_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var _silent_audio := PackedVector2Array()
var audio_phase: float = 0.0
var tone_frequency: float = 440.0
var tone_remaining: float = 0.0
var tone_length: float = 0.1
var sparkle_tone: bool = false
var rolling_request: bool = false
var roll_sound_elapsed: float = 0.0
var roll_sound_clock: float = 0.0
var last_frost_active: bool = false
var surge_live: bool = false
var surge_band: int = 0
var fanfare_remaining: float = 0.0
var fanfare_phase: float = 0.0
var fanfare_island: int = 1
var surge_beat_clock: float = 0.0
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
var rocket_cutscene: Control
var stock_music_time: float = 0.0
var stock_shake_clock: float = 0.0
var debug_unlocked: bool = false
var debug_time_multiplier: float = 1.0
var graphics_quality: String = "balanced"
var climate_audio: Node
var climate_target: String = ""
var pending_refill: bool = false
var empty_can_prompted: bool = false
var equipment_island: int = 0
var equipment_prompt_time: float = 0.0
var climate_shake: float = 0.0
var farm_viewport: SubViewport
var touch_controls
var conversation

func _ready() -> void:
	test_mode = "--integration-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()
	_register_inputs()
	state = StateScript.new()
	state.name = "FarmState"
	add_child(state)
	builds = BuildsScript.new()
	builds.name = "PlayerBuilds"
	builds.state = state
	state.build_system = builds
	add_child(builds)
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
	farm_viewport.add_child(world)
	world.build_world(state.current_island)
	_reset_camera_view()
	get_tree().root.size_changed.connect(_stop_map_navigation)
	get_tree().root.focus_exited.connect(_stop_map_navigation)
	world.set_day_time(state.elapsed)
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
	var cinema_layer := CanvasLayer.new()
	cinema_layer.name = "StockRocketCinema"
	cinema_layer.layer = 100
	add_child(cinema_layer)
	rocket_cutscene = load("res://scripts/stock_rocket_cutscene.gd").new()
	cinema_layer.add_child(rocket_cutscene)
	rocket_cutscene.finished.connect(_on_rocket_finished)
	hud.action_requested.connect(_on_user_action)
	hud.roll_revealed.connect(_on_roll_revealed)
	state.changed.connect(_on_state_changed)
	state.notified.connect(_on_notification)
	state.purchase_completed.connect(_on_purchase_completed)
	state.purchase_rejected.connect(_on_purchase_rejected)
	state.reward_received.connect(_on_reward)
	state.harvest_chain.connect(_on_chain)
	state.island_changed.connect(_on_island_changed)
	state.export_changed.connect(_on_export_changed)
	state.blind_resolved.connect(_on_blind_resolved)
	state.tax_boom_started.connect(_on_tax_boom)
	state.run_ended.connect(_on_run_ended)
	state.climate_changed.connect(_on_climate_changed)
	_setup_sound()
	climate_audio = load("res://scripts/climate_audio.gd").new()
	add_child(climate_audio)
	tutorial = TutorialScript.new()
	tutorial.name = "FirstIslandTutorial"
	add_child(tutorial)
	tutorial.setup(self)
	state.climate.on_arrival(state)
	_on_state_changed()
	state.activate_roll_boost()
	hud.set_tool(selected_tool)
	if not test_mode:
		if state.run_over:
			_on_run_ended()
		elif not bool(state.tutorial_progress.get("completed", false)) and state.current_island == 1:
			tutorial.start()
		elif returning:
			hud.show_toast("Your farm is restored. The market is open!")
	get_tree().auto_accept_quit = false

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
	if world == null or hud == null:
		return
	if state.run_over:
		_pump_audio()
		return
	if is_instance_valid(conversation) and conversation.visible:
		_pump_audio()
		return
	state.ClimateSystem.Lesson.tick(state, delta)
	if not climate_target.is_empty() and (state.current_island != world.current_island or (not state.ClimateSystem.Lesson.active(state) and (state.climate.data.phase not in ["warning", "active"] or state.current_island != int(state.climate.data.island)))):
		climate_target = ""
		hud._climate_console.targeting = ""
	if state.climate.data.intro_pending:
		_pump_audio()
		return
	if state.rocket_pending:
		_start_rocket_if_ready()
		return
	# Scale only the simulation. A capped accelerated step keeps short market
	# windows visible even after a slow frame; presentation stays in real time.
	var simulation_delta: float = _simulation_delta(delta)
	_updating_simulation = true
	_advance_simulation(simulation_delta)
	_updating_simulation = false
	if _simulation_changed:
		_simulation_changed = false
		_on_state_changed()
	if state.run_over:
		return
	if state.rocket_pending:
		_start_rocket_if_ready()
		return
	_update_equipment_card(delta)
	if prize_target:
		var ready: Dictionary = builds.professions.cultivation_info()
		if not ready.ready:
			_cancel_prize_target()
			hud.show_farm_hint(ready.reason)
	var climate_info: Dictionary = state.climate_info()
	world.set_climate(climate_info)
	world.set_day_time(state.elapsed)
	climate_audio.set_weather(climate_info, state.current_island, state.tutorial_active or state.run_over)
	_update_camera_zoom(delta)
	_update_stock_shake(delta)
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
			if prize_target and walking:
				hud.set_plot_action("Click a glowing crop · 1 compost · grows a giant potato with 3× yield.")
			walking = false
			pending_plot = -1
			pending_refill = false
			pending_ferry = false
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
				if not walking and pending_ferry:
					pending_ferry = false
					_on_user_action("island")
				elif not walking and pending_refill:
					pending_refill = false
					var before_water: float = float(state.ClimateSystem.Operations.local(state).can)
					hud.show_farm_hint(state.ClimateSystem.Operations.refill(state))
					if float(state.ClimateSystem.Operations.local(state).can) > before_water:
						world._climate_field.loop.refill_time = 1.6
						_close_equipment()
					_save_blind_checkpoint.call_deferred()
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
		world.set_export_state(state.export_active, state.export_timer)
		world.set_frost_state(state.frost_active, state.frost_timer)
		var activity: Dictionary = builds.activity_info()
		world.set_processing(bool(activity.processing), float(activity.progress))
		world.set_activity_state(activities.info())
		world.profession_world.refresh(builds, state)
	save_elapsed += delta
	if save_elapsed >= 10.0 and not test_mode:
		state.save_game()
		save_elapsed = 0.0
	if not tutorial_notes.is_empty():
		tutorial_note_clock -= delta
		if tutorial_note_clock <= 0.0:
			_play_tone(tutorial_notes.pop_front(), 0.11)
			tutorial_note_clock = 0.14
	_pump_audio()
	if hud.is_roll_animating():
		roll_sound_elapsed += delta
		roll_sound_clock -= delta
		if roll_sound_clock <= 0.0:
			_play_tone(270.0 + minf(3.0, roll_sound_elapsed) * 135.0, 0.025)
			roll_sound_clock = lerpf(0.055, 0.24, minf(1.0, roll_sound_elapsed / 3.0))
	elif surge_band > 0 and surge_band < 3 and fanfare_remaining <= 0.0:
		surge_beat_clock -= delta
		if surge_beat_clock <= 0.0 and tone_remaining < 0.1:
			_play_tone(196.0 if state.current_island == 1 else (246.94 if state.current_island == 2 else 329.63), 0.065)
			surge_beat_clock = 0.45 if surge_band == 1 else 0.30

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

func _simulation_delta(delta: float) -> float:
	if not is_finite(delta) or delta <= 0.0:
		return 0.0
	# Debug is a workbench: editing a test setup must not spend a tax cycle,
	# especially when the previous scenario left accelerated time enabled.
	if is_instance_valid(hud) and hud.is_panel_open() and hud._panel_kind == "debug": return 0.0
	var multiplier: float = debug_time_multiplier if debug_unlocked else 1.0
	var step: float = minf(delta * multiplier, MAX_ACCELERATED_STEP if multiplier > 1.0 else 3600.0)
	# State pauses exactly at a rocket boundary. Feed every simulation system
	# that same interval, including processing and its furnace heat bonus.
	if state.current_island >= 3 and not _tutorial_active():
		step = minf(step, maxf(0.000001, float(state.rocket_timer)))
	return step

func _advance_simulation(delta: float) -> void:
	if state.run_over or state.climate.data.intro_pending or state.ClimateSystem.Lesson.active(state):
		return
	if _tutorial_active():
		state.update(delta)
		return
	var remaining: float = delta
	while remaining >= 0.000001:
		var step: float = remaining
		# Fertilizer belongs to builds but affects State's crop growth. Expire it
		# at its own boundary, then consume the rest of this simulation interval.
		if builds.fertilizer > 0.0:
			step = minf(step, maxf(0.000001, float(builds.fertilizer)))
		if float(state.blind_cycle.due_in) > 0.0:
			step = minf(step, float(state.blind_cycle.due_in))
		if state.climate.clock_running(state): step = minf(step, float(state.climate.data.timer))
		var processing_step: float = activities.processing_time(step)
		state.update(step)
		if state.run_over:
			return
		builds.update(step, processing_step)
		remaining = maxf(0.0, remaining - step)
		if state.rocket_pending:
			return

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
			if parts.size() != 4:
				return
			# Invalid text must not silently become a zero-money multiplier.
			var parsed_money: Dictionary = HudScript.DebugMoneyInput.parse_number(parts[2])
			if parsed_money.has("error") or not parts[3].is_valid_float():
				hud.show_toast(str(parsed_money.get("error", "Enter a valid luck multiplier.")))
				return
			state.apply_debug(float(parsed_money["value"]), float(parts[3]))
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
			if parts.size() == 3 and parts[2] in ["drought", "flood", "storm"]:
				if state.climate.begin_warning(state, parts[2], 1.0): hud.close_panel()
				else: state._finish("Travel to Island 2 or 3 and wait for calm weather first.")
		"island":
			if parts.size() != 3 or not parts[2].is_valid_int(): return
			hud.show_toast(state.debug_unlock_island(int(parts[2])))
			if not test_mode: state.save_game()
		"reset":
			debug_time_multiplier = 1.0
			hud.set_debug_session(true, 1.0)
			state.reset_debug()
			if not test_mode:
				state.save_game()

func _input(event: InputEvent) -> void:
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		touch_controls.toggle_fullscreen()
		return
	if is_instance_valid(conversation) and conversation.visible: return
	if touch_controls.enabled and event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if state.climate.data.intro_pending: return
	if hud == null:
		return
	if state.run_over:
		return
	if state.rocket_pending:
		return
	if hud.is_roll_animating():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if prize_target:
					_cancel_prize_target()
					return
				if not climate_target.is_empty() or not hud._climate_console.equipment.is_empty():
					_climate_action("cancel")
					return
				if hud.is_panel_open():
					hud.close_panel()
				else:
					_on_user_action("menu")
			KEY_B: _on_user_action("market")
			KEY_V: _on_user_action("barn")
			KEY_I: _on_user_action("inventory")
			KEY_C: _on_user_action("builds")
			KEY_U: _on_user_action("tools")
			KEY_R: _on_user_action("roll")
			KEY_P: _on_user_action("dex")
			KEY_Q: _on_user_action("quests")
			KEY_F: _on_user_action("quick_sell")
			KEY_H, KEY_F1: _on_user_action("help")
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
	elif hit.has("station"):
		_interact_station(str(hit.station))

func _interact_station(station: String) -> void:
	if station.begins_with("equipment:"):
		_select_equipment(station.trim_prefix("equipment:"))
		if station == "equipment:tank": _queue_refill()
	elif station == "profession:farmer":
		_on_action("build:inspect:farmer")
	elif station.begins_with("profession:"):
		_on_action("builds")
	elif station == "island":
		queue_ferry()
	elif station == "market" and not _tutorial_active():
		# Visiting Mara herself is a deliberate conversation, even after her intro.
		_start_conversation("mara", "market")
	else:
		_on_user_action(station)

func _on_user_action(action: String) -> void:
	if conversation.visible: return
	if action in ["market", "sell_potatoes"]:
		# Market tabs navigate the same shop session; they are not NPC visits.
		# Use the existing saved memory for ordinary re-entry, so a completed
		# introduction stays completed after loading, too. The stall and talk:mara
		# still allow players to start a conversation deliberately.
		var browsing_market: bool = hud._panel_kind in ["market", "sell_potatoes"]
		var met_mara: bool = int(state.npc_history.get("mara", {}).get("visits", 0)) > 0
		if browsing_market or met_mara:
			_on_action(action)
			return
	var id: String = state.NpcRoster.for_station(action, state.current_island)
	if not id.is_empty() and state.NpcRoster.available(id, state.current_island) and not _tutorial_active():
		_start_conversation(id, action)
	else:
		_on_action(action)

func _start_conversation(id: String, requested_service: String = "") -> void:
	if not state.NpcRoster.available(id, state.current_island) or _tutorial_active() or state.run_over or state.rocket_pending or state.climate.data.intro_pending or hud.is_roll_animating(): return
	var return_service: String = requested_service if not requested_service.is_empty() else hud._panel_kind
	if return_service.is_empty(): return_service = state.NpcRoster.PEOPLE[id].service
	_cancel_walk()
	_cancel_prize_target()
	_close_equipment()
	climate_target = ""
	hud._climate_console.targeting = ""
	touch_controls.release_all()
	touch_controls.drawer.hide()
	hud.close_panel()
	hud._climate_alert.dismiss()
	farm_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	conversation.start(id, state, return_service, touch_controls.enabled)
	_save_blind_checkpoint.call_deferred()

func _finish_conversation(service: String) -> void:
	farm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	touch_controls.release_all()
	_save_blind_checkpoint.call_deferred()
	if not service.is_empty(): _on_action(service)
	else: hud.update_state(state)

func _camera_zoom_max() -> float:
	return (74.0 if world.current_island == 3 else (64.0 if world.current_island == 2 else 56.0)) * world.LAND_SPACING

func _reset_camera_zoom() -> void:
	_zoom_target_size = clampf(world.camera.size, CAMERA_ZOOM_MIN, _camera_zoom_max())

func _reset_camera_view() -> void:
	_cancel_map_drag()
	if is_instance_valid(touch_controls): touch_controls.release_all()
	# Loading a save on the current island reuses its camera. Do not promote
	# the player's current pan/zoom into the new default overview.
	if _camera_home_id == world.camera.get_instance_id():
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
	_zoom_target_size = clampf(_camera_home_size, CAMERA_ZOOM_MIN, _camera_zoom_max())

func _map_navigation_allowed() -> bool:
	return is_instance_valid(hud) and not hud.is_panel_open() and not state.run_over and not state.rocket_pending and not state.climate.data.intro_pending and not hud.is_roll_animating() and not (is_instance_valid(conversation) and conversation.visible) and not (is_instance_valid(touch_controls) and touch_controls.drawer.visible)

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
	return (Vector2(28, 22) if world.current_island == 3 else (Vector2(23, 18) if world.current_island == 2 else Vector2(20, 15))) * world.LAND_SPACING

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

func _start_walk(point: Vector3, follow_ferry: bool = false) -> void:
	walk_waypoints = world.walk_route(world.player.position, point, follow_ferry)
	destination = walk_waypoints.pop_front()
	walking = true

func queue_ferry() -> void:
	if state.run_over:
		return
	if _tutorial_active() and not tutorial.allows_action("island"):
		tutorial.explain_block()
		return
	_cancel_prize_target()
	_cancel_walk()
	if world.player.position.distance_to(world.ferry_position()) <= 2.0:
		_on_user_action("island")
		return
	pending_ferry = true
	_start_walk(world.ferry_position(), true)

func _cancel_walk() -> void:
	sprint_blend = 0.0
	pending_tool = selected_tool
	pending_refill = false
	walking = false
	pending_plot = -1
	pending_ferry = false
	walk_waypoints.clear()
	hover_plot = -1
	if world != null:
		world.highlight_tiles(NO_TILES)

func _select_tool(tool: String) -> void:
	_cancel_prize_target()
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

func _begin_prize_target() -> void:
	var info: Dictionary = builds.professions.cultivation_info()
	if not info.ready:
		hud.show_toast(info.reason)
		return
	_cancel_walk()
	_close_equipment()
	climate_target = ""
	hud._climate_console.targeting = ""
	prize_target = true
	hud.close_panel()
	hud._toast_box.hide()
	hud.clear_farm_hint()
	hud.set_plot_action("Grow a giant potato · 1 compost\nClick one of the glowing planted patches.")
	_preview_area(-1, "cultivate")

func _cancel_prize_target() -> void:
	if not prize_target: return
	prize_target = false
	if pending_tool == "cultivate": _cancel_walk()
	if is_instance_valid(hud): hud.set_plot_action("")
	if is_instance_valid(world): world.highlight_tiles(NO_TILES)

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
	if prize_target:
		var target_info: Dictionary = builds.professions.cultivation_info(index)
		if not target_info.ready:
			hud.set_plot_action(target_info.reason + "\nChoose a glowing planted patch.")
			_preview_area(-1, "cultivate")
			return
		hud.set_plot_action("Walking to feed this crop · 1 compost\nIt will grow a giant potato with 3× the harvest.")
	hud.note_farm_action()
	if not state.plots[index].unlocked and not state.ClimateSystem.Lesson.active(state):
		hud.show_farm_hint("Unlock more beds at Tools · $1.8K")
		return
	pending_ferry = false
	pending_plot = index
	pending_tool = "cultivate" if prize_target else selected_tool
	_start_walk(world.plot_positions[index] + Vector3(0.0, 0.0, 0.65))
	_preview_area(index, pending_tool)

func perform_plot(index: int, tool: String = "hoe") -> void:
	if state.run_over or index < 0 or index >= state.plots.size(): return
	if tool == "cultivate":
		var already_prize: bool = state.plots[index].get("cultivated", false)
		var result: String = builds.professions.cultivate(index)
		if state.plots[index].get("cultivated", false) and not already_prize:
			_cancel_prize_target()
			hud.show_farm_hint("Giant potato growing · Harvest [4] when ripe." if state.plots[index].watered else "Compost added · Water [3], then harvest the giant potato when ripe.")
			world.play_farm_effect([index], "compost", 1, 0)
			_save_blind_checkpoint.call_deferred()
		else:
			hud.set_plot_action(result + "\nChoose another glowing crop, or cancel.")
		return
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
			if action == "harvest" and int(before[step].stage) == 3:
				harvest_snapshots[tile] = before[step]
	if lesson_before == "water" and state.climate.data.lesson.stage == "area": changed_indices.append(index)
	if changed_indices.is_empty():
		if _tutorial_active(): hud.show_tutorial_feedback(result)
		else: hud.show_farm_hint(result)
	if not changed_indices.is_empty():
		hud.clear_farm_hint()
		if tool == "harvest" and state.storage_used() >= state.capacity:
			hud.show_farm_hint("Barn full · Sell crops [F]")
		world.play_farm_effect(changed_indices, action, state.combo_multiplier, int(state.tools.get("hoe" if action == "plant" else action, 0)), harvest_snapshots)
	if _tutorial_active():
		tutorial.update(0.0)

func _interact_nearby() -> void:
	if hud.is_panel_open() or state.run_over or state.rocket_pending or state.climate.data.intro_pending or hud.is_roll_animating(): return
	if prize_target:
		var eligible: Array = builds.professions.cultivation_info().eligible
		var nearest_crop: int = -1
		var nearest_distance: float = 2.8
		for index in eligible:
			var distance: float = world.player.position.distance_to(world.plot_positions[index])
			if distance < nearest_distance:
				nearest_crop = index
				nearest_distance = distance
		if nearest_crop >= 0: perform_plot(nearest_crop, "cultivate")
		else: hud.set_plot_action("Move closer to a glowing crop, or click it.\n1 compost makes this harvest 3× larger.")
		return
	if world.player.position.distance_to(world._climate_field.loop.tank_position() + Vector3(-0.4, 0, 2.3)) <= 2.0:
		_select_equipment("tank")
		_queue_refill()
		return
	if world.player.position.distance_to(world.ferry_position()) <= 2.0:
		_cancel_walk()
		_on_user_action("island")
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
		else: perform_plot(nearest, selected_tool)
	else:
		hud.show_farm_hint("Click a bed, or move closer to use E")

func _preview_area(index: int, tool: String) -> void:
	if prize_target or tool == "cultivate":
		var chosen: Array[int] = []
		chosen.assign(builds.professions.cultivation_info().eligible)
		world.highlight_tiles(chosen)
		return
	if not hud._climate_console.equipment.is_empty():
		var id: String = hud._climate_console.equipment
		var tiles: Array[int] = []
		if id.begins_with("sprinkler") or id == "trees":
			var patch: int = 0 if id == "trees" else int(id.trim_prefix("sprinkler"))
			for i in range(state.plots.size()):
				if state.ClimateSystem.Operations.zone(i, state.current_island) == patch: tiles.append(i)
		world.highlight_tiles(tiles)
		return
	if not climate_target.is_empty():
		var target_index: int = 35 if state.ClimateSystem.Lesson.active(state) or index < 0 else index
		var chosen: int = state.ClimateSystem.Operations.zone(target_index, state.current_island)
		var tiles: Array[int] = []
		for i in range(state.plots.size()):
			if state.ClimateSystem.Operations.zone(i, state.current_island) == chosen: tiles.append(i)
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
	var hit: Dictionary = world.pick(farm_viewport.to_farm_position(get_viewport().get_mouse_position()))
	hover_plot = int(hit.get("plot_index", -1))
	_preview_area(pending_plot if walking and pending_plot >= 0 else hover_plot, pending_tool if walking else selected_tool)
	if prize_target:
		hud.set_context("")
		return
	if not climate_target.is_empty():
		hud.set_context("Click the highlighted beds · Esc cancels")
		return
	if state.ClimateSystem.Lesson.active(state):
		hud.set_context("Water the glowing practice bed [3]" if state.climate.data.lesson.stage == "water" else "Click the near sprinkler to water its connected beds")
		return
	if hover_plot >= 0:
		var plot: Dictionary = state.plots[hover_plot]
		var action: String = selected_tool
		if state.climate.data.phase == "active" and state.climate.data.island == state.current_island and float(state.climate.data.operations.stress.get(str(hover_plot), 0)) > 0.1:
			hud.set_context("Danger %d%% · %s" % [roundi(float(state.climate.data.operations.stress[str(hover_plot)]) * 100), "Water [3] rescues this bed" if state.climate.data.event == "drought" else ("Hoe [1] drains this bed" if state.climate.data.event == "flood" else "Heat your hoe at the furnace, then Hoe [1]" if state.climate.data.event == "freeze" else "Harvest ripe crops before the next strike")])
		elif bool(plot.get("frozen", false)):
			hud.set_context("Frozen bed · Press 1, then click to break ice")
		elif bool(plot.get("pests", false)):
			hud.set_context("Pests · %d/3 left · Press 5, then click" % maxi(0, 3 - int(plot.get("pest_ticks", 0))))
		elif not plot.unlocked:
			hud.set_context("12 more beds · Unlock at Tools for $1.8K")
		elif int(plot.stage) == 3:
			hud.set_context("%s is ripe · Click to %s" % [str(plot.crop).capitalize(), action])
		elif int(plot.stage) > 0 and bool(plot.watered):
			var seconds: float = maxf(0.0, (float(state.CROPS[str(plot.crop)].grow) - float(plot.elapsed)) / state.crop_growth_speed(0, str(plot.crop)))
			hud.set_context("%s · Ready in %.0fs" % [str(plot.crop).capitalize(), seconds])
		else:
			var area: int = state.affected_tiles(hover_plot, action).size()
			hud.set_context("%s · Click to work %d bed%s" % [action.capitalize(), area, "" if area == 1 else "s"])
	elif hit.has("station"):
		if str(hit.station).begins_with("profession:"):
			var profession: String = str(hit.station).get_slice(":", 1)
			hud.set_context({"farmer": "Compost · Click to grow a giant potato", "industrialist": "Workshop · Click to load and grade crops", "scientist": "Seed bench · Click to discover planting traits", "investor": "Buyers · Click to reserve a shipment price", "gambler": "Harvest stakes · Click to choose crops and see the odds"}.get(profession, "Builds · Click to explore"))
			return
		if str(hit.station).begins_with("equipment:"):
			var id: String = str(hit.station).trim_prefix("equipment:")
			hud.set_context("Tank · Click to walk over and refill" if id == "tank" else ("Sprinkler · Click to see its connected beds" if id.begins_with("sprinkler") else "Click to see how this protects your farm"))
			return
		var travel_hint: String = "Ferry · Click to board"
		var descriptions: Dictionary = {"market": "Seeds · Click to buy or sell", "barn": "Barn · Click for inventory", "roll": "Roll House · Click to view odds" if state.roll_available() else "Rolls closed · Travel to your newest island", "island": travel_hint, "quests": "Quests · Click for challenges", "forge": "Tools · Click to upgrade", "builds": "Builds · Click for abilities", "climate": "Farm protection · Click to view upgrades"}
		descriptions["activities"] = "Ducks · Click to hire pest patrol" if state.current_island == 1 else ("Contracts · Click to supply a buyer" if state.current_island == 2 else "Furnace · Click to boost growth")
		descriptions["duck_patrol"] = "Ducks · Click to hire pest patrol"
		descriptions["tools"] = "Tools · Click to upgrade"
		hud.set_context(descriptions.get(str(hit.station), "TATERLAND"))
	else:
		hud.set_context("Ferry · Press E to board" if world.player.position.distance_to(world.ferry_position()) <= 2.0 and (not _tutorial_active() or tutorial.allows_action("island")) else "")

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
		if world.current_island != state.current_island:
			_on_island_changed(state.current_island)
		world.profession_world.refresh(builds, state)
		world.update_plots(state.ClimateSystem.Lesson.preview(state) if state.ClimateSystem.Lesson.active(state) else state.plots)
		world.set_climate(state.climate_info())
		world.set_island2_unlocked(state.island2_unlocked)
		world.set_island3_unlocked(state.island3_unlocked)
		world.set_export_state(state.export_active, state.export_timer)
		world.set_frost_state(state.frost_active, state.frost_timer)
		world.set_golden_hat(state.golden_hat)
		world.set_roll_available(state.roll_available())
		world.set_equipment(state.equipment_loadout(), state.ITEM_CATALOG)
		world.set_activity_state(activities.info())
		if state.current_island == 3 and last_frost_active != state.frost_active:
			if state.frost_active:
				_play_tone(523.0, 0.2)
			elif state.thaw_remaining > 0.0:
				_play_tone(1174.0, 0.7)
				sparkle_tone = true
				world.play_reward("legendary")
	last_frost_active = state.frost_active
	if hud != null:
		hud.update_state(state)
		_hud_update_frame = Engine.get_process_frames()
		_update_market_impact()

func _update_market_impact() -> void:
	if state.run_over or _tutorial_active() or state.rocket_pending:
		hud.set_market_intensity(state.current_island, 0.0)
		surge_live = false
		surge_band = 0
		fanfare_remaining = 0.0
		return
	var peak: float = float(state.market[state.selected_crop].change)
	var crazy: bool = peak > 300.0
	var band: int = HudScript.MarketImpact.tier_for_percent(peak)
	hud.set_market_intensity(state.current_island, peak)
	if band < surge_band:
		fanfare_remaining = 0.0
	if band > surge_band:
		fanfare_island = state.current_island
		fanfare_remaining = 1.2
		fanfare_phase = 0.0
		stock_music_time = 0.0
		stock_shake_clock = 0.0
	surge_live = crazy
	surge_band = band


func _start_rocket_if_ready() -> void:
	# Finish a paid roll's reveal first; its HUD animates independently while
	# simulation is paused. No purchase or harvest is interrupted mid-transaction.
	if hud.is_roll_animating() or rocket_cutscene.active:
		return
	_cancel_walk()
	hud.close_panel()
	fanfare_remaining = 0.0
	tone_remaining = 0.0
	surge_band = 0
	world.camera.h_offset = 0.0
	world.camera.v_offset = 0.0
	hud.set_market_intensity(state.current_island, 0.0)
	if not test_mode:
		state.save_game()
	rocket_cutscene.start(state.current_island)
	farm_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _on_rocket_finished() -> void:
	farm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	state.complete_rocket_launch()
	if not test_mode:
		state.save_game()


func _update_stock_shake(delta: float) -> void:
	stock_shake_clock += delta
	var amplitude: float = 0.0
	if surge_band >= 3 and not _tutorial_active():
		amplitude = (0.075 if surge_band == 3 else 0.12) * (0.45 + 0.55 * exp(-fmod(stock_shake_clock, 0.5) * 7.0))
	climate_shake = move_toward(climate_shake, 0.0, delta * 0.25)
	var weather: Dictionary = state.climate_info()
	if weather.phase == "active" and weather.event == "storm" and weather.island == state.current_island:
		amplitude += float(weather.severity) * 0.075 * (0.2 + 0.8 * pow(maxf(0.0, sin(stock_shake_clock * 1.7)), 3.0))
	amplitude = minf(0.26, amplitude + climate_shake)
	world.camera.h_offset = sin(stock_shake_clock * 43.0) * amplitude
	world.camera.v_offset = sin(stock_shake_clock * 57.0 + 0.8) * amplitude * 0.6

func _on_island_changed(id: int) -> void:
	_cancel_prize_target()
	climate_target = ""
	_cancel_walk()
	if hud != null:
		hud._climate_console.targeting = ""
		hud.close_panel()
	world.switch_island(id)
	_reset_camera_view()
	world.set_day_time(state.elapsed)
	destination = world.player.position
	world.update_plots(state.plots)
	world.set_island2_unlocked(state.island2_unlocked)
	world.set_island3_unlocked(state.island3_unlocked)
	world.set_export_state(state.export_active, state.export_timer)
	world.set_frost_state(state.frost_active, state.frost_timer)
	world.set_golden_hat(state.golden_hat)
	world.set_roll_available(state.roll_available())
	world.set_equipment(state.equipment_loadout(), state.ITEM_CATALOG)
	world.set_activity_state(activities.info())
	surge_live = false
	surge_band = 0
	fanfare_remaining = 0.0
	stock_music_time = 0.0
	if hud != null:
		hud.update_state(state)
		hud.set_context("")

func _on_export_changed(active: bool) -> void:
	world.set_export_state(active, state.export_timer)
	if active and not state.disaster_market_active():
		if state.current_island == 2:
			world.play_reward("legendary")
		_play_tone(1046.0, 0.7)
		sparkle_tone = true

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
				if state.ClimateSystem.Operations.zone(i, state.current_island) == state.ClimateSystem.Operations.zone(index, state.current_island): tiles.append(i)
			world.play_farm_effect(tiles, "water")
	world.set_climate(state.climate_info())
	hud.show_farm_hint(result)
	hud.update_state(state)
	_save_blind_checkpoint.call_deferred()

func _climate_action(action: String) -> void:
	if action == "open_furnace":
		_on_user_action("activities")
		return
	if action == "heat_hoe":
		state.ClimateSystem.Operations.operate(state, action)
		_select_tool("hoe")
		hud.close_panel()
		return
	match action:
		"refill": _queue_refill()
		"close_equipment": _close_equipment()
		"show_sprinkler": _select_equipment("sprinkler2")
		"show_trees": _select_equipment("trees")
		"show_drain": _select_equipment("drain")
		"use_sprinkler":
			var patch: int = int(hud._climate_console.equipment.trim_prefix("sprinkler"))
			for i in range(state.plots.size()):
				if state.ClimateSystem.Operations.zone(i, state.current_island) != patch: continue
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
	_save_blind_checkpoint.call_deferred()

func _on_action(action: String) -> void:
	if is_instance_valid(conversation) and conversation.visible: return
	if state.ClimateSystem.Lesson.active(state) and not action.begins_with("climate_operate:") and action not in ["save", "pause", "help", "menu"] and not action.begins_with("graphics"):
		state.ClimateSystem.Lesson.finish(state)
		climate_target = ""
	if not action.begins_with("climate_operate:"):
		_close_equipment()
		climate_target = ""
		hud._climate_console.targeting = ""
	if state.climate.data.intro_pending and action not in ["reset", "climate_continue"]: return
	if action == "climate_continue":
		state.climate.acknowledge(state)
		hud._climate_alert.dismiss()
		hud._climate_intro.stop()
		_on_user_action("climate")
		_save_blind_checkpoint.call_deferred()
		return
	if state.run_over and action not in ["reset", "debug", "close"] and not action.begins_with("debug:"):
		return
	if state.rocket_pending and action != "reset":
		return
	if hud.is_roll_animating():
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
		"talk":
			if parts.size() == 2: _start_conversation(parts[1])
		"graphics":
			if parts.size() == 2:
				_apply_graphics_quality(parts[1], true)
			elif parts.size() == 1:
				_cancel_walk()
				hud.show_panel("graphics", state)
		"menu", "tracked_prices", "market", "sell_potatoes", "barn", "inventory", "builds", "tools", "roll", "help", "pause", "dex", "island", "quests", "activities", "duck_patrol", "debug", "blinds", "taxes", "climate", "debt":
			if parts[0] == "debug" and parts.size() > 1:
				_debug_action(parts)
				return
			if parts[0] == "roll" and parts.size() > 1:
				if not hud.begin_roll(parts[1]):
					return
				var previous_roll_count: int = state.roll_count
				rolling_request = true
				roll_sound_elapsed = 0.0
				roll_sound_clock = 0.0
				state.roll(parts[1])
				rolling_request = false
				if state.roll_count > previous_roll_count:
					if not test_mode:
						state.save_game()
					if state.last_roll_results.size() > 1:
						hud.spin_batch(state.last_roll_results.duplicate(true))
					else:
						hud.spin_roll(state.last_roll.duplicate(true))
				else:
					hud.cancel_roll()
			else:
				_cancel_prize_target()
				_cancel_walk()
				if parts[0] == "builds": hud._build_selection = ""
				hud.show_panel(parts[0], state)
		"roll_batch":
			if parts.size() != 3 or not hud.begin_roll(parts[1]):
				return
			rolling_request = true
			roll_sound_elapsed = 0.0
			roll_sound_clock = 0.0
			var results: Array = state.roll_batch(parts[1], int(parts[2]))
			rolling_request = false
			if results.is_empty():
				hud.cancel_roll()
			else:
				if not test_mode:
					state.save_game()
				hud.spin_batch(results)
		"activity":
			if parts.size() < 2:
				return
			match parts[1]:
				"duck":
					if parts.size() == 3 and parts[2] == "speed":
						activities.train_ducks()
					else:
						activities.hire_duck()
				"contract":
					if parts.size() == 3:
						activities.choose_contract(parts[2])
				"deliver": activities.deliver_contract()
				"furnace":
					if parts.size() == 3:
						activities.charge_furnace(parts[2])
			if not test_mode:
				state.save_game()
		"climate_operate":
			if parts.size() == 2:
				_climate_action(parts[1])
				_save_blind_checkpoint.call_deferred()
		"recovery":
			if parts.size() != 2: return
			if parts[1] == "deliver": state.deliver_recovery()
			elif parts[1] == "seeds": state.claim_recovery_seeds()
			_save_blind_checkpoint.call_deferred()
		"climate_fund":
			if parts.size() == 2:
				state.climate.fund(state, parts[1])
				_save_blind_checkpoint.call_deferred()
		"gear":
			if parts.size() != 3:
				return
			if parts[1] == "equip":
				state.equip_gear(parts[2])
			elif parts[1] == "unequip":
				state.unequip_gear(parts[2])
			if not test_mode:
				state.save_game()
		"island_unlock": state.unlock_island2()
		"island3_unlock": state.unlock_island3()
		"forge":
			_cancel_walk()
			hud.show_panel("tools", state)
		"travel": state.travel_to(int(parts[1]))
		"quest": state.claim_quest(parts[1])
		"profession":
			if parts[1] == "giant":
				_begin_prize_target()
			elif parts[1] == "cancel": _cancel_prize_target()
			elif parts[1] == "sell": builds.sell_processed()
			else: builds.professions.action(parts[1], parts[2] if parts.size() > 2 else "")
		"build":
			match parts[1]:
				"inspect":
					if parts.size() != 3 or (not parts[2].is_empty() and parts[2] not in builds.IDS): return
					_cancel_prize_target()
					_cancel_walk()
					hud._build_selection = parts[2]
					hud.show_panel("builds", state)
				"select":
					_cancel_prize_target()
					builds.select_build(parts[2])
				"ability": builds.use_ability()
				"sell_processed": builds.sell_processed()
				"open_crate":
					var result: Dictionary = builds.open_crate()
					if not result.is_empty():
						if not test_mode:
							state.save_game()
						if hud.begin_roll("build_crate"):
							roll_sound_elapsed = 0.0
							roll_sound_clock = 0.0
							hud.spin_roll(result)
						else:
							builds.finish_crate_reveal()
		"close": hud.close_panel()
		"crop": state.select_crop(parts[1])
		"tracked_seed":
			if parts.size() == 3:
				state.set_tracked_seed(parts[1], parts[2] == "1")
				if not test_mode:
					state.save_game()
		"tool": _select_tool(parts[1])
		"buy": state.buy_seeds(parts[1], int(parts[2]))
		"sell": state.sell_crop(parts[1], int(parts[2]))
		"quick_sell": state.sell_crop(state.selected_crop)
		"sell_mutations": state.sell_mutations()
		"upgrade":
			match parts[1]:
				"barn": state.upgrade_barn()
				"expansion": state.expand_field()
				_: state.upgrade_tool(parts[1])
		"save":
			if not test_mode:
				hud.show_toast("Farm saved. Your crops are tucked away." if state.save_game() else "Could not save. Check the available disk space.")
		"load":
			if not test_mode:
				_cancel_walk()
				hud.close_panel()
				var loaded: bool = state.load_game()
				if loaded:
					state.activate_roll_boost()
					if not bool(state.tutorial_progress.get("completed", false)) and state.current_island == 1:
						tutorial.start()
				hud.show_toast("Farm restored. The exchange is open." if loaded else "No readable farm save yet.")
		"reset":
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

func _on_tax_boom() -> void:
	var info: Dictionary = state.blind_info()
	hud.show_toast("TAX BOOM +%.0f%% · Bill %s\nTwo more major stocks to prepare." % [(float(info.tax_multiplier) - 1.0) * 100.0, state.money(info.tax, true)])
	_play_tone(196.0, 0.45)

func _on_climate_changed(phase: String) -> void:
	if phase in ["calm", "recovery"]:
		climate_target = ""
		hud._climate_console.targeting = ""
	var info: Dictionary = state.climate_info()
	if phase in ["introduction", "warning", "impact", "recovery"]:
		if phase == "introduction":
			_cancel_walk()
			hud.cancel_roll()
			hud.close_panel()
		if phase == "introduction": hud._climate_intro.start()
		else: hud._climate_alert.present(phase, info, state)
		_play_tone(164.81 if phase == "impact" else 220.0, 0.6)
	if is_instance_valid(climate_audio):
		climate_audio.set_weather(info, state.current_island, state.run_over)
		if phase in ["impact", "strike"]: climate_audio.impact()
	if phase == "impact" and info.island == state.current_island:
		climate_shake = 0.22 if info.event != "drought" else 0.08
	world.set_climate(info)
	_save_blind_checkpoint.call_deferred()

func _on_blind_resolved(result: Dictionary) -> void:
	world.profession_world.tax_collected(result, state)
	if not state.run_over:
		hud.show_toast("TAX %s · %s\nCollected %s · Balance %s" % ["PAID" if result.cleared else "BORROWED", state.blind_progress_text(result.ratio), state.money(result.tax, true), state.money(result.after, true)])
		_play_tone(1046.5, 0.35)
	_save_blind_checkpoint.call_deferred()

func _on_run_ended() -> void:
	_cancel_walk()
	hud.cancel_roll()
	hud._climate_alert.dismiss()
	climate_shake = 0.0
	if is_instance_valid(climate_audio): climate_audio.set_weather(state.climate_info(), state.current_island, true)
	builds.finish_crate_reveal()
	pest_alert.update(0.0, 0)
	surge_band = 0
	fanfare_remaining = 0.0
	world.camera.h_offset = 0.0
	world.camera.v_offset = 0.0
	_play_tone(130.81, 0.65)
	_save_blind_checkpoint.call_deferred()

func _save_blind_checkpoint() -> void:
	if not test_mode:
		state.save_game()

func _on_purchase_rejected(message: String) -> void:
	hud.show_toast(message)

func _on_notification(message: String) -> void:
	if rolling_request or hud.is_roll_animating():
		return
	# Routine work, quotes and shipments are already visible in the field and HUD.
	# Keep interruptions for problems and milestones that need the player's attention.
	var lower: String = message.to_lower()
	if _working_plot:
		# Plot results use one quiet footer slot, never a second central toast.
		return
	for marker in ["quest complete", "shores unlocked", "frosthollow unlocked", "could not", "couldn't", "cannot", "can't", "not enough", "need ", "needs ", "full", "seeds left", "no potatoes", "no readable", "damaged", "all builds", "failed", "already collected", "emergency"]:
		if lower.contains(marker):
			hud.show_toast(message)
			return

func _on_reward(title: String, detail: String, rarity: String) -> void:
	if rolling_request or _tutorial_active():
		return
	hud.show_reward(title, detail, rarity)
	world.play_reward(rarity)
	_play_tone(660.0 if rarity in ["common", "rare"] else 880.0, 0.85)
	sparkle_tone = true

func _on_roll_revealed(_title: String, _detail: String, rarity: String) -> void:
	builds.finish_crate_reveal()
	state.activate_roll_boost()
	var celebrate: bool = RewardFeedback.celebrates(rarity)
	if celebrate:
		world.play_reward(rarity)
	_play_tone(1046.0 if celebrate else (660.0 if rarity == "rare" else 440.0), 0.95 if celebrate else 0.14)
	sparkle_tone = celebrate

func _on_pest_warning(_index: int, destroyed: bool) -> void:
	if _tutorial_active():
		return
	if is_instance_valid(pest_alert):
		pest_alert.notify_attack(destroyed)

func _on_chain(count: int, multiplier: int) -> void:
	# The rising streak note layers over the potato's pull/pop foley.
	if count > 0:
		_play_tone(400.0 + float(multiplier) * 40.0, 0.25)

func _tutorial_active() -> bool:
	return is_instance_valid(tutorial) and tutorial.active

func play_tutorial_cue(kind: String) -> void:
	# Short, warm notes guide progress without borrowing the jackpot fanfare.
	match kind:
		"pest": tutorial_notes.assign([329.63, 220.0, 329.63])
		"visit": tutorial_notes.assign([587.33, 783.99])
		"finish": tutorial_notes.assign([523.25, 659.25, 783.99, 1046.50])
		_: tutorial_notes.assign([523.25, 659.25])
	tutorial_note_clock = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_map_navigation()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null and not test_mode:
			state.save_game()
		get_tree().quit()

func _setup_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	sound_player = AudioStreamPlayer.new()
	# Generated jackpot/tool audio must use the streaming mixer on Web too.
	# The browser's sample playback path cannot play AudioStreamGenerator.
	sound_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.08
	sound_player.stream = stream
	sound_player.volume_db = -18.0
	add_child(sound_player)
	sound_player.play()
	audio_playback = sound_player.get_stream_playback()

func _play_tone(frequency: float, duration: float) -> void:
	tone_frequency = frequency
	tone_length = duration
	tone_remaining = duration
	sparkle_tone = false

func _pump_audio() -> void:
	if audio_playback == null:
		return
	var frames: int = audio_playback.get_frames_available()
	if tone_remaining <= 0.0 and fanfare_remaining <= 0.0 and (surge_band < 3 or state.rocket_pending):
		# Silence is a bulk transfer, not 22,050 interpreted push_frame calls/sec.
		_silent_audio.resize(frames)
		audio_playback.push_buffer(_silent_audio)
		return
	var fanfare_pitch: float = 1.0 if fanfare_island == 1 else (1.12246 if fanfare_island == 2 else 1.25992)
	var stock_pitch: float = 1.0 if state.current_island == 1 else (1.12246 if state.current_island == 2 else 1.25992)
	var stock_playing: bool = surge_band >= 3 and not state.rocket_pending
	for frame in range(frames):
		var sample: float = 0.0
		if tone_remaining > 0.0:
			var envelope: float = minf(1.0, (tone_length - tone_remaining) * 80.0) * (tone_remaining / tone_length)
			var harmonic: float = sin(audio_phase * TAU) + (sin(audio_phase * TAU * 1.5) * 0.4 if sparkle_tone else 0.0)
			sample = harmonic * envelope * 0.4
			audio_phase = fmod(audio_phase + tone_frequency / 22050.0, 1.0)
			tone_remaining -= 1.0 / 22050.0
		if fanfare_remaining > 0.0:
			var age: float = 1.2 - fanfare_remaining
			var note: int = mini(3, int(age / 0.13))
			var envelope: float = minf(1.0, age * 65.0) * minf(1.0, fanfare_remaining * 3.0)
			sample += (sin(fanfare_phase * TAU) + 0.35 * sin(fanfare_phase * TAU * 2.0) + 0.18 * sin(fanfare_phase * TAU * 3.0)) * envelope * 0.28
			fanfare_phase = fmod(fanfare_phase + FANFARE_NOTES[note] * fanfare_pitch / 22050.0, 1.0)
			fanfare_remaining -= 1.0 / 22050.0
		if stock_playing:
			# An original pentatonic synth groove follows the visual half-second beat.
			var beat: float = fmod(stock_music_time, 0.25)
			var bass_beat: float = fmod(stock_music_time, 0.5)
			var note: float = STOCK_NOTES[int(stock_music_time / 0.25) % STOCK_NOTES.size()] * stock_pitch
			sample += sin(TAU * note * stock_music_time) * exp(-beat * 14.0) * minf(1.0, beat * 120.0) * 0.22
			sample += sin(TAU * 130.81 * stock_pitch * stock_music_time) * exp(-bass_beat * 9.0) * 0.18
			sample += sin(TAU * (48.0 * bass_beat + 1.8 * (1.0 - exp(-bass_beat * 30.0)))) * exp(-bass_beat * 23.0) * 0.32
			stock_music_time += 1.0 / 22050.0
		sample = clampf(sample, -0.95, 0.95)
		audio_playback.push_frame(Vector2(sample, sample))

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
		elif tip.action == "practice":
			if not help.start_practice(state):
				hud.show_toast("Keep some harvested crops ready. Practice is available between stock booms in the Valley.")
		else:
			# Browsing dismisses the suggestion; it never certifies understanding.
			if tip.id not in ["pests", "stocks"]:
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
	_cancel_prize_target()
	equipment_prompt_time = 10.0 if brief else 0.0
	_cancel_walk()
	hud.close_panel()
	hud._climate_console.equipment = id
	equipment_island = state.current_island
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
	if equipment_island != state.current_island: _close_equipment()
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
		if hud._blind_card.visible and left < hud._blind_card.get_global_rect().end.x:
			minimum_top = maxf(minimum_top, hud._blind_card.get_global_rect().end.y + 12)
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
