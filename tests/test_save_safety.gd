extends SceneTree
## Disposable paths only: never read or write a player's farm.
const State = preload("res://scripts/game_state.gd")
const SAVE: String = "user://taterland_save_safety_test_only.json"
var checks: int = 0
var failures: int = 0
var notice: String = ""

class BlockedMove extends "res://scripts/game_state.gd":
	var move_attempted: bool = false
	func _move_save(_source: String, _destination: String) -> bool:
		move_attempted = true
		return false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func write_file(path: String, payload: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "fixture file opens")
	if file == null: return
	file.store_string(payload)
	file.close()

func clean(state) -> void:
	for path in [SAVE, SAVE + ".tmp", state.backup_path(SAVE), state.rejected_path(SAVE)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run() -> void:
	var state = State.new()
	root.add_child(state)
	state.notified.connect(func(message: String): notice = message)
	clean(state)
	check(state.backup_path() == State.DEFAULT_SAVE_PATH + ".bak", "default backup path")
	check(state.rejected_path() == State.DEFAULT_SAVE_PATH + ".rejected", "default rejected path")
	var original_coins: float = state.coins
	var damaged: String = "{broken JSON"
	write_file(SAVE, damaged)
	check(not state.load_game(SAVE), "damaged JSON is refused")
	check(not FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(state.rejected_path(SAVE)) == damaged, "damaged JSON is moved intact to rejected")
	check("set aside" in notice and state.coins == original_coins, "notice explains preservation and live farm is unchanged")
	var invalid: String = JSON.stringify({"schema_version": State.SAVE_VERSION, "coins": 123})
	write_file(SAVE, invalid)
	check(not state.load_game(SAVE), "parseable invalid save is refused")
	check(not FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(state.rejected_path(SAVE)) == invalid, "latest rejected save replaces older rejected file")
	state.reset_game()
	check(state.save_game(SAVE), "fresh farm saves after a rejected load")
	check(FileAccess.get_file_as_string(state.rejected_path(SAVE)) == invalid, "fresh save leaves rejected evidence intact")
	check(not FileAccess.file_exists(state.backup_path(SAVE)), "first save has no previous farm to back up")
	var first: String = FileAccess.get_file_as_string(SAVE)
	state.coins += 100
	check(state.save_game(SAVE), "second save succeeds")
	check(FileAccess.get_file_as_string(state.backup_path(SAVE)) == first, "backup equals first save byte for byte")
	var second: String = FileAccess.get_file_as_string(SAVE)
	state.coins += 100
	check(state.save_game(SAVE), "third save succeeds")
	check(FileAccess.get_file_as_string(state.backup_path(SAVE)) == second, "one rolling backup replaces the older backup")
	var restored = State.new()
	root.add_child(restored)
	check(restored.load_game(state.backup_path(SAVE)), "backup is loadable")
	check(restored.coins == original_coins + 100, "backup restores previous farm balance")
	check(FileAccess.get_file_as_string(state.rejected_path(SAVE)) == invalid, "save rotation and backup loading preserve rejected file")
	var oversized: String = " ".repeat(2000001)
	write_file(SAVE, oversized)
	check(not state.load_game(SAVE), "oversized save is refused")
	check(not FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(state.rejected_path(SAVE)) == oversized, "oversized file is set aside intact")
	check(FileAccess.get_file_as_string(state.backup_path(SAVE)) == second, "rejection leaves backup intact")
	# Inject an I/O failure without relying on platform-specific permissions.
	var blocked = BlockedMove.new()
	root.add_child(blocked)
	write_file(SAVE, first)
	check(not blocked.save_game(SAVE) and blocked.move_attempted, "backup failure aborts saving")
	check(FileAccess.get_file_as_string(SAVE) == first, "backup failure preserves the previous farm")
	blocked.move_attempted = false
	# The spy prevents all file moves; this never opens a player's legacy save.
	blocked._reject_save(State.LEGACY_SAVE_PATH)
	check(not blocked.move_attempted, "legacy v2 rejection never attempts to move its file")
	check(not blocked.save_game(State.LEGACY_SAVE_PATH), "saving cannot overwrite the legacy v2 path")
	blocked.free()
	clean(state)
	restored.free()
	state.free()
	print("SAVE SAFETY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
