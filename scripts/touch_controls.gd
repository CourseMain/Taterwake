extends CanvasLayer
## Touch owns fingers, never keyboard actions. A pinch is never a farm tap.
const TOOL_NAMES := {"hoe": "Hoe", "plant": "Seeds", "water": "Water", "harvest": "Harvest", "pest": "Sprayer"}
var game
var enabled: bool = false
var movement := Vector2.ZERO
var sprinting: bool = false
var stick_finger: int = -1
var button_fingers: Dictionary = {}
var world_fingers: Dictionary = {}
var tap_origins: Dictionary = {}
var gesture_used: bool = false
var pinch_distance: float = 0.0
var root: Control
var stick: Control
var knob: Control
var use_button: Button
var tools_button: Button
var menu_button: Button
var sell_button: Button
var status: Label
var drawer: PanelContainer
var drawer_body: VBoxContainer
var drawer_kind: String = ""
var fullscreen: Button
var guide_button: Button
var guide_open: bool = false
var last_size := Vector2.ZERO
var _clock: float = 0.0
var _blocked_before: bool = false
var equipment_sheet: ScrollContainer
var guide_sheet: ScrollContainer

func _ready() -> void:
	layer = 30
	process_priority = 100
	enabled = DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = enabled or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0", true))
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = game.hud.root.theme
	add_child(root)
	stick = Panel.new()
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.add_theme_stylebox_override("panel", skin(Color(0.08, 0.2, 0.16, 0.55), 100))
	root.add_child(stick)
	knob = Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", skin(Color(0.95, 0.88, 0.66, 0.8), 100))
	stick.add_child(knob)
	use_button = button("Use Hoe", func(): game._interact_nearby())
	tools_button = button("Tools", func(): open_drawer("tools"))
	menu_button = button("Menu", func(): game.hud._act("menu"))
	sell_button = button("Sell", func(): game.hud._act("quick_sell"))
	fullscreen = button("Full screen", toggle_fullscreen)
	guide_button = button("Show guide", func(): guide_open = not guide_open)
	guide_button.hide()
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color("fff3cf"))
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_stylebox_override("normal", skin(Color(0.07, 0.18, 0.14, 0.86), 10))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	drawer = PanelContainer.new()
	drawer.add_theme_stylebox_override("panel", skin(Color("193c33"), 16))
	root.add_child(drawer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.add_child(scroll)
	drawer_body = VBoxContainer.new()
	drawer_body.add_theme_constant_override("separation", 8)
	drawer_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(drawer_body)
	drawer.hide()
	if enabled:
		equipment_sheet = ScrollContainer.new()
		equipment_sheet.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		game.hud.root.add_child(equipment_sheet)
		game.hud._climate_console.reparent(equipment_sheet)
		game.hud._climate_console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipment_sheet.hide()
		guide_sheet = ScrollContainer.new()
		guide_sheet.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		guide_sheet.z_index = 30
		game.hud.root.add_child(guide_sheet)
		game.hud._tutorial_card.reparent(guide_sheet)
		game.hud._tutorial_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guide_sheet.hide()
	get_tree().root.size_changed.connect(resize)
	resize()
	if not enabled:
		for item in [stick, use_button, tools_button, menu_button, sell_button, status]: item.hide()
	# Browser shell owns its button so fullscreen is requested in a trusted DOM gesture.
	fullscreen.visible = not OS.has_feature("web")
	get_tree().root.focus_exited.connect(release_all)

func skin(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func button(caption: String, callback: Callable, parent: Node = null) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size = Vector2(68, 68)
	result.add_theme_font_size_override("font_size", 22)
	result.add_theme_color_override("font_color", Color("fff3cf"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		result.add_theme_stylebox_override(state, skin(Color("426c53") if state == "pressed" else Color("193c33"), 12))
	result.focus_mode = Control.FOCUS_NONE
	(parent if parent != null else root).add_child(result)
	result.pressed.connect(callback)
	return result

func resize() -> void:
	release_all()
	if enabled:
		var physical := Vector2(get_tree().root.size)
		var short_edge: float = minf(physical.x, physical.y)
		if OS.has_feature("web"):
			short_edge = float(JavaScriptBridge.eval("Math.min(document.getElementById('canvas').clientWidth, document.getElementById('canvas').clientHeight)", true))
		# Phones get 44px targets; tablets keep more farm visible with 68px targets.
		var logical := physical * (clampf(short_edge, 600, 900) / minf(physical.x, physical.y))
		get_tree().root.content_scale_size = Vector2i(logical)
	last_size = get_viewport().get_visible_rect().size
	var w := last_size.x
	var h := last_size.y
	if enabled: game.hud._climate_console.compact_layout = w > h
	place(stick, Rect2(22, h - 190, 166, 166))
	place(knob, Rect2(51, 51, 64, 64))
	place(use_button, Rect2(w - 210, h - 100, 188, 78))
	place(tools_button, Rect2(w - 210, h - 178, 188, 68))
	place(menu_button, Rect2(w - 134, 16, 112, 68))
	place(sell_button, Rect2(w - 134, 94, 112, 68))
	place(status, Rect2(18, 16, minf(w - 172, 500), 72))
	place(fullscreen, Rect2(w - 280, 16, 136, 44 if not enabled else 68))
	place(guide_button, Rect2(18, 16, 204, 68))
	place(drawer, Rect2(maxf(16, w - 430), 92, minf(w - 32, 408), maxf(180, h - 280)))
	if enabled: fit_modal()

func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

func fit_modal() -> void:
	if not enabled or not is_instance_valid(game.hud._modal_card): return
	var hud = game.hud
	var view := get_viewport().get_visible_rect().size
	var width := minf(940, view.x - 24)
	# Existing game actions and transaction checks are shared with desktop.
	adapt(hud._body, width - 64, true)
	adapt(hud._modal_fixed, width - 64, true)
	adapt(hud._modal_card.get_child(0).get_child(0), width - 64, false)
	hud._modal_subtitle.hide()
	hud._modal_title.add_theme_font_size_override("font_size", 28)
	place(hud._modal_card, Rect2((view.x - width) / 2, 100, width, view.y - 112))
	# Filters and stake choices must also scroll on a short landscape phone.
	if hud._modal_fixed.get_parent() != hud._body:
		hud._modal_fixed.reparent(hud._body)
		hud._body.move_child(hud._modal_fixed, 0)

func adapt(node: Node, available: float, stack: bool) -> void:
	if node is Control:
		if not node.has_meta("touch_min"):
			node.set_meta("touch_min", node.custom_minimum_size)
		var original: Vector2 = node.get_meta("touch_min")
		node.custom_minimum_size.x = minf(original.x, available)
		if node is Label or node is Button or node is LineEdit:
			if not node.has_meta("touch_font"): node.set_meta("touch_font", node.get_theme_font_size("font_size"))
			node.add_theme_font_size_override("font_size", maxi(22, int(node.get_meta("touch_font"))))
		if node is Label:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if node is Button:
			node.custom_minimum_size.x = maxf(68, node.custom_minimum_size.x)
			node.custom_minimum_size.y = maxf(original.y, 68)
			if node is OptionButton:
				node.fit_to_longest_item = false
				node.get_popup().add_theme_font_size_override("font_size", 22)
				node.get_popup().add_theme_constant_override("v_separation", 38)
			else: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node is LineEdit: node.custom_minimum_size.y = maxf(original.y, 68)
		if node is GridContainer:
			if not node.has_meta("touch_columns"): node.set_meta("touch_columns", node.columns)
			node.columns = 1 if available < 650 else mini(2, int(node.get_meta("touch_columns")))
	for child in node.get_children():
		# Decorative contents of buttons keep their icon/label composition.
		adapt(child, available - (32 if node is PanelContainer else 0), stack and not node is Button)
	if node.get_class() == "BoxContainer" and stack:
		var row_width: float = 0
		for child in node.get_children():
			if child is Control and child.visible:
				row_width += child.get_combined_minimum_size().x + node.get_theme_constant("separation")
		node.vertical = available < 650 or row_width > available

func _process(delta: float) -> void:
	if not enabled: return
	_clock += delta
	var hud = game.hud
	var blocked: bool = hud.is_panel_open() or game.state.run_over or game.state.rocket_pending or game.state.climate.data.intro_pending or hud.is_roll_animating()
	if blocked and not _blocked_before: release_all()
	if blocked != _blocked_before and OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.classList.toggle('menu-open', %s)" % ("true" if blocked else "false"), true)
	_blocked_before = blocked
	guide_button.visible = hud.is_panel_open() and not hud._tutorial.is_empty()
	guide_button.text = "Hide guide" if guide_open else "Show guide"
	if not hud._tutorial.is_empty(): hud._tutorial_card.visible = not hud.is_panel_open() or guide_open
	else: guide_open = false
	for item in [stick, use_button, tools_button, menu_button, sell_button, status]: item.visible = not blocked
	sell_button.visible = not blocked and not hud._climate_console.visible and not drawer.visible
	if blocked:
		drawer.hide()
	# Desktop information is summarized in one small status strip on touch.
	for item in [hud._stats_card, hud._menu_button, hud._hotbar, hud._quick_sell, hud._crop_row, hud._tracked_box, hud._context_box, hud._blind_card, hud._export_box, hud._farm_help_card, hud._tutorial_pointer]: item.hide()
	if _clock >= 0.2:
		_clock = 0
		status.text = "%s · %s\n%s" % [hud._top.coins.text, game.state.selected_crop.capitalize(), hud._export_title.text if not game._tutorial_active() else "Drag to move · pinch to zoom"]
		var weather: Dictionary = game.state.climate_info()
		if weather.phase != "calm": status.text += "\n%s · %ds" % [weather.name, ceili(weather.timer)]
		elif game.state.blind_info().due_in > 0: status.text += "\nTax %s · %ds" % [game.state.money(game.state.blind_info().tax, true), ceili(game.state.blind_info().due_in)]
		use_button.text = "Use " + TOOL_NAMES[game.selected_tool]
		if game.prize_target: use_button.text = "Grow giant"
		elif game.world.player.position.distance_to(game.world._climate_field.loop.tank_position() + Vector3(-0.4, 0, 2.3)) <= 2: use_button.text = "Refill can"
		elif game.world.player.position.distance_to(game.world.ferry_position()) <= 2: use_button.text = "Travel"
		sell_button.disabled = hud._quick_sell.disabled
		if hud.is_panel_open(): fit_modal()
		fit_auxiliary()
	knob.position = Vector2(51, 51) + movement * 46
	tools_button.text = TOOL_NAMES[game.selected_tool] + "  /  Tools"

func fit_auxiliary() -> void:
	var hud = game.hud
	var view := get_viewport().get_visible_rect().size
	var portrait := view.x < view.y
	equipment_sheet.visible = hud._climate_console.visible
	guide_sheet.visible = hud._tutorial_card.visible
	if hud._tutorial_card.visible:
		var width := minf(460, view.x - 172)
		adapt(hud._tutorial_card, width - 30, false)
		hud._tutorial_icon.hide()
		hud._tutorial_key.hide()
		hud._tutorial_body.add_theme_font_size_override("font_size", 21)
		for b in [hud._tutorial_next, hud._tutorial_skip]: b.custom_minimum_size.y = 68
		hud._tutorial_skip.custom_minimum_size.x = 68
		if not portrait: hud._tutorial_body.add_theme_font_size_override("font_size", 19)
		hud._tutorial_body.text = hud._tutorial_body.text.replace("Click", "Tap").replace("click", "tap").replace("WASD", "the stick").replace("arrow keys", "the stick")
		var top: float = maxf(104, status.get_global_rect().end.y + 12) if not hud.is_panel_open() else 104
		place(guide_sheet, Rect2(18, top, width, minf(view.y - top - 196, hud._tutorial_card.get_combined_minimum_size().y)))
	if hud._climate_console.visible:
		adapt(hud._climate_console, 380, false)
		if not portrait: hud._climate_console.story.hide()
		place(equipment_sheet, Rect2(view.x - 420, 174 if portrait else 92, 398, view.y - (380 if portrait else 280)))
	if hud._climate_alert.visible:
		var panel: Control = hud._climate_alert.panel
		var width := minf(700, view.x - 32)
		adapt(panel, width - 64, false)
		hud._climate_alert.title.add_theme_font_size_override("font_size", 32)
		place(panel, Rect2((view.x - width) / 2, 100, width, 0))
	for notice in [hud._toast_box, hud._purchase_box, hud._reward_box, hud._plot_action_box]:
		if notice.visible:
			place(notice, Rect2(18, 10 if hud.is_panel_open() else view.y - 290, minf(440, view.x - (220 if hud.is_panel_open() else 36)), 0))
	if game.state.run_over: adapt(hud._run_end, view.x - 72, true)

func open_drawer(kind: String) -> void:
	if drawer.visible and drawer_kind == kind:
		drawer.hide()
		return
	drawer_kind = kind
	for child in drawer_body.get_children():
		drawer_body.remove_child(child)
		child.queue_free()
	button("Close controls", func(): drawer.hide(), drawer_body)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	drawer_body.add_child(grid)
	for tool in TOOL_NAMES:
		if game._tutorial_active() and not game.tutorial.allows_tool(tool): continue
		var choice := button(TOOL_NAMES[tool], func(): game._select_tool(tool); open_seeds() if tool == "plant" else drawer.hide(), grid)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button("Crop", open_seeds, grid).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button("Zoom +", func(): game._zoom_by_log_amount(-0.18), drawer_body)
	button("Zoom −", func(): game._zoom_by_log_amount(0.18), drawer_body)
	button("Cancel task", func(): game._cancel_prize_target(); game._climate_action("cancel"); game._cancel_walk(); drawer.hide(), drawer_body)
	drawer.show()

func open_seeds() -> void:
	for child in drawer_body.get_children():
		drawer_body.remove_child(child)
		child.queue_free()
	button("Close seeds", func(): drawer.hide(), drawer_body)
	for crop in game.hud._market_crops():
		button("%s · %d seeds" % [crop.capitalize(), game.state.seed_inventory.get(crop, 0)], func(): game.hud._act("crop:" + crop); drawer.hide(), drawer_body)
	drawer.show()

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		if drawer.visible and drawer.get_global_rect().has_point(event.position): return
		# Overlay actions are dispatched by finger ID, allowing stick + action.
		for item in [use_button, tools_button, menu_button, sell_button, fullscreen, guide_button]:
			if item.is_visible_in_tree() and item.get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
				return
	if event is InputEventScreenTouch:
		if event.pressed and stick.visible and stick.get_global_rect().has_point(event.position) and stick_finger == -1:
			stick_finger = event.index
			move_stick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == stick_finger:
			stick_finger = -1
			movement = Vector2.ZERO
			sprinting = false
			get_viewport().set_input_as_handled()
		elif event.pressed:
			if drawer.visible and drawer.get_global_rect().has_point(event.position): return
			for item in [use_button, tools_button, menu_button, sell_button, fullscreen, guide_button]:
				if item.is_visible_in_tree() and not item.disabled and item.get_global_rect().has_point(event.position):
					button_fingers[event.index] = item
					get_viewport().set_input_as_handled()
					return
		elif button_fingers.has(event.index):
			var target: Button = button_fingers[event.index]
			button_fingers.erase(event.index)
			if not event.canceled and target.is_visible_in_tree() and not target.disabled and target.get_global_rect().has_point(event.position): target.pressed.emit()
			get_viewport().set_input_as_handled()
		elif world_fingers.has(event.index):
			# Releases may occur over a menu/control; always clear the finger.
			finish_world_touch(event)
			get_viewport().set_input_as_handled()
	if event is InputEventScreenDrag:
		if event.index == stick_finger:
			move_stick(event.position)
			get_viewport().set_input_as_handled()
		elif world_fingers.has(event.index):
			world_fingers[event.index] = event.position
			if event.position.distance_to(tap_origins[event.index]) > 16: gesture_used = true
			if world_fingers.size() == 2:
				var points: Array = world_fingers.values()
				var distance: float = points[0].distance_to(points[1])
				if pinch_distance > 1 and distance > 1: game._zoom_by_log_amount(log(pinch_distance / distance))
				pinch_distance = distance
			get_viewport().set_input_as_handled()

func move_stick(point: Vector2) -> void:
	var offset := (point - stick.get_global_rect().get_center()) / 65
	movement = offset.limit_length(1.0) if offset.length() > 0.16 else Vector2.ZERO
	sprinting = offset.length() >= 0.85

func world_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		world_fingers[event.index] = event.position
		tap_origins[event.index] = event.position
		if world_fingers.size() > 1:
			gesture_used = true
			var points: Array = world_fingers.values()
			pinch_distance = points[0].distance_to(points[1])
		get_viewport().set_input_as_handled()

func finish_world_touch(event: InputEventScreenTouch) -> void:
	var tap: bool = not event.canceled and not gesture_used and event.position.distance_to(tap_origins[event.index]) < 16
	world_fingers.erase(event.index)
	tap_origins.erase(event.index)
	if world_fingers.is_empty():
		gesture_used = false
		pinch_distance = 0
	if tap and not game.hud.is_panel_open() and not game.state.run_over and not game.state.rocket_pending and not game.state.climate.data.intro_pending:
		game._tap_world(event.position)

func release_all() -> void:
	movement = Vector2.ZERO
	sprinting = false
	stick_finger = -1
	button_fingers.clear()
	world_fingers.clear()
	tap_origins.clear()
	gesture_used = false
	pinch_distance = 0

func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.taterFullscreen && window.taterFullscreen()", true)
	else:
		var window := get_tree().root
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		fullscreen.text = "Exit full" if window.mode == Window.MODE_FULLSCREEN else "Full screen"
