extends SceneTree
## Offline authoring only. Runtime playback uses these original PCM files.
## Run: godot --headless --path . --script res://tools/bake_farm_audio.gd
const RATE: int = 22050

func _initialize() -> void:
	for kind in ["harvest", "giant", "water", "hoe", "pest", "plant", "ice"]:
		write("farm-" + kind, foley(kind))
	write("ledger-paper", paper())
	write("foreclosure-note", note(130.81, 0.65, false, true))
	for cue in [[164.81, .6, "impact"], [220.0, .6, "warning"], [440.0, .1, "tool"], [740.0, .12, "purchase"], [523.25, .11, "c"], [659.25, .11, "e"], [783.99, .11, "g"], [1046.5, .11, "high-c"]]:
		write("cue-" + str(cue[2]), note(float(cue[0]), float(cue[1])))
	write("cue-reward", note(880, .85, true))
	quit()

func write(label: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for frame in range(samples.size()): bytes.encode_s16(frame * 2, roundi(clampf(samples[frame], -.95, .95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	var result: Error = stream.save_to_wav("res://assets/audio/%s.wav" % label)
	if result != OK:
		push_error("Cannot write " + label)
		quit(1)
	print("%s: %.2f s" % [label, stream.get_length()])

func foley(kind: String) -> PackedFloat32Array:
	# Preserve the original tool/pull/pop/landing envelopes exactly.
	var harvest: bool = kind in ["harvest", "giant"]
	var heavy: bool = kind == "giant"
	var pull: float = .32 if heavy else .18
	var landing: float = pull + (.48 if heavy else .36)
	var duration: float = landing + .36 if harvest else .42
	var samples := PackedFloat32Array()
	samples.resize(int(duration * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9417
	var soft_noise: float = 0
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var noise: float = rng.randf_range(-1, 1)
		soft_noise = lerpf(soft_noise, noise, .18)
		var sample: float = 0
		if harvest:
			if t < pull: sample = (soft_noise * .65 + sin(TAU * (85 * t + 90 * t * t)) * .10) * sin(PI * t / pull)
			var pop: float = t - pull
			if pop >= 0: sample += (sin(TAU * (160 * pop + 4 * (1 - exp(-pop * 35)))) * .55 + noise * .25) * exp(-pop * 30)
			var thud: float = t - landing
			if thud >= 0: sample += (sin(TAU * (54 if heavy else 112) * thud) * (.85 if heavy else .32) + soft_noise * .4) * exp(-thud * (15 if heavy else 29))
		else:
			match kind:
				"water": sample = (soft_noise * .6 + sin(TAU * (520 * t + sin(t * 51) * 1.5)) * .12) * sin(PI * t / duration)
				"hoe": sample = (soft_noise * .8 + sin(TAU * 94 * t) * .45) * exp(-t * 17)
				"pest": sample = noise * .25 * sin(PI * t / duration)
				_: sample = (soft_noise * .5 + sin(TAU * 240 * t) * .18) * exp(-t * 23)
		var edge: float = minf(1, t * 700) * minf(1, (duration - t) * 80)
		samples[frame] = sample * edge
	return samples

func paper() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(.42 * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 117993
	var soft: float = 0
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var noise: float = rng.randf_range(-1, 1)
		soft = lerpf(soft, noise, .25)
		var sweep: float = pow(sin(PI * t / .42), 2)
		var fold: float = exp(-absf(t - .12) * 50) + exp(-absf(t - .30) * 70) * .4
		samples[frame] = (noise - soft) * (.12 * sweep + .20 * fold) * minf(1, t * 200) * minf(1, (.42 - t) * 200)
	return samples
