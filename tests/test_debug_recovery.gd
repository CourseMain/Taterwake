extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## Authenticated test funding and recovery from the overdraft boundary.
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func settle() -> void:
	for _i in range(8): await process_frame
func shot(name: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.75).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/debug-recovery-" + name + ".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	var farm = game.state
	game._on_action("debug:set_balance:10000")
	check(farm.coins == 2000, "locked route cannot set test funds")
	game._on_action("debug:unlock:" + game.DEBUG_ACCESS_CODE)
	game._on_action("debug:island:2")
	check(farm.coins == 2000, "unlocking preserves cash and location")
	farm.seed_inventory.russet = 37
	farm.storage["russet"] = Stock.pile(40)
	farm.tools.water = 1
	farm.coins = -5000
	check(not farm.run_over, "exact overdraft boundary survives")
	farm.coins = -501
	farm.season_clock.season = 2
	farm.season_clock.seconds = 149.75
	farm.update(0.25)
	await settle()
	var collapse = game.hud._run_end
	check(collapse.visible and collapse.headline.text == "FORECLOSED" and collapse._threshold.text.contains("5,000"), "collapse explains overdraft boundary")
	await shot("receipt")
	var before: float = farm.coins
	farm.coins = 2000
	check(farm.coins == before, "ordinary balance assignment cannot revive an ended run")
	game._on_action("debug")
	game._on_action("debug:recover:0")
	check(farm.run_over, "recovery requires positive funds")
	game._on_action("debug:recover:2000")
	await settle()
	check(not farm.run_over and farm.coins == 2000, "explicit debug recovery resumes farm")
	check(farm.seed_inventory.russet == 37 and Stock.count(farm.storage, "russet") == 38 and Stock.count(farm.trading.held, "russet") == 38 and farm.tools.water == 1, "recovery preserves surviving stores, seeds and tools after Winter spoilage")
	check(farm.climate.data.collapse.is_empty() and not collapse.visible, "recovery clears stale final receipt")
	game.hud.close_panel()
	game._on_action("debug")
	game._on_action("debug:set_balance:10000")
	check(farm.coins == 10000, "authorized cash editor sets bounded funds")
	game._on_action("debug:set_balance:100001")
	check(farm.coins == 10000, "cash editor rejects amounts above the limit")
	game.queue_free()
	await settle()
	print("DEBUG RECOVERY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
