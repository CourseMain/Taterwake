extends RefCounted
## Device-local presentation settings; independent of farm progress and debug.
const PATH: String = "user://taterland_graphics.cfg"
const MODES: Array[String] = ["balanced", "smooth", "crisp"]

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
	config.load(path)
	config.set_value("graphics", "quality", mode)
	return config.save(path)

static func load_shadow_size(phone: bool, path: String = PATH) -> int:
	var config := ConfigFile.new()
	config.load(path)
	var size = config.get_value("graphics", "shadows", 2048 if phone else 4096)
	return int(size) if size is int and size in [2048, 4096] else (2048 if phone else 4096)

static func save_shadow_size(size: int, path: String = PATH) -> Error:
	if size not in [2048, 4096]: return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("graphics", "shadows", size)
	return config.save(path)
