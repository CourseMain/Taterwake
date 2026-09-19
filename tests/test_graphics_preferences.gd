extends SceneTree
## Exercise the real menu and device setting without reading or writing a farm.
const Preferences = preload("res://scripts/graphics_preferences.gd")
const TEST_PATH: String = "user://integration_graphics_preferences.cfg"
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
	if "--integration-test" not in OS.get_cmdline_user_args():
		quit(1)
		return
	check(Preferences.save_mode("smooth", TEST_PATH) == OK, "device preference writes successfully")
	check(Preferences.load_mode(TEST_PATH) == "smooth", "Smooth survives a new settings read")
	check(Preferences.save_mode("unknown", TEST_PATH) == ERR_INVALID_PARAMETER, "invalid mode cannot replace saved setting")
	check(Preferences.load_mode(TEST_PATH) == "smooth", "rejected setting preserves previous choice")
	check(Preferences.save_mode("crisp", TEST_PATH) == OK and Preferences.load_mode(TEST_PATH) == "crisp", "Crisp is a persisted device option")
	var corrupt := ConfigFile.new()
	corrupt.set_value("graphics", "quality", 42)
	corrupt.save(TEST_PATH)
	check(Preferences.load_mode(TEST_PATH) == "balanced", "invalid stored data falls back safely")
	DirAccess.remove_absolute(TEST_PATH)
	check(Preferences.load_mode(TEST_PATH) == "balanced", "first launch uses Balanced")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var purse: float = game.state.coins
	var elapsed: float = game.state.elapsed
	game.hud._act("graphics")
	await process_frame
	check(game.hud._panel_kind == "graphics", "menu action opens actual graphics panel")
	check(game.hud._refs.graphics_balanced.disabled, "selected Balanced control is clear")
	var backing_size: Vector2i = root.size
	game.hud._refs.graphics_crisp.pressed.emit()
	check(game.graphics_quality == "crisp" and game.world._sun.shadow_enabled, "Crisp keeps shadows and selects the sharp farm mode")
	check(game.farm_viewport.msaa_3d == Viewport.MSAA_4X and root.size == backing_size, "Crisp raises farm antialiasing independently of UI resolution")
	game.hud._refs.graphics_smooth.pressed.emit()
	check(game.graphics_quality == "smooth" and game.world.graphics_quality == "smooth", "button updates world and controller")
	check(not game.world._sun.shadow_enabled, "Smooth removes costly shadow map")
	check(game.hud._refs.graphics_smooth.disabled and not game.hud._refs.graphics_balanced.disabled, "buttons reflect the new selection")
	check(game.state.coins == purse and game.state.elapsed == elapsed, "graphics selection leaves money and farm time intact")
	check(not game.debug_unlocked and game.debug_time_multiplier == 1.0, "graphics does not change debug access or simulation speed")
	game._on_action("graphics:unknown")
	check(game.graphics_quality == "smooth", "unsupported menu action leaves graphics unchanged")
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	for island: int in [2, 3, 1]:
		game.state.travel_to(island)
		check(game.world.graphics_quality == "smooth" and not game.world._sun.shadow_enabled, "Smooth stays active on island%d" % island)
	game.hud._act("graphics")
	await process_frame
	game.hud._refs.graphics_balanced.pressed.emit()
	check(game.world._sun.shadow_enabled, "Balanced restores world shadows")
	check(game.hud._refs.graphics_current.text == "Using Balanced", "panel reflects Balanced again")
	game.hud.close_panel()
	game.tutorial.start()
	var lesson: String = game.tutorial.current_id()
	var guide_graphics: Button = game.hud.root.find_child("TutorialGraphics", true, false)
	check(guide_graphics.is_visible_in_tree() and not guide_graphics.disabled, "graphics is reachable from the first tutorial card")
	guide_graphics.pressed.emit()
	check(game.hud._panel_kind == "graphics", "tutorial settings icon opens Graphics")
	game.hud._act("graphics:smooth")
	check(game.graphics_quality == "smooth" and game.tutorial.current_id() == lesson, "tutorial settings keep the current lesson")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/graphics-menu.png")
	game.queue_free()
	await process_frame
	print("GRAPHICS PREFERENCES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
