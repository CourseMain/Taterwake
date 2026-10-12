extends SceneTree
const Refusal = preload("res://scripts/refused_tap.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for frame in range(8): await process_frame
	game.set_process(false); game.year_intro.stop(); game.hud.close_panel()
	game.tutorial.start(); game.state.tutorial_progress.step = 4; game.tutorial._enter_step()
	var instruction: String = game.hud._tutorial_body.text
	game.hud.show_refusal("Can empty · Click the tank to walk over and refill.", game.hud._tutorial_next)
	check(game.hud._tutorial_body.text == instruction, "refusal preserves the guided instruction")
	check(game.hud._tutorial_feedback.text == "Can empty. Fill it at the tank.", "refusal gives cause and effect together")
	check(game.hud._tutorial_feedback.get_theme_font_size("font_size") >= 14, "refusal uses caption size")
	check(game.hud._tutorial_next.get_meta("refusal_duration_ms") == 200, "control shakes for 200 ms")
	var tween: Tween = game.hud._tutorial_next.get_meta("refusal_tween")
	tween.custom_step(.20)
	check(is_zero_approx(game.hud._tutorial_next.rotation), "shake restores the control")
	game.tutorial.active = false; game.hud.set_tutorial({})
	check(game.hud._notice_is_warning("Low Field · for rent at the Winter accounts, 55,000 a year"), "phone keeps the full rental direction visible")
	game.hud.set_context("Water this bed.")
	game.hud.show_refusal("Can empty", game.hud._tutorial_next)
	check(game.hud._context.text == "Water this bed.", "farm instruction remains above refusal")
	check(game.hud._refusal_caption.visible and game.hud._refusal_caption.text == "Can empty. Fill it at the tank.", "farm refusal has its own line")
	for cause in ["Can empty","Frozen beds","Sprayer empty","No pests","Barn full","Nothing to harvest","Still growing","Water this","No seeds","Already planted","Till the soil","Plant a seed","Ready to harvest","Already watered","Soil ready","Not enough Spudions","tank water","Can is full","Not enough tonnes","whole number","Autumn","Spring","Run over","guided","glowing","collected"]:
		check(Refusal.caption(cause).split(" ",false).size() <= 8, "eight-word refusal: " + cause)
	check(await preload("res://tests/audio_fixture.gd").release(game,self), "audio releases")
	game.queue_free()
	for frame in range(8): await process_frame
	print("REFUSED TAPS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
