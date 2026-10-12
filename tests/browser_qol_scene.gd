extends "res://tests/browser_surfaces_scene.gd"
## Segment 21j review fixture. No normal save is read or written.

func command(args: Array) -> void:
	if not args.is_empty() and str(args[0]).begins_with("latency:page:"):
		_latency_prepare(str(args[0]).trim_prefix("latency:page:"))
	elif not args.is_empty() and str(args[0]).begins_with("latency:target:"):
		_latency_target(int(str(args[0]).trim_prefix("latency:target:")))
	elif not args.is_empty() and str(args[0]).begins_with("qol_"):
		request += 1
		_present_qol(str(args[0]), request)
	else: super.command(args)

func _present_qol(action: String, ticket: int) -> void:
	latency_mode = false
	live_player = false
	var view: String = action.get_slice(":", 0)
	var base: String = {"qol_winter":"play_winter", "qol_grades":"grades", "qol_accounts":"accounts", "qol_seed":"market", "qol_guide":"guide_welcome", "qol_refused":"guide_grow", "qol_undo":"market_sell", "qol_sell":"market_sell", "qol_buyfeedback":"market"}.get(view, "play_spring")
	await super._present(base, ticket)
	if ticket != request: return
	is_ready = false
	current_page = view
	if view in ["qol_home", "qol_low", "qol_quests", "qol_rent", "qol_locked"]:
		var season: int = int(action.get_slice(":", 1)) if action.contains(":") else 0
		game.state.season_clock.season = season
		game.world.set_calendar(3, season, 75)
		game.world._animate_sun(3.4)
		var target: Vector3 = {"qol_home":Vector3(-1.8,0,6.3), "qol_low":Vector3(17.2,0,17.5), "qol_quests":Vector3(-14.7,1.3,9.9), "qol_rent":Vector3(14.5,1,19.7), "qol_locked":Vector3(17.2,0,17.5)}[view]
		var camera: Camera3D = game.world.camera
		camera.size = {"qol_home":20.0, "qol_low":20.0, "qol_quests":12.0, "qol_rent":8.0, "qol_locked":28.0}[view]
		camera.position = target + camera.basis.z * 260.0
		game.world.fit_camera_depth()
		game.hud.root.visible = view == "qol_locked"
		game.touch_controls.root.hide()
		if view == "qol_locked": game.hud.show_farm_hint(preload("res://scripts/farm_advice.gd").locked(game.state, 24))
	if view == "qol_hotbar": game.hud.set_tool("harvest")
	if view == "qol_player":
		game.world.set_player_position(Vector3(0,0,9))
		game.world.fit_overview(false)
		game._reset_camera_view(true)
		game._update_player_camera(false)
		live_player = true
	if view == "qol_refused":
		game.state.tutorial_progress.step = 4
		game.state.tutorial_progress.plot = 5
		game.state.plots[5].merge({"stage":1, "crop":"russet", "tilled":true, "watered":false},true)
		game.state.climate.data.operations.supply.can = 0
		game.tutorial._enter_step()
		if game.hud.has_method("show_refusal"): game.hud.last_tap = game.touch_controls.use_button
		game.perform_plot(5,"water")
	if view == "qol_undo":
		var page = game.hud._refs.market_page
		page.select_variety("russet","Table")
		page.quantity.set_value_no_signal(1)
		page._sell()
	if view == "qol_buyfeedback":
		game.state.buy_seeds("russet",1)
	if view == "qol_accounts":
		var scroll: ScrollContainer = game.hud._body.get_parent()
		scroll.scroll_vertical = 100000
	for frame in range(8): await get_tree().process_frame
	is_ready = true
	_publish()

func _publish() -> void:
	super._publish()
	last_report.latency_buttons = []
	for index in range(latency_buttons.size()):
		var button: Button = latency_buttons[index]
		if is_instance_valid(button):
			last_report.latency_buttons.append({"index":index,"text":button.text,"action":button.get_meta("action",""),"rect":_latency_rect(button),"disabled":button.disabled})
	last_report.latency_armed = _latency_rect(armed) if is_instance_valid(armed) else []
	last_report.hotbar = _rect(game.hud._hotbar)
	last_report.hotbar_caption = _rect(game.hud._tool_caption)
	var body_screen: Vector2 = game.world.camera.unproject_position(game.world.player.global_position + Vector3.UP * game.world.FarmerAvatar.BODY_CENTER)
	last_report.player_camera = {"player":[game.world.player.position.x,game.world.player.position.y,game.world.player.position.z],"body_screen":[body_screen.x,body_screen.y],"viewport":[game.farm_viewport.size.x,game.farm_viewport.size.y],"size":game.world.camera.size}
	last_report.sell_rows = []
	if game.hud._refs.has("market_page") and game.hud._refs.market_page.selling:
		var rows = game.hud._refs.market_page.get("sale_rows")
		if rows is Dictionary:
			for entry in rows.values():
				if entry.has("sales"): last_report.sell_rows.append({"rect":_rect(entry.card),"graph":_rect(entry.history),"buttons":[_rect(entry.sales[1]),_rect(entry.sales[5])]})
	if not is_instance_valid(game): return
	last_report.fixture = "qol"
	last_report.quests = []
	var board: Node3D = game.world.find_child("FarmingQuestBoard", true, false)
	if board:
		for x: float in [-1.085, 0.0, 1.085]:
			for y: float in [0.94, 1.53, 2.12]:
				var point: Vector3 = board.to_global(Vector3(x,y,.16))
				var projected: Vector2 = game.world.camera.unproject_position(point)
				last_report.quests.append([projected.x,projected.y])
	_publish_raw()

var latency_buttons: Array[Button] = []
var latency_mode: bool = false
var live_player: bool = false
var armed: Button
var tap_start: float = -1
var visual_start: float = -1
var baseline_scale: Vector2
var baseline_rotation: float
var baseline_pressed: bool
var baseline_text: String

func _latency_prepare(view: String) -> void:
	live_player = false
	request += 1
	var ticket: int = request
	latency_mode = false
	armed = null
	for dialog in game.hud.root.find_children("*","AcceptDialog",true,false):
		dialog.hide(); dialog.queue_free()
	game.touch_controls.drawer.hide()
	if is_instance_valid(game.epilogue_screen): game._close_epilogue(false)
	var base: String = view.get_slice("/",0)
	if base == "tool_tiles": base = "play_spring"
	if base == "guide": base = "guide_welcome"
	if base == "market_undo": base = "market_sell"
	if base == "reset_confirm": base = "save_page"
	if base == "epilogue": base = "run_summary"
	if base == "farm_tip": base = "help"
	if base == "field_notes": base = "market_sell"
	if base == "debug_locked": base = "debug"
	game.hud._debug_unlocked = view == "debug"
	await super._present(base,ticket)
	is_ready = false
	if view == "reset_confirm": game.hud._act("request_reset")
	if view == "farm_tip":
		game.state.farm_help.enable()
		game.hud._opened_farm_tip = game.state.farm_help.tip(game.state)
		game.hud.show_panel("farm_tip",game.state)
	if view == "field_notes":
		for button in game.hud._modal_card.find_children("*","Button",true,false):
			if button.text == "?": button.pressed.emit(); break
	if view.begins_with("npc:") and view.contains("/"):
		game.conversation.show_page(view.get_slice("/",1))
		game.conversation.reveal()
	if view == "epilogue":
		game.epilogue_result = {"outcome":"Holding on", "projects":game.state.climate.data.projects.duplicate(true), "records":[], "headlines":[], "verdicts":[], "farm_value":0}
		game._show_epilogue()
		game.epilogue_screen.finish_reveal()
	if view.begins_with("guide/"):
		game.state.tutorial_progress.step = int(view.get_slice("/",1))
		game.tutorial._enter_step()
	if view.begins_with("market_sell/"):
		game.hud._refs.market_page.select_variety(view.get_slice("/",1))
	if view == "market_undo":
		var page = game.hud._refs.market_page
		page.select_variety("russet","Table")
		page.quantity.set_value_no_signal(1)
		page._sell()
	if view == "tool_tiles": game.touch_controls.open_drawer("tools")
	# Include controls inside every expandable card, not just its closed header.
	for key in game.hud._refs.keys():
		if str(key).ends_with(":toggle"):
			var section: String = str(key).trim_suffix(":toggle")
			if game.hud._refs.has(section) and not game.hud._refs[section].visible:
				game.hud._act("toggle_details:" + section)
	preload("res://scripts/sound_mix.gd").quieter = false
	latency_mode = true
	game.seasonal_ambience.set_process(false)
	game.climate_audio.set_process(false)
	_silence_beds(game)
	game.touch_controls.fit_modal()
	for frame in range(8): await get_tree().process_frame
	latency_buttons.clear()
	var roots: Array = [game.hud._modal_card] if game.hud.is_panel_open() else [game.hud._tutorial_card]
	if view == "tool_tiles": roots = [game.touch_controls.drawer]
	if view.begins_with("npc"): roots = [game.conversation]
	if view == "epilogue": roots = [game.epilogue_screen]
	if view == "foreclosure": roots = [game.hud._run_end]
	if view == "field_notes": roots = game.hud.root.find_children("*","AcceptDialog",true,false)
	if view == "title": roots = [game.title_scene]
	if view == "front_page": roots = [game.year_intro]
	for branch in roots:
		if branch is AcceptDialog and branch.visible: latency_buttons.append(branch.get_ok_button())
		else: _latency_collect(branch)
	for button in latency_buttons:
		button.gui_input.connect(func(event):
			if button == armed and (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed):
				if tap_start < 0:
					JavaScriptBridge.eval("window.qolSound=" + JSON.stringify({"registered":button.has_meta("tap_feedback"),"played":game.feedback_audio.played_count,"voices":game.feedback_audio.voices.size(),"muted":AudioServer.is_bus_mute(0)}),true)
					tap_start = float(JavaScriptBridge.eval("performance.now()",true))
		)
	if not RenderingServer.frame_post_draw.is_connected(_latency_paint): RenderingServer.frame_post_draw.connect(_latency_paint)
	current_page = "latency:" + view
	is_ready = true
	_publish()

func _silence_beds(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _silence_beds(child)

func _latency_collect(node: Node) -> void:
	if node is Button and node.is_visible_in_tree(): latency_buttons.append(node)
	for child in node.get_children(): _latency_collect(child)

func _latency_target(index: int) -> void:
	armed = latency_buttons[index]
	is_ready = false
	var parent: Node = armed.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(armed)
		parent = parent.get_parent()
	for frame in range(6): await get_tree().process_frame
	tap_start = -1; visual_start = -1
	baseline_scale = armed.scale; baseline_rotation = armed.rotation; baseline_pressed = armed.is_pressed(); baseline_text = armed.text
	JavaScriptBridge.eval("window.qolTap=null",true)
	is_ready = true
	_publish()

func _latency_paint() -> void:
	if tap_start < 0 or visual_start >= 0: return
	if not is_instance_valid(armed) or not armed.is_visible_in_tree() or armed.scale != baseline_scale or not is_equal_approx(armed.rotation,baseline_rotation) or armed.is_pressed() != baseline_pressed or armed.text != baseline_text:
		visual_start = float(JavaScriptBridge.eval("performance.now()",true))
		JavaScriptBridge.eval("window.qolTap=" + JSON.stringify({"input":tap_start,"paint":visual_start,"visual_ms":visual_start-tap_start}),true)

func _process(delta: float) -> void:
	if live_player:
		game._process(delta)
	elif latency_mode:
		game.hud._process(delta)
		game._update_accounts_camera(delta)
	else: super._process(delta)

func _latency_rect(button: Control) -> Array:
	var rect: Rect2 = button.get_global_rect()
	if button.get_window() != get_tree().root: rect.position += Vector2(button.get_window().position)
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
