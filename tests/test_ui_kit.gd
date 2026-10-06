extends SceneTree
## Segment 21h rejects the kit's sent-back list and verifies cosmetic rewards.
const Kit = preload("res://scripts/ui_kit.gd")
const Roster = preload("res://scripts/npc_roster.gd")
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + words)
func settle() -> void:
	for i in range(14): await process_frame
	game.hud.advance_panel_entrance(.8)
	game.touch_controls.resize(); game.touch_controls.fit_modal()
	game.hud.fit_text(game.hud.root)
func audit(node: Node, scale: float, sizes: Dictionary, page: String) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is Button or node is LineEdit:
		var words: String = node.text
		if not words.is_empty():
			var pixels: float = node.get_theme_font_size("font_size") * scale
			check(pixels >= 13.99, page + " has no text under 14 px: " + words)
			if node.has_meta("text_tier"): sizes[int(node.get_meta("text_tier"))] = true
			check(not words.contains("★") and words.to_lower() not in ["common", "uncommon", "rare", "found"], page + " has no rarity word or star")
			var font: Font = node.get_theme_font("font")
			if font is FontVariation: check(font.base_font in [Kit.Type.DISPLAY, Kit.Type.BODY, Kit.Type.BODY_BOLD], page + " uses the two kit typefaces")
	if node is ScrollContainer and page in ["farmer", "menu", "grades", "practice", "sale_reveal"]:
		check(not node.get_v_scroll_bar().visible and not node.get_h_scroll_bar().visible, page + " card has no scrollbar")
	if node is Button and not node.disabled:
		check(minf(node.size.x, node.size.y) * scale >= 43.9, page + " has a full touch target: " + node.text)
	if node is PanelContainer:
		var skin: StyleBox = node.get_theme_stylebox("panel")
		var fill: Color = skin.bg_color if skin is StyleBoxFlat else skin.get_meta("surface_fill", Color.TRANSPARENT)
		check(fill.a < .01 or fill not in [Color.WHITE, Color.GRAY, Color("e7e7dc")], page + " has no grey or white surface")
	for child in node.get_children(): audit(child, scale, sizes, page)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); await settle()
	for glyph in [0xE000, 0x2192, 0x2191, 0x2193]:
		check(Kit.Type.SPUDION.has_char(glyph), "drawn money and price arrows have bundled glyphs")
	game.state.boundary_save_path = ""; game.state.tutorial_progress.completed = true; game.state.tutorial_active = false; game.hud.set_tutorial({})
	root.min_size = Vector2i.ZERO; root.size = Vector2i(390,844)
	game.touch_controls.enabled = true; game.touch_controls._build_touch_sheets(); game.touch_controls.resize()
	await settle()
	for id in Roster.PEOPLE:
		for key in ["first", "story", "answer", "advice", "thanks", "weather"]:
			check(str(Roster.PEOPLE[id][key]).split(" ").size() <= (5 if id == "bram" else 8), id + " line fits its cast voice: " + key)
		for line in Roster.PEOPLE[id].daily: check(str(line).split(" ").size() <= (5 if id == "bram" else 8), id + " daily line is brief")
		for season in range(4):
			game.state.season_clock.season = season
			check(Roster.service_greeting(id, game.state).split(" ").size() <= (5 if id == "bram" else 8), id + " seasonal greeting is brief")
	game.state.season_clock.year = 3; game.state.season_clock.season = 3; game.state.ledger.post_fixed_costs(3)
	game.hud._component_receipt = {"tonnes":14,"grade":"Table","grade_factor":1.2,"season_name":"Winter","price":672,"amount":11289.6,"fired":["cold_store"]}
	for page in ["farmer", "menu", "accounts", "market", "grades", "practice", "sale_reveal"]:
		game.hud.show_panel(page, game.state); await settle()
		game.hud._modal_card._tilt(-2)
		check(game.hud._modal_card.rotation == 0, page + " whole page stays still on hover")
		var scale: float = game.touch_controls.display_scale()
		var sizes: Dictionary = {}; audit(game.hud._modal_card, scale, sizes, page)
		check(sizes.size() <= 3, page + " uses at most three type sizes")
		check(Rect2(Vector2.ZERO, game.hud.root.size).encloses(game.hud._modal_card.get_global_rect()), page + " fits the phone width")
		if page == "farmer":
			var preview = game.hud._refs.farmer_preview
			preview._process(.01)
			for point in [Vector3(-.8,0,0),Vector3(.8,2.1,0)]:
				check(Rect2(Vector2.ZERO, Vector2(preview.viewport.size)).encloses(Rect2(preview.camera.unproject_position(point), Vector2.ONE)), "whole farmer fits the preview")
			for hat in ["flower", "scarf"]: check(game.hud._body.find_child("FarmerChoice_hat_"+hat,true,false).disabled, "unearned clothing is shown and locked")
		elif page == "menu":
			var tiles: Array = game.hud._body.find_children("MenuTile_*", "Button", true, false)
			check(tiles.size() == 6, "Menu has exactly six picture tiles")
			for tile in tiles: check(tile.has_picture(), "Menu tile has a drawing above its name")
		elif page == "practice":
			for tile in game.hud._body.find_children("*", "PanelContainer", true, false):
				check(tile.edge == Kit.RARITIES[tile.DEFINITIONS[tile.rule_id].rarity], "practice rarity lives on its edge")
	var before_receipt: Dictionary = game.state._save_data()
	var reveal = game.hud._body.find_child("SaleReveal", true, false)
	reveal.set_process(false); reveal.elapsed = 0; reveal.completed = false; reveal._process(.3)
	check(reveal.steps.front().modulate.a > 0 and reveal.steps.back().modulate.a == 0, "sale starts with sacks and reveals money last")
	reveal.skip()
	check(reveal.completed and reveal.steps.all(func(step): return step.modulate.a == 1), "tap skips the presentation within four seconds")
	check(game.state._save_data() == before_receipt, "sale reveal never posts or changes the supplied transaction")
	game.hud.close_panel()
	var farm = game.state
	farm.reset_game()
	var cash: float = farm.coins; var random_state: int = farm.rng.state
	farm._harvest_plot(farm.plots[0])
	check(farm.clothing_unlocked == ["flower"], "first Table harvest earns Mara's flower hat")
	check(not farm.Clothing.earned(farm, "flower"), "reward is earned once")
	check(farm.coins == cash and farm.rng.state == random_state, "clothing does not affect cash or RNG")
	farm.season_clock.year = 5; farm.season_clock.season = 3
	farm._season_boundary()
	check("scarf" in farm.clothing_unlocked, "surviving year five earns Tess's scarf")
	game.hud.close_panel()
	farm.season_clock.year = 6; farm.coins += 150000; farm.ledger.post(6,0,"sales","Test crop sales",150000)
	farm._season_boundary()
	check("glasses" in farm.clothing_unlocked, "first profitable year earns Nell's glasses")
	await settle()
	check(game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text == "A profit. Write the date down."), "Nell marks the first profit")
	check(game.hud._body.find_child("KeeperPortrait_nell", true, false).avatar.expression == "pleased", "Nell smiles at the first profit")
	game.hud.show_panel("accounts", farm); await settle()
	check(game.hud._body.find_child("KeeperPortrait_nell", true, false).avatar.expression == "exact", "Nell returns to her exact expression afterward")
	var profile: String = "user://test_21h_clothing.json"
	farm.Clothing.write_profile(farm.clothing_unlocked, profile)
	check(farm.Clothing.read_profile(profile) == farm.clothing_unlocked, "collection survives a profile reload")
	DirAccess.remove_absolute(profile)
	var snapshot: Dictionary = farm._save_data()
	check(farm._valid_save(snapshot), "clothing save remains valid")
	farm.reset_game(); check(farm.clothing_unlocked.size() == 3, "collection survives a new run")
	farm.restore_snapshot(snapshot); check(farm.clothing_unlocked.size() == 3, "collection survives snapshot restore")
	for bad in [["bad"],["flower","flower"],"flower"]: check(not farm.Clothing.valid(bad), "invalid clothing save rejected")
	check(Roster.expression("nell",farm,"A profit. Write the date down.") == "pleased", "Nell smiles only at her profit line")
	root.size = Vector2i(1440,900); game.touch_controls.enabled = false
	game.touch_controls.resize(); await settle()
	for page in ["farmer", "menu", "accounts", "market", "grades", "practice", "sale_reveal"]:
		game.hud.show_panel(page, game.state); await settle()
		var scale: float = float(root.size.x) / game.hud.root.size.x
		check(game.hud._modal_card.size.x * scale >= (560 if page == "farmer" else 700), page + " uses computer width")
		check(Rect2(Vector2.ZERO, game.hud.root.size).encloses(game.hud._modal_card.get_global_rect()), page + " stays inside the computer screen")
		if page == "market": check(game.hud._refs.market_page.grid.columns == 5, "five seed cards spread across the computer")
		if page == "accounts": check(game.hud._refs.accounts_net.get_parent().get_parent() is HBoxContainer, "figures and records occupy separate desktop columns")
	game.hud.close_panel(); game.hud.show_panel("menu", farm); await settle()
	game.hud._body.find_child("MenuTile_save_page", true, false).pressed.emit(); await settle()
	check(game.hud._panel_kind == "save_page", "Menu Save opens save and new-farm choices")
	game.hud._body.find_children("*", "Button", true, false).filter(func(b):return b.get_meta("hud_action", "") == "request_reset")[0].pressed.emit(); await settle()
	check(game.hud._reset_pending and game.hud._body.find_children("*", "Label", true, false).any(func(l):return l.text == "Plant a new farm?"), "New Farm reaches its confirmation when leaving Save")
	game.hud._act("cancel_reset"); await settle()
	check(not game.hud._reset_pending and game.hud._body.find_child("MenuTile_save_page", true, false) != null, "cancel keeps the old farm")
	game.hud._act("save_page"); game.hud._act("request_reset"); await settle()
	game.hud._body.find_children("*", "Button", true, false).filter(func(b):return b.get_meta("hud_action", "") == "reset")[0].pressed.emit(); await settle()
	check(farm.season_clock.year == 1 and farm.season_clock.season == 0 and farm.coins == farm.Ledger.STARTING_CASH and not farm.run_over, "confirmed New Farm creates a playable fresh Spring")
	check(farm.clothing_unlocked.size() == 3, "New Farm keeps earned clothing")
	game.queue_free(); await process_frame
	print("UI KIT: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
