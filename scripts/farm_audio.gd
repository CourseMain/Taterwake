extends Node
## Original, prebuilt PCM foley and cues: playback never synthesizes samples.
const Mix = preload("res://scripts/sound_mix.gd")
const CLIPS: Dictionary = {
	"quack": preload("res://assets/audio/duck-quack.wav"),
	"harvest_notes": preload("res://assets/audio/harvest-two-notes.wav"),
	"harvest": preload("res://assets/audio/farm-harvest.wav"),
	"giant": preload("res://assets/audio/farm-giant.wav"),
	"water": preload("res://assets/audio/farm-water.wav"),
	"hoe": preload("res://assets/audio/farm-hoe.wav"),
	"pest": preload("res://assets/audio/farm-pest.wav"),
	"plant": preload("res://assets/audio/farm-plant.wav"),
	"ice": preload("res://assets/audio/farm-ice.wav"),
	"paper": preload("res://assets/audio/ledger-paper.wav"),
	"foreclosure": preload("res://assets/audio/foreclosure-note.wav"),
}
const TONES: Array = [
	[130.81, .65, preload("res://assets/audio/foreclosure-note.wav")],
	[164.81, .60, preload("res://assets/audio/cue-impact.wav")],
	[220.0, .60, preload("res://assets/audio/cue-warning.wav")],
	[440.0, .10, preload("res://assets/audio/cue-tool.wav")],
	[740.0, .12, preload("res://assets/audio/cue-purchase.wav")],
	[523.25, .11, preload("res://assets/audio/cue-c.wav")],
	[659.25, .11, preload("res://assets/audio/cue-e.wav")],
	[783.99, .11, preload("res://assets/audio/cue-g.wav")],
	[1046.5, .11, preload("res://assets/audio/cue-high-c.wav")],
]
const REWARD: AudioStreamWAV = preload("res://assets/audio/cue-reward.wav")
const VOICE_COUNT: int = 4
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var last_kind: String = ""
var last_grade: String = ""
var last_cue: String = ""
var played_count: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	for index in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16.0
		add_child(voice)
		voices.append(voice)

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func play_action(kind: String) -> void:
	last_kind = kind
	if kind == "quack" and not Mix.allow_charm(): return
	_play(bake(kind), "action:" + kind)

func play_grade(grade: String) -> void:
	if grade not in ["Table", "Standard", "Feed"]: return
	last_grade = grade
	if Mix.allow_charm(): _play(CLIPS.harvest_notes, "grade:" + grade)

func play_paper() -> void:
	_play(CLIPS.paper, "paper")

func play_foreclosure() -> void:
	_play(CLIPS.foreclosure, "foreclosure")

func play_tone(frequency: float, duration: float, sparkle: bool = false) -> void:
	if not is_finite(frequency) or frequency <= 0 or not is_finite(duration) or duration <= 0: return
	if sparkle:
		_play(REWARD, "reward", frequency / 880.0)
		return
	# Every game cue has an exact authored clip. The nearest note also keeps
	# debug/test callers audible without introducing a runtime sample loop.
	var nearest: Array = TONES[0]
	var distance: float = INF
	for tone: Array in TONES:
		var difference: float = absf(log(frequency / float(tone[0]))) + absf(duration - float(tone[1]))
		if difference < distance:
			distance = difference
			nearest = tone
	_play(nearest[2], "tone", frequency / float(nearest[0]))

func _play(stream: AudioStreamWAV, cue: String, pitch: float = 1.0) -> void:
	var alert: bool = cue == "tone" and stream in [TONES[1][2], TONES[2][2]]
	if alert and not Mix.allow_alert(): return
	var tool: bool = cue.begins_with("grade:") or cue.begins_with("action:") and cue != "action:quack" or stream == TONES[3][2]
	if tool: Mix.tool_played()
	last_cue = cue
	played_count += 1
	if voices.is_empty(): return
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.volume_db = (-16.0 if tool else -24.0) + Mix.gain(tool)
	voice.stream = stream
	voice.pitch_scale = clampf(pitch, .25, 4.0)
	voice.play()

static func bake(kind: String) -> AudioStreamWAV:
	# Compatibility for callers that inspected the old cached foley. All
	# authored samples now live in assets and are loaded before gameplay.
	return CLIPS.get(kind, CLIPS.plant)
