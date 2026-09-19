extends SceneTree
## Offline, deterministic original score. Runtime only loads the baked WAV.
const DURATION: float = 7.4
const IGNITION_AT: float = 2.05
const LIFTOFF_AT: float = 2.65
const SAMPLE_RATE: int = 22050
const COUNTDOWN: Array[float] = [739.989, 880.0, 1174.659]
const ARPEGGIO: Array[float] = [293.665, 369.994, 440.0, 587.330, 659.255, 739.989, 880.0, 1174.659]
const COINS: Array[float] = [1174.659, 1479.978, 1760.0, 2349.318, 1760.0, 1479.978]
const CHORD: Array[float] = [146.832, 293.665, 369.994, 440.0, 659.255]

func _initialize() -> void:
	var sound := _make_sound()
	var error: Error = sound.save_to_wav("res://assets/audio/stock-rocket-launch.wav")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(sound.data)
	print("Launch PCM SHA-256: " + hash.finish().hex_encode())
	quit(0 if error == OK else 1)

func _bell(age: float, frequency: float, decay: float) -> float:
	if age < 0.0:
		return 0.0
	var envelope: float = minf(1.0, age / 0.005) * exp(-age * decay)
	return (sin(age * TAU * frequency) + sin(age * TAU * frequency * 2.003) * 0.22 + sin(age * TAU * frequency * 3.01) * 0.06) * envelope

func _make_sound() -> AudioStreamWAV:
	# D-major bells, a rising engine, punchy bass, stereo coins and a warm payoff.
	# Echo taps are baked too: no DSP/PCM generation runs on the browser thread.
	var frames: int = int(DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 4)
	var history_left := PackedFloat32Array()
	var history_right := PackedFloat32Array()
	history_left.resize(frames)
	history_right.resize(frames)
	var short_delay: int = int(SAMPLE_RATE * 0.115)
	var long_delay: int = int(SAMPLE_RATE * 0.23)
	var rng := RandomNumberGenerator.new()
	rng.seed = 472015
	var low_noise: float = 0.0
	var rumble_noise: float = 0.0
	for frame: int in range(frames):
		var t: float = float(frame) / SAMPLE_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, white, 0.11)
		rumble_noise = lerpf(rumble_noise, white, 0.006)
		var center: float = 0.0
		var melody: float = 0.0
		var spread: float = 0.0
		var count: int = int(t / (IGNITION_AT / 3.0))
		var note_t: float = fposmod(t, IGNITION_AT / 3.0)
		if count < 3:
			melody += _bell(note_t, COUNTDOWN[count], 5.0) * 0.24
			# A short answering interval makes each countdown sound like a launch cue.
			melody += _bell(note_t - 0.105, COUNTDOWN[count] * 0.5, 9.0) * 0.09
			center += sin(note_t * TAU * 73.416) * exp(-note_t * 16.0) * minf(1.0, note_t * 200) * 0.10
		var ignition: float = smoothstep(1.65, LIFTOFF_AT, t) * (1.0 - smoothstep(4.15, 5.65, t))
		center += (low_noise * 0.82 + rumble_noise * 2.4 + sin(t * TAU * 36.708) * 0.12) * ignition
		if t > 1.1 and t < 3.1:
			var rise_t: float = t - 1.1
			var rise_phase: float = 100.0 / 1.35 * (exp(rise_t * 1.35) - 1.0)
			var rise_envelope: float = smoothstep(0.0, 1.5, rise_t) * (1.0 - smoothstep(2.7, 3.1, t))
			melody += sin(TAU * rise_phase) * rise_envelope * 0.115
			center += (white - low_noise) * rise_envelope * 0.035
		if t >= LIFTOFF_AT:
			var launch_t: float = t - LIFTOFF_AT
			center += sin(TAU * (44.0 * launch_t + 4.3 * (1.0 - exp(-launch_t * 16.0)))) * exp(-launch_t * 3.3) * 0.67
			center += low_noise * exp(-launch_t * 8.0) * 0.35
		if t >= 2.8 and t < 5.8:
			var groove: float = t - 2.8
			var beat: float = fposmod(groove, 0.25)
			var bass: float = 73.416 if int(groove / 0.5) % 2 == 0 else 110.0
			center += sin(TAU * bass * beat) * exp(-beat * 13.0) * minf(1.0, beat * 180.0) * 0.18
			center += (white - low_noise) * exp(-beat * 92.0) * minf(1.0, beat * 500.0) * 0.045
		if t > 3.05 and t < 5.95:
			var arp_t: float = t - 3.05
			var n: int = int(arp_t / 0.16)
			var frequency: float = ARPEGGIO[n % ARPEGGIO.size()] * (1.0 if n < 8 else 2.0)
			var local: float = fposmod(arp_t, 0.16)
			var envelope: float = minf(1.0, local / 0.007) * exp(-local * 15.0) * (1.0 - smoothstep(5.6, 5.95, t))
			var arp: float = (sin(local * TAU * frequency) + sin(local * TAU * frequency * 2.0) * 0.13) * envelope * 0.13
			melody += arp
			spread += arp * sin(n * 1.73) * 0.50
		if t > 3.25 and t < 6.3:
			var cascade_t: float = t - 3.25
			var cascade_phase: float = cascade_t * 6.0 + cascade_t * cascade_t * 1.25
			var coin_index: int = int(cascade_phase)
			var coin_age: float = fposmod(cascade_phase, 1.0) / (6.0 + cascade_t * 2.5)
			var coin: float = _bell(coin_age, COINS[coin_index % COINS.size()], 25.0) * 0.095 * (1.0 - smoothstep(5.95, 6.3, t))
			melody += coin
			spread += coin * (-0.70 if coin_index % 2 == 0 else 0.70)
		if t > 5.75:
			var chord_t: float = t - 5.75
			var envelope: float = minf(1.0, chord_t / 0.045) * exp(-chord_t * 1.25)
			for frequency: float in CHORD:
				melody += (sin(chord_t * TAU * frequency) + sin(chord_t * TAU * frequency * 2) * 0.10) * envelope * 0.08
			center += sin(TAU * 73.416 * chord_t) * exp(-chord_t * 3.0) * minf(1.0, chord_t * 100.0) * 0.20
			for hit: int in range(4):
				var chime: float = _bell(chord_t - hit * 0.12, ARPEGGIO[hit + 4], 4.1) * 0.12
				melody += chime
				spread += chime * (-0.42 if hit % 2 else 0.42)
			melody += _bell(chord_t - 0.52, 2349.318, 5.0) * 0.11
		var left: float = melody - spread
		var right: float = melody + spread
		history_left[frame] = left
		history_right[frame] = right
		if frame >= short_delay:
			left += history_right[frame - short_delay] * 0.22
			right += history_left[frame - short_delay] * 0.22
		if frame >= long_delay:
			left += history_left[frame - long_delay] * 0.10
			right += history_right[frame - long_delay] * 0.10
		var fade: float = minf(1.0, t / 0.02) * (1.0 - smoothstep(DURATION - 0.35, DURATION, t))
		for channel: int in range(2):
			var sample: float = center + (left if channel == 0 else right)
			sample = sample / (1.0 + absf(sample) * 0.72) * fade
			var pcm: int = int(clampf(sample, -0.98, 0.98) * 32767.0)
			data[frame * 4 + channel * 2] = pcm & 255
			data[frame * 4 + channel * 2 + 1] = (pcm >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = true
	sound.data = data
	return sound
