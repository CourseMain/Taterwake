extends SceneTree
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)

	for plot in game.state.plots:
		game.state._clear_crop(plot)
	var plot: Dictionary = game.state.plots[4]
	plot.merge({"stage": 3, "crop": "russet", "tilled": true, "watered": true, "elapsed": 10.0, "pests": true}, true)
	game._on_state_changed()
	check(game.pest_alert.alerts_played == 1 and game.pest_alert.last_kind == "attack", "real infested crop starts the dedicated warning")
	var mix = preload("res://scripts/sound_mix.gd")
	check(game.pest_alert.player.stream == game.pest_alert.CUES[0] and game.pest_alert.player.volume_db == -14, "first pest cue uses the target mix")
	for cue in game.pest_alert.CUES:
		check(cue.get_length() > .2 and cue.get_length() < 1, "each pest cue is short and prebuilt")
	for index in range(10): game._on_pest_warning(index, false)
	check(game.pest_alert.alerts_played == 1, "field-wide infestation makes one grouped cue")
	mix.advance(19.9); game.pest_alert.update(19.9, 1)
	check(game.pest_alert.alerts_played == 1, "pests cannot repeat inside twenty seconds")
	mix.advance(.2); game.pest_alert.update(.2, 1)
	check(game.pest_alert.alerts_played == 2 and game.pest_alert.last_cue == 1, "next cue rotates after twenty seconds")
	mix.advance(20); game.pest_alert.update(20, 1)
	check(game.pest_alert.alerts_played == 3 and game.pest_alert.last_cue == 2, "third reminder uses the third cue")
	check(not mix.allow_alert(), "a second alert cannot overlap within two seconds")
	mix.advance(20); game.pest_alert.update(20, 1)
	check(game.pest_alert.last_cue == 0, "all three cues rotate in order")
	game.perform_plot(4, "pest")
	game._process(.05)
	check(not game.pest_alert.player.playing and game.pest_alert.infested_count == 0, "cleared fields stop the reminder")
	var alerts: int = game.pest_alert.alerts_played
	mix.advance(40); game.pest_alert.update(40, 0)
	check(game.pest_alert.alerts_played == alerts, "clean fields remain quiet")
	mix.quieter = true
	check(mix.gain() < -6 and mix.gain(true) == 0, "Quieter halves ordinary sounds while keeping tool cues")
	mix.quieter = false
	game.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("PEST AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
