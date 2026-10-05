extends SceneTree
## Presentation: clickable duck patrol controls.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 4e+17
	var stations: Dictionary = {1: "DuckPatrolHouse"}
	for island in [1]:
		game._on_state_changed()
		await process_frame
		await physics_frame
		var station: Node3D = game.world.get_node(stations[island])
		var aim: Vector2 = game.world.camera.unproject_position(station.global_position + Vector3(0, 1.2, 0))
		check(str(game.world.pick(aim).get("station", "")) == ("duck_patrol" if island == 1 else "activities"), "island %d activity station is actually clickable" % island)
		game.hud.show_panel("duck_patrol", game.state)
		check(game.hud._refs.has("activity_status"), "island %d activity uses modal rather than adding HUD clutter" % island)
		game.hud.close_panel()
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("FEATURE PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
