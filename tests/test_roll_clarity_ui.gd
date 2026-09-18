extends SceneTree
## All-in affordability, discoverable cheats, and truthful weighted reel previews.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/roll-clarity-" + name + ".png") == OK, "render " + name)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for glyph: String in ["→", "←", "↑", "↓", "✓", "▸", "▾", "★", "◆"]:
		check(game.hud._font.has_char(glyph.unicode_at(0)), "bundled UI font covers " + glyph)
	check(game.hud._font.variation_opentype.get(2003265652) == 400.0 and game.hud._heading_font.variation_opentype.get(2003265652) == 700.0, "bundled variable font uses readable body and heading weights")
	game._on_action("menu")
	var menu: GridContainer = game.hud._body.get_child(0)
	check(menu.get_child(2).get_meta("action", "") == "debug", "Debug is in the first menu row")
	await shot("debug-menu")
	menu.get_child(2).pressed.emit()
	check(game.hud._panel_kind == "debug", "first-row Debug card opens money and luck controls")
	await shot("debug-controls")
	game.hud.close_panel()
	game.state.coins = 1e16
	game.state.mastery.russet = 30000
	game.state.unlock_island2()
	game.state.unlock_island3()
	game.state.travel_to(3)
	game.state.coins = 20e12
	game._on_action("roll")
	check(not game.hud._refs["roll:normal"].disabled, "winter ordinary roll still costs20T")
	check(game.hud._refs["roll:all_in"].disabled, "20T purse cannot all-in below the60T floor")
	game.state.coins = 60e12
	game.hud.update_state(game.state)
	check(game.hud._refs["roll:all_in"].disabled and game.hud._refs["roll:all_in"].text.contains("Need >"), "exactly60T is visibly ineligible for all-in")
	check(not game.hud._refs["batch:3"].disabled, "60T still buys three ordinary rolls")
	check(game.hud._refs.roll_minimum.text.contains("more than") and game.hud._refs.roll_minimum.text.contains("60"), "single stake and strict all-in floor are explained separately")
	await shot("all-in-floor")
	game.state.coins = 61e12
	game.hud.update_state(game.state)
	check(not game.hud._refs["roll:all_in"].disabled, "61T purse can all-in")
	game.hud._act("roll:all_in")
	check(game.hud._all_in_pending and not game.hud.is_roll_animating(), "eligible all-in still requires the deliberate second press")
	game.hud._act("cancel_all_in")
	game.state.luck = 3
	game.state.apply_debug(1, 1000)
	game.hud._preview_stake("normal")
	var actual_odds: Array = game.state.roll_odds("normal")
	check(game.hud._spinner._odds.size() == actual_odds.size(), "reel receives all current rarity tiers")
	for index: int in range(actual_odds.size()):
		check(is_equal_approx(float(game.hud._spinner._odds[index].chance), float(actual_odds[index].chance)), "reel probability matches backend tier " + str(actual_odds[index].tier))
	var sim_rng: int = game.state.rng.state
	game.hud._spinner._rng.seed = 44176
	var commons: int = 0
	var premium: int = 0
	for _index: int in range(10000):
		var tier: String = game.hud._spinner._preview_tier()
		if tier == "common": commons += 1
		if tier in ["legendary", "mythic", "jackpot", "relic", "mystery"]: premium += 1
	check(commons < 100 and premium > 5000, "3000x luck previews follow rare-heavy live odds rather than22percent hardcoded commons")
	check(game.state.rng.state == sim_rng, "decorative previews do not consume actual game RNG")
	await shot("high-luck-preview")
	game.hud.begin_roll("normal")
	var frozen: Array = game.hud._spinner._odds.duplicate(true)
	game.state.debug_luck_multiplier = 1
	game.hud.update_state(game.state)
	check(game.hud._spinner._odds == frozen, "reel odds stay frozen to purchase odds during animation")
	var real_result: Dictionary = {"tier": "common", "title": "THE EMPTY SACK", "detail": "No reward", "bet": 20e12}
	game.hud.spin_roll(real_result)
	game.hud._spinner._process(5)
	check(game.hud._revealed_roll == real_result and str(game.hud._spinner._cards[23].tier) == "common", "actual backend result stays authoritative even when previews favor rare tiers")
	check(game.hud._spinner._flash == 0, "actual common result does not gain fake high-rarity effects")
	game.hud._preview_stake("big")
	check(str(game.hud._spinner._cards[23].title) == "THE EMPTY SACK", "changing odds after reveal cannot replace the real winning card")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("ROLL CLARITY UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
