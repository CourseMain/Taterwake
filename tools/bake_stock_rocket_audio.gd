extends SceneTree
## Offline baker for the original launch score. Run headless once, then import.
## Runtime loads the resulting PCM asset without synthesizing 163,170 frames.
const DURATION: float = 7.4
const IGNITION_AT: float = 2.05
const LIFTOFF_AT: float = 2.65
const SAMPLE_RATE: int = 22050

func _initialize() -> void:
	var sound := _make_sound()
	var error: Error = sound.save_to_wav("res://assets/audio/stock-rocket-launch.wav")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(sound.data)
	print("Launch PCM SHA-256: " + hash.finish().hex_encode())
	quit(0 if error == OK else 1)

func _make_sound() -> AudioStreamWAV:
	# Original PCM score: three bells, a filtered ignition roar and bass impact,
	# a rising five-note arpeggio, then a warm major-nine arrival chord.
	var frames: int = int(DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 472019
	var low_noise: float = 0.0
	var rumble_noise: float = 0.0
	for frame in range(frames):
		var t: float = float(frame) / SAMPLE_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, white, 0.12)
		rumble_noise = lerpf(rumble_noise, white, 0.007)
		var sample: float = 0.0
		var count: int = int(t / (IGNITION_AT / 3.0))
		var note_t: float = fposmod(t, IGNITION_AT / 3.0)
		if count < 3:
			var note: float = [622.254, 783.991, 932.328][count]
			var envelope: float = minf(1.0, note_t / 0.012) * exp(-note_t * 6.0)
			sample += (sin(t * TAU * note) + sin(t * TAU * note * 2.003) * 0.18) * envelope * 0.20
		var ignite: float = smoothstep(IGNITION_AT - 0.3, LIFTOFF_AT, t) * (1.0 - smoothstep(4.8, 6.1, t))
		sample += (low_noise * 1.10 + rumble_noise * 2.8 + sin(t * TAU * 43.0) * 0.13) * ignite
		if t >= LIFTOFF_AT:
			var launch_t: float = t - LIFTOFF_AT
			sample += sin(TAU * (39.0 * launch_t + 2.7 * (1.0 - exp(-launch_t * 14.0)))) * exp(-launch_t * 3.2) * 0.44
		if t > 3.12 and t < 5.9:
			var arp_t: float = t - 3.12
			var n: int = int(arp_t / 0.22)
			var frequency: float = [311.127, 391.995, 466.164, 622.254, 783.991, 932.328, 1244.508][n % 7]
			var local: float = fposmod(arp_t, 0.22)
			var envelope: float = minf(1.0, local / 0.01) * exp(-local * 11.0) * (1.0 - smoothstep(5.4, 5.9, t))
			sample += (sin(t * TAU * frequency) + sin(t * TAU * frequency * 2.0) * 0.14) * envelope * 0.095
		if t > 5.8:
			var chord_t: float = t - 5.8
			var envelope: float = minf(1.0, chord_t / 0.06) * exp(-chord_t * 1.4)
			for frequency: float in [155.563, 311.127, 391.995, 466.164, 698.456]:
				sample += sin(t * TAU * frequency) * envelope * 0.075
		var fade: float = minf(1.0, t / 0.02) * (1.0 - smoothstep(DURATION - 0.35, DURATION, t))
		sample = sample / (1.0 + absf(sample)) * fade
		var stereo: float = sin(t * 1.8) * 0.10
		for channel in range(2):
			var pcm: int = int(clampf(sample * (1.0 + stereo * (-1.0 if channel == 0 else 1.0)), -0.98, 0.98) * 32767.0)
			data[frame * 4 + channel * 2] = pcm & 255
			data[frame * 4 + channel * 2 + 1] = (pcm >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = true
	sound.data = data
	return sound
