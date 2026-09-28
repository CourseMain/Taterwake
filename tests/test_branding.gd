extends SceneTree
## The displayed title may change; the v4 farm uses its own save filename.
func _initialize() -> void:
	var checks: Array[bool] = [
		ProjectSettings.get_setting("application/config/name") == "Taterland",
		ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		ProjectSettings.get_setting("application/config/use_custom_user_dir"),
		ProjectSettings.get_setting("application/config/custom_user_dir_name") == "Godot/app_userdata/Spud Valley",
		ProjectSettings.get_setting("application/config/custom_user_dir_name.linux") == "godot/app_userdata/Spud Valley",
		load("res://scripts/game_state.gd").DEFAULT_SAVE_PATH == "user://taterland_save_v4.json"
	]
	if OS.get_name() in ["macOS", "Windows", "Linux"]:
		checks.append(OS.get_user_data_dir().replace("\\", "/").to_lower().ends_with("godot/app_userdata/spud valley"))
	var failures: int = checks.count(false)
	print("TATERLAND BRANDING: %d checks, %d failures" % [checks.size(), failures])
	quit(1 if failures > 0 else 0)
