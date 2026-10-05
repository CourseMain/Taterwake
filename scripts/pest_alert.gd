extends Node
## Three soft alerts, rotated, with one reminder at most every twenty seconds.
const Mix = preload("res://scripts/sound_mix.gd")
const REMINDER_SECONDS: float = 20.0
const GROUP_COOLDOWN: float = 20.0
const CUES: Array[AudioStreamWAV] = [preload("res://assets/audio/pest-cue-1.wav"), preload("res://assets/audio/pest-cue-2.wav"), preload("res://assets/audio/pest-cue-3.wav")]
var player: AudioStreamPlayer
var cooldown: float = 0.0
var reminder: float = 0.0
var infested_count: int = 0
var last_kind: String = ""
var last_cue: int = -1
var alerts_played: int = 0
func _ready() -> void:
	player = AudioStreamPlayer.new(); player.name = "PestWarningAudio"; player.volume_db = -14
	add_child(player)
func notify_attack(destroyed: bool = false) -> void:
	if cooldown > 0 or not Mix.allow_alert(): return
	last_kind = "lost" if destroyed else "attack"
	cooldown = GROUP_COOLDOWN; reminder = REMINDER_SECONDS
	last_cue = (last_cue + 1) % CUES.size(); alerts_played += 1
	player.stream = CUES[last_cue]; player.volume_db = -14 + Mix.gain()
	if DisplayServer.get_name() != "headless": player.play()
func update(delta: float, count: int) -> void:
	if not is_finite(delta) or delta < 0: return
	cooldown = maxf(0, cooldown - delta); infested_count = maxi(0, count)
	if infested_count == 0:
		reminder = 0; player.stop(); return
	reminder = maxf(0, reminder - delta)
	if reminder <= 0: notify_attack()
func _exit_tree() -> void:
	player.stop(); player.stream = null
