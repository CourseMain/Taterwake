extends SceneTree
## Tests cinematic handoff against the real controller, with no player save I/O.
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

func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "capture " + name)

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
	game.state.travel_to(3)
	game.state.select_crop("icecap")
	game.state.coins = 1.23e24
	game.state.storage.icecap = 4
	game.state.rocket_timer = 9.0
	game.hud.update_state(game.state)
	check(game.hud._export_title.text.contains("ROCKET IN") and game.hud._export_detail.text.contains("50,000"), "HUD announces imminent rocket with correct range")
	await shot("stock-rocket-countdown-hud")
	game.state.rocket_timer = 0.1
	game.state.surge_timer = 0.1
	game.hud.begin_roll("normal")
	game._process(0.1)
	check(game.state.rocket_pending and not game.rocket_cutscene.active, "rocket waits for an existing paid roll reveal")
	game.hud.cancel_roll()
	game._process(0.01)
	game.rocket_cutscene.set_process(false)
	check(game.rocket_cutscene.active and not game.hud.is_panel_open(), "pending rocket starts full-screen launch and closes menus")
	check(game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "opaque rocket film suspends hidden farm rendering")
	check(game.state.surge_remaining == 0.0, "no simultaneous normal boom consumes the selling window")
	var elapsed: float = game.state.elapsed
	var frost: float = game.state.frost_timer
	var pest: float = game.state.pest_timer
	var money: float = game.state.coins
	for tick: int in range(10):
		game._process(0.5)
	game._on_action("quick_sell")
	game._on_action("travel:1")
	check(game.state.elapsed == elapsed and game.state.frost_timer == frost and game.state.pest_timer == pest, "farm, pest and winter clocks pause during launch")
	check(game.state.current_island == 3 and game.state.coins == money and game.state.storage.icecap == 4, "cinematic blocks selling and travel input")
	game.rocket_cutscene._process(3.3)
	await shot("stock-rocket-live-launch")
	game.rocket_cutscene._process(game.rocket_cutscene.DURATION - 3.3)
	check(not game.state.rocket_pending and not game.rocket_cutscene.active, "finished signal releases simulation once")
	check(game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "farm drawing resumes with the selling window")
	check(game.state.surge_kind == "rocket" and game.state.surge_remaining == 10.0, "ten full seconds start after cinematic finishes")
	check(game.surge_band == 4 and game.hud._market_impact.tier == 4, "rocket quote activates strongest island-coloured stock effects")
	check(game.hud._export_title.text.contains("ROCKET"), "rocket selling window is labelled clearly")
	game.world.set_day_time(0)
	game.hud._market_impact._process(0.8)
	await shot("stock-rocket-boom-hud")
	var price: float = game.state.market.icecap.sell
	game._on_action("quick_sell")
	check(game.state.storage.icecap == 0 and game.state.coins > money and game.state.coins == money + price * 4, "F-sale action resumes at the actual rocket quote")
	game._process(0.1)
	check(absf(game.world.camera.h_offset) > 0 and absf(game.world.camera.h_offset) <= 0.12, "rocket celebration has bounded camera shake")
	game.state.surge_remaining = 0.0
	game.state.surge_factor = 1.0
	game.state.surge_kind = "normal"
	game.state._refresh_market(false)
	game._on_state_changed()
	game._update_stock_shake(0.01)
	check(game.surge_band == 0 and game.fanfare_remaining == 0.0 and game.hud._market_impact.tier == 0 and game.world.camera.h_offset == 0.0 and game.world.camera.v_offset == 0.0, "normal quote clears stock music, tier and camera shake")
	game.state.surge_remaining = 10.0
	game.state.surge_factor = 71.0
	game.state._refresh_market(false)
	game._on_state_changed()
	check(game.surge_band == 3 and game.hud._market_impact.tier == 3, "winter normal boom triggers musical tier three without cinematic")
	check(not game.rocket_cutscene.active, "ordinary jackpot never plays rocket movie")
	game.hud._market_impact._process(1.1)
	await shot("stock-winter-jackpot-hud")
	game.state.travel_to(1)
	game.state.surge_remaining = 10.0
	game.state.surge_crop = "russet"
	game.state.surge_factor = 18.0
	game.state._refresh_market(false)
	game._on_state_changed()
	check(game.surge_band == 2 and game.hud._market_impact.island == 1, "returning to Valley changes palette and uses early-island tier")
	check(not game.hud._export_detail.text.contains("ROCKET"), "rocket countdown is hidden on earlier islands")
	game.queue_free()
	await create_timer(0.5).timeout
	print("STOCK ROCKET GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
