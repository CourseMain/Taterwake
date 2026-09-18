extends Node
## A dedicated warning channel: tool clicks and reward sounds cannot replace it.
const SAMPLE_RATE: int = 22050
const REMINDER_SECONDS: float = 6.0
const GROUP_COOLDOWN: float = 2.0
var player: AudioStreamPlayer
var attack_sound: AudioStreamWAV
var lost_sound: AudioStreamWAV
var cooldown: float = 0.0
var reminder: float = 0.0
var infested_count: int = 0
var last_kind: String = ""
var alerts_played: int = 0

func _ready() -> void:
	attack_sound = _make_sound(false)
	lost_sound = _make_sound(true)
	player = AudioStreamPlayer.new()
	player.name = "PestWarningAudio"
	player.volume_db = -7.0
	add_child(player)

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null

func notify_attack(destroyed: bool = false) -> void:
	# Group simultaneous beds into one alert. Crop loss may interrupt a warning,
	# but multiple losses in the same batch must not restart the sound repeatedly.
	if cooldown > 0.0 and (not destroyed or last_kind == "lost"):
		return
	last_kind = "lost" if destroyed else "attack"
	cooldown = GROUP_COOLDOWN
	reminder = REMINDER_SECONDS
	alerts_played += 1
	if is_instance_valid(player):
		player.stream = lost_sound if destroyed else attack_sound
		player.play()

func update(delta: float, count: int) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	infested_count = maxi(0, count)
	if infested_count == 0:
		reminder = 0.0
		if last_kind == "attack" and is_instance_valid(player):
			player.stop()
		return
	reminder = maxf(0.0, reminder - delta)
	if reminder <= 0.0:
		notify_attack()

func _make_sound(destroyed: bool) -> AudioStreamWAV:
	var seconds: float = 1.08 if destroyed else 0.86
	var frames: int = int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase: float = 0.0
	for frame in range(frames):
		var time: float = float(frame) / SAMPLE_RATE
		var beat: float = 0.24 if destroyed else 0.25
		var note: int = int(time / beat)
		var within: float = fmod(time, beat)
		var sounding: bool = within < 0.17 and note < (4 if destroyed else 3)
		var sample: float = 0.0
		if sounding:
			var frequency: float = [660.0, 494.0, 330.0, 220.0][mini(note, 3)] if destroyed else [880.0, 1174.66, 1396.91][mini(note, 2)]
			var envelope: float = minf(1.0, within / 0.012) * minf(1.0, (0.17 - within) / 0.04)
			phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
			# A bell-like warning with a quiet insect buzz under the rising chirps.
			sample = (sin(phase * TAU) + 0.2 * sin(phase * TAU * 2.0)) * envelope * 0.46
			if not destroyed:
				sample += sin(time * TAU * 155.0) * (0.5 + 0.5 * sin(time * TAU * 37.0)) * envelope * 0.07
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[frame * 2] = pcm & 255
		data[frame * 2 + 1] = (pcm >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = false
	sound.data = data
	return sound
