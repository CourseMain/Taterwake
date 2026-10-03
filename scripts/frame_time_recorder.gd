extends Node
## Device-only diagnostics. Samples never enter the farm's save or journal.
signal finished
signal copied(ok: bool)
var game
var recording: bool = false
var samples := PackedFloat64Array()
var report_text: String = ""
var report: Dictionary = {}
var _previous_tick: int = 0
var _target_year: int = 0
var _saw_accounts: bool = false
var _worst_ms: float = 0
var _worst_season: int = 0
var _shadow_sizes: Array[int] = []
var _resolutions: Array[Vector2i] = []
var _clipboard_callback

func start() -> bool:
	if game.state.run_over or game.state.tutorial_active or game.state.ClimateSystem.Lesson.active(game.state): return false
	samples.clear()
	report.clear()
	report_text = ""
	_worst_ms = 0
	_shadow_sizes.clear()
	_resolutions.clear()
	_target_year = game.state.season_clock.year + (1 if game.state.season_clock.season == 3 and not game.state.accounts_open else 0)
	_saw_accounts = game.state.accounts_open and game.state.season_clock.year == _target_year
	_previous_tick = Time.get_ticks_usec()
	_capture_context()
	recording = true
	return true

func _process(_delta: float) -> void:
	if not recording: return
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = (now - _previous_tick) / 1000.0
	_previous_tick = now
	_capture_context()
	observe(frame_ms, game.state.season_clock.year, game.state.season_clock.season, game.state.accounts_open, game.state.run_over)

func _capture_context() -> void:
	var shadow: int = game.shadow_size if game.world._sun.shadow_enabled else 0
	var resolution: Vector2i = get_tree().root.size
	if shadow not in _shadow_sizes: _shadow_sizes.append(shadow)
	if resolution not in _resolutions: _resolutions.append(resolution)

func observe(frame_ms: float, year: int, season: int, accounts: bool, ended: bool = false) -> void:
	if not recording or not is_finite(frame_ms) or frame_ms <= 0: return
	samples.append(frame_ms)
	if frame_ms > _worst_ms:
		_worst_ms = frame_ms
		_worst_season = season
	if year == _target_year and season == 3 and accounts: _saw_accounts = true
	if _saw_accounts and not accounts: finish("Winter accounts closed")
	elif ended: finish("Run ended before Winter accounts closed")

static func statistics(frames: PackedFloat64Array) -> Dictionary:
	if frames.is_empty(): return {"frames": 0, "mean_fps": 0.0, "low_fps": 0.0, "worst_ms": 0.0}
	var sorted: PackedFloat64Array = frames.duplicate()
	sorted.sort()
	var total: float = 0
	for ms in sorted: total += ms
	var tail_count: int = maxi(1, ceili(sorted.size() / 100.0))
	var tail_total: float = 0
	for index in range(sorted.size() - tail_count, sorted.size()): tail_total += sorted[index]
	return {"frames": sorted.size(), "mean_fps": sorted.size() * 1000.0 / total,
		"low_fps": tail_count * 1000.0 / tail_total, "worst_ms": sorted[-1]}

func finish(reason: String) -> void:
	if not recording: return
	recording = false
	report = statistics(samples)
	report.device = "%s · %s" % [OS.get_model_name(), OS.get_name()]
	if OS.has_feature("web"):
		report.device += "\n" + str(JavaScriptBridge.eval("navigator.userAgent", true))
	var shadows := PackedStringArray()
	for size in _shadow_sizes: shadows.append("Off" if size == 0 else str(size))
	var resolutions := PackedStringArray()
	for size in _resolutions: resolutions.append("%d×%d" % [size.x, size.y])
	report.shadows = ", ".join(shadows)
	report.resolution = ", ".join(resolutions)
	report.worst_season = game.state.SeasonClock.NAMES[_worst_season]
	report.reason = reason
	report_text = "Taterland · %s\n%s\nDevice: %s\nShadow map: %s\nResolution: %s\nFrames: %d\nMean: %.1f fps\n1%% low: %.1f fps\nWorst: %.2f ms · %s\n1%% low = mean fps of the slowest 1%% of frames.\nFrame intervals include rendering and browser scheduling." % [ProjectSettings.get_setting("application/config/version"), reason, report.device, report.shadows, report.resolution, report.frames, report.mean_fps, report.low_fps, report.worst_ms, report.worst_season]
	finished.emit()

func copy_report() -> void:
	if report_text.is_empty(): return
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(report_text)
		copied.emit(true)
		return
	if _clipboard_callback == null:
		_clipboard_callback = JavaScriptBridge.create_callback(func(args): copied.emit(not args.is_empty() and bool(args[0])))
	JavaScriptBridge.get_interface("window").taterMeasurementCopied = _clipboard_callback
	JavaScriptBridge.eval("""(() => {
		const text = %s;
		const done = ok => window.taterMeasurementCopied(ok);
		const fallback = () => {
			const input = document.createElement('textarea');
			input.value = text; input.style.position = 'fixed'; input.style.opacity = '0';
			document.body.appendChild(input); input.select();
			let ok = false; try { ok = document.execCommand('copy'); } catch (_) {}
			input.remove(); done(ok);
		};
		if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(() => done(true), fallback);
		else fallback();
	})()""" % JSON.stringify(report_text), true)
