extends SceneTree
## Presentation contracts: clickable activities, actual batch cards, and persistent gear art.
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
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	game.state.coins = 1e16
	game.state._grant_item("aurora_crown")
	var stations: Dictionary = {1: "DuckPatrolHouse", 2: "BuyerContracts", 3: "FrostFurnace"}
	for island: int in [1, 2, 3]:
		game.state.travel_to(island)
		game._on_state_changed()
		await process_frame
		await physics_frame
		var station: Node3D = game.world.get_node(stations[island])
		var aim: Vector2 = game.world.camera.unproject_position(station.global_position + Vector3(0, 1.2, 0))
		check(str(game.world.pick(aim).get("station", "")) == "activities", "island %d activity station is actually clickable" % island)
		check(is_instance_valid(game.world._gear_hat) and game.world._gear_hat_id == "aurora_crown", "collected hat survives island %d rebuild" % island)
		game.hud.show_panel("activities", game.state)
		check(game.hud._refs.has("activity_status"), "island %d activity uses modal rather than adding HUD clutter" % island)
		if island == 2:
			game.hud._refs.contract_crop_choice.item_selected.emit(4)
			check(game.state.selected_crop == "sunburst", "contract crop picker selects the supplied crop without a seed menu round-trip")
			game.hud._act("activity:contract:mutation")
			check(game.hud._refs.contract_crop_choice.disabled and game.hud._refs.activity_status.text.contains("SUNBURST"), "active mutation order identifies and locks its selected crop")
		game.hud.close_panel()
	game.hud.begin_roll("normal")
	var results: Array = [
		{"tier": "common", "title": "Spare change", "detail": "Coins"},
		{"tier": "rare", "title": "Lucky Patchwork Cap", "item_id": "lucky_cap", "detail": "Permanent luck"},
		{"tier": "rare", "title": "Harvest Straw Hat", "item_id": "straw_hat", "detail": "Permanent yield"}
	]
	game.hud.spin_batch(results)
	game.hud._spinner._process(5.0)
	check(game.hud._revealed_roll.title == "Lucky Patchwork Cap", "batch reel reveals one of the actual highest-tier outcomes")
	check(game.hud._refs.batch_results.get_child_count() == 3, "three actual results produce exactly three reward cards")
	check(game.hud._spinner._flash == 0, "batch of common and rare rewards does not trigger jackpot flash")
	game.hud.begin_roll("normal")
	check(game.hud._refs.batch_results.get_child_count() == 0 and not game.hud._refs.batch_results.visible, "next spin clears stale batch cards before charging")
	game.hud.cancel_roll()
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("FEATURE PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
