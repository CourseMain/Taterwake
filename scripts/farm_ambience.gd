extends Node
## Four short original loops; weather remains on ClimateAudio's own channel.
const FADE_SECONDS: float = 1.0
const VOLUME_DB: float = -20.0
const STREAMS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/season-birds.wav"),
	preload("res://assets/audio/season-cicadas.wav"),
	preload("res://assets/audio/season-wind.wav"),
	preload("res://assets/audio/season-snow.wav"),
]
var players: Array[AudioStreamPlayer] = []
var gains: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _from: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _target: Array[float] = [0.0, 0.0, 0.0, 0.0]
var elapsed: float = FADE_SECONDS
var season: int = -1
var paused: bool = true

func _ready() -> void:
	for original in STREAMS:
		var player := AudioStreamPlayer.new()
		var loop: AudioStreamWAV = original.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		player.stream = loop
		player.volume_db = -60
		add_child(player)
		players.append(player)

func set_season(index: int, silence: bool = false) -> void:
	index = clampi(index, 0, 3)
	if index == season and silence == paused: return
	season = index
	paused = silence
	_from.assign(gains)
	elapsed = 0
	for current in range(4):
		_target[current] = 1.0 if current == index and not silence else 0.0
		if _target[current] > 0 and not players[current].playing and DisplayServer.get_name() != "headless": players[current].play()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if elapsed >= FADE_SECONDS: return
	elapsed = minf(FADE_SECONDS, elapsed + maxf(0, delta))
	var progress: float = elapsed / FADE_SECONDS
	for index in range(4):
		gains[index] = lerpf(_from[index], _target[index], progress)
		players[index].volume_db = VOLUME_DB + linear_to_db(maxf(.001, gains[index]))
		if progress == 1 and _target[index] == 0: players[index].stop()

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
