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
	var legacy: Dictionary = farm._save_data().duplicate(true)
	legacy.mechanics_revision = 24
	legacy.builds = {"active": "scientist", "xp": {"farmer": 999}, "processed": {"russet": {"count": 100}}, "professions": {"compost": 99}}
	legacy.npc_history.ada = {"visits": 4, "last": "Welcome.", "kind": false}
	legacy.farm_help.dismissed.append("builds")
	legacy.tutorial_progress = {"version": 2, "step": 6, "plot": 4, "completed": true, "tour_only": true}
	for field: Array in legacy.island_plots.values():
		field[0].cultivated = true
		field[0].variety = "hearty"
	write_save(legacy)
	check(farm.load_game(SAVE), "revision 24 farm loads after build removal")
	check(farm.coins == 4321.0 and farm.storage.russet == 17 and farm.quest_progress.starter_combo == 5, "ordinary balance, crops and quests survive")
	check(farm.tutorial_progress.step == 5 and game.tutorial.TOUR[5].id == "quests", "optional quest tour retains its place")
	check(not farm.npc_history.has("ada") and not "builds" in farm.farm_help.data.dismissed, "retired resident and tip memory are dropped")
	for field: Array in farm.island_plots.values():
		check(not field[0].has("cultivated") and not field[0].has("variety"), "bed traits removed on every island")
	check(farm.save_game(SAVE), "migrated farm saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved.mechanics_revision == 25 and not saved.has("builds"), "new saves omit all build inventory and progression")
	check(farm.load_game(SAVE) and farm.tutorial_progress.step == 5, "current saves do not shift the tour twice")
	legacy.builds = "invalid retired data"
	legacy.tutorial_progress.step = 5
	write_save(legacy)
	check(farm.load_game(SAVE) and farm.tutorial_progress.step == 5, "removed tour stop advances to quests; retired block needs no validator")
	legacy.storage.russet = -1
	check(not farm._valid_save(legacy), "surviving inventory still validates strictly")
	farm.reset_game()
	farm.plots[0].merge({"tilled": true, "stage": 3, "crop": "russet", "watered": true, "elapsed": 10.0}, true)
	farm.interact_plot(0, "harvest")
	check(farm.storage.russet == 3, "ordinary first harvest has no build bonus")
	check(farm.affected_tiles(0, "hoe").size() == 1 and farm.crop_growth_speed(1, "russet") == 1.0, "base tools and growth have no build bonus")
	for island: int in [1, 2, 3]:
		farm.debug_unlock_island(island)
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
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
