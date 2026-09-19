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
const MarketImpact = preload("res://scripts/market_impact.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const EquipmentPreview = preload("res://scripts/equipment_preview.gd")
const UI_FONT = preload("res://assets/fonts/NunitoSans.ttf")
const UI_SYMBOLS = preload("res://assets/fonts/NotoSansSymbols.ttf")
const UI_SYMBOLS_2 = preload("res://assets/fonts/NotoSansSymbols2.ttf")
const RewardFeedback = preload("res://scripts/reward_feedback.gd")
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
const GROW_TIMES: Dictionary = {"russet": 10, "golden": 30, "giant": 45, "radioactive": 90, "sunburst": 45}
const TOOL_COSTS: Dictionary = {"hoe": [300, 12000], "water": [450, 15000], "harvest": [600, 20000]}
const TOOL_AREAS: Dictionary = {"hoe": ["1 tile", "3 tiles", "3 × 3 tiles", "5 × 5 tiles"], "water": ["1 tile", "3 × 3 tiles", "5 × 5 tiles", "7 × 7 tiles"], "harvest": ["1 tile", "one full row", "three full rows", "five full rows"]}
const PURCHASE_SECONDS: float = 3.2

var root: Control
var _state: Node
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
var _reward_box: PanelContainer
var _reward_title: Label
var _reward_detail: Label
var _reward_rarity: Label
var _reward_timer: Timer
var _modal: Control
var _modal_title: Label
var _modal_subtitle: Label
var _body: VBoxContainer
var _panel_kind: String = ""
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
var _quick_sell: Button
var _modal_card: PanelContainer
var _spinner: Control
var _rolling: bool = false
var _frozen_coins: float = 0.0
var _revealed_roll: Dictionary = {}
var _crop_row: HBoxContainer
var _crop_defs: Dictionary = {}
var _stake_kind: String = "normal"
var _frozen_odds: Array = []
var _frozen_luck: float = 1.0
var _frozen_stake_bonus: float = 0.0
var _inventory_sections: Dictionary = {}
var _inventory_tab: String = "crops"
var _inventory_signature: String = ""
var _market_impact: Control
var _builds_button: Button
var _tracked_row: HBoxContainer
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

func _process(delta: float) -> void:
	_hud_clock += delta
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
	var showing: bool = _selected_tool == "plant" and not is_panel_open() and (_tutorial.is_empty() or "plant" in _tutorial.get("tools", []))
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
		_context_box.offset_top = -300 if showing else -184
		_context_box.offset_bottom = -258 if showing else -142


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
	title_font.base_font = UI_FONT
	title_font.fallbacks = [UI_SYMBOLS, UI_SYMBOLS_2]
	title_font.variation_opentype = {weight_axis: 700.0}
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
	_build_top()
	_build_sidebar()
	_build_footer()
	_build_notices()
	_build_export_strip()
	_build_modal()
	_build_tutorial()

func _build_tutorial() -> void:
	_tutorial_card = _card(Color("17382d"), 15)
	_tutorial_card.name = "FirstIslandGuide"
	_tutorial_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(_tutorial_card, Rect2(28, 108, 219, 0))
	_tutorial_card.z_index = 30
	var contents: VBoxContainer = _vbox(10)
	_tutorial_card.add_child(contents)
	var top_row: HBoxContainer = _hbox(2)
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
		_tutorial_progress.text = "FIRST FARM  ·  %d / %d" % [int(info.get("step", 1)), int(info.get("total", 1))]
		_tutorial_title.text = str(info.get("title", "Your first farm"))
		_tutorial_body.text = str(info.get("body", ""))
		_tutorial_next.text = str(info.get("continue_label", "Next stop →")) if bool(info.get("continue", false)) else "Follow gold arrow ↓"
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

func _apply_tutorial_buttons() -> void:
	if _tutorial.is_empty():
		return
	for node: Node in root.find_children("*", "Button", true, false):
		if not node.has_meta("hud_action"):
			continue
		if not _tutorial_allows(str(node.get_meta("hud_action"))):
			if not node.has_meta("tutorial_disabled"):
				node.set_meta("tutorial_disabled", node.disabled)
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
	# Logical game size is preserved by the viewport. Measure the modal's
	# clear margin too, keeping this guide outside every shop's controls.
	var available_width: float = _modal_card.position.x - 44.0 if is_panel_open() else 219.0
	var card_width: float = minf(219.0, maxf(180.0, available_width))
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
	else:
		var tool: String = str(_tutorial.get("tool", ""))
		if _tool_buttons.has(tool):
			target = _tool_buttons[tool]
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

func _hbox(gap: int = 10) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box

func _card(color: Color = CREAM, padding: int = 16) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, padding, 17))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel

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
	button.add_theme_color_override("font_disabled_color", Color("92998a"))
	button.add_theme_stylebox_override("normal", _style(INK if primary else PAPER, 10, 10))
	button.add_theme_stylebox_override("hover", _style(GREEN if primary else Color("e3e8d6"), 10, 10))
	button.add_theme_stylebox_override("pressed", _style(GREEN if primary else Color("d5ddc5"), 10, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("e7e8dd"), 10, 10))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, 10, GOLD))
	button.pressed.connect(func() -> void: _act(action))
	return button

func _act(action: String) -> void:
	if not _tutorial_allows(action):
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
		return
	if action == "debug_unlock":
		if _refs.has("debug_code"):
			var code: String = _refs.debug_code.text
			_refs.debug_code.clear()
			action_requested.emit("debug:unlock:" + code)
		return
	if (action.begins_with("debug:") or action.begins_with("debug_")) and not _debug_unlocked:
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
	_place(brand, Rect2(28, 20, 350, 70))
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wordmark: HBoxContainer = _hbox(8)
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(wordmark)
	wordmark.add_child(_label("TATER", 32, INK, true))
	wordmark.add_child(_label("/", 32, GOLD, true))
	wordmark.add_child(_label("LAND", 32, INK, true))

	var stats: PanelContainer = _card(CREAM, 12)
	_stats_card = stats
	_place(stats, Rect2(387, 21, 524, 72))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = _hbox(20)
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
	_top["luck"] = _stat(row, "LUCK", "1.0×", GREEN)
	var stats_font: FontVariation = _compact_heading_font()
	for label: Node in stats.find_children("*", "Label", true, false):
		label.add_theme_font_override("font", stats_font)
	stats.size.x = 763
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
	var tracked_contents: HBoxContainer = _hbox(10)
	tracked.add_child(tracked_contents)
	var chooser: Button = _button("Track seeds ▾", "tracked_prices")
	chooser.custom_minimum_size = Vector2(134, 38)
	chooser.add_theme_font_size_override("font_size", 12)
	tracked_contents.add_child(chooser)
	_tracked_row = _hbox(8)
	_tracked_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracked_contents.add_child(_tracked_row)

func _stat(parent: HBoxContainer, title: String, value: String, color: Color) -> Label:
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
	var slots: HBoxContainer = _hbox(6)
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
	_context_box = _card(Color(0.09, 0.20, 0.16, 0.93), 10)
	root.add_child(_context_box)
	_context_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_context_box.offset_left = -328
	_context_box.offset_right = 328
	_context_box.offset_top = -244
	_context_box.offset_bottom = -202
	_context_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context = _wrap("Walk to a garden bed. Till, plant, water, and harvest.", 14, CREAM)
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
	_toast_box = _card(INK, 14)
	_place(_toast_box, Rect2(374, 170, 566, 52))
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _wrap("", 15, CREAM)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var header: HBoxContainer = _hbox(10)
	column.add_child(header)
	var titles: VBoxContainer = _vbox(3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_modal_title = _wrap("Welcome to Taterland", 28, INK, true)
	_modal_subtitle = _wrap("Good soil. Wild markets.", 14, MUTED)
	titles.add_child(_modal_title)
	titles.add_child(_modal_subtitle)
	var close: Button = _button("×", "close")
	close.custom_minimum_size.x = 40
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(close)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	_top.market_name.text = str(_crop_name(crop)).to_upper() + " MARKET"
	_top.price.text = "%s  %s" % [_money(float(quote.get("sell", 0))), _change_text(delta)]
	_top.price.add_theme_color_override("font_color", GREEN if delta >= 0 else CHERRY)
	_top.luck.text = "%.1f×" % (_frozen_luck if _rolling else _effective_luck())
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
	if is_instance_valid(_context):
		_context.text = text
		_context_box.visible = not text.is_empty() and not text.begins_with("WASD") and not text.begins_with("GOLDEN SHORES · 2") and not text.begins_with("SPUD VALLEY ·")
		if not _tutorial.is_empty():
			_context_box.hide()

func show_toast(text: String) -> void:
	if _rolling or not _tutorial.is_empty():
		return
	if not is_instance_valid(root):
		build_ui()
	# Seed a real wrap width before rapid notifications can query minimum height.
	_toast_label.size.x = 538.0
	_toast_label.text = text
	_toast_box.size = Vector2(566.0, maxf(52.0, _toast_label.get_minimum_size().y + 28.0))
	_toast_box.show()
	_toast_box.move_to_front()
	_toast_timer.start()

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
	return is_instance_valid(_modal) and _modal.visible

func close_panel() -> void:
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
	_modal_card.add_theme_stylebox_override("panel", _style(CASINO if kind == "roll" else CREAM, 24, 17))
	_modal_title.add_theme_color_override("font_color", CREAM if kind == "roll" else INK)
	_modal_subtitle.add_theme_color_override("font_color", CASINO_LIGHT if kind == "roll" else MUTED)
	_refs.clear()
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var scroll: ScrollContainer = _body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0
	match kind:
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
		_: _build_help()
	_refresh_panel()
	_modal.show()
	_refresh_seed_visibility()
	_modal.move_to_front()
	_apply_tutorial_visibility()
	_apply_tutorial_buttons()

func _heading(title: String, subtitle: String) -> void:
	_modal_title.text = title
	_modal_subtitle.text = subtitle

func _info(key: String, text: String = "", color: Color = GREEN, size: int = 14) -> Label:
	var label: Label = _wrap(text, size, color)
	_body.add_child(label)
	_refs[key] = label
	return label

func _offer(title: String, detail: String, text: String, action: String, primary: bool = false, parent: VBoxContainer = null) -> void:
	var card: PanelContainer = _card(PAPER, 13)
	var target: VBoxContainer = _body if parent == null else parent
	target.add_child(card)
	var row: HBoxContainer = _hbox(12)
	card.add_child(row)
	var description: VBoxContainer = _vbox(3)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	description.add_child(_wrap(title, 17, INK, true))
	var detail_label: Label = _wrap(detail, 13, MUTED)
	description.add_child(detail_label)
	_refs[action + ":detail"] = detail_label
	var button: Button = _button(text, action, primary)
	button.custom_minimum_size.x = 146
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	_refs[action] = button

func _build_market() -> void:
	var first_seed: bool = _tutorial_seed_market()
	_heading("Meet the seed seller" if first_seed else "The Spud Exchange", "Start small. One Russet seed is all you need." if first_seed else "Buy seeds low. Grow them yourself. Decide when to sell.")
	_info("market_note", "Prices stay live. Changes are vs opening prices; graphs show recent sale prices.")
	_panel_crops = _market_crops()
	for crop: String in _panel_crops:
		var card: PanelContainer = _card(PAPER, 7 if _panel_crops.size() == 5 else 12)
		_body.add_child(card)
		var column: VBoxContainer = _vbox(4 if _panel_crops.size() == 5 else 6)
		card.add_child(column)
		var header: HBoxContainer = _hbox(12)
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
		var row: HBoxContainer = _hbox(10)
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
	_heading("Your inventory", "Your crops. Your gear. Your next big build.")
	_info("inventory_total", "")
	_panel_crops = _known_crops()
	_inventory_sections.clear()
	var tabs: HBoxContainer = _hbox(8)
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
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", "relic"))
		var section: String = "gear" if kind == "gear" else ("crops" if kind in ["seed", "crop"] else ("builds" if kind in ["build", "build_crate"] else "items"))
		var card: PanelContainer = _card(PAPER, 12)
		_inventory_sections[section].add_child(card)
		var row: HBoxContainer = _hbox(12)
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
		elif kind == "gear":
			action = "gear:equip:" + id
		elif kind == "processed" and action in ["", "sell"]:
			action = "build:sell_processed"
		if not action.is_empty():
			var button: Button = _button("Select", action, kind == "crop")
			button.custom_minimum_size.x = 145
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(button)
			_refs["item:" + id + ":action"] = button
	for section: String in ["crops", "gear", "items", "builds"]:
		if _inventory_sections[section].get_child_count() == 0:
			_inventory_sections[section].add_child(_wrap("Empty for now. Keep farming!", 15, MUTED))
	_offer("A roomier barn", "", "Upgrade", "upgrade:barn", false, _inventory_sections.crops)

	var sell_rare: Button = _button("Sell all mutation crates", "sell_mutations")
	_inventory_sections.items.add_child(sell_rare)
	_refs["sell_mutations"] = sell_rare
	_set_inventory_tab()

func _build_tools() -> void:
	_heading("Tools for bigger harvests", "More beds with every click.")
	for tool: String in ["hoe", "water", "harvest"]:
		var names: Dictionary = {"hoe": "The trusty hoe", "water": "Watering can", "harvest": "Harvest scythe"}
		_offer(names[tool], "", "Upgrade", "upgrade:" + tool, true)
	_offer("More room to grow", "Unlock all 24 beds.", "$1.8K", "upgrade:expansion")
	var row: HBoxContainer = _hbox(10)
	_body.add_child(row)
	var dex_button: Button = _button("PotatoDex  [P]", "dex")
	dex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dex_button)
	var island_button: Button = _button("Explore the islands", "island")
	island_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(island_button)
	_info("tool_tip", "Equip tools with keys 1–5 or the hotbar.", MUTED, 13)

func _build_roll() -> void:
	_heading("BUILD CRATE" if _crate_reel else "The Questionable Shack", "")
	_refs["roll_purse"] = _modal_subtitle
	var reel_card: PanelContainer = _card(Color("20152f"), 10)
	reel_card.add_theme_stylebox_override("panel", _style(Color("20152f"), 10, 14, Color("6d518f")))
	_body.add_child(reel_card)
	_spinner = RollReel.new()
	_spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spinner.custom_minimum_size.y = 180
	reel_card.add_child(_spinner)
	_spinner.finished.connect(_on_roll_finished)
	_spinner.set_build_deck(_crate_reel)
	var result_box: VBoxContainer = _vbox(3)
	_body.add_child(result_box)
	var result_title: Label = _wrap("PICK A STAKE. LET IT ROLL.", 18, GOLD, true)
	result_box.add_child(result_title)
	_refs["roll_result_title"] = result_title
	var result_detail: Label = _wrap("Your prize lands in the centre.", 13, Color("dbcee9"))
	result_box.add_child(result_detail)
	_refs["roll_result_detail"] = result_detail
	var receipt: Label = _wrap("", 12, CASINO_LIGHT)
	result_box.add_child(receipt)
	receipt.hide()
	_refs["roll_accounting"] = receipt
	var batch_results: HBoxContainer = _hbox(7)
	_body.add_child(batch_results)
	batch_results.hide()
	_refs["batch_results"] = batch_results
	if _crate_reel:
		result_title.text = "ONE CRATE. ONE BUILD."
		result_detail.text = "One crate → one build level."
		var open_button: Button = _button("Open another Build Crate", "build:open_crate", true)
		_body.add_child(open_button)
		_refs["build:open_crate"] = open_button
		return
	var trophies: Button = _button("▸ Trophy cabinet · rarest drops", "toggle_trophies")
	_body.add_child(trophies)
	_refs["trophy_toggle"] = trophies
	var gallery: VBoxContainer = _vbox(8)
	_body.add_child(gallery)
	_refs["trophy_gallery"] = gallery
	_trophy_signature = ""
	_refresh_trophies()
	_info("crown_offer", "AURORA CROWN · One free same-stake roll with every purchase.", Color("98e3e8"), 12)
	_info("roll_minimum", "", CASINO_LIGHT, 12)
	var stakes: GridContainer = GridContainer.new()
	stakes.columns = 2
	stakes.add_theme_constant_override("h_separation", 10)
	stakes.add_theme_constant_override("v_separation", 8)
	_body.add_child(stakes)
	for kind: String in ["normal", "big", "stupid", "all_in"]:
		var button: Button = _button("Roll", "roll:" + kind)
		button.custom_minimum_size.y = 42
		button.mouse_entered.connect(_preview_stake.bind(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _style(Color("e6c07b") if kind == "normal" else Color("eee4f4"), 10, 10))
		button.add_theme_stylebox_override("hover", _style(Color("ffe0a1") if kind == "normal" else Color("d7c2ee"), 10, 10))
		button.add_theme_color_override("font_color", CASINO)
		stakes.add_child(button)
		_refs["roll:" + kind] = button
	if _island_id() == 3:
		var batches: HBoxContainer = _hbox(8)
		_body.add_child(batches)
		var batch_stake: OptionButton = OptionButton.new()
		for label: String in ["Normal stake", "Big stake", "Stupid stake"]:
			batch_stake.add_item(label)
		batch_stake.selected = ["normal", "big", "stupid"].find(_batch_kind)
		batch_stake.item_selected.connect(func(index: int) -> void:
			if not _rolling:
				_batch_kind = ["normal", "big", "stupid"][index]
				_preview_stake(_batch_kind)
				_refresh_panel())
		batches.add_child(batch_stake)
		_refs["batch_stake"] = batch_stake
		for count: int in [3, 5]:
			var batch: Button = _button("Roll ×%d" % count, "batch:" + str(count))
			batch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			batches.add_child(batch)
			_refs["batch:" + str(count)] = batch
		_info("batch_note", "FROSTHOLLOW SPECIAL · Same odds per roll. Every prize is yours.", CASINO_LIGHT, 12)
	var odds: GridContainer = GridContainer.new()
	odds.columns = 3
	odds.add_theme_constant_override("h_separation", 18)
	odds.add_theme_constant_override("v_separation", 4)
	_body.add_child(odds)
	var tiers: Array = _state.call("roll_odds", _stake_kind)
	for entry: Dictionary in tiers:
		var tier: String = str(entry.get("tier", "common"))
		var label: Label = _label("", 12, CASINO_LIGHT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = str(entry.get("description", ""))
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		odds.add_child(label)
		_refs["odds:" + tier] = label
	_info("all_in_warning", "", Color("f0b995"), 13)
	var cancel: Button = _button("Keep my coins · cancel all-in", "cancel_all_in")
	_body.add_child(cancel)
	_refs["cancel_all_in"] = cancel

func _build_dex() -> void:
	_heading("The PotatoDex", "Strange mutations. Growing mastery. Every harvest counts.")
	_panel_crops = _known_crops()
	for crop: String in _panel_crops:
		_info("mastery:" + crop, "", INK, 16)
	_info("dex_bonus", "", GREEN, 14)
	_info("dex_entries", "", MUTED, 15)
	_info("dex_tip", "Mutation value = live crop price × rarity multiplier.", MUTED, 14)

func _build_island() -> void:
	_heading("New islands. Bigger harvests.", "Your crops keep growing while you travel.")
	_offer("SPUD VALLEY", "24 beds · 4 crops · Home sweet home", "Travel", "travel:1", true)
	_offer("GOLDEN SHORES", "48 beds · 2× yield · 4× mutations\nFirst Sunburst harvest: guaranteed Golden mutation.", "Travel", "travel:2", true)
	_info("island_requirements", "", CORAL, 15)
	_offer("A ticket to Golden Shores", "%s harvests + %s" % [_number(_catalog_number("ISLAND2_UNLOCK_HARVEST", 500)), _money(_catalog_number("ISLAND2_UNLOCK_COST", 1000000))], "Unlock · $1M", "island_unlock")
	_refs["island_unlock_card"] = _body.get_child(_body.get_child_count() - 1)
	_info("island_rush", "Buyer contracts · Five quests · Big stock surges", MUTED, 14)
	if _island_id() >= 2 or _flag("island3_unlocked"):
		_offer("FROST HOLLOW", "80 beds · 3× yield · Icecaps\nBreak frozen beds for a stock bonus.", "Travel", "travel:3", true)
		_info("winter_requirements", "", Color("6594b8"), 14)
		_offer("A passage through the ice", "%s + %s harvests" % [_money(_catalog_number("ISLAND3_UNLOCK_COST", 1e11)), _number(_catalog_number("ISLAND3_UNLOCK_HARVEST", 25000))], "Unlock · $100B", "island3_unlock")
		_refs["winter_unlock_card"] = _body.get_child(_body.get_child_count() - 1)
	var quests: Button = _button("Local quest board  [Q]", "quests")
	_body.add_child(quests)

func _build_quests() -> void:
	_heading(str(_state.call("island_name")).capitalize() + " quests", "Grow it. Ship it. Claim it.")
	_info("quest_note", "", CORAL, 14)
	for quest: Dictionary in _quests():
		var id: String = str(quest.get("id", ""))
		var card: PanelContainer = _card(SHORES_PAPER, 12)
		_body.add_child(card)
		var body: VBoxContainer = _vbox(5)
		card.add_child(body)
		body.add_child(_wrap(str(quest.get("title", "Farm challenge")), 17, INK, true))
		body.add_child(_wrap(str(quest.get("description", "")), 13, MUTED))
		var progress: ProgressBar = ProgressBar.new()
		progress.custom_minimum_size.y = 7
		progress.show_percentage = false
		progress.add_theme_stylebox_override("background", _style(Color("e4d9c5"), 0, 3))
		progress.add_theme_stylebox_override("fill", _style(GOLD, 0, 3))
		body.add_child(progress)
		_refs["quest:" + id + ":bar"] = progress
		var row: HBoxContainer = _hbox(10)
		body.add_child(row)
		var detail: Label = _wrap("", 13, INK)
		row.add_child(detail)
		_refs["quest:" + id + ":detail"] = detail
		var claim: Button = _button("Claim reward", "quest:" + id, true)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(claim)
		_refs["quest:" + id] = claim

func _build_help() -> void:
	_heading("Welcome to Taterland", "A little manual farming. A very wild potato market.")
	var intro: PanelContainer = _card(INK, 18)
	_body.add_child(intro)
	intro.add_child(_wrap("CHECK PRICES → PLANT → WATER → HARVEST → SELL OR HOLD", 20, CREAM, true))
	_help_step("01  Move & farm", "WASD to walk · Two-finger scroll / pinch to zoom\n1 Hoe · 2 Seeds · 3 Water · 4 Harvest · 5 Spray\nClick a bed to use your tool.")
	_help_step("02  Grow", "Water once. Harvest when ripe.\nRusset 10s · Golden 30s · Giant/Sunburst 45s · Icecap 60s · Radioactive 90s")
	_help_step("03  Buy low. Sell high.", "B: Market · I: Inventory · F: Sell held\nSurges last 10 seconds. Save crops for the right price.")
	_help_step("04  Go bigger", "U: Upgrade tools\nChain harvests within 3.5s for up to ×16 bonuses.")
	_help_step("05  Find your build", "R: Roll for gear and builds using game coins. Empty rolls happen.\nP: Discoveries · Q: Quests")
	_help_step("06  Hire a crew", "Ducks clear pests: up to 1 / 2 / 3 per island.\nHire more or train them for speed.")
	_help_step("07  Winter tricks", "Burn 25 Icecaps for faster growth.\nFrostbreak: hoe icy beds within 20s for a seed + stock bonus.")
	_body.add_child(_button("Let's get growing  →", "close", true))

func _help_step(title: String, detail: String) -> void:
	var box: VBoxContainer = _vbox(3)
	_body.add_child(box)
	box.add_child(_label(title, 17, INK, true))
	box.add_child(_wrap(detail, 14, MUTED))

func _build_pause() -> void:
	_heading("Your farm", "%s · Your crops and the market keep moving." % str(_state.call("island_name")))
	var menu: GridContainer = GridContainer.new()
	menu.columns = 3
	menu.add_theme_constant_override("h_separation", 10)
	menu.add_theme_constant_override("v_separation", 10)
	_body.add_child(menu)
	var activity_name: String = "Duck patrol" if _island_id() == 1 else ("Buyer contracts" if _island_id() == 2 else "Frost furnace")
	var entries: Array = [["Inventory", "inventory", "I", "build_crate"], ["Market", "market", "B", "trader_token"], ["Debug: money, luck & time", "debug", "", "debug"], ["Player builds", "builds", "C", "farmer"], [activity_name, "activities", "", "duck" if _island_id() == 1 else ("contract" if _island_id() == 2 else "furnace")], ["Quests", "quests", "Q", "almanac"], ["Tool upgrades", "tools", "U", "hoe"], ["Roll House", "roll", "R", "gambler"], ["Travel islands", "island", "", "compass"], ["PotatoDex", "dex", "P", "lens"], ["Tracked prices", "tracked_prices", "", "investor"]]
	if _island_id() > 1:
		entries.insert(5, ["Duck patrol", "duck_patrol", "", "duck"])
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
		button.custom_minimum_size.y = 92
		menu.add_child(button)
		var row: HBoxContainer = _hbox(6)
		button.add_child(row)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.offset_top = 8
		row.offset_bottom = -8
		var icon_kind: String = "activity" if entry[1] in ["activities", "duck_patrol", "debug"] else ("build" if str(entry[3]) in ["farmer", "gambler", "investor"] else ("tool" if entry[3] == "hoe" else ("build_crate" if entry[3] == "build_crate" else "relic")))
		row.add_child(_icon({"kind": icon_kind, "id": str(entry[3])}, 48))
		var name_label: Label = _wrap(str(entry[0]) + ("\n[" + str(entry[2]) + "]" if not str(entry[2]).is_empty() else ""), 13, INK, true)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
	var utility: HBoxContainer = _hbox(8)
	_body.add_child(utility)
	for entry: Array in [["Save farm", "save"], ["Load farm", "load"], ["Graphics", "graphics"], ["How to play", "help"]]:
		var button: Button = _button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(button)
	if _tutorial.is_empty():
		_body.add_child(_button("First island guided tour", "tutorial:restart"))
	_body.add_child(_button("Back to the farm", "close", true))
	if _reset_pending:
		_info("reset_warning", "Replace this farm with a new one? This cannot be undone.", CHERRY, 14)
		_body.add_child(_button("Keep my farm", "cancel_reset"))
		_body.add_child(_button("Yes, start a new farm", "reset", true))
	else:
		var reset_button: Button = _button("Start a new farm…", "request_reset")
		reset_button.add_theme_font_size_override("font_size", 12)
		_body.add_child(reset_button)

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
			_refs.roll_purse.text = "Purse %s  ·  Luck %.1f×  ·  %s stake bonus +%.0f%%" % [_money(_frozen_coins if _rolling else coins), _frozen_luck if _rolling else _effective_luck(), _stake_kind.replace("_", " ").capitalize(), _frozen_stake_bonus if _rolling else float(_state.call("stake_luck_bonus", _stake_kind))]
			var all_in_floor: float = _minimum_roll_stake("all_in")
			_refs.roll_minimum.text = "Single roll %s  ·  All-in requires more than %s" % [_money(float(_state.call("roll_cost", "normal"))), _money(all_in_floor)]
			var labels: Dictionary = {"normal": "ROLL", "big": "BIG ROLL", "stupid": "STUPID ROLL", "all_in": "CONFIRM ALL-IN" if _all_in_pending else "ALL-IN"}
			for kind: String in ["normal", "big", "stupid", "all_in"]:
				var cost: float = _frozen_coins if kind == "all_in" and _rolling else float(_state.call("roll_cost", kind))
				var caption: String = "%s · %s" % [labels[kind], _money(cost)]
				if kind == "all_in" and coins <= all_in_floor and not _rolling:
					caption = "ALL-IN · Need > " + _money(all_in_floor)
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
			var odds: Array = _frozen_odds if _rolling else _state.call("roll_odds", _stake_kind)
			_spinner.set_odds(odds)
			for entry: Dictionary in odds:
				var key: String = "odds:" + str(entry.get("tier", "common"))
				if _refs.has(key):
					_refs[key].text = "???  ??%" if bool(entry.get("hidden_chance", false)) else "%s  %.3f%%" % [str(entry.get("tier", "common")).capitalize(), float(entry.get("chance", 0))]
		"dex":
			var mastery: Dictionary = _state.get("mastery")
			for crop: String in _panel_crops:
				_refs["mastery:" + crop].text = "%s  ·  Lv.%d  ·  %s harvested  ·  +%d%% yield" % [_crop_name(crop), int(_state.call("mastery_level", crop)), _number(float(mastery.get(crop, 0))), mini(1000, 2 * int(_state.call("mastery_level", crop)))]
			_refs.dex_bonus.text = "Permanent harvest bonus: +%s%% yield. Mutation luck: %.1f×." % [_number(float(_state.get("permanent_yield")) * 100.0), float(_state.get("luck"))]
			var dex: Array = _state.get("dex")
			_refs.dex_entries.text = "DISCOVERED MUTATIONS\n" + (", ".join(dex) if not dex.is_empty() else "No mutations discovered yet. Your next harvest could surprise you.")

		"island":
			var unlocked: bool = bool(_state.get("island2_unlocked"))
			var harvested: int = int(_state.call("total_mastery"))
			_set_button("travel:1", "You are here" if _island_id() == 1 else "Travel to Valley", _island_id() == 1)
			_set_button("travel:2", "You are here" if _island_id() == 2 else ("Travel to Shores" if unlocked else "Unlock first"), _island_id() == 2 or not unlocked)
			_refs.island_requirements.visible = not unlocked
			_refs.island_requirements.text = "YOUR PROGRESS  ·  %s / %s harvested  ·  %s / %s" % [_number(harvested), _number(_catalog_number("ISLAND2_UNLOCK_HARVEST", 500)), _money(coins), _money(_catalog_number("ISLAND2_UNLOCK_COST", 1000000))]
			_refs.island_unlock_card.visible = not unlocked
			_set_button("island_unlock", "Unlock · " + _money(_catalog_number("ISLAND2_UNLOCK_COST", 1000000)), unlocked or coins < _catalog_number("ISLAND2_UNLOCK_COST", 1000000) or harvested < _catalog_number("ISLAND2_UNLOCK_HARVEST", 500))
			if _refs.has("travel:3"):
				var winter_unlocked: bool = _flag("island3_unlocked")
				_set_button("travel:3", "You are here" if _island_id() == 3 else ("Travel to Frost" if winter_unlocked else "Unlock first"), _island_id() == 3 or not winter_unlocked)
				_refs.winter_requirements.visible = not winter_unlocked
				_refs.winter_requirements.text = "%s / %s harvested  ·  %s / %s" % [_number(harvested), _number(_catalog_number("ISLAND3_UNLOCK_HARVEST", 25000)), _money(coins), _money(_catalog_number("ISLAND3_UNLOCK_COST", 1e11))]
				_refs.winter_unlock_card.visible = not winter_unlocked
				_set_button("island3_unlock", "Unlock · " + _money(_catalog_number("ISLAND3_UNLOCK_COST", 1e11)), winter_unlocked or not unlocked or coins < _catalog_number("ISLAND3_UNLOCK_COST", 1e11) or harvested < _catalog_number("ISLAND3_UNLOCK_HARVEST", 25000))
		"builds":
			_refresh_builds()
		"activities":
			_refresh_activities()
		"duck_patrol":
			_refresh_duck_patrol()
		"debug":
			_refresh_debug()
		"quests":
			_refs.quest_note.text = "Complete these goals on %s, then claim your rewards." % str(_state.call("island_name"))
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
				_refs["quest:" + id + ":detail"].text = "%s / %s  ·  %s%s" % [_number(minf(progress, target)), _number(target), str(quest.get("reward_text", "")), "  ·  CLAIMED ✓" if claimed else ""]
				var claim: Button = _refs["quest:" + id]
				claim.visible = complete and not claimed
				claim.disabled = claimed or not complete
				claim.text = "Claim reward"
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
	_toast_box.position.y = 205

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
	_place(_export_box, Rect2(28, 98, 302, 86))
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
	_refs.roll_result_title.text = "LET IT ROLL…"
	_refs.roll_result_detail.text = "A little suspense. A lot of possibility."
	_refs.roll_accounting.hide()
	_toast_box.hide()
	_reward_box.hide()
	_refresh_panel()
	return true

func spin_roll(result: Dictionary) -> void:
	if not _rolling:
		return
	if result.is_empty() or not is_instance_valid(_spinner):
		cancel_roll()
		return
	_spinner.spin_to(result.duplicate(true))

func cancel_roll() -> void:
	_rolling = false
	_batch_results.clear()
	if is_instance_valid(_spinner):
		_spinner.spinning = false
		_spinner.set_process(false)
	if _panel_kind == "roll":
		_refs.roll_result_title.text = "PICK A STAKE. LET IT ROLL."
		_refs.roll_result_detail.text = "Your coins are ready when you are."
		_refs.roll_accounting.hide()
		_refresh_panel()

func _on_roll_finished(result: Dictionary) -> void:
	if not _rolling:
		return
	_rolling = false
	_revealed_roll = result.duplicate(true)
	var title: String = str(result.get("title", "Roll complete"))
	var detail: String = str(result.get("detail", ""))
	var tier: String = str(result.get("tier", "common"))
	_refs.roll_result_title.text = "%s · %s" % [tier.to_upper(), title]
	_refs.roll_result_detail.text = detail
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
				detail = "%s · %s slot%s\n%s" % ["EQUIPPED" if equipped else "STORED", str(entry.get("slot", "gear")).capitalize(), " · " + specialty.capitalize() + " style" if specialty not in ["", "all"] else "", detail]
				if float(entry.get("synergy", 1.0)) > 1.0:
					detail += " · Matching build: bonuses +25%"
				if is_instance_valid(button):
					button.text = "Equipped ✓" if equipped else "Equip " + str(entry.get("slot", "gear"))
					button.disabled = equipped
			"relic":
				detail = "ACTIVE · " + (detail if not detail.is_empty() else str(entry.get("description", "Permanent bonus")))
		_refs[key + ":detail"].text = detail
	var barn_cost: float = 500.0 * pow(5.0, int(_state.get("barn_level")))
	_refs["upgrade:barn:detail"].text = "More space for your harvest."
	_set_button("upgrade:barn", _money(barn_cost), float(_state.get("coins")) < barn_cost)
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
	_heading("Make the farm your own", "Five ways to play. Build Crates grant levels. Find crates in 5% of rolls.")
	_info("build_activity_title", "", INK, 18)
	_info("build_activity_detail", "", MUTED, 14)
	var actions: HBoxContainer = _hbox(10)
	_body.add_child(actions)
	var ability: Button = _button("Use ability", "build:ability", true)
	ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(ability)
	_refs["build:ability"] = ability
	var processed: Button = _button("Sell processed", "build:sell_processed")
	processed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(processed)
	_refs["build:sell_processed"] = processed
	var progress: ProgressBar = ProgressBar.new()
	progress.max_value = 1.0
	progress.custom_minimum_size.y = 7
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _style(PAPER, 0, 3))
	progress.add_theme_stylebox_override("fill", _style(GOLD, 0, 3))
	_body.add_child(progress)
	_refs["build_progress"] = progress
	for entry: Dictionary in _build_entries():
		var id: String = str(entry.get("id", "farmer"))
		_offer(str(entry.get("name", id.capitalize())), "", "Select", "build:select:" + id)
		var build_card: Node = _body.get_child(_body.get_child_count() - 1)
		var row: HBoxContainer = build_card.get_child(0) as HBoxContainer
		if is_instance_valid(row):
			var icon: Control = _icon({"kind": "build", "id": id})
			row.add_child(icon)
			row.move_child(icon, 0)

func _refresh_builds() -> void:
	var system: Object = _build_system()
	if system == null or not system.has_method("activity_info"):
		_refs.build_activity_title.text = "Choose your next way to farm."
		_refs.build_activity_detail.text = "Find a Build Crate at the Roll House, then open it from Inventory."
		_set_button("build:ability", "No active ability", true)
		_refs["build:sell_processed"].hide()
		_refs.build_progress.hide()
		return
	var activity: Dictionary = system.call("activity_info")
	_refs.build_activity_title.text = str(activity.get("title", "Your build"))
	var cooldown: float = float(activity.get("cooldown", 0))
	_refs.build_activity_detail.text = str(activity.get("description", "")) + (" Ready in %.1fs." % cooldown if cooldown > 0 else "")
	_set_button("build:ability", str(activity.get("action_label", "Use ability")), not bool(activity.get("can_use", false)))
	var value: float = float(activity.get("processed_value", 0))
	_refs["build:sell_processed"].visible = value > 0
	_set_button("build:sell_processed", "Sell processed · " + _money(value), value <= 0)
	_refs.build_progress.visible = bool(activity.get("processing", false))
	_refs.build_progress.value = clampf(float(activity.get("progress", 0)), 0, 1)
	for entry: Dictionary in _build_entries():
		var id: String = str(entry.get("id", "farmer"))
		var key: String = "build:select:" + id
		if not _refs.has(key):
			continue
		var unlocked: bool = bool(entry.get("unlocked", false))
		var selected: bool = bool(entry.get("active", false))
		var bonuses: String = str(entry.get("bonuses", ""))
		_refs[key + ":detail"].text = str(entry.get("description", "")) + ("\n" + bonuses if not bonuses.is_empty() else "")
		_set_button(key, "Active · Lv.%d" % int(entry.get("level", 1)) if selected else ("Select · Lv.%d" % int(entry.get("level", 1)) if unlocked else "Find in a crate"), selected or not unlocked)

func _build_tracked_prices() -> void:
	_heading("Tracked Seed Prices", "Choose prices for your Seeds tray [2]. Your choices are saved.")
	for id: String in _market_crops():
		var row: HBoxContainer = _hbox(12)
		_body.add_child(row)
		row.add_child(_icon({"kind": "seed", "crop": id}, 48))
		var toggle: CheckButton = CheckButton.new()
		toggle.text = _crop_name(id) + " seeds"
		toggle.custom_minimum_size.y = 46
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = id in _tracked_ids()
		toggle.set_meta("tracked_seed", id)
		toggle.toggled.connect(func(enabled: bool) -> void: action_requested.emit("tracked_seed:%s:%d" % [id, 1 if enabled else 0]))
		row.add_child(toggle)
	_body.add_child(_button("Back to the farm", "close", true))

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
		_export_detail.text = "+15,000–50,000% AFTER LIFTOFF"
	elif _island_id() >= 3 and not _surge_active and not _surge_urgent:
		_export_detail.text = "3K–10K%% · ROCKET %d:%02d" % [rocket_seconds / 60, rocket_seconds % 60]
	# Keep only actionable island activities as a single short secondary line.
	if not _surge_active and not _surge_urgent:
		if _island_id() == 2 and bool(_state.get("export_active")):
			_export_detail.text = "Export · %.0fs · Golden / Sunburst" % float(_state.get("export_timer"))
	_export_detail.add_theme_color_override("font_color", accent)
	_export_bar.max_value = 10.0 if _surge_active else (10.0 if _surge_urgent else 180.0)
	_export_bar.value = float(info.get("timer", 180)) if _surge_active or _surge_urgent else 180.0 - float(info.get("timer", 180))
	if rocket_soon and not _surge_active:
		_export_bar.value = rocket_seconds
	_export_bar.get_theme_stylebox("fill").bg_color = accent
	_toast_box.position.y = 205
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
	var row: HBoxContainer = _refs.batch_results
	row.show()
	for result: Dictionary in _batch_results:
		var tier: String = str(result.get("tier", "common"))
		var accent: Color = RollReel.COLORS.get(tier, Color("b8a3ce"))
		var card: PanelContainer = _card(Color("382747"), 7)
		card.set_meta("result", result.duplicate(true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("382747"), 7, 10, accent))
		row.add_child(card)
		var column: VBoxContainer = _vbox(3)
		card.add_child(column)
		var item_id: String = str(result.get("item_id", ""))
		var result_title: String = str(result.get("title", "")).to_lower()
		var icon_kind: String = "gear" if not item_id.is_empty() else ("build_crate" if "build crate" in result_title else ("empty" if "empty" in result_title or "nothing" in result_title else "relic"))
		var icon: Control = _icon({"kind": icon_kind, "id": item_id if not item_id.is_empty() else "trader_token"}, 44)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var title: Label = _wrap(str(result.get("title", "Reward")), 11, CREAM, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size.x = 95
		column.add_child(title)
		var rarity: Label = _label(tier.to_upper(), 10, accent)
		rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(rarity)
		if _batch_bonus_count() > 0:
			var bonus_label: Label = _label("AURORA BONUS" if bool(result.get("bonus_roll", false)) else "PAID ROLL", 9, Color("98e3e8") if bool(result.get("bonus_roll", false)) else CASINO_LIGHT)
			bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(bonus_label)
		card.tooltip_text = ("Aurora bonus roll · No extra stake\n" if bool(result.get("bonus_roll", false)) else "") + str(result.get("detail", ""))
		card.mouse_filter = Control.MOUSE_FILTER_PASS

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
	var hero: HBoxContainer = _hbox(15)
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
			var crop_row: HBoxContainer = _hbox(12)
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
			var choices: HBoxContainer = _hbox(12)
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
			_offer("Feed the frost furnace", "20s burst · 2.5× growth · 3× processing", "Burn 25 Icecaps", "activity:furnace:icecap", true)
			_info("activity_hint", "Uses stored Icecaps · 60s between bursts", MUTED)
			_body.add_child(_button("Winter Roll House · 3 or 5 rolls together", "roll"))
	_refresh_activities()

func _build_duck_patrol() -> void:
	_heading("Duck patrol", "More ducks. Faster patrols. Fewer pests.")
	var hero: HBoxContainer = _hbox(15)
	_body.add_child(hero)
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
	_set_button("activity:duck", "Flock full" if count >= capacity else "Hire +1 · " + _money(float(data.get("duck_cost", 1500))), not bool(data.get("duck_can_buy", false)))
	_refs["activity:duck:detail"].text = "%d / %d ducks · Each duck covers a different bed." % [count, capacity]
	_set_button("activity:duck:speed", "Top speed" if speed >= 2 else ("Hire a duck first" if count == 0 else "Faster · " + _money(float(data.get("duck_speed_cost", 15000)))), not bool(data.get("duck_can_train", false)))
	_refs["activity:duck:speed:detail"].text = "%.0fs → %.0fs per bed" % [float(data.get("duck_interval", 4)), maxf(2.0, float(data.get("duck_interval", 4)) - 1.0)] if speed < 2 else "2s per bed · Maximum speed"
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
			_refs.activity_detail.text = "%s Icecaps in storage\n2.5× crop growth · 3× processing · 20 seconds" % _number(float(data.get("furnace_held", 0)))
			_set_button("activity:furnace:icecap", "Burning…" if remaining > 0 else ("Cooling…" if cooldown > 0 else "Burn 25 Icecaps"), not bool(data.get("can_charge", false)))

func _build_equipment_header(parent: VBoxContainer) -> void:
	var card: PanelContainer = _card(Color("e3e8d8"), 12)
	parent.add_child(card)
	var layout: HBoxContainer = _hbox(14)
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
		button.custom_minimum_size = Vector2(150, 91)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(button)
		var contents: HBoxContainer = _hbox(5)
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
		_refs["equipment:" + slot] = button
		_refs["equipment:" + slot + ":icon"] = icon
		_refs["equipment:" + slot + ":name"] = name_label
	var rules: Label = _wrap("Equip for bonuses · No duplicate stacking · Matching build: +25%", 12, MUTED)
	parent.add_child(rules)
	var totals: Label = _wrap("", 12, GREEN, true)
	parent.add_child(totals)
	_refs["equipment_totals"] = totals
	parent.add_child(_label("OWNED GEAR", 16, INK, true))

func _refresh_equipment() -> void:
	if not _refs.has("equipment_preview") or not _state.has_method("equipment_info"):
		return
	var catalog: Dictionary = _state.get_script().get_script_constant_map().get("ITEM_CATALOG", {})
	var loadout: Dictionary = _state.call("equipment_loadout")
	_refs.equipment_preview.set_equipment(loadout, catalog)
	var builds: Object = _build_system()
	var active_build: String = str(builds.get("active")) if builds != null else "farmer"
	_refs.equipment_build.text = "YOUR LOADOUT · " + active_build.to_upper()
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
	_refs.equipment_totals.text = "EQUIPPED · " + " · ".join(total_parts) if not total_parts.is_empty() else "Equip gear below to activate its bonuses."
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
		var icon: Control = _refs[key + ":icon"]
		icon.item = {"kind": "slot", "id": slot} if empty else {"kind": "gear", "id": id, "slot": slot, "role": entry.get("role", "")}
		icon.queue_redraw()
		button.add_theme_stylebox_override("normal", _style(Color("d5e7cb") if not empty else PAPER, 8, 10, Color("91b184") if not empty else Color.TRANSPARENT))

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
		_info("debug_access_note", "Money, luck and time controls are locked.", MUTED, 16)
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
	_heading("Debug controls", "Money and luck save. Time speed resets each session.")
	var data: Dictionary = _debug_info()
	_info("debug_balance", "", INK, 20)
	_info("debug_luck_status", "", GREEN, 15)
	for field: String in ["money", "luck"]:
		var card: PanelContainer = _card(PAPER, 14)
		_body.add_child(card)
		var column: VBoxContainer = _vbox(8)
		card.add_child(column)
		column.add_child(_label("MONEY · ONE-TIME MULTIPLIER" if field == "money" else "LUCK · STAYS ACTIVE UNTIL RESET", 15, INK, true))
		var row: HBoxContainer = _hbox(8)
		column.add_child(row)
		var number: Control
		var input: LineEdit
		if field == "money":
			var money_input: DebugMoneyInput = DebugMoneyInput.new()
			money_input.max_value = float(data.get("money_limit", 1e6))
			money_input.value = 1.0
			money_input.placeholder_text = "0.1 or 1e-20"
			money_input.tooltip_text = "Multiply current money by this amount. Decimals and scientific notation work; 0 clears the purse."
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
		number.custom_minimum_size = Vector2(155, 40)
		number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(number)
		input.add_theme_color_override("font_color", INK)
		input.add_theme_font_size_override("font_size", 16)
		input.add_theme_stylebox_override("normal", _style(CREAM, 10, 8, Color("c6d3bd")))
		input.add_theme_stylebox_override("focus", _style(CREAM, 10, 8, GREEN))
		_refs["debug_" + field] = number
		var presets: Array = ["0.01", "0.1", "1", "10", "100", "1000"] if field == "money" else ["1", "10", "100", "1000"]
		for amount: String in presets:
			var preset: Button = _button("×" + amount, "debug_%s:%s" % [field, amount])
			preset.add_theme_stylebox_override("normal", _style(CREAM, 10, 8, Color("c6d3bd")))
			preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(preset)
	var time_card: PanelContainer = _card(PAPER, 14)
	_body.add_child(time_card)
	var time_column: VBoxContainer = _vbox(8)
	time_card.add_child(time_column)
	_refs["debug_time_status"] = _label("GAME TIME", 15, INK, true)
	time_column.add_child(_refs.debug_time_status)
	var time_row: HBoxContainer = _hbox(8)
	time_column.add_child(time_row)
	for speed: int in [1, 2, 5, 10, 30]:
		var choice: Button = _button("%d×" % speed, "debug:time:%d" % speed)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_row.add_child(choice)
		_refs["debug_time_%d" % speed] = choice
	_info("debug_time_note", "Crops, markets, pests and abilities follow game time.", MUTED, 13)
	_info("debug_preview", "", GREEN, 14)
	var actions: HBoxContainer = _hbox(9)
	_body.add_child(actions)
	var apply: Button = _button("Apply money once + set luck", "debug_apply", true)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(apply)
	_refs["debug_apply"] = apply
	var reset: Button = _button("Reset luck + time", "debug:reset")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(reset)
	_refs["debug_reset"] = reset
	_info("debug_note", "Money: 0.1 = 10% · 0 = empty purse\nReset keeps coins. Debug trophies stay marked.", MUTED, 13)
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
	_refs.debug_balance.text = "CURRENT MONEY  " + _precise_money(coins)
	_refs.debug_luck_status.text = "Normal luck %.2f×  ·  Debug multiplier %.2f×  ·  Effective luck %.2f×" % [float(data.get("normal_luck", 1)), float(data.get("luck_multiplier", 1)), float(data.get("effective_luck", 1))]
	var parsed: Dictionary = _debug_money_value()
	_refs.debug_apply.disabled = parsed.has("error")
	if parsed.has("error"):
		_refs.debug_preview.text = str(parsed.error)
		_refs.debug_preview.add_theme_color_override("font_color", CHERRY)
	else:
		var multiplier: float = float(parsed.value)
		var after: float = minf(1e300, coins * multiplier)
		_refs.debug_preview.text = "APPLY ONCE  %s × %s → %s\nSet debug luck to %.2f×" % [_precise_money(coins), String.num_scientific(multiplier), _precise_money(after), float(_refs.debug_luck.value)]
		_refs.debug_preview.add_theme_color_override("font_color", GREEN)
	_refs.debug_reset.disabled = is_equal_approx(float(data.get("luck_multiplier", 1)), 1.0) and is_equal_approx(_debug_time_multiplier, 1.0)
	_refs.debug_time_status.text = "GAME TIME · %d×" % int(_debug_time_multiplier)
	for speed: int in [1, 2, 5, 10, 30]:
		_refs["debug_time_%d" % speed].disabled = is_equal_approx(_debug_time_multiplier, float(speed))

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
	_refs.trophy_toggle.text = "%s Trophy cabinet · %d rare discoveries" % ["▾" if _trophies_open else "▸", trophies.size()]
	_refs.trophy_gallery.visible = _trophies_open
	var signature: String = JSON.stringify(trophies)
	if signature == _trophy_signature:
		return
	_trophy_signature = signature
	var gallery: VBoxContainer = _refs.trophy_gallery
	for child: Node in gallery.get_children():
		gallery.remove_child(child)
		child.queue_free()
	gallery.add_child(_wrap("Your rarest drops. Odds show that roll's rarity tier, not the specific item.", 12, CASINO_LIGHT))
	if trophies.is_empty():
		gallery.add_child(_wrap("No trophies yet. Rare and better drops will appear here.", 14, CREAM))
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	gallery.add_child(grid)
	for trophy: Dictionary in trophies:
		var tier: String = str(trophy.get("tier", "rare"))
		var accent: Color = RollReel.COLORS.get(tier, Color("c1a4df"))
		var card: PanelContainer = _card(Color("382747"), 10)
		card.set_meta("trophy", trophy.duplicate(true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("382747"), 10, 12, accent))
		grid.add_child(card)
		var row: HBoxContainer = _hbox(8)
		card.add_child(row)
		var item_id: String = str(trophy.get("item_id", ""))
		var title: String = str(trophy.get("title", "Rare drop"))
		var kind: String = "gear" if not item_id.is_empty() else ("build_crate" if "build crate" in title.to_lower() else "relic")
		row.add_child(_icon({"kind": kind, "id": item_id if not item_id.is_empty() else "trader_token"}, 50))
		var labels: VBoxContainer = _vbox(3)
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(labels)
		labels.add_child(_wrap(title, 13, CREAM, true))
		labels.add_child(_wrap("%s · ×%d%s" % [tier.to_upper(), int(trophy.get("count", 1)), " · DEBUG" if bool(trophy.get("debug", false)) else ""], 10, accent, true))
		labels.add_child(_wrap("Tier odds %.4f%%\nIsland %d · roll #%d" % [float(trophy.get("best_probability", 0)), int(trophy.get("island", 1)), int(trophy.get("roll_number", 0))], 11, Color("ded4ea")))
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
