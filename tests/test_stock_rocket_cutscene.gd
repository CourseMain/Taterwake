extends SceneTree
## An isolated cinematic fixture. Never instantiates GameState or reads saves.
const Rocket = preload("res://scripts/stock_rocket_cutscene.gd")
var checks: int = 0
var failures: int = 0
var completions: int = 0
var capture: bool = false
var film: Control
var button_presses: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _shot(filename: String) -> void:
	if not capture:
		return
	film._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "capture " + filename)

func _press_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		push_error("Run with -- --integration-test or --capture")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var began: int = Time.get_ticks_usec()
	film = Rocket.new()
	layer.add_child(film)
	print("Rocket setup and original PCM synthesis: %.2f ms" % ((Time.get_ticks_usec() - began) / 1000.0))
	film.finished.connect(func() -> void: completions += 1)
	await process_frame
	check(not film.active and not film.visible and not film.is_processing(), "mounting has no visible or processing side effects")
	check(film.mouse_filter == Control.MOUSE_FILTER_STOP, "cinematic catches pointer input")
	check(film.size.is_equal_approx(root.get_visible_rect().size), "cinematic fills the viewport")
	check(film._sound.stereo and is_equal_approx(film._sound.get_length(), Rocket.DURATION), "original stereo score spans the whole cinematic")
	var pcm_data: PackedByteArray = film._sound.data
	var peak: int = 0
	var rms_sum: float = 0.0
	for i in range(0, pcm_data.size(), 2):
		var value: int = int(pcm_data[i]) | (int(pcm_data[i + 1]) << 8)
		if value >= 32768:
			value -= 65536
		peak = maxi(peak, absi(value))
		rms_sum += float(value) * float(value)
	check(peak > 12000 and peak < 32767, "launch score is audible without clipping")
	check(sqrt(rms_sum / (pcm_data.size() / 2.0)) > 1500, "score has a sustained cinematic sound bed")
	var child_count: int = film.get_child_count()
	var button := Button.new()
	button.text = "Underlying HUD action"
	root.add_child(button)
	button.pressed.connect(func() -> void: button_presses += 1)
	var next_button := Button.new()
	next_button.text = "Next HUD action"
	next_button.position.y = 60.0
	root.add_child(next_button)
	button.focus_next = button.get_path_to(next_button)
	button.grab_focus()
	_press_key(KEY_ENTER)
	check(button_presses == 1, "a focused underlying button responds to real ui_accept input before playback")
	film.start()
	film.set_process(false)
	check(root.gui_get_focus_owner() == null and film.is_processing_input(), "start clears HUD keyboard focus and enables the input trap")
	_press_key(KEY_TAB)
	check(root.gui_get_focus_owner() == null, "Tab cannot enter the underlying HUD during playback")
	# Even a HUD refresh that takes focus again must not bypass the trap.
	button.grab_focus()
	_press_key(KEY_ENTER)
	_press_key(KEY_TAB)
	check(button_presses == 1 and root.gui_get_focus_owner() == button, "focused HUD buttons cannot activate or traverse focus during playback")
	film.stop()
	_press_key(KEY_ENTER)
	_press_key(KEY_TAB)
	check(button_presses == 2 and root.gui_get_focus_owner() == next_button and not film.is_processing_input(), "stopping restores normal HUD activation and Tab navigation")
	button.queue_free()
	next_button.queue_free()
	film.start()
	film.set_process(false)
	check(film.active and film.visible and film.elapsed == 0.0 and film.island == 3, "default start resets and displays the cinematic")
	check(film._player.playing, "start plays the dedicated launch audio channel")
	for invalid: float in [-1.0, NAN, INF]:
		film._process(invalid)
	check(film.elapsed == 0.0 and film.active and completions == 0, "invalid frame deltas cannot end or corrupt the film")
	film._process(1.0)
	check(film._altitude() == 0.0 and film._ignition() == 0.0, "countdown keeps the rocket on the launchpad")
	await _shot("rocket-01-countdown")
	film._process(1.58)
	check(film._ignition() > 0.9 and film._altitude() == 0.0 and film._shake().length() > 0.2, "ignition and screen shake precede liftoff")
	await _shot("rocket-02-ignition")
	film._process(0.72)
	var first_height: float = film._altitude()
	check(first_height > 50.0 and film._rocket_position().y < 560.0 and completions == 0, "rocket ascends while completion remains pending")
	await _shot("rocket-03-liftoff")
	film._process(1.30)
	check(film._altitude() > first_height * 4.0 and film._camera_offset() > 150.0 and film._rocket_scale() < 1.0, "ascent accelerates, camera tracks, and view pulls back")
	await _shot("rocket-04-ascent")
	film._process(1.85)
	check(film.active and completions == 0, "final title still belongs to the cinematic before market handoff")
	await _shot("rocket-05-finale")
	root.size = Vector2i(960, 600)
	await process_frame
	check(film.size.is_equal_approx(root.get_visible_rect().size), "minimum desktop viewport is filled after resize")
	await _shot("rocket-06-finale-small")
	root.size = Vector2i(1600, 900)
	await process_frame
	check(film.size.is_equal_approx(root.get_visible_rect().size), "wide viewport is filled after resize")
	await _shot("rocket-07-finale-wide")
	film._process(20.0)
	check(not film.active and not film.visible and not film.is_processing() and completions == 1, "oversized final frame hides film and emits exactly one completion")
	check(not film._player.playing, "completion stops its sound")
	film._process(20.0)
	check(completions == 1, "processing a completed film cannot emit twice")
	film.start(2)
	film.set_process(false)
	check(film.island == 2 and film.elapsed == 0.0 and film.active, "restart resets time and selects the new island")
	film._process(3.0)
	film.stop()
	check(completions == 1 and not film.active and not film._player.playing, "cancellation hides/stops without announcing a stock boom")
	film.start(99)
	film.set_process(false)
	check(film.island == 3 and film.get_child_count() == child_count, "restarts reuse child canvases and audio, clamping invalid islands")
	film._process(Rocket.DURATION - 0.001)
	check(completions == 1 and film.active, "handoff never occurs before the advertised duration")
	film._process(0.0011)
	check(completions == 2 and not film.active, "each completed playback announces one handoff")
	if capture:
		check(film._sound.save_to_wav("res://artifacts/stock-rocket-original-launch.wav") == OK, "export original cinematic soundtrack")
	film.queue_free()
	layer.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("STOCK ROCKET CINEMATIC: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
