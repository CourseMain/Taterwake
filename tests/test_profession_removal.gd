extends SceneTree
## Retired activities cannot return through saves, menus or world interactions.
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://profession_removal_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var farm = game.state
	farm.coins = 4321.0
	farm.storage.russet = 17
	farm.quest_progress.starter_combo = 5
	var saved: Dictionary = farm._save_data()
	check(not saved.has("builds"), "saves omit build progression")
	for plot in farm.plots:
		check(not plot.has("cultivated") and not plot.has("variety"), "no build traits on beds")
	farm.reset_game()
	farm.plots[0].merge({"tilled": true, "stage": 3, "crop": "russet", "watered": true, "elapsed": 10.0}, true)
	farm.interact_plot(0, "harvest")
	check(farm.storage.russet == 3, "ordinary first harvest has no build bonus")
	check(farm.affected_tiles(0, "hoe").size() == 1 and farm.crop_growth_speed("russet") == 1.0, "base tools and growth have no build bonus")
	for island in [1]:
		check(game.world.find_child("WashAndSortWorkshop", true, false) == null, "island %d has no workshop" % island)
		for target: Node in game.world.find_children("*", "CollisionObject3D", true, false):
			check(not str(target.get_meta("station", "")).begins_with("profession:") and target.get_meta("station", "") != "builds", "world targets belong to surviving stations")
	check(not farm.NpcRoster.PEOPLE.has("ada"), "Ada is retired from the roster")
	game.hud.show_panel("menu", farm)
	for button: Node in game.hud._body.find_children("*", "Button", true, false):
		check(button.get_meta("hud_action", "") != "builds" and not button.text.to_lower().contains("builds"), "menu has no Builds entry")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/segment5-menu.png")
	game.hud.close_panel()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	game._unhandled_input(key)
	check(not game.hud.is_panel_open(), "C no longer opens a build page")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("PROFESSION REMOVAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
