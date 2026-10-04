extends Node
## Disposable export fixture. It never loads or writes a player's farm.
## Frame intervals use the monotonic clock, not Godot's capped simulation delta.
const SAVE_PATH: String = "user://feel-benchmark-test-only.json"
const Stock = preload("res://scripts/graded_stock.gd")
var game
var callback
var measurements: Array[Dictionary] = []
var boundaries: Array[Dictionary] = []
var sample_name: String = ""
var warmup_left: float = 0
var sample_seconds: float = 0
var sample_elapsed: float = 0
var previous_frame: int = 0
var frames_ms: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var draw_calls: Array[float] = []
var render_objects: Array[float] = []
var shadow_size: int = 4096
var sample_active: bool = false
var sampling: bool = false
var full_year: bool = false
var year_started: int = 0
var last_publication: Dictionary = {}
var pending_boundary: int = -1
var slowest_frames: Array[Dictionary] = []

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	assert(game.test_mode, "The browser fixture must be exported in integration mode.")
	game.state.boundary_save_path = SAVE_PATH
	game.state.season_changed.connect(_boundary_saved)
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	while not game.world.visuals.winter_materials_ready: await get_tree().process_frame
	if OS.has_feature("web"):
		callback = JavaScriptBridge.create_callback(command)
		JavaScriptBridge.get_interface("window").feelQA = callback
	_publish()

func command(args: Array) -> void:
	if args.is_empty(): return
	var action: String = str(args[0])
	var fields: PackedStringArray = action.split(":")
	match fields[0]:
		"rain":
			shadow_size = int(fields[1]) if fields.size() > 1 else 4096
			_prepare_farm(5, 1)
			game.state.climate.begin_warning(game.state, "storm", 0.65)
			game.state.climate._impact(game.state)
			game.hud._climate_alert.dismiss()
			game._on_state_changed()
			_start_sample("summer_rain_shadow_%d" % shadow_size, float(fields[2]) if fields.size() > 2 else 12.0, 3.0)
		"boundary":
			var stress: bool = fields.size() > 1 and fields[1] == "stress"
			_prepare_farm(10 if stress else 1, 2)
			if stress:
				for year in range(1, 10): game.state.ledger.post_fixed_costs(year)
				for i in range(3000):
					var year: int = i % 10 + 1
					game.state.ledger.post(year, mini(i % 4, 2) if year == 10 else i % 4, "sales", "Benchmark journal receipt %04d" % i, 0.25 if i % 2 == 0 else -0.25)
				game.state.coins = 140000
			game.state.season_clock.seconds = game.state.season_seconds() - 0.65
			game._on_state_changed()
			_start_sample("boundary_year10_3000_entries" if stress else "boundary_ordinary_year1", 3.0, 0.0)
		"year":
			_prepare_farm(1, 0)
			full_year = true
			year_started = 1
			_start_sample("full_year_real_hold", 900.0, 0.0)
		"status": pass
		_:
			push_error("Unknown feel benchmark command: " + action)
	_publish()

func _prepare_farm(year: int, season: int) -> void:
	sample_active = false
	full_year = false
	game.set_process(false)
	game.conversation.finish()
	game.hud.close_panel()
	game.year_intro.stop()
	game.state.reset_game()
	game.state.rng.seed = 712804
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	game.state.season_clock.year = year
	game.state.season_clock.season = season
	game.state.season_clock.seconds = 0
	game.state.accounts_open = false
	game.state.climate_report_open = false
	game.state.coins = 140000
	game.state.boundary_save_path = SAVE_PATH
	game.state.climate.data.outlook.started = (year - 1) * 4 + season
	game.state.climate.data.outlook.seen_year = year
	game.state.climate.prime_next(game.state)
	for i in range(game.state.plots.size()):
		game.state._clear_crop(game.state.plots[i])
		if i < 24:
			game.state.plots[i].merge({"unlocked": true, "tilled": true, "watered": true, "stage": 2, "crop": "russet", "elapsed": 30.0, "quality": 100}, true)
	for project in ["rainwater", "drainage", "windbreaks", "frost"]: game.state.climate.data.projects[project] = 1
	Stock.add(game.state.storage, "russet", 12, 90)
	game._apply_graphics_quality("balanced")
	game._set_shadow_size(shadow_size)
	shadow_size = game.shadow_size
	game.hud._climate_alert.dismiss()
	game.hud._toast_box.hide()
	game._on_state_changed()
	boundaries.clear()
	pending_boundary = -1
	for node in [game.hud, game.touch_controls, game.world, game.world.visuals, game]:
		if node.get("_feel_profile") is Dictionary: node.set("_feel_profile", {})
	game.set_process(true)

func _start_sample(id: String, duration: float, warmup: float) -> void:
	sample_name = id
	warmup_left = warmup
	sample_seconds = clampf(duration, 2, 900)
	sample_elapsed = 0
	frames_ms.clear()
	process_ms.clear()
	physics_ms.clear()
	draw_calls.clear()
	render_objects.clear()
	slowest_frames.clear()
	previous_frame = Time.get_ticks_usec()
	sample_active = true
	sampling = warmup == 0

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var interval_ms: float = (now - previous_frame) / 1000.0 if previous_frame else 0.0
	previous_frame = now
	if pending_boundary >= 0:
		boundaries[pending_boundary].following_frame_ms = interval_ms
		pending_boundary = -1
	if not sample_active or interval_ms <= 0: return
	if warmup_left > 0:
		warmup_left -= interval_ms / 1000.0
		if warmup_left <= 0:
			sampling = true
			_publish()
		return
	frames_ms.append(interval_ms)
	if interval_ms > 20:
		slowest_frames.append({"ms": interval_ms, "at_seconds": sample_elapsed,
			"year": game.state.season_clock.year, "season": game.state.season_clock.season, "accounts": game.state.accounts_open})
		slowest_frames.sort_custom(func(a, b): return a.ms > b.ms)
		if slowest_frames.size() > 12: slowest_frames.resize(12)
	process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	draw_calls.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	render_objects.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))
	sample_elapsed += interval_ms / 1000.0
	if full_year:
		if game.state.season_clock.year > year_started and game.state.season_clock.season == 0:
			_finish_sample()
		elif sample_elapsed >= sample_seconds:
			_finish_sample("Full year timed out; no simulation shortcut was used.")
	elif sample_elapsed >= sample_seconds:
		_finish_sample()

func _boundary_saved() -> void:
	if not sample_active: return
	var record: Dictionary = {"year": game.state.season_clock.year, "season": game.state.season_clock.season,
		"sample_elapsed_seconds": sample_elapsed, "journal_entries": game.state.ledger.entry_count(),
		"save_ms": game.state.get("last_save_ms"), "save_path": SAVE_PATH,
		"callback_elapsed_in_frame_ms": (Time.get_ticks_usec() - previous_frame) / 1000.0}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	record.file_bytes = file.get_length() if file != null else 0
	boundaries.append(record)
	pending_boundary = boundaries.size() - 1

func _finish_sample(error: String = "") -> void:
	sample_active = false
	sampling = false
	var result: Dictionary = {"id": sample_name, "seconds": sample_elapsed, "frames": frames_ms.size(),
		"fps": frames_ms.size() / maxf(sample_elapsed, 0.001), "frame_ms": _statistics(frames_ms),
		"godot_process_ms": _statistics(process_ms), "godot_physics_ms": _statistics(physics_ms),
		"draw_calls": _statistics(draw_calls), "render_objects": _statistics(render_objects),
		"boundaries": boundaries.duplicate(true), "slowest_frames": slowest_frames.duplicate(true), "shadow_size": shadow_size, "metadata": _metadata(), "error": error,
		"time_source": "Godot monotonic process-to-process intervals, including render and browser scheduling",
		"cpu_source": "Godot Performance TIME_PROCESS/TIME_PHYSICS_PROCESS monitors; engine monitor samples, not GPU timings"}
	if full_year:
		result.simulation_seconds = game.state.elapsed
		result.observed_pace = game.state.elapsed / maxf(sample_elapsed, 0.001)
	result.stage_timings = {}
	for entry in [{"name": "hud", "node": game.hud}, {"name": "touch", "node": game.touch_controls}, {"name": "world", "node": game.world}, {"name": "visuals", "node": game.world.visuals}, {"name": "main", "node": game}]:
		var timings: Variant = entry.node.get("_feel_profile")
		if timings is Dictionary: result.stage_timings[entry.name] = timings.duplicate(true)
	result.stage_timing_note = "Optional disposable wrappers include child calls in parent timings; recursive totals overlap. They are diagnostic CPU timings, not an uninstrumented FPS comparison."
	var slow_frames: int = 0
	var missed_refreshes: int = 0
	for frame in frames_ms:
		if frame > 20: missed_refreshes += 1
		if frame > 33.34: slow_frames += 1
	result.frames_above_20ms = missed_refreshes
	result.frames_above_33_34ms = slow_frames
	# Verify the latest boundary on disk after the timed sample, so JSON parsing
	# by this diagnostic cannot inflate the boundary frame being measured.
	if not boundaries.is_empty():
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		result.saved_boundary = saved.get("season_clock", {}) if saved is Dictionary else {}
		result.saved_journal_entries = saved.get("ledger", {}).get("entries", []).size() if saved is Dictionary else 0
	measurements.append(result)
	_publish()
	print("FEEL_BROWSER " + JSON.stringify(result))

func _statistics(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0
	for value in sorted: total += value
	return {"count": values.size(), "mean": total / values.size(), "median": sorted[clampi(ceili(values.size() * 0.5) - 1, 0, values.size() - 1)],
		"p95": sorted[clampi(ceili(values.size() * 0.95) - 1, 0, values.size() - 1)],
		"p99": sorted[clampi(ceili(values.size() * 0.99) - 1, 0, values.size() - 1)], "max": sorted.back()}

func _metadata() -> Dictionary:
	return {"version": ProjectSettings.get_setting("application/config/version"), "godot": Engine.get_version_info(),
		"renderer": RenderingServer.get_video_adapter_name(), "renderer_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "display": DisplayServer.get_name(),
		"window_backing": [get_tree().root.size.x, get_tree().root.size.y], "logical_canvas": [game.hud.root.size.x, game.hud.root.size.y],
		"farm_render": [game.farm_viewport.size.x, game.farm_viewport.size.y], "graphics": game.graphics_quality,
		"farm_msaa": game.farm_viewport.msaa_3d, "shadow_size_forced": shadow_size,
		"shadow_size_project": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"),
		"shadow_size_mobile": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size.mobile"),
		"soft_filter_project": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"),
		"soft_filter_mobile": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile"),
		"test_mode": game.test_mode, "save_path": game.state.boundary_save_path}

func _publish() -> void:
	var buttons: Array = []
	for node in [game.hud.root, game.touch_controls.root, game.conversation, game.year_intro]: _buttons(node, buttons)
	last_publication = {"ready": true, "sample": {"id": sample_name, "active": sample_active, "sampling": sampling, "elapsed": sample_elapsed},
		"measurements": measurements, "state": {"year": game.state.season_clock.year, "season": game.state.season_clock.season,
			"seconds": game.state.season_clock.seconds, "accounts": game.state.accounts_open, "cause_card": game.state.climate_report_open,
			"conversation": game.conversation.visible, "panel": game.hud._panel_kind, "run_over": game.state.run_over,
			"weather": game.state.climate.data.phase, "event": game.state.climate.data.event,
			"hurry_active": game.get("hurry_active") == true, "simulation_elapsed": game.state.elapsed,
			"touch": game.touch_controls.enabled, "hurry_action": InputMap.has_action("hurry"), "buttons": buttons,
			"logical_canvas": [game.hud.root.size.x, game.hud.root.size.y]}, "metadata": _metadata()}
	if OS.has_feature("web"): JavaScriptBridge.eval("window.feelReport=" + JSON.stringify(last_publication), true)

func _buttons(node: Node, output: Array) -> void:
	if node is Button and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		output.append({"text": node.text, "action": node.get_meta("hud_action", ""), "disabled": node.disabled,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child in node.get_children(): _buttons(child, output)
