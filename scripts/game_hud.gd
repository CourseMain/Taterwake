class_name GameHUD
extends CanvasLayer

signal action_requested(action: String)
signal roll_revealed(title: String, detail: String, rarity: String)

class DebugMoneyInput extends LineEdit:
	# Range/SpinBox displays tiny positive values as zero. Keep the original
	# text until Apply, and normalize decimals before Godot's float conversion.
	var max_value: float = 1e6
	var value: float:
		get:
			return float(read_number().get("value", 1.0))
		set(new_value):
			text = String.num_scientific(new_value)

	func get_line_edit() -> LineEdit:
		return self

	func read_number() -> Dictionary:
		return parse_number(text, max_value)

	static func parse_number(raw: String, maximum: float = 1e6) -> Dictionary:
		var source: String = raw.strip_edges().to_lower()
		var pattern: RegEx = RegEx.new()
		pattern.compile("^[+]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:e[+-]?[0-9]+)?$")
		if source.length() > 256 or pattern.search(source) == null:
			return {"error": "Enter a number from 0 to 1e6, such as 0.1 or 1e-20."}
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
			return {"error": "The largest money multiplier is 1e6."}
		var significant: String = digits.substr(first, 1) + "." + digits.substr(first + 1, 16)
		while significant.ends_with("0"):
			significant = significant.left(-1)
		significant = significant.trim_suffix(".")
		var canonical: String = significant + "e" + str(exponent)
		var parsed: float = float(canonical)
		if not is_finite(parsed) or parsed > maximum:
			return {"error": "The largest money multiplier is 1e6."}
		if parsed <= 0.0:
			return {"error": "That positive multiplier is too small. Enter 0 explicitly to clear money."}
		return {"value": parsed, "canonical": canonical}

const Sparkline = preload("res://scripts/price_sparkline.gd")
const RollReel = preload("res://scripts/roll_spinner.gd")
const RollLuckMeter = preload("res://scripts/roll_luck_meter.gd")
const MarketImpact = preload("res://scripts/market_impact.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const EquipmentPreview = preload("res://scripts/equipment_preview.gd")
const Type = preload("res://scripts/ui_type.gd")
const ClimateIcon = preload("res://scripts/climate_icon.gd")
const UI_FONT = preload("res://assets/fonts/NunitoSans.ttf")
const UI_SYMBOLS = preload("res://assets/fonts/NotoSansSymbols.ttf")
const UI_SYMBOLS_2 = preload("res://assets/fonts/NotoSansSymbols2.ttf")
const RewardFeedback = preload("res://scripts/reward_feedback.gd")
const BlindRules = preload("res://scripts/blind_rules.gd")
const CASINO: Color = Color("2b1d40")
const CASINO_LIGHT: Color = Color("bca5da")
const INK: Color = Color("17382d")
const MUTED: Color = Color("667569")
const CREAM: Color = Color("fffbed")
const PAPER: Color = Color("f3efdf")
const GREEN: Color = Color("377858")
const GOLD: Color = Color("d9a948")
const CHERRY: Color = Color("bb654d")
const CROP_IDS: Array[String] = ["russet", "golden", "giant", "radioactive"]
const ALL_CROP_IDS: Array[String] = ["russet", "golden", "giant", "radioactive", "sunburst"]
const SHORES_PAPER: Color = Color("fff0d8")
const CORAL: Color = Color("bf7058")
const CROP_NAMES: Dictionary = {"russet": "Russet", "golden": "Golden", "giant": "Giant", "radioactive": "Radioactive", "sunburst": "Sunburst"}
const CROP_COLORS: Dictionary = {"russet": Color("b48a52"), "golden": GOLD, "giant": Color("b16f50"), "radioactive": Color("71a557"), "sunburst": Color("da9334")}
const GROW_TIMES: Dictionary = {"russet": 10, "golden": 25, "giant": 40, "radioactive": 50, "sunburst": 55, "icecap": 60}
const TOOL_COSTS: Dictionary = {"hoe": [300, 12000], "water": [450, 15000], "harvest": [600, 20000]}
const TOOL_AREAS: Dictionary = {"hoe": ["1 tile", "3 tiles", "3 × 3 tiles", "5 × 5 tiles"], "water": ["1 tile", "3 × 3 tiles", "5 × 5 tiles", "7 × 7 tiles"], "harvest": ["1 tile", "one full row", "three full rows", "five full rows"]}
const PURCHASE_SECONDS: float = 3.2

var _conversation: Control
var root: Control
var _state: Node
var _plain_font: FontVariation = Type.face(Type.BODY, 400.0)
var _card_heading_font: FontVariation = Type.face(Type.SHOP, 600.0)
var _card_button_font: FontVariation = Type.face(Type.DISPLAY, 600.0)
var _font: Font
var _heading_font: Font
var _top: Dictionary = {}
var _crop_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _selected_tool: String = "hoe"
var _crop_detail: Label
var _context: Label
var _combo_box: PanelContainer
var _combo_label: Label
var _combo_bar: ProgressBar
var _purchase_box: PanelContainer
var _purchase_title: Label
var _purchase_detail: Label
var _purchase_bar: ProgressBar
var _purchase_remaining: float = 0.0
var _purchase_receipt: Dictionary = {}
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
var _modal_fixed: VBoxContainer
var _panel_kind: String = ""
var _build_selection: String = ""
const BuildPages = preload("res://scripts/build_pages.gd")
var _panel_island: int = 0
var _refs: Dictionary = {}
var _reset_pending: bool = false
var _all_in_pending: bool = false
var _island_button: Button
var _sidebar_box: PanelContainer
var _quest_button: Button
var _export_box: PanelContainer
var _export_title: Label
var _export_detail: Label
var _export_bar: ProgressBar
var _visual_island: int = 0
var _panel_crops: Array[String] = []
var _tool_caption: Label
var _context_box: PanelContainer
var _hover_context: String = ""
var _farm_hint: String = ""
var _farm_hint_remaining: float = 0.0
var _farm_busy_remaining: float = 0.0
var _quick_sell: Button
var _modal_card: PanelContainer
var _spinner: Control
var _rolling: bool = false
var _frozen_coins: float = 0.0
var _revealed_roll: Dictionary = {}
var _crop_row: BoxContainer
var _crop_defs: Dictionary = {}
var _stake_kind: String = "normal"
var _frozen_odds: Array = []
var _frozen_luck: float = 1.0
var _frozen_luck_math: String = ""
var _frozen_luck_breakdown: Dictionary = {}
var _frozen_build_quality: float = 1.0
var _frozen_stake_bonus: float = 0.0
var _inventory_sections: Dictionary = {}
var _inventory_tab: String = "crops"
var _dex_tab: String = "mutations"
var _inventory_signature: String = ""
var _market_impact: Control
var _builds_button: Button
var _tracked_row: BoxContainer
var _tracked_labels: Dictionary = {}
var _tracked_prices: Dictionary = {}
var _price_moves: Dictionary = {}
var _tracked_signature: String = ""
var _crate_reel: bool = false
var _tracked_box: PanelContainer
var _surge_style: StyleBoxFlat
var _surge_urgent: bool = false
var _surge_active: bool = false
var _hud_clock: float = 0.0
var _batch_results: Array = []
var _batch_kind: String = "normal"
var _trophies_open: bool = false
var _trophy_signature: String = ""
var _frozen_crown: bool = false
var _farm_tip: Dictionary = {}
var _farm_help_card: PanelContainer
var _farm_help_action: Button
var _opened_farm_tip: Dictionary = {}
var _help_cooldown: float = 0.0
var _tutorial: Dictionary = {}
var _tutorial_card: PanelContainer
var _tutorial_title: Label
var _tutorial_body: Label
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
var _blind_card: PanelContainer
var _blind_labels: Dictionary = {}
var _run_end: Control
var _run_end_title: Label
var _run_end_detail: Label
var _blind_modal_warning: Label
var _climate_console: PanelContainer
var _weather_button: Button
var _climate_intro: Control
var _climate_alert: Control
var _climate_effect: Control
var _collapse_hidden: Array[CanvasItem] = []
var _plot_action_box: PanelContainer
var _plot_action_label: Label
var _plot_action_text: String = ""

func _process(delta: float) -> void:
	_hud_clock += delta
	_help_cooldown = maxf(0.0, _help_cooldown - delta)
	_farm_hint_remaining = maxf(0.0, _farm_hint_remaining - delta)
	_farm_busy_remaining = maxf(0.0, _farm_busy_remaining - delta)
	_update_context()
	_update_farm_help()
	if _purchase_remaining > 0.0:
		_purchase_remaining = maxf(0.0, _purchase_remaining - delta)
		_purchase_bar.value = _purchase_remaining
		if _purchase_remaining == 0.0:
			_purchase_box.hide()
			_purchase_receipt.clear()
	if not _tutorial.is_empty():
		_apply_tutorial_visibility()
		_update_tutorial_pointer()
		return
	if not is_instance_valid(_surge_style):
		return
	var accent: Color = _island_accent()
	var pulse: float = pow(0.5 + 0.5 * sin(_hud_clock * TAU * 1.8), 3.0)
	_surge_style.bg_color = Color("132c29").lerp(accent, (0.14 + pulse * 0.22) if _surge_urgent or _surge_active else 0.025)
	_surge_style.border_color = accent * (1.0 if _surge_urgent or _surge_active else 0.65)
	_surge_style.shadow_color = Color(accent, (0.2 + pulse * 0.28) if _surge_urgent or _surge_active else 0.0)
	_export_title.scale = Vector2.ONE * (1.0 + pulse * 0.022 if _surge_urgent else 1.0)
	_export_title.pivot_offset = _export_title.size * 0.5

func _island_accent() -> Color:
	return Color("32ff8c") if _island_id() == 1 else (Color("ffd22b") if _island_id() == 2 else Color("39bcff"))

func _refresh_seed_visibility() -> void:
	var showing: bool = _selected_tool == "plant" and _plot_action_text.is_empty() and not is_panel_open() and (_tutorial.is_empty() or "plant" in _tutorial.get("tools", []))
	if is_instance_valid(_crop_row):
		_crop_row.visible = showing
		var first_seed: bool = not _tutorial.is_empty() and "stock" not in _tutorial.get("features", [])
		_crop_row.anchor_left = 0.5 if first_seed else 0.0
		_crop_row.anchor_right = 0.5 if first_seed else 1.0
		_crop_row.offset_left = -150.0 if first_seed else 28.0
		_crop_row.offset_right = 150.0 if first_seed else -28.0
	if is_instance_valid(_tracked_box):
		_tracked_box.visible = showing and not _tracked_ids().is_empty() and (_tutorial.is_empty() or "stock" in _tutorial.get("features", []))
	if is_instance_valid(_context_box):
		_context_box.offset_top = -274 if showing else -152
		_context_box.offset_bottom = -244 if showing else -122


func build_ui() -> void:
	if is_instance_valid(root):
		return
	layer = 10
	var body_font: FontVariation = FontVariation.new()
	body_font.base_font = UI_FONT
	body_font.fallbacks = [UI_SYMBOLS, UI_SYMBOLS_2]
	var weight_axis: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	body_font.variation_opentype = {weight_axis: 400.0}
	_font = body_font
	var title_font: FontVariation = FontVariation.new()
	title_font.base_font = Type.DISPLAY
	title_font.fallbacks = [UI_SYMBOLS, UI_SYMBOLS_2]
	title_font.variation_opentype = {weight_axis: 600.0}
	_heading_font = title_font
	root = Control.new()
	root.name = "TaterlandHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	theme.default_font = _font
	theme.default_font_size = 15
	root.theme = theme
	add_child(root)
	_market_impact = MarketImpact.new()
	root.add_child(_market_impact)
	_climate_effect = load("res://scripts/climate_effect.gd").new()
	root.add_child(_climate_effect)
	_build_top()
	_build_sidebar()
	_build_footer()
	_build_notices()
	_build_export_strip()
	_build_blind_card()
	_build_modal()
	_climate_console = load("res://scripts/climate_console.gd").new()
	root.add_child(_climate_console)
	_climate_console.operated.connect(func(action: String) -> void: _act("climate_operate:" + action))
	_climate_console.opened.connect(func() -> void: _act("climate"))
	_build_tutorial()
	_build_farm_help()
	_build_plot_action()
	_climate_alert = load("res://scripts/climate_alert.gd").new()
	root.add_child(_climate_alert)
	_climate_alert.continue_requested.connect(func() -> void: _act("climate_continue"))
	_climate_intro = preload("res://scripts/climate_intro.gd").new()
	root.add_child(_climate_intro)
	_climate_intro.finished.connect(func(): _act("climate_continue"))
	_build_run_end()

func _build_blind_card() -> void:
	_blind_card = _card(Color("172e2b"), 12)
	_blind_card.name = "BlindForecast"
	_place(_blind_card, Rect2(28, 164, 302, 48))
	var column: BoxContainer = _hbox(8)
	_blind_card.add_child(column)
	for entry: Array in [["title", 13, GOLD], ["balance", 19, CREAM], ["debt", 12, CHERRY], ["weather", 12, Color("d7b18e")]]:
		var label: Label = _label("", int(entry[1]), entry[2])
		label.add_theme_font_override("font", _plain_font)
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(label)
		_blind_labels[entry[0]] = label
	_blind_card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_act("taxes")
	)
	_blind_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _build_run_end() -> void:
	_run_end = load("res://scripts/climate_collapse.gd").new()
	root.add_child(_run_end)
	_run_end_title = _run_end.headline
	_run_end_detail = _run_end.detail
	_run_end.restart_requested.connect(func() -> void: _act("reset"))
	_run_end.debug_requested.connect(func() -> void: _act("debug"))

func _update_blind_ui() -> void:
	if not is_instance_valid(_state) or not _state.has_method("blind_info"):
		return
	var info: Dictionary = _state.call("blind_info")
	var climate: Dictionary = _state.call("climate_info")
	var water_count: Label = _tool_buttons.water.get_meta("water_count")
	water_count.text = "%d/%d" % [floori(climate.supply.can), int(climate.can_capacity)]
	water_count.add_theme_color_override("font_color", Color("ffd39f") if float(climate.supply.can) < 1.0 else CREAM)
	_tool_buttons.water.tooltip_text = "Watering can: %d / %d water. Each watered bed uses 1. Click the tank to refill." % [floori(climate.supply.can), int(climate.can_capacity)]
	_climate_console.refresh(climate, _island_id(), is_panel_open() or bool(info.run_over) or not _tutorial.is_empty() or climate.intro_pending or not _plot_action_text.is_empty())
	_climate_effect.set_weather(climate, _island_id(), bool(info.run_over) or not _tutorial.is_empty())
	_blind_card.visible = _tutorial.is_empty() and not is_panel_open() and not bool(info.run_over) and not _state.ClimateSystem.Lesson.active(_state)
	_blind_labels.title.text = "Tax in %ds" % ceili(info.due_in) if info.due_in > 0.0 else "Tax · %d stocks left" % (int(info.booms_required) - int(info.booms))
	_blind_labels.balance.text = "%s due  ›" % _blind_money(info.target)
	_blind_labels.title.add_theme_color_override("font_color", Color("ffb85e") if info.tax_boom else GOLD)
	_blind_labels.balance.add_theme_color_override("font_color", CREAM if info.cleared else Color("ff7777"))
	_blind_card.tooltip_text = "Cash %s · %s covered\nAfter tax %s · Bankruptcy below %s\nClick for forecast, rates and last payment" % [_blind_money(info.current), str(_state.call("blind_progress_text", float(info.ratio))), _blind_money(info.projected), _blind_money(info.bankruptcy)]
	_blind_labels.debt.hide()
	_blind_labels.debt.text = "Bankruptcy below " + _blind_money(info.bankruptcy)
	_blind_labels.weather.hide()
	_weather_button.visible = _island_id() >= 2 and _tutorial.is_empty() and not is_panel_open() and not _state.run_over and not climate.intro_pending
	_weather_button.text = "Weather & protection →" if climate.phase == "calm" else "%s · %ds →" % [str(climate.name).capitalize(), ceili(climate.timer)]
	var weather_name: String = "Storm" if climate.event == "storm" else str(climate.name).capitalize()
	_blind_labels.weather.text = "%s %s%ds" % [weather_name, "in " if climate.phase == "warning" else ("recovery · " if climate.phase == "recovery" else "· "), ceili(climate.timer)] if climate.phase != "calm" else "Recovery costs +%.0f%%" % (float(climate.pressure) * 100.0)
	_blind_modal_warning.visible = _tutorial.is_empty() and not bool(info.run_over) and (info.due_in > 0.0 or info.current < 0.0)
	var stocks_left: int = int(info.booms_required) - int(info.booms)
	_blind_modal_warning.text = "Tax %s in %ds · Cash %s" % [_blind_money(info.target), ceili(info.due_in), _blind_money(info.current)] if info.due_in > 0 else "Debt %s · Tax %s after %d more stock%s" % [_blind_money(absf(info.current)), _blind_money(info.target), stocks_left, "" if stocks_left == 1 else "s"]
	_blind_modal_warning.add_theme_color_override("font_color", (Color("edb96d") if info.cleared else Color("ff7777")) if _panel_kind == "roll" else (GREEN if info.cleared else Color("bb4334")))
	if not climate.intro_pending and _climate_alert.introduction: _climate_alert.dismiss()
	if climate.intro_pending and not info.run_over: _climate_intro.start()
	elif _climate_intro.visible: _climate_intro.stop()
	if info.run_over:
		var debug_open: bool = is_panel_open() and _panel_kind == "debug"
		_modal.z_index = 210 if debug_open else 0
		if not _run_end.visible and not debug_open:
			cancel_roll()
			close_panel()
			_toast_box.hide()
			_purchase_box.hide()
			_combo_box.hide()
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


func _build_blinds() -> void:
	_heading("Tax day", "A clear forecast for your farm's next bill.")
	var hero := _surface("island", GREEN, true)
	_body.add_child(hero)
	var column := _vbox(8)
	hero.add_child(column)
	var top := _hbox(12)
	column.add_child(top)
	top.add_child(_icon({"kind": "metric", "id": "coin"}, 56))
	var amount := _vbox(2)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(amount)
	amount.add_child(_label("YOUR NEXT BILL", 11, MUTED, true))
	_refs.blind_live = _wrap("", 32, INK, true)
	amount.add_child(_refs.blind_live)
	_refs.tax_status = _badge("")
	top.add_child(_refs.tax_status)
	_refs.blind_due = _wrap("", 14, GREEN, true)
	column.add_child(_refs.blind_due)
	_refs.tax_progress = _meter(GREEN)
	column.add_child(_refs.tax_progress)
	_refs.blind_forecast = _wrap("", 13, MUTED)
	column.add_child(_refs.blind_forecast)
	var summary := _surface("quest")
	_body.add_child(summary)
	var summary_body := _vbox(8)
	summary.add_child(summary_body)
	_section_title(summary_body, "After collection")
	_refs.tax_balance = _wrap("", 20, GREEN, true)
	summary_body.add_child(_refs.tax_balance)
	_refs.tax_limit = _wrap("", 13, MUTED)
	summary_body.add_child(_refs.tax_limit)
	_info("tax_advice", "", MUTED, 13)
	if _island_id() >= 2: _body.add_child(_button("Protect your farm →", "climate", true))
	var details := _details_section("tax_details", "rates, ranks & last payment")
	_section_title(details, "Island tax guide")
	for island: int in BlindRules.PROGRESSION_BASELINES:
		var row := _hbox(12)
		details.add_child(row)
		row.add_child(_icon({"kind": "island", "island": island}, 56))
		var labels := _vbox(3)
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(labels)
		labels.add_child(_label(["Spud Valley", "Golden Shores", "Frosthollow"][island - 1], 17, INK, true))
		labels.add_child(_wrap("%s–%s tax · Bankruptcy below %s" % [_blind_money(float(BlindRules.PROGRESSION_BASELINES[island]) * BlindRules.TAX_RATE), _blind_money(float(BlindRules.PROGRESSION_BASELINES[island]) * BlindRules.TAX_RATE * BlindRules.TAX_BOOM_MAX), _blind_money(BlindRules.bankruptcy(island))], 13, MUTED))
	details.add_child(_wrap("Base tax is 5% of the island progression target. Tax Booms and weather can add up to +150%. Returning to an earlier island keeps your tax tier.", 13, MUTED))
	_section_title(details, "Savings milestones", "Balance ÷ bill")
	var ranks := HFlowContainer.new()
	ranks.add_theme_constant_override("h_separation", 6)
	ranks.add_theme_constant_override("v_separation", 6)
	details.add_child(ranks)
	for rank: Dictionary in BlindRules.WEALTH_RANKS:
		ranks.add_child(_badge("%s× %s" % [_number(rank.ratio), str(rank.name).capitalize()], "active"))
	_refs.blind_last = _wrap("", 13, INK)
	details.add_child(_refs.blind_last)
	_refresh_blinds()

func _refresh_blinds() -> void:
	var info: Dictionary = _state.call("blind_info")
	_refs.blind_live.text = _blind_money(info.tax)
	_refs.blind_live.add_theme_color_override("font_color", INK if info.cleared else Color("bb4334"))
	Cozy.badge(_refs.tax_status, "Covered" if info.cleared else "Shortfall", "active" if info.cleared else "warning")
	_refs.blind_forecast.text = "Base %s · +%.0f%%%s" % [_blind_money(info.base_tax), (float(info.tax_multiplier) - 1.0) * 100.0, " TAX BOOM" if info.tax_boom else " recovery pressure"]
	_refs.tax_balance.text = "%s remaining" % _blind_money(info.projected)
	_refs.tax_balance.add_theme_color_override("font_color", GREEN if info.projected >= 0 else CHERRY)
	_refs.tax_limit.text = "Current savings %s · Bankruptcy below %s" % [_blind_money(info.current), _blind_money(info.bankruptcy)]
	_refs.blind_due.text = "Collector arrives in %ds" % ceili(info.due_in) if info.due_in > 0.0 else "%d / %d major stocks until collection" % [int(info.booms), int(info.booms_required)]
	_refs.tax_progress.value = float(info.booms) / maxf(1, float(info.booms_required)) * 100
	_refs.tax_advice.text = "Disaster markets are down. Booms resume after recovery; crashes do not advance collection." if _state.disaster_market_active() else "Sell your harvest when prices suit you. Collection follows every third major stock and its full selling window. Unpaid tax becomes debt."
	var last: Dictionary = info.last_result
	_refs.blind_last.text = "No payments yet. Your latest receipt will appear here." if last.is_empty() else "Last payment · %s\nBefore collection %s · Bill %s\nRemaining %s · Savings milestone: %s" % ["Paid" if last.cleared else "Borrowed", _blind_money(last.balance), _blind_money(last.tax), _blind_money(last.after), str(_state.call("blind_progress_text", float(last.ratio)))]

func _build_climate() -> void:
	_heading("Weather station", "Forecasts, equipment and farm protection in one place.")
	if _island_id() < 2:
		_info("climate_locked", "Climate action begins on Golden Shores.", INK, 23)
		_body.add_child(_button("Explore islands →", "island", true))
		return
	var hero := _surface("island", GREEN, true)
	_body.add_child(hero)
	var row := _hbox(16)
	hero.add_child(row)
	var icon := ClimateIcon.new()
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)
	_refs.climate_icon = icon
	var status := _vbox(3)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	_refs.climate_status = _wrap("", 26, INK, true)
	_refs.climate_market = _wrap("", 16, INK)
	status.add_child(_refs.climate_status)
	status.add_child(_refs.climate_market)
	_info("protection_summary", "")
	if _island_id() == 3: _body.add_child(_button("Open furnace · heat the thawing hoe →", "activities"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	var captions: Dictionary = {"irrigation": "Buy once. Sprinklers and pipes carry to every island.", "rainwater": "More stored water for your can and sprinklers.", "drainage": "Open the gate to send floodwater to the sea.", "barn": "Automatic shutters protect your stored harvest.", "windbreaks": "Fixed trees calm the wind over the far beds."}
	var equipment_names: Dictionary = {"irrigation": "Sprinklers & irrigation", "rainwater": "Bigger rainwater tank", "drainage": "Drain channels", "barn": "Reinforced barn", "windbreaks": "Shelter trees"}
	for id in _state.ClimateSystem.PROJECTS:
		var project: Dictionary = _state.ClimateSystem.PROJECTS[id]
		var card := _surface("upgrade", GREEN)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = project.detail
		grid.add_child(card)
		var column := _vbox(3)
		card.add_child(column)
		var top := _hbox(8)
		column.add_child(top)
		top.add_child(_wrap(equipment_names[id], 19, INK, true))
		var story := preload("res://scripts/water_story.gd").new()
		story.concept = {"rainwater": "tank", "drainage": "drain", "windbreaks": "trees"}.get(id, id)
		column.add_child(story)
		var effect := _wrap(captions[id], 14, MUTED)
		effect.custom_minimum_size.y = 42
		column.add_child(effect)
		_refs["climate_effect:" + id] = effect
		var progress := _badge("")
		column.add_child(progress)
		_refs["climate_level:" + id] = progress
		var button := _button("", "climate_fund:" + id, true)
		button.add_theme_font_override("font", _card_button_font)
		column.add_child(button)
		_refs["climate_fund:" + id] = button
	if _island_id() == 2:
		var practice := _button("Try the water lesson · safe practice", "climate_operate:lesson_start")
		_body.add_child(practice)
		_refs.climate_practice = practice
	var bottom := _hbox(12)
	_body.add_child(bottom)
	var tax := _button("Tax forecast →", "taxes")
	tax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(tax)
	var details := _details_section("climate_details", "weather & protection details")
	_section_title(details, "Weather risks")
	for event: String in (["drought", "flood", "storm", "freeze"] if _island_id() == 3 else ["drought", "flood", "storm"]):
		var weather_row := _hbox(10)
		details.add_child(weather_row)
		var weather_icon := ClimateIcon.new()
		weather_icon.kind = event
		weather_icon.custom_minimum_size = Vector2(40, 40)
		weather_row.add_child(weather_icon)
		var weather_text := _vbox(3)
		weather_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weather_row.add_child(weather_text)
		weather_text.add_child(_label(str(_state.ClimateSystem.EVENTS[event].name).capitalize(), 16, INK, true))
		weather_text.add_child(_wrap(_state.ClimateSystem.EVENTS[event].prepare, 13, MUTED))
	details.add_child(_wrap("45s warning → 30s disaster → 75s recovery. Sale prices can crash up to −95%. No positive stocks during the disaster or recovery; the Rocket waits for clear skies.", 13, CHERRY))
	_section_title(details, "What each project protects")
	for project in _state.ClimateSystem.PROJECTS.values(): details.add_child(_wrap(project.name + " · " + project.detail, 13, MUTED))
	_refs.climate_reference = _wrap("", 14, GREEN)
	details.add_child(_refs.climate_reference)
	_refresh_climate()

func _refresh_climate() -> void:
	if not _refs.has("climate_status"): return
	var info: Dictionary = _state.call("climate_info")
	_refs.climate_icon.kind = info.event if info.phase != "calm" else "calm"
	_refs.climate_icon.queue_redraw()
	_refs.climate_status.text = "Clear skies" if info.phase == "calm" else "%s · %ds" % [str(info.name).capitalize(), ceili(info.timer)]
	if info.phase == "recovery": _refs.climate_status.text = "Weather clearing · %ds" % ceili(info.timer)
	if info.phase == "warning":
		_refs.climate_market.text = "Harvest now. Recovery tax: about %s." % _blind_money(info.warning_tax)
	elif info.phase in ["active", "recovery"]:
		_refs.climate_market.text = "Seeds +%.0f%% · Sales %.0f%%
Next tax %s" % [(float(info.seed_factor) - 1.0) * 100.0, (float(info.sell_factor) - 1.0) * 100.0, _blind_money(_state.call("blind_info").tax)]
	else:
		_refs.climate_market.text = "Prepare before the next warning." if info.pressure == 0.0 else "Weather passed. Recovery tax is still due."
	var protection_lines: Array[String] = ["FARM PROTECTION · " + ("Frosthollow" if _island_id() == 3 else "Golden Shores")]
	for event: String in (["drought", "flood", "storm", "freeze"] if _island_id() == 3 else ["drought", "flood", "storm"]):
		protection_lines.append("%s: crop stress −%d%% · barn loss −%d%% · recovery tax −%d%%" % [str(_state.ClimateSystem.EVENTS[event].name).capitalize(),roundi(_state.climate.protection(event,_island_id(),"field")*100),roundi(_state.climate.protection(event,_island_id(),"barn")*100),roundi(_state.climate.protection(event,_island_id(),"tax")*100)])
	protection_lines.append("Trees shelter the far patch; barn shutters add automatic cover. Operate equipment for active rescue.")
	if _island_id() == 3: protection_lines.append("Frozen crops: %d · Thawing hoe: %ds heat" % [info.frozen_crops,ceili(info.supply.heat)])
	_refs.protection_summary.text = "\n".join(protection_lines)
	if _refs.has("climate_practice"):
		var owned: bool = int(info.projects["2"].get("irrigation", 0)) > 0
		_refs.climate_practice.disabled = not owned
		_refs.climate_practice.text = "Try the water lesson · safe practice" if owned else "Buy sprinklers above to try the water lesson"
	var opportunity: Dictionary = _state.call("stock_opportunity")
	_refs.climate_reference.text = "Stock haul reference: %s · %s potatoes at this quote." % [_blind_money(opportunity.reference), _number(opportunity.units)]
	for id in _state.ClimateSystem.PROJECTS:
		var project: Dictionary = _state.ClimateSystem.PROJECTS[id]
		var level: int = int(info.projects[str(_island_id())].get(id, 0))
		var cost: float = float(BlindRules.PROGRESSION_BASELINES[2 if id == "irrigation" else _island_id()]) * float(project.cost) * float(level + 1)
		var maximum: int = _state.ClimateSystem.MAX_PROJECT_LEVEL
		if id == "rainwater":
			_refs["climate_effect:" + id].text = "%d stored water · shared by can and sprinklers." % int(info.water_capacity) if level >= maximum else "%d → %d stored water for your can and sprinklers." % [int(info.water_capacity), int(info.water_capacity) + 36]
		elif id == "irrigation":
			_refs["climate_effect:" + id].text = "4 water per patch · your most efficient pipes." if level >= maximum else ("6 → 4 water for the same fixed patch." if level == 1 else "Connect three fixed patches · 6 tank water each.")
		Cozy.badge(_refs["climate_level:" + id], "Level %d / %d · %s" % [level, maximum, "Complete" if level >= maximum else ("Affordable" if float(_state.coins) >= cost else "Save up")], "active" if level >= maximum or float(_state.coins) >= cost else "warning")
		_set_button("climate_fund:" + id, "Fully upgraded" if level >= maximum else "%s · %s" % ["Build" if level == 0 and id != "rainwater" else "Upgrade", _blind_money(cost)], level >= maximum or float(_state.coins) < cost)

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
	_tutorial_skip.tooltip_text = "End tutorial"
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
	contents.add_child(_tutorial_title)
	_tutorial_body = _wrap("", 15, Color("e2ead9"))
	var guide_font: FontVariation = FontVariation.new()
	guide_font.base_font = UI_FONT
	guide_font.variation_opentype = _font.variation_opentype
	_tutorial_body.add_theme_font_override("font", guide_font)
	contents.add_child(_tutorial_body)
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
	_tutorial_exit_box.add_child(_wrap("Leave the tutorial?", 15, CREAM, true))
	var stay: Button = _button("Keep learning →", "tutorial:stay")
	stay.add_theme_stylebox_override("normal", _style(GOLD, 9, 10))
	_tutorial_exit_box.add_child(stay)
	var leave: Button = _button("End tutorial", "tutorial:skip")
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
	_tutorial = info.duplicate(true)
	if _tutorial.is_empty():
		_tutorial_card.hide()
		_tutorial_exit_pending = false
		_tutorial_pointer.hide()
		_stats_card.show()
		_stats_card.size.x = 763.0
		for key: String in ["coins", "market_name", "luck"]:
			_top[key].get_parent().show()
		_menu_button.show()
		_hotbar.show()
		for button: Button in _tool_buttons.values():
			button.show()
		_hotbar.offset_left = -254
		_hotbar.offset_right = 254
		_quick_sell.show()
		_export_box.show()
		set_context(_context.text)
		_refresh_seed_visibility()
	else:
		_tutorial_progress.text = ("VALLEY TOUR" if info.get("tour_only", false) else "FIRST HARVEST") + "  ·  %d / %d" % [int(info.get("step", 1)), int(info.get("total", 1))]
		_tutorial_title.text = str(info.get("title", "Your first farm"))
		_tutorial_body.text = str(info.get("body", ""))
		_tutorial_next.text = str(info.get("continue_label", "Next stop →")) if bool(info.get("continue", false)) else "Click the gold bed" if str(info.get("focus", "")).begins_with("plot:") else "Follow the gold marker"
		_tutorial_next.disabled = not bool(info.get("continue", false))
		if info.get("id") == "inventory" and not bool(info.get("continue", false)):
			_tutorial_next.text = "Open bag [I] →"
			_tutorial_next.disabled = false
		elif info.get("id") == "walk":
			_tutorial_next.text = "Try a few steps"
		elif info.get("id") == "grow":
			_tutorial_next.text = "Growing…"
		_tutorial_key.text = str(info.get("key", ""))
		_tutorial_key.visible = not _tutorial_key.text.is_empty()
		_tutorial_meter.value = 100.0 * float(info.get("step", 1)) / maxf(1.0, float(info.get("total", 20)))
		var tool: String = str(info.get("tool", ""))
		var activity: String = "duck" if info.get("id") == "ducks" else ("contract" if info.get("id") == "quests" else "")
		_tutorial_icon.item = {"kind": "tool", "id": tool} if not tool.is_empty() else ({"kind": "activity", "id": activity} if not activity.is_empty() else {"kind": "crop", "crop": "russet"})
		_tutorial_icon.queue_redraw()
		_tutorial_card.show()
		# Clear a previous surge immediately, including its child process, so a
		# replay never flashes through the guide or resumes a stale jackpot.
		_market_impact.set_quote(_island_id(), 0.0)
		_market_impact.remaining = 0.0
		_market_impact._reward_remaining = 0.0
		_market_impact.set_countdown(_island_id(), 180.0)
		_market_impact.hide()
		_market_impact.set_process(false)
		_toast_timer.stop()
		_reward_timer.stop()
		_apply_tutorial_visibility()
	if is_panel_open():
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
			node.tooltip_text = "Available after the first sale, or choose End tutorial to farm freely."
			node.disabled = true

func _apply_tutorial_visibility() -> void:
	if _tutorial.is_empty() or not is_instance_valid(_tutorial_card):
		return
	var features: Array = _tutorial.get("features", [])
	var tools: Array = _tutorial.get("tools", [])
	_stats_card.visible = "coins" in features or "stock" in features or "roll" in features
	_top.coins.get_parent().visible = "coins" in features
	_top.market_name.get_parent().visible = "stock" in features
	_top.luck.get_parent().visible = "roll" in features
	var revealed_stats: int = int("coins" in features) + int("stock" in features) + int("roll" in features)
	_stats_card.size.x = 763.0 if revealed_stats >= 3 else (510.0 if revealed_stats == 2 else 225.0)
	if "stock" in features:
		_top.market_name.text = "STOCKS PAUSED"
		_top.price.text = "After the tour"
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
	_island_button.hide()
	_sidebar_box.hide()
	_context_box.hide()
	_combo_box.hide()
	_toast_box.hide()
	_reward_box.hide()
	_export_box.hide()
	_market_impact.hide()
	_refresh_seed_visibility()
	var touch = get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		_tutorial_next.visible = not _tutorial_exit_pending
		_tutorial_exit_box.visible = _tutorial_exit_pending
		_tutorial_card.move_to_front()
		return
	# Logical game size is preserved by the viewport. Measure the modal's
	# clear margin too, keeping this guide outside every shop's controls.
	var available_width: float = _modal_card.position.x - 44.0 if is_panel_open() else 219.0
	var card_width: float = minf(219.0, maxf(138.0, available_width))
	# Roll House is wider than other shops. Stack its guide heading so the
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
	if not _tutorial_next.disabled:
		target = _tutorial_next
	elif is_panel_open():
		var action: String = "buy:russet:1" if _tutorial.get("id") == "market" else ("sell:russet:-1" if _tutorial.get("id") == "sell" else "")
		for node: Node in _body.find_children("*", "Button", true, false):
			if not action.is_empty() and str(node.get_meta("hud_action", "")) == action and node.is_visible_in_tree() and not node.disabled:
				target = node
				break
	# Farming tools are already equipped. The only cue belongs to the bed.
	_tutorial_pointer.target = target

func _style(color: Color, padding: int = 14, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
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
	# Nunito covers plain numeric HUD labels; symbol fallbacks have taller
	# line metrics and are only needed on labels that actually use symbols.
	var compact: FontVariation = FontVariation.new()
	compact.base_font = UI_FONT
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
	panel.add_theme_stylebox_override("panel", _style(Color("fffdf4") if color == PAPER else color, padding, 17, Color("d9decd") if color == PAPER else Color.TRANSPARENT))
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
	button.custom_minimum_size.y = 39
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
	button.pressed.connect(func() -> void: _act(action))
	return button

func _act(action: String) -> void:
	if action.begins_with("build:inspect:"):
		_build_selection = action.get_slice(":", 2)
		show_panel("builds", _state)
		return
	if action == "farm_help:details":
		if not _farm_tip.is_empty() and _tutorial.is_empty() and not _rolling and not _state.run_over:
			_opened_farm_tip = _farm_tip.duplicate(true)
			show_panel("farm_tip", _state)
		return
	if action.begins_with("dex_tab:") and _panel_kind == "dex":
		var tab: String = action.get_slice(":", 1)
		if tab in ["crops", "mutations"]:
			_dex_tab = tab
			show_panel("dex", _state)
		return
	if action.begins_with("toggle_details:"):
		var key: String = action.get_slice(":", 1)
		if _refs.has(key):
			_refs[key].visible = not _refs[key].visible
			if _refs.has(key + ":toggle"):
				_refs[key + ":toggle"].text = ("Hide " if _refs[key].visible else "Show ") + str(_refs[key + ":toggle"].get_meta("section_title", "details"))
			if _refs[key].visible: _reveal_details(_refs[key])
		return
	if is_instance_valid(_state) and bool(_state.get("run_over")) and action not in ["reset", "debug", "close"] and not action.begins_with("debug"):
		return
	if not _tutorial_allows(action):
		show_tutorial_feedback("Finish this step, or choose End tutorial to farm freely.")
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
	if _rolling:
		return
	if action.begins_with("batch:"):
		action_requested.emit("roll_batch:%s:%s" % [_batch_kind, action.get_slice(":", 1)])
		return
	if action == "toggle_trophies":
		_trophies_open = not _trophies_open
		_refresh_trophies()
		_polish_card_typography(_refs.trophy_gallery)
		if _trophies_open: _reveal_details(_refs.trophy_gallery)
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
	if action.begins_with("debug_money:") or action.begins_with("debug_luck:"):
		var field: String = "debug_money" if action.begins_with("debug_money:") else "debug_luck"
		_refs[field].value = float(action.get_slice(":", 1))
		_refresh_debug()
		return
	if action == "debug_apply":
		var multiplier: Dictionary = _debug_money_value()
		if multiplier.has("error"):
			_refresh_debug()
			return
		action_requested.emit("debug:apply:%s:%s" % [str(multiplier.canonical), String.num_scientific(float(_refs.debug_luck.value))])
		_refs.debug_money.value = 1.0
		_refresh_debug()
		return
	if action == "debug:reset" and _refs.has("debug_luck"):
		_refs.debug_luck.value = 1.0
	if action == "menu":
		show_panel("pause", _state)
		return
	if action == "tracked_prices":
		show_panel("tracked_prices", _state)
		return
	if action.begins_with("inventory_tab:"):
		_inventory_tab = action.get_slice(":", 1)
		_set_inventory_tab()
		(_body.get_parent() as ScrollContainer).scroll_vertical = 0
		return
	if action.begins_with("roll:"):
		_stake_kind = action.get_slice(":", 1)
	if action == "close":
		close_panel()
	elif action == "request_reset":
		_reset_pending = true
		show_panel("pause", _state)
	elif action == "cancel_reset":
		_reset_pending = false
		show_panel("pause", _state)
	elif action == "roll:all_in" and not _all_in_pending:
		_all_in_pending = true
		_refresh_panel()
	elif action == "cancel_all_in":
		_all_in_pending = false
		_refresh_panel()
	else:
		if action.begins_with("tool:"):
			set_tool(action.get_slice(":", 1))
		if action.begins_with("roll:"):
			_all_in_pending = false
		action_requested.emit(action)

func _place(control: Control, rect: Rect2) -> void:
	root.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _build_top() -> void:
	var brand: VBoxContainer = _vbox(0)
	_place(brand, Rect2(88, 20, 290, 70))
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wordmark: BoxContainer = _hbox(8)
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(wordmark)
	wordmark.add_child(_label("TATER", 32, INK, true))
	wordmark.add_child(_label("/", 32, GOLD, true))
	wordmark.add_child(_label("LAND", 32, INK, true))

	var stats: PanelContainer = _card(CREAM, 12)
	_stats_card = stats
	_place(stats, Rect2(387, 21, 524, 72))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: BoxContainer = _hbox(20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(row)
	_top["coins"] = _stat(row, "COINS", "$240", GOLD)
	var market_box: VBoxContainer = _vbox(0)
	market_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(market_box)
	_top["market_name"] = _label("RUSSET MARKET", 10, MUTED, true)
	_top["price"] = _label("$38  +0%", 22, GREEN, true)
	market_box.add_child(_top["market_name"])
	market_box.add_child(_top["price"])
	_top["luck"] = _stat(row, "LUCK · +0%", "1.0×", GREEN)
	_top["luck_percent"] = _top.luck.get_parent().get_child(0)
	var stats_font: FontVariation = _compact_heading_font()
	for label: Node in stats.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", stats_font)
	stats.size.x = 763
	_weather_button = _button("Weather & protection →", "climate")
	_place(_weather_button, Rect2(28, 104, 302, 44))
	_weather_button.add_theme_font_size_override("font_size", 14)
	var island: Button = _button("SPUD VALLEY\nIsland 1  ·  Explore →", "island", true)
	_place(island, Rect2(923, 21, 218, 72))
	island.add_theme_font_size_override("font_size", 14)
	_island_button = island
	var menu_button: Button = _button("", "menu")
	_menu_button = menu_button
	menu_button.name = "MainMenuButton"
	menu_button.tooltip_text = "Farm menu · Debug money & luck · Esc"
	_place(menu_button, Rect2(1174, 21, 78, 72))
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
		bar.color = INK
		bar.custom_minimum_size.y = 3
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_icon.add_child(bar)
	var save: Button = _button("Save", "save")
	save.custom_minimum_size.y = 27
	save.add_theme_font_size_override("font_size", 12)
	_place(save, Rect2(1154, 67, 98, 27))
	save.hide()
	island.hide()
	var tracked: PanelContainer = _card(Color(1, 0.984, 0.929, 0.96), 8)
	_tracked_box = tracked
	root.add_child(tracked)
	tracked.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tracked.offset_left = 28
	tracked.offset_right = -28
	tracked.offset_top = -245
	tracked.offset_bottom = -195
	tracked.hide()
	var tracked_contents: BoxContainer = _hbox(10)
	tracked.add_child(tracked_contents)
	var chooser: Button = _button("Track seeds ▾", "tracked_prices")
	chooser.custom_minimum_size = Vector2(134, 38)
	chooser.add_theme_font_size_override("font_size", 12)
	tracked_contents.add_child(chooser)
	_tracked_row = _hbox(8)
	_tracked_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracked_contents.add_child(_tracked_row)

func _stat(parent: BoxContainer, title: String, value: String, color: Color) -> Label:
	var box: VBoxContainer = _vbox(0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_label(title, 10, MUTED, true))
	var number: Label = _label(value, 23, color, true)
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
	_builds_button = _button("Builds  [C]", "builds")
	_builds_button.custom_minimum_size.y = 30
	body.add_child(_builds_button)
	_quest_button = _button("Quest board  [Q]", "quests")
	_quest_button.custom_minimum_size.y = 30
	body.add_child(_quest_button)

func _build_footer() -> void:
	_crop_row = _hbox(8)
	root.add_child(_crop_row)
	_crop_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_crop_row.offset_left = 28
	_crop_row.offset_right = -28
	_crop_row.offset_top = -185
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
	for nav: Array in [["Market [B]", "market"], ["Inventory [I]", "inventory"], ["Upgrades [U]", "tools"], ["Roll House [R]", "roll"]]:
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
	sell_box.add_child(_quick_sell)
	_context_box = _card(Color(0.09, 0.20, 0.16, 0.93), 6)
	var hint_skin: StyleBoxFlat = _context_box.get_theme_stylebox("panel")
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
	_toast_box = _card(INK, 10)
	_place(_toast_box, Rect2(926, 104, 326, 0))
	_toast_box.z_index = 20
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _wrap("", 13, CREAM)
	_toast_label.add_theme_font_override("font", _plain_font)
	_toast_box.add_child(_toast_label)
	_toast_box.hide()
	_toast_timer = _timer(2.5, func() -> void: _toast_box.hide())
	_combo_box = _card(INK, 14)
	_place(_combo_box, Rect2(1022, 316, 230, 85))
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var combo_body: VBoxContainer = _vbox(5)
	_combo_box.add_child(combo_body)
	_combo_label = _label("HARVEST CHAIN  ×1", 18, GOLD, true)
	combo_body.add_child(_combo_label)
	_combo_bar = ProgressBar.new()
	_combo_bar.custom_minimum_size.y = 7
	_combo_bar.show_percentage = false
	_combo_bar.max_value = 3.5
	_combo_bar.add_theme_stylebox_override("background", _style(Color("315246"), 0, 3))
	_combo_bar.add_theme_stylebox_override("fill", _style(GOLD, 0, 3))
	combo_body.add_child(_combo_bar)
	_combo_box.hide()
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
	var panel: PanelContainer = _card(CREAM, 24)
	_modal_card = panel
	_modal.add_child(panel)
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
	_modal_title = _wrap("Welcome to Taterland", 34, INK, true)
	_modal_subtitle = _wrap("Good soil. Wild markets.", 14, MUTED)
	titles.add_child(_modal_title)
	titles.add_child(_modal_subtitle)
	var close: Button = _button("×", "close")
	close.custom_minimum_size.x = 40
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(close)
	_blind_modal_warning = _wrap("", 13, CHERRY, true)
	column.add_child(_blind_modal_warning)
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
	_modal.hide()

func update_state(state: Node) -> void:
	_state = state
	if not is_instance_valid(root):
		build_ui()
	_restore_tutorial_buttons()
	_sync_crop_catalog()
	_update_island_style()
	var crop: String = str(state.get("selected_crop"))
	var markets: Dictionary = state.get("market")
	var quote: Dictionary = markets.get(crop, {})
	var seeds: Dictionary = state.get("seed_inventory")
	var storage: Dictionary = state.get("storage")
	var delta: float = float(quote.get("change", 0))
	_top.coins.text = _money(_frozen_coins if _rolling else float(state.get("coins")))
	_top.coins.add_theme_color_override("font_color", Color("bb4334") if float(state.get("coins")) < float(state.call("blind_info").tax) else GOLD)
	_top.market_name.text = str(_crop_name(crop)).to_upper() + " MARKET"
	_top.price.text = "%s  %s" % [_money(float(quote.get("sell", 0))), _change_text(delta)]
	_top.price.add_theme_color_override("font_color", GREEN if delta >= 0 else CHERRY)
	var displayed_luck: float = _frozen_luck if _rolling else _effective_luck()
	_top.luck.text = String.num(displayed_luck, 3) + "×"
	_top.luck_percent.text = "LUCK · +%s%%" % _number((displayed_luck - 1.0) * 100.0)
	_top.luck.tooltip_text = _frozen_luck_math if _rolling else _luck_math()
	_crop_detail.text = "%s · %s seeds" % [_crop_name(crop), _number(float(seeds.get(crop, 0)))]
	var held: float = float(storage.get(crop, 0))
	_quick_sell.text = "Sell held [F] · " + _money(held * float(quote.get("sell", 0)))
	_quick_sell.disabled = held <= 0 or _rolling
	var available: Array[String] = _market_crops()
	for id: String in _all_crop_ids():
		var button: Button = _crop_buttons[id]
		button.visible = id in available
		button.text = "%s%s  ·  %ds\n%s seeds   /   %s in barn" % ["● " if id == crop else "", _crop_name(id), _crop_grow(id), _number(float(seeds.get(id, 0))), _number(float(storage.get(id, 0)))]
		button.add_theme_stylebox_override("normal", _style((Color("f8dfae") if _island_id() == 2 else Color("e4ebd7")) if id == crop else (SHORES_PAPER if _island_id() == 2 else CREAM), 10, 12, (CORAL if _island_id() == 2 else GREEN) if id == crop else Color.TRANSPARENT))
	_update_quest_sidebar()
	_update_builds_badge()
	_update_export_strip()
	_update_tracked_prices()
	_refresh_seed_visibility()
	var combo_time: float = float(state.get("combo_time"))
	_combo_box.visible = combo_time > 0 and _purchase_remaining <= 0.0
	_combo_label.text = "HARVEST CHAIN  ×%d" % int(state.get("combo_multiplier"))
	_combo_bar.value = combo_time
	_apply_tutorial_visibility()
	_apply_tutorial_buttons()
	_update_blind_ui()
	_update_farm_help()
	if is_panel_open():
		if _panel_kind in ["activities", "duck_patrol", "menu", "pause"] and _panel_island != _island_id():
			show_panel(_panel_kind, state)
			return
		var expected_crops: Array[String] = _market_crops() if _panel_kind == "market" else _known_crops()
		if _panel_kind in ["inventory", "barn"] and _inventory_signature != _inventory_id_string(_inventory_data()):
			show_panel(_panel_kind, state)
			return
		if _panel_kind in ["market", "barn", "inventory", "dex"] and _panel_crops != expected_crops:
			show_panel(_panel_kind, state)
		else:
			_refresh_panel()

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
		button.add_theme_stylebox_override("normal", _style(Color("f9d782") if key == tool else PAPER, 5, 10, GOLD if key == tool else Color.TRANSPARENT))
		var caption: Label = button.get_meta("caption")
		caption.add_theme_color_override("font_color", INK)
	_apply_tutorial_visibility()

func set_context(text: String) -> void:
	_hover_context = text
	_update_context()

func note_farm_action() -> void:
	_farm_busy_remaining = 3.0
	if is_instance_valid(_farm_help_card): _farm_help_card.hide()

func show_farm_hint(text: String) -> void:
	if _rolling or not _tutorial.is_empty(): return
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
	if is_instance_valid(_toast_box) and _toast_box.visible: _layout_toast()
	if is_instance_valid(_plot_action_box):
		_plot_action_box.visible = not _plot_action_text.is_empty() and not is_panel_open() and not _rolling and not (is_instance_valid(_state) and _state.run_over)
	var text: String = _farm_hint if _farm_hint_remaining > 0.0 else _hover_context
	_context.text = text
	_context_box.visible = not text.is_empty() and _plot_action_text.is_empty() and _tutorial.is_empty() and not is_panel_open() and not _rolling and not (is_instance_valid(_state) and _state.run_over)
	# Hug the single line instead of spanning the farm. Input passes through.
	var width: float = clampf(_plain_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0, 120.0, 480.0)
	_context_box.offset_left = -width * 0.5
	_context_box.offset_right = width * 0.5
	_context.size.x = width - 12
	_context_box.size = Vector2(width, 0)

func show_toast(text: String) -> void:
	if _rolling or not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	_toast_label.text = text
	_toast_layout_key = ""
	_layout_toast()
	_toast_box.show()
	_toast_box.move_to_front()
	_toast_timer.start()

func _layout_toast() -> void:
	var in_menu: bool = is_panel_open()
	var compact: bool = in_menu and root.size.y - _modal_card.get_global_rect().end.y < 60
	var weather_on_right: bool = is_instance_valid(_climate_console) and _climate_console.visible and _climate_console.position.x > root.size.x * 0.5
	var key: String = str([in_menu, compact, weather_on_right, _toast_label.text, _blind_card.get_global_rect().end.y])
	if key == _toast_layout_key: return
	_toast_layout_key = key
	var width: float = 700 if in_menu else (302 if weather_on_right else 326)
	_toast_label.max_lines_visible = (1 if compact else 2) if in_menu else 3
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var toast_style: StyleBoxFlat = _toast_box.get_theme_stylebox("panel")
	toast_style.content_margin_top = 4 if compact else 8
	toast_style.content_margin_bottom = 4 if compact else 8
	_toast_label.size.x = width - 20
	# Ellipsis labels may report zero minimum height after their parent shrinks.
	# Reserve the actual wrapped lines so switching from a menu never blanks a toast.
	var lines: int = clampi(_toast_label.get_line_count(), 1, _toast_label.max_lines_visible)
	_toast_label.custom_minimum_size.y = lines * _toast_label.get_theme_font("font").get_height(_toast_label.get_theme_font_size("font_size"))
	_toast_box.size = Vector2(width, 0)
	_toast_box.position = Vector2((root.size.x-width)*.5, root.size.y-(42 if compact else 70)) if in_menu else (Vector2(28, _blind_card.get_global_rect().end.y+12) if weather_on_right else Vector2(root.size.x-width-28,104))
	_toast_label.tooltip_text = _toast_label.text

func show_purchase(receipt: Dictionary) -> void:
	# Only committed purchases reach this method; failed affordability checks
	# keep their normal feedback and never create a success card.
	var kind: String = str(receipt.get("kind", ""))
	var quantity: int = int(receipt.get("quantity", 0))
	var cost: float = float(receipt.get("cost", -1.0))
	if kind not in ["seeds", "tool", "barn", "field", "duck", "island", "service"] or quantity <= 0 or not is_finite(cost) or cost < 0.0:
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
			title = "+%d barn spaces" % int(combined.quantity)
			detail = "Capacity %d" % int(combined.get("total", quantity))
		"field":
			title = "+%d garden beds" % int(combined.quantity)
			detail = "%d beds unlocked" % int(combined.get("total", quantity))
		"island": detail = "Island unlocked"
	_purchase_title.size.x = 202.0
	_purchase_detail.size.x = 202.0
	_purchase_title.text = title
	_purchase_detail.text = "%s · −%s" % [detail, _money(float(combined.cost))]
	_purchase_box.size = Vector2(230.0, _purchase_title.get_minimum_size().y + _purchase_detail.get_minimum_size().y + 45.0)
	_purchase_remaining = PURCHASE_SECONDS
	_purchase_bar.value = PURCHASE_SECONDS
	_combo_box.hide()
	_purchase_box.show()

func show_reward(title: String, detail: String, rarity: String) -> void:
	if _rolling or not _tutorial.is_empty():
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
	_market_impact.reward(_island_id(), 6.0)

func is_panel_open() -> bool:
	return (is_instance_valid(_modal) and _modal.visible) or (is_instance_valid(_conversation) and _conversation.visible)

func close_panel() -> void:
	if is_instance_valid(_conversation) and _conversation.visible: _conversation.finish()
	if _rolling:
		return
	if is_instance_valid(_modal):
		_modal.hide()
	_panel_kind = ""
	_refresh_seed_visibility()
	_crate_reel = false
	_stake_kind = "normal"
	_reset_pending = false
	_all_in_pending = false
	_apply_tutorial_visibility()

func show_panel(kind: String, state: Node, crate_mode: bool = false) -> void:
	if _rolling:
		return
	_state = state
	if not is_instance_valid(root):
		build_ui()
	if kind != _panel_kind:
		_reset_pending = false
		_all_in_pending = false
	_panel_kind = kind
	_panel_island = _island_id()
	_crate_reel = kind == "roll" and crate_mode
	if not _crate_reel and _stake_kind == "build_crate":
		_stake_kind = "normal"
	_modal_card.add_theme_stylebox_override("panel", Cozy.modal())
	_modal_card.offset_left = -452 if kind == "roll" else -376
	_modal_card.offset_right = 452 if kind == "roll" else 376
	_modal_card.offset_top = -354 if kind == "roll" else -317
	_modal_card.offset_bottom = 354 if kind == "roll" else 317
	_modal_title.add_theme_color_override("font_color", INK)
	_modal_title.add_theme_font_override("font", _card_heading_font)
	_modal_title.add_theme_font_size_override("font_size", 28)
	_modal_subtitle.add_theme_font_override("font", _plain_font)
	_modal_subtitle.add_theme_color_override("font_color", MUTED)
	_refs.clear()
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
		"barn", "inventory": _build_barn()
		"tools": _build_tools()
		"roll": _build_roll()
		"pause", "menu": _build_pause()
		"dex": _build_dex()
		"island": _build_island()
		"quests": _build_quests()
		"builds": _build_builds()
		"tracked_prices": _build_tracked_prices()
		"activities": _build_activities()
		"duck_patrol": _build_duck_patrol()
		"debug": _build_debug()
		"graphics": _build_graphics()
		"taxes", "blinds": _build_blinds()
		"climate": _build_climate()
		_: _build_help()
	_polish_card_typography(_body)
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 8
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(bottom_space)
	_refresh_panel()
	_modal.show()
	_context_box.hide()
	_farm_help_card.hide()
	_blind_card.hide()
	_refresh_seed_visibility()
	_modal.move_to_front()
	_update_blind_ui()
	_apply_tutorial_visibility()
	_apply_tutorial_buttons()
	if is_instance_valid(get_parent().get("touch_controls")):
		get_parent().touch_controls.fit_modal()
		# Newly built content can settle its minimum size after the first fit.
		# Refit this frame rather than waiting for the periodic touch update.
		get_parent().touch_controls.fit_modal.call_deferred()

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

func _build_market() -> void:
	var first_seed: bool = _tutorial_seed_market()
	_heading("Meet the seed seller" if first_seed else "The Spud Exchange", "Start small. One Russet seed is all you need." if first_seed else "Buy low. Grow. Sell high.")
	_info("market_note", "Live prices · Buy seeds or sell your harvest.")
	_panel_crops = _market_crops()
	for crop: String in _panel_crops:
		var card: PanelContainer = _card(PAPER, 7 if _panel_crops.size() == 5 else 12)
		_body.add_child(card)
		var column: VBoxContainer = _vbox(4 if _panel_crops.size() == 5 else 6)
		card.add_child(column)
		var header: BoxContainer = _hbox(12)
		column.add_child(header)
		var name_label: Label = _label(str(_crop_name(crop)).to_upper(), 14, _crop_color(crop), true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		var sell: Label = _label("SELL $0", 17, INK, true)
		var change: Label = _label("+0%", 14, GREEN, true)
		header.add_child(sell)
		header.add_child(change)
		sell.visible = not first_seed
		change.visible = not first_seed
		_refs[crop + ":price"] = sell
		_refs[crop + ":change"] = change
		var row: BoxContainer = _hbox(10)
		column.add_child(row)
		var graph: Control = Sparkline.new()
		graph.custom_minimum_size = Vector2(118, 36)
		row.add_child(graph)
		graph.visible = not first_seed
		if first_seed:
			row.add_child(_icon({"kind": "seed", "id": "russet", "crop": "russet"}, 78))
		_refs[crop + ":graph"] = graph
		var quote: Label = _wrap("", 12, MUTED)
		quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(quote)
		_refs[crop + ":quote"] = quote
		for qty: int in [1, 5]:
			var action: String = "buy:%s:%d" % [crop, qty]
			var buy: Button = _button("Buy %d" % qty, action, first_seed and qty == 1)
			buy.visible = not first_seed or qty == 1
			row.add_child(buy)
			_refs[action] = buy
		var sell_button: Button = _button("Sell held", "sell:" + crop + ":-1", true)
		row.add_child(sell_button)
		sell_button.visible = not first_seed
		_refs["sell:" + crop + ":-1"] = sell_button

func _build_barn() -> void:
	_heading("Your inventory", "Crops, gear and everything you own.")
	_info("inventory_total", "")
	_info("barn_tip", "Beginner tip: upgrade your barn here to store more crops and save harvests for better market prices.")
	_offer("A roomier barn", "", "Upgrade", "upgrade:barn")
	_panel_crops = _known_crops()
	_inventory_sections.clear()
	var tabs: BoxContainer = _hbox(8)
	_body.add_child(tabs)
	for section: String in ["crops", "gear", "items", "builds"]:
		var names: Dictionary = {"crops": "Crops & seeds", "gear": "Gear", "items": "Items & mutations", "builds": "Builds & crates"}
		var button: Button = _button(names[section], "inventory_tab:" + section)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		_refs["tab:" + section] = button
		var column: VBoxContainer = _vbox(9)
		_inventory_sections[section] = column
	for section: String in ["crops", "gear", "items", "builds"]:
		_body.add_child(_inventory_sections[section])
	_build_equipment_header(_inventory_sections.gear)
	var entries: Array[Dictionary] = _inventory_data()
	_inventory_signature = _inventory_id_string(entries)
	var gear_grid := GridContainer.new()
	gear_grid.columns = 2
	gear_grid.add_theme_constant_override("h_separation", 10)
	gear_grid.add_theme_constant_override("v_separation", 10)
	_inventory_sections.gear.add_child(gear_grid)
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", "relic"))
		if kind == "gear":
			_build_gear_card(gear_grid, entry)
			continue
		var section: String = "crops" if kind in ["seed", "crop"] else ("builds" if kind in ["build", "build_crate"] else "items")
		var card: PanelContainer = _card(PAPER, 12)
		_inventory_sections[section].add_child(card)
		var row: BoxContainer = _hbox(12)
		card.add_child(row)
		row.add_child(_icon(entry))
		var description: VBoxContainer = _vbox(4)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var title: Label = _wrap("", 16, INK, true)
		var detail: Label = _wrap("", 13, MUTED)
		description.add_child(title)
		description.add_child(detail)
		_refs["item:" + id + ":title"] = title
		_refs["item:" + id + ":detail"] = detail
		var action: String = str(entry.get("action", ""))
		if kind == "crop":
			action = "sell:" + str(entry.get("crop", "russet")) + ":-1"
		elif kind == "processed" and action in ["", "sell"]:
			action = "build:sell_processed"
		if not action.is_empty():
			var button: Button = _button("Select", action, kind == "crop")
			button.custom_minimum_size.x = 145
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(button)
			_refs["item:" + id + ":action"] = button
	if gear_grid.get_child_count() == 0:
		var empty := _surface("gear", GREEN)
		_inventory_sections.gear.add_child(empty)
		var empty_row := _hbox(14)
		empty.add_child(empty_row)
		empty_row.add_child(_icon({"kind": "slot", "id": "body"}, 62))
		empty_row.add_child(_wrap("Your wardrobe starts here. Find clothing at the Roll House, then equip it for extra bonuses.", 14, MUTED))
	for section: String in ["crops", "gear", "items", "builds"]:
		if _inventory_sections[section].get_child_count() == 0:
			_inventory_sections[section].add_child(_wrap("Empty for now. Keep farming!", 15, MUTED))

	var sell_rare: Button = _button("Sell all mutation crates", "sell_mutations")
	_inventory_sections.items.add_child(sell_rare)
	_refs["sell_mutations"] = sell_rare
	_set_inventory_tab()

func _build_gear_card(parent: GridContainer, entry: Dictionary) -> void:
	var id: String = str(entry.id)
	var key: String = "item:" + id
	var rarity: String = str(entry.get("rarity", "common"))
	var accent: Color = Cozy.RARITY_COLORS.get(rarity, GREEN)
	var card := _surface("gear", accent)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	_refs[key + ":card"] = card
	var body := _vbox(7)
	card.add_child(body)
	var top := _hbox(10)
	body.add_child(top)
	top.add_child(_icon(entry, 64))
	var metadata := _vbox(5)
	metadata.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(metadata)
	var rarity_badge := _badge(rarity.capitalize())
	rarity_badge.add_theme_stylebox_override("normal", _style(accent.lerp(CREAM, 0.86), 5, 7))
	rarity_badge.add_theme_color_override("font_color", accent.darkened(0.12))
	metadata.add_child(rarity_badge)
	metadata.add_child(_label(str(entry.get("slot", "gear")).capitalize() + " slot", 12, MUTED))
	var title := _wrap("", 18, INK, true)
	body.add_child(title)
	_refs[key + ":title"] = title
	var detail := _wrap("", 13, GREEN)
	detail.custom_minimum_size.y = 52
	body.add_child(detail)
	_refs[key + ":detail"] = detail
	var footer := _hbox(8)
	body.add_child(footer)
	var status := _badge("Owned")
	footer.add_child(status)
	_refs[key + ":status"] = status
	var button := _button("Equip", "gear:equip:" + id, true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(button)
	_refs[key + ":action"] = button

func _build_tools() -> void:
	_heading("Tool shed", "Better tools. More beds. Fewer trips.")
	for tool: String in ["hoe", "water", "harvest"]:
		var names: Dictionary = {"hoe": "The trusty hoe", "water": "Watering can", "harvest": "Harvest scythe"}
		_offer(names[tool], "", "Upgrade", "upgrade:" + tool, true)
	_offer("More room to grow", "Unlock all 24 beds.", "$1.8K", "upgrade:expansion")
	var row: BoxContainer = _hbox(10)
	_body.add_child(row)
	var dex_button: Button = _button("PotatoDex  [P]", "dex")
	dex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dex_button)
	var island_button: Button = _button("Explore the islands", "island")
	island_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(island_button)
	_info("tool_tip", "Equip tools with keys 1–5 or the hotbar.", MUTED, 13)

func _build_roll() -> void:
	_heading("Build crate" if _crate_reel else "The Questionable Shack", "")
	_refs.roll_purse = _modal_subtitle
	_modal_subtitle.visible = not _crate_reel
	if not _crate_reel:
		_modal_fixed.show()
		var meter := RollLuckMeter.new()
		_modal_fixed.add_child(meter)
		_refs.roll_luck_meter = meter
		meter.completed.connect(_start_pending_spin)
		var quality := _label("", 12, GREEN)
		quality.add_theme_font_override("font", _card_button_font)
		_modal_fixed.add_child(quality)
		_refs.roll_quality = quality
		meter.explanation_changed.connect(func(text: String): quality.text = text)
	var core := _hbox(18)
	_body.add_child(core)
	var play_column := _vbox(8)
	play_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core.add_child(play_column)
	var odds_column := _vbox(10)
	odds_column.custom_minimum_size.x = 234
	odds_column.visible = not _crate_reel
	core.add_child(odds_column)
	var reel_card := _surface("island", Color("9375a7"))
	reel_card.add_theme_stylebox_override("panel", _style(Color("eee7ed"), 7, 14, Color("c9b9ce")))
	play_column.add_child(reel_card)
	_spinner = RollReel.new()
	_spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reel_card.add_child(_spinner)
	_spinner.finished.connect(_on_roll_finished)
	_spinner.set_build_deck(_crate_reel)
	var result_box := _vbox(4)
	play_column.add_child(result_box)
	var result_title := _wrap("Choose your stake", 17, INK, true)
	result_box.add_child(result_title)
	_refs.roll_result_title = result_title
	var result_detail := _wrap("Your prize lands in the centre.", 12, MUTED)
	result_box.add_child(result_detail)
	result_detail.hide()
	_refs.roll_result_detail = result_detail
	var receipt := _wrap("", 12, GREEN)
	result_box.add_child(receipt)
	receipt.hide()
	_refs.roll_accounting = receipt
	if _crate_reel:
		result_detail.show()
		result_title.text = "One crate. One new build level."
		result_detail.text = "Open your crate to discover a specialty."
		var open_button := _button("Open another Build Crate", "build:open_crate", true)
		play_column.add_child(open_button)
		_refs["build:open_crate"] = open_button
		return
	var stakes := GridContainer.new()
	stakes.columns = 2
	stakes.add_theme_constant_override("h_separation", 10)
	stakes.add_theme_constant_override("v_separation", 7)
	play_column.add_child(stakes)
	for kind: String in ["normal", "big", "stupid", "all_in"]:
		var button := _button("Roll", "roll:" + kind, kind == "normal")
		button.custom_minimum_size.y = 39
		button.mouse_entered.connect(_preview_stake.bind(kind))
		button.focus_entered.connect(_preview_stake.bind(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stakes.add_child(button)
		_refs["roll:" + kind] = button
	if _island_id() == 3:
		var batches := _hbox(8)
		play_column.add_child(batches)
		var batch_stake := OptionButton.new()
		for label: String in ["Normal stake", "Big stake", "Stupid stake"]:
			batch_stake.add_item(label)
		batch_stake.selected = ["normal", "big", "stupid"].find(_batch_kind)
		batch_stake.item_selected.connect(func(index: int) -> void:
			if not _rolling:
				_batch_kind = ["normal", "big", "stupid"][index]
				_preview_stake(_batch_kind)
				_refresh_panel())
		_style_choice(batch_stake)
		batches.add_child(batch_stake)
		_refs.batch_stake = batch_stake
		for count: int in [3, 5]:
			var batch := _button("Roll ×%d" % count, "batch:" + str(count))
			batch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			batches.add_child(batch)
			_refs["batch:" + str(count)] = batch
	_info("all_in_warning", "", CHERRY, 13)
	var cancel := _button("Keep my coins · cancel all-in", "cancel_all_in")
	play_column.add_child(cancel)
	_refs.cancel_all_in = cancel
	_info("crown_offer", "Aurora Crown · One free same-stake roll with every purchase.", GREEN, 12)
	_info("roll_minimum", "", MUTED, 11)
	for key: String in ["all_in_warning", "crown_offer", "roll_minimum"]:
		_refs[key].reparent(play_column)
	play_column.move_child(cancel, _refs.all_in_warning.get_index() + 1)
	var batch_results := GridContainer.new()
	batch_results.columns = 3
	batch_results.add_theme_constant_override("h_separation", 8)
	batch_results.add_theme_constant_override("v_separation", 8)
	play_column.add_child(batch_results)
	batch_results.hide()
	_refs.batch_results = batch_results
	var odds_card := _surface("quest", Color("9375a7"))
	odds_column.add_child(odds_card)
	var odds_body := _vbox(9)
	odds_card.add_child(odds_body)
	_section_title(odds_body, "Live odds")
	odds_body.add_child(_wrap("Every rarity, for this stake.", 12, MUTED))
	var odds := GridContainer.new()
	odds.columns = 1
	odds.add_theme_constant_override("h_separation", 10)
	odds.add_theme_constant_override("v_separation", 4)
	odds_body.add_child(odds)
	for entry: Dictionary in _state.call("roll_odds", _stake_kind):
		var tier: String = str(entry.get("tier", "common"))
		var label := _label("", 13, INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = str(entry.get("description", ""))
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		var odds_style := _style(RollReel.COLORS.get(tier, GOLD).lerp(CREAM, 0.85), 8, 7)
		odds_style.content_margin_top = 3
		odds_style.content_margin_bottom = 3
		label.add_theme_stylebox_override("normal", odds_style)
		odds.add_child(label)
		_refs["odds:" + tier] = label
	_refs.roll_luck_total = _wrap("", 12, GREEN)
	odds_column.add_child(_refs.roll_luck_total)
	odds_column.add_child(_wrap("Odds include empty sacks.", 12, MUTED))
	var math_body := _details_section("roll_math_section", "roll calculation")
	_section_title(math_body, "How this roll is calculated")
	var math := _wrap("", 14, INK)
	math_body.add_child(math)
	_refs.roll_luck_math = math
	math_body.add_child(_wrap("Non-common weight = base weight × roll quality × luck weight raised to the tier’s rarity power. Above 10× luck, multiply again by (luck / 10) raised to 0.35 × rarity steps above Rare. Normalize to the displayed odds. Ordinary cash jackpots cap at 2.25%; excess moves to Relic and Mystery.", 12, MUTED))
	var trophies := _button("Show trophy cabinet", "toggle_trophies")
	_body.add_child(trophies)
	_refs.trophy_toggle = trophies
	var utilities := _hbox(10)
	_body.add_child(utilities)
	_refs["roll_math_section:toggle"].reparent(utilities)
	trophies.reparent(utilities)
	_body.move_child(utilities, _refs.roll_math_section.get_index())
	for utility: Control in utilities.get_children(): utility.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gallery := _vbox(8)
	_body.add_child(gallery)
	_refs.trophy_gallery = gallery
	_trophy_signature = ""
	_refresh_trophies()

func _roll_chance(chance: float) -> String:
	# Do not round a possible rare outcome down to an impossible-looking 0%.
	if chance == 0.0 or chance >= 0.001: return "%.3f" % chance
	var exponent: int = int(floor(log(chance) / log(10.0)))
	if exponent >= -7: return String.num(chance, 2 - exponent)
	return "%.3fe%d" % [chance / pow(10.0, exponent), exponent]

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
	popup.add_theme_stylebox_override("panel", _style(CREAM, 8, 10, Color("b7c8af")))
	popup.add_theme_stylebox_override("hover", _style(Color("dcebd7"), 6, 6))
	popup.add_theme_font_override("font", _plain_font)
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)

func _build_dex() -> void:
	_heading("The PotatoDex", "An illustrated field guide to ordinary spuds and extraordinary finds.")
	_panel_crops = _known_crops()
	var tabs := _hbox(10)
	_body.add_child(tabs)
	for tab: String in ["mutations", "crops"]:
		var button := _button("Special mutations" if tab == "mutations" else "Crop varieties", "dex_tab:" + tab)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = _dex_tab == tab
		tabs.add_child(button)
	_info("dex_entries", "", GREEN, 14)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	var ids: Array = _state.MUTATION_IDS if _dex_tab == "mutations" else _state.CROP_IDS
	var crop_notes: Dictionary = {"russet": "A quick, dependable first harvest.", "golden": "Golden skin with a valuable little harvest.", "giant": "A hefty potato with a generous yield.", "radioactive": "Bright green, with wildly changing prices.", "sunburst": "A sun-loving specialty of Golden Shores.", "icecap": "A frosty blue potato grown in Frosthollow."}
	var mutation_notes: Dictionary = {"golden": "A gleaming gold mutation. A different discovery from the ordinary Golden crop.", "crystal": "Translucent crystals turn this potato into a rare mineral treasure.", "rainbow": "Bands of colour make this a prized, many-hued harvest.", "radioactive": "An intense glow marks this mutation. Any potato variety can develop it."}
	for index: int in range(ids.size()):
		var id: String = str(ids[index])
		var special: bool = _dex_tab == "mutations"
		var card := _surface("gear", Color("9676a9") if special else _crop_color(id))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var column := _vbox(6)
		card.add_child(column)
		var heading := _hbox(10)
		column.add_child(heading)
		var picture := _icon({"kind": "mutation", "id": "mutation:russet:" + id, "crop": "russet"} if special else {"kind": "crop", "crop": id}, 76)
		picture.name = "DexPicture_" + id
		heading.add_child(picture)
		var title := _wrap("#%02d · %s" % [index + 1, id.capitalize() + " mutation" if special else _crop_name(id)], 18, INK, true)
		title.custom_minimum_size.x = 155
		heading.add_child(title)
		var description := _wrap(str(mutation_notes[id] if special else crop_notes[id]), 14, MUTED)
		description.custom_minimum_size.x = 250
		column.add_child(description)
		var status := _wrap("", 12, GREEN, true)
		column.add_child(status)
		_refs["dex_status:" + id] = status
		var detail := _wrap("", 15, GREEN, true)
		column.add_child(detail)
		_refs["dex_detail:" + id] = detail
	var footer := _surface("quest", GOLD)
	_body.add_child(footer)
	var footer_body := _vbox(6)
	footer.add_child(footer_body)
	_section_title(footer_body, "Every discovery stays with you")
	_refs.dex_bonus = _wrap("", 14, GREEN, true)
	footer_body.add_child(_refs.dex_bonus)
	footer_body.add_child(_wrap("Mutation value = live crop price × its multiplier. Sell a find whenever you like; its discovery remains in your field guide.", 13, MUTED))

func _refresh_dex() -> void:
	var found: Array = _state.dex
	_refs.dex_entries.text = "%d / 4 mutation types discovered" % found.size() if _dex_tab == "mutations" else "6 varieties · Water once · Growth bonuses can make them faster"
	var ids: Array = _state.MUTATION_IDS if _dex_tab == "mutations" else _state.CROP_IDS
	for id: String in ids:
		if _dex_tab == "mutations":
			_refs["dex_status:" + id].text = "DISCOVERED" if id in found else "NOT DISCOVERED · Preview"
			Cozy.badge(_refs["dex_status:" + id], "DISCOVERED" if id in found else "NOT DISCOVERED · Preview", "active" if id in found else "neutral")
			_refs["dex_detail:" + id].text = "%s× live crop value" % _number(_state.MUTATION_MULTIPLIERS[id])
		else:
			var home: String = "Golden Shores" if id == "sunburst" else ("Frosthollow" if id == "icecap" else "Spud Valley onward")
			_refs["dex_status:" + id].text = "%ds base growth · %s" % [_crop_grow(id), home]
			_refs["dex_detail:" + id].text = "Lv.%d · %s harvested · +%d%% mastery yield" % [int(_state.mastery_level(id)), _number(_state.mastery[id]), mini(1000, 2 * int(_state.mastery_level(id)))]
	_refs.dex_bonus.text = "Permanent harvest bonus +%s%% · Total luck %s× (+%s%%)" % [_number(_state.permanent_yield * 100.0), String.num(_effective_luck(), 3), _number((_effective_luck() - 1.0) * 100.0)]

func _build_island() -> void:
	_heading("Set sail", "Three little worlds. Your crops keep growing while you explore.")
	var destinations: Array[Dictionary] = [
		{"id": 1, "name": "Spud Valley", "tagline": "Good soil. A place to call home.", "beds": "24 beds", "crops": "4 crops", "feature": "Home farm", "accent": GREEN},
		{"id": 2, "name": "Golden Shores", "tagline": "Sunburst harvests and seaside fortunes.", "beds": "48 beds", "crops": "2× yield", "feature": "Wild weather", "accent": CORAL},
		{"id": 3, "name": "Frosthollow", "tagline": "Rare Icecaps, Frostbreaks and northern lights.", "beds": "80 beds", "crops": "3× yield", "feature": "Frozen beds", "accent": Color("56899d")},
	]
	for destination: Dictionary in destinations:
		var id: int = int(destination.id)
		var key: String = "travel:" + str(id)
		var accent: Color = destination.accent
		var card := _surface("island", accent)
		_body.add_child(card)
		_refs[key + ":card"] = card
		var body := _vbox(10)
		card.add_child(body)
		var row := _hbox(14)
		body.add_child(row)
		row.add_child(_icon({"kind": "island", "island": id}, 100))
		var description := _vbox(7)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var title_row := _hbox(8)
		description.add_child(title_row)
		var title := _label(destination.name, 22, INK, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var status := _badge("")
		title_row.add_child(status)
		_refs[key + ":status"] = status
		description.add_child(_wrap(destination.tagline, 13, MUTED))
		var features := HFlowContainer.new()
		features.add_theme_constant_override("h_separation", 14)
		description.add_child(features)
		features.add_child(_metric("beds", destination.beds))
		features.add_child(_metric("crops", destination.crops))
		features.add_child(_metric("weather" if id > 1 else "yield", destination.feature))
		var button := _button("Travel", key, true)
		description.add_child(button)
		_refs[key] = button
		if id == 1: continue
		var unlock_body := _vbox(6)
		body.add_child(unlock_body)
		_refs[key + ":unlock"] = unlock_body
		_section_title(unlock_body, "Your next adventure" if id == 2 else "Beyond the golden coast")
		for requirement: String in ["harvest", "coins"]:
			var progress_row := _hbox(8)
			unlock_body.add_child(progress_row)
			progress_row.add_child(_icon({"kind": "metric", "id": "yield" if requirement == "harvest" else "coin"}, 22))
			var label := _label("", 13, INK, true)
			label.custom_minimum_size.x = 240
			progress_row.add_child(label)
			_refs[key + ":" + requirement + ":label"] = label
			var bar := _meter(accent)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			progress_row.add_child(bar)
			_refs[key + ":" + requirement + ":bar"] = bar
		var actions := _hbox(10)
		unlock_body.add_child(actions)
		var gate := _wrap("", 12, MUTED)
		actions.add_child(gate)
		_refs[key + ":gate"] = gate
		var unlock_action: String = "island_unlock" if id == 2 else "island3_unlock"
		var unlock_button := _button("Unlock", unlock_action, true)
		actions.add_child(unlock_button)
		_refs[unlock_action] = unlock_button
	_body.add_child(_button("Local quest board  [Q]", "quests"))

func _refresh_islands() -> void:
	var coins: float = float(_state.coins)
	var harvested: float = float(_state.call("total_mastery"))
	for id: int in [1, 2, 3]:
		var key: String = "travel:" + str(id)
		var unlocked: bool = id == 1 or _flag("island%d_unlocked" % id)
		var here: bool = _island_id() == id
		Cozy.badge(_refs[key + ":status"], "You are here" if here else ("Unlocked" if unlocked else "Locked"), "active" if unlocked else "locked")
		_set_button(key, "You are here" if here else ("Set sail →" if unlocked else "Destination locked"), here or not unlocked)
		if id == 1: continue
		_refs[key + ":unlock"].visible = not unlocked
		var cost: float = _catalog_number("ISLAND%d_UNLOCK_COST" % id, 1e6 if id == 2 else 1e11)
		var target: float = _catalog_number("ISLAND%d_UNLOCK_HARVEST" % id, 500 if id == 2 else 25000)
		_refs[key + ":harvest:label"].text = "%s / %s harvested" % [_number(minf(harvested, target)), _number(target)]
		_refs[key + ":coins:label"].text = "%s / %s saved" % [_money(coins), _money(cost)]
		_refs[key + ":harvest:bar"].value = clampf(harvested / target * 100.0, 0, 100)
		_refs[key + ":coins:bar"].value = clampf(coins / cost * 100.0, 0, 100)
		var previous_unlocked: bool = id == 2 or _flag("island2_unlocked")
		var ready: bool = coins >= cost and harvested >= target and previous_unlocked
		_refs[key + ":gate"].text = "Unlock Golden Shores first" if not previous_unlocked else ("Ready for a new horizon!" if ready else "Keep harvesting and saving for passage.")
		_set_button("island_unlock" if id == 2 else "island3_unlock", "Unlock · " + _money(cost), unlocked or not ready)

func _build_quests() -> void:
	_heading(str(_state.call("island_name")).capitalize() + " quests", "A little purpose for every harvest.")
	_info("quest_note", "", GREEN, 13)
	var icons: Dictionary = {"starter_crash": {"kind": "seed", "crop": "golden"}, "starter_spike": {"kind": "build", "id": "investor"}, "starter_combo": {"kind": "tool", "id": "harvest"}, "ground": {"kind": "tool", "id": "hoe"}, "sunburst": {"kind": "crop", "crop": "sunburst"}, "combo": {"kind": "tool", "id": "harvest"}, "export": {"kind": "collectible", "id": "compass"}, "mutation": {"kind": "mutation", "id": "mutation:russet:golden"}, "winter_ground": {"kind": "tool", "id": "hoe"}, "winter_harvest": {"kind": "crop", "crop": "icecap"}, "winter_frost": {"kind": "crop", "crop": "icecap"}}
	for quest: Dictionary in _quests():
		var id: String = str(quest.get("id", ""))
		var key: String = "quest:" + id
		var card := _surface("quest")
		_body.add_child(card)
		_refs[key + ":card"] = card
		var body := _vbox(8)
		card.add_child(body)
		var header := _hbox(12)
		body.add_child(header)
		header.add_child(_icon(icons.get(id, {"kind": "tool", "id": "harvest"}), 52))
		var titles := _vbox(3)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(titles)
		titles.add_child(_wrap(str(quest.get("title", "Farm challenge")).capitalize(), 19, INK, true))
		titles.add_child(_wrap(str(quest.get("description", "")), 13, MUTED))
		var status := _badge("In progress")
		header.add_child(status)
		_refs[key + ":status"] = status
		var progress_row := _hbox(12)
		body.add_child(progress_row)
		var progress := _meter(GREEN, 10)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress_row.add_child(progress)
		_refs[key + ":bar"] = progress
		var detail := _label("", 16, GREEN, true)
		progress_row.add_child(detail)
		_refs[key + ":detail"] = detail
		var footer := _hbox(8)
		body.add_child(footer)
		var rewards := HFlowContainer.new()
		rewards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewards.add_theme_constant_override("h_separation", 12)
		footer.add_child(rewards)
		rewards.add_child(_metric("coin", _money(float(quest.get("coins", 0))), Color("896221")))
		var reward_text: String = str(quest.get("reward_text", ""))
		if " + " in reward_text:
			var special: String = reward_text.get_slice(" + ", 1)
			var reward_row := _hbox(5)
			rewards.add_child(reward_row)
			var seed_crop: String = "icecap" if "Icecap" in special else ("sunburst" if "Sunburst" in special else "golden")
			reward_row.add_child(_icon({"kind": "seed", "crop": seed_crop} if "seeds" in special else {"kind": "gear", "id": "prospectors_hat"}, 26))
			reward_row.add_child(_label(special, 13, INK, true))
		var claim := _button("Claim reward", key, true)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(claim)
		_refs[key] = claim

func _build_help() -> void:
	_heading("Welcome to Taterland", "A little manual farming. A very wild potato market.")
	var intro: PanelContainer = _card(INK, 18)
	_body.add_child(intro)
	intro.add_child(_wrap("CHECK PRICES → PLANT → WATER → HARVEST → SELL OR HOLD", 20, CREAM, true))
	_help_step("Touch screens", "Drag the stick to move; push to its edge to sprint. Tap beds, buildings and equipment to interact. Pinch the farm with two fingers to zoom. Tools contains tools, seeds, zoom +/− and Cancel task. Swipe menus to scroll. Use works beside beds, the tank and ferry; Menu opens every activity.")
	_help_step("01  Move & farm", "WASD / arrows to walk · Hold Shift to sprint\nTwo-finger scroll / pinch to zoom\n1 Hoe · 2 Seeds · 3 Water · 4 Harvest · 5 Spray\nClick a bed to use your tool.")
	_help_step("02  Grow", "Water once. Harvest when ripe.\nRusset 10s · Golden 25s · Giant 40s · Radioactive 50s · Sunburst 55s · Icecap 60s")
	_help_step("03  Buy low. Sell high.", "B: Market · I: Inventory · F: Sell held\nSurges last 10 seconds. Save crops for the right price.")
	_help_step("04  Go bigger", "U: Upgrade tools\nChain harvests within 3.5s for up to ×16 bonuses.")
	_help_step("05  Find your build", "R: Roll for gear and builds using game coins. Empty rolls happen.\nP: Discoveries · Q: Quests")
	_help_step("06  Hire a crew", "Ducks clear pests: up to 1 / 2 / 3 per island.\nHire more or train them for speed.")
	_help_step("07  Shops & travel", "Walk up to a shop or NPC and press E when the small badge appears, or tap the badge. You can also click a building or sign. E still works beside beds and the ferry.")
	_help_step("08  Taxes & debt", "Tax is deducted after every third major boom and its full 10-second selling window. Natural spikes and practice do not count. Debt is playable; only going below your bankruptcy limit ends the run. Check the forecast in Taxes.")
	_help_step("09  Winter tricks", "Burn 25 Icecaps for faster growth.\nFrostbreak: hoe icy beds within 20s for a seed + stock bonus.")
	_body.add_child(_button("Optional Valley tour", "tutorial:restart"))
	_body.add_child(_button("Show farm tips" if _state.farm_help.data.hidden or not _state.farm_help.data.enabled else "Hide farm tips", "farm_help:toggle"))
	_body.add_child(_button("Let's get growing  →", "close", true))

func _help_step(title: String, detail: String) -> void:
	var card := _surface("quest")
	_body.add_child(card)
	var box: VBoxContainer = _vbox(3)
	card.add_child(box)
	box.add_child(_label(title, 17, INK, true))
	box.add_child(_wrap(detail, 14, MUTED))

func _build_pause() -> void:
	_heading("Your farm", "Choose your next move.")
	var menu: GridContainer = GridContainer.new()
	menu.columns = 3
	menu.add_theme_constant_override("h_separation", 10)
	menu.add_theme_constant_override("v_separation", 10)
	_body.add_child(menu)
	var activity_name: String = "Duck patrol" if _island_id() == 1 else ("Buyer contracts" if _island_id() == 2 else "Frost furnace")
	var entries: Array = [["Inventory", "inventory", "I", "build_crate"], ["Market", "market", "B", "trader_token"], ["Debug", "debug", "", "debug"], ["Player builds", "builds", "C", "farmer"], [activity_name, "activities", "", "duck" if _island_id() == 1 else ("contract" if _island_id() == 2 else "furnace")], ["Quests", "quests", "Q", "almanac"], ["Tool upgrades", "tools", "U", "hoe"], ["Roll House", "roll", "R", "gambler"], ["Travel islands", "island", "", "compass"], ["PotatoDex", "dex", "P", "lens"], ["Tracked prices", "tracked_prices", "", "investor"]]
	if _island_id() > 1:
		entries.insert(5, ["Duck patrol", "duck_patrol", "", "duck"])
	if _tutorial.is_empty():
		entries.append(["Taxes", "taxes", "", "investor"])
		if _island_id() >= 2: entries.append(["Weather & protection", "climate", "", "almanac"])
	for entry: Array in entries:
		var tutorial_feature: String = str(entry[1])
		if tutorial_feature == "activities":
			tutorial_feature = "duck_patrol"
		elif tutorial_feature in ["tracked_prices", "dex"]:
			tutorial_feature = "stock" if tutorial_feature == "tracked_prices" else "inventory"
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
		var icon_kind: String = "activity" if entry[1] in ["activities", "duck_patrol", "debug"] else ("build" if str(entry[3]) in ["farmer", "gambler", "investor"] else ("tool" if entry[3] == "hoe" else ("build_crate" if entry[3] == "build_crate" else "relic")))
		row.add_child(_icon({"kind": icon_kind, "id": str(entry[3])}, 36))
		var name_label: Label = _wrap(str(entry[0]), 13, INK, true)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
	_body.add_child(_button("Settings, saves & help", "toggle_details:menu_settings"))
	var settings := _vbox(8)
	_body.add_child(settings)
	_refs.menu_settings = settings
	settings.hide()
	var utility: BoxContainer = _hbox(8)
	settings.add_child(utility)
	for entry: Array in [["Save farm", "save"], ["Load farm", "load"], ["Graphics", "graphics"], ["How to play", "help"]]:
		var button: Button = _button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(button)
	if _tutorial.is_empty():
		settings.add_child(_button("Optional Valley tour", "tutorial:restart"))
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
	_heading("Graphics", "Choose what feels best on this device.")
	_info("graphics_current", "", GREEN, 19)
	for entry: Array in [["balanced", "Balanced", "Clear farm · gentle shadows"], ["smooth", "Smooth", "Faster farm · shadows off"], ["crisp", "Crisp", "Sharpest farm · needs more power"]]:
		var choice: Button = _button(str(entry[1]) + "\n" + str(entry[2]), "graphics:" + str(entry[0]))
		choice.custom_minimum_size.y = 70
		_body.add_child(choice)
		_refs["graphics_" + str(entry[0])] = choice
	_info("graphics_note", "Sharp menus in every mode.\nSaved on this device.", MUTED, 15)
	_body.add_child(_button("Back to farm", "close"))
	_refresh_graphics()

func _refresh_graphics() -> void:
	if not _refs.has("graphics_current"):
		return
	_refs.graphics_current.text = "Using " + _graphics_quality.capitalize()
	for mode: String in ["balanced", "smooth", "crisp"]:
		_refs["graphics_" + mode].disabled = mode == _graphics_quality

func _refresh_panel() -> void:
	if _panel_kind == "climate":
		_refresh_climate()
		return
	if _panel_kind in ["taxes", "blinds"]:
		_refresh_blinds()
		return
	if not is_instance_valid(_state):
		return
	_restore_tutorial_buttons()
	var coins: float = float(_state.get("coins"))
	if _panel_kind == "roll" and _crate_reel:
		var system: Object = _build_system()
		var crates: int = int(system.get("build_crates")) if system != null else 0
		_refs.roll_purse.text = "BUILD-ONLY REEL · %d crate%s remaining" % [crates, "" if crates == 1 else "s"]
		_set_button("build:open_crate", "Opening crate…" if _rolling else ("Open another · %d owned" % crates if crates > 0 else "You need a Build Crate"), _rolling or crates <= 0)
		_apply_tutorial_buttons()
		return
	var markets: Dictionary = _state.get("market")
	var storage: Dictionary = _state.get("storage")
	match _panel_kind:
		"market":
			_refs.market_note.text = ("EXPORT ×%.1f · %.1fs left. " % [float(_state.get("export_factor")), float(_state.get("export_timer"))] if bool(_state.get("export_active")) else "") + "Changes vs opening prices; graphs show recent sale prices."
			if _state.disaster_market_active():
				_refs.market_note.text = "Disaster market · Up to −95%. Export and reward bonuses cannot create a positive boom during recovery."
			if _tutorial_seed_market():
				_refs.market_note.text = "Buy 1 Russet → head to the gold bed." if _tutorial_allows("buy:russet:1") else "Just browsing. Shop after the tour."
			for crop: String in _panel_crops:
				var quote: Dictionary = markets.get(crop, {})
				var sell: float = float(quote.get("sell", 0))
				var seed: float = float(quote.get("seed", 0))
				var change: float = float(quote.get("change", 0))
				var color: Color = GREEN if change >= 0 else CHERRY
				_refs[crop + ":price"].text = "SELL " + _money(sell)
				_refs[crop + ":change"].text = _change_text(change)
				_refs[crop + ":change"].add_theme_color_override("font_color", color)
				_refs[crop + ":quote"].text = "%s\nSeed %s · Held %s" % [_trend(change, quote.get("history", [])), _money(seed), _number(float(storage.get(crop, 0)))]
				if _tutorial_seed_market():
					_refs[crop + ":quote"].text = "Seed %s each\nOwned %s seeds · Grows in 10s" % [_money(seed), _number(float(_state.get("seed_inventory").get(crop, 0)))]
				var history: Array = quote.get("history", [])
				_refs[crop + ":graph"].set_history(history, color)
				var single_buy: String = "buy:" + crop + ":1"
				var guided_purchase: bool = not _tutorial.is_empty() and crop == "russet" and _tutorial_allows(single_buy)
				_set_button(single_buy, "Buy 1 Russet" if guided_purchase else "Buy 1", coins < seed)
				_set_button("buy:" + crop + ":5", "Buy 5", coins < seed * 5)
				_set_button("sell:" + crop + ":-1", "Sell held", float(storage.get(crop, 0)) <= 0)
		"barn", "inventory":
			_refresh_inventory()
		"tools":
			var levels: Dictionary = _state.get("tools")
			for tool: String in ["hoe", "water", "harvest"]:
				var costs: Array = _tool_costs().get(tool, [])
				var level: int = clampi(int(levels.get(tool, 0)), 0, costs.size())
				var areas: Array = TOOL_AREAS[tool]
				var maximum: bool = level >= costs.size()
				var winter_gate: bool = level >= 2 and _island_id() != 3 and not maximum
				_refs["upgrade:" + tool + ":detail"].text = "Now: %s per action.%s" % [areas[mini(level, areas.size() - 1)], " Fully upgraded." if maximum else " Next: " + str(areas[mini(level + 1, areas.size() - 1)]) + (" · Frost Hollow only." if winter_gate else ".")]
				if tool == "water":
					var carried: int = 16 + 16 * level
					_refs["upgrade:water:detail"].text = "Carries %d water · %s per action." % [carried, areas[mini(level, areas.size() - 1)]]
					if not maximum:
						_refs["upgrade:water:detail"].text += "\nNext: %d water · %s%s" % [carried + 16, areas[mini(level + 1, areas.size() - 1)], " · Frost Hollow only." if winter_gate else "."]
				var cost: float = float(costs[level]) if not maximum else 0.0
				_set_button("upgrade:" + tool, "Fully upgraded" if maximum else ("Visit Frost Hollow" if winter_gate else _money(cost)), maximum or winter_gate or coins < cost)
			var expanded: bool = bool(_state.get("expansion")) or _island_id() >= 2
			_refs["upgrade:expansion:detail"].text = "All %d beds are open. Your hands make them productive." % int(_state.get("plots").size()) if _island_id() >= 2 else "Unlock all 24 garden beds. Every patch is still farmed by hand."
			_set_button("upgrade:expansion", "Open ✓" if expanded else "$1.8K", expanded or coins < 1800)
		"roll":
			_refresh_trophies()
			_refs.crown_offer.visible = _frozen_crown if _rolling else _wears_crown()
			_refs.trophy_toggle.disabled = _rolling
			var stall_open: bool = bool(_state.call("roll_available")) if _state.has_method("roll_available") else true
			if not stall_open and not _rolling:
				_refs.roll_result_title.text = "THIS TABLE IS CLOSED"
				_refs.roll_result_detail.text = "Use the Roll House on your newest unlocked island."
				_refs.roll_result_detail.show()
			_refs.roll_purse.text = "Purse %s  ·  %s stake +%.0f%% quality" % [_money(_frozen_coins if _rolling else coins), _stake_kind.replace("_", " ").capitalize(), _frozen_stake_bonus if _rolling else float(_state.call("stake_luck_bonus", _stake_kind))]
			var all_in_floor: float = _minimum_roll_stake("all_in")
			_refs.roll_minimum.text = "Single roll %s  ·  All-in requires more than %s" % [_money(float(_state.call("roll_cost", "normal"))), _money(all_in_floor)]
			var labels: Dictionary = {"normal": "Roll", "big": "Big roll", "stupid": "Stupid roll", "all_in": "Confirm all-in" if _all_in_pending else "All-in"}
			for kind: String in ["normal", "big", "stupid", "all_in"]:
				var cost: float = _frozen_coins if kind == "all_in" and _rolling else float(_state.call("roll_cost", kind))
				var caption: String = "%s · %s" % [labels[kind], _money(cost)]
				if kind == "all_in" and coins <= all_in_floor and not _rolling:
					caption = "All-in · Need > " + _money(all_in_floor)
				_set_button("roll:" + kind, caption, _rolling or not _can_roll_stake(kind))
				_refs["roll:" + kind].tooltip_text = "Your entire purse must be greater than " + _money(all_in_floor) + "." if kind == "all_in" else "One roll costs " + _money(cost) + "."
			for count: int in [3, 5]:
				var batch_kind: String = _batch_kind
				var batch_cost: float = float(_state.call("roll_cost", batch_kind)) * count
				_set_button("batch:" + str(count), "%s ×%d · %s" % [batch_kind.capitalize(), count, _money(batch_cost)], _rolling or not stall_open or coins < batch_cost)
			if _refs.has("batch_stake"):
				_refs.batch_stake.disabled = _rolling or not stall_open
			_refs.all_in_warning.visible = _all_in_pending
			_refs.all_in_warning.text = "Risk every coin? Click CONFIRM ALL-IN to commit this stake."
			_refs.cancel_all_in.visible = _all_in_pending and not _rolling
			var stake_bonus: float = _frozen_stake_bonus if _rolling else float(_state.stake_luck_bonus(_stake_kind))
			var build_quality: float = _frozen_build_quality if _rolling else float(_state._build_bonus("roll_quality_factor", 1.0))
			var tally: Dictionary = (_frozen_luck_breakdown if _rolling else _state.luck_breakdown()).duplicate(true)
			tally["stake_bonus"] = stake_bonus
			tally["build_quality"] = build_quality
			_refs.roll_luck_meter.set_values(tally)
			var quality: float = (1.0 + stake_bonus / 100.0) * build_quality
			var luck_quality: float = 1.0 + ((_frozen_luck if _rolling else _effective_luck()) - 1.0) * 0.12
			_refs.roll_quality.text = "Roll quality %.2f×  ·  Luck +%s%%  ·  Final luck %s×" % [quality, RollLuckMeter.number(float(tally.total_percent)), RollLuckMeter.number(float(tally.total))]
			_refs.roll_luck_total.text = "Earned +%s%% · Gear +%s%%\nNormal cap: +900%% (10×)\nLuck boost ×%s %s" % [RollLuckMeter.number(float(tally.earned) * 100.0), RollLuckMeter.number(float(tally.gear) * 100.0), RollLuckMeter.number(float(tally.multiplier)), "active" if float(tally.multiplier) > 1.0 else "(base)"]
			if _refs.roll_luck_meter.playing: _refs.roll_quality.text = _refs.roll_luck_meter.description
			_refs.roll_luck_math.text = (_frozen_luck_math if _rolling else _luck_math()) + "\n\nStake: 1 + %.0f%% = %.2f×\nBuild quality: %.2f×\nCombined roll quality: %.2f×\nLuck quality: 1 + (total luck − 1) × 0.12 = %.3f×\nHigh-luck rarity factor: max(1, total luck / 10) = %s×" % [stake_bonus, 1.0 + stake_bonus / 100.0, build_quality, quality, luck_quality, RollLuckMeter.number(maxf(1.0, float(tally.total) / 10.0))]
			var odds: Array = _frozen_odds if _rolling else _state.call("roll_odds", _stake_kind)
			_spinner.set_odds(odds)
			for entry: Dictionary in odds:
				var key: String = "odds:" + str(entry.get("tier", "common"))
				if _refs.has(key):
					_refs[key].text = "%s   %s%%" % ["Mystery" if str(entry.tier) == "mystery" else str(entry.tier).capitalize(), _roll_chance(float(entry.get("chance", 0)))]
		"dex": _refresh_dex()

		"island":
			_refresh_islands()
		"builds":
			_refresh_builds()
		"activities":
			_refresh_activities()
		"duck_patrol":
			_refresh_duck_patrol()
		"tracked_prices":
			_refresh_tracked_prices()
		"debug":
			_refresh_debug()
		"quests":
			var completed: int = 0
			var ready: int = 0
			for quest: Dictionary in _quests():
				var id: String = str(quest.get("id", ""))
				var progress: float = float(quest.get("progress", 0))
				var target: float = maxf(1.0, float(quest.get("target", 1)))
				var claimed: bool = bool(quest.get("claimed", false))
				var complete: bool = bool(quest.get("complete", false))
				var bar: ProgressBar = _refs.get("quest:" + id + ":bar") as ProgressBar
				if not is_instance_valid(bar):
					continue
				bar.max_value = target
				bar.value = minf(progress, target)
				_refs["quest:" + id + ":detail"].text = "%s / %s" % [_number(minf(progress, target)), _number(target)]
				Cozy.badge(_refs["quest:" + id + ":status"], "Claimed" if claimed else ("Claim ready" if complete else "In progress"), "active" if claimed else ("ready" if complete else "neutral"))
				_refs["quest:" + id + ":card"].add_theme_stylebox_override("panel", Cozy.surface("quest", GREEN if claimed else GOLD, complete))
				completed += 1 if claimed else 0
				ready += 1 if complete and not claimed else 0
				var claim: Button = _refs["quest:" + id]
				claim.visible = complete and not claimed
				claim.disabled = claimed or not complete
				claim.text = "Claim reward"
			_refs.quest_note.text = "%d / %d rewards collected%s" % [completed, _quests().size(), " · %d ready to claim!" % ready if ready > 0 else " · Keep growing!"]
	_apply_tutorial_buttons()

func _set_button(key: String, text: String, disabled: bool) -> void:
	var button: Button = _refs.get(key) as Button
	if is_instance_valid(button):
		button.text = text
		button.disabled = disabled

func _change_text(change: float) -> String:
	if absf(change) >= 10000.0:
		return ("+" if change >= 0 else "−") + _number(absf(change)) + "%"
	return "%+.0f%%" % change

func _trend(change: float, history: Array = []) -> String:
	if absf(change) >= 400:
		return "GOING INSANE"
	if history.size() >= 2:
		var reference: float = float(history[maxi(0, history.size() - 5)])
		change = (float(history[-1]) / reference - 1.0) * 100.0 if reference > 0 else 0.0
	if change >= 60:
		return "SURGING"
	if change <= -40:
		return "FALLING HARD"
	if change >= 5:
		return "RISING"
	if change <= -5:
		return "FALLING"
	return "STABLE"

func _blind_money(value: float) -> String:
	return str(_state.call("money", value, true))

func _money(value: float) -> String:
	return str(_state.call("money", value)) if is_instance_valid(_state) else "$%.0f" % value

func _number(value: float) -> String:
	return str(_state.call("format_number", value)) if is_instance_valid(_state) else "%.0f" % value

func _island_id() -> int:
	return maxi(1, int(_state.get("current_island"))) if is_instance_valid(_state) else 1

func _market_crops() -> Array[String]:
	if _tutorial_seed_market():
		return ["russet"]
	if not is_instance_valid(_state) or not _state.has_method("available_crops"):
		return CROP_IDS.duplicate()
	var result: Array[String] = []
	var available: Array = _state.call("available_crops")
	for id: Variant in available:
		result.append(str(id))
	return result

func _tutorial_seed_market() -> bool:
	return not _tutorial.is_empty() and "stock" not in _tutorial.get("features", [])

func _known_crops() -> Array[String]:
	var result: Array[String] = []
	var storage: Dictionary = _state.get("storage") if is_instance_valid(_state) else {}
	var seeds: Dictionary = _state.get("seed_inventory") if is_instance_valid(_state) else {}
	var available: Array[String] = _market_crops()
	for id: String in _all_crop_ids():
		if id in CROP_IDS or id in available or float(storage.get(id, 0)) > 0 or float(seeds.get(id, 0)) > 0 or (id == "sunburst" and _flag("island2_unlocked")) or (id == "icecap" and _flag("island3_unlocked")):
			result.append(id)
	return result

func _quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(_state) and _state.has_method("quest_info"):
		var quests: Array = _state.call("quest_info")
		for quest: Dictionary in quests:
			result.append(quest)
	return result

func _update_island_style() -> void:
	var island: int = _island_id()
	_island_button.text = "%s\nIsland %d  ·  Travel →" % [str(_state.call("island_name")), island]
	if _visual_island == island:
		return
	_visual_island = island
	var shores: bool = island == 2
	var winter: bool = island == 3
	_sidebar_box.add_theme_stylebox_override("panel", _style(Color("edf5fa") if winter else (SHORES_PAPER if shores else CREAM), 13, 17))
	_island_button.add_theme_stylebox_override("normal", _style(Color("486c90") if winter else (CORAL if shores else INK), 10, 10))
	_island_button.add_theme_stylebox_override("hover", _style(Color("ab614b") if shores else GREEN, 10, 10))
	_quest_button.add_theme_stylebox_override("normal", _style(Color("d7e6f1") if winter else (Color("f2d39b") if shores else PAPER), 10, 10))

func _update_quest_sidebar() -> void:
	_quest_button.visible = true
	var ready: int = 0
	for quest: Dictionary in _quests():
		if bool(quest.get("complete", false)) and not bool(quest.get("claimed", false)):
			ready += 1
	_quest_button.text = "Claim %d reward%s  [Q]" % [ready, "" if ready == 1 else "s"] if ready > 0 else "Quest board  [Q]"

func _build_export_strip() -> void:
	_export_box = _card(INK, 12)
	_export_box.name = "StockCountdown"
	_place(_export_box, Rect2(28, 688, 302, 86))
	_export_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_export_box.offset_left = 28
	_export_box.offset_right = 330
	_export_box.offset_top = -112
	_export_box.offset_bottom = -26
	_export_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surge_style = _style(Color("132c29"), 12, 16, Color("32ff8c"))
	_surge_style.set_border_width_all(2)
	_surge_style.shadow_size = 20
	_export_box.add_theme_stylebox_override("panel", _surge_style)
	var column: VBoxContainer = _vbox(3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_export_box.add_child(column)
	var compact_font: FontVariation = _compact_heading_font()
	_export_title = _label("NEXT STOCK  3:00", 25, CREAM, true)
	_export_title.add_theme_font_override("font", compact_font)
	_export_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_export_title)
	_top["surge"] = _export_title
	_export_detail = _label("+500–2,999% stock boom", 12, Color("8cdaa9"), true)
	_export_detail.add_theme_font_override("font", compact_font)
	_export_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_export_detail)
	_export_bar = ProgressBar.new()
	_export_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_export_bar.custom_minimum_size.y = 3
	_export_bar.show_percentage = false
	_export_bar.add_theme_stylebox_override("background", _style(Color("284439"), 0, 2))
	_export_bar.add_theme_stylebox_override("fill", _style(Color("32ff8c"), 0, 2))
	column.add_child(_export_bar)

func _update_export_strip() -> void:
	_update_surge_timer()

func handle_island_changed() -> void:
	if not is_instance_valid(_state):
		return
	_visual_island = 0
	update_state(_state)

func show_export_alert(_active: bool) -> void:
	if is_instance_valid(_state):
		_update_export_strip()

func is_roll_animating() -> bool:
	return _rolling

func begin_roll(kind: String = "") -> bool:
	if _rolling or not is_instance_valid(_state):
		return false
	var needs_build_deck: bool = kind == "build_crate"
	var rebuild: bool = _panel_kind != "roll" or _crate_reel != needs_build_deck
	_crate_reel = needs_build_deck
	if rebuild:
		show_panel("roll", _state, needs_build_deck)
	if not kind.is_empty():
		_stake_kind = kind
	_rolling = true
	_frozen_odds = [] if _crate_reel else _state.call("roll_odds", _stake_kind)
	_frozen_luck = _effective_luck()
	_frozen_luck_math = _luck_math()
	_frozen_luck_breakdown = _state.luck_breakdown().duplicate(true)
	_frozen_build_quality = float(_state._build_bonus("roll_quality_factor", 1.0))
	_frozen_crown = _wears_crown()
	_frozen_stake_bonus = 0.0 if _crate_reel else float(_state.call("stake_luck_bonus", _stake_kind))
	_frozen_coins = float(_state.get("coins"))
	_all_in_pending = false
	_batch_results.clear()
	if _refs.has("batch_results"):
		_refs.batch_results.hide()
		for child: Node in _refs.batch_results.get_children():
			_refs.batch_results.remove_child(child)
			child.queue_free()
	_refs.roll_result_title.text = "CALCULATING YOUR ROLL…" if not _crate_reel else "LET IT ROLL…"
	_refs.roll_result_detail.text = "A little suspense. A lot of possibility."
	_refs.roll_result_detail.hide()
	_refs.roll_accounting.hide()
	_toast_box.hide()
	_reward_box.hide()
	_refresh_panel()
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0
	if _refs.has("roll_luck_meter"): _refs.roll_luck_meter.play()
	return true

var _pending_spin: Dictionary = {}

func _start_pending_spin() -> void:
	if not _rolling or _pending_spin.is_empty() or not is_instance_valid(_spinner): return
	_spinner.spin_to(_pending_spin)
	_pending_spin = {}
	_refs.roll_result_title.text = "LET IT ROLL…"

func spin_roll(result: Dictionary) -> void:
	if not _rolling:
		return
	if result.is_empty() or not is_instance_valid(_spinner):
		cancel_roll()
		return
	_pending_spin = result.duplicate(true)
	if not _refs.has("roll_luck_meter") or not _refs.roll_luck_meter.playing:
		_start_pending_spin()

func cancel_roll() -> void:
	_pending_spin = {}
	if _refs.has("roll_luck_meter"): _refs.roll_luck_meter.finish()
	_rolling = false
	_batch_results.clear()
	if is_instance_valid(_spinner):
		_spinner.spinning = false
		_spinner.set_process(false)
	if _panel_kind == "roll":
		_refs.roll_result_title.text = "PICK A STAKE. LET IT ROLL."
		_refs.roll_result_detail.text = "Your coins are ready when you are."
		_refs.roll_result_detail.hide()
		_refs.roll_accounting.hide()
		_refresh_panel()

func _on_roll_finished(result: Dictionary) -> void:
	if not _rolling:
		return
	_rolling = false
	if _refs.has("roll_luck_meter"): _refs.roll_luck_meter.finish()
	_revealed_roll = result.duplicate(true)
	var title: String = str(result.get("title", "Roll complete"))
	var detail: String = str(result.get("detail", ""))
	var tier: String = str(result.get("tier", "common"))
	_refs.roll_result_title.text = "%s · %s" % [tier.to_upper(), title]
	_refs.roll_result_detail.text = detail
	_refs.roll_result_detail.show()
	if not _batch_results.is_empty():
		var bonus_count: int = _batch_bonus_count()
		_refs.roll_result_title.text = "%d PAID + AURORA BONUS · %s" % [_batch_results.size() - bonus_count, title] if bonus_count > 0 else "%d ROLLS · %s" % [_batch_results.size(), title]
		_refs.roll_result_detail.text = ("Your Crown added one free roll. " if bonus_count > 0 else "") + "Best pull shown above. Hover a card for the full result."
		_show_batch_results()
	_show_roll_accounting()
	_refresh_panel()
	_top.coins.text = _money(float(_state.get("coins")))
	if RewardFeedback.celebrates(tier) and _tutorial.is_empty():
		_market_impact.reward(_island_id(), 6.0)
	roll_revealed.emit(title, detail, tier)

func _sync_crop_catalog() -> void:
	if _crop_defs.is_empty():
		var constants: Dictionary = _state.get_script().get_script_constant_map()
		_crop_defs = constants.get("CROPS", {})
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
	var button: Button = _button(_crop_name(id), "crop:" + id)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	_crop_row.add_child(button)
	_crop_buttons[id] = button
	button.visible = id in _market_crops()

func _crop_name(id: String) -> String:
	var definition: Dictionary = _crop_defs.get(id, {})
	return str(definition.get("name", CROP_NAMES.get(id, id.capitalize()))).trim_suffix(" Potato")

func _crop_grow(id: String) -> int:
	var definition: Dictionary = _crop_defs.get(id, {})
	return int(definition.get("grow", GROW_TIMES.get(id, 10)))

func _crop_color(id: String) -> Color:
	var definition: Dictionary = _crop_defs.get(id, {})
	var value: Variant = definition.get("color", CROP_COLORS.get(id, GOLD))
	return value if value is Color else Color(str(value))

func _tool_costs() -> Dictionary:
	var constants: Dictionary = _state.get_script().get_script_constant_map()
	return constants.get("TOOL_COSTS", TOOL_COSTS)

func _flag(key: String) -> bool:
	return bool(_state.get(key)) if is_instance_valid(_state) else false

func _preview_stake(kind: String) -> void:
	if _rolling:
		return
	_stake_kind = kind
	if _panel_kind == "roll":
		_refresh_panel()

func _inventory_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(_state) and _state.has_method("inventory_info"):
		var data: Array = _state.call("inventory_info")
		for entry: Dictionary in data:
			if str(entry.get("kind", "")) != "tool":
				result.append(entry)
	return result

func _inventory_id_string(entries: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("id", "")))
	return "|".join(ids)

func _set_inventory_tab() -> void:
	_refs["upgrade:barn:card"].visible = _inventory_tab == "crops"
	_refs["barn_tip"].visible = _inventory_tab == "crops" and int(_state.get("barn_level")) == 0
	for section: Variant in _inventory_sections:
		_inventory_sections[section].visible = str(section) == _inventory_tab
		var button: Button = _refs.get("tab:" + str(section)) as Button
		if is_instance_valid(button):
			button.add_theme_stylebox_override("normal", _style(Color("dce7d1") if str(section) == _inventory_tab else PAPER, 10, 10))

func _refresh_inventory() -> void:
	_refs.inventory_total.text = "HELD VALUE %s  ·  %s / %s crop storage" % [_money(float(_state.call("barn_value"))), _number(float(_state.call("storage_used"))), _number(float(_state.get("capacity")))]
	_refresh_equipment()
	var available: Array[String] = _market_crops()
	for entry: Dictionary in _inventory_data():
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", "relic"))
		var key: String = "item:" + id
		if not _refs.has(key + ":title"):
			continue
		_refs[key + ":title"].text = "%s%s" % [str(entry.get("name", "Found item")), " ×" + _number(float(entry.get("count", 1)))]
		var detail: String = str(entry.get("effect", entry.get("description", "")))
		var button: Button = _refs.get(key + ":action") as Button
		match kind:
			"crop", "mutation", "processed":
				detail = "Current value %s%s" % [_money(float(entry.get("sell_value", entry.get("processed_value", entry.get("value", 0))))), " · " + detail if kind == "mutation" else " · held until you sell"]
				if is_instance_valid(button):
					button.text = "Sell · " + _money(float(entry.get("sell_value", entry.get("processed_value", entry.get("value", 0)))))
				if kind == "processed" and id == "processing":
					detail = str(entry.get("effect", "Processing")) + " · loaded batch"
					if is_instance_valid(button):
						button.text = "View processor"
				elif kind == "processed" and id.begins_with("queued:"):
					detail = str(entry.get("effect", "")) + " · waiting in the production queue"
					if is_instance_valid(button): button.text = "View queue"
				elif kind == "processed" and id == "harvest_stake":
					detail = str(entry.get("effect", "")) + " · reserved harvest stake"
					if is_instance_valid(button): button.text = "View stake result"
				elif kind == "processed" and is_instance_valid(button):
					button.text = "Sell all batches"
			"build":
				detail = str(entry.get("effect", "")) + " · " + str(entry.get("description", ""))
				if is_instance_valid(button):
					button.text = "Equipped" if bool(entry.get("active", false)) else "Equip build"
					button.disabled = bool(entry.get("active", false))
			"seed":
				var crop: String = str(entry.get("crop", "russet"))
				detail = "%ds growth · %s" % [_crop_grow(crop), "Ready to plant here" if crop in available else "Plant on its home island"]
				if is_instance_valid(button):
					button.text = "Selected" if str(_state.get("selected_crop")) == crop else "Select seeds"
					button.disabled = crop not in available or str(_state.get("selected_crop")) == crop
			"build_crate":
				detail = "Own %d · Open for one build level" % maxi(0, int(entry.get("count", 0)))
				if is_instance_valid(button):
					button.text = "Open crate"
					button.disabled = int(entry.get("count", 0)) <= 0
			"gear":
				var equipped: bool = bool(entry.get("equipped", false))
				var specialty: String = str(entry.get("role", "all"))
				_refs[key + ":title"].text = str(entry.get("name", "Gear"))
				detail = detail.replace(" while equipped", "")
				if specialty not in ["", "all"]: detail += "\n" + specialty.capitalize() + " specialty"
				if float(entry.get("synergy", 1.0)) > 1.0:
					detail += " · Match +25%"
				Cozy.badge(_refs[key + ":status"], "Equipped" if equipped else "Owned ×%d" % int(entry.get("count", 1)), "active" if equipped else "neutral")
				_refs[key + ":card"].add_theme_stylebox_override("panel", Cozy.surface("gear", Cozy.RARITY_COLORS.get(str(entry.get("rarity", "common")), GREEN), equipped))
				if is_instance_valid(button):
					button.text = "Equipped ✓" if equipped else "Equip " + str(entry.get("slot", "gear"))
					button.disabled = equipped
			"relic":
				detail = "ACTIVE · " + (detail if not detail.is_empty() else str(entry.get("description", "Permanent bonus")))
		_refs[key + ":detail"].text = detail
	var barn_cost: float = 500.0 * pow(5.0, int(_state.get("barn_level")))
	var maxed: bool = int(_state.get("barn_level")) >= 20
	_refs["barn_tip"].visible = _inventory_tab == "crops" and int(_state.get("barn_level")) == 0
	_refs["upgrade:barn:detail"].text = "Maximum barn capacity reached." if maxed else "Adds %s spaces for your harvest." % _number(200.0 * pow(4.0, int(_state.get("barn_level"))))
	_set_button("upgrade:barn", "Max level" if maxed else "Upgrade · " + _money(barn_cost), maxed or float(_state.get("coins")) < barn_cost)
	var mutations: Array = _state.get("mutations")
	_set_button("sell_mutations", "Sell all mutation crates", mutations.is_empty())

func _catalog_number(key: String, fallback: float) -> float:
	var constants: Dictionary = _state.get_script().get_script_constant_map()
	return float(constants.get(key, fallback))

func set_market_intensity(island: int, percent: float) -> void:
	if not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	_market_impact.set_quote(island, percent)

func show_market_surge(island: int, intensity: float, seconds: float) -> void:
	if not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	_market_impact.surge(island, intensity, seconds)

func _build_system() -> Object:
	if not is_instance_valid(_state):
		return null
	var system: Variant = _state.get("build_system")
	return system if system is Object and is_instance_valid(system) else null

func _build_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var system: Object = _build_system()
	if system == null or not system.has_method("build_info"):
		return result
	var entries: Array = system.call("build_info")
	for entry: Dictionary in entries:
		result.append(entry)
	return result

func _update_builds_badge() -> void:
	for entry: Dictionary in _build_entries():
		if bool(entry.get("active", false)):
			_builds_button.text = "%s Lv.%d  [C]" % [str(entry.get("name", "Farmer")), int(entry.get("level", 1))]
			return
	_builds_button.text = "Builds  [C]"

func _build_builds() -> void:
	BuildPages.create(self)

func _refresh_builds() -> void:
	BuildPages.refresh(self)

func _build_tracked_prices() -> void:
	_heading("Tracked Seed Prices", "Pin your favourite seeds to the Seeds tray [2]. Choices save automatically.")
	var summary := _label("", 14, GREEN, true)
	_body.add_child(summary)
	_refs.tracked_summary = summary
	var checked := Cozy.toggle_texture(true)
	var unchecked := Cozy.toggle_texture(false)
	for id: String in _market_crops():
		var card := _surface("tracked", _crop_color(id), id in _tracked_ids())
		_body.add_child(card)
		_refs["tracked:" + id + ":card"] = card
		var row := _hbox(14)
		card.add_child(row)
		row.add_child(_icon({"kind": "seed", "crop": id, "backdrop": _crop_color(id).lerp(CREAM, 0.8).to_html(false)}, 64))
		var body := _vbox(3)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
		body.add_child(_label(_crop_name(id) + " seeds", 19, INK, true))
		var quote := _wrap("", 14, GREEN, true)
		body.add_child(quote)
		_refs["tracked:" + id + ":quote"] = quote
		body.add_child(_label("%ds to grow" % _crop_grow(id), 12, MUTED))
		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(116, 44)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggle.add_theme_font_override("font", Type.face(Type.BODY, 700))
		toggle.add_theme_font_size_override("font_size", 13)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			toggle.add_theme_color_override(color_name, INK)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			toggle.add_theme_stylebox_override(state, Cozy.button_style("hover" if state == "hover_pressed" else state, false))
		toggle.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, 10, GOLD))
		for icon_name: String in ["checked", "checked_disabled"]: toggle.add_theme_icon_override(icon_name, checked)
		for icon_name: String in ["unchecked", "unchecked_disabled"]: toggle.add_theme_icon_override(icon_name, unchecked)
		toggle.set_meta("tracked_seed", id)
		toggle.tooltip_text = "Show " + _crop_name(id) + " seed prices in your Seeds tray."
		toggle.toggled.connect(func(enabled: bool) -> void:
			action_requested.emit("tracked_seed:%s:%d" % [id, 1 if enabled else 0])
			_refresh_tracked_prices())
		row.add_child(toggle)
		_refs["tracked:" + id + ":toggle"] = toggle
	_body.add_child(_button("Back to the farm", "close", true))
	_refresh_tracked_prices()

func _refresh_tracked_prices() -> void:
	if not _refs.has("tracked_summary"): return
	var tracked := _tracked_ids()
	_refs.tracked_summary.text = "%d of %d seeds tracked" % [tracked.size(), _market_crops().size()] if not tracked.is_empty() else "No seeds tracked · choose a seed to pin its price"
	for id: String in _market_crops():
		var key: String = "tracked:" + id
		if not _refs.has(key + ":toggle"): continue
		var enabled: bool = id in tracked
		var toggle: CheckButton = _refs[key + ":toggle"]
		toggle.set_pressed_no_signal(enabled)
		toggle.text = "Tracking" if enabled else "Track"
		var quote: Dictionary = _state.market.get(id, {})
		_refs[key + ":quote"].text = "%s / seed" % _money(float(quote.get("seed", 0)))
		_refs[key + ":card"].add_theme_stylebox_override("panel", Cozy.surface("tracked", _crop_color(id), enabled))

func _tracked_ids() -> Array[String]:
	var ids: Array[String] = []
	if is_instance_valid(_state) and _state.has_method("tracked_seed_ids"):
		for id: Variant in _state.call("tracked_seed_ids"):
			ids.append(str(id))
	else:
		ids = _market_crops()
	return ids

func _update_tracked_prices() -> void:
	var ids: Array[String] = _tracked_ids()
	var signature: String = "|".join(ids)
	if signature != _tracked_signature or _tracked_row.get_child_count() == 0:
		_tracked_signature = signature
		for child: Node in _tracked_row.get_children():
			_tracked_row.remove_child(child)
			child.queue_free()
		_tracked_labels.clear()
		for id: String in ids:
			var column: VBoxContainer = _vbox(0)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_tracked_row.add_child(column)
			column.add_child(_label(_crop_name(id).to_upper() + " SEED", 9, MUTED, true))
			var quote: Label = _label("", 13, INK, true)
			column.add_child(quote)
			_tracked_labels[id] = quote
		if ids.is_empty():
			_tracked_row.add_child(_label("Choose seeds to pin their prices here.", 13, MUTED))
	var now: float = Time.get_ticks_msec() / 1000.0
	var market: Dictionary = _state.get("market")
	for id: String in ids:
		var price: float = float(market.get(id, {}).get("seed", 0))
		var previous: float = float(_tracked_prices.get(id, price))
		if not is_equal_approx(price, previous):
			_price_moves[id] = {"from": previous, "to": price, "until": now + 2.5}
		_tracked_prices[id] = price
		var label: Label = _tracked_labels[id]
		var move: Dictionary = _price_moves.get(id, {})
		var fresh: bool = float(move.get("until", 0)) > now
		label.text = "%s → %s %s" % [_money(float(move.get("from", price))), _money(price), "↑" if price > float(move.get("from", price)) else "↓"] if fresh else _money(price)
		var color: Color = GREEN if price >= float(move.get("from", price)) else CHERRY
		label.add_theme_color_override("font_color", color if fresh else INK)
		label.add_theme_color_override("font_shadow_color", Color(color, 0.45 if fresh else 0.0))
		label.add_theme_constant_override("shadow_outline_size", 3 if fresh else 0)

func _update_surge_timer() -> void:
	if not _tutorial.is_empty():
		_surge_active = false
		_surge_urgent = false
		return
	if not _state.has_method("surge_info"):
		return
	var info: Dictionary = _state.call("surge_info")
	if bool(info.get("crash", false)):
		_surge_active = false
		_surge_urgent = false
		_export_title.text = "MARKET RECOVERING" if info.phase == "recovery" else "DISASTER CRASH"
		_export_title.add_theme_font_size_override("font_size", 22)
		_export_title.add_theme_color_override("font_color", Color("f4bd9e"))
		_export_detail.text = "%s %.0f%% · Booms paused" % [_crop_name(str(info.crop)), float(info.percent)]
		_export_detail.add_theme_color_override("font_color", Color("f4bd9e"))
		_export_bar.max_value = 75.0 if info.phase == "recovery" else 30.0
		_export_bar.value = float(info.timer)
		_export_bar.get_theme_stylebox("fill").bg_color = CHERRY
		_export_box.tooltip_text = "Disaster prices can fall up to 95%. Positive stocks and the Rocket wait until recovery ends."
		_market_impact.set_countdown(_island_id(), 180.0)
		return
	var seconds: int = ceili(maxf(0.0, float(info.get("timer", 180))))
	var rocket_seconds: int = ceili(float(info.get("rocket_timer", 1800)))
	var rocket_soon: bool = _island_id() >= 3 and rocket_seconds <= 10
	var span: String = "+3,000–10,000%" if _island_id() >= 3 else "+500–2,999%"
	_surge_active = bool(info.get("active", false))
	_surge_urgent = not _surge_active and (seconds <= 10 or rocket_soon)
	var accent: Color = _island_accent()
	_export_title.text = "JACKPOT · %ds · SELL [F]" % seconds if _surge_active else "NEXT STOCK  %d:%02d" % [seconds / 60, seconds % 60]
	if _surge_active and str(info.get("kind", "normal")) == "rocket":
		_export_title.text = "ROCKET · %ds · SELL [F]" % seconds
	elif rocket_soon and not _surge_active:
		_export_title.text = "ROCKET IN  %ds" % rocket_seconds
	_export_title.add_theme_font_size_override("font_size", 22 if _surge_active else 25)
	_export_title.add_theme_color_override("font_color", Color.WHITE if _surge_active or _surge_urgent else CREAM)
	_export_detail.text = "%s  +%.0f%%" % [_crop_name(str(info.get("crop", "russet"))).to_upper(), float(info.get("percent", 500))] if _surge_active else ("GET READY · " + span if _surge_urgent else span + " stock boom")
	if rocket_soon and not _surge_active:
		_export_detail.text = "+35,000–100,000% AFTER LIFTOFF"
	elif _island_id() >= 3 and not _surge_active and not _surge_urgent:
		_export_detail.text = "3K–10K%% · ROCKET %d:%02d" % [rocket_seconds / 60, rocket_seconds % 60]
	# Keep only actionable island activities as a single short secondary line.
	if not _surge_active and not _surge_urgent:
		if _island_id() == 2 and bool(_state.get("export_active")):
			_export_detail.text = "Export · %.0fs · Golden / Sunburst" % float(_state.get("export_timer"))
	var opportunity: Dictionary = _state.call("stock_opportunity")
	_export_box.tooltip_text = "Haul reference: %s (8%% of progression)\n%s %s at this quote. Grow and sell to earn it." % [_blind_money(opportunity.reference), _number(opportunity.units), _crop_name(opportunity.crop)]
	_export_detail.add_theme_color_override("font_color", accent)
	_export_bar.max_value = 10.0 if _surge_active else (10.0 if _surge_urgent else 180.0)
	_export_bar.value = float(info.get("timer", 180)) if _surge_active or _surge_urgent else 180.0 - float(info.get("timer", 180))
	if rocket_soon and not _surge_active:
		_export_bar.value = rocket_seconds
	_export_bar.get_theme_stylebox("fill").bg_color = accent
	_market_impact.set_countdown(_island_id(), minf(float(info.get("timer", 180)), float(rocket_seconds) if _island_id() >= 3 else 180.0) if not _surge_active else 180.0)

func _effective_luck() -> float:
	return float(_state.call("effective_luck")) if is_instance_valid(_state) and _state.has_method("effective_luck") else float(_state.get("luck"))

func spin_batch(results: Array) -> void:
	if not _rolling:
		return
	if results.is_empty():
		cancel_roll()
		return
	_batch_results = results.duplicate(true)
	var order: Array[String] = ["common", "rare", "build", "epic", "legendary", "mythic", "jackpot", "relic", "mystery"]
	var best: Dictionary = results[0]
	for result: Dictionary in results:
		if order.find(str(result.get("tier", "common"))) > order.find(str(best.get("tier", "common"))):
			best = result
	_refs.roll_result_title.text = "%d ROLLS IN ONE · FINDING YOUR BEST PULL…" % results.size()
	_refs.roll_result_detail.text = "%d paid + 1 Aurora bonus roll. Every result is yours." % (results.size() - 1) if _batch_bonus_count() > 0 else "All %d rewards are locked in. One reel, every reward." % results.size()
	spin_roll(best)

func _show_batch_results() -> void:
	if not _refs.has("batch_results"):
		return
	var row: GridContainer = _refs.batch_results
	row.show()
	for result: Dictionary in _batch_results:
		var tier: String = str(result.get("tier", "common"))
		var accent: Color = RollReel.COLORS.get(tier, Color("b8a3ce"))
		var card: PanelContainer = _surface("gear", accent)
		card.set_meta("result", result.duplicate(true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var column: VBoxContainer = _vbox(3)
		card.add_child(column)
		var item_id: String = str(result.get("item_id", ""))
		var result_title: String = str(result.get("title", "")).to_lower()
		var icon_kind: String = "gear" if not item_id.is_empty() else ("build_crate" if "build crate" in result_title else ("empty" if "empty" in result_title or "nothing" in result_title else "relic"))
		var icon: Control = _icon({"kind": icon_kind, "id": item_id if not item_id.is_empty() else "trader_token"}, 44)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var title: Label = _wrap(str(result.get("title", "Reward")), 14, INK, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size.x = 95
		column.add_child(title)
		var rarity: Label = _badge(tier.capitalize())
		rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(rarity)
		if _batch_bonus_count() > 0:
			var bonus_label: Label = _label("AURORA BONUS" if bool(result.get("bonus_roll", false)) else "PAID ROLL", 10, GREEN if bool(result.get("bonus_roll", false)) else MUTED)
			bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(bonus_label)
		card.tooltip_text = ("Aurora bonus roll · No extra stake\n" if bool(result.get("bonus_roll", false)) else "") + str(result.get("detail", ""))
		card.mouse_filter = Control.MOUSE_FILTER_PASS
	_polish_card_typography(row)

func _activity_info() -> Dictionary:
	if not is_instance_valid(_state):
		return {}
	var system: Object = _state.get("activity_system")
	return system.call("info") if system != null and system.has_method("info") else {}

func _build_activities() -> void:
	if _island_id() == 1:
		_build_duck_patrol()
		return
	var data: Dictionary = _activity_info()
	_heading(str(data.get("title", "Island activities")), str(data.get("description", "A different way to work your farm on each island.")))
	var hero: BoxContainer = _hbox(15)
	_body.add_child(hero)
	hero.add_child(_icon({"kind": "activity", "id": "contract" if _island_id() == 2 else "furnace"}, 64))
	var description: VBoxContainer = _vbox(5)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(description)
	var status: Label = _wrap("", 21, GREEN, true)
	description.add_child(status)
	_refs["activity_status"] = status
	var detail: Label = _wrap("", 14, MUTED)
	description.add_child(detail)
	_refs["activity_detail"] = detail
	match _island_id():
		2:
			var crop_row: BoxContainer = _hbox(12)
			_body.add_child(crop_row)
			crop_row.add_child(_label("Crop to supply", 14, INK, true))
			var crop_choice: OptionButton = OptionButton.new()
			crop_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			crop_choice.add_theme_font_size_override("font_size", 14)
			crop_choice.add_theme_color_override("font_color", INK)
			crop_choice.add_theme_color_override("font_hover_color", INK)
			crop_choice.add_theme_stylebox_override("normal", _style(PAPER, 8, 8, Color("b8c7a5")))
			crop_choice.add_theme_stylebox_override("hover", _style(Color("e4edcf"), 8, 8, GREEN))
			for crop: String in _market_crops():
				crop_choice.add_item(_crop_name(crop))
				crop_choice.set_item_metadata(crop_choice.item_count - 1, crop)
			crop_choice.item_selected.connect(func(index: int) -> void: _act("crop:" + str(crop_choice.get_item_metadata(index))))
			crop_row.add_child(crop_choice)
			_refs["contract_crop_choice"] = crop_choice
			var choices: BoxContainer = _hbox(12)
			_body.add_child(choices)
			_refs["contract_choices"] = choices
			for kind: String in ["bulk", "mutation"]:
				var card: PanelContainer = _card(Color("e4edcf") if kind == "bulk" else Color("ece0f2"), 14)
				card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				choices.add_child(card)
				var column: VBoxContainer = _vbox(6)
				card.add_child(column)
				var offer_icon: Control = _icon({"kind": "crop", "crop": "sunburst"}, 48)
				column.add_child(offer_icon)
				_refs["contract_icon:" + kind] = offer_icon
				column.add_child(_label("BULK BUYER" if kind == "bulk" else "MUTATION COLLECTOR", 15, INK, true))
				column.add_child(_label("+25% PAY" if kind == "bulk" else "+50% PAY", 25, GREEN if kind == "bulk" else Color("8155ac"), true))
				var detail_label: Label = _wrap("", 14, INK)
				column.add_child(detail_label)
				_refs["contract_offer:" + kind] = detail_label
				var choose: Button = _button("Take order →", "activity:contract:" + kind, true)
				column.add_child(choose)
				_refs["activity:contract:" + kind] = choose
			var progress: ProgressBar = ProgressBar.new()
			progress.custom_minimum_size.y = 14
			progress.show_percentage = false
			progress.add_theme_stylebox_override("fill", _style(GREEN, 0, 7))
			progress.add_theme_stylebox_override("background", _style(Color("dce2cf"), 0, 7))
			_body.add_child(progress)
			_refs["contract_progress"] = progress
			_offer("Ship your harvest", "Live price locks per shipment. Paid when the order is full.", "Deliver held", "activity:deliver", true)
			_refs["contract_delivery"] = _body.get_child(_body.get_child_count() - 1)
			_info("activity_hint", "Partial deliveries welcome · No deadline", MUTED)
		3:
			_offer("Thawing forge", "Pump the bellows to heat your hoe for 60 seconds. Then use Hoe [1] on frozen crops. No potato fuel needed.", "Heat thawing hoe", "climate_operate:heat_hoe", true)
			_offer("Feed the frost furnace", "20s burst · 2.5× growth · 3× processing", "Burn 25 Icecaps", "activity:furnace:icecap", true)
			_info("activity_hint", "Uses stored Icecaps · 60s between bursts", MUTED)
			_body.add_child(_button("Winter Roll House · 3 or 5 rolls together", "roll"))
	_refresh_activities()

func _build_duck_patrol() -> void:
	_heading("Duck patrol", "More ducks. Faster patrols. Fewer pests.")
	var hero_card := _surface("island", GREEN, true)
	_body.add_child(hero_card)
	var hero: BoxContainer = _hbox(15)
	hero_card.add_child(hero)
	hero.add_child(_icon({"kind": "activity", "id": "duck"}, 92))
	var description: VBoxContainer = _vbox(5)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(description)
	var status: Label = _wrap("", 21, GREEN, true)
	description.add_child(status)
	_refs["activity_status"] = status
	var detail: Label = _wrap("", 14, MUTED)
	description.add_child(detail)
	_refs["activity_detail"] = detail
	_section_title(_body, "Train your feathered crew")
	_offer("Flock size", "", "Hire a duck", "activity:duck", true)
	_offer("Patrol speed", "", "Train ducks", "activity:duck:speed", true)
	_info("duck_summary", "", MUTED, 12)
	_info("activity_hint", "This island's flock works while you visit.", MUTED)
	_refresh_duck_patrol()

func _refresh_duck_patrol() -> void:
	if not _refs.has("activity:duck"):
		return
	var data: Dictionary = _activity_info()
	var count: int = int(data.get("duck_count", 0))
	var capacity: int = int(data.get("duck_capacity", _island_id()))
	var speed: int = int(data.get("duck_speed", 0))
	var hire_cost: float = float(data.get("duck_cost", 1500))
	var speed_cost: float = float(data.get("duck_speed_cost", 15000))
	var coins: float = float(_state.coins)
	_set_button("activity:duck", "Flock full" if count >= capacity else "Hire +1 · " + _money(float(data.get("duck_cost", 1500))), not bool(data.get("duck_can_buy", false)))
	_refs["activity:duck:detail"].text = "%d / %d ducks · Each duck covers a different bed." % [count, capacity]
	_set_button("activity:duck:speed", "Top speed" if speed >= 2 else ("Hire a duck first" if count == 0 else "Faster · " + _money(float(data.get("duck_speed_cost", 15000)))), not bool(data.get("duck_can_train", false)))
	_refs["activity:duck:speed:detail"].text = "%.0fs → %.0fs per bed" % [float(data.get("duck_interval", 4)), maxf(2.0, float(data.get("duck_interval", 4)) - 1.0)] if speed < 2 else "2s per bed · Maximum speed"
	if _refs.has("activity:duck:value"):
		_refs["activity:duck:value"].text = "%d → %d ducks" % [count, count + 1] if count < capacity else "%d / %d ducks" % [count, capacity]
		_refs["activity:duck:speed:value"].text = _refs["activity:duck:speed:detail"].text
		_refs["activity:duck:speed:detail"].text = "Less time between beds for your whole flock."
		Cozy.badge(_refs["activity:duck:status"], "Complete" if count >= capacity else ("Affordable" if coins >= hire_cost else "Need " + _money(hire_cost - coins) + " more"), "active" if count >= capacity or coins >= hire_cost else "warning")
		Cozy.badge(_refs["activity:duck:speed:status"], "Complete" if speed >= 2 else ("Locked · Hire a duck" if count == 0 else ("Affordable" if coins >= speed_cost else "Need " + _money(speed_cost - coins) + " more")), "locked" if count == 0 else ("active" if speed >= 2 or coins >= speed_cost else "warning"))
	_refs.duck_summary.text = "Island limits: 1 / 2 / 3 ducks · %d pests cleared" % int(data.get("duck_clears", 0))
	_refs.activity_status.text = "%d / %d DUCKS ON PATROL" % [count, capacity]
	_refs.activity_detail.text = "%.0fs between beds" % float(data.get("duck_interval", 4)) if count > 0 else "Build your feathered crew."

func _refresh_activities() -> void:
	if _island_id() == 1:
		_refresh_duck_patrol()
		return
	if not _refs.has("activity_status"):
		return
	var data: Dictionary = _activity_info()
	match _island_id():
		2:
			var contract: Dictionary = data.get("contract", {})
			var cooldown: float = float(data.get("contract_cooldown", 0))
			var active: bool = not contract.is_empty()
			var crop_choice: OptionButton = _refs.contract_crop_choice
			crop_choice.disabled = active
			_refs.contract_choices.visible = not active
			_refs.contract_delivery.visible = active
			_refs.contract_progress.visible = active
			_refs.contract_progress.value = 100.0 * float(contract.get("delivered", 0)) / maxf(1.0, float(contract.get("target", 1)))
			for kind: String in ["bulk", "mutation"]:
				var offer: Dictionary = data.get(kind + "_offer", {})
				var crop: String = str(offer.get("crop", "sunburst"))
				_refs["contract_icon:" + kind].item = {"kind": "crop", "crop": crop} if kind == "bulk" else {"kind": "mutation", "id": "mutation:" + crop + ":crystal", "crop": crop}
				_refs["contract_icon:" + kind].queue_redraw()
				var unit: String = ("mutation" if int(offer.get("target", 1)) == 1 else "mutations") if kind == "mutation" else "potatoes"
				_refs["contract_offer:" + kind].text = "%s %s · Held %s\n%s" % [_number(float(offer.get("target", 0))), unit, _number(float(offer.get("held", 0))), "Pays the full rarity value + bonus" if kind == "mutation" else "At this price: " + _money(float(offer.get("base_quote", 0)))]
			for index: int in range(crop_choice.item_count):
				if str(crop_choice.get_item_metadata(index)) == str(contract.get("crop", data.get("contract_crop", "sunburst"))):
					crop_choice.select(index)
			_refs.activity_status.text = (str(contract.get("crop_name", "Harvest")).to_upper() + (" MUTATIONS" if str(contract.get("kind", "bulk")) == "mutation" else " BULK ORDER")) if active else ("NEXT BUYER IN %ds" % ceili(cooldown) if cooldown > 0 else "PICK YOUR BUYER")
			_refs.activity_detail.text = "%s / %s shipped · %s banked" % [_number(float(contract.get("delivered", 0))), _number(float(contract.get("target", 1))), _money(float(contract.get("credit", 0)))] if active else "%d orders completed · Choose your crop below" % int(data.get("contract_completed", 0))
			_set_button("activity:contract:bulk", "Take bulk order →", active or cooldown > 0)
			_set_button("activity:contract:mutation", "Take rare order →", active or cooldown > 0)
			var amount: int = int(contract.get("ship_amount", 0))
			_set_button("activity:deliver", "Ship %s →" % _number(amount) if amount > 0 else "Harvest more first", not bool(contract.get("can_deliver", false)))
		3:
			var remaining: float = float(data.get("furnace_remaining", 0))
			var cooldown: float = float(data.get("furnace_cooldown", 0))
			_refs.activity_status.text = "HEAT BURST · %.1fs" % remaining if remaining > 0 else ("COOLING · %ds" % ceili(cooldown) if cooldown > 0 else "READY TO FIRE")
			_refs["climate_operate:heat_hoe:detail"].text = "Hoe heat: %ds · Hoe [1] melts frozen crops. Reheat with the bellows for free." % ceili(float(data.get("thaw_heat", 0)))
			_refs.activity_detail.text = "%s Icecaps in storage\n2.5× crop growth · 3× processing · 20 seconds" % _number(float(data.get("furnace_held", 0)))
			_set_button("activity:furnace:icecap", "Burning…" if remaining > 0 else ("Cooling…" if cooldown > 0 else "Burn 25 Icecaps"), not bool(data.get("can_charge", false)))

func _build_equipment_header(parent: VBoxContainer) -> void:
	var card: PanelContainer = _surface("build", GREEN, true)
	parent.add_child(card)
	var layout: BoxContainer = _hbox(14)
	card.add_child(layout)
	var portrait_column: VBoxContainer = _vbox(4)
	portrait_column.custom_minimum_size.x = 228
	layout.add_child(portrait_column)
	var preview: Control = EquipmentPreview.new()
	preview.custom_minimum_size = Vector2(228, 310)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_column.add_child(preview)
	_refs["equipment_preview"] = preview
	var hint: Label = _label("DRAG TO TURN YOUR FARMER", 10, MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_column.add_child(hint)
	var matching := _wrap("", 13, GREEN, true)
	matching.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_column.add_child(matching)
	_refs.equipment_matching = matching
	var right: VBoxContainer = _vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(right)
	var build_title: Label = _wrap("YOUR LOADOUT", 17, INK, true)
	right.add_child(build_title)
	_refs["equipment_build"] = build_title
	right.add_child(_wrap("Click an occupied slot to remove it.", 12, MUTED))
	var slots: GridContainer = GridContainer.new()
	slots.columns = 2
	slots.add_theme_constant_override("h_separation", 7)
	slots.add_theme_constant_override("v_separation", 7)
	right.add_child(slots)
	for slot: String in ["head", "body", "legs", "feet", "hands", "charm"]:
		var button: Button = _button("", "gear:unequip:" + slot)
		button.custom_minimum_size = Vector2(150, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(button)
		var contents: BoxContainer = _hbox(5)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 7
		contents.offset_right = -7
		contents.offset_top = 7
		contents.offset_bottom = -7
		var icon: Control = _icon({"kind": "slot", "id": slot}, 40)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		contents.add_child(icon)
		var labels: VBoxContainer = _vbox(3)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		contents.add_child(labels)
		labels.add_child(_label(slot.to_upper(), 10, MUTED, true))
		var name_label: Label = _wrap("Empty", 11, INK, true)
		labels.add_child(name_label)
		var slot_status := _label("Find gear below", 10, MUTED)
		labels.add_child(slot_status)
		_refs["equipment:" + slot + ":status"] = slot_status
		_refs["equipment:" + slot] = button
		_refs["equipment:" + slot + ":icon"] = icon
		_refs["equipment:" + slot + ":name"] = name_label
	var totals: Label = _wrap("", 13, GREEN, true)
	right.add_child(totals)
	_refs["equipment_totals"] = totals
	var build_bonus := _wrap("", 13, INK)
	parent.add_child(build_bonus)
	_refs.equipment_build_bonus = build_bonus
	parent.add_child(_wrap("Matching pieces gain +25% to their gear bonuses. Extra copies do not stack.", 12, MUTED))
	_section_title(parent, "Owned Gear", "Choose a piece to equip")

func _refresh_equipment() -> void:
	if not _refs.has("equipment_preview") or not _state.has_method("equipment_info"):
		return
	var catalog: Dictionary = _state.get_script().get_script_constant_map().get("ITEM_CATALOG", {})
	var loadout: Dictionary = _state.call("equipment_loadout")
	_refs.equipment_preview.set_equipment(loadout, catalog)
	var builds: Object = _build_system()
	var active_build: String = str(builds.get("active")) if builds != null else "farmer"
	_refs.equipment_build.text = "YOUR LOADOUT · " + active_build.to_upper()
	var matching: int = 0
	var worn: int = 0
	for slot: String in loadout:
		var gear_id: String = str(loadout[slot])
		if gear_id.is_empty(): continue
		worn += 1
		if str(catalog.get(gear_id, {}).get("role", "")) == active_build: matching += 1
	_refs.equipment_matching.text = "%d / 6 slots filled · %d matching" % [worn, matching]
	for build: Dictionary in _build_entries():
		if bool(build.get("active", false)):
			_refs.equipment_build_bonus.text = "%s Lv.%d · %s" % [build.get("name", "Farmer"), int(build.get("level", 1)), str(build.get("bonuses", ""))]
	var total_parts: Array[String] = []
	for stat: String in ["yield", "growth", "stock", "luck", "mutation", "processing"]:
		var value: float = float(_state.call("equipment_bonus", stat))
		if value <= 0.000001:
			continue
		var names: Dictionary = {"yield": "Yield", "growth": "Growth", "stock": "Stocks", "luck": "Luck", "mutation": "Mutations", "processing": "Processing"}
		var number: String = ("%.2f" % (value if stat == "luck" else value * 100.0)).trim_suffix("0").trim_suffix("0").trim_suffix(".")
		total_parts.append("%s +%s%s" % [names[stat], number, "×" if stat == "luck" else "%"])
	if _wears_crown():
		total_parts.append("Bonus roll +1 / purchase")
	_refs.equipment_totals.text = "Gear total · " + " · ".join(total_parts) if not total_parts.is_empty() else "Equip gear below to activate its bonuses."
	var entries: Array = _state.call("equipment_info")
	for entry: Dictionary in entries:
		var slot: String = str(entry.get("slot", ""))
		var key: String = "equipment:" + slot
		if not _refs.has(key):
			continue
		var id: String = str(entry.get("id", ""))
		var empty: bool = bool(entry.get("empty", id.is_empty()))
		var button: Button = _refs[key]
		button.disabled = empty
		button.tooltip_text = "Empty %s slot. Equip something from your owned gear below." % slot if empty else str(entry.get("name", "Gear")) + "\n" + str(entry.get("effect", "")) + "\nClick to remove."
		_refs[key + ":name"].text = "Empty" if empty else str(entry.get("name", "Gear"))
		_refs[key + ":status"].text = "Find gear below" if empty else ("Build match +25%" if float(entry.get("synergy", 1.0)) > 1.0 else "Equipped · Remove")
		var icon: Control = _refs[key + ":icon"]
		icon.item = {"kind": "slot", "id": slot} if empty else {"kind": "gear", "id": id, "slot": slot, "role": entry.get("role", "")}
		icon.queue_redraw()
		button.add_theme_stylebox_override("normal", _style(Color("d5e7cb") if not empty else PAPER, 8, 10, Color("91b184") if not empty else Color.TRANSPARENT))
		button.add_theme_stylebox_override("disabled", _style(Color("f2f2e7"), 8, 10, Color("c6ccba")))

func _debug_info() -> Dictionary:
	return _state.call("debug_info") if is_instance_valid(_state) and _state.has_method("debug_info") else {"luck_multiplier": 1.0, "normal_luck": _effective_luck(), "effective_luck": _effective_luck(), "money_limit": 1e6, "luck_limit": 1000.0}

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

func _build_debug() -> void:
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
	_heading("Debug workshop", "Changes save to this farm. Future trophies stay marked DEBUG.")
	var data: Dictionary = _debug_info()
	_info("debug_balance", "", INK, 20)
	var funding := _card(PAPER, 14)
	_body.add_child(funding)
	var funds := _vbox(8)
	funding.add_child(funds)
	funds.add_child(_label("TEST FUNDS · EXACT BALANCE", 15, INK, true))
	var amount := DebugMoneyInput.new()
	amount.max_value = 1e300
	amount.value = float(_state.call("blind_info").base_tax) * 3.0 if _flag("run_over") else maxf(0, float(_state.get("coins")))
	amount.placeholder_text = "15000000000 or 15e9"
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
	for item: Array in [["Valley · $150K", "150000"], ["Shores · $15B", "15e9"], ["Winter · $750T", "750e12"]]:
		var preset := _button(item[0], "debug_balance_preset:" + item[1])
		preset.tooltip_text = "Fill the input with three base tax bills. Nothing changes until you apply."
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
	funds.add_child(_wrap("Sets money directly, including from debt or $0. Recovery keeps your farm and restarts the tax countdown at normal speed.", 13, MUTED))

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
	time_column.add_child(_wrap("Debug pauses game time while open. Outside this panel, 30× also speeds up taxes and weather.", 13, MUTED))

	var access := _card(PAPER, 14)
	_body.add_child(access)
	var access_body := _vbox(9)
	access.add_child(access_body)
	access_body.add_child(_label("ISLANDS & WEATHER", 15, INK, true))
	var islands := HFlowContainer.new()
	islands.add_theme_constant_override("h_separation", 8)
	islands.add_theme_constant_override("v_separation", 8)
	access_body.add_child(islands)
	for island: int in [2, 3]:
		var unlock := _button("", "debug:island:%d" % island)
		islands.add_child(unlock)
		_refs["debug_island_%d" % island] = unlock
	_refs.debug_island_note = _wrap("Unlocking gives access, not money. Visiting Shores raises base tax to $5B; Winter to $250T. That tier stays when you return. Set test funds before travelling.", 13, MUTED)
	access_body.add_child(_refs.debug_island_note)
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

	var advanced: VBoxContainer = _details_section("debug_advanced", "money multiplier & luck")
	_refs.debug_luck_status = _wrap("", 15, GREEN)
	advanced.add_child(_refs.debug_luck_status)
	for field: String in ["money", "luck"]:
		var card: PanelContainer = _card(PAPER, 14)
		advanced.add_child(card)
		var column: VBoxContainer = _vbox(8)
		card.add_child(column)
		column.add_child(_label("MONEY · MULTIPLY ONCE" if field == "money" else "LUCK · STAYS UNTIL RESET", 15, INK, true))
		var number: Control
		var input: LineEdit
		if field == "money":
			var money_input: DebugMoneyInput = DebugMoneyInput.new()
			money_input.max_value = float(data.get("money_limit", 1e6))
			money_input.value = 1.0
			money_input.placeholder_text = "0.1 or 1e-20"
			money_input.tooltip_text = "Multiply current money once. Set balance above can fund a zero or negative purse."
			money_input.text_changed.connect(func(_text: String) -> void: _refresh_debug())
			number = money_input
			input = money_input
		else:
			var luck_input: SpinBox = SpinBox.new()
			luck_input.min_value = 1.0
			luck_input.max_value = float(data.get("luck_limit", 1000.0))
			luck_input.step = 0.25
			luck_input.value = float(data.get("luck_multiplier", 1.0))
			luck_input.suffix = "×"
			luck_input.value_changed.connect(func(_value: float) -> void: _refresh_debug())
			number = luck_input
			input = luck_input.get_line_edit()
		number.custom_minimum_size = Vector2(0, 40)
		column.add_child(number)
		input.add_theme_color_override("font_color", INK)
		input.add_theme_font_size_override("font_size", 16)
		input.add_theme_stylebox_override("normal", _style(CREAM, 10, 8, Color("c6d3bd")))
		input.add_theme_stylebox_override("focus", _style(CREAM, 10, 8, GREEN))
		_refs["debug_" + field] = number
		var choices := HFlowContainer.new()
		choices.add_theme_constant_override("h_separation", 6)
		choices.add_theme_constant_override("v_separation", 6)
		column.add_child(choices)
		var multipliers: Array = ["0.01", "0.1", "1", "10", "100", "1000"] if field == "money" else ["1", "10", "100", "1000"]
		for value: String in multipliers:
			var preset: Button = _button("×" + value, "debug_%s:%s" % [field, value])
			preset.add_theme_stylebox_override("normal", _style(CREAM, 10, 8, Color("c6d3bd")))
			choices.add_child(preset)
	advanced.add_child(_button("Luck calculation", "toggle_details:debug_luck_math"))
	_refs.debug_luck_math = _wrap("", 13, GREEN)
	advanced.add_child(_refs.debug_luck_math)
	_refs.debug_luck_math.hide()
	_refs.debug_preview = _wrap("", 14, GREEN)
	advanced.add_child(_refs.debug_preview)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 9)
	actions.add_theme_constant_override("v_separation", 9)
	advanced.add_child(actions)
	_refs.debug_apply = _button("Apply money once + set luck", "debug_apply", true)
	actions.add_child(_refs.debug_apply)
	_refs.debug_reset = _button("Reset luck + time", "debug:reset")
	actions.add_child(_refs.debug_reset)
	advanced.add_child(_wrap("0.1 keeps 10% · 0 empties your purse. Multiplying debt increases debt. Reset keeps coins and all Debug history.", 13, MUTED))
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
	if not _refs.has("debug_luck") or not _refs.has("debug_preview"):
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
			_refs.debug_balance_preview.text = "Enter a balance from 0 to 1e300, such as 15e9."
		else:
			_refs.debug_balance_preview.text = "%s to %s%s" % [_blind_money(coins), _blind_money(float(balance.value)), " · resume with progress kept" if ended else " · exact new balance"]
			if ended and float(balance.value) <= 0: _refs.debug_balance_preview.text = "Enter positive test funds to recover this farm."
		_refs.debug_balance_preview.add_theme_color_override("font_color", CHERRY if not valid or (ended and float(balance.get("value", 0)) <= 0) else GREEN)
	_refs.debug_balance.text = "CURRENT MONEY  " + _blind_money(coins)
	_refs.debug_balance.tooltip_text = _precise_money(coins)
	_refs.debug_luck_status.text = "Normal %.2f× (+%s%%) · Debug ×%.2f · Total %.2f×" % [float(data.normal_luck), _number((float(data.normal_luck) - 1.0) * 100.0), float(data.luck_multiplier), float(data.effective_luck)]
	_refs.debug_luck_math.text = _luck_math()
	var parsed: Dictionary = _debug_money_value()
	_refs.debug_apply.disabled = parsed.has("error") or ended
	if parsed.has("error"):
		_refs.debug_preview.text = str(parsed.error)
		_refs.debug_preview.add_theme_color_override("font_color", CHERRY)
	else:
		var multiplier: float = float(parsed.value)
		var after: float = minf(1e300, coins * multiplier)
		_refs.debug_preview.text = "APPLY ONCE  %s × %s → %s\nLuck %.2f× × %.2f = %.2f× (+%s%%)" % [_precise_money(coins), String.num_scientific(multiplier), _precise_money(after), float(data.normal_luck), float(_refs.debug_luck.value), float(data.normal_luck) * float(_refs.debug_luck.value), _number((float(data.normal_luck) * float(_refs.debug_luck.value) - 1.0) * 100.0)]
		_refs.debug_preview.add_theme_color_override("font_color", CHERRY if after < float(_state.call("bankruptcy_limit")) else GREEN)
		if after < float(_state.call("bankruptcy_limit")): _refs.debug_preview.text += "\nThis crosses bankruptcy. Use exact test funds above to clear debt."
	_refs.debug_reset.disabled = is_equal_approx(float(data.get("luck_multiplier", 1)), 1.0) and is_equal_approx(_debug_time_multiplier, 1.0)
	for island: int in [2, 3]:
		var unlocked: bool = _flag("island2_unlocked" if island == 2 else "island3_unlocked")
		var label: String = "Golden Shores" if island == 2 else "Frosthollow + Shores"
		_refs["debug_island_%d" % island].text = label + (" · Unlocked" if unlocked else " · Unlock")
		_refs["debug_island_%d" % island].disabled = unlocked or ended
	_refs.debug_time_status.text = "GAME TIME · %d×" % int(_debug_time_multiplier)
	for speed: int in [1, 2, 5, 10, 30]:
		_refs["debug_time_%d" % speed].disabled = ended or is_equal_approx(_debug_time_multiplier, float(speed))
	var climate: Dictionary = _state.call("climate_info")
	var can_weather: bool = not ended and _island_id() >= 2 and climate.phase == "calm" and not climate.intro_pending and not _state.ClimateSystem.Lesson.active(_state)
	for weather: String in ["drought", "flood", "storm", "freeze"]:
		_refs["debug_weather_" + weather].disabled = not can_weather or (weather == "freeze" and _island_id() != 3)
	_refs.debug_weather_note.text = "Starts a full 45-second warning; crops and stores can be lost." if can_weather else ("Recover this test farm first." if ended else ("Travel to Shores or Winter first." if _island_id() < 2 else "Finish the current weather or lesson before starting a test."))

func _precise_money(amount: float) -> String:
	return "$" + String.num_scientific(amount)

func _show_roll_accounting() -> void:
	if _crate_reel or not _refs.has("roll_accounting") or not _state.has_method("roll_accounting_info"):
		return
	var receipt: Dictionary = _state.call("roll_accounting_info")
	if receipt.is_empty():
		return
	var details: Array[String] = []
	for entry: Array in [["refunds", "10% stake refunds"], ["duplicate_returns", "duplicate trade-ins"], ["jackpot_returns", "jackpots"]]:
		if float(receipt.get(entry[0], 0)) > 0.0:
			details.append("%s from %s" % [_money(float(receipt[entry[0]])), str(entry[1])])
	_refs.roll_accounting.text = "Spent %s · Returned %s · Balance %s" % [_money(float(receipt.get("paid_total", 0))), _money(float(receipt.get("cash_returned", 0))), _money(float(receipt.get("balance_after", 0)))]
	if not details.is_empty():
		_refs.roll_accounting.text += "\nReturned: " + "; ".join(details) + "."
	_refs.roll_accounting.tooltip_text = "Before: %s\nPaid upfront: %s\nCash returned: %s\nNet change: %s\nBalance after this roll: %s" % [_precise_money(float(receipt.get("balance_before", 0))), _precise_money(float(receipt.get("paid_total", 0))), _precise_money(float(receipt.get("cash_returned", 0))), _precise_money(float(receipt.get("net_change", 0))), _precise_money(float(receipt.get("balance_after", 0)))]
	_refs.roll_accounting.show()

func _refresh_trophies() -> void:
	if not _refs.has("trophy_gallery") or _rolling:
		return
	var trophies: Array = _state.call("trophy_info") if _state.has_method("trophy_info") else []
	_refs.trophy_toggle.text = "%s trophy cabinet · %d rare discoveries" % ["Hide" if _trophies_open else "Show", trophies.size()]
	_refs.trophy_gallery.visible = _trophies_open
	var signature: String = JSON.stringify(trophies)
	if signature == _trophy_signature:
		return
	_trophy_signature = signature
	var gallery: VBoxContainer = _refs.trophy_gallery
	for child: Node in gallery.get_children():
		gallery.remove_child(child)
		child.queue_free()
	gallery.add_child(_wrap("Your rarest drops. Odds show that roll's rarity tier, not the specific item.", 12, MUTED))
	if trophies.is_empty():
		var empty := _surface("quest", GOLD)
		gallery.add_child(empty)
		empty.add_child(_wrap("A shelf for future treasures. Rare and better finds will appear here as you roll.", 14, MUTED))
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	gallery.add_child(grid)
	for trophy: Dictionary in trophies:
		var tier: String = str(trophy.get("tier", "rare"))
		var accent: Color = RollReel.COLORS.get(tier, Color("c1a4df"))
		var card: PanelContainer = _surface("gear", Cozy.RARITY_COLORS.get(tier, GREEN))
		card.set_meta("trophy", trophy.duplicate(true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var row: BoxContainer = _hbox(8)
		card.add_child(row)
		var item_id: String = str(trophy.get("item_id", ""))
		var title: String = str(trophy.get("title", "Rare drop"))
		var kind: String = "gear" if not item_id.is_empty() else ("build_crate" if "build crate" in title.to_lower() else "relic")
		row.add_child(_icon({"kind": kind, "id": item_id if not item_id.is_empty() else "trader_token"}, 50))
		var labels: VBoxContainer = _vbox(3)
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(labels)
		labels.add_child(_wrap(title, 15, INK, true))
		labels.add_child(_wrap("%s · ×%d%s" % [tier.to_upper(), int(trophy.get("count", 1)), " · DEBUG" if bool(trophy.get("debug", false)) else ""], 11, Cozy.RARITY_COLORS.get(tier, GREEN), true))
		labels.add_child(_wrap("Tier odds %.4f%%\nIsland %d · roll #%d" % [float(trophy.get("best_probability", 0)), int(trophy.get("island", 1)), int(trophy.get("roll_number", 0))], 12, MUTED))
		card.tooltip_text = "Recorded rarity-tier odds, including the luck and stake used on that roll."
		card.mouse_filter = Control.MOUSE_FILTER_PASS

func _wears_crown() -> bool:
	if not is_instance_valid(_state) or not _state.has_method("equipment_loadout"):
		return false
	var equipment: Dictionary = _state.call("equipment_loadout")
	return str(equipment.get("head", "")) == "aurora_crown"

func _batch_bonus_count() -> int:
	var count: int = 0
	for result: Dictionary in _batch_results:
		if bool(result.get("bonus_roll", false)):
			count += 1
	return count

func _minimum_roll_stake(kind: String) -> float:
	return float(_state.call("roll_minimum_stake", kind)) if _state.has_method("roll_minimum_stake") else float(_state.call("roll_cost", "normal"))

func _can_roll_stake(kind: String) -> bool:
	if _state.has_method("can_roll"):
		return bool(_state.call("can_roll", kind))
	var cost: float = float(_state.call("roll_cost", kind))
	var coins: float = float(_state.get("coins"))
	if not bool(_state.call("roll_available")) or not is_finite(cost) or coins < cost:
		return false
	return cost > _minimum_roll_stake(kind) if kind == "all_in" else cost >= _minimum_roll_stake(kind)

func show_tutorial_feedback(message: String) -> void:
	if not _tutorial.is_empty():
		_tutorial_body.text = message

func _build_farm_help() -> void:
	_farm_help_card = _card(CREAM, 4)
	_farm_help_card.name = "FarmHelp"
	_place(_farm_help_card, Rect2(28, 290, 302, 0))
	var row := _hbox(4)
	_farm_help_card.add_child(row)
	_farm_help_action = _button("", "farm_help:details")
	_farm_help_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_farm_help_action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(_farm_help_action)
	var dismiss_button := _button("×", "farm_help:dismiss")
	dismiss_button.tooltip_text = "Dismiss this tip"
	row.add_child(dismiss_button)
	for button: Button in [_farm_help_action, dismiss_button]:
		button.custom_minimum_size.y = 30
		button.add_theme_font_override("font", _plain_font)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _style(CREAM, 6, 6))
		button.add_theme_stylebox_override("hover", _style(PAPER, 6, 6))
	_farm_help_card.hide()

func _update_farm_help() -> void:
	if not is_instance_valid(_farm_help_card) or not is_instance_valid(_state): return
	var tip: Dictionary = _state.farm_help.tip(_state)
	if not tip.is_empty() and _help_cooldown > 0.0 and tip.id not in ["pests", "taxes", "debt"]:
		tip = {}
	_farm_tip = tip
	_farm_help_card.visible = not tip.is_empty() and _tutorial.is_empty() and not is_panel_open() and not _rolling and not _state.run_over and not _crop_row.visible and not _toast_box.visible and _farm_busy_remaining <= 0.0 and _plot_action_text.is_empty() and _climate_console.equipment.is_empty() and not _state.ClimateSystem.Lesson.active(_state)
	if tip.is_empty(): return
	var summaries: Dictionary = {"repeat": "Grow another crop · Help", "pests": "Pests · Press 5 to spray", "stocks": "Try a practice boom", "taxes": "Tax after 3 stocks · Help", "debt": "In debt · Recovery tips", "tools": "Upgrade your tools", "ducks": "Ducks can clear pests", "builds": "Explore your builds"}
	_farm_help_action.text = str(tip.title) if tip.id == "stocks" and float(_state.farm_help.data.practice_remaining) > 0.0 else str(summaries[tip.id])
	_farm_help_action.text += "  ›"
	_farm_help_card.position = Vector2(28, root.size.y - 230)
	_farm_help_card.size = Vector2(302, 0)

func _build_plot_action() -> void:
	_plot_action_box = _card(Color("193c33"), 10)
	_plot_action_box.name = "CropActionPrompt"
	root.add_child(_plot_action_box)
	_plot_action_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_plot_action_box.offset_left = -270
	_plot_action_box.offset_right = 270
	_plot_action_box.offset_top = -205
	_plot_action_box.offset_bottom = -145
	var row := _hbox(12)
	_plot_action_box.add_child(row)
	row.add_child(_icon({"kind": "build", "id": "farmer"}, 38))
	_plot_action_label = _wrap("", 14, CREAM)
	_plot_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_plot_action_label)
	row.add_child(_button("Cancel · Esc", "profession:cancel"))
	_plot_action_box.hide()

func set_plot_action(text: String) -> void:
	_plot_action_text = text
	_plot_action_label.text = text
	if not text.is_empty(): _climate_console.hide()
	_refresh_seed_visibility()
	_update_context()
	_update_farm_help()

func _build_farm_tip() -> void:
	if _opened_farm_tip.is_empty(): return
	_heading(str(_opened_farm_tip.title), "Optional farm help")
	_info("farm_tip_body", str(_opened_farm_tip.body), INK, 16)
	_body.add_child(_button(str(_opened_farm_tip.label), "farm_help:act", true))
	_body.add_child(_button("Dismiss this tip", "farm_help:dismiss"))

func _luck_math() -> String:
	if not is_instance_valid(_state): return ""
	var info: Dictionary = _state.luck_breakdown()
	return "1 base + %s earned + %s equipped = %s× (+%s%%)%s\n%s× normal × %s debug = %s× total (+%s%%)" % [String.num(info.earned, 3), String.num(info.gear, 3), String.num(info.normal, 3), _number(info.normal_percent), " · capped at 10×" if float(info.uncapped) > 10.0 else "", String.num(info.normal, 3), String.num(info.multiplier, 3), String.num(info.total, 3), _number(info.total_percent)]
