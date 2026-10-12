extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for frame in range(8): await process_frame
	game.set_process(false); game.year_intro.stop(); game.tutorial.active = false; game.hud.set_tutorial({})
	var button := Button.new(); button.text = "Sell"; game.hud._body.add_child(button)
	check(button.get_meta("tap_feedback",false), "new card buttons receive feedback automatically")
	var sound_before: int = game.feedback_audio.played_count
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	button.gui_input.emit(event)
	check(button.scale == Vector2(.96,.96), "tap changes the drawing during input dispatch")
	check(game.feedback_audio.played_count == sound_before+1, "tap starts the authored sound during input dispatch")
	(button.get_meta("tap_tween") as Tween).custom_step(.15)
	check(button.scale == Vector2.ONE, "tap restores the drawing")
	button.disabled = true; game.tap_feedback._last_tick -= 31
	var journal: Dictionary = game.state.ledger.save_data()
	button.gui_input.emit(event)
	check(button.has_meta("refusal_tween"), "a disabled control answers a refused tap")
	check(game.state.ledger.save_data() == journal, "disabled feedback cannot commit a transaction")
	button.set_meta("action", "sell_amount:russet:5"); game.tap_feedback._last_tick -= 31
	button.gui_input.emit(event)
	check(game.hud._refusal_caption.text == "Too little stock. Reduce the quantity.", "disabled tonne buttons explain their stock refusal")
	check(await preload("res://tests/audio_fixture.gd").release(game,self), "audio releases")
	game.queue_free()
	for frame in range(8): await process_frame
	print("TAP FEEDBACK: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
