extends SceneTree
## Original nature and keeper cues, authored offline. No runtime synthesis.
const RATE: int = 22050
const BED_SECONDS: float = 48.0
func _initialize() -> void:
	for kind in ["breeze", "leaves", "stream", "rain", "hush"]: write("nature-" + kind, bed(kind))
	write("climate-wind", bed("breeze"))
	for index in range(6): write("bird-call-%d" % (index + 1), chirp(index, true))
	for index in range(3):
		write("keeper-chirp-%d" % (index + 1), chirp(index, false))
		write("pest-cue-%d" % (index + 1), chirp(index + 3, false))
	write("nature-cicadas", insect())
	write("duck-quack", quack())
	write("harvest-two-notes", chirp(0, false))
	quit()

func write(label: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for index in range(samples.size()): bytes.encode_s16(index * 2, roundi(clampf(samples[index], -.9, .9) * 32767))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE; stream.data = bytes
	if stream.save_to_wav("res://assets/audio/" + label + ".wav") != OK: quit(1); return
	print(label + ": " + str(stream.get_length()) + " s")

func bed(kind: String) -> PackedFloat32Array:
	var samples := PackedFloat32Array(); samples.resize(roundi(BED_SECONDS * RATE))
	var rng := RandomNumberGenerator.new(); rng.seed = 8013 + kind.hash()
	var low: float = 0; var leaves: float = 0
	var gaps: Array[Vector2] = []
	var at: float = rng.randf_range(3, 7)
	while at < BED_SECONDS:
		gaps.append(Vector2(at, rng.randf_range(1.0, 3.5))); at += rng.randf_range(6, 13)
	for index in range(samples.size()):
		var t: float = float(index) / RATE; var noise: float = rng.randf_range(-1, 1)
		low = lerpf(low, noise, .006); leaves = lerpf(leaves, noise, .13)
		var flow: float = .65 + .15 * sin(t * .27) + .10 * sin(t * .83)
		var gap: float = 1.0
		for pause in gaps:
			if t > pause.x and t < pause.x + pause.y: gap *= .15 + .85 * pow(cos((t - pause.x) / pause.y * PI), 2)
		var sample: float = low * 1.2 * flow
		match kind:
			"leaves": sample = leaves * .24 * flow + low * .25
			"stream": sample = leaves * .33 + sin(t * TAU * 470 + sin(t * 19)) * .015 + low * .6
			"rain": sample = noise * .095 + leaves * .28 + low * .3
			"hush": sample = low * .55 + leaves * .015
		var edge: float = minf(1, t / 2) * minf(1, (BED_SECONDS - t) / 2)
		samples[index] = sample * gap * edge
	return samples

func chirp(index: int, bird: bool) -> PackedFloat32Array:
	var duration: float = .9 + .06 * index if bird else .42
	var samples := PackedFloat32Array(); samples.resize(roundi(duration * RATE))
	var notes: int = 2 + index % 2
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE; var slot: float = duration / notes
		var step: int = mini(notes - 1, int(t / slot)); var age: float = fmod(t, slot)
		var sounding: float = slot * .75
		if age >= sounding: continue
		var frequency: float = (1500 + index * 167) if bird else (660 + index * 37)
		frequency *= [1.0, 1.25, 1.12][step]
		var sweep: float = 420 * age * age + .18 * sin(age * 50 + index) if bird else 70 * age * age
		var envelope: float = pow(sin(PI * age / sounding), 2)
		samples[frame] = (sin(TAU * (frequency * age + sweep)) + .12 * sin(TAU * frequency * age * 2)) * envelope * .32
	return samples

func insect() -> PackedFloat32Array:
	var samples := PackedFloat32Array(); samples.resize(RATE * 3)
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		samples[frame] = (sin(t * TAU * 3100) + .4 * sin(t * TAU * 3470)) * (.5 + .5 * sin(t * 77)) * pow(sin(t / 3 * PI), 2) * .12
	return samples

func quack() -> PackedFloat32Array:
	var samples := PackedFloat32Array(); samples.resize(roundi(RATE * .22))
	for frame in range(samples.size()):
		var t: float = float(frame) / RATE
		var pitch: float = 220 * t - 120 * t * t
		samples[frame] = (sin(TAU * pitch) + .6 * sin(TAU * pitch * 3) + .2 * sin(TAU * pitch * 5)) * pow(sin(t / .22 * PI), 2) * .2
	return samples
