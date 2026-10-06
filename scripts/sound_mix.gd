extends RefCounted
## Cosmetic mixer state. It never reads or advances the farm RNG.
const MUTED_DB: float = -80.0
static var clock: float = 0.0
static var last_alert: float = -100.0
static var last_sound: float = -100.0
static var quieter: bool = false:
	set(value):
		quieter = value
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)

static func advance(delta: float) -> void:
	clock += maxf(0, delta)

static func gain(_tool: bool = false) -> float:
	return MUTED_DB if quieter else 0.0

static func allow_alert() -> bool:
	if clock - last_alert < 2.0: return false
	last_alert = clock
	last_sound = clock
	return true

static func allow_charm() -> bool:
	if clock - last_sound < 2.0: return false
	last_sound = clock
	return true

static func tool_played() -> void:
	last_sound = clock

static func load_preference(path: String = "user://taterland_sound.cfg") -> void:
	var config := ConfigFile.new()
	config.load(path)
	quieter = config.get_value("sound", "quieter", false) == true

static func save_preference(path: String = "user://taterland_sound.cfg") -> Error:
	var config := ConfigFile.new()
	config.set_value("sound", "quieter", quieter)
	return config.save(path)
