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
	for frame in range(stream.data.size() / 2):
		var sample: int = stream.data.decode_s16(frame * 2)
		peak = maxi(peak, absi(sample))
		squares += float(sample) * sample
		if sample != 0 and previous != 0 and signi(sample) != signi(previous): crossings += 1
		if sample != 0: previous = sample
	return {"peak": peak, "rms": sqrt(squares / (stream.data.size() / 2)), "crossings": crossings}

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
	var table: Dictionary = metrics(Foley.CLIPS.grade_table)
	var standard: Dictionary = metrics(Foley.CLIPS.grade_standard)
	var feed: Dictionary = metrics(Foley.CLIPS.grade_feed)
	check(table.crossings > standard.crossings and standard.crossings > feed.crossings, "Table, Standard and Feed stamps have distinct descending pitches")
	check(Foley.CLIPS.grade_table.data != Foley.CLIPS.grade_standard.data and Foley.CLIPS.grade_standard.data != Foley.CLIPS.grade_feed.data, "grades use independent authored waveforms")
	check(float(metrics(Foley.CLIPS.foreclosure).crossings) / Foley.CLIPS.foreclosure.get_length() / 2 < 100, "foreclosure is a low note")
	for index in range(4):
		var stream: AudioStreamWAV = Ambience.STREAMS[index]
		var level: Dictionary = metrics(stream)
		check(stream.get_length() == 8 and level.rms > 200 and level.peak < 32767, "season %d has an audible short ambience loop" % index)
		check(absi(stream.data.decode_s16(0)) < 100 and absi(stream.data.decode_s16(stream.data.size() - 2)) < 100, "season %d joins without a PCM seam" % index)
		if index > 0: check(stream.data != Ambience.STREAMS[index - 1].data, "adjacent seasons have different sound beds")
	check(metrics(Ambience.STREAMS[3]).crossings < metrics(Ambience.STREAMS[2]).crossings, "Winter wind is audibly muffled relative to Autumn")
	var foley := Foley.new()
	root.add_child(foley)
	foley.play_action("harvest")
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
	ambience.advance(1)
	check(ambience.gains == [1.0, 0.0, 0.0, 0.0], "Spring settles at its sole loop")
	ambience.set_season(1)
	ambience.advance(.5)
	check(ambience.gains == [.5, .5, 0.0, 0.0], "season crossfade has both loops at its half-second midpoint")
	ambience.set_season(1)
	check(ambience.elapsed == .5, "repeated per-frame state requests cannot restart the fade")
	ambience.advance(.499)
	check(ambience.gains[0] > 0 and ambience.gains[1] < 1, "crossfade never completes before one second")
	ambience.advance(.001)
	check(ambience.gains == [0.0, 1.0, 0.0, 0.0], "crossfade completes at exactly one second")
	for player in ambience.players:
		var loop: AudioStreamWAV = player.stream
		check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end == 176400, "ambience is a bounded loop over the full authored clip")
	ambience.set_season(1, true)
	ambience.advance(1)
	check(ambience.gains == [0.0, 0.0, 0.0, 0.0], "paused presentation fades all seasonal channels out")
	ambience.queue_free()
	foley.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("FARM AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
