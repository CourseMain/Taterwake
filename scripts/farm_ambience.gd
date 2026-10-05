extends Node
## Two long nature layers and spaced, varied calls. Cosmetic RNG only.
const Mix = preload("res://scripts/sound_mix.gd")
const FADE_SECONDS: float = 6.0
const VOLUME_DB: float = -24.0
const STREAMS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/nature-breeze.wav"), preload("res://assets/audio/nature-leaves.wav"),
	preload("res://assets/audio/nature-stream.wav"), preload("res://assets/audio/nature-rain.wav"),
	preload("res://assets/audio/nature-hush.wav"),
]
const CALLS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/bird-call-1.wav"), preload("res://assets/audio/bird-call-2.wav"),
	preload("res://assets/audio/bird-call-3.wav"), preload("res://assets/audio/bird-call-4.wav"),
	preload("res://assets/audio/bird-call-5.wav"), preload("res://assets/audio/bird-call-6.wav"),
]
var players: Array[AudioStreamPlayer] = []
var tails: Array[AudioStreamPlayer] = []
var layer_age: Array[float] = [6.0, 6.0]
var gains: Array[float] = [0.0, 0.0]
var _from: Array[float] = [0.0, 0.0]
var _target: Array[float] = [0.0, 0.0]
var elapsed: float = FADE_SECONDS
var season: int = -1
var paused: bool = true
var wet: bool = false
var near_pond: bool = false
var call_player: AudioStreamPlayer
var call_wait: float = 25.0
var last_call: int = -1
var calls_played: int = 0
var _rng := RandomNumberGenerator.new()
var _bed_indices: Array[int] = [-1, -1]
var _bed_wait: Array[float] = [0, 0]
var _clock: float = 0.0

func _ready() -> void:
	_rng.randomize()
	call_wait = _rng.randf_range(20, 40)
	for index in range(2):
		var player := AudioStreamPlayer.new(); player.volume_db = -60
		add_child(player); players.append(player)
		var tail := AudioStreamPlayer.new(); tail.volume_db = -60
		add_child(tail); tails.append(tail)
	call_player = AudioStreamPlayer.new(); call_player.volume_db = -30
	add_child(call_player)

func set_environment(info: Dictionary, pond: bool) -> void:
	wet = info.event in ["flood", "storm"] and info.phase in ["warning", "active", "recovery"]
	near_pond = pond

func set_season(index: int, silence: bool = false) -> void:
	index = clampi(index, 0, 3)
	if index != season or silence != paused:
		season = index; paused = silence; _from.assign(gains); elapsed = 0
		_target.assign([0.0, 0.0] if silence else [1.0, 1.0])

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	_clock += delta
	elapsed = minf(FADE_SECONDS, elapsed + delta)
	for index in range(2):
		gains[index] = lerpf(_from[index], _target[index], smoothstep(0, 1, elapsed / FADE_SECONDS))
		_bed_wait[index] -= delta
		var kind: int = (4 if season == 3 else 0) if index == 0 else (4 if season == 3 else (3 if wet else (2 if near_pond else 1)))
		if _bed_indices[index] != kind or _bed_wait[index] <= 0:
			# Two logical layers each overlap their outgoing and incoming bed.
			# The authored 48-second beds leave six seconds for this crossfade.
			tails[index].stop()
			tails[index].stream = players[index].stream
			if players[index].playing and not paused and DisplayServer.get_name() != "headless":
				tails[index].play(players[index].get_playback_position())
			players[index].stop()
			_bed_indices[index] = kind
			var offset: float = _rng.randf_range(0, 2)
			_bed_wait[index] = STREAMS[kind].get_length() - offset - FADE_SECONDS
			players[index].stream = STREAMS[kind]
			layer_age[index] = 0.0
			if not paused and DisplayServer.get_name() != "headless": players[index].play(offset)
		layer_age[index] = minf(FADE_SECONDS, layer_age[index] + delta)
		var blend: float = smoothstep(0, 1, layer_age[index] / FADE_SECONDS)
		var sway: float = .85 + .15 * sin(_clock * .11 + index * PI)
		var gain: float = gains[index] * sway
		players[index].volume_db = VOLUME_DB - 6.0206 + linear_to_db(maxf(.001, gain * blend)) + Mix.gain()
		tails[index].volume_db = VOLUME_DB - 6.0206 + linear_to_db(maxf(.001, gain * (1 - blend))) + Mix.gain()
		if layer_age[index] == FADE_SECONDS: tails[index].stop()
		if elapsed == FADE_SECONDS and paused:
			players[index].stop(); tails[index].stop()
		elif not paused and not players[index].playing and DisplayServer.get_name() != "headless": players[index].play()
	if paused: call_player.stop(); return
	call_wait -= delta
	if call_wait <= 0:
		call_wait = _rng.randf_range(20, 40)
		if season == 3: return
		if season == 1 and calls_played % 3 == 2:
			call_player.stream = preload("res://assets/audio/nature-cicadas.wav")
		else:
			var choice: int = _rng.randi_range(0, CALLS.size() - 2)
			if choice >= last_call: choice += 1
			last_call = choice; call_player.stream = CALLS[choice]
		call_player.pitch_scale = _rng.randf_range(.94, 1.06)
		call_player.volume_db = -30 + Mix.gain()
		calls_played += 1
		if DisplayServer.get_name() != "headless": call_player.play()

func _exit_tree() -> void:
	for player in players + tails + [call_player]:
		player.stop(); player.stream = null
