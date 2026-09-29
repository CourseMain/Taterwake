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
	check(game.pest_alert.player.stream == game.pest_alert.attack_sound, "attack uses the rising chirp sound")
	var sound: AudioStreamWAV = game.pest_alert.attack_sound
	var peak: int = 0
	var sum_squares: float = 0.0
	for index in range(0, sound.data.size(), 2):
		var value: int = int(sound.data[index]) | (int(sound.data[index + 1]) << 8)
		if value >= 32768: value -= 65536
		peak = maxi(peak, absi(value))
		sum_squares += float(value) * float(value)
	check(peak > 12000 and peak < 32767 and sqrt(sum_squares / (sound.data.size() / 2.0)) > 4000.0, "warning PCM is audible and does not clip")
	check(sound.get_length() > 0.8 and game.pest_alert.lost_sound.data != sound.data, "attack and crop-loss sounds are distinct and long enough to notice")
	game._play_tone(440.0, 0.1)
	check(game.pest_alert.player.stream == sound and game.pest_alert.player.playing, "tool sounds cannot overwrite the pest warning channel")
	for index in range(10):
		game._on_pest_warning(index, false)
	check(game.pest_alert.alerts_played == 1, "a field-wide outbreak produces one grouped alarm")
	game.pest_alert.update(5.9, 1)
	check(game.pest_alert.alerts_played == 1, "warning reminder does not repeat early")
	game.pest_alert.update(0.11, 1)
	check(game.pest_alert.alerts_played == 2, "unresolved pests repeat an alert after six seconds")
	game.perform_plot(4, "pest")
	game._process(0.05)
	check(not game.pest_alert.player.playing and game.pest_alert.infested_count == 0, "spraying the last infestation stops the attack alarm")
	var alerts: int = game.pest_alert.alerts_played
	game.pest_alert.update(12.0, 0)
	check(game.pest_alert.alerts_played == alerts, "clean fields remain quiet")
	plot.pests = true
	game._on_state_changed()
	game.state.update(15.0)
	check(game.pest_alert.last_kind == "lost" and game.pest_alert.player.stream == game.pest_alert.lost_sound, "destroyed crop plays a separate descending loss alert")
	alerts = game.pest_alert.alerts_played
	game._on_pest_warning(5, true)
	check(game.pest_alert.alerts_played == alerts, "simultaneous crop losses do not stack loud alarms")
	game.pest_alert.update(0.01, 0)
	check(game.pest_alert.player.playing, "crop-loss sound finishes even when no crops remain infested")
	if "--capture" in OS.get_cmdline_user_args():
		check(game.pest_alert.attack_sound.save_to_wav("res://artifacts/pest-attack-alert.wav") == OK, "attack warning exports as a playable sound")
		check(game.pest_alert.lost_sound.save_to_wav("res://artifacts/pest-crop-lost.wav") == OK, "crop-loss warning exports as a playable sound")
	# Release the test's own PCM reference before checking scene shutdown.
	var attack_reference: WeakRef = weakref(game.pest_alert.attack_sound)
	var loss_reference: WeakRef = weakref(game.pest_alert.lost_sound)
	sound = null
	game.queue_free()
	await process_frame
	# AudioServer fades stopped streams out on its mixer thread. A short test
	# must let that thread retire its playback references before engine exit.
	await create_timer(0.3).timeout
	for attempt in range(12):
		if attack_reference.get_ref() == null and loss_reference.get_ref() == null:
			break
		await create_timer(0.05).timeout
	check(attack_reference.get_ref() == null and loss_reference.get_ref() == null, "scene shutdown releases warning sounds and their mixer playback references")
	print("PEST AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
