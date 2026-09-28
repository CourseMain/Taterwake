extends SceneTree

const State = preload("res://scripts/game_state.gd")
const SAVE := "user://gacha_removal_test_only.json"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

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
	legacy.mechanics_revision = 21
	legacy.tutorial_progress = {"version": 2, "step": 9, "plot": 4, "completed": true, "tour_only": true}
	legacy.npc_history.rook = {"visits": 4, "last": "Welcome.", "kind": false}
	for field in ["luck", "debug_luck_multiplier", "trophies", "roll_count", "last_roll", "last_roll_results", "last_roll_accounting", "pending_roll_boost", "boost_remaining", "boost_factor", "permanent_yield"]:
		legacy[field] = {"retired": true}
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(farm.load_game(SAVE), "revision 21 ignores retired fields before validation")
	check(farm.coins == 4321.0 and farm.storage.russet == 17 and farm.quest_progress.starter_combo == 5, "migration preserves money, crops and quest progress")
	check(farm.tutorial_progress.step == 7, "saved optional ferry tour remains on the ferry after the removed stop")
	check(not farm.npc_history.has("rook"), "retired resident history is dropped")
	check(farm.save_game(SAVE), "migrated farm saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved.mechanics_revision == 26, "save records mechanics revision 25")
	for field in ["luck", "debug_luck_multiplier", "trophies", "roll_count", "last_roll", "last_roll_results", "last_roll_accounting", "pending_roll_boost", "boost_remaining", "boost_factor", "permanent_yield"]:
		check(not saved.has(field), "new saves omit " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.storage.russet = -1
	check(not farm._valid_save(bad), "surviving farm data still validates strictly")
	for island in [1, 2, 3]:
		farm.debug_unlock_island(island)
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
		check(game.world.find_child("RollHouse", true, false) == null, "island %d has no Roll House" % island)
	check(not farm.NpcRoster.PEOPLE.has("rook"), "Rook is absent from roster")
	game.hud.show_panel("pause", farm)
	check(not game.hud._refs.has("roll"), "menu has no Roll House action")
	game.hud.close_panel()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	game._unhandled_input(key)
	check(not game.hud.is_panel_open(), "R no longer opens a panel")
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("GACHA REMOVAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
