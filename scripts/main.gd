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
const WALK_SPEED: float = 7.0
const NO_TILES: Array[int] = []
const CAMERA_ZOOM_MIN: float = 18.0
const CAMERA_ZOOM_RESPONSE: float = 14.0
const CAMERA_SCROLL_STEP: float = 0.035

var state
var world
var hud
var builds
var activities
var selected_tool: String = "hoe"
var destination: Vector3 = Vector3.ZERO
var walking: bool = false
var pending_plot: int = -1
var pending_tool: String = "hoe"
var hover_plot: int = -1
var hover_elapsed: float = 0.0
var ui_elapsed: float = 0.0
var save_elapsed: float = 0.0
var test_mode: bool = false
var sound_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
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
var tutorial: Node
var tutorial_notes: Array[float] = []
var tutorial_note_clock: float = 0.0

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
	add_child(world)
	world.build_world(state.current_island)
	_reset_camera_zoom()
	world.set_day_time(state.elapsed)
	world.pest_warning.connect(_on_pest_warning)
	hud = HudScript.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.build_ui()
	hud.action_requested.connect(_on_action)
	hud.roll_revealed.connect(_on_roll_revealed)
	state.changed.connect(_on_state_changed)
	state.notified.connect(_on_notification)
	state.purchase_completed.connect(_on_purchase_completed)
	state.purchase_rejected.connect(_on_purchase_rejected)
	state.reward_received.connect(_on_reward)
	state.harvest_chain.connect(_on_chain)
	state.island_changed.connect(_on_island_changed)
	state.export_changed.connect(_on_export_changed)
	_setup_sound()
	tutorial = TutorialScript.new()
	tutorial.name = "FirstIslandTutorial"
	add_child(tutorial)
	tutorial.setup(self)
	_on_state_changed()
	state.activate_roll_boost()
	hud.set_tool(selected_tool)
	if not test_mode:
		if not bool(state.tutorial_progress.get("completed", false)) and state.current_island == 1:
			tutorial.start()
		elif returning:
			hud.show_toast("Your farm is restored. The market is open!")
	get_tree().auto_accept_quit = false

func _register_inputs() -> void:
	var bindings: Dictionary = {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT]
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
	# Crops and the exchange stay live while you browse the barn, tools or rolls.
	var processing_step: float = activities.processing_time(delta)
	state.update(delta)
	world.set_day_time(state.elapsed)
	_update_camera_zoom(delta)
	var infested: int = 0
	for plot in state.plots:
		if bool(plot.get("pests", false)) and int(plot.stage) > 0:
			infested += 1
	pest_alert.update(delta, infested if not _tutorial_active() else 0)
	if not _tutorial_active():
		builds.update(delta, processing_step)
	var moving: bool = false
	if not hud.is_panel_open():
		var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_vector.length() > 0.05:
			walking = false
			pending_plot = -1
			var right: Vector3 = world.camera.global_basis.x
			var forward: Vector3 = world.camera.global_basis.z
			right.y = 0.0
			forward.y = 0.0
			var direction: Vector3 = (right.normalized() * input_vector.x + forward.normalized() * input_vector.y).normalized()
			var next_position: Vector3 = world.player.position + direction * WALK_SPEED * delta
			world.set_player_position(_clamp_destination(next_position))
			moving = true
		elif walking:
			var current: Vector3 = world.player.position
			current.y = 0.0
			var target: Vector3 = destination
			target.y = 0.0
			if current.distance_to(target) < 0.32:
				walking = false
				if pending_plot >= 0:
					perform_plot(pending_plot, pending_tool)
					pending_plot = -1
			else:
				var move_speed: float = WALK_SPEED + float(state.tools.get("harvest", 0)) * 0.8
				world.set_player_position(current.move_toward(target, move_speed * delta))
				moving = true
		hover_elapsed += delta
		if hover_elapsed > 0.08:
			hover_elapsed = 0.0
			_update_hover()
	world.animate(delta, moving)
	if _tutorial_active():
		tutorial.update(delta)
	ui_elapsed += delta
	if ui_elapsed > 0.2:
		ui_elapsed = 0.0
		hud.update_state(state)
		world.set_export_state(state.export_active, state.export_timer)
		world.set_frost_state(state.frost_active, state.frost_timer)
		var activity: Dictionary = builds.activity_info()
		world.set_processing(bool(activity.processing), float(activity.progress))
		world.set_activity_state(activities.info())
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
	elif surge_band > 0 and fanfare_remaining <= 0.0:
		surge_beat_clock -= delta
		if surge_beat_clock <= 0.0 and tone_remaining < 0.1:
			_play_tone(196.0 if state.current_island == 1 else (246.94 if state.current_island == 2 else 329.63), 0.065)
			surge_beat_clock = 0.45 if surge_band == 1 else 0.30

func _unhandled_input(event: InputEvent) -> void:
	if hud == null:
		return
	if hud.is_roll_animating():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if hud.is_panel_open():
					hud.close_panel()
				else:
					_on_action("menu")
			KEY_B: _on_action("market")
			KEY_V: _on_action("barn")
			KEY_I: _on_action("inventory")
			KEY_C: _on_action("builds")
			KEY_U: _on_action("tools")
			KEY_R: _on_action("roll")
			KEY_P: _on_action("dex")
			KEY_Q: _on_action("quests")
			KEY_F: _on_action("quick_sell")
			KEY_H, KEY_F1: _on_action("help")
			KEY_F5: _on_action("save")
			KEY_F9: _on_action("load")
			KEY_1: _select_tool("hoe")
			KEY_2: _select_tool("plant")
			KEY_3: _select_tool("water")
			KEY_4: _select_tool("harvest")
			KEY_5: _select_tool("pest")
			KEY_E, KEY_SPACE:
				if not hud.is_panel_open():
					_interact_nearby()
	if hud.is_panel_open():
		return
	if _handle_map_zoom(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var hit: Dictionary = world.pick(event.position)
			if hit.has("plot_index"):
				queue_plot(int(hit.plot_index))
			elif hit.has("station"):
				_on_action(str(hit.station))
			elif hit.has("ground"):
				destination = _clamp_destination(hit.ground)
				pending_plot = -1
				walking = true

func _camera_zoom_max() -> float:
	return 74.0 if world.current_island == 3 else (64.0 if world.current_island == 2 else 56.0)

func _reset_camera_zoom() -> void:
	_zoom_target_size = clampf(world.camera.size, CAMERA_ZOOM_MIN, _camera_zoom_max())

func _handle_map_zoom(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture:
		if not is_finite(event.factor) or event.factor <= 0.0:
			return false
		# A spread-out pinch magnifies the map, reducing its orthographic span.
		_zoom_by_log_amount(-log(event.factor))
		return true
	if event is InputEventPanGesture:
		if not is_finite(event.delta.y) or is_zero_approx(event.delta.y):
			return false
		_zoom_by_log_amount(event.delta.y * CAMERA_SCROLL_STEP)
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
	if not is_instance_valid(world.camera) or not is_finite(delta) or delta <= 0.0:
		return
	_zoom_target_size = clampf(_zoom_target_size, CAMERA_ZOOM_MIN, _camera_zoom_max())
	world.camera.size = lerpf(world.camera.size, _zoom_target_size, 1.0 - exp(-CAMERA_ZOOM_RESPONSE * minf(delta, 0.25)))
	if absf(world.camera.size - _zoom_target_size) < 0.0001:
		world.camera.size = _zoom_target_size

func _clamp_destination(point: Vector3) -> Vector3:
	if state.current_island == 3:
		point.x = clampf(point.x, -25.0, 25.0)
		point.z = clampf(point.z, -8.0, 18.0)
		point.y = 0.0
		return point
	point.x = clampf(point.x, -20.0 if state.current_island == 2 else -17.0, 20.0 if state.current_island == 2 else 18.0)
	point.z = clampf(point.z, -6.0 if state.current_island == 2 else -5.0, 14.0 if state.current_island == 2 else 12.0)
	point.y = 0.0
	return point

func _cancel_walk() -> void:
	walking = false
	pending_plot = -1
	hover_plot = -1
	if world != null:
		world.highlight_tiles(NO_TILES)

func _select_tool(tool: String) -> void:
	if _tutorial_active() and not tutorial.allows_tool(tool):
		return
	if tool not in ["hoe", "plant", "water", "harvest", "pest"]:
		return
	selected_tool = tool
	hud.set_tool(tool)
	if not hud.is_panel_open():
		_update_hover()

func queue_plot(index: int) -> void:
	if _tutorial_active() and not tutorial.allows_plot(index, selected_tool):
		return
	if index < 0 or index >= state.plots.size():
		return
	if not state.plots[index].unlocked:
		hud.show_toast("Room to grow! Unlock the lower field at the tool shop for $1.8K.")
		return
	destination = world.plot_positions[index] + Vector3(0.0, 0.0, 0.65)
	pending_plot = index
	pending_tool = selected_tool
	walking = true
	_preview_area(index, pending_tool)

func perform_plot(index: int, tool: String = "hoe") -> void:
	if _tutorial_active() and not tutorial.allows_plot(index, tool):
		return
	if index < 0 or index >= state.plots.size():
		return
	var action: String = tool
	var indices: Array[int] = state.affected_tiles(index, action)
	var before: Array[Dictionary] = []
	for tile in indices:
		before.append(state.plots[tile].duplicate(true))
	state.interact_plot(index, tool)
	var changed_indices: Array[int] = []
	for step in range(indices.size()):
		var tile: int = indices[step]
		if before[step] != state.plots[tile]:
			changed_indices.append(tile)
	if not changed_indices.is_empty():
		world.play_farm_effect(changed_indices, action, state.combo_multiplier, int(state.tools.get("hoe" if action == "plant" else action, 0)))
		var pitch: float = 440.0 + float(state.combo_multiplier) * 28.0 if action == "harvest" else float({"hoe": 220.0, "plant": 440.0, "water": 660.0, "pest": 880.0}.get(action, 330.0))
		_play_tone(pitch, 0.16 if action == "harvest" else 0.10)
	if _tutorial_active():
		tutorial.update(0.0)

func _interact_nearby() -> void:
	var nearest: int = -1
	var distance: float = 2.8
	for index in range(world.plot_positions.size()):
		var candidate: float = world.player.position.distance_to(world.plot_positions[index])
		if candidate < distance:
			distance = candidate
			nearest = index
	if nearest >= 0:
		walking = false
		pending_plot = -1
		perform_plot(nearest, selected_tool)
	else:
		hud.show_toast("Click a plot to walk over, or stand beside it and press E to use your tool.")

func _preview_area(index: int, tool: String) -> void:
	if index >= 0:
		world.highlight_tiles(state.affected_tiles(index, tool))
	else:
		world.highlight_tiles(NO_TILES)

func _update_hover() -> void:
	var hit: Dictionary = world.pick(get_viewport().get_mouse_position())
	hover_plot = int(hit.get("plot_index", -1))
	_preview_area(pending_plot if walking and pending_plot >= 0 else hover_plot, pending_tool if walking else selected_tool)
	if hover_plot >= 0:
		var plot: Dictionary = state.plots[hover_plot]
		var action: String = selected_tool
		if bool(plot.get("frozen", false)):
			hud.set_context("FROZEN BED · Use the hoe to crack the ice · Finish Frostbreak before time runs out")
		elif bool(plot.get("pests", false)):
			hud.set_context("PESTS! Yield %d/3 · Press 5, then click to spray them off" % maxi(0, 3 - int(plot.get("pest_ticks", 0))))
		elif not plot.unlocked:
			hud.set_context("LOWER FIELD · 12 more plots · Unlock at Tools for $1.8K")
		elif int(plot.stage) == 3:
			hud.set_context("RIPE %s · Click to %s · Store it or sell at the live price" % [str(plot.crop).to_upper(), action])
		elif int(plot.stage) > 0 and bool(plot.watered):
			var seconds: float = maxf(0.0, (float(state.CROPS[str(plot.crop)].grow) - float(plot.elapsed)) / state.crop_growth_speed())
			hud.set_context("%s · %.0fs until ripe · Use this time to check the market" % [str(plot.crop).to_upper(), seconds])
		else:
			var area: int = state.affected_tiles(hover_plot, action).size()
			hud.set_context("%s · Click to work %d tile%s · Every action is yours" % [action.to_upper(), area, "" if area == 1 else "s"])
	elif hit.has("station"):
		var travel_hint: String = "FERRY · Choose an island · Both fields keep growing" if state.current_island > 1 else ("FERRY · Sail to Golden Shores" if state.island2_unlocked else "GOLDEN SHORES · Unlock with $1M and 500 harvested potatoes")
		var descriptions: Dictionary = {"market": "MARKET · Watch prices · Buy seeds · Choose your moment to sell", "barn": "INVENTORY · Seeds, potatoes, crates, builds and keepsakes", "roll": "ROLL HOUSE · Risk earned game coins for rare rewards" if state.roll_available() else state.roll_lock_reason(), "island": travel_hint, "quests": "QUEST BOARD · Farming challenges and rewards", "forge": "WINTER WORKSHOP · Upgrade your manual farming tools", "builds": "WORKSHOP · Your build, abilities and batch processor"}
		descriptions["activities"] = "DUCK PATROL · Train ducks to clear pests" if state.current_island == 1 else ("BUYER CONTRACTS · Supply harvests or valuable mutations" if state.current_island == 2 else "FROST FURNACE · Burn Icecaps for a growth and processing burst")
		descriptions["duck_patrol"] = "DUCK PATROL · Train this island's ducks to clear pests"
		descriptions["tools"] = "TOOL UPGRADES · Meet the toolsmith · Work more beds with each action"
		hud.set_context(descriptions.get(str(hit.station), "TATERLAND"))
	else:
		hud.set_context("")

func _on_state_changed() -> void:
	if world != null:
		if world.current_island != state.current_island:
			_on_island_changed(state.current_island)
		world.update_plots(state.plots)
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
		_update_market_impact()

func _update_market_impact() -> void:
	if _tutorial_active():
		hud.set_market_intensity(state.current_island, 0.0)
		surge_live = false
		surge_band = 0
		fanfare_remaining = 0.0
		return
	var peak: float = float(state.market[state.selected_crop].change)
	var crazy: bool = peak > 300.0
	var band: int = 2 if peak > 1000.0 else (1 if crazy else 0)
	hud.set_market_intensity(state.current_island, peak)
	if band > surge_band:
		fanfare_island = state.current_island
		fanfare_remaining = 1.2
		fanfare_phase = 0.0
	surge_live = crazy
	surge_band = band

func _on_island_changed(id: int) -> void:
	_cancel_walk()
	if hud != null:
		hud.close_panel()
	world.switch_island(id)
	_reset_camera_zoom()
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
	if hud != null:
		hud.update_state(state)
		hud.set_context("")

func _on_export_changed(active: bool) -> void:
	world.set_export_state(active, state.export_timer)
	if active:
		if state.current_island == 2:
			world.play_reward("legendary")
		_play_tone(1046.0, 0.7)
		sparkle_tone = true

func _on_action(action: String) -> void:
	if hud.is_roll_animating():
		return
	if action.begins_with("tutorial:"):
		match action.get_slice(":", 1):
			"next": tutorial.next()
			"skip": tutorial.finish()
			"restart": tutorial.start(true)
		return
	if _tutorial_active() and not tutorial.allows_action(action):
		return
	var parts: PackedStringArray = action.split(":")
	match parts[0]:
		"menu", "tracked_prices", "market", "barn", "inventory", "builds", "tools", "roll", "help", "pause", "dex", "island", "quests", "activities", "duck_patrol", "debug":
			if parts[0] == "debug" and parts.size() > 1:
				if parts[1] == "apply" and parts.size() == 4:
					# Invalid text must not silently become a zero-money multiplier.
					var parsed_money: Dictionary = HudScript.DebugMoneyInput.parse_number(parts[2])
					if parsed_money.has("error") or not parts[3].is_valid_float():
						hud.show_toast(str(parsed_money.get("error", "Enter a valid luck multiplier.")))
						return
					state.apply_debug(float(parsed_money["value"]), float(parts[3]))
				elif parts[1] == "reset":
					state.reset_debug()
				if not test_mode:
					state.save_game()
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
				_cancel_walk()
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
				"duck": activities.buy_duck()
				"contract":
					if parts.size() == 3:
						activities.choose_contract(parts[2])
				"deliver": activities.deliver_contract()
				"furnace":
					if parts.size() == 3:
						activities.charge_furnace(parts[2])
			if not test_mode:
				state.save_game()
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
		"build":
			match parts[1]:
				"select": builds.select_build(parts[2])
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
			world.set_player_position(Vector3(0, 0, 9))
			_select_tool("hoe")
			hud.close_panel()
			tutorial.start()
	if _tutorial_active():
		tutorial.observe_action(action)

func _on_purchase_completed(receipt: Dictionary) -> void:
	hud.show_purchase(receipt)
	_play_tone(740.0, 0.12)
	if _tutorial_active():
		tutorial.observe_purchase(receipt)

func _on_purchase_rejected(message: String) -> void:
	hud.show_toast(message)

func _on_notification(message: String) -> void:
	if rolling_request or hud.is_roll_animating():
		return
	# Routine work, quotes and shipments are already visible in the field and HUD.
	# Keep interruptions for problems and milestones that need the player's attention.
	var lower: String = message.to_lower()
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
			var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
			var pitch: float = 1.0 if fanfare_island == 1 else (1.12246 if fanfare_island == 2 else 1.25992)
			var note: int = mini(3, int(age / 0.13))
			var envelope: float = minf(1.0, age * 65.0) * minf(1.0, fanfare_remaining * 3.0)
			sample += (sin(fanfare_phase * TAU) + 0.35 * sin(fanfare_phase * TAU * 2.0) + 0.18 * sin(fanfare_phase * TAU * 3.0)) * envelope * 0.28
			fanfare_phase = fmod(fanfare_phase + notes[note] * pitch / 22050.0, 1.0)
			fanfare_remaining -= 1.0 / 22050.0
		audio_playback.push_frame(Vector2(sample, sample))
