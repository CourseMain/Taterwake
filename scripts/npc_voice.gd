extends Node
## Cosmetic chatter uses its own RNG, so talking never changes farm outcomes.
const CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/npc-potato-1.wav"),
	preload("res://assets/audio/npc-potato-2.wav"),
	preload("res://assets/audio/npc-potato-3.wav"),
]
# Pitch and pause length give the villagers recognisable speaking rhythms.
const PROFILES: Dictionary = {
	"mara": Vector2(1.12, .28), "bram": Vector2(.90, .42),
	"nell": Vector2(1.04, .38), "tess": Vector2(1.18, .24),
	"pip": Vector2(1.30, .20),
	"hollis": Vector2(.94, .45),
	"iris": Vector2(1.20, .35), "oren": Vector2(.86, .46),
	"edwin": Vector2(1.02, .40),
}
var player: AudioStreamPlayer
var speaker: String = ""
var last_clip: int = -1
var utterances: int = 0
var _remaining: int = 0
var _wait: float = 0.0
var _concerned: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	player = AudioStreamPlayer.new()
	player.volume_db = -12.0
	# Use the same mixer in native and web builds; stopping a line is immediate.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	set_process(false)

func begin_line(id: String, characters: int, concerned: bool = false) -> void:
	stop()
	speaker = id
	_concerned = concerned
	_remaining = clampi(ceili(float(characters) / 65.0), 1, 3)
	_utter()
	set_process(_remaining > 0)

func _utter() -> void:
	# Never play the same take twice consecutively, including across pages.
	var take: int = _rng.randi_range(0, CLIPS.size() - 2)
	if take >= last_clip: take += 1
	if last_clip < 0: take = _rng.randi_range(0, CLIPS.size() - 1)
	last_clip = take
	var profile: Vector2 = PROFILES.get(speaker, Vector2(1.0, .32))
	player.stop()
	player.stream = CLIPS[take]
	player.pitch_scale = profile.x * _rng.randf_range(.96, 1.04) * (.96 if _concerned else 1.0)
	player.play()
	_remaining -= 1
	utterances += 1
	_wait = player.stream.get_length() / player.pitch_scale + profile.y + _rng.randf_range(.04, .16)

func _process(delta: float) -> void:
	if _remaining <= 0: return
	_wait -= minf(delta, .25)
	if _wait <= 0:
		_utter()
		if _remaining == 0: set_process(false)

func stop() -> void:
	_remaining = 0
	_wait = 0.0
	set_process(false)
	if is_instance_valid(player): player.stop()

func _exit_tree() -> void:
	stop()
