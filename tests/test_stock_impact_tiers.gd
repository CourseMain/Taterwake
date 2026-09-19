extends SceneTree
## Exact boundaries and cleanup matter: a falling quote must never leave jackpot FX alive.
const Impact = preload("res://scripts/market_impact.gd")
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
	var effect = Impact.new()
	root.add_child(effect)
	await process_frame
	check(not effect.active and not effect.visible and not effect.is_processing(), "calm farm allocates no active FX loop")
	var boundaries: Dictionary = {-100.0: 0, 300.0: 0, 300.01: 1, 499.99: 1, 500.0: 2, 2999.99: 2, 3000.0: 3, 10000.0: 3, 14999.99: 3, 15000.0: 4, 19900.0: 4}
	for percent: float in boundaries:
		effect.set_quote(1, percent)
		check(Impact.tier_for_percent(percent) == boundaries[percent] and effect.tier == boundaries[percent], "exact tier boundary at %s percent" % percent)
	effect._process(1.5)
	var arrival_age: float = effect._tier_elapsed
	effect.set_quote(1, 17500.0)
	check(effect._tier_elapsed == arrival_age and effect.tier == 4, "same-tier quote updates do not replay the arrival flash")
	effect._process(40.0)
	check(effect.active and effect.tier == 4 and effect._energy() > 0.0, "continuous stock lasts as long as its quote")
	effect.set_quote(1, 400.0)
	check(effect.tier == 1 and not effect._strong and effect._visual_tier() == 1, "falling quote immediately removes jackpot symbols and the stronger wash")
	effect.set_quote(1, 300.0)
	check(not effect.active and not effect.visible and not effect.is_processing() and effect.strength == 0.0, "return to ordinary stock clears the effect in the same update")
	check(float(effect._mist_material.get_shader_parameter("energy")) == 0.0 and effect._energy() == 0.0, "quote drop also clears shader energy")
	effect.set_quote(1, 16000.0)
	effect.reward(1)
	effect.set_countdown(1, 1.0)
	effect._process(0.5)
	effect.set_quote(2, 350.0)
	check(effect.tier == 1 and effect._elapsed == 0.0 and effect._tier_elapsed == 0.0, "changing islands restarts the appropriate tier")
	check(effect._reward_remaining == 0.0 and effect._anticipation == 0.0 and effect.remaining == 0.0, "previous island cannot leak rewards, countdown or timed surges")
	check(effect._color == Color("ffd537"), "island two is yellow")
	effect.set_quote(3, 15000.0)
	check(effect._color == Color("35aaff"), "island three is blue")
	effect.set_quote(1, 301.0)
	check(effect._color == Color("19f889"), "island one is green")
	effect.set_quote(1, 0.0)
	effect.reward(1, 2.0)
	check(effect.active and effect.tier == 0 and effect._visual_tier() == 0 and not effect._strong, "reward mist does not turn into stock jackpot symbols")
	effect._process(2.01)
	check(not effect.active, "reward layer expires independently")
	effect.set_countdown(1, 10.0)
	check(effect.active and effect._anticipation > 0.0 and effect.tier == 0, "countdown retains its quiet anticipation")
	effect.set_countdown(1, 180.0)
	check(not effect.active, "reset countdown fully clears anticipation")
	effect.surge(1, 1.0, 2.0)
	effect._process(0.5)
	check(effect.active and effect._visual_tier() == 2 and effect.tier == 0, "legacy timed surge remains supported without promoting the quote")
	effect.set_quote(1, 0.0)
	check(not effect.active and effect.remaining == 0.0, "a calm quote cancels a stale timed surge")
	effect.set_quote(1, 16000.0)
	var node_count: int = effect.get_child_count()
	for frame: int in range(600):
		effect._process(1.0 / 60.0)
	check(effect.get_child_count() == node_count and node_count == 1, "sustained rocket tier has bounded resources and no particle-node accumulation")
	check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect._mist.mouse_filter == Control.MOUSE_FILTER_IGNORE, "effects pass every farm and camera interaction through")
	effect.free()
	if "--capture" in OS.get_cmdline_user_args():
		await capture_farm()
	print("STOCK IMPACT TIERS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture_farm() -> void:
	# Use the real farming scene for readability QA, at native and compact sizes.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.hud.set_process(false)
	game.hud.close_panel()
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud.set_context("")
	game.state.island2_unlocked = true
	game.state.island3_unlocked = true
	var effect = game.hud._market_impact
	for level: int in range(1, 5):
		effect.set_quote(1, [0.0, 400.0, 1500.0, 7000.0, 17000.0][level])
		effect._elapsed = 2.2
		effect._tier_elapsed = 2.2
		effect._process(0.0)
		effect.set_process(false)
		await shot("tier-" + str(level))
	for island_id: int in [2, 3]:
		game.state.travel_to(island_id)
		game.hud._toast_box.hide()
		effect.set_quote(island_id, 7000.0)
		effect._elapsed = 2.2
		effect._tier_elapsed = 2.2
		effect._process(0.0)
		effect.set_process(false)
		await shot("island-" + str(island_id) + "-jackpot")
	root.size = Vector2i(960, 600)
	effect.set_quote(3, 17000.0)
	effect._elapsed = 2.2
	effect._tier_elapsed = 2.2
	effect._process(0.0)
	effect.set_process(false)
	await shot("compact-rocket")
	effect.set_quote(3, 0.0)
	await shot("cleared")
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/stock-impact-" + label + ".png") == OK, "render " + label)
