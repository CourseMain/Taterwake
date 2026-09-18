extends SceneTree
## The displayed title may change; the existing farm's storage location must not.
func _initialize() -> void:
	var checks: Array[bool] = [
		ProjectSettings.get_setting("application/config/name") == "Taterwake",
		ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		ProjectSettings.get_setting("application/config/use_custom_user_dir"),
		ProjectSettings.get_setting("application/config/custom_user_dir_name") == "Godot/app_userdata/Spud Valley",
		ProjectSettings.get_setting("application/config/custom_user_dir_name.linux") == "godot/app_userdata/Spud Valley",
		load("res://scripts/game_state.gd").DEFAULT_SAVE_PATH == "user://spud_valley_save_v3.json"
	]
	if OS.get_name() in ["macOS", "Windows", "Linux"]:
		checks.append(OS.get_user_data_dir().replace("\\", "/").to_lower().ends_with("godot/app_userdata/spud valley"))
	var failures: int = checks.count(false)
	print("TATERWAKE BRANDING: %d checks, %d failures" % [checks.size(), failures])
	quit(1 if failures > 0 else 0)
