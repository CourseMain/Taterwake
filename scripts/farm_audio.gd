extends Node
## Small original foley clips, cached once and shared across island rebuilds.
const RATE: int = 22050
static var clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var last_kind: String = ""

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -14.0
		add_child(voice)
		voices.append(voice)

func play_action(kind: String) -> void:
	last_kind = kind
	if voices.is_empty(): return
	if not clips.has(kind): clips[kind] = bake(kind)
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = clips[kind]
	voice.play()

static func bake(kind: String) -> AudioStreamWAV:
	var harvest: bool = kind in ["harvest", "giant"]
	var heavy: bool = kind == "giant"
	var pull: float = .32 if heavy else .18
	var landing: float = pull + (.48 if heavy else .36)
	var duration: float = landing + .36 if harvest else .42
	var bytes := PackedByteArray()
	bytes.resize(int(duration * RATE) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9417
	var soft_noise: float = 0.0
	for frame in range(bytes.size() / 2):
		var t: float = float(frame) / RATE
		var noise: float = rng.randf_range(-1, 1)
		soft_noise = lerpf(soft_noise, noise, .18)
		var sample: float = 0
		if harvest:
			if t < pull:
				sample = (soft_noise * .65 + sin(TAU * (85 * t + 90 * t * t)) * .10) * sin(PI * t / pull)
			var pop: float = t - pull
			if pop >= 0:
				sample += (sin(TAU * (160 * pop + 4 * (1 - exp(-pop * 35)))) * .55 + noise * .25) * exp(-pop * 30)
			var thud: float = t - landing
			if thud >= 0:
				sample += (sin(TAU * (54 if heavy else 112) * thud) * (.85 if heavy else .32) + soft_noise * .4) * exp(-thud * (15 if heavy else 29))
		else:
			match kind:
				"water": sample = (soft_noise * .6 + sin(TAU * (520 * t + sin(t * 51) * 1.5)) * .12) * sin(PI * t / duration)
				"hoe": sample = (soft_noise * .8 + sin(TAU * 94 * t) * .45) * exp(-t * 17)
				"pest": sample = noise * .25 * sin(PI * t / duration)
				_: sample = (soft_noise * .5 + sin(TAU * 240 * t) * .18) * exp(-t * 23)
		var edge: float = minf(1, t * 700) * minf(1, (duration - t) * 80)
		bytes.encode_s16(frame * 2, int(clampf(sample * edge, -.95, .95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
