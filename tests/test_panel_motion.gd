extends SceneTree
## Open real places, follow their projected origins, and keep the farm alive.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for frame in range(8): await process_frame

func projected(point: Vector3) -> Vector2:
	return game.world.camera.unproject_position(point) * game.hud.root.size / Vector2(game.farm_viewport.size)

func station_origin(station: String) -> Vector2:
	return projected(game.world.station_position(station) + Vector3(0, 1.8, 0))

func economy() -> String:
	return JSON.stringify({"cash": game.state.coins, "ledger": game.state.ledger.entries,
		"stock": game.state.storage, "seeds": game.state.seed_inventory})

func entrance(kind: String, expected: Vector2, duration: float) -> void:
	var hud = game.hud
	check(hud.panel_entrance_duration() == duration and hud.panel_entrance_progress() == 0, kind + " begins its authored slide")
	var origin: Vector2 = expected - hud._modal_card.get_global_rect().get_center()
	check(hud.panel_entrance_offset().distance_to(origin) < .1, kind + " starts at the projected world object")
	check(hud._modal_entrance_shield.visible and hud._modal_motion.modulate.a == 0, kind + " shields input before the drawing settles")
	var previous: float = origin.length()
	for fraction in [.2, .3, .49]:
		hud.advance_panel_entrance(duration * fraction)
		var offset: Vector2 = hud.panel_entrance_offset()
		check(offset.length() <= previous + .01 and offset.dot(origin) >= -.01, kind + " approaches its frame without overshoot")
		previous = offset.length()
	check(hud.panel_entrance_progress() < 1 and hud._modal_entrance_shield.visible, kind + " cannot accept taps before its duration ends")
	hud.advance_panel_entrance(duration * .011)
	check(hud.panel_entrance_progress() == 1 and hud.panel_entrance_offset() == Vector2.ZERO, kind + " settles within its duration")
	check(not hud._modal_entrance_shield.visible and hud._modal_motion.modulate.a == 1, kind + " releases input with an opaque page")
	hud.advance_panel_entrance(10)
	check(hud.panel_entrance_offset() == Vector2.ZERO, kind + " stays settled after a long frame")

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.state.rng.seed = 6
	game.state.tutorial_progress.completed = true
	game.hud.set_tutorial({})
	await settle()
	check(game.test_mode, "motion fixture cannot touch the player's save")
	var before: String = economy()
	for dimensions in [Vector2i(1280, 800), Vector2i(390, 844)]:
		root.min_size = Vector2i.ZERO
		root.content_scale_size = dimensions
		root.size = dimensions
		await settle()
		for place in ["market", "barn", "climate", "quests"]:
			var expected: Vector2 = station_origin(place)
			game.hud.set_panel_source(place)
			check(game.hud.panel_source_position(place).distance_to(expected) < .1, place + " source uses the camera projection at " + str(dimensions))
			game.hud.set_panel_source(place)
			game.hud.show_panel(place, game.state)
			await settle()
			entrance(place, expected, .42)
			check(game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, place + " leaves the farm rendering")
			game.hud.close_panel()
		# A tap source overrides a generic destination once, then is consumed.
		game.hud.set_panel_source("barn")
		check(game.hud.panel_source_position("market").distance_to(station_origin("barn")) < .1, "the tapped building owns the source")
		check(game.hud.panel_source_position("market").distance_to(station_origin("market")) < .1, "a previous tap cannot move an unrelated next page")
		game.state.season_clock.season = 3
		game.hud.set_panel_source("barn")
		var book: Vector2 = projected(game.world.ledger_book_position())
		check(game.hud.ledger_screen_position().distance_to(book) < .1, "ledger origin tracks the book at " + str(dimensions))
		game.hud.show_panel("accounts", game.state)
		while game.hud.accounts_building: await process_frame
		await settle()
		entrance("accounts", book, .6)
		game.hud.close_panel()
		game.state.season_clock.season = 0
		check(game.hud.panel_source_position("climate").distance_to(station_origin("climate")) < .1, "closing the ledger cannot leak the old barn source into the next forecast")
	check(economy() == before, "opening and animating pages never changes cash, ledger, stock or seeds")
	# A closed page invalidates its deferred entrance before that callback runs.
	game.hud.show_panel("market", game.state)
	game.hud.close_panel()
	await settle()
	check(not game.hud.is_panel_open() and not game.hud._modal_entrance_shield.visible, "closing immediately cancels the pending entrance and input shield")
	# Enter through the actual tapped station path, then observe paused reading.
	game._interact_station("market")
	check(game.conversation.visible and game.conversation.npc_id == "mara", "tapping Mara opens her short greeting before seeds")
	game.conversation.set_process(false)
	check(game.conversation.visible and game.conversation.npc_id == "mara", "tapping Mara's stall opens her conversation")
	var expected_offset: Vector2 = station_origin("market") - game.conversation.size * .5
	check(game.conversation._source_offset.distance_to(expected_offset) < .1, "Mara's conversation starts at her stall")
	var saved: String = JSON.stringify(game.state._save_data())
	var world_time: float = game.world._time
	game._process(.2)
	check(game.world._time > world_time and game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the farm visibly advances behind a conversation")
	check(JSON.stringify(game.state._save_data()) == saved, "reading a conversation leaves the full farm and calendar unchanged")
	game.conversation._process(.42)
	check(game.conversation.modulate.a == 1, "conversation arrives in the same brief ordinary motion")
	game.conversation.finish()
	check(economy() == before, "conversation motion cannot transact crops or money")
	game.queue_free()
	await settle()
	await create_timer(.1).timeout
	print("PANEL MOTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
