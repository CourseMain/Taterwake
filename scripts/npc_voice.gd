extends Node
## One soft chirp when a page opens, never during individual lines.
const Mix = preload("res://scripts/sound_mix.gd")
const CLIPS: Array[AudioStream] = [preload("res://assets/audio/keeper-chirp-1.wav"), preload("res://assets/audio/keeper-chirp-2.wav"), preload("res://assets/audio/keeper-chirp-3.wav")]
const PROFILES := {"mara": 1.12, "bram": .90, "nell": 1.04, "tess": 1.18, "pip": 1.30, "iris": 1.20, "edwin": 1.02}
var player: AudioStreamPlayer
var speaker: String = ""
var last_clip: int = -1
var utterances: int = 0
func _ready() -> void:
	player = AudioStreamPlayer.new(); player.volume_db = -24
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
func begin_page(id: String) -> void:
	stop(); speaker = id
	if not Mix.allow_charm(): return
	last_clip = (last_clip + 1) % CLIPS.size()
	player.stream = CLIPS[last_clip]; player.pitch_scale = PROFILES.get(id, 1.0)
	player.volume_db = -24 + Mix.gain(); utterances += 1
	if DisplayServer.get_name() != "headless": player.play()
func stop() -> void:
	if is_instance_valid(player): player.stop()
func _exit_tree() -> void:
	stop()
