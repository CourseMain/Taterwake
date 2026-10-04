class_name GameHUD
extends CanvasLayer
const Balance = preload("res://scripts/balance.gd")

signal action_requested(action: String)
signal panel_opened(kind: String)

class DebugMoneyInput extends LineEdit:
	# Range/SpinBox displays tiny positive values as zero. Keep the original
	# text until Apply, and normalize decimals before Godot's float conversion.
	var max_value: float = 100000
	var value: float:
		get:
			return float(read_number().get("value", 1.0))
		set(new_value):
			text = str(new_value)

	func get_line_edit() -> LineEdit:
		return self

	func read_number() -> Dictionary:
		return parse_number(text, max_value)

	static func parse_number(raw: String, maximum: float = 100000) -> Dictionary:
		var source: String = raw.strip_edges().to_lower()
		var pattern: RegEx = RegEx.new()
		pattern.compile("^[+]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:e[+-]?[0-9]+)?$")
		if source.length() > 256 or pattern.search(source) == null:
			return {"error": "Enter a number from 0 to 100000, such as 0.1 or 1e-20."}
		source = source.trim_prefix("+")
		var pieces: PackedStringArray = source.split("e")
		var decimal: PackedStringArray = pieces[0].split(".")
		var digits: String = decimal[0] + (decimal[1] if decimal.size() > 1 else "")
		var first: int = 0
		while first < digits.length() and digits[first] == "0":
			first += 1
		if first == digits.length():
			return {"value": 0.0, "canonical": "0"}
		var explicit_exponent: float = float(pieces[1]) if pieces.size() > 1 else 0.0
		if not is_finite(explicit_exponent) or absf(explicit_exponent) > 1000:
			return {"error": "That multiplier is outside the supported range."}
		var exponent: int = decimal[0].length() - first - 1 + int(explicit_exponent)
		if exponent < -324:
			return {"error": "That positive multiplier is too small. Enter 0 explicitly to clear money."}
		if exponent > 308:
			return {"error": "The largest money multiplier is 100000."}
		var significant: String = digits.substr(first, 1) + "." + digits.substr(first + 1, 16)
		while significant.ends_with("0"):
			significant = significant.left(-1)
		significant = significant.trim_suffix(".")
		var canonical: String = significant + "e" + str(exponent)
		var parsed: float = float(canonical)
		if not is_finite(parsed) or parsed > maximum:
			return {"error": "The largest money multiplier is 100000."}
		if parsed <= 0.0:
			return {"error": "That positive multiplier is too small. Enter 0 explicitly to clear money."}
		return {"value": parsed, "canonical": canonical}

const MarketPages = preload("res://scripts/market_pages.gd")
const ShopPages = preload("res://scripts/shop_pages.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const Type = preload("res://scripts/ui_type.gd")
const UI_FONT = preload("res://assets/fonts/NunitoSans.ttf")
const UI_SYMBOLS = preload("res://assets/fonts/NotoSansSymbols.ttf")
const UI_SYMBOLS_2 = preload("res://assets/fonts/NotoSansSymbols2.ttf")
const INK: Color = Color("17382d")
const MUTED: Color = Color("667569")
const CREAM: Color = Color("fffbed")
const PAPER: Color = Color("f3efdf")
const GREEN: Color = Color("377858")
const GOLD: Color = Color("d9a948")
const CHERRY: Color = Color("bb654d")
const CropTable = preload("res://scripts/crop_table.gd")
const CROP_IDS: Array[String] = CropTable.IDS
const ALL_CROP_IDS: Array[String] = CropTable.IDS

const TOOL_COSTS: Dictionary = Balance.TOOL_COSTS
const TOOL_AREAS: Dictionary = {"hoe": ["1 tile", "3 tiles", "3 × 3 tiles", "5 × 5 tiles"], "water": ["1 tile", "3 × 3 tiles", "5 × 5 tiles", "7 × 7 tiles"], "harvest": ["1 tile", "one full row", "three full rows", "five full rows"]}
const PURCHASE_SECONDS: float = 3.2
const ACCOUNTS_ENTRANCE_SECONDS: float = 0.6
const PANEL_ENTRANCE_SECONDS: float = 0.42

var _conversation: Control
var root: Control
var _state: Node
var _plain_font: FontVariation = Type.face(Type.BODY, 400.0)
var _card_heading_font: FontVariation = Type.face(Type.SHOP, 600.0)
var _card_button_font: FontVariation = Type.face(Type.DISPLAY, 600.0)
var _paper_body_font: FontVariation = Type.face(Type.BODY, 600.0)
var _paper_heading_font: FontVariation = Type.face(Type.DISPLAY, 600.0)
var _ledger_font: FontVariation = Type.face(Type.BODY, 400.0)
var _font: Font
var _heading_font: Font
var _top: Dictionary = {}
var _crop_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _selected_tool: String = "hoe"
var _crop_detail: Label
var _context: Label
var _barn_full_alert: PanelContainer
var _barn_full_detail: Label
var _barn_full_sell: Button
var _purchase_box: PanelContainer
var _purchase_title: Label
var _purchase_detail: Label
var _purchase_bar: ProgressBar
var _purchase_remaining: float = 0.0
var _purchase_receipt: Dictionary = {}
var _purchase_layout_key: String = ""
var _toast_box: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _toast_layout_key: String = ""
var _reward_box: PanelContainer
var _reward_title: Label
var _reward_detail: Label
var _reward_rarity: Label
var _reward_timer: Timer
var _modal: Control
var _modal_title: Label
var _modal_subtitle: Label
var _body: VBoxContainer
var _modal_market_nav: HBoxContainer
var _modal_trade_footer: VBoxContainer
var _modal_fixed: VBoxContainer
var _panel_kind: String = ""
var accounts_building: bool = false
var _accounts_build_request: int = 0
var _displayed_calendar: String = ""
var _sell_crop: String = ""
var _refs: Dictionary = {}
var _reset_pending: bool = false
var _sidebar_box: PanelContainer
var _quest_button: Button
var _panel_crops: Array[String] = []
var _tool_caption: Label
var _context_box: PanelContainer
var _hover_context: String = ""
var _context_layout_key: String = ""
var _farm_hint: String = ""
var _farm_hint_remaining: float = 0.0
var _farm_busy_remaining: float = 0.0
var _play_band: PanelContainer
var _quick_sell: Button
var _modal_card: PanelContainer
var _crop_row: BoxContainer
var _crop_defs: Dictionary = {}
var _inventory_sections: Dictionary = {}
var _inventory_tab: String = "crops"
var _inventory_signature: String = ""
var _price_moves: Dictionary = {}
var _hud_clock: float = 0.0
var _farm_tip: Dictionary = {}
var _farm_help_card: PanelContainer
var _farm_help_action: Button
var _opened_farm_tip: Dictionary = {}
var _help_cooldown: float = 0.0
var _tutorial: Dictionary = {}
var _tutorial_card: PanelContainer
var _tutorial_forecaster: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_feedback: Label
var _tutorial_progress: Label
var _tutorial_next: Button
var _tutorial_skip: Button
var _tutorial_key: Label
var _tutorial_icon: Control
var _tutorial_meter: ProgressBar
var _tutorial_exit_box: VBoxContainer
var _tutorial_exit_pending: bool = false
var _tutorial_pointer: Control
var _stats_card: PanelContainer
var _menu_button: Button
var _hotbar: PanelContainer
var _debug_unlocked: bool = false
var _debug_time_multiplier: float = 1.0
var _debug_access_error: String = ""
var _graphics_quality: String = "balanced"
var _run_end: Control
var _run_end_title: Label
var _run_end_detail: Label
var _modal_fade: Tween
var _modal_motion: Control
var _modal_entrance_shield: Control
var _entrance_elapsed: float = ACCOUNTS_ENTRANCE_SECONDS
var _entrance_duration: float = ACCOUNTS_ENTRANCE_SECONDS
var _entrance_origin := Vector2.ZERO
var _panel_source: String = ""
var _panel_source_tick: int = 0
var _entrance_offset := Vector2.ZERO
var _entrance_request: int = 0
var _hurry_badge: PanelContainer
var hurry_active: bool = false
var _climate_console: PanelContainer
var _weather_button: Button
var _climate_alert: Control
var _climate_effect: Control
var _collapse_hidden: Array[CanvasItem] = []
var _panel_hidden: Array[CanvasItem] = []
var _season_strip: Control
var _season_jobs: PanelContainer
var last_screenshot_path: String = ""

func _process(delta: float) -> void:
	advance_panel_entrance(delta)
	_update_hurry_badge()
	_hud_clock += delta
	_help_cooldown = maxf(0.0, _help_cooldown - delta)
	_farm_hint_remaining = maxf(0.0, _farm_hint_remaining - delta)
	_farm_busy_remaining = maxf(0.0, _farm_busy_remaining - delta)
	_update_context()
	_update_farm_help()
	_season_jobs.refresh()
	if _purchase_remaining > 0.0:
		_layout_purchase()
		_purchase_remaining = maxf(0.0, _purchase_remaining - delta)
		_purchase_bar.value = _purchase_remaining
		if _purchase_remaining == 0.0:
			_purchase_box.hide()
			_purchase_receipt.clear()
	if not _tutorial.is_empty():
		_apply_tutorial_visibility()
		_update_tutorial_pointer()
		_sync_panel_chrome()
		return
	_sync_panel_chrome()

func _sync_panel_chrome() -> void:
	if not is_panel_open():
		for child in _panel_hidden:
			if is_instance_valid(child): child.show()
		_panel_hidden.clear()
		return
	for child in root.get_children():
		if not child is CanvasItem or child in [_modal, _run_end, _climate_effect, _tutorial_pointer, _purchase_box, _toast_box, _reward_box]: continue
		if child == _tutorial_card or (child is Control and child.is_ancestor_of(_tutorial_card)): continue
		if child.visible:
			if child not in _panel_hidden: _panel_hidden.append(child)
			child.hide()

func _refresh_seed_visibility() -> void:
	var showing: bool = _selected_tool == "plant" and not is_panel_open() and (_tutorial.is_empty() or "plant" in _tutorial.get("tools", []))
	if is_instance_valid(_crop_row):
		_crop_row.visible = showing
		var first_seed: bool = not _tutorial.is_empty() and "stock" not in _tutorial.get("features", [])
		_crop_row.anchor_left = 0.5 if first_seed else 0.0
		_crop_row.anchor_right = 0.5 if first_seed else 1.0
		_crop_row.offset_left = -150.0 if first_seed else 28.0
		_crop_row.offset_right = 150.0 if first_seed else -28.0
	if is_instance_valid(_context_box):
		_update_context()


func build_ui() -> void:
	if is_instance_valid(root):
		return
	layer = 10
	var body_font: FontVariation = FontVariation.new()
	body_font.base_font = UI_FONT
	body_font.fallbacks = [Type.SPUDION, UI_SYMBOLS, UI_SYMBOLS_2]
	var weight_axis: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	body_font.variation_opentype = {weight_axis: 400.0}
	_font = body_font
	var title_font: FontVariation = FontVariation.new()
	title_font.base_font = Type.DISPLAY
	title_font.fallbacks = [Type.SPUDION, UI_SYMBOLS, UI_SYMBOLS_2]
	title_font.variation_opentype = {weight_axis: 600.0}
	_heading_font = title_font
	_paper_body_font.fallbacks = [Type.SPUDION]
	_paper_heading_font.fallbacks = [Type.SPUDION]
	_ledger_font.fallbacks = [Type.SPUDION]
	root = Control.new()
	root.name = "TaterlandHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	theme.default_font = _font
	theme.default_font_size = 15
	root.theme = theme
	add_child(root)
	_climate_effect = load("res://scripts/climate_effect.gd").new()
	root.add_child(_climate_effect)
	_build_top()
	_build_hurry_badge()
	_season_jobs = preload("res://scripts/season_jobs.gd").new()
	root.add_child(_season_jobs)
	_season_jobs.setup(self)
	_build_sidebar()
	_build_footer()
	_build_notices()
	_build_modal()
	_climate_console = load("res://scripts/climate_console.gd").new()
	root.add_child(_climate_console)
	_climate_console.operated.connect(func(action: String) -> void: _act("climate_operate:" + action))
	_climate_console.opened.connect(func() -> void: _act("climate"))
	_build_tutorial()
	_build_farm_help()
	_climate_alert = load("res://scripts/climate_alert.gd").new()
	root.add_child(_climate_alert)
	_build_run_end()

func _build_run_end() -> void:
	_run_end = load("res://scripts/climate_collapse.gd").new()
	root.add_child(_run_end)
	_run_end_title = _run_end.headline
	_run_end_detail = _run_end.detail
	_run_end.restart_requested.connect(func() -> void: _act("reset"))
	_run_end.debug_requested.connect(func() -> void: _act("debug"))

func _update_weather_ui() -> void:
	if not is_instance_valid(_state):
		return
	var climate: Dictionary = _state.call("climate_info")
	var water_count: Label = _tool_buttons.water.get_meta("water_count")
	water_count.text = "%d/%d" % [floori(climate.supply.can), int(climate.can_capacity)]
	water_count.add_theme_color_override("font_color", Color("ffd39f") if float(climate.supply.can) < 1.0 else CREAM)
	_tool_buttons.water.tooltip_text = "Watering can: %d / %d water. Each watered bed uses 1. Click the tank to refill." % [floori(climate.supply.can), int(climate.can_capacity)]
	_climate_console.refresh(climate, is_panel_open() or bool(_state.run_over) or not _tutorial.is_empty())
	_climate_effect.set_weather(climate, bool(_state.run_over) or (not _tutorial.is_empty() and not _state.guided_first_year()))
	_weather_button.visible = _tutorial.is_empty() and not is_panel_open() and not _state.run_over
	_weather_button.text = "Weather & protection →" if climate.phase == "calm" else "%s · %ds →" % [str(climate.name).capitalize(), ceili(climate.timer)]
	var game = get_parent()
	if game.has_method("title_active") and game.title_active():
		_run_end.hide()
		if game.title_scene.confirming:
			_modal.z_index = 210
			_modal.show()
		return
	if _state.run_outcome == "foreclosed":
		var debug_open: bool = is_panel_open() and _panel_kind in ["debug", "measurement"]
		_modal.z_index = 210 if debug_open else 0
		if not _run_end.visible and not debug_open:
			close_panel()
			_toast_box.hide()
			_purchase_box.hide()
		for child in root.get_children():
			if child is CanvasItem and child != _run_end and not (debug_open and child == _modal) and child.visible:
				if not _collapse_hidden.has(child): _collapse_hidden.append(child)
				child.hide()
		_run_end.show_report(_state)
	elif _run_end.visible:
		_modal.z_index = 0
		_run_end.hide()
		for child in _collapse_hidden:
			if is_instance_valid(child): child.show()
		_collapse_hidden.clear()


func _build_climate() -> void:
	var page := preload("res://scripts/weather_pages.gd").new()
	_body.add_child(page)
	_refs.weather_page = page
	page.setup(self)

func _refresh_climate() -> void:
	if _refs.has("weather_page"): _refs.weather_page.refresh()

func _build_tutorial() -> void:
	_tutorial_card = _card(Color("17382d"), 15)
	_tutorial_card.name = "FirstIslandGuide"
	_tutorial_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(_tutorial_card, Rect2(28, 108, 219, 0))
	_tutorial_card.z_index = 30
	var contents: VBoxContainer = _vbox(10)
	_tutorial_card.add_child(contents)
	var top_row: BoxContainer = _hbox(2)
	contents.add_child(top_row)
	_tutorial_progress = _label("YOUR FIRST FARM", 11, GOLD, true)
	_tutorial_progress.add_theme_font_override("font", _compact_heading_font())
	_tutorial_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_tutorial_progress)
	var graphics: Button = _button("⚙", "graphics")
	graphics.name = "TutorialGraphics"
	graphics.tooltip_text = "Graphics · smoother play"
	graphics.custom_minimum_size = Vector2(26, 26)
	graphics.add_theme_font_size_override("font_size", 18)
	for style_name: String in ["normal", "hover", "pressed"]:
		graphics.add_theme_stylebox_override(style_name, _style(Color("29493b") if style_name != "normal" else Color.TRANSPARENT, 0, 5))
		graphics.add_theme_color_override("font_" + ("color" if style_name == "normal" else style_name + "_color"), Color("acbfae"))
	top_row.add_child(graphics)
	_tutorial_skip = _button("×", "tutorial:exit")
	_tutorial_skip.name = "TutorialSkip"
	_tutorial_skip.tooltip_text = "Skip the guided year"
	_tutorial_skip.custom_minimum_size = Vector2(26, 26)
	_tutorial_skip.add_theme_font_size_override("font_size", 20)
	for style_name: String in ["normal", "hover", "pressed"]:
		_tutorial_skip.add_theme_stylebox_override(style_name, _style(Color("29493b") if style_name != "normal" else Color.TRANSPARENT, 0, 5))
		_tutorial_skip.add_theme_color_override("font_" + ("color" if style_name == "normal" else style_name + "_color"), Color("acbfae"))
	top_row.add_child(_tutorial_skip)
	_tutorial_meter = ProgressBar.new()
	_tutorial_meter.custom_minimum_size.y = 5
	_tutorial_meter.show_percentage = false
	_tutorial_meter.add_theme_stylebox_override("background", _style(Color("305140"), 0, 3))
	_tutorial_meter.add_theme_stylebox_override("fill", _style(GOLD, 0, 3))
	contents.add_child(_tutorial_meter)
	_tutorial_icon = _icon({"kind": "crop", "crop": "russet"}, 54)
	_tutorial_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	contents.add_child(_tutorial_icon)
	_tutorial_title = _wrap("Welcome home", 21, CREAM, true)
	_tutorial_title.add_theme_font_override("font", _compact_heading_font())
	var speaker := HBoxContainer.new()
	speaker.add_theme_constant_override("separation", 10)
	contents.add_child(speaker)
	_tutorial_forecaster = preload("res://scripts/npc_portrait.gd").new()
	_tutorial_forecaster.custom_minimum_size = Vector2(68, 86)
	speaker.add_child(_tutorial_forecaster)
	_tutorial_forecaster.show_person("iris")
	_tutorial_forecaster.hide()
	_tutorial_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker.add_child(_tutorial_title)
	_tutorial_body = _wrap("", 15, Color("e2ead9"))
	var guide_font: FontVariation = FontVariation.new()
	guide_font.base_font = UI_FONT
	guide_font.variation_opentype = _font.variation_opentype
	_tutorial_body.add_theme_font_override("font", guide_font)
	contents.add_child(_tutorial_body)
	_tutorial_feedback = _wrap("", 13, GOLD)
	contents.add_child(_tutorial_feedback)
	_tutorial_feedback.hide()
	_tutorial_key = _label("", 13, GOLD, true)
	_tutorial_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(_tutorial_key)
	_tutorial_next = _button("Let's grow →", "tutorial:next")
	_tutorial_next.name = "TutorialNext"
	_tutorial_next.custom_minimum_size.y = 48
	_tutorial_next.add_theme_stylebox_override("normal", _style(GOLD, 9, 10))
	_tutorial_next.add_theme_stylebox_override("hover", _style(Color("ffeaa1"), 9, 10))
	_tutorial_next.add_theme_stylebox_override("pressed", _style(Color("e9b94f"), 9, 10))
	_tutorial_next.add_theme_stylebox_override("disabled", _style(Color("274b3b"), 9, 10))
	_tutorial_next.add_theme_color_override("font_disabled_color", Color("c2d7c0"))
	contents.add_child(_tutorial_next)
	_tutorial_exit_box = _vbox(8)
	contents.add_child(_tutorial_exit_box)
	_tutorial_exit_box.add_child(_wrap("Skip the guided year? Your farm and seasons stay.", 15, CREAM, true))
	var stay: Button = _button("Keep learning →", "tutorial:stay")
	stay.add_theme_stylebox_override("normal", _style(GOLD, 9, 10))
	_tutorial_exit_box.add_child(stay)
	var leave: Button = _button("Skip guided year", "tutorial:skip")
	leave.add_theme_stylebox_override("normal", _style(Color("294438"), 9, 10))
	leave.add_theme_color_override("font_color", Color("c9d1c4"))
	_tutorial_exit_box.add_child(leave)
	_tutorial_exit_box.hide()
	_tutorial_card.hide()
	_tutorial_pointer = preload("res://scripts/tutorial_pointer.gd").new()
	root.add_child(_tutorial_pointer)
	_tutorial_pointer.hide()

func set_tutorial(info: Dictionary) -> void:
	if not is_instance_valid(root):
		build_ui()
	_restore_tutorial_buttons()
	if info.get("step", -1) != _tutorial.get("step", -1):
		_tutorial_exit_pending = false
		_tutorial_feedback.text = ""
		_tutorial_feedback.hide()
	_tutorial = info.duplicate(true)
	if _tutorial.is_empty():
		_tutorial_card.hide()
		_tutorial_exit_pending = false
		_tutorial_pointer.hide()
		_stats_card.show()
		_stats_card.size.x = 763.0
		for key: String in ["coins", "market_name"]:
			_top[key].get_parent().show()
		_menu_button.show()
		_hotbar.show()
		for button: Button in _tool_buttons.values():
			button.show()
		_hotbar.offset_left = -254
		_hotbar.offset_right = 254
		_quick_sell.show()
		set_context(_context.text)
		_refresh_seed_visibility()
	else:
		_tutorial_progress.text = ("VALLEY TOUR" if info.get("tour_only", false) else "FIRST YEAR") + "  ·  %d / %d" % [int(info.get("step", 1)), int(info.get("total", 1))]
		_tutorial_forecaster.visible = bool(info.get("forecaster", false))
		_tutorial_title.text = str(info.get("title", "Your first farm"))
		_tutorial_body.text = str(info.get("body", ""))
		_tutorial_next.text = str(info.get("continue_label", "Next stop →")) if bool(info.get("continue", false)) else "Click the gold bed" if str(info.get("focus", "")).begins_with("plot:") else "Follow the gold marker"
		_tutorial_next.disabled = not bool(info.get("continue", false))
		if info.get("id") == "inventory" and not bool(info.get("continue", false)):
			_tutorial_next.text = "Open bag [I] →"
			_tutorial_next.disabled = false
		elif info.get("id") == "walk":
			_tutorial_next.text = "Try a few steps"
		elif info.get("id") in ["grow", "winter"]:
			_tutorial_next.text = str(info.get("wait_label", "Work on the other beds"))
		_tutorial_key.text = str(info.get("key", ""))
		_tutorial_key.visible = not _tutorial_key.text.is_empty()
		_tutorial_meter.value = 100.0 * float(info.get("step", 1)) / maxf(1.0, float(info.get("total", 20)))
		var tool: String = str(info.get("tool", ""))
		var activity: String = "duck" if info.get("id") == "ducks" else ""
		_tutorial_icon.item = {"kind": "tool", "id": tool} if not tool.is_empty() else ({"kind": "activity", "id": activity} if not activity.is_empty() else {"kind": "crop", "crop": "russet"})
		_tutorial_icon.queue_redraw()
		_tutorial_card.show()
		_toast_timer.stop()
		_reward_timer.stop()
		_apply_tutorial_visibility()
	if is_panel_open():
		if _panel_kind in ["barn", "inventory"] and _first_harvest_barn():
			_inventory_tab = "crops"
			_set_inventory_tab()
		if _panel_kind in ["pause", "menu"] or (_panel_kind == "market" and _panel_crops != _market_crops()):
			show_panel(_panel_kind, _state)
		else:
			_refresh_panel()
	_apply_tutorial_buttons()
	if _tutorial.is_empty() and is_instance_valid(_state):
		update_state(_state)

func _tutorial_allows(action: String) -> bool:
	if _tutorial.is_empty() or action in ["tutorial:next", "tutorial:skip", "tutorial:exit", "tutorial:stay", "close"]:
		return true
	if not _tutorial.has("allowed_actions"):
		return true
	for permitted: String in _tutorial.allowed_actions:
		if action == permitted or (permitted.ends_with(":") and action.begins_with(permitted)):
			return true
	return false

func _restore_tutorial_buttons() -> void:
	if not is_instance_valid(root):
		return
	for node: Node in root.find_children("*", "Button", true, false):
		if node.has_meta("tutorial_disabled"):
			node.disabled = bool(node.get_meta("tutorial_disabled"))
			node.remove_meta("tutorial_disabled")
			node.tooltip_text = str(node.get_meta("tutorial_tooltip", ""))
			node.remove_meta("tutorial_tooltip")

func _apply_tutorial_buttons() -> void:
	if _tutorial.is_empty():
		return
	for node: Node in root.find_children("*", "Button", true, false):
		if not node.has_meta("hud_action"):
			continue
		if not _tutorial_allows(str(node.get_meta("hud_action"))):
			if not node.has_meta("tutorial_disabled"):
				node.set_meta("tutorial_disabled", node.disabled)
				node.set_meta("tutorial_tooltip", node.tooltip_text)
			node.tooltip_text = "Available after the first accounts, or skip the guided year to farm freely."
			node.disabled = true

func _apply_tutorial_visibility() -> void:
	if _tutorial.is_empty() or not is_instance_valid(_tutorial_card):
		return
	var features: Array = _tutorial.get("features", [])
	var tools: Array = _tutorial.get("tools", [])
	_stats_card.visible = "coins" in features or "stock" in features
	_top.coins.get_parent().visible = "coins" in features
	_top.market_name.get_parent().visible = "stock" in features
	var revealed_stats: int = int("coins" in features) + int("stock" in features)
	_stats_card.size.x = 763.0 if revealed_stats >= 3 else (510.0 if revealed_stats == 2 else 225.0)
	if "stock" in features:
		_top.market_name.text = "POTATO PRICES"
	_menu_button.visible = "menu" in features
	_hotbar.visible = not tools.is_empty()
	var hotbar_width: float = maxf(112.0, 14.0 + tools.size() * 92.0 + maxi(0, tools.size() - 1) * 6.0)
	_hotbar.offset_left = -hotbar_width * 0.5
	_hotbar.offset_right = hotbar_width * 0.5
	for tool: String in _tool_buttons:
		_tool_buttons[tool].visible = tool in tools
	if "stock" not in features:
		for crop: String in _crop_buttons:
			_crop_buttons[crop].visible = crop == "russet"
	_quick_sell.visible = "market" in features and "harvest" in tools
	_sidebar_box.hide()
	_context_box.hide()
	_toast_box.hide()
	_reward_box.hide()
	_refresh_seed_visibility()
	var touch = get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		_tutorial_next.visible = not _tutorial_exit_pending
		_tutorial_exit_box.visible = _tutorial_exit_pending
		_tutorial_card.move_to_front()
		return
	# Logical game size is preserved by the viewport. Measure the modal's
	# clear margin too, keeping this guide outside every shop's controls.
	if is_panel_open():
		# Wide exchange/build pages leave room for the first-lesson guide.
		_modal_card.position.x = maxf(_modal_card.position.x, minf(264.0, root.size.x - _modal_card.size.x - 16.0))
	var available_width: float = _modal_card.position.x - 44.0 if is_panel_open() else 219.0
	var card_width: float = minf(219.0, maxf(138.0, available_width))
	# progress label and exit controls cannot force a 214px overlap.
	(_tutorial_progress.get_parent() as BoxContainer).vertical = card_width < 210
	_tutorial_card.position = Vector2(28.0, 108.0)
	_tutorial_title.custom_minimum_size.x = card_width - 30.0
	_tutorial_body.custom_minimum_size.x = card_width - 30.0
	_tutorial_card.size = Vector2(card_width, 0.0)
	_tutorial_next.visible = not _tutorial_exit_pending
	_tutorial_exit_box.visible = _tutorial_exit_pending
	if _tutorial_card.get_index() != root.get_child_count() - 1:
		_tutorial_card.move_to_front()

func _update_tutorial_pointer() -> void:
	_tutorial_pointer.target = null
	_tutorial_pointer.visible = not _tutorial.is_empty() and not _tutorial_exit_pending
	if not _tutorial_pointer.visible:
		return
	var target: Control = null
	if _panel_kind == "market" and _refs.has("starter_continue"):
		target = _refs.starter_continue
	elif not _tutorial_next.disabled:
		target = _tutorial_next
	elif is_panel_open():
		var sale_action: String = "market_sell" if _panel_kind == "sell_potatoes" else "sell_potatoes"
		var action: String = "buy:russet:1" if _tutorial.get("id") == "market" else (sale_action if _tutorial.get("id") == "sell" else "")
		for node: Node in _modal_card.find_children("*", "Button", true, false):
			if not action.is_empty() and str(node.get_meta("hud_action", "")) == action and node.is_visible_in_tree() and not node.disabled:
				target = node
				break
	# Farming tools are already equipped. The only cue belongs to the bed.
	_tutorial_pointer.target = target

func _style(color: Color, padding: int = 14, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(mini(radius, 5))
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	return style

func _label(text: String, size: int = 15, color: Color = INK, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _heading_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _compact_heading_font() -> FontVariation:
	# Nunito plus our potato glyph keeps balances compact on native and web.
	var compact: FontVariation = FontVariation.new()
	compact.base_font = UI_FONT
	compact.fallbacks = [Type.SPUDION]
	compact.variation_opentype = _heading_font.variation_opentype
	return compact

func _wrap(text: String, size: int = 15, color: Color = INK, bold: bool = false) -> Label:
	var label: Label = _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _vbox(gap: int = 8) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box

func _hbox(gap: int = 10) -> BoxContainer:
	var box: BoxContainer = BoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box

func _card(color: Color = CREAM, padding: int = 16) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Cozy.paper(color, padding, 6, color.darkened(.20)))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel

func _surface(kind: String, accent: Color = GREEN, selected: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Cozy.surface(kind, accent, selected))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel

func _badge(text: String, tone: String = "neutral") -> Label:
	var label := _label(text, 11, INK, true)
	label.add_theme_font_override("font", Type.face(Type.BODY, 700))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Cozy.badge(label, text, tone)
	return label

func _meter(accent: Color = GREEN, height: float = 8) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("e1e5d5"), 0, 4))
	bar.add_theme_stylebox_override("fill", _style(accent, 0, 4))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _metric(icon_id: String, text: String, color: Color = INK) -> BoxContainer:
	var row := _hbox(5)
	row.add_child(_icon({"kind": "metric", "id": icon_id}, 22))
	row.add_child(_label(text, 13, color, true))
	return row

func _section_title(parent: Control, title: String, detail: String = "") -> void:
	var row := _hbox(10)
	parent.add_child(row)
	var heading := _label(title, 17, INK, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	if not detail.is_empty(): row.add_child(_label(detail, 12, MUTED))

func _polish_card_typography(node: Node) -> void:
	# Symbol fallback fonts have tall line metrics. These illustrated menus
	# use drawn icons, so keep text on the compact body/display font faces.
	if node is Label:
		if node.get_theme_font("font") == _heading_font:
			node.add_theme_font_override("font", _card_heading_font)
		elif not node.has_theme_font_override("font"):
			node.add_theme_font_override("font", _plain_font)
	elif node is OptionButton:
		_style_choice(node)
	elif node is Button:
		node.add_theme_font_override("font", _card_button_font)
	for child: Node in node.get_children():
		_polish_card_typography(child)

func _button(text: String, action: String, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.set_meta("hud_action", action)
	button.text = text
	button.set_meta("action", action)
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_font_override("font", _heading_font)
	button.add_theme_color_override("font_color", CREAM if primary else INK)
	button.add_theme_color_override("font_hover_color", CREAM if primary else INK)
	button.add_theme_color_override("font_pressed_color", CREAM if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("727d69"))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Cozy.button_style(state, primary))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, 10, GOLD))
	preload("res://scripts/place_ui.gd").pill(button, GREEN, primary)
	button.pressed.connect(func() -> void: _act(action))
	return button

func _act(action: String) -> void:
	if action.is_empty(): return
	if action == "ledger_screenshot":
		_capture_ledger()
		return
	if action == "farm_help:details":
		if not _farm_tip.is_empty() and _tutorial.is_empty() and not _state.run_over:
			_opened_farm_tip = _farm_tip.duplicate(true)
			show_panel("farm_tip", _state)
		return

	if action.begins_with("toggle_details:"):
		var key: String = action.get_slice(":", 1)
		if _refs.has(key):
			_refs[key].visible = not _refs[key].visible
			if _refs.has(key + ":toggle"):
				_refs[key + ":toggle"].text = ("Hide " if _refs[key].visible else "Show ") + str(_refs[key + ":toggle"].get_meta("section_title", "details"))
			if _refs[key].visible: _reveal_details(_refs[key])
		return
	if is_instance_valid(_state) and bool(_state.get("run_over")) and action not in (["reset", "debug", "close", "menu", "accounts", "run_summary", "epilogue", "request_reset", "cancel_reset", "measurement", "measurement_copy"] if _state.run_outcome == "completed" else ["reset", "debug", "close", "cancel_reset", "measurement", "measurement_copy"]) and not action.begins_with("debug"):
		return
	if not _tutorial_allows(action):
		show_tutorial_feedback("This action waits until later. Skip the guided year to farm freely.")
		return
	if action == "sleep_spring":
		if is_instance_valid(_state) and _state.can_sleep_until_spring(): show_panel("sleep_confirm", _state)
		return
	if action in ["tutorial:exit", "tutorial:stay"]:
		_tutorial_exit_pending = action == "tutorial:exit"
		_apply_tutorial_visibility()
		_update_tutorial_pointer()
		return
	if action == "tutorial:skip":
		if not _tutorial_exit_pending:
			return
		_tutorial_exit_pending = false
	if action == "tutorial:next" and not bool(_tutorial.get("continue", false)):
		if _tutorial.get("id") == "inventory":
			action = "inventory"
		else:
			return
	if action == "debug_unlock":
		if _refs.has("debug_code"):
			var code: String = _refs.debug_code.text
			_refs.debug_code.clear()
			action_requested.emit("debug:unlock:" + code)
		return
	if (action.begins_with("debug:") or action.begins_with("debug_")) and not _debug_unlocked:
		return
	if action.begins_with("debug_balance_preset:"):
		if _refs.has("debug_balance_input"):
			_refs.debug_balance_input.text = action.get_slice(":", 1)
			_refresh_debug()
		return
	if action in ["debug_set_balance", "debug_recover"]:
		if not _refs.has("debug_balance_input"): return
		var balance: Dictionary = _refs.debug_balance_input.read_number()
		if balance.has("error") or (action == "debug_recover" and float(balance.value) <= 0):
			_refresh_debug()
			return
		action_requested.emit("debug:%s:%s" % ["recover" if action == "debug_recover" else "set_balance", str(balance.canonical)])
		_refresh_debug()
		return
	if action.begins_with("debug_money:"):
		var field: String = "debug_money"
		_refs[field].value = float(action.get_slice(":", 1))
		_refresh_debug()
		return
	if action == "debug_apply":
		var multiplier: Dictionary = _debug_money_value()
		if multiplier.has("error"):
			_refresh_debug()
			return
		action_requested.emit("debug:apply:" + str(multiplier.canonical))
		_refs.debug_money.value = 1.0
		_refresh_debug()
		return
	if action == "menu":
		show_panel("pause", _state)
		return
	if action.begins_with("inventory_tab:"):
		var tab: String = action.get_slice(":", 1)
		if tab not in ["crops", "tools"]: return
		_inventory_tab = tab
		_set_inventory_tab()
		if is_instance_valid(_refs.get("shop_page")): _refs.shop_page.refresh()
		(_body.get_parent() as ScrollContainer).scroll_vertical = 0
		return
	if action == "close":
		close_panel()
	elif action == "request_reset":
		_reset_pending = true
		show_panel("pause", _state)
	elif action == "cancel_reset":
		_reset_pending = false
		show_panel("pause", _state)
	else:
		if action.begins_with("tool:"):
			set_tool(action.get_slice(":", 1))
		action_requested.emit(action)

func _place(control: Control, rect: Rect2) -> void:
	root.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _build_top() -> void:
	_play_band = _card(INK, 0)
	_play_band.name = "PlayHudBand"
	_play_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_play_band, Rect2(0,0,1280,104))
	_play_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_play_band.offset_bottom = 104
	var brand: VBoxContainer = _vbox(0)
	_place(brand, Rect2(88, 20, 290, 70))
	brand.name = "FarmWordmark"
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wordmark: BoxContainer = _hbox(8)
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(wordmark)
	wordmark.add_child(_label("TATER", 32, CREAM, true))
	wordmark.add_child(_label("/", 32, GOLD, true))
	wordmark.add_child(_label("LAND", 32, CREAM, true))
	_top["season"] = _label("Year 1 · Spring", 16, INK, true)
	brand.add_child(_top.season)
	_top.season.hide()
	_season_strip = preload("res://scripts/paper_detail.gd").new()
	_season_strip.kind = "season"
	_place(_season_strip, Rect2(88, 76, 330, 24))

	var stats: PanelContainer = _card(INK, 8)
	_stats_card = stats
	_place(stats, Rect2(387, 21, 524, 72))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: BoxContainer = _hbox(20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(row)
	_top["coins"] = _stat(row, "SPUDIONS", "\uE000 240", GOLD)
	var market_box: VBoxContainer = _vbox(0)
	market_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(market_box)
	_top["market_name"] = _label("RUSSET MARKET", 10, CREAM.darkened(.25), true)
	_top["price"] = _label("", 22, GREEN, true)
	market_box.add_child(_top["market_name"])
	_top["price"].add_theme_stylebox_override("normal", Cozy.paper(CREAM, 3, 3))
	var quote_row: BoxContainer = _hbox(8)
	quote_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	market_box.add_child(quote_row)
	quote_row.add_child(_top["price"])
	_top["price_change"] = _label("", 16, INK, true)
	_top.price_change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quote_row.add_child(_top.price_change)
	var stats_font: FontVariation = _compact_heading_font()
	for label: Node in stats.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", stats_font)
	stats.size.x = 763
	_weather_button = _button("Weather & protection →", "climate")
	_place(_weather_button, Rect2(28, 112, 302, 44))
	_world_button(_weather_button, INK)
	_weather_button.add_theme_font_size_override("font_size", 14)
	var menu_button: Button = _button("", "menu")
	_menu_button = menu_button
	menu_button.name = "MainMenuButton"
	menu_button.tooltip_text = "Farm menu · Debug money · Esc"
	_place(menu_button, Rect2(1174, 21, 78, 72))
	_world_button(menu_button, INK)
	var menu_icon: VBoxContainer = _vbox(5)
	menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(menu_icon)
	menu_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_icon.offset_left = -12
	menu_icon.offset_right = 12
	menu_icon.offset_top = -10
	menu_icon.offset_bottom = 10
	for _line: int in range(3):
		var bar: ColorRect = ColorRect.new()
		bar.color = CREAM
		bar.custom_minimum_size.y = 3
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_icon.add_child(bar)
	var save: Button = _button("Save", "save")
	save.custom_minimum_size.y = 27
	save.add_theme_font_size_override("font_size", 12)
	_place(save, Rect2(1154, 67, 98, 27))
	save.hide()

func _world_button(button: Button, tone: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Cozy.paper(tone.lightened(.12) if state == "hover" else tone.darkened(.08) if state == "pressed" else tone, 10, 5))
	for property: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(property, CREAM.darkened(.3) if property == "font_disabled_color" else CREAM)

func _build_hurry_badge() -> void:
	_hurry_badge = _card(CREAM, 6)
	_hurry_badge.name = "HurryBadge"
	_hurry_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurry_badge.z_index = 200
	var badge: Label = _label("3×", 16, INK, true)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurry_badge.add_child(badge)
	_place(_hurry_badge, Rect2(338, 112, 46, 28))
	_hurry_badge.hide()

func set_hurry_active(active: bool) -> void:
	hurry_active = active
	_update_hurry_badge()

func _update_hurry_badge() -> void:
	if not is_instance_valid(_hurry_badge): return
	var touch = get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	# Touch shows the badge in its held field button. A keyboard can still
	# hurry an ordinary phone menu, where the field controls are hidden.
	_hurry_badge.visible = hurry_active and (not phone or is_panel_open()) and is_instance_valid(_state) and not _state.run_over
	if not _hurry_badge.visible: return
	var badge: Label = _hurry_badge.get_child(0)
	if phone:
		var scale: float = minf(float(get_tree().root.size.x) / root.size.x, float(get_tree().root.size.y) / root.size.y)
		var extent := Vector2(46, 28) / maxf(.1, scale)
		_hurry_badge.position = Vector2(root.size.x - extent.x - 22, 24)
		_hurry_badge.size = extent
		badge.add_theme_font_size_override("font_size", ceili(16 / maxf(.1, scale)))
	else:
		_hurry_badge.position = Vector2(338, 112)
		_hurry_badge.size = Vector2(46, 28)
		badge.add_theme_font_size_override("font_size", 16)

func _stat(parent: BoxContainer, title: String, value: String, color: Color) -> Label:
	var box: VBoxContainer = _vbox(0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_label(title, 10, CREAM.darkened(.25), true))
	var number: Label = _label(value, 23, color, true)
	number.add_theme_stylebox_override("normal", Cozy.paper(CREAM, 3, 3))
	box.add_child(number)
	return number

func _build_sidebar() -> void:
	_sidebar_box = _card(CREAM, 12)
	_place(_sidebar_box, Rect2(28, 176, 219, 0))
	_sidebar_box.hide()
	var body: VBoxContainer = _vbox(7)
	_sidebar_box.add_child(body)
	_crop_detail = _wrap("Russet · 12 seeds", 16, INK, true)
	body.add_child(_crop_detail)
	_quest_button = _button("Quest board  [Q]", "quests")
	_quest_button.custom_minimum_size.y = 30
	body.add_child(_quest_button)

func _build_footer() -> void:
	_crop_row = _hbox(8)
	root.add_child(_crop_row)
	_crop_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_crop_row.offset_left = 28
	_crop_row.offset_right = -28
	_crop_row.offset_top = -214
	_crop_row.offset_bottom = -130
	for crop: String in _all_crop_ids():
		_add_crop_chip(crop)
	var hotbar: PanelContainer = _card(Color("223d33"), 7)
	_hotbar = hotbar
	hotbar.name = "ToolHotbar"
	root.add_child(hotbar)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -254
	hotbar.offset_right = 254
	hotbar.offset_top = -114
	hotbar.offset_bottom = -20
	var slots: BoxContainer = _hbox(6)
	hotbar.add_child(slots)
	var tools: Array[String] = ["hoe", "plant", "water", "harvest", "pest"]
	var tool_names: Array[String] = ["Hoe", "Seeds", "Water", "Harvest", "Sprayer"]
	for index: int in range(tools.size()):
		var tool: String = tools[index]
		var button: Button = _button("", "tool:" + tool)
		button.custom_minimum_size = Vector2(92, 80)
		_world_button(button, Cozy.WOOD)
		button.tooltip_text = "%d · %s — equip for field work" % [index + 1, tool_names[index]]
		slots.add_child(button)
		var content: VBoxContainer = _vbox(0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 5
		content.offset_right = -5
		content.offset_top = 3
		content.offset_bottom = -3
		var icon: Control = _icon({"id": tool, "kind": "tool", "tool": tool}, 49)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var caption: Label = _label("%d  %s" % [index + 1, tool_names[index]], 12, INK, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(caption)
		button.set_meta("caption", caption)
		if tool == "water":
			var count := _label("16/16", 11, CREAM, true)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.add_theme_stylebox_override("normal", _style(INK, 2, 5))
			button.add_child(count)
			count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			count.offset_left = -44
			count.offset_right = -4
			count.offset_top = 5
			button.set_meta("water_count", count)
		_tool_buttons[tool] = button
	_tool_caption = _label("Hoe equipped · Click / E to use", 12, INK, true)
	_tool_caption.add_theme_font_override("font", _compact_heading_font())
	root.add_child(_tool_caption)
	_tool_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tool_caption.offset_left = -248
	_tool_caption.offset_right = 248
	_tool_caption.offset_top = -130
	_tool_caption.offset_bottom = -112
	_tool_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_caption.hide()
	var nav_grid: GridContainer = GridContainer.new()
	nav_grid.columns = 2
	nav_grid.hide()
	nav_grid.add_theme_constant_override("h_separation", 7)
	nav_grid.add_theme_constant_override("v_separation", 7)
	root.add_child(nav_grid)
	nav_grid.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	nav_grid.offset_left = 28
	nav_grid.offset_right = 326
	nav_grid.offset_top = -106
	nav_grid.offset_bottom = -21
	for nav: Array in [["Buy Seeds [B]", "market"], ["Inventory [I]", "inventory"], ["Upgrades [U]", "tools"]]:
		var button: Button = _button(nav[0], nav[1], nav[1] == "market")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_grid.add_child(button)
	var sell_box: VBoxContainer = _vbox(6)
	root.add_child(sell_box)
	sell_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sell_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sell_box.offset_left = -326
	sell_box.offset_right = -28
	sell_box.offset_top = -66
	sell_box.offset_bottom = -20
	_quick_sell = _button("Sell held [F]", "quick_sell", true)
	_quick_sell.custom_minimum_size.y = 46
	_world_button(_quick_sell, Cozy.WOOD)
	sell_box.add_child(_quick_sell)
	_context_box = _card(Color(0.09, 0.20, 0.16, 0.93), 6)
	var hint_skin: StyleBox = _context_box.get_theme_stylebox("panel")
	hint_skin.content_margin_top = 2
	hint_skin.content_margin_bottom = 2
	root.add_child(_context_box)
	_context_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_context_box.offset_left = -220
	_context_box.offset_right = 220
	_context_box.offset_top = -152
	_context_box.offset_bottom = -122
	_context_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context = _label("", 13, CREAM)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context.add_theme_font_override("font", _plain_font)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_box.add_child(_context)
	_context_box.hide()
	set_tool("hoe")

func _icon(data: Dictionary, pixels: float = 62.0) -> Control:
	var icon: Control = ItemIcon.new()
	icon.item = data.duplicate(true)
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.size = Vector2(pixels, pixels)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _build_notices() -> void:
	_barn_full_alert = _card(Color("a52f38"), 16)
	_barn_full_alert.name = "BarnFullAlert"
	root.add_child(_barn_full_alert)
	_barn_full_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_barn_full_alert.z_index = 15
	_barn_full_alert.add_theme_stylebox_override("panel", Cozy.paper(Color("a52f38"), 16, 6, Color("ffd0a3")))
	var alert_row := _hbox(16)
	_barn_full_alert.add_child(alert_row)
	var alert_words := _vbox(3)
	alert_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alert_row.add_child(alert_words)
	var alert_title := _label("BARN FULL", 26, Color.WHITE, true)
	alert_title.add_theme_font_override("font", _compact_heading_font())
	alert_words.add_child(alert_title)
	_barn_full_detail = _wrap("Sell crops to keep harvesting.", 15, Color("fff4e1"))
	_barn_full_detail.add_theme_font_override("font", UI_FONT)
	alert_words.add_child(_barn_full_detail)
	var sell := _button("Sell crops", "sell_potatoes")
	sell.custom_minimum_size = Vector2(128, 52)
	sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_row.add_child(sell)
	_barn_full_sell = sell
	_barn_full_alert.hide()
	_toast_box = _card(INK, 10)
	_place(_toast_box, Rect2(926, 104, 326, 0))
	_toast_box.z_index = 20
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _wrap("", 13, CREAM)
	_toast_label.add_theme_font_override("font", _plain_font)
	_toast_box.add_child(_toast_label)
	_toast_box.hide()
	_toast_timer = _timer(2.5, func() -> void: _toast_box.hide())
	_purchase_box = _card(INK, 14)
	_purchase_box.name = "PurchaseReceipt"
	_place(_purchase_box, Rect2(1022, 216, 230, 0))
	# The exchange stays open while buying. Keep its receipt in the clear
	# right margin, above the modal shade and away from every purchase button.
	_purchase_box.z_index = 20
	_purchase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var purchase_body: VBoxContainer = _vbox(5)
	purchase_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purchase_box.add_child(purchase_body)
	_purchase_title = _wrap("", 18, GOLD, true)
	_purchase_detail = _wrap("", 13, CREAM)
	_purchase_title.add_theme_font_override("font", _compact_heading_font())
	_purchase_detail.add_theme_font_override("font", _plain_font)
	purchase_body.add_child(_purchase_title)
	purchase_body.add_child(_purchase_detail)
	_purchase_bar = ProgressBar.new()
	_purchase_bar.custom_minimum_size.y = 7
	_purchase_bar.show_percentage = false
	_purchase_bar.max_value = PURCHASE_SECONDS
	_purchase_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purchase_bar.add_theme_stylebox_override("background", _style(Color("315246"), 0, 3))
	_purchase_bar.add_theme_stylebox_override("fill", _style(GOLD, 0, 3))
	purchase_body.add_child(_purchase_bar)
	_purchase_box.hide()
	_reward_box = _card(INK, 17)
	_place(_reward_box, Rect2(1022, 412, 230, 0))
	_reward_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reward_body: VBoxContainer = _vbox(8)
	_reward_box.add_child(reward_body)
	_reward_rarity = _label("★ RARE FIND", 12, GOLD, true)
	_reward_title = _wrap("A lovely surprise.", 23, CREAM, true)
	_reward_detail = _wrap("", 14, Color("e1e6ce"))
	reward_body.add_child(_reward_rarity)
	reward_body.add_child(_reward_title)
	reward_body.add_child(_reward_detail)
	_reward_box.hide()
	_reward_timer = _timer(8.0, func() -> void: _reward_box.hide())

func _timer(seconds: float, callback: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.timeout.connect(callback)
	add_child(timer)
	return timer

func _build_modal() -> void:
	_modal = Control.new()
	root.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.06, 0.13, 0.10, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_motion = Control.new()
	_modal_motion.name = "ModalPresentation"
	_modal_motion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(_modal_motion)
	_modal_motion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = _card(CREAM, 24)
	_modal_card = panel
	_modal_motion.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -376
	panel.offset_right = 376
	panel.offset_top = -317
	panel.offset_bottom = 317
	var column: VBoxContainer = _vbox(14)
	panel.add_child(column)
	var header: BoxContainer = _hbox(10)
	column.add_child(header)
	var titles: VBoxContainer = _vbox(3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_modal_title = _wrap("", 34, CREAM, true)
	_modal_subtitle = _wrap("", 14, MUTED)
	titles.add_child(_modal_title)
	titles.add_child(_modal_subtitle)
	_modal_market_nav = HBoxContainer.new()
	_modal_market_nav.add_theme_constant_override("separation", 8)
	titles.add_child(_modal_market_nav)
	_modal_market_nav.hide()
	var close: Button = _button("×", "close")
	close.custom_minimum_size.x = 44
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(close)
	_modal_fixed = _vbox(6)
	column.add_child(_modal_fixed)
	_modal_fixed.hide()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scrollbar: VScrollBar = scroll.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = 8
	scrollbar.add_theme_stylebox_override("scroll", _style(Color("e3e5d6"), 4, 4))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state, _style(Color("8d9d7f") if state == "grabber" else GREEN, 4, 4))
	column.add_child(scroll)
	_body = _vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_modal_trade_footer = _vbox(4)
	column.add_child(_modal_trade_footer)
	_modal_trade_footer.hide()
	var shield := ColorRect.new()
	shield.name = "AccountsEntranceShield"
	shield.color = Color.TRANSPARENT
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.z_index = 20
	_modal.add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.hide()
	_modal_entrance_shield = shield
	_modal.hide()

func price_change_color(crop: String) -> Color:
	var price: float = _state.market[crop].sell
	var base: float = float(_crop_defs[crop].base)
	if is_equal_approx(price, base): return INK
	return Color("436733") if price > base else Color("a63529")

func update_state(state: Node) -> void:
	_state = state
	if not is_instance_valid(root):
		build_ui()
	_restore_tutorial_buttons()
	_sync_crop_catalog()
	var crop: String = str(state.get("selected_crop"))
	var markets: Dictionary = state.get("market")
	var quote: Dictionary = markets.get(crop, {})
	var seeds: Dictionary = state.get("seed_inventory")
	var calendar: String = "%d:%d:%s" % [state.season_clock.year, state.season_clock.season, state.run_outcome]
	var calendar_changed: bool = calendar != _displayed_calendar
	_displayed_calendar = calendar
	_top.season.text = "Year %d · %s" % [state.season_clock.year, state.SeasonClock.NAMES[state.season_clock.season]] + (" · %ds" % state.season_seconds() if state.season_clock.season == 1 and state.diversification.owns("shop") else "")
	# Reconcile from state on ordinary refreshes too, after the boundary save.
	# Remember the calendar so Escape can dismiss Winter without reopening it.
	if calendar_changed and state.run_outcome != "foreclosed":
		if state.run_outcome == "completed": show_panel("run_summary", state)
		elif state.season_clock.season == 3: show_panel("accounts", state)
		elif _panel_kind == "accounts": close_panel()
		elif _panel_kind in ["menu", "pause"]: show_panel(_panel_kind, state)
	_season_strip.year = state.season_clock.year
	_season_strip.season = state.season_clock.season
	_season_strip.queue_redraw()
	_season_jobs.refresh()
	_top.coins.text = _money(float(state.get("coins")))
	_top.coins.add_theme_color_override("font_color", Color("bb4334") if float(state.get("coins")) < 0.0 else GOLD)
	_top.market_name.text = str(_crop_name(crop)).to_upper() + " MARKET"
	_top.price.text = state.market_money(float(quote.get("sell", 0)))
	_top.price.add_theme_color_override("font_color", INK)
	_top.price_change.text = "· " + state.price_percent_text(crop)
	_top.price_change.add_theme_color_override("font_color", Color("e8c27b") if price_change_color(crop) == INK else price_change_color(crop).lightened(.4))
	_top.price_change.show()
	_crop_detail.text = "%s · %s seeds" % [_crop_name(crop), _number(float(seeds.get(crop, 0)))]
	var held: float = state.trading.fresh_count(state, crop)
	var sale_value: float = 0
	for word in state.Quality.GRADES: sale_value += state.trading.fresh_count(state, crop, word) * state.Quality.MULTIPLIER[word] * float(quote.get("sell", 0))
	_quick_sell.text = "Sell held [F] · " + _money(sale_value)
	_quick_sell.disabled = held <= 0
	var available: Array[String] = _market_crops()
	for id: String in _all_crop_ids():
		var button: Button = _crop_buttons[id]
		button.visible = id in available
		button.refresh(int(seeds.get(id, 0)), state.stock_count(id), id == crop)
	_update_quest_sidebar()
	_refresh_seed_visibility()
	_apply_tutorial_visibility()
	_apply_tutorial_buttons()
	_update_weather_ui()
	_update_farm_help()
	if is_panel_open():
		var expected_crops: Array[String] = _market_crops() if _panel_kind == "market" else _known_crops()
		if _panel_kind in ["inventory", "barn"] and _inventory_signature != _inventory_id_string(_inventory_data()):
			show_panel(_panel_kind, state)
			return
		if _panel_kind == "sell_potatoes": expected_crops = preload("res://scripts/game_state.gd").crops_by_base_price(_known_crops())
		if _panel_kind in ["market", "sell_potatoes", "barn", "inventory", "dex"] and _panel_crops != expected_crops:
			show_panel(_panel_kind, state)
		else:
			_refresh_panel()
	_update_barn_full_alert()

func set_tool(tool: String) -> void:
	if tool not in ["hoe", "plant", "water", "harvest", "pest"]:
		return
	if not _tutorial.is_empty() and tool not in _tutorial.get("tools", []):
		return
	_selected_tool = tool
	_refresh_seed_visibility()
	var names: Dictionary = {"hoe": "Hoe", "plant": "Seeds", "water": "Watering can", "harvest": "Harvest scythe", "pest": "Bug sprayer"}
	if is_instance_valid(_tool_caption):
		_tool_caption.text = "%s equipped · Click / E to use" % names[tool]
	for key: Variant in _tool_buttons:
		var button: Button = _tool_buttons[key]
		button.add_theme_stylebox_override("normal", Cozy.paper(Color("a87b47") if key == tool else Cozy.WOOD, 5, 4, GOLD if key == tool else Cozy.WOOD.darkened(.25)))
		var caption: Label = button.get_meta("caption")
		caption.add_theme_color_override("font_color", CREAM)
	_apply_tutorial_visibility()

func set_context(text: String) -> void:
	_hover_context = text
	_update_context()

func note_farm_action() -> void:
	_farm_busy_remaining = 3.0
	if is_instance_valid(_farm_help_card): _farm_help_card.hide()

func show_farm_hint(text: String) -> void:
	if not _tutorial.is_empty(): return
	note_farm_action()
	# Repeated input shares one slot and cannot keep extending the same notice.
	if text == _farm_hint and _farm_hint_remaining > 0.0: return
	_farm_hint = text
	_farm_hint_remaining = 1.4
	_update_context()

func clear_farm_hint() -> void:
	_farm_hint_remaining = 0.0
	_update_context()

func _update_context() -> void:
	if not is_instance_valid(_context): return
	_update_barn_full_alert()
	if is_instance_valid(_toast_box) and _toast_box.visible: _layout_toast()
	var text: String = _farm_hint if _farm_hint_remaining > 0.0 else _hover_context
	var warning: bool = _notice_is_warning(text)
	if not _context_box.has_meta("surface_warning") or _context_box.get_meta("surface_warning") != warning:
		var skin: StyleBoxTexture = Cozy.paper(Color("a5343c") if warning else INK, 6, 4, Color("ffbd9e") if warning else Color("657079"))
		skin.content_margin_top = 2
		skin.content_margin_bottom = 2
		_context_box.add_theme_stylebox_override("panel", skin)
		_context_box.set_meta("surface_warning", warning)
	_context_box.set_meta("warning", warning)
	_context_box.set_meta("grade", text.contains("Table") or text.contains("Standard") or text.contains("Feed"))
	_context.text = text
	_context_box.visible = not text.is_empty() and not (is_instance_valid(_barn_full_alert) and _barn_full_alert.visible) and _tutorial.is_empty() and not is_panel_open() and not (is_instance_valid(_state) and _state.run_over)
	var touch = get_parent().get("touch_controls")
	var touch_enabled: bool = is_instance_valid(touch) and touch.enabled
	if touch_enabled:
		_context_box.visible = _context_box.visible and (warning or _context_box.get_meta("grade", false))
	var seed_row: bool = is_instance_valid(_crop_row) and _crop_row.visible
	var layout_key: String = "%s|%s|%s|%s" % [text, root.size.x, touch_enabled, seed_row]
	if layout_key == _context_layout_key: return
	_context_layout_key = layout_key
	# Measure at the displayed font size; reflow only when the hint or layout changes.
	var font_size: int = 20 if touch_enabled else 13
	_context.add_theme_font_size_override("font_size", font_size)
	var width: float = clampf(_plain_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 24.0, 120.0, minf(480.0, root.size.x - 24.0))
	_context_box.offset_left = -width * 0.5
	_context_box.offset_right = width * 0.5
	_context_box.offset_top = -310 if touch_enabled else (-251 if seed_row else -152)
	_context_box.offset_bottom = -268 if touch_enabled else (-221 if seed_row else -122)
	_context.size.x = width - 12
	_context_box.size.y = 0
	# Wrapping updates minimum height during container layout; release the old height afterward.
	_context_box.set_size.call_deferred(Vector2(width, 0))

func _notice_is_warning(text: String) -> bool:
	var lower := text.to_lower()
	for word: String in ["unlock", "full", "not enough", "need ", "needs ", "empty", "frozen", "no seeds", "no water", "out of", "cannot", "can't", "could not"]:
		if lower.contains(word): return true
	return false

func _update_barn_full_alert() -> void:
	if not is_instance_valid(_barn_full_alert): return
	_barn_full_alert.visible = is_instance_valid(_state) and _state.storage_used() >= _state.capacity and not _state.run_over and _tutorial.is_empty() and not is_panel_open()
	if not _barn_full_alert.visible: return
	_barn_full_detail.text = "%s t stored · Sell crops to keep harvesting." % _number(_state.storage_used())
	var width: float = minf(520, root.size.x - 36)
	var top: float = 112
	var touch = get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		top = maxf(touch.status.get_global_rect().end.y, touch.sell_button.get_global_rect().end.y) + 12
		_barn_full_detail.add_theme_font_size_override("font_size", 19)
		_barn_full_sell.custom_minimum_size.y = 68
		_barn_full_sell.add_theme_font_size_override("font_size", 22)
	_barn_full_alert.offset_left = -width / 2
	_barn_full_alert.offset_right = width / 2
	_barn_full_alert.offset_top = top
	_barn_full_alert.offset_bottom = top
	_barn_full_alert.size.y = 0

func show_toast(text: String) -> void:
	if not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	_toast_label.text = text
	_toast_box.add_theme_stylebox_override("panel", Cozy.paper(Color("a5343c") if _notice_is_warning(text) else INK, 10, 6))
	_toast_layout_key = ""
	_layout_toast()
	_toast_box.show()
	_toast_box.move_to_front()
	_toast_timer.start()

func _layout_toast() -> void:
	var in_menu: bool = is_panel_open()
	var compact: bool = in_menu and root.size.y - _modal_card.get_global_rect().end.y < 60
	var weather_on_right: bool = is_instance_valid(_climate_console) and _climate_console.visible and _climate_console.position.x > root.size.x * 0.5
	var key: String = str([in_menu, compact, weather_on_right, _toast_label.text])
	if key == _toast_layout_key: return
	_toast_layout_key = key
	var width: float = 700 if in_menu else (302 if weather_on_right else 326)
	_toast_label.max_lines_visible = (1 if compact else 2) if in_menu else 3
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var toast_style: StyleBox = _toast_box.get_theme_stylebox("panel")
	toast_style.content_margin_top = 4 if compact else 8
	toast_style.content_margin_bottom = 4 if compact else 8
	_toast_label.size.x = width - 20
	# Ellipsis labels may report zero minimum height after their parent shrinks.
	# Reserve the actual wrapped lines so switching from a menu never blanks a toast.
	var lines: int = clampi(_toast_label.get_line_count(), 1, _toast_label.max_lines_visible)
	_toast_label.custom_minimum_size.y = lines * _toast_label.get_theme_font("font").get_height(_toast_label.get_theme_font_size("font_size"))
	_toast_box.position = Vector2((root.size.x-width)*.5, root.size.y-(42 if compact else 70)) if in_menu else Vector2(root.size.x-width-28,104)
	_toast_box.size = Vector2(width, 0)
	_toast_label.tooltip_text = _toast_label.text

func _layout_purchase() -> void:
	var touch: bool = is_instance_valid(get_parent().get("touch_controls")) and get_parent().touch_controls.enabled
	if not is_instance_valid(_purchase_box) or _purchase_receipt.is_empty(): return
	var menu: bool = is_instance_valid(_modal_card) and _modal.visible
	var bounds: Rect2 = _modal_card.get_rect() if menu else Rect2()
	var key: String = str([root.size, bounds, menu, touch])
	if key == _purchase_layout_key: return
	_purchase_layout_key = key
	# New counters are wider than the original menus. Wrap the receipt in
	# their actual outer margin instead of covering the right-hand controls.
	# TouchControls positions notices in the space above its mobile menus.
	var width: float = minf(230.0, root.size.x - bounds.end.x - 24.0) if menu and not touch else 230.0
	width = maxf(112.0, width)
	_purchase_title.add_theme_font_size_override("font_size", 16 if width < 180.0 else 18)
	_purchase_title.size.x = width - 28.0
	_purchase_detail.size.x = width - 28.0
	_purchase_box.size = Vector2(width, _purchase_title.get_minimum_size().y + _purchase_detail.get_minimum_size().y + 45.0)
	if not touch:
		_purchase_box.position = Vector2(root.size.x - width - (12.0 if menu else 28.0), 216.0)

func show_purchase(receipt: Dictionary) -> void:
	# Only committed purchases reach this method; failed affordability checks
	# keep their normal feedback and never create a success card.
	var kind: String = str(receipt.get("kind", ""))
	var quantity: int = int(receipt.get("quantity", 0))
	var cost: float = float(receipt.get("cost", -1.0))
	if kind not in ["seeds", "tool", "barn", "field", "duck"] or quantity <= 0 or not is_finite(cost) or cost < 0.0:
		return
	if not is_instance_valid(root):
		build_ui()
	var combined: Dictionary = receipt.duplicate(true)
	if kind == "seeds" and _purchase_remaining > 0.0 and _purchase_receipt.get("kind") == "seeds" and str(_purchase_receipt.get("id", "")) == str(receipt.get("id", "")):
		combined["quantity"] = int(_purchase_receipt.quantity) + quantity
		combined["cost"] = float(_purchase_receipt.cost) + cost
	_purchase_receipt = combined
	var item_name: String = str(combined.get("name", "Purchase"))
	var title: String = "+%d %s seeds" % [int(combined.quantity), item_name] if kind == "seeds" else item_name
	var detail: String = "Purchased"
	match kind:
		"seeds": detail = "Owned %d" % int(combined.get("total", quantity))
		"tool": detail = "Level %d" % int(combined.get("level", 1))
		"duck":
			if str(combined.get("id", "")) == "duck_patrol":
				title = "+1 patrol duck"
				detail = "%d on patrol" % int(combined.get("total", 1))
			else:
				detail = "%.0fs per bed" % float(combined.get("interval", 4.0 - float(combined.get("level", 1))))
		"barn":
			title = "+%d t barn capacity" % int(combined.quantity)
			detail = "Capacity %d t" % int(combined.get("total", quantity))
		"field":
			title = "+%d garden beds" % int(combined.quantity)
			detail = "%d beds unlocked" % int(combined.get("total", quantity))
	_purchase_title.text = title
	_purchase_detail.text = "%s · −%s" % [detail, _money(float(combined.cost))]
	_purchase_layout_key = ""
	_layout_purchase()
	_layout_purchase.call_deferred()
	_purchase_remaining = PURCHASE_SECONDS
	_purchase_bar.value = PURCHASE_SECONDS
	_purchase_box.show()

func show_reward(title: String, detail: String, rarity: String) -> void:
	if not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	_reward_title.size.x = 196.0
	_reward_detail.size.x = 196.0
	_reward_rarity.text = "★ " + rarity.to_upper()
	_reward_title.text = title
	_reward_detail.text = detail
	var content_height: float = _reward_rarity.get_minimum_size().y + _reward_title.get_minimum_size().y + _reward_detail.get_minimum_size().y + 50.0
	_reward_box.size = Vector2(230.0, content_height)
	_reward_box.show()
	_reward_box.move_to_front()
	_reward_timer.start()

func is_panel_open() -> bool:
	return (is_instance_valid(_modal) and _modal.visible) or (is_instance_valid(_conversation) and _conversation.visible)

func close_panel() -> void:
	_accounts_build_request += 1
	accounts_building = false
	if is_instance_valid(_state): _state.accounts_open = false
	if is_instance_valid(_modal_fade): _modal_fade.kill()
	_entrance_request += 1
	_finish_panel_entrance()
	if is_instance_valid(_conversation) and _conversation.visible: _conversation.finish()
	if is_instance_valid(_modal):
		_modal.hide()
	_panel_kind = ""
	_sync_panel_chrome()
	_refresh_seed_visibility()
	_reset_pending = false
	_apply_tutorial_visibility()
	_layout_purchase()
	_season_jobs.refresh()

func show_panel(kind: String, state: Node) -> void:
	if kind == "winter_stores": kind = "sell_potatoes"
	_accounts_build_request += 1
	accounts_building = false
	_state = state
	_state.accounts_open = kind == "accounts"
	if not is_instance_valid(root):
		build_ui()
	var opening: bool = not _modal.visible or kind != _panel_kind
	_entrance_request += 1
	_finish_panel_entrance()
	if kind != _panel_kind:
		_reset_pending = false
	_panel_kind = kind
	_body.add_theme_constant_override("separation", 6 if kind == "accounts" else 10)
	var paper: bool = kind in ["accounts", "run_summary"]
	(_modal.get_child(0) as ColorRect).color = Color(0.06, 0.13, 0.10, 0.28)
	_modal.z_index = 150 if paper else 0
	_modal_card.add_theme_stylebox_override("panel", Cozy.modal())
	_modal_card.offset_left = -376
	_modal_card.offset_right = 376
	_modal_card.offset_top = -317
	_modal_card.offset_bottom = 317
	if kind in ["market", "sell_potatoes"]:
		_modal_card.offset_left = -500
		_modal_card.offset_right = 500
		_modal_card.offset_top = -380
		_modal_card.offset_bottom = 380
	_modal_title.add_theme_color_override("font_color", CREAM)
	_modal_title.add_theme_font_override("font", _card_heading_font)
	_modal_title.add_theme_font_size_override("font_size", 28)
	_modal_subtitle.add_theme_font_override("font", _plain_font)
	_modal_subtitle.add_theme_color_override("font_color", Color("c5ccb7"))
	_modal_title.visible = kind not in ["market", "sell_potatoes"]
	_modal_subtitle.visible = kind not in ["market", "sell_potatoes"]
	for child: Node in _modal_market_nav.get_children():
		_modal_market_nav.remove_child(child)
		child.queue_free()
	_modal_market_nav.hide()
	_refs.clear()
	for child: Node in _modal_trade_footer.get_children():
		_modal_trade_footer.remove_child(child)
		child.queue_free()
	_modal_trade_footer.hide()
	for child: Node in _modal_fixed.get_children():
		_modal_fixed.remove_child(child)
		child.queue_free()
	_modal_fixed.hide()
	for child: Node in _body.get_children():
		if child == _modal_fixed: continue
		_body.remove_child(child)
		child.queue_free()
	var scroll: ScrollContainer = _body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0
	match kind:
		"farm_tip": _build_farm_tip()
		"market": _build_market()
		"sell_potatoes": _build_market(true)
		"barn", "inventory": _build_barn()
		"tools": _build_tools()
		"pause", "menu": _build_pause()
		"accounts":
			if DisplayServer.get_name() != "headless":
				_open_books(opening, _accounts_build_request)
				return
			_build_winter()
		"sleep_confirm": _build_sleep_confirm()
		"bank":
			_heading("The overdraft", "Edwin · Bank manager")
			_body.add_child(_wrap(_state.NpcRoster.bank_line(_state), 20, INK))
			_body.add_child(_wrap("Annual fixed bills: " + _state.money(_state.ledger.fixed_cost_total()) + ". Open Winter accounts for the full ledger.", 16, INK))
		"run_summary": _build_run_summary()
		"dex": _build_dex()
		"quests": _build_quests()
		"contracts": _build_contracts()
		"businesses":
			_heading("A second income", "WINTER · Plans for the coming year")
			_build_diversification()
		"loss_notices": _build_loss_notices()
		"activities": _build_activities()
		"duck_patrol": _build_duck_patrol()
		"debug": _build_debug()
		"measurement": _build_measurement()
		"graphics": _build_graphics()
		"climate": _build_climate()
		_: _build_help()
	_finish_panel_build(kind, opening)

func _finish_panel_build(kind: String, opening: bool) -> void:
	var paper: bool = kind in ["accounts", "run_summary"]
	_polish_card_typography(_body)
	_polish_card_typography(_modal_trade_footer)
	_polish_card_typography(_modal_market_nav)
	if paper:
		_paper_typography(_modal_card)
	_surface_text(_modal_card)
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 8
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(bottom_space)
	_refresh_panel()
	_modal.show()
	if is_instance_valid(_modal_fade): _modal_fade.kill()
	_modal.modulate.a = 1.0 if paper else 0.0
	_modal_fade = create_tween()
	_modal_fade.tween_property(_modal, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_barn_full_alert.hide()
	_context_box.hide()
	_farm_help_card.hide()
	_refresh_seed_visibility()
	_season_jobs.hide()
	_modal.move_to_front()
	_update_weather_ui()
	_apply_tutorial_visibility()
	_apply_tutorial_buttons()
	_layout_purchase.call_deferred()
	if is_instance_valid(get_parent().get("touch_controls")):
		get_parent().touch_controls.fit_modal()
		# Newly built content can settle its minimum size after the first fit.
		# Refit this frame rather than waiting for the periodic touch update.
		get_parent().touch_controls.fit_modal.call_deferred()
	if opening:
		_modal_motion.modulate.a = 0
		(_modal.get_child(0) as CanvasItem).modulate.a = 0
		_modal_entrance_shield.show()
		_begin_panel_entrance.call_deferred(kind, _entrance_request)
	_sync_panel_chrome()

func _open_books(opening: bool, request: int) -> void:
	accounts_building = true
	_paper_page()
	_heading("Opening the books…", "Winter · Time paused")
	_modal.show()
	_modal.modulate.a = 1
	_modal.move_to_front()
	_modal_entrance_shield.show()
	_season_jobs.hide()
	# Paint the status before the first cold font and portrait work.
	await get_tree().process_frame
	if request != _accounts_build_request: return
	await _build_winter(true, request)
	if request != _accounts_build_request: return
	accounts_building = false
	_finish_panel_build("accounts", opening)

func _accounts_frame(request: int) -> bool:
	_paper_typography(_modal_card)
	var touch = get_parent().get("touch_controls")
	if is_instance_valid(touch): touch.fit_modal()
	await get_tree().process_frame
	return request == _accounts_build_request and _panel_kind == "accounts"

func _begin_panel_entrance(kind: String, request: int) -> void:
	if request != _entrance_request or not _modal.visible or kind != _panel_kind: return
	_entrance_elapsed = 0
	_entrance_duration = ACCOUNTS_ENTRANCE_SECONDS if kind == "accounts" else PANEL_ENTRANCE_SECONDS
	_entrance_origin = panel_source_position(kind) - _modal_card.get_global_rect().get_center()
	_apply_panel_entrance()
	panel_opened.emit(kind)

func set_panel_source(station: String) -> void:
	_panel_source = station
	_panel_source_tick = Time.get_ticks_msec()

func panel_source_position(kind: String) -> Vector2:
	if kind in ["accounts", "run_summary"]:
		_panel_source = ""
		return ledger_screen_position()
	var places := {"market":"market", "sell_potatoes":"market", "barn":"barn", "inventory":"barn", "tools":"tools", "climate":"climate", "quests":"quests", "loss_notices":"quests", "contracts":"contracts", "bank":"bank", "businesses":"barn", "duck_patrol":"activities", "activities":"activities"}
	var station: String = _panel_source if not _panel_source.is_empty() and Time.get_ticks_msec() - _panel_source_tick < 1000 else str(places.get(kind, ""))
	_panel_source = ""
	var game = get_parent()
	var world = game.get("world")
	var farm_view = game.get("farm_viewport")
	if is_instance_valid(world) and is_instance_valid(world.camera) and is_instance_valid(farm_view):
		var point: Vector3 = world.station_position(station) + Vector3(0, 1.8, 0) if not station.is_empty() else world.player.position + Vector3(0, 1.8, 0)
		return world.camera.unproject_position(point) * root.size / Vector2(farm_view.size).max(Vector2.ONE)
	return root.size * Vector2(.5, .8)

func _surface_text(node: Node, fill: Color = INK) -> void:
	# Text follows the actual material underneath it, including optional cards.
	if node is Control:
		var surface: String = "normal" if node is BaseButton or node is Label else "panel"
		if node.has_theme_stylebox_override(surface):
			var skin: StyleBox = node.get_theme_stylebox(surface)
			var local_fill: Color = skin.bg_color if skin is StyleBoxFlat else skin.get_meta("surface_fill", Color.TRANSPARENT)
			fill = fill.blend(local_fill)
	if node is Label:
		var ink: Color = node.get_theme_color("font_color")
		if fill.get_luminance() < .45 and ink.get_luminance() < .62:
			node.add_theme_color_override("font_color", CREAM if ink == INK else ink.lightened(.62))
	for child in node.get_children(): _surface_text(child, fill)

func ledger_screen_position() -> Vector2:
	var game = get_parent()
	var world = game.get("world")
	var farm_view = game.get("farm_viewport")
	if is_instance_valid(world) and is_instance_valid(world.camera) and is_instance_valid(farm_view):
		return world.camera.unproject_position(world.ledger_book_position()) * root.size / Vector2(farm_view.size).max(Vector2.ONE)
	return root.size * Vector2(.5, .8)

func panel_entrance_duration() -> float:
	return _entrance_duration

func panel_entrance_progress() -> float:
	return clampf(_entrance_elapsed / _entrance_duration, 0, 1)

func panel_entrance_offset() -> Vector2:
	return _entrance_offset

func advance_panel_entrance(delta: float) -> void:
	if _entrance_elapsed >= _entrance_duration: return
	_entrance_elapsed = minf(_entrance_duration, _entrance_elapsed + maxf(0, delta))
	_apply_panel_entrance()

func _apply_panel_entrance() -> void:
	var progress: float = panel_entrance_progress()
	var eased: float = 1 - pow(1 - progress, 3)
	_entrance_offset = _entrance_origin * (1 - eased)
	# A render-only wrapper leaves the settled card rect intact for responsive
	# fitting. Its temporary input shield covers the translated presentation.
	RenderingServer.canvas_item_set_transform(_modal_motion.get_canvas_item(), Transform2D(0, _entrance_offset))
	_modal_motion.modulate.a = minf(1, progress * 3)
	(_modal.get_child(0) as CanvasItem).modulate.a = progress
	_modal_entrance_shield.visible = progress < 1

func _finish_panel_entrance() -> void:
	_entrance_elapsed = _entrance_duration
	_entrance_offset = Vector2.ZERO
	if is_instance_valid(_modal_motion):
		RenderingServer.canvas_item_set_transform(_modal_motion.get_canvas_item(), Transform2D.IDENTITY)
		_modal_motion.modulate.a = 1
	if is_instance_valid(_modal_entrance_shield): _modal_entrance_shield.hide()
	if is_instance_valid(_modal): (_modal.get_child(0) as CanvasItem).modulate.a = 1

func _fit_shop_modal() -> void:
	if _panel_kind not in ["barn", "inventory", "tools"] or not _modal.visible: return
	var touch = get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		touch.fit_modal()
		return
	var height: float = clampf(ShopPages.content_height(self), 240.0, minf(760.0, root.size.y - 40.0))
	_modal_card.offset_top = -height * 0.5
	_modal_card.offset_bottom = height * 0.5
	_layout_purchase.call_deferred()

func _heading(title: String, subtitle: String) -> void:
	_modal_title.text = title
	_modal_subtitle.text = subtitle
	_modal_subtitle.visible = not subtitle.is_empty()

func _reveal_details(control: Control) -> void:
	# Let the expanded contents settle before scrolling them into view.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return
	var target: Control = control.get_child(0) if control.get_child_count() > 0 else control
	(_body.get_parent() as ScrollContainer).ensure_control_visible(target)

func _details_section(key: String, title: String) -> VBoxContainer:
	var toggle := _button("Show " + title, "toggle_details:" + key)
	toggle.set_meta("section_title", title)
	_body.add_child(toggle)
	_refs[key + ":toggle"] = toggle
	var card := _surface("quest", GREEN)
	_body.add_child(card)
	_refs[key] = card
	var contents := _vbox(9)
	card.add_child(contents)
	card.hide()
	return contents

func _info(key: String, text: String = "", color: Color = GREEN, size: int = 14) -> Label:
	var label: Label = _wrap(text, size, color)
	_body.add_child(label)
	_refs[key] = label
	return label

func _offer(title: String, detail: String, text: String, action: String, primary: bool = false, parent: VBoxContainer = null) -> void:
	var card: PanelContainer = _surface("upgrade")
	var target: VBoxContainer = _body if parent == null else parent
	target.add_child(card)
	_refs[action + ":card"] = card
	var row: BoxContainer = _hbox(12)
	card.add_child(row)
	var offer_icons: Dictionary = {"activity:duck": {"kind": "activity", "id": "duck"}, "activity:duck:speed": {"kind": "metric", "id": "speed"}, "upgrade:hoe": {"kind": "tool", "id": "hoe"}, "upgrade:water": {"kind": "tool", "id": "water"}, "upgrade:harvest": {"kind": "tool", "id": "harvest"}, "upgrade:expansion": {"kind": "metric", "id": "beds"}, "upgrade:barn": {"kind": "build", "id": "farmer"}}
	if offer_icons.has(action): row.add_child(_icon(offer_icons[action], 48))
	var description: VBoxContainer = _vbox(3)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	description.add_child(_wrap(title, 17, INK, true))
	var detail_label: Label = _wrap(detail, 13, MUTED)
	description.add_child(detail_label)
	_refs[action + ":detail"] = detail_label
	if action in ["activity:duck", "activity:duck:speed"]:
		var value := _wrap("", 18, GREEN, true)
		description.add_child(value)
		_refs[action + ":value"] = value
		var status := _badge("")
		description.add_child(status)
		_refs[action + ":status"] = status
	var button: Button = _button(text, action, primary)
	button.custom_minimum_size.x = 146
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	_refs[action] = button

func _build_market(selling: bool = false) -> void:
	_heading("Sell Potatoes" if selling else "Buy Seeds", "")
	_modal_card.add_theme_stylebox_override("panel", Cozy.modal())
	var page = MarketPages.new()
	_body.add_child(page)
	_refs.market_page = page
	page.setup(self, selling)
	if not selling and _tutorial_seed_market():
		_refs.starter_continue = _button("Use my starter seeds →", "tutorial:next", true)
		_modal_trade_footer.add_child(_refs.starter_continue)
		_modal_trade_footer.show()


func _first_harvest_barn() -> bool:
	return not _tutorial.is_empty() and not bool(_tutorial.get("tour_only", false))

func _build_barn() -> void:
	# The first sale opens the crop shelf.
	if _first_harvest_barn():
		_inventory_tab = "crops"
	var page = ShopPages.new()
	_body.add_child(page)
	_refs.shop_page = page
	page.setup(self, true)

func _build_tools() -> void:
	var page = ShopPages.new()
	_body.add_child(page)
	_refs.shop_page = page
	page.setup(self, false)

func _style_choice(choice: OptionButton) -> void:
	choice.custom_minimum_size.y = 39
	choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	choice.add_theme_font_override("font", _card_button_font)
	choice.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		choice.add_theme_stylebox_override(state, Cozy.button_style(state, false))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		choice.add_theme_color_override(color, INK)
	choice.add_theme_color_override("font_disabled_color", MUTED)
	choice.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, 10, GOLD))
	var popup := choice.get_popup()
	popup.add_theme_stylebox_override("panel", Cozy.paper(CREAM, 8, 6, Color("b7c8af")))
	popup.add_theme_stylebox_override("hover", _style(Color("dcebd7"), 6, 6))
	popup.add_theme_font_override("font", _plain_font)
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)

func _build_dex() -> void:
	_heading("Crop varieties", "")
	_panel_crops = _known_crops()
	_info("dex_entries", "", CREAM, 14)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	var ids: Array = _state.CROP_IDS
	for index: int in range(ids.size()):
		var id: String = str(ids[index])
		var card := _card(Cozy.WOOD, 14)
		card.name = "VarietyBoard_" + id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var column := _vbox(6)
		card.add_child(column)
		var heading := _hbox(10)
		column.add_child(heading)
		var picture := _icon({"kind": "crop", "crop": id}, 76)
		picture.name = "DexPicture_" + id
		heading.add_child(picture)
		var title := _wrap("#%02d · %s" % [index + 1, _crop_name(id)], 18, CREAM, true)
		title.custom_minimum_size.x = 155
		heading.add_child(title)
		var status := _wrap("", 12, CREAM, true)
		column.add_child(status)
		_refs["dex_status:" + id] = status
		var detail := _wrap("", 15, INK, true)
		detail.add_theme_stylebox_override("normal", Cozy.paper(CREAM, 6, 3))
		detail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(detail)
		_refs["dex_detail:" + id] = detail
func _refresh_dex() -> void:
	_refs.dex_entries.text = "%d varieties" % _state.CROP_IDS.size()
	for id: String in _state.CROP_IDS:
		_refs["dex_status:" + id].text = "%ds base growth · Spud Valley" % _crop_grow(id)
		_refs["dex_detail:" + id].text = "%d t per bed" % int(_state.CropTable.CROPS[id]["yield"])

func _build_quests(show_losses: bool = false) -> void:
	var page = preload("res://scripts/tess_board.gd").new()
	_body.add_child(page); _refs.tess_board = page; page.setup(self, show_losses)

func _build_help() -> void:
	_heading("Controls", "")
	_modal_card.offset_left = -310
	_modal_card.offset_right = 310
	_modal_card.offset_top = -200
	_modal_card.offset_bottom = 200
	var entries: Array = [["Camera", "Hold click + drag"], ["Zoom", "Mouse wheel / pinch"], ["Recenter", "Home"], ["Move", "WASD / arrows"], ["Interact", "Click / E"], ["Sell", "F"], ["Hurry", "Hold H · 3×"]]
	if is_instance_valid(get_parent().get("touch_controls")) and get_parent().get("touch_controls").enabled:
		entries = [["Camera", "Drag farm"], ["Zoom", "Pinch"], ["Move", "Joystick"], ["Interact", "Tap bed or shop"], ["Recenter", "Tools → Recenter"], ["Hurry", "Hold to hurry · 3×"]]
	var controls := _vbox(10)
	_body.add_child(controls)
	for entry: Array in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		controls.add_child(row)
		var title := _label(entry[0], 16, INK, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(_label(entry[1], 16, INK))

func _account_row(parent: Node, title: String, value: String) -> Label:
	var row := preload("res://scripts/ledger_row.gd").new()
	parent.add_child(row)
	row.setup(self, title, value)
	if not parent.get_meta("ledger_leaf", false): row.add_theme_stylebox_override("panel", Cozy.paper(CREAM, 5, 1))
	return row.amount

func _ledger_leaf(parent: Control, contents: VBoxContainer) -> void:
	var leaf := PanelContainer.new()
	leaf.name = "LedgerLeaf"
	leaf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaf.add_theme_stylebox_override("panel", Cozy.paper(CREAM, 12, 3, Cozy.WOOD))
	contents.set_meta("ledger_leaf", true)
	parent.add_child(leaf)
	leaf.add_child(contents)

func ledger_row_font() -> Font:
	return _ledger_font

func _capture_ledger() -> void:
	if _panel_kind not in ["accounts", "run_summary"]: return
	if DisplayServer.get_name() == "headless":
		_refs.screenshot_status.text = "A rendered window is needed for a screenshot."
		return
	var footer_visible: bool = _modal_trade_footer.visible
	_modal_trade_footer.hide()
	_refs.screenshot_status.hide()
	await get_tree().process_frame
	RenderingServer.force_draw()
	var picture: Image = get_viewport().get_texture().get_image()
	last_screenshot_path = "user://taterland-ledger-year-%02d-%s.png" % [_state.season_clock.year, str(Time.get_unix_time_from_system()).replace(".", "-")]
	var error: Error = picture.save_png(last_screenshot_path)
	if OS.has_feature("web") and error == OK:
		JavaScriptBridge.download_buffer(picture.save_png_to_buffer(), last_screenshot_path.get_file(), "image/png")
	_modal_trade_footer.visible = footer_visible
	_refs.screenshot_status.show()
	_refs.screenshot_status.text = "Saved to " + ProjectSettings.globalize_path(last_screenshot_path) if error == OK else "Could not save screenshot."

func _ledger_actions() -> void:
	var actions := GridContainer.new()
	actions.columns = 2
	actions.set_meta("fixed_columns", 2)
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	_refs.ledger_actions = actions
	_modal_trade_footer.add_child(actions)
	_refs.ledger_screenshot = _button("Save screenshot", "ledger_screenshot")
	_refs.ledger_screenshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_refs.ledger_screenshot)
	_refs.screenshot_status = _wrap("", 12, MUTED)
	_refs.screenshot_status.hide()
	_modal_trade_footer.add_child(_refs.screenshot_status)

func touch_target() -> float:
	var scale: float = minf(float(get_tree().root.size.x) / root.size.x, float(get_tree().root.size.y) / root.size.y)
	return maxf(68, ceilf(44 / maxf(scale, 0.1)))

func _paper_typography(node: Node) -> void:
	if node is Label and not node.has_meta("ledger_row_type"):
		var heading: bool = node.get_theme_font("font") in [_card_heading_font, _heading_font, _paper_heading_font]
		var font: FontVariation = _paper_heading_font if heading else _paper_body_font
		node.add_theme_font_override("font", font)
	for child in node.get_children(): _paper_typography(child)

func _paper_page() -> void:
	_modal_card.offset_left = -550
	_modal_card.offset_right = 550
	_modal_card.offset_top = -370
	_modal_card.offset_bottom = 370
	_modal_card.add_theme_stylebox_override("panel", Cozy.paper(INK, 24, 5, Cozy.WOOD))

func _build_winter(staged: bool = false, request: int = 0) -> void:
	_paper_page()
	var clock = _state.season_clock
	_heading("The annual accounts", "Winter · Time paused")
	var stamp := _badge("FILED · YEAR %02d" % clock.year, "neutral")
	stamp.name = "LedgerYearStamp"
	stamp.set_meta("paper_stamp", true)
	var stamp_ink: StyleBoxFlat = Cozy.box(Color.TRANSPARENT, 5, 2, CHERRY)
	stamp_ink.set_border_width_all(2)
	stamp.add_theme_stylebox_override("normal", stamp_ink)
	stamp.add_theme_color_override("font_color", CHERRY)
	var filing := HBoxContainer.new(); filing.add_theme_constant_override("separation", 12)
	var book: Control = _icon({"kind": "place", "id": "ledger"}, 66)
	book.name = "LedgerDrawing"
	filing.add_child(book)
	filing.add_child(stamp)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; filing.add_child(spacer)
	var portrait := preload("res://scripts/npc_portrait.gd").new()
	portrait.custom_minimum_size = Vector2(52, 64); portrait.size_flags_horizontal = Control.SIZE_SHRINK_END; portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER; filing.add_child(portrait)
	_body.add_child(filing)
	portrait.show_person("nell")
	if staged and not await _accounts_frame(request): return
	var net: float = _state.ledger.total(clock.year)
	_refs.accounts_net = _label(("+" if net >= 0 else "−") + _state.money(absf(net)), 42, GREEN if net >= 0 else Color("a63529"), true)
	_refs.accountant = _wrap("Nell · Accountant", 14, MUTED)
	_body.add_child(_refs.accounts_net)
	_body.add_child(_label("NET FOR THE YEAR", 12, MUTED))
	var columns := _hbox(32)
	columns.name = "LedgerColumns"
	columns.resized.connect(func(): columns.vertical = columns.size.x < 640)
	_body.add_child(columns)
	var categories := _vbox(2)
	categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_leaf(columns, categories)
	categories.add_child(_label("THIS YEAR", 13, MUTED, true))
	for category in _state.Ledger.CATEGORIES:
		_refs["accounts_" + category] = _account_row(categories, _state.Ledger.LABELS[category], _state.money(_state.ledger.total(clock.year, category)))
		_refs["accounts_" + category].get_parent().get_parent().visible = not is_zero_approx(_state.ledger.total(clock.year, category))
		if staged and not await _accounts_frame(request): return
	_refs.accounts_guided_credit = _account_row(categories, _state.Ledger.GUIDED_CREDIT_LABEL, "")
	var credit_row = _refs.accounts_guided_credit.get_parent().get_parent()
	credit_row.caption.set_meta("ledger_wrap", true)
	credit_row.caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit_row._layout()
	credit_row.hide()
	var years := _vbox(2)
	years.custom_minimum_size.x = 245
	years.size_flags_horizontal = Control.SIZE_FILL
	_ledger_leaf(columns, years)
	years.add_child(_label("TEN-YEAR RECORD", 13, MUTED, true))
	for year in range(1, 11):
		_refs["accounts_year_%d" % year] = _account_row(years, "Year %d" % year, _state.money(_state.ledger.total(year)) if _state.ledger.is_closed(year) else "")
		_refs["accounts_year_%d" % year].get_parent().get_parent().visible = _state.ledger.is_closed(year)
		if staged and not await _accounts_frame(request): return
	var strip = preload("res://scripts/climate_strip.gd").new()
	strip.name = "AnnualClimateStrip"
	strip.setup(_state.climate.data.outlook.records, clock.year)
	_body.add_child(strip)
	_body.add_child(_refs.accountant)
	_refs.accounts_balance = _wrap("", 16, INK)
	var balance_row := HBoxContainer.new(); _body.add_child(balance_row)
	_refs.accounts_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL; balance_row.add_child(_refs.accounts_balance)
	_refs.accounts_loan = _wrap("", 16, INK)
	_body.add_child(_refs.accounts_loan)
	preload("res://scripts/place_ui.gd").help(self, balance_row, "Mortgage: %s interest + %s principal on the original %s loan. Fixed bills total %s per year.\n" % [_state.money(-_state.Ledger.FIXED_COSTS[0].amount), _state.money(-_state.Ledger.FIXED_COSTS[1].amount), _state.money(_state.Ledger.INITIAL_LOAN), _state.money(_state.ledger.fixed_cost_total())] + _state.NpcRoster.ledger_lines(_state))
	if staged and not await _accounts_frame(request): return
	for word in _state.Quality.GRADES:
		_refs["grade_sales:" + word] = _account_row(_body, word + " sales", "")
	var lease_heading := HBoxContainer.new(); _body.add_child(lease_heading)
	var lease_title := _wrap("FIELDS · leases for the coming year", 18, INK, true); lease_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lease_heading.add_child(lease_title)
	preload("res://scripts/place_ui.gd").help(self, lease_heading, "Rent renews each Winter. Cancel for a refund of that renewal; standing crops are cleared. Purchased bed expansions remain.")
	for field in _state.Land.IDS:
		if field == "home": continue
		_body.add_child(_wrap(_state.Land.NAMES[field], 16, INK))
		var row := _hbox(12)
		_body.add_child(row)
		if field != "home":
			row.add_child(_button(("Cancel lease" if _state.land[field].rented else "Rent · " + _state.money(_state.Land.RENTS[field]) + "/year"), "lease:" + field))
	if staged and not await _accounts_frame(request): return
	_build_diversification()
	if staged and not await _accounts_frame(request): return
	_build_loss_cards(_body, clock.year)
	if staged and not await _accounts_frame(request): return
	_ledger_actions()
	var resume: Button = _button("Read ten years", "run_summary", true) if _state.run_outcome == "completed" else _button("Walk out to the field", "close", true)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refs.ledger_actions.add_child(resume)
	_modal_trade_footer.show()

func _refresh_accounts() -> void:
	if accounts_building: return
	_refresh_diversification()
	if not _refs.has("accounts_net") or _refs.accounts_net.get_meta("entries", -1) == _state.ledger.entry_count(): return
	_refs.accounts_net.set_meta("entries", _state.ledger.entry_count())
	var net: float = _state.ledger.total(_state.season_clock.year)
	var credit: float = _state.ledger.guided_credit(_state.season_clock.year)
	_refs.accountant.text = "Nell: " + _state.NpcRoster.GUIDED_CREDIT_LINE if credit > 0 else "Nell · Accountant"
	_refs.accountant.tooltip_text = _state.NpcRoster.ledger_lines(_state)
	_refs.accounts_net.text = ("+" if net >= 0 else "−") + _state.money(absf(net))
	_refs.accounts_net.add_theme_color_override("font_color", GREEN if net >= 0 else Color("a63529"))
	for category in _state.Ledger.CATEGORIES:
		var amount: float = _state.ledger.total(_state.season_clock.year, category) - (credit if category == "other" else 0.0)
		_refs["accounts_" + category].text = _state.money(amount)
		_refs["accounts_" + category].get_parent().get_parent().visible = not is_zero_approx(amount)
	_refs.accounts_guided_credit.text = "+" + _state.money(credit)
	_refs.accounts_guided_credit.get_parent().get_parent().visible = credit > 0
	for year in range(1, 11):
		_refs["accounts_year_%d" % year].text = _state.money(_state.ledger.total(year)) if _state.ledger.is_closed(year) else ""
		_refs["accounts_year_%d" % year].get_parent().get_parent().visible = _state.ledger.is_closed(year)
	var grades: Dictionary = _state.Stock.sales(_state.ledger, _state.season_clock.year)
	for word in grades:
		_refs["grade_sales:" + word].text = "%d t · %s" % [grades[word].sacks, _state.money(grades[word].total)]
		_refs["grade_sales:" + word].get_parent().get_parent().visible = grades[word].sacks > 0
	_refs.accounts_balance.text = "Purse %s · Overdraft limit %s" % [_state.money(_state.coins), _state.money(_state.bankruptcy_limit())]
	_refs.accounts_loan.text = "Loan remaining " + _state.money(_state.ledger.loan_remaining())
	_refs.accounts_loan.visible = _state.ledger.loan_remaining() > 0
	_surface_text(_modal_card)

func _build_run_summary() -> void:
	_paper_page()
	_heading("Ten years on the farm", "FINAL ACCOUNTS · Spud Valley")
	_refs.run_title = _label(_state.run_title(), 32, GREEN, true)
	var summary_header := HBoxContainer.new(); _body.add_child(summary_header)
	_refs.run_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; summary_header.add_child(_refs.run_title)
	var keeper := preload("res://scripts/npc_portrait.gd").new(); keeper.custom_minimum_size = Vector2(52, 64); keeper.size_flags_vertical = Control.SIZE_SHRINK_CENTER; summary_header.add_child(keeper); keeper.show_person("nell")
	_body.add_child(_label(_state.money(_state.ledger.total()), 40, INK, true))
	_body.add_child(_label("NET OVER TEN YEARS", 12, MUTED))
	for category in _state.Ledger.CATEGORIES:
		if not is_zero_approx(_state.ledger.total(0, category)): _account_row(_body, _state.Ledger.LABELS[category], _state.money(_state.ledger.total(0, category)))
	var final_strip := preload("res://scripts/climate_strip.gd").new()
	final_strip.setup(_state.climate.data.outlook.records, 10)
	_body.add_child(final_strip)
	_ledger_actions()
	_account_row(_body, "Years in profit", "%d / 10" % _state.ledger.years_in_profit())
	var worst: Dictionary = _state.ledger.worst_year()
	var best: Dictionary = _state.ledger.best_year()
	_account_row(_body, "Worst year", "Year %d · %s" % [worst.year, _state.money(worst.net)])
	_account_row(_body, "Best year", "Year %d · %s" % [best.year, _state.money(best.net)])
	_account_row(_body, "Final purse", _state.money(_state.coins))
	_account_row(_body, "Loan remaining", _state.money(_state.ledger.loan_remaining()))
	_body.add_child(_wrap("The books close here. Your choices carry on for forty more years, under a sky that keeps changing.", 24, MUTED, true))
	for entry in [["Fifty years on", "epilogue"], ["Plant a new farm", "reset"], ["Year 10 accounts", "accounts"]]:
		var button := _button(entry[0], entry[1], entry[1] == "epilogue")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_refs.ledger_actions.add_child(button)
	_modal_trade_footer.show()


func _build_sleep_confirm() -> void:
	_modal_card.offset_left = -330
	_modal_card.offset_right = 330
	_modal_card.offset_top = -230
	_modal_card.offset_bottom = 230
	_heading("Sleep until Spring?", "WINTER · Year %d" % _state.season_clock.year)
	var quote: Dictionary = _state.winter_sleep_quote()
	_refs.sleep_quote = _wrap("%d t still in store · Late Winter %s total" % [quote.tonnes, _state.money(quote.peak_value)], 24, INK, true)
	_refs.sleep_quote.name = "WinterSleepQuote"
	_body.add_child(_refs.sleep_quote)
	_body.add_child(_wrap("Resolve the current weather, then wake at the Spring boundary. Stored sacks stay unsold and return to the barn.", 18, INK))
	if int(quote.tonnes) > 0:
		_body.add_child(_wrap("The late Winter value uses the grades now in store. Weather losses may change it.", 15, MUTED))
	var actions: BoxContainer = _hbox(10)
	_body.add_child(actions)
	var cancel: Button = _button("Keep working", "close")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(cancel)
	var confirm: Button = _button("Sleep until Spring", "confirm_sleep_spring", true)
	confirm.name = "ConfirmSleepUntilSpring"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.disabled = not _state.can_sleep_until_spring()
	actions.add_child(confirm)

func _build_pause() -> void:
	_heading("Your farm", "")
	if _state.season_clock.season == 3: _body.add_child(_button("Annual accounts", "accounts", true))
	if _state.can_sleep_until_spring():
		var sleep: Button = _button("Sleep until Spring", "sleep_spring")
		sleep.name = "MenuSleepUntilSpring"
		_body.add_child(sleep)
	if _state.run_outcome == "completed": _body.add_child(_button("Ten-year summary", "run_summary", true))
	var menu: GridContainer = GridContainer.new()
	menu.columns = 3
	menu.add_theme_constant_override("h_separation", 10)
	menu.add_theme_constant_override("v_separation", 10)
	_body.add_child(menu)
	var entries: Array = [["Inventory", "inventory", "I", "symbol"], ["Contracts", "contracts", "", "book"], ["Buy Seeds", "market", "B", "market"], ["Sell Potatoes", "sell_potatoes", "", "coin"], ["Debug", "debug", "", "debug"], ["Duck patrol", "activities", "", "duck"], ["Quests", "quests", "Q", "book"], ["Tool upgrades", "tools", "U", "hoe"], ["PotatoDex", "dex", "P", "magnify"]]
	if _tutorial.is_empty():
		entries.append(["Weather & protection", "climate", "", "book"])
	for entry: Array in entries:
		var tutorial_feature: String = str(entry[1])
		if tutorial_feature == "activities":
			tutorial_feature = "duck_patrol"
		elif tutorial_feature == "dex":
			tutorial_feature = "inventory"
		if not _tutorial.is_empty() and tutorial_feature not in _tutorial.get("features", []):
			continue
		var button: Button = _button("", str(entry[1]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 61
		menu.add_child(button)
		var row: BoxContainer = _hbox(6)
		button.add_child(row)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.offset_top = 8
		row.offset_bottom = -8
		var icon_kind: String = "activity" if entry[1] in ["activities", "duck_patrol", "debug"] else ("metric" if entry[3] == "coin" else ("tool" if entry[3] == "hoe" else "symbol"))
		row.add_child(_icon({"kind": icon_kind, "id": str(entry[3])}, 36))
		var name_label: Label = _wrap(str(entry[0]), 13, INK, true)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
	_body.add_child(_button("Settings & saves", "toggle_details:menu_settings"))
	var settings := _vbox(8)
	_body.add_child(settings)
	_refs.menu_settings = settings
	settings.hide()
	var utility: BoxContainer = _hbox(8)
	settings.add_child(utility)
	for entry: Array in [["Save farm", "save"], ["Load farm", "load"], ["Graphics", "graphics"], ["Controls", "help"]]:
		var button: Button = _button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(button)
	if _reset_pending:
		settings.show()
		settings.add_child(_wrap("Start over? This replaces your farm.", 14, CHERRY))
		settings.add_child(_button("Keep my farm", "cancel_reset"))
		settings.add_child(_button("Yes, start a new farm", "reset", true))
	else:
		var reset_button: Button = _button("Start a new farm…", "request_reset")
		reset_button.add_theme_font_size_override("font_size", 12)
		settings.add_child(reset_button)

	_body.add_child(_button("Back to the farm", "close", true))

func set_graphics_quality(mode: String) -> void:
	_graphics_quality = mode
	if _panel_kind == "graphics":
		_refresh_graphics()

func _build_graphics() -> void:
	_heading("Graphics", "")
	_info("graphics_current", "", GREEN, 19)
	for entry: Array in [["balanced", "Balanced", "Clear farm · gentle shadows"], ["smooth", "Smooth", "Faster farm · shadows off"], ["crisp", "Crisp", "Sharpest farm · needs more power"]]:
		var choice: Button = _button(str(entry[1]) + "\n" + str(entry[2]), "graphics:" + str(entry[0]))
		choice.custom_minimum_size.y = 70
		_body.add_child(choice)
		_refs["graphics_" + str(entry[0])] = choice
	_body.add_child(_label("SHADOW MAP", 15, INK, true))
	for size in [2048, 4096]:
		_refs["shadows_%d" % size] = _button(str(size), "shadows:%d" % size)
		_body.add_child(_refs["shadows_%d" % size])
	_body.add_child(_button("Back to farm", "close"))
	_refresh_graphics()

func _refresh_graphics() -> void:
	if not _refs.has("graphics_current"):
		return
	_refs.graphics_current.text = "Using " + _graphics_quality.capitalize()
	var game = get_parent()
	if game.get("shadow_size") != null:
		_refs.graphics_current.text += " · %d shadows" % game.shadow_size
		for size in [2048, 4096]: _refs["shadows_%d" % size].disabled = game.shadow_size == size or (game.touch_controls.enabled and size > 2048)
	for mode: String in ["balanced", "smooth", "crisp"]:
		_refs["graphics_" + mode].disabled = mode == _graphics_quality

func _refresh_panel() -> void:
	if _panel_kind == "accounts":
		_refresh_accounts()
		return
	if _panel_kind == "loss_notices":
		_refresh_loss_notices()
		return
	if _panel_kind == "businesses":
		_refresh_diversification()
		return
	if _panel_kind == "contracts":
		_refresh_contracts()
		return
	if _panel_kind == "climate":
		_refresh_climate()
		return
	if not is_instance_valid(_state):
		return
	_restore_tutorial_buttons()
	var coins: float = float(_state.get("coins"))
	var markets: Dictionary = _state.get("market")
	match _panel_kind:
		"market", "sell_potatoes":
			_refs.market_page.refresh()
		"barn", "inventory":
			_refresh_inventory()
			_refs.shop_page.refresh()
		"tools":
			for tool in ["hoe", "water", "harvest"]:
				var level: int = int(_state.tools[tool]); var costs: Array = _tool_costs()[tool]
				var maximum: bool = level >= costs.size()
				var effect: String = "%s per action" % TOOL_AREAS[tool][mini(level, TOOL_AREAS[tool].size() - 1)]
				if tool == "water": effect = "%d water · %s per action" % [16 + 16 * level, TOOL_AREAS[tool][mini(level, TOOL_AREAS[tool].size() - 1)]]
				_refs["upgrade:" + tool + ":detail"].text = effect
				var cost: float = 0.0 if maximum else costs[level]
				_set_purchase_button("upgrade:" + tool, "Fully upgraded" if maximum else "Upgrade · " + _money(cost), cost, maximum)
			_refs.shop_page.refresh()
		"dex": _refresh_dex()

		"activities":
			_refresh_activities()
		"duck_patrol":
			_refresh_duck_patrol()
		"debug":
			_refresh_debug()
		"quests": _refs.tess_board.refresh()
	_apply_tutorial_buttons()

func _set_button(key: String, text: String, disabled: bool) -> void:
	var button: Button = _refs.get(key) as Button
	if is_instance_valid(button):
		button.text = text
		button.disabled = disabled

func _set_purchase_button(key: String, caption: String, cost: float, blocked: bool = false) -> void:
	var quote: Dictionary = _state.purchase_quote(cost)
	_set_button(key, caption, blocked or not quote.affordable)
	var button: Button = _refs.get(key) as Button
	if is_instance_valid(button): button.tooltip_text = str(quote.reason)

func _money(value: float) -> String:
	return str(_state.call("money", value)) if is_instance_valid(_state) else "\uE000 %.0f" % value

func _number(value: float) -> String:
	return str(_state.call("format_number", value)) if is_instance_valid(_state) else "%.0f" % value

func _market_crops() -> Array[String]:
	if _tutorial_seed_market():
		return ["russet"]
	if not is_instance_valid(_state) or not _state.has_method("available_crops"):
		return preload("res://scripts/game_state.gd").crops_by_base_price(CROP_IDS)
	var result: Array[String] = []
	var available: Array = _state.call("available_crops")
	for id: Variant in available:
		result.append(str(id))
	return preload("res://scripts/game_state.gd").crops_by_base_price(result)

func _tutorial_seed_market() -> bool:
	return not _tutorial.is_empty() and "stock" not in _tutorial.get("features", [])

func _known_crops() -> Array[String]:
	var result: Array[String] = []
	var seeds: Dictionary = _state.get("seed_inventory") if is_instance_valid(_state) else {}
	var available: Array[String] = _market_crops()
	for id: String in _all_crop_ids():
		if id in CROP_IDS or id in available or (is_instance_valid(_state) and _state.stock_count(id) > 0) or float(seeds.get(id, 0)) > 0:
			result.append(id)
	return result

func _quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(_state) and _state.has_method("quest_info"):
		var quests: Array = _state.call("quest_info")
		for quest: Dictionary in quests:
			result.append(quest)
	return result

func _update_quest_sidebar() -> void:
	_quest_button.visible = true
	var ready: int = 0
	for quest: Dictionary in _quests():
		if bool(quest.get("complete", false)) and not bool(quest.get("claimed", false)):
			ready += 1
	_quest_button.text = "Claim %d reward%s  [Q]" % [ready, "" if ready == 1 else "s"] if ready > 0 else "Quest board  [Q]"

func _sync_crop_catalog() -> void:
	if _crop_defs.is_empty():
		_crop_defs = CropTable.CROPS
	for id: String in _all_crop_ids():
		if not _crop_buttons.has(id):
			_add_crop_chip(id)

func _all_crop_ids() -> Array[String]:
	var result: Array[String] = []
	if _crop_defs.is_empty():
		return ALL_CROP_IDS.duplicate()
	for key: Variant in _crop_defs.keys():
		result.append(str(key))
	return result

func _add_crop_chip(id: String) -> void:
	var button := preload("res://scripts/seed_slot.gd").new()
	_crop_row.add_child(button)
	button.setup(self, id)
	button.pressed.connect(func(): _act("crop:" + id))
	_crop_buttons[id] = button
	button.visible = id in _market_crops()

func _crop_name(id: String) -> String:
	var definition: Dictionary = _crop_defs.get(id, {})
	return str(definition.get("name", id.capitalize())).trim_suffix(" Potato")

func _crop_grow(id: String) -> int:
	var definition: Dictionary = _crop_defs.get(id, {})
	return int(definition.get("grow", CropTable.CROPS[id].grow))

func _crop_color(id: String) -> Color:
	var definition: Dictionary = _crop_defs.get(id, {})
	var value: Variant = definition.get("color", CropTable.CROPS[id].color)
	return value if value is Color else Color(str(value))

func _tool_costs() -> Dictionary:
	var constants: Dictionary = _state.get_script().get_script_constant_map()
	return constants.get("TOOL_COSTS", TOOL_COSTS)

func _flag(key: String) -> bool:
	return bool(_state.get(key)) if is_instance_valid(_state) else false

func _inventory_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(_state) and _state.has_method("inventory_info"):
		var data: Array = _state.call("inventory_info")
		for entry: Dictionary in data:
			result.append(entry)
	return result

func _inventory_id_string(entries: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("id", "")))
	return "|".join(ids)

func _set_inventory_tab() -> void:
	_refs["upgrade:barn:card"].visible = _inventory_tab == "crops"
	for section: Variant in _inventory_sections:
		_inventory_sections[section].visible = str(section) == _inventory_tab
		var button: Button = _refs.get("tab:" + str(section)) as Button
		if is_instance_valid(button):
			preload("res://scripts/place_ui.gd").tab(button, str(section) == _inventory_tab)

func _refresh_inventory() -> void:
	_set_inventory_tab()
	_refs.inventory_total.text = "HELD VALUE %s  ·  %s / %s t crop storage" % [_money(float(_state.call("barn_value"))), _number(float(_state.call("storage_used"))), _number(float(_state.get("capacity")))]
	for entry: Dictionary in _inventory_data():
		var id: String = str(entry.id)
		var key: String = "item:" + id
		if not _refs.has(key + ":title"): continue
		var kind: String = str(entry.kind)
		_refs[key + ":title"].text = str(entry.name) + (" · " + _number(float(entry.count)) + " t" if kind == "crop" else " ×" + _number(float(entry.count)) if kind == "seed" else "")
		var detail: String = str(entry.get("effect", ""))
		var button: Button = _refs.get(key + ":action") as Button
		match kind:
			"crop":
				detail = "Current value " + _money(float(entry.sell_value))
				if is_instance_valid(button):
					button.text = "View Winter stores" if _state.season_clock.season == 3 and _state.Stock.count(_state.trading.held, entry.crop) > 0 else "Sell potatoes"
					button.disabled = int(entry.count) <= 0
			"seed":
				if is_instance_valid(button):
					button.text = "Selected" if _state.selected_crop == entry.crop else "Select seeds"
					button.disabled = entry.crop not in _state.available_crops() or _state.selected_crop == entry.crop
			"tool":
				detail = "Rank %d · %s" % [int(entry.level), str(entry.effect)]
				if is_instance_valid(button): button.text = "Use tool"
		_refs[key + ":detail"].text = detail
		_refs[key + ":detail"].visible = not detail.is_empty()
	var barn_cost: float = float(_state.BARN_COSTS[mini(2, int(_state.barn_level))])
	var maxed: bool = int(_state.barn_level) >= 3
	_refs["upgrade:barn:detail"].text = "Maximum capacity" if maxed else "+%s t storage" % _number(200.0 * pow(4.0, int(_state.get("barn_level"))))
	_set_purchase_button("upgrade:barn", "Max level" if maxed else ("Upgrade · " + _money(barn_cost)), barn_cost, maxed)

func _catalog_number(key: String, fallback: float) -> float:
	var constants: Dictionary = _state.get_script().get_script_constant_map()
	return float(constants.get(key, fallback))

func _activity_info() -> Dictionary:
	if not is_instance_valid(_state):
		return {}
	var system: Object = _state.get("activity_system")
	return system.call("info") if system != null and system.has_method("info") else {}

func _build_activities() -> void:
	_build_duck_patrol()

func _build_duck_patrol() -> void:
	_heading("Duck patrol", "")
	_modal_card.offset_top = -380
	_modal_card.offset_bottom = 380
	_modal_card.add_theme_stylebox_override("panel", Cozy.modal())
	var hero_card := _card(Cozy.WOOD, 14)
	_body.add_child(hero_card)
	var hero: VBoxContainer = _vbox(7)
	hero_card.add_child(hero)
	var pond := preload("res://scripts/duck_pond_view.gd").new()
	hero.add_child(pond)
	_refs.duck_pond = pond
	var status: Label = _wrap("", 23, CREAM, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(status)
	_refs["activity_status"] = status
	var detail: Label = _wrap("", 14, CREAM.darkened(.1))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(detail)
	_refs["activity_detail"] = detail
	_offer("Add a duck", "", "Hire a duck", "activity:duck", true)
	_offer("Patrol speed", "", "Train ducks", "activity:duck:speed", true)
	for action: String in ["activity:duck", "activity:duck:speed"]:
		var skin: StyleBoxTexture = Cozy.paper(Cozy.WOOD, 14, 6, Cozy.WOOD.darkened(.25))
		_refs[action + ":card"].add_theme_stylebox_override("panel", skin)
		_refs[action + ":value"].add_theme_color_override("font_color", CREAM)
	_refresh_duck_patrol()

func _refresh_duck_patrol() -> void:
	if not _refs.has("activity:duck"):
		return
	var data: Dictionary = _activity_info()
	var count: int = int(data.get("duck_count", 0))
	var capacity: int = int(data.get("duck_capacity", 2))
	var speed: int = int(data.get("duck_speed", 0))
	var hire_cost: float = float(data.get("duck_cost", Balance.DUCK_HIRE_COST))
	var speed_cost: float = float(data.get("duck_speed_cost", Balance.DUCK_TRAINING_COSTS[0]))
	var coins: float = float(_state.coins)
	_set_purchase_button("activity:duck", "Flock full" if count >= capacity else ("Hire +1 · " + _money(hire_cost)), hire_cost, count >= capacity or _state.run_over)
	_refs["activity:duck:detail"].text = "%d / %d ducks" % [count, capacity]
	_set_purchase_button("activity:duck:speed", "Top speed" if speed >= 2 else ("Hire a duck first" if count == 0 else ("Faster · " + _money(speed_cost))), speed_cost, speed >= 2 or count == 0 or _state.run_over)
	_refs["activity:duck:speed:detail"].text = "%.0fs → %.0fs per bed" % [float(data.get("duck_interval", 4)), maxf(2.0, float(data.get("duck_interval", 4)) - 1.0)] if speed < 2 else "2s per bed · Maximum speed"
	if _refs.has("activity:duck:value"):
		_refs["activity:duck:value"].text = "Clears pests automatically"
		_refs["activity:duck:speed:value"].text = _refs["activity:duck:speed:detail"].text
		_refs["activity:duck:speed:detail"].text = "Whole flock"
		Cozy.badge(_refs["activity:duck:status"], "Complete" if count >= capacity else ("Affordable" if _state.can_purchase(hire_cost) else "Need Spudions"), "active" if count >= capacity or _state.can_purchase(hire_cost) else "warning")
		Cozy.badge(_refs["activity:duck:speed:status"], "Complete" if speed >= 2 else ("Locked · Hire a duck" if count == 0 else ("Affordable" if _state.can_purchase(speed_cost) else "Need Spudions")), "locked" if count == 0 else ("active" if speed >= 2 or _state.can_purchase(speed_cost) else "warning"))
	_refs.duck_pond.count = count
	_refs.duck_pond.capacity = capacity
	_refs.activity_status.text = "%d duck%s on patrol" % [count, "" if count == 1 else "s"] if count > 0 else "No ducks hired yet"
	_refs.activity_detail.text = "%.0fs per bed · %d pests cleared" % [float(data.get("duck_interval", 4)), int(data.get("duck_clears", 0))] if count > 0 else ""
	_refs.activity_detail.visible = count > 0

func _refresh_activities() -> void:
	_refresh_duck_patrol()

func _debug_info() -> Dictionary:
	return _state.debug_info()


func set_debug_session(unlocked: bool, speed: float = 1.0, error: String = "") -> void:
	var changed_access: bool = _debug_unlocked != unlocked
	_debug_unlocked = unlocked
	_debug_time_multiplier = speed if unlocked else 1.0
	_debug_access_error = error
	if _panel_kind != "debug":
		return
	if changed_access:
		show_panel("debug", _state)
	elif _refs.has("debug_access_error"):
		_refs.debug_access_error.text = error
	else:
		_refresh_debug()

func _focus_debug_code() -> void:
	if _panel_kind == "debug" and _refs.has("debug_code") and is_instance_valid(_refs.debug_code):
		_refs.debug_code.grab_focus()

func _build_measure_controls() -> void:
	var recorder = get_parent().get("frame_recorder")
	if not is_instance_valid(recorder): return
	var card := _card(PAPER, 14)
	_body.add_child(card)
	var column := _vbox(8)
	card.add_child(column)
	column.add_child(_label("FRAME TIME", 16, INK, true))
	var button := _button("Recording…" if recorder.recording else "Measure a year", "measure_year", true)
	button.disabled = recorder.recording or _state.run_over or _state.tutorial_active or _state.ClimateSystem.Lesson.active(_state)
	column.add_child(button)
	column.add_child(_wrap("Records through the next Winter accounts closing. No farm data changes.", 14, MUTED))
	if not recorder.report_text.is_empty(): column.add_child(_button("Last measurement", "measurement"))

func _build_measurement() -> void:
	_heading("Year frame times", "DEVICE MEASUREMENT")
	var report := TextEdit.new()
	report.name = "FrameTimeReport"
	report.text = get_parent().frame_recorder.report_text
	report.editable = false
	report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	report.custom_minimum_size.y = 480
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report.add_theme_font_override("font", _plain_font)
	report.add_theme_font_size_override("font_size", 18)
	_body.add_child(report)
	_body.add_child(_button("Copy", "measurement_copy", true))
	_refs.measurement_copy_status = _wrap("", 14, GREEN)
	_body.add_child(_refs.measurement_copy_status)
	_body.add_child(_button("Walk out to the field", "close"))

func _build_debug() -> void:
	_build_measure_controls()
	if not _debug_unlocked:
		_heading("Debug access", "Enter the access code to unlock controls for this session.")
		_info("debug_access_note", "Test funding and recovery change this saved farm. Ordinary gameplay stays paused after bankruptcy.", MUTED, 15)
		var code: LineEdit = LineEdit.new()
		code.secret = true
		code.max_length = 64
		code.placeholder_text = "Access code"
		code.custom_minimum_size = Vector2(0, 46)
		code.add_theme_color_override("font_color", INK)
		code.add_theme_color_override("font_placeholder_color", MUTED)
		code.add_theme_font_size_override("font_size", 18)
		code.add_theme_stylebox_override("normal", _style(PAPER, 10, 12, Color("c6d3bd")))
		code.add_theme_stylebox_override("focus", _style(CREAM, 10, 12, GREEN))
		code.text_submitted.connect(func(_text: String) -> void: _act("debug_unlock"))
		_body.add_child(code)
		_refs["debug_code"] = code
		_info("debug_access_error", _debug_access_error, CHERRY, 14)
		var unlock: Button = _button("Unlock debug", "debug_unlock", true)
		_body.add_child(unlock)
		_refs["debug_unlock"] = unlock
		call_deferred("_focus_debug_code")
		return
	_heading("Debug workshop", "Changes save to this farm. Progress is kept.")
	var data: Dictionary = _debug_info()
	_info("debug_balance", "", INK, 20)
	var funding := _card(PAPER, 14)
	_body.add_child(funding)
	var funds := _vbox(8)
	funding.add_child(funds)
	funds.add_child(_label("TEST FUNDS · EXACT BALANCE", 15, INK, true))
	var amount := DebugMoneyInput.new()
	amount.max_value = Balance.MAX_MONEY
	amount.value = Balance.STARTING_CASH if _flag("run_over") else maxf(0, float(_state.get("coins")))
	amount.placeholder_text = str(int(Balance.STARTING_CASH))
	amount.custom_minimum_size = Vector2(0, 42)
	amount.add_theme_font_size_override("font_size", 18)
	amount.add_theme_color_override("font_color", INK)
	amount.add_theme_stylebox_override("normal", _style(CREAM, 10, 10, Color("b9cbb4")))
	amount.add_theme_stylebox_override("focus", _style(CREAM, 10, 10, GREEN))
	amount.text_changed.connect(func(_text: String) -> void: _refresh_debug())
	funds.add_child(amount)
	_refs.debug_balance_input = amount
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 7)
	presets.add_theme_constant_override("v_separation", 7)
	funds.add_child(presets)
	for title: String in Balance.DEBUG_BALANCES:
		var preset := _button(title, "debug_balance_preset:" + str(int(Balance.DEBUG_BALANCES[title])))
		preset.tooltip_text = "Fill the input with test funds. Nothing changes until you apply."
		presets.add_child(preset)
	_refs.debug_balance_preview = _wrap("", 14, GREEN)
	funds.add_child(_refs.debug_balance_preview)
	var fund_actions := HFlowContainer.new()
	fund_actions.add_theme_constant_override("h_separation", 8)
	fund_actions.add_theme_constant_override("v_separation", 8)
	funds.add_child(fund_actions)
	_refs.debug_set_balance = _button("Set balance", "debug_set_balance", true)
	fund_actions.add_child(_refs.debug_set_balance)
	_refs.debug_recover = _button("Recover test farm", "debug_recover", true)
	fund_actions.add_child(_refs.debug_recover)
	funds.add_child(_wrap("Sets money directly, including from debt or \uE000 0. Recovery keeps your farm.", 13, MUTED))

	var time_card: PanelContainer = _card(PAPER, 14)
	_body.add_child(time_card)
	var time_column: VBoxContainer = _vbox(8)
	time_card.add_child(time_column)
	_refs["debug_time_status"] = _label("GAME TIME", 15, INK, true)
	time_column.add_child(_refs.debug_time_status)
	var time_row := HFlowContainer.new()
	time_row.add_theme_constant_override("h_separation", 8)
	time_column.add_child(time_row)
	for speed: int in [1, 2, 5, 10, 30]:
		var choice: Button = _button("%d×" % speed, "debug:time:%d" % speed)
		choice.custom_minimum_size.x = 74
		time_row.add_child(choice)
		_refs["debug_time_%d" % speed] = choice
	time_column.add_child(_wrap("Debug pauses game time while open. Outside this panel, 30× also speeds up weather.", 13, MUTED))

	var access := _card(PAPER, 14)
	_body.add_child(access)
	var access_body := _vbox(9)
	access.add_child(access_body)
	access_body.add_child(_label("WEATHER", 15, INK, true))
	var weather_tests := HFlowContainer.new()
	weather_tests.add_theme_constant_override("h_separation", 8)
	weather_tests.add_theme_constant_override("v_separation", 8)
	access_body.add_child(weather_tests)
	for weather: String in ["drought", "flood", "storm", "freeze"]:
		var test := _button("Test " + weather, "debug:weather:" + weather)
		weather_tests.add_child(test)
		_refs["debug_weather_" + weather] = test
	_refs.debug_weather_note = _wrap("", 13, MUTED)
	access_body.add_child(_refs.debug_weather_note)

	var advanced: VBoxContainer = _details_section("debug_advanced", "money multiplier")
	var number: DebugMoneyInput = DebugMoneyInput.new()
	number.max_value = float(data.get("money_limit", 100000))
	number.value = 1.0
	number.placeholder_text = "0.1 or 1e-20"
	number.custom_minimum_size = Vector2(0, 40)
	number.text_changed.connect(func(_text: String) -> void: _refresh_debug())
	advanced.add_child(number)
	_refs.debug_money = number
	var choices := HFlowContainer.new()
	advanced.add_child(choices)
	for value: String in ["0.01", "0.1", "1", "10", "100", "1000"]:
		choices.add_child(_button("×" + value, "debug_money:" + value))
	_refs.debug_preview = _wrap("", 14, GREEN)
	advanced.add_child(_refs.debug_preview)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 9)
	actions.add_theme_constant_override("v_separation", 9)
	advanced.add_child(actions)
	_refs.debug_apply = _button("Apply money once", "debug_apply", true)
	actions.add_child(_refs.debug_apply)
	_refs.debug_reset = _button("Reset time", "debug:reset")
	actions.add_child(_refs.debug_reset)
	advanced.add_child(_wrap("0.1 keeps 10% · 0 empties your purse. Multiplying debt increases debt. Reset keeps Spudions and all Debug history.", 13, MUTED))
	_body.add_child(_button("Lock debug · restore 1× time", "debug:lock"))
	_refresh_debug()
func _debug_money_value() -> Dictionary:
	var parsed: Dictionary = _refs.debug_money.read_number()
	if parsed.has("error"):
		return parsed
	var multiplier: float = float(parsed.value)
	var coins: float = float(_state.get("coins"))
	if coins > 0.0 and multiplier > 0.0 and coins * multiplier == 0.0:
		return {"error": "That result is too small to keep a nonzero balance. Use a larger multiplier, or 0 to clear money."}
	return parsed

func _refresh_debug() -> void:
	if not _refs.has("debug_money") or not _refs.has("debug_preview"):
		return
	var data: Dictionary = _debug_info()
	var coins: float = float(_state.get("coins"))
	var ended: bool = _flag("run_over")
	if _refs.has("debug_balance_input"):
		var balance: Dictionary = _refs.debug_balance_input.read_number()
		var valid: bool = not balance.has("error")
		_refs.debug_set_balance.visible = not ended
		_refs.debug_set_balance.disabled = not valid or ended
		_refs.debug_recover.visible = ended
		_refs.debug_recover.disabled = not valid or (valid and float(balance.value) <= 0.0)
		if not valid:
			_refs.debug_balance_preview.text = "Enter a balance from 0 to %s, such as %s." % [_number(Balance.MAX_MONEY), _number(Balance.STARTING_CASH)]
		else:
			_refs.debug_balance_preview.text = "%s to %s%s" % [_money(coins), _money(float(balance.value)), " · resume with progress kept" if ended else " · exact new balance"]
			if ended and float(balance.value) <= 0: _refs.debug_balance_preview.text = "Enter positive test funds to recover this farm."
		_refs.debug_balance_preview.add_theme_color_override("font_color", CHERRY if not valid or (ended and float(balance.get("value", 0)) <= 0) else GREEN)
	_refs.debug_balance.text = "CURRENT MONEY  " + _money(coins)
	_refs.debug_balance.tooltip_text = _money(coins)
	var parsed: Dictionary = _debug_money_value()
	_refs.debug_apply.disabled = parsed.has("error") or ended
	if parsed.has("error"):
		_refs.debug_preview.text = str(parsed.error)
		_refs.debug_preview.add_theme_color_override("font_color", CHERRY)
	else:
		var multiplier: float = float(parsed.value)
		var after: float = minf(Balance.MAX_MONEY, coins * multiplier)
		_refs.debug_preview.text = "APPLY ONCE  %s × %s → %s" % [_money(coins), str(multiplier), _money(after)]
		_refs.debug_preview.add_theme_color_override("font_color", CHERRY if after < float(_state.call("bankruptcy_limit")) else GREEN)
		if after < float(_state.call("bankruptcy_limit")): _refs.debug_preview.text += "\nBelow the overdraft limit. Foreclosure is assessed after Winter costs."
	_refs.debug_reset.disabled = is_equal_approx(_debug_time_multiplier, 1.0)
	_refs.debug_time_status.text = "GAME TIME · %d×" % int(_debug_time_multiplier)
	for speed: int in [1, 2, 5, 10, 30]:
		_refs["debug_time_%d" % speed].disabled = ended or is_equal_approx(_debug_time_multiplier, float(speed))
	var climate: Dictionary = _state.call("climate_info")
	var can_weather: bool = not ended and climate.phase == "calm" and not _state.ClimateSystem.Lesson.active(_state)
	for weather: String in ["drought", "flood", "storm", "freeze"]:
		_refs["debug_weather_" + weather].disabled = not can_weather
	_refs.debug_weather_note.text = "Starts a full 45-second warning; crops and stores can be lost." if can_weather else "Finish the current weather or lesson before starting a test."

func show_tutorial_feedback(message: String) -> void:
	if not _tutorial.is_empty():
		_tutorial_feedback.text = message
		_tutorial_feedback.show()

func _build_farm_help() -> void:
	# Keep the shared layout handle for older touch/capture callers. Contextual
	# advice is now opened from Help, never painted over the farm.
	_farm_help_card = PanelContainer.new()
	_farm_help_card.name = "FarmHelp"
	_farm_help_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_farm_help_card)
	_farm_help_card.hide()

func _update_farm_help() -> void:
	if not is_instance_valid(_farm_help_card) or not is_instance_valid(_state): return
	_farm_help_card.hide()
	_farm_tip = _state.farm_help.tip(_state)

func _build_farm_tip() -> void:
	if _opened_farm_tip.is_empty(): return
	_heading(str(_opened_farm_tip.title), "")
	_info("farm_tip_body", str(_opened_farm_tip.body), INK, 16)
	_body.add_child(_button(str(_opened_farm_tip.label), "farm_help:act", true))
	_body.add_child(_button("Back to help", "help"))

func modal_content_height() -> float:
	var column: VBoxContainer = _modal_card.get_child(0)
	var extra: float = _modal_card.get_theme_stylebox("panel").get_minimum_size().y
	var visible_children: int = 0
	for child in column.get_children():
		if not child is Control or not child.visible: continue
		visible_children += 1
		if child != _body.get_parent(): extra += child.get_combined_minimum_size().y
	extra += maxf(0, visible_children - 1) * column.get_theme_constant("separation")
	return _body.get_combined_minimum_size().y + extra


func _build_contracts() -> void:
	preload("res://scripts/buyer_slips.gd").build(self)
func _refresh_contracts() -> void:
	preload("res://scripts/buyer_slips.gd").refresh(self)

func _build_diversification() -> void:
	if _state.season_clock.year < _state.Diversification.Balance.DIVERSIFY_YEAR: return
	_body.add_child(_label("DIVERSIFY OR DOUBLE DOWN", 18, INK, true))
	var descriptions: Dictionary = {
		"shop": "Earn %s each Winter after a full year. Running the shop shortens each Summer by %d seconds (%d seconds to farm)." % [_state.money(_state.Diversification.Balance.SHOP_INCOME), _state.Diversification.Balance.SHOP_SUMMER_SECONDS, _state.SeasonClock.SEASON_SECONDS - _state.Diversification.Balance.SHOP_SUMMER_SECONDS],
		"grower": "From next Spring, accept two different orders at %.1f× the ordinary contract price. Shortfall penalties still apply." % _state.Diversification.Balance.GROWER_PRICE_FACTOR,
		"lodging": "Earn up to %s each Winter after a full year: %s per completed tank, drainage, windbreak or frost-cover project. Levels do not stack; no protections means no guests." % [_state.money(_state.Diversification.Balance.LODGING_INCOME), _state.money(_state.Diversification.Balance.LODGING_INCOME / 4.0)],
	}
	var effects: Dictionary = {
		"shop": "+%s/year · Summer −%ds" % [_state.money(_state.Diversification.Balance.SHOP_INCOME), _state.Diversification.Balance.SHOP_SUMMER_SECONDS],
		"grower": "2 orders · price +%d%%" % roundi((_state.Diversification.Balance.GROWER_PRICE_FACTOR - 1.0) * 100),
		"lodging": "+%s/protection · max %s/year" % [_state.money(_state.Diversification.Balance.LODGING_INCOME / 4.0), _state.money(_state.Diversification.Balance.LODGING_INCOME)],
	}
	var grid := GridContainer.new()
	grid.name = "WinterBusinessTiles"
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.resized.connect(func(): grid.columns = 3 if grid.size.x >= 900 else 1)
	_body.add_child(grid)
	var Place = preload("res://scripts/place_ui.gd")
	for id in _state.Diversification.NAMES:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", Place.skin())
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
		var column := _vbox(8); tile.add_child(column)
		var title := HBoxContainer.new(); column.add_child(title)
		var label := _wrap(_state.Diversification.NAMES[id], 18, INK, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.add_child(label)
		Place.help(self, title, descriptions[id])
		var effect := _wrap(effects[id], 16, MUTED)
		effect.name = "BusinessEffect_" + id; column.add_child(effect)
		_refs["diversify:" + id] = _button("", "diversify:" + id)
		_refs["diversify:" + id].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Place.pill(_refs["diversify:" + id], GREEN)
		column.add_child(_refs["diversify:" + id])
	_refs.business_ledger = _wrap("", 16, INK)
	_body.add_child(_refs.business_ledger)
	_refresh_diversification()

func _refresh_diversification() -> void:
	if not _refs.has("business_ledger"): return
	for id in _state.Diversification.NAMES:
		var owned: bool = _state.diversification.owns(id)
		_refs["diversify:" + id].text = ("Enrolled" if id == "grower" else "Built") if owned else ("Enrol free" if id == "grower" else "Build · " + _state.money(_state.Diversification.Balance.BUSINESS_COSTS[id]))
		_refs["diversify:" + id].disabled = not _state.diversification.can_buy(_state, id)
	var lines := PackedStringArray()
	for entry in _state.ledger.entries:
		if int(entry.year) != _state.season_clock.year: continue
		if entry.label in _state.Diversification.BUILD_LABELS.values() or entry.label in _state.Diversification.INCOME_LABELS.values() or str(entry.label).begins_with("Contract grower "):
			lines.append(entry.label + (" · " + _state.money(entry.amount) if not is_zero_approx(entry.amount) else ""))
	_refs.business_ledger.text = "\n".join(lines)
	_refs.business_ledger.visible = not lines.is_empty()

func _build_loss_notices() -> void:
	_build_quests(true)
func _refresh_loss_notices() -> void:
	_refs.tess_board.refresh()

func _build_loss_cards(parent: Control, year: int, show_empty: bool = false) -> void:
	var Place = preload("res://scripts/place_ui.gd")
	var count: int = 0
	for entry in _state.climate.data.protection.losses:
		if int(entry.year) != year: continue
		var card := PanelContainer.new(); card.name = "PinnedCauseNote"
		card.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 18, 7)); parent.add_child(card)
		var note := _vbox(8); card.add_child(note)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); note.add_child(row)
		row.add_child(_icon({"kind": "event", "id": entry.event}, 36))
		row.add_child(_wrap("%s · %s" % [str(entry.event).replace("_", " ").capitalize(), _state.Land.NAMES.get(entry.field, "Barn")], 19, INK, true))
		note.add_child(_wrap("Lost %d t of %s" % [entry.sacks, _crop_name(entry.crop)], 20, INK, true))
		note.add_child(_wrap("Worth %s" % _money(entry.sacks * _state.CropTable.CROPS[entry.crop].base), 15, MUTED))
		note.add_child(_wrap(_state.ClimateSystem.Protection.counterfactual(entry), 16, INK))
		var stamp := _wrap("Year %d · %s" % [entry.year, _state.SeasonClock.NAMES[entry.season]], 13, MUTED); note.add_child(stamp)
		var pin = preload("res://scripts/paper_detail.gd").new(); pin.kind = "pin"; card.add_child(pin); pin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count += 1
	if count == 0 and show_empty: parent.add_child(_wrap("No crop losses recorded.", 16, MUTED))
