extends SceneTree
## Native fullscreen and keyboard toggles use the real game controls, with no saves.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func settle() -> void:
	for frame in range(8): await process_frame

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	root.mode = Window.MODE_WINDOWED
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.tutorial.start()
	await settle()
	var button: Button = game.touch_controls.fullscreen
	check(not button.visible, "guide hides native fullscreen chrome")
	game.tutorial.finish()
	await settle()
	check(button.visible, "native fullscreen returns when the guide ends")
	check(button.tooltip_text == "Enter fullscreen (F11)", "windowed mode starts with the enter action")
	check(button.get_theme_stylebox("normal") is StyleBoxEmpty, "fullscreen has an invisible background")
	check(button.size.x >= 44 and button.size.y >= 44, "small icon retains a usable click target")
	var headless: bool = DisplayServer.get_name() == "headless"
	button.pressed.emit()
	await settle()
	check(root.mode == (Window.MODE_MINIMIZED if headless else Window.MODE_FULLSCREEN), "fullscreen request reflects the display backend result")
	check(button.tooltip_text == ("Enter fullscreen (F11)" if headless else "Exit fullscreen (F11)"), "button reflects actual display mode, including an unavailable headless window")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F11
	event.pressed = true
	root.push_input(event, true)
	await settle()
	check(root.mode == (Window.MODE_MINIMIZED if headless else Window.MODE_WINDOWED), "F11 uses the same display-mode action")
	check(button.tooltip_text == "Enter fullscreen (F11)", "exit returns the enter icon state")
	if game.touch_controls.enabled:
		root.min_size = Vector2i.ZERO
		for dimensions in [Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			await settle()
			var bounds := root.get_visible_rect()
			check(bounds.encloses(button.get_global_rect()), "fullscreen remains in bounds on " + str(dimensions))
			check(button.size.y * dimensions.y / bounds.size.y >= 43, "fullscreen retains a physical 44px touch target on " + str(dimensions))
	await release_audio()
	game.queue_free()
	await settle()
	print("NATIVE FULLSCREEN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func release_audio() -> void:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var playbacks: Array[WeakRef] = []
	for player: AudioStreamPlayer in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback(): playbacks.append(weakref(player.get_stream_playback()))
		player.stop()
		player.stream = null
	for frame in range(120):
		if playbacks.all(func(ref: WeakRef): return ref.get_ref() == null): break
		await process_frame
	check(playbacks.all(func(ref: WeakRef): return ref.get_ref() == null), "audio playbacks release before fullscreen fixture teardown")
