extends SceneTree
## Offline authoring only. Runtime playback uses these original PCM files.
## Run: godot --headless --path . --script res://tools/bake_farm_audio.gd
const RATE: int = 22050
const LOOP_SECONDS: float = 8.0

func _initialize() -> void:
	for kind in ["harvest", "giant", "water", "hoe", "pest", "plant", "ice"]:
		write("farm-" + kind, foley(kind))
	for season in range(4): write("season-" + ["birds", "cicadas", "wind", "snow"][season], ambience(season))
	for grade in ["table", "standard", "feed"]: write("grade-" + grade, grade_stamp(grade))
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

func ambience(season: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(LOOP_SECONDS * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 72161 + season
	var breeze: float = 0
	var muffled: float = 0
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var noise: float = rng.randf_range(-1, 1)
		breeze = lerpf(breeze, noise, .025)
		muffled = lerpf(muffled, noise, .003)
		var sample: float = 0
		match season:
			0:
				sample = breeze * .20
				for call in [[.7, .38, 1900.0], [1.35, .28, 2400.0], [3.8, .52, 1700.0], [6.1, .36, 2100.0], [6.6, .24, 2600.0]]:
					var age: float = t - float(call[0])
					if age < 0 or age >= float(call[1]): continue
					var envelope: float = pow(sin(PI * age / float(call[1])), 2)
					var trill: float = .65 + .35 * sin(age * TAU * 19)
					sample += sin(TAU * (float(call[2]) * age + 380 * age * age + .35 * sin(age * TAU * 10))) * envelope * trill * .20
			1:
				var chorus: float = .4 + .3 * sin(TAU * t / 4) + .15 * sin(TAU * t / 2)
				var trill: float = .55 + .45 * pow(sin(TAU * 36 * t), 2)
				sample = (sin(TAU * 3100 * t) * .12 + sin(TAU * 3420 * t + sin(TAU * .5 * t)) * .08 + noise * .025) * chorus * trill + breeze * .15
			2:
				var gust: float = .6 + .25 * sin(TAU * t / 8) + .1 * sin(TAU * t / 2)
				sample = breeze * gust * 1.5 + muffled * .65
			3:
				var hush: float = .7 + .2 * sin(TAU * t / 4)
				sample = muffled * hush * 2.4 + breeze * .12
				for at in [1.2, 4.5, 6.4]:
					var age: float = t - at
					if age >= 0 and age < .18: sample += breeze * .15 * sin(PI * age / .18)
		# An inaudible-edge fade removes the discontinuity in the random beds.
		var edge: float = minf(1, t / .03) * minf(1, (LOOP_SECONDS - t - 1.0 / RATE) / .03)
		samples[frame] = sample * maxf(0, edge)
	return samples

func note(frequency: float, duration: float, sparkle: bool = false, low: bool = false) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(duration * RATE))
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var envelope: float = minf(1, t * 80) * pow(maxf(0, 1 - t / duration), 1.5)
		var harmonic: float = sin(TAU * frequency * t) + (.4 * sin(TAU * frequency * 1.5 * t) if sparkle else 0)
		if low: harmonic = .6 * sin(TAU * frequency * .5 * t) + .25 * sin(TAU * frequency * t)
		samples[frame] = harmonic * envelope * .4
	return samples

func grade_stamp(grade: String) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(.38 * RATE))
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var stamp: float = sin(TAU * 145 * t) * exp(-t * 55) * .28
		var frequency: float = {"table": 659.25, "standard": 392.0, "feed": 196.0}[grade]
		var envelope: float = minf(1, t * 200) * exp(-t * (13 if grade == "feed" else 9)) * minf(1, (.38 - t) * 70)
		var pitch: float = frequency * t - (60 * t * t if grade == "feed" else 0)
		var ring: float = sin(TAU * pitch) * .26
		if grade == "table" and t >= .09:
			var second: float = t - .09
			ring += sin(TAU * 783.99 * second) * exp(-second * 9) * minf(1, second * 200) * .18
		samples[frame] = stamp + ring * envelope
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
