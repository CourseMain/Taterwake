extends SceneTree
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + text)
func settle() -> void:
	for _i in range(5): await process_frame
func shot(name: String) -> void:
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/luck-" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.coins = 1e9
	game.state.luck = 2.0
	game.state.inventory_items.lucky_cap = 1
	game.state.equipment.head = "lucky_cap"
	game.state.debug_luck_multiplier = 3.0
	var rng_before: int = game.state.rng.state
	var odds: Array = game.state.roll_odds("normal")
	game._on_action("roll")
	var meter = game.hud._refs.roll_luck_meter
	check(meter.is_visible_in_tree() and meter.numbers[2].text == "×3" and meter.numbers[1].text == "+125%", "preview shows additive percentage and multiplier")
	check(game.state.rng.state == rng_before and game.state.roll_odds("normal") == odds, "presentation does not consume reward RNG")
	await shot("preview")
	game.hud.begin_roll("stupid")
	meter.set_process(false)
	var result: Dictionary = {"tier": "common", "title": "THE EMPTY SACK", "detail": "No reward", "bet": 2000.0}
	game.hud.spin_roll(result)
	check(meter.playing and not game.hud._spinner.spinning, "calculation runs before reel starts")
	check(meter.numbers[0].text == "4×" and meter.captions[0].text == "Roll quality", "first step shows frozen stake and build quality")
	meter._process(0.7)
	check(meter.captions[1].text == "Earned + gear" and meter.numbers[1].text == "+125%", "second step shows earned and equipped bonus as a percentage")
	await shot("add-luck")
	var frozen: Dictionary = meter.values.duplicate(true)
	var elapsed: float = meter.elapsed
	game.state.luck = 5.0
	game.hud.update_state(game.state)
	check(meter.values == frozen and meter.elapsed == elapsed, "refresh cannot restart or replace purchased math")
	meter._process(0.65)
	check(meter.captions[2].text == "Luck multiplier" and meter.details[2].text == "+575% final bonus", "third step multiplies capped normal luck and shows its full total")
	await shot("multiply-luck")
	meter._process(0.65)
	check(not meter.playing and game.hud._spinner.spinning, "reel starts only after complete calculation")
	game.hud._spinner._process(5.0)
	check(game.hud._revealed_roll == result, "the purchased reward is preserved")
	game.hud.begin_roll("normal")
	game.hud.spin_roll(result)
	game.hud.cancel_roll()
	meter._process(10)
	check(not game.hud._spinner.spinning and game.hud._pending_spin.is_empty(), "cancellation cannot launch a stale result")
	game.hud.begin_roll("build_crate")
	check(not game.hud._refs.has("roll_luck_meter"), "build crate does not imply luck affects its separate reward deck")
	game.hud.cancel_roll()
	game.hud.close_panel()
	game.state.debug_unlock_island(3)
	game.state.travel_to(3)
	game.state.climate.acknowledge(game.state)
	game.state.coins = 1e16
	game._on_action("roll")
	meter = game.hud._refs.roll_luck_meter
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = dimensions
		await settle()
		check(game.hud.root.get_global_rect().encloses(game.hud._modal_card.get_global_rect()), "roll panel fits " + str(dimensions))
		check(game.hud._body.get_combined_minimum_size().x <= game.hud._body.size.x + 1.0, "calculation does not force horizontal scroll " + str(dimensions))
		for kind: String in ["normal", "big", "stupid", "all_in"]:
			check(game.hud._body.get_parent().get_global_rect().encloses(game.hud._refs["roll:" + kind].get_global_rect()), "stake visible without scrolling " + kind + " " + str(dimensions))
		check(meter.size.y <= 80 and game.hud._modal_card.get_global_rect().encloses(meter.get_global_rect()), "luck calculation stays compact and visible " + str(dimensions))
		for entry: Dictionary in game.state.roll_odds("normal"):
			var label: Label = game.hud._refs["odds:" + str(entry.tier)]
			check(label.text.contains("%") and not label.text.contains("??"), "every rarity reveals its full percentage")
			check(game.hud._body.get_parent().get_global_rect().encloses(label.get_global_rect()), "odds visible without scrolling " + str(entry.tier) + " " + str(dimensions))
	root.size = Vector2i(1280, 800)
	game.hud._toast_box.hide()
	await shot("winter")
	game.state.luck = 10.0
	game.state.debug_luck_multiplier = 1000.0
	game.hud.update_state(game.state)
	game.hud.begin_roll("big")
	var gear_result: Dictionary = {"tier": "rare", "title": "SEVEN-LEAGUE SNEAKERS", "detail": "Seven-League Sneakers collected! +0.15x luck while equipped. Equipped in your empty feet slot. Extra copies do not stack.", "bet": 200e12, "item_id": "gambler_boots"}
	game.hud.spin_roll(gear_result)
	meter._process(2.0)
	game.hud._spinner._process(5.0)
	await settle()
	check(meter.numbers[1].text == "+900%" and meter.details[2].text == "+999,900% final bonus", "maximum luck stays capped before multiplication")
	for kind: String in ["normal", "big", "stupid", "all_in"]:
		check(game.hud._body.get_parent().get_global_rect().encloses(game.hud._refs["roll:" + kind].get_global_rect()), "stake stays visible after a long reward description")
	await shot("reward")
	game.state.luck = 1.0
	game.state.equipment = game.state._empty_equipment()
	game.state.coins = 2.4e29
	game.hud.update_state(game.state)
	game.hud.show_panel("roll", game.state)
	game.hud._preview_stake("all_in")
	check(game.hud._refs.roll_luck_total.text.contains("Luck boost ×1,000 active"), "zero earned luck still explicitly reports the active multiplier")
	await shot("boost-1000")
	game.hud.close_panel()
	game.hud._toast_box.hide()
	await shot("ranchers")
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("ROLL LUCK METER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
