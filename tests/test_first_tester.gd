extends SceneTree
## Segment 21f: fresh guidance, real cosmetic purchases, saves and phone typography.
var game
var checks: int = 0
var failures: int = 0
const SAVE := "user://first-tester-test-only.json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + words)
func settle() -> void:
	for frame in range(12): await process_frame
	game.hud._process(.21)
	game.touch_controls._process(.21)
func typography(node: Node, scale: float, page: String) -> void:
	for child in node.get_children(): typography(child, scale, page)
	if not node is Control or not node.is_visible_in_tree(): return
	if node is Label or node is Button or node is LineEdit or node is RichTextLabel:
		var property: String = "normal_font_size" if node is RichTextLabel else "font_size"
		var pixels: float = node.get_theme_font_size(property) * scale
		check(pixels >= 13.99, "%s: %s meets the 14 px text floor (%s)" % [page, node.name, pixels])
		if node.has_meta("text_tier"): check(node.get_meta("text_tier") in [14, 16, 22], "three text tiers only")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(); game.set_process(false)
	game._resume_loaded_farm(false)
	check(game.hud._panel_kind == "farmer" and not game.hud._tutorial_card.visible, "first farm shows one skippable farmer card")
	check(game.hud._modal_close.text == "Skip", "first farmer card has one named Skip exit")
	game.hud._refs.farmer_name.text = "Rowan"; game.hud._refs.farmer_name.text_changed.emit("Rowan")
	var shirt: Button = game.hud._body.find_child("FarmerChoice_shirt_a86f62", true, false)
	check(not shirt.disabled, "first-launch farmer choices are usable before the guide")
	shirt.pressed.emit()
	game.hud._act("close")
	check(game.state.farmer_appearance.chosen and game.state.farmer_appearance.name == "Rowan" and game.state.farmer_appearance.shirt == "a86f62", "name and appearance are kept when the card closes")
	game.tutorial.refresh(); await settle()
	check(game.tutorial.current_id() == "welcome" and not game.hud._weather_button.visible and not game.hud._quick_sell.visible and not game.hud._season_strip.visible, "welcome hides everything its step does not need")
	check(game.state.ClimateSystem.GUIDED_WARNING_SECONDS == 30, "guided warning gives thirty normal seconds")
	for step in game.tutorial.STEPS:
		check(str(step.body).split(" ").size() <= 12 and not str(step.body).contains(";") and not str(step.body).contains("["), "guide uses short plain sentences: " + step.id)
	game.tutorial.finish(); game.hud.close_panel()
	for season in range(4):
		game.state.season_clock.season = season
		for keeper in ["mara", "nell", "tess", "iris"]:
			check(game.state.NpcRoster.service_greeting(keeper, game.state).contains("Rowan"), "keeper uses the chosen name")
	game.state.season_clock.season = 0
	var before: Dictionary = game.state._save_data().duplicate(true)
	var starting_cash: float = game.state.coins
	game.hud.show_panel("tools", game.state)
	game._on_action("decorate:bench:0")
	check(game.state.decorations == {"bench":0} and game.state.coins == starting_cash - 2000, "decoration purchase uses the sole ledger balance")
	check(game.state.ledger.entries.back().label == "Decoration · Bench" and game.state.ledger.entries.back().amount == -2000, "bench posts the exact cosmetic cash spend")
	check(game.state.plots == before.plots and game.state.tools == before.tools and str(game.state.rng.state) == before.rng_state, "decoration changes no crops, tools or farm RNG")
	var cash: float = game.state.coins
	game._on_action("decorate:bench:1")
	check(game.state.coins == cash, "an owned decoration cannot charge twice")
	game._on_action("decorate:gate_flag:2")
	check(game.state.decorations.gate_flag == 0, "the flag stays on the gate")
	check(game.world.decorations_root.has_node("Decoration_bench"), "bought decorations appear on the farm")
	check(game.state.save_game(SAVE) and game.state.load_game(SAVE), "appearance and decorations survive a real save reload")
	check(game.state.farmer_appearance.name == "Rowan" and game.state.decorations.has("bench"), "reload preserves chosen identity and possessions")
	var old: Dictionary = game.state._save_data()
	for key in ["farmer_appearance", "decorations", "graded_harvests"]: old.erase(key)
	check(game.state._valid_save(old), "v2.0.1 saves remain compatible")
	game.hud.close_panel()
	for bed in game.state.plots: game.state._clear_crop(bed)
	game.state.plots[5].tilled = true; game.state.interact_plot(5, "plant")
	game.state.interact_plot(5, "water")
	game.hud.update_state(game.state); game.hud._process(.21)
	check(game.hud._wait_card.visible and game.hud._wait_label.text == game.tutorial.WAIT_MESSAGE, "ordinary growing wait explains the next action")
	game.queue_plot(5)
	check(game.hud._context.text.begins_with("Ready in "), "tapping a growing bed names the remaining seconds")
	game._cancel_walk()
	root.min_size = Vector2i.ZERO; root.size = Vector2i(390, 844)
	game.touch_controls.enabled = true; game.touch_controls._build_touch_sheets(); game.touch_controls.resize()
	await settle()
	var scale: float = game.touch_controls.display_scale()
	check(game.hud._play_band.size.y * scale <= 56.1, "phone top band is at most fifty-six pixels")
	var row: Array[Control] = [game.hud._season_strip, game.hud._stats_card, game.hud._menu_button]
	check(row[0].position.y == row[1].position.y and row[1].position.y == row[2].position.y, "season, money and Menu occupy one row")
	check(game.hud.root.find_child("FarmWordmark", true, false) == null, "the wordmark lives on the gate, not in the HUD")
	for page in ["market", "barn", "inventory", "tools", "accounts", "climate", "quests", "pause", "farmer", "grades", "calendar"]:
		game.hud.show_panel(page, game.state); await settle()
		typography(game.hud.root, scale, page)
	game.hud.close_panel()
	game.state.season_clock.season = 0
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	game.hud.set_tutorial({})
	game.hud._spring_target.refresh()
	await settle()
	check(game.hud._play_band.get_theme_stylebox("panel") is StyleBoxEmpty and game.hud._stats_card.get_theme_stylebox("panel") is StyleBoxEmpty, "top row has no filled green blocks")
	check(game.hud._spring_target.facts.text.count("\n") == 2, "Spring arithmetic uses three compact rows")
	check(game.hud.root.find_child("HurryBadge", true, false) == null and not InputMap.has_action("hurry"), "removed Hurry leaves no badge or input action")
	game.hud.show_farm_hint("Home bed · open 12 more at the Tools shed, 48,000")
	await settle()
	var paper = game.hud._context_box.get_theme_stylebox("panel")
	check(paper.get_meta("surface_fill").a < 1 and game.hud._context_cue.mouse_filter == Control.MOUSE_FILTER_IGNORE, "warm hint paper and its animated cue pass farm input through")
	game.hud.clear_farm_hint()
	game._on_user_action("market"); await settle()
	check(not game.hud._spring_target.visible and not game.hud._wait_card.visible and not game.touch_controls.fullscreen.visible, "conversation clears farm notes and the fullscreen tap target")
	game.conversation.finish(); await settle()
	game.state.graded_harvests = 0
	for harvest in range(4):
		game.state.plots[6].merge({"unlocked":true, "tilled":true, "stage":3, "crop":"russet", "watered":true, "quality":60}, true)
		game._on_state_changed(); game.perform_plot(6, "harvest")
		var fx = game.world.harvest_feedback
		check(fx.active[0].stamp.text.contains("normal") == (harvest < 3), "only the first three harvests carry the grade gloss")
		check((game.hud._panel_kind == "grades") == (harvest == 0), "grade explanation appears once")
		game.hud.close_panel(); fx.animate(2)
	game.world.show_future({"outcome":"Thriving", "axes":{"land_health":.8,"water_security":.8,"biodiversity":.8,"soil_fertility":.8}, "projects":{}, "conditions":{}, "crops":[], "decorations":game.state.decorations, "farmer_appearance":game.state.farmer_appearance})
	check(game.world.decorations_root.has_node("Decoration_bench"), "the fifty-year farm keeps bought decorations")
	for suffix in ["", ".bak", ".tmp", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	game.queue_free(); await process_frame; await create_timer(.3).timeout
	print("FIRST TESTER: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
