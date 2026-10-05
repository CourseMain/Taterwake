extends SceneTree
## Audible original cues, cached PCM, and exact seasonal crossfade timing.
const Foley = preload("res://scripts/farm_audio.gd")
const Ambience = preload("res://scripts/farm_ambience.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func metrics(stream: AudioStreamWAV) -> Dictionary:
	var peak: int = 0
	var squares: float = 0
	var crossings: int = 0
	var previous: int = 0
	var stride: int = maxi(1, int(stream.data.size() / 2 / 200000))
	for frame in range(0, stream.data.size() / 2, stride):
		var sample: int = stream.data.decode_s16(frame * 2)
		peak = maxi(peak, absi(sample))
		squares += float(sample) * sample
		if sample != 0 and previous != 0 and signi(sample) != signi(previous): crossings += 1
		if sample != 0: previous = sample
	return {"peak": peak, "rms": sqrt(squares / ceili(float(stream.data.size() / 2) / stride)), "crossings": crossings}

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args():
		quit(1)
		return
	for label: String in Foley.CLIPS:
		var clip: AudioStreamWAV = Foley.CLIPS[label]
		var level: Dictionary = metrics(clip)
		check(clip.format == AudioStreamWAV.FORMAT_16_BITS and clip.mix_rate == 22050, label + " is ready PCM, not a runtime generator")
		check(clip.get_length() >= .1 and level.rms > 200 and level.peak < 32767, label + " is audible with headroom")
	for tone: Array in Foley.TONES:
		var clip: AudioStreamWAV = tone[2]
		check(absf(clip.get_length() - float(tone[1])) < .0001, "cue duration remains authored at " + str(tone[0]))
	check(Foley.bake("harvest") == Foley.bake("harvest") and Foley.bake("giant") == Foley.CLIPS.giant, "foley returns cached assets before the first tool action")
	check(Foley.bake("giant").get_length() > Foley.bake("harvest").get_length(), "heavy harvest retains its longer pull and landing")
	check(Foley.CLIPS.harvest_notes.get_length() > .2, "harvest has one authored two-note cue")
	check(float(metrics(Foley.CLIPS.foreclosure).crossings) / Foley.CLIPS.foreclosure.get_length() / 2 < 100, "foreclosure is a low note")
	for index in range(Ambience.STREAMS.size()):
		var stream: AudioStreamWAV = Ambience.STREAMS[index]
		var level: Dictionary = metrics(stream)
		check(stream.get_length() >= 40 and level.rms > 200 and level.peak < 32767, "season %d has an long nature bed" % index)
		check(absi(stream.data.decode_s16(0)) < 100 and absi(stream.data.decode_s16(stream.data.size() - 2)) < 100, "season %d joins without a PCM seam" % index)
		if index > 0: check(stream.data != Ambience.STREAMS[index - 1].data, "adjacent seasons have different sound beds")
	check(metrics(Ambience.STREAMS[4]).rms < metrics(Ambience.STREAMS[0]).rms, "Winter wind is audibly muffled relative to Autumn")
	var foley := Foley.new()
	root.add_child(foley)
	foley.play_action("harvest")
	preload("res://scripts/sound_mix.gd").advance(3)
	foley.play_grade("Table")
	check(foley.last_kind == "harvest" and foley.last_grade == "Table" and foley.last_cue == "grade:Table", "grade stamp keeps its tool receipt separate")
	var before: int = foley.played_count
	foley.play_grade("unknown")
	check(foley.played_count == before, "unknown grades do not add a false success stamp")
	foley.play_paper()
	check(foley.last_cue == "paper", "accounts has a paper cue")
	foley.play_foreclosure()
	check(foley.last_cue == "foreclosure", "foreclosure has a dedicated cue")
	foley.play_tone(880, .85, true)
	check(foley.last_cue == "reward", "reward keeps the existing bright cue")
	var ambience := Ambience.new()
	root.add_child(ambience)
	ambience.set_process(false)
	ambience.set_season(0)
	ambience.advance(3)
	check(ambience.gains == [.5, .5], "two nature layers fade in together over six seconds")
	ambience.set_season(0)
	check(ambience.elapsed == 3, "per-frame state requests do not restart the fade")
	ambience.advance(3)
	check(ambience.gains == [1.0, 1.0], "both layers settle at the quiet bed level")
	ambience.set_environment({"event":"storm", "phase":"active"}, false)
	ambience.advance(.01)
	check(ambience.players[1].stream == Ambience.STREAMS[3] and ambience.tails[1].stream == Ambience.STREAMS[1], "rain crossfades from the outgoing leaves layer")
	ambience.advance(3)
	check(ambience.layer_age[1] > 3 and ambience.layer_age[1] < 6, "nature crossfade is slow, not an abrupt replacement")
	ambience.advance(3)
	check(ambience.layer_age[1] == 6, "crossfade finishes after six seconds")
	for player in ambience.players:
		check(player.volume_db <= -30 and player.stream.get_length() >= 40, "two half-volume layers keep their combined bed below -24 dB")
	var last: int = -1
	var heard: Dictionary = {}
	for index in range(40):
		ambience.call_wait = 0; ambience.advance(.01)
		check(ambience.last_call != last, "bird calls never repeat consecutively")
		heard[ambience.last_call] = true; last = ambience.last_call
		check(ambience.call_wait >= 20 and ambience.call_wait <= 40, "nature calls leave random twenty-to-forty second gaps")
	check(heard.size() == 6, "all six bird calls can be heard")
	ambience.set_season(1, true)
	ambience.advance(6)
	check(ambience.gains == [0.0, 0.0], "paused presentation fades both nature layers out")
	ambience.queue_free()
	foley.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("FARM AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
