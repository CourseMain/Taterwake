extends Node
var wind: AudioStreamPlayer
var thunder: AudioStreamPlayer
var strength: float = 0.0
var storm: bool = false
var clock: float = 0.0
func _ready() -> void:
	wind = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = preload("res://assets/audio/climate-wind.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	wind.stream = stream
	wind.volume_db = -60
	add_child(wind)
	thunder = AudioStreamPlayer.new()
	thunder.stream = preload("res://assets/audio/climate-thunder.wav")
	thunder.volume_db = -12
	add_child(thunder)
func _exit_tree() -> void:
	# Release active playback before the audio players leave the tree.
	for player in [wind, thunder]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
func set_weather(info: Dictionary, island: int, paused: bool) -> void:
	strength = 0.0 if paused or info.island != island or island < 2 else (float(info.severity) if info.phase == "active" else (float(info.severity) * 0.35 if info.phase in ["warning", "recovery"] else 0.0))
	storm = info.event == "storm" and info.phase == "active" and strength > 0.0
	if strength == 0.0:
		wind.stop()
		thunder.stop()
	elif not wind.playing: wind.play()
func impact() -> void:
	if strength > 0.0: thunder.play()
func _process(delta: float) -> void:
	wind.volume_db = lerpf(wind.volume_db, lerpf(-40.0, -20.0, strength), minf(1.0, delta * 3.0))
	clock += delta
	if clock >= 8.0:
		clock = 0.0
		if storm: thunder.play()
