extends SceneTree
## Shared materials retain their edge at phone scale; objects remain recognisable.
const Cozy = preload("res://scripts/cozy_ui.gd")
const Place = preload("res://scripts/place_ui.gd")
var checks := 0
var failures := 0
var game

func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + words)
func settle() -> void:
	for frame in range(12): await process_frame
	if is_instance_valid(game): game.hud.advance_panel_entrance(game.hud.ACCOUNTS_ENTRANCE_SECONDS)
func cream_layers(control: Control) -> int:
	var count := 0
	var node: Node = control
	while node != null:
		if node is PanelContainer:
			var style: StyleBox = node.get_theme_stylebox("panel")
			var fill: Color = style.get_meta("surface_fill", Color.TRANSPARENT)
			if fill.a > .8 and fill.v > .75 and fill.s < .3: count += 1
			elif fill.a > .8: break
		node = node.get_parent()
	return count
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var paper: StyleBoxTexture = Cozy.paper()
	check(paper.texture.get_size() == Vector2(64, 64), "panel grain uses one 64 by 64 swatch")
	check(paper.texture == Cozy.paper().texture, "identical surfaces reuse the cached texture")
	check(paper.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE and paper.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "grain tiles rather than stretching across large panels")
	check(paper.get_texture_margin(SIDE_LEFT) == 8 and paper.get_texture_margin(SIDE_BOTTOM) == 8, "nine-slice preserves the edge")
	var pixels: Image = paper.texture.get_image()
	check(pixels.get_pixel(1, 30).v < pixels.get_pixel(2, 30).v, "darker one-pixel inner edge borders the paper")
	check(pixels.get_pixel(20, 20) != pixels.get_pixel(21, 20), "paper has visible grain instead of a flat fill")
	check(Place.skin().texture == Cozy.paper(Place.PAPER, 12, 8, Color("d7c9aa")).texture, "place pages share the same panel material")
	check(Cozy.modal().get_meta("surface_fill") == Cozy.INK, "large panel frames use ink")
	var button := Button.new(); Place.pill(button, Cozy.GREEN)
	check(button.get_theme_stylebox("normal") is StyleBoxFlat, "small action buttons retain simple clear states")
	button.free()
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(); game.set_process(false); game.hud.set_process(false)
	game.state.tutorial_progress.completed = true; game.hud.set_tutorial({})
	game.state.season_clock.year = 3; game.state.coins = 80000
	root.min_size = Vector2i.ZERO; root.size = Vector2i(390, 844)
	game.touch_controls.enabled = true; game.touch_controls._build_touch_sheets()
	await settle()
	for kind in ["market", "sell_potatoes", "barn", "tools", "quests", "contracts", "climate", "accounts", "pause", "activities"]:
		game.state.season_clock.season = 3 if kind in ["accounts", "climate"] else 0
		game.hud.show_panel(kind, game.state); await settle(); game.touch_controls.fit_modal(); await settle()
		check(game.hud._modal_card.get_theme_stylebox("panel") is StyleBoxTexture, kind + " frame uses the shared material")
		var nested_cream := false
		for panel in game.hud._modal_card.find_children("*", "PanelContainer", true, false):
			if panel.is_visible_in_tree() and cream_layers(panel) >= 3: nested_cream = true
		check(not nested_cream, kind + " has no three stacked cream panels")
		if kind == "market":
			for crop in game.hud._refs.market_page.crops:
				var found := false
				for item in game.hud._refs.market_page.seed_cards[crop].find_children("*", "Control", true, false):
					if item.get_script() == preload("res://scripts/item_icon.gd") and item.item.get("crop") == crop: found = true
				check(found, crop + " seed packet has its own crop drawing")
		elif kind == "barn": check(game.hud._body.find_child("BarnDrawing", true, false) != null, "barn tally has a recognisable barn drawing")
		elif kind == "climate": check(game.hud._body.find_child("ForecastDrawing", true, false) != null, "forecast has its own weather drawing")
		elif kind == "activities":
			for words in ["Add a duck", "Patrol speed", "0 / 2 ducks", "Whole flock"]:
				var labels: Array = game.hud._body.find_children("*", "Label", true, false).filter(func(label): return label.text == words)
				check(labels.size() == 1 and labels[0].get_theme_color("font_color").get_luminance() > .7, "duck offer text reads on timber: " + words)
		elif kind == "pause":
			check(game.hud._modal_title.get_theme_color("font_color").get_luminance() > .7, "farm title stays light against its ink frame")
			var menu_labels := 0
			for tile in game.hud._body.find_children("*", "Button", true, false):
				if not tile.is_visible_in_tree(): continue
				for label in tile.find_children("*", "Label", true, false):
					if not label.is_visible_in_tree(): continue
					menu_labels += 1
					check(label.get_theme_color("font_color").get_luminance() < .3, "farm menu action remains dark on its paper button: " + label.text)
			check(menu_labels >= 10, "farm-menu contrast check covers every illustrated destination")
			var badge: Label = game.hud._badge("Ready", "ready")
			game.hud._body.add_child(badge)
			var badge_ink: Color = badge.get_theme_color("font_color")
			game.hud._surface_text(game.hud._modal_card)
			check(badge.get_theme_color("font_color") == badge_ink, "paper badge keeps its readable ink inside an ink panel")
			game.hud._body.remove_child(badge); badge.queue_free()
			if "--capture" in OS.get_cmdline_user_args():
				for dimensions in [Vector2i(390, 844), Vector2i(1280, 800)]:
					root.size = dimensions; game.touch_controls.enabled = dimensions.x < 600
					game.hud.show_panel("pause", game.state); await settle(); game.touch_controls.fit_modal(); await settle()
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://artifacts/surfaces-farm-menu-%d.png" % dimensions.x)
	game.queue_free(); await settle()
	print("SURFACES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
