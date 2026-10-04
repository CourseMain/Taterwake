extends Node
## Matched screenshots in a disposable export. No player save is read or written.
## window.surfaceQA("title" | "accounts" | "market" | "climate" | "npc:nell"
##   | "run_summary" | "foreclosure" | "scroll:end" | "scroll:top" | "status").
## Await window.surfaceReport.ready before capturing the browser viewport.
const PAGES: Array[String] = ["title", "accounts", "market", "climate", "npc", "run_summary", "foreclosure", "barn", "tools", "quests", "loss_notices", "contracts", "sell_potatoes", "menu", "pause", "graphics", "debug", "help", "activities", "duck_patrol", "dex", "front_page"]
var game
var callback
var request := 0
var current_page := ""
var is_ready := false
var base_snapshot: Dictionary
var last_report: Dictionary

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	assert(game.test_mode, "Export this fixture with tools/export_browser_benchmark.py or --integration-test.")
	game.set_process(false)
	game.state.boundary_save_path = ""
	game.state.rng.seed = 712804
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	game.hud.set_tutorial({})
	game.state.season_clock.year = 3
	game.state.coins = 80000
	for crop: String in game.state.CROP_IDS: game.state.storage[crop] = game.state.Stock.pile(12)
	game.state.ledger.post_fixed_costs(1)
	game.state.ledger.post_fixed_costs(2)
	game.state.ledger.post(3, 0, "sales", "Table Russet · 12 t", 5184)
	game.state.ledger.post(3, 0, "seeds", "Russet seed", -3240)
	game.state.climate.data.outlook.records.append({"year":2, "season":1, "event":"storm", "severity":0.5})
	game.state.ClimateSystem.Protection.record(game.state, "autumn_cold", "russet", 3, 0.0, 1.0, "Harvest before Winter", "field", 2)
	base_snapshot = game.state._save_data()
	if OS.has_feature("web"):
		callback = JavaScriptBridge.create_callback(command)
		JavaScriptBridge.get_interface("window").surfaceQA = callback
	await _present("title", request)
	if "--surface-smoke" in OS.get_cmdline_user_args():
		var failures: int = 0 if is_ready and _page_visible() else 1
		for page: String in ["accounts", "market", "climate", "npc", "run_summary", "foreclosure", "title"]:
			request += 1
			await _present(page, request)
			if not is_ready or not _page_visible():
				failures += 1
				push_error("Surface did not become visible: " + page)
			else: print("SURFACE FIXTURE READY: " + page)
		print("SURFACE FIXTURE: 8 checks, %d failures" % failures)
		get_tree().quit(1 if failures else 0)

func _page_visible() -> bool:
	match current_page:
		"title": return game.title_active() if game.has_method("title_active") else game.year_intro.visible
		"npc": return game.conversation.visible
		"foreclosure": return game.hud._run_end.visible
		_: return game.hud.is_panel_open() and game.hud._panel_kind == current_page

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.world): return
	if game.has_method("title_active") and game.title_active():
		game._process(delta)
	else:
		# Freeze only crop/calendar simulation. Clouds, windmill, potato farmer,
		# keepers, snow and the UI's own entrance animations remain live.
		game.world.animate(delta, false)
		game._update_accounts_camera(delta)
		game.seasonal_ambience.set_season(game.state.season_clock.season, game.state.run_over)

func command(args: Array) -> void:
	if args.is_empty(): return
	var action: String = str(args[0])
	if action == "status": _publish(); return
	if action.begins_with("scroll:"):
		_scroll(action.get_slice(":", 1))
		return
	var page: String = action.get_slice(":", 0)
	page = {"crop": "market", "crop_card": "market", "forecast": "climate"}.get(page, page)
	if page not in PAGES:
		last_report = {"ready": false, "error": "Unknown surface: " + page, "commands": PAGES}
		_publish_raw()
		return
	request += 1
	_present(page + (":" + action.get_slice(":", 1) if action.contains(":") else ""), request)

func _present(action: String, ticket: int) -> void:
	is_ready = false
	current_page = action.get_slice(":", 0)
	_publish()
	if game.has_method("title_active") and game.title_active(): game.title_scene.finish()
	game.year_intro.stop()
	game.conversation.finish()
	game.hud.close_panel()
	game.state.restore_snapshot(base_snapshot)
	game.state.set_tutorial_active(false)
	game.hud.set_tutorial({})
	game._cancel_walk()
	game._recenter_camera()
	game.world.camera.size = game._camera_home_size
	game.world.set_player_position(Vector3(0,0,9))
	game.state.climate.data.phase = "calm"
	game.state.climate.data.event = ""
	game.state.climate.data.timer = 0
	game.state.season_clock.seconds = 75
	if current_page in ["accounts", "climate", "run_summary", "foreclosure"]:
		game.state.season_clock.season = 3
		game.state.season_clock.seconds = 0
		game.state.ledger.post_fixed_costs(3)
		for plot: Dictionary in game.state.plots:
			game.state._clear_crop(plot)
			plot.tilled = false
			plot.winter_ice = true
	if current_page == "run_summary":
		game.state.season_clock.year = 10
		game.state.season_clock.seconds = game.state.SeasonClock.SEASON_SECONDS
		for year in range(4,11): game.state.ledger.post_fixed_costs(year)
		game.state.coins = 80000
		game.state.run_outcome = "completed"
		game.state.run_over = true
	elif current_page == "foreclosure":
		game.state.coins = -210000
		game.state.run_outcome = "foreclosed"
		game.state.run_over = true
		game.state.climate.capture_collapse(game.state)
	game._on_state_changed()
	game.world.set_calendar(game.state.season_clock.year, game.state.season_clock.season, game.state.calendar_light_seconds(), game.state.climate.data.outlook.signal)
	game.hud.close_panel()
	game.hud.root.show()
	game.touch_controls.root.show()
	game.hud._climate_alert.dismiss()
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	match current_page:
		"title":
			if game.has_method("_show_title"):
				game._show_title(true)
			else:
				# Tag k actually opened on Iris's annual page, not its unused
				# "Welcome to Taterland" modal-title initializer.
				_open_front_page()
		"front_page": _open_front_page()
		"npc":
			var person: String = action.get_slice(":",1) if action.contains(":") else "nell"
			if person not in game.state.NpcRoster.PEOPLE: person = "nell"
			game._start_conversation(person, str(game.state.NpcRoster.PEOPLE[person].service))
			game.farm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		"foreclosure": game.hud.update_state(game.state)
		_: game.hud.show_panel(current_page, game.state)
	game.touch_controls.resize()
	for frame in range(12): await get_tree().process_frame
	while game.hud.accounts_building:
		await get_tree().process_frame
		if ticket != request: return
	if ticket != request: return
	# Let native transitions and any cold fonts/portraits finish normally.
	await get_tree().create_timer(1.25).timeout
	if ticket != request: return
	game.touch_controls.fit_modal()
	for frame in range(3): await get_tree().process_frame
	is_ready = true
	_publish()

func _open_front_page() -> void:
	game.year_intro.present(game.state)
	game.year_intro._process(1.0)
	game.year_intro.set_process(false)

func _scroll(where: String) -> void:
	is_ready = false
	_publish()
	var scroll: ScrollContainer = game.hud._body.get_parent()
	if current_page == "foreclosure": scroll = game.hud._run_end._scroll
	elif current_page in ["front_page", "title"] and game.year_intro.visible:
		var candidates: Array[Node] = game.year_intro.find_children("*", "ScrollContainer", true, false)
		if not candidates.is_empty(): scroll = candidates.front()
	scroll.scroll_vertical = 100000 if where == "end" else 0
	for frame in range(4): await get_tree().process_frame
	is_ready = true
	_publish()

func _rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _publish() -> void:
	if not is_instance_valid(game): return
	var modal: Control = game.hud._modal_card
	var scroll: ScrollContainer = game.hud._body.get_parent()
	last_report = {"ready": is_ready, "page": current_page, "request": request,
		"fixture": "surfaces", "version": ProjectSettings.get_setting("application/config/version"),
		"year": game.state.season_clock.year, "season": game.state.season_clock.NAMES[game.state.season_clock.season],
		"logical_size": [game.hud.root.size.x, game.hud.root.size.y],
		"backing_size": [get_tree().root.size.x, get_tree().root.size.y], "touch": game.touch_controls.enabled,
		"modal": _rect(modal), "scroll": _rect(scroll), "scroll_top": scroll.scroll_vertical,
		"content_fits_width": game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 1,
		"world_animation_time": game.world._time, "simulation_seconds": game.state.elapsed,
		"title_available": game.has_method("_show_title"), "buttons": [], "labels": [], "surfaces": []}
	_collect(get_tree().root)
	_publish_raw()

func _collect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		var visible: bool = rect.intersects(get_viewport().get_visible_rect())
		var ancestor: Node = node.get_parent()
		while visible and ancestor != null:
			if ancestor is Control and ancestor.clip_contents: visible = rect.intersects(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if visible:
			if node is Button:
				last_report.buttons.append({"text": node.text, "action": node.get_meta("action", node.get_meta("hud_action", "")), "rect": _rect(node), "disabled": node.disabled})
			elif (node is Label or node is RichTextLabel) and not node.text.is_empty():
				last_report.labels.append({"text": node.text, "rect": _rect(node)})
			if node is PanelContainer or node is Panel:
				var style: StyleBox = node.get_theme_stylebox("panel")
				var fill := Color.TRANSPARENT
				if style is StyleBoxFlat: fill = style.bg_color
				elif style.has_meta("surface_fill"): fill = style.get_meta("surface_fill")
				last_report.surfaces.append({"name": node.name, "rect": _rect(node), "type": style.get_class(), "fill": fill.to_html()})
	for child in node.get_children(): _collect(child)

func _publish_raw() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.surfaceReport=" + JSON.stringify(last_report), true)
