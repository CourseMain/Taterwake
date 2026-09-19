extends RefCounted
## Device-local presentation settings; independent of farm progress and debug.
const PATH: String = "user://taterland_graphics.cfg"
const MODES: Array[String] = ["balanced", "smooth"]

static func load_mode(path: String = PATH) -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return "balanced"
	var mode = config.get_value("graphics", "quality", "balanced")
	return mode if mode is String and mode in MODES else "balanced"

static func save_mode(mode: String, path: String = PATH) -> Error:
	if mode not in MODES:
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", mode)
	return config.save(path)
