extends SceneTree
## Three original short foley clips, authored once; no runtime synthesis.
const RATE: int = 44100
func _initialize() -> void:
	for id in ["bell", "roll", "stamp"]:
		var duration: float = {"bell":.65,"roll":.7,"stamp":.12}[id]
		var pcm := PackedByteArray(); pcm.resize(int(duration*RATE)*2)
		var rng := RandomNumberGenerator.new(); rng.seed = 2201
		for sample in range(pcm.size()/2):
			var t: float = float(sample)/RATE
			var value: float
			if id == "bell": value = (sin(TAU*880*t)+.35*sin(TAU*1764*t)+.16*sin(TAU*2657*t))*exp(-t*9)*minf(1,t*200)*.28
			elif id == "roll":
				var beat: float = fmod(t,.065)
				value = (rng.randf_range(-1,1)*.7+sin(TAU*145*t)*.3)*exp(-beat*90)*(.13+t*.15)*minf(1,(duration-t)*40)
			else: value = (sin(TAU*95*t)*.75+rng.randf_range(-1,1)*.25)*exp(-t*38)*minf(1,t*1000)*.65
			pcm.encode_s16(sample*2,int(clampf(value,-1,1)*32767))
		var clip := AudioStreamWAV.new(); clip.format = AudioStreamWAV.FORMAT_16_BITS; clip.mix_rate = RATE; clip.data = pcm
		clip.save_to_wav("res://assets/audio/pedlar-"+id+".wav")
	quit()
