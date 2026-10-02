extends VBoxContainer
## Painted workbench and timber stock bins, with clear labels and real dividers.
const Surface = preload("res://scripts/shop_surface.gd")
const Barn = preload("res://scripts/barn_crates.gd")
const Type = preload("res://scripts/ui_type.gd")
const INK := Color("282d30")
const MUTED := Color("594b39")
const PAPER := Color("f2e2c2")
const COPPER := Color("d8955f")
const HONEY := Color("ebc781")
const GREEN := Color("d4a654")
const CHALK := Color("f2edda")
var hud
var barn: bool = false
var _grids: Array[GridContainer] = []
var _tabs: GridContainer
var _ledger_trade: Button
var _wallet: Label
var _levels: Dictionary = {}
var _item_quantities: Dictionary = {}
var _fit_pending: bool = false
var _title_font: FontVariation = Type.face(Type.DISPLAY, 650)
var _body_font: FontVariation = Type.face(Type.BODY, 600)

func setup(owner_hud, barn_page: bool) -> void:
	hud = owner_hud
	barn = barn_page
	_title_font.fallbacks = [Type.SPUDION]
	_body_font.fallbacks = [Type.SPUDION]
	set_meta("market_responsive", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var modal: StyleBoxFlat = hud.Cozy.modal()
	modal.bg_color = _room_color()
	modal.border_color = Color("3d211a") if barn else Color("12212c")
	modal.set_corner_radius_all(5)
	modal.set_border_width_all(3)
	modal.shadow_size = 0
	hud._modal_card.add_theme_stylebox_override("panel", modal)
	hud._modal_card.offset_left = -500
	hud._modal_card.offset_right = 500
	hud._modal_card.offset_top = -380
	hud._modal_card.offset_bottom = 380
	hud._modal_title.text = "Nell's barn" if barn else "Bram's workbench"
	hud._modal_title.add_theme_color_override("font_color", CHALK)
	hud._modal_title.add_theme_font_override("font", _title_font)
	hud._modal_title.add_theme_font_size_override("font_size", 29)
	hud._modal_subtitle.hide()
	if barn: _build_barn()
	else: _build_tools()
	resized.connect(_layout)
	minimum_size_changed.connect(_queue_modal_fit)
	_layout.call_deferred()
	_queue_modal_fit()

func _queue_modal_fit() -> void:
	if _fit_pending or not is_inside_tree(): return
	_fit_pending = true
	# Wrapping and responsive columns settle after the page is attached.
	await get_tree().process_frame
	await get_tree().process_frame
	_fit_pending = false
	if is_queued_for_deletion() or not is_instance_valid(hud): return
	if hud._refs.get("shop_page") == self: hud._fit_shop_modal()

static func content_height(owner_hud) -> float:
	return owner_hud.modal_content_height()

func _room_color() -> Color:
	return Color("723e32") if barn else Color("213a4d")

func _card_color() -> Color:
	return Color("e6c89f") if barn else Color("eee1c5")

func _accent() -> Color:
	return HONEY if barn else COPPER

func _label(words: String, pixels: int = 14, color: Color = INK, display: bool = false) -> Label:
	var result: Label = hud._wrap(words, pixels, color)
	result.add_theme_font_override("font", _title_font if display else _body_font)
	result.set_meta("shop_font", pixels)
	return result

func _style_button(button: Button, accent: Color = HONEY, filled: bool = false) -> void:
	button.custom_minimum_size.y = maxf(46, button.custom_minimum_size.y)
	button.add_theme_font_override("font", _body_font)
	button.add_theme_font_size_override("font_size", 15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if accent == HONEY: accent = _accent()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = accent if filled else PAPER
		if state == "hover": fill = Color("f2cf96") if filled else Color("fff0d5")
		if state == "pressed": fill = Color("c9975a") if filled else Color("d9bc92")
		if state == "disabled": fill = Color("d1bd9e")
		var skin: StyleBoxFlat = hud.Cozy.box(fill, 12, 3, Color("6b482e") if barn else Color("344957"))
		skin.set_border_width_all(1)
		skin.border_width_bottom = 2 if state != "pressed" else 1
		skin.content_margin_top = 9
		skin.content_margin_bottom = 9
		skin.shadow_size = 0
		button.add_theme_stylebox_override(state, skin)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", Color("6b5c48"))
	var focus: StyleBoxFlat = hud.Cozy.box(Color.TRANSPARENT, 12, 3, INK)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)

func _button(words: String, action: String, accent: Color = HONEY, filled: bool = false) -> Button:
	var result: Button = hud._button(words, action)
	_style_button(result, accent, filled)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _timber(parent: Control, name_value: String, _index: int = 0, frame: bool = false) -> PanelContainer:
	var panel := Surface.new()
	panel.name = name_value
	panel.base = Color("4c2822") if barn and frame else (Color("152836") if frame else _card_color())
	panel.edge = Color("795438") if barn else Color("405a6b")
	panel.radius = 3
	panel.frame = frame
	panel.padding = 8 if frame else 16
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

func _grid(parent: Control) -> GridContainer:
	var result := GridContainer.new()
	result.columns = 2
	result.add_theme_constant_override("h_separation", 14)
	result.add_theme_constant_override("v_separation", 14)
	parent.add_child(result)
	_grids.append(result)
	return result

func _build_tools() -> void:
	_wallet = _label("", 14, CHALK)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_wallet)
	var bench := _timber(self, "BramWorkbench", 0, true)
	var grid := _grid(bench)
	var titles := {"hoe": "Hoe", "water": "Watering can", "harvest": "Harvest scythe", "expansion": "Garden beds"}
	for tool: String in ["hoe", "water", "harvest", "expansion"]:
		var action := "upgrade:" + tool
		var tray := _timber(grid, tool.capitalize() + "ToolTray", grid.get_child_count())
		hud._refs[action + ":card"] = tray
		var contents: VBoxContainer = hud._vbox(10)
		tray.add_child(contents)
		var display := HBoxContainer.new()
		display.add_theme_constant_override("separation", 10)
		contents.add_child(display)
		display.add_child(hud._icon({"kind": "metric" if tool == "expansion" else "tool", "id": "beds" if tool == "expansion" else tool}, 90))
		var names: VBoxContainer = hud._vbox(4)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display.add_child(names)
		var tool_name := _label(titles[tool], 23, INK, true)
		tool_name.add_theme_stylebox_override("normal", hud.Cozy.box(COPPER, 7, 2, Color("9b613d")))
		names.add_child(tool_name)
		if tool != "expansion":
			var level := _label("", 12, MUTED)
			names.add_child(level)
			_levels[tool] = level
		var detail := _label("", 14)
		detail.custom_minimum_size.y = 40
		contents.add_child(detail)
		hud._refs[action + ":detail"] = detail
		var purchase := _button("Upgrade", action, HONEY, true)
		contents.add_child(purchase)
		hud._refs[action] = purchase
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	add_child(links)
	links.add_child(_button("PotatoDex  [P]", "dex"))

func _build_barn() -> void:
	Barn.build(self)

func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud) or not is_instance_valid(hud._state): return
	if hud._refs.get("shop_page") != self: return
	if not barn:
		_wallet.text = "Balance " + hud._money(float(hud._state.coins))
		for tool: String in _levels:
			_levels[tool].text = "LEVEL %d" % int(hud._state.tools.get(tool, 0))
		return
	Barn.refresh(self)
	_layout.call_deferred()

func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	if barn:
		Barn.layout(self)
		return
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	for grid: GridContainer in _grids:
		grid.columns = 1 if grid.get_child_count() <= 1 or size.x < (610 if touch else 560) else 2
	for button: Node in find_children("*", "Button", true, false):
		button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(hud.touch_target() if touch else 46, button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", 20 if touch else 15)
	for label: Node in find_children("*", "Label", true, false):
		if label.has_meta("shop_font"):
			label.add_theme_font_size_override("font_size", maxi(18 if touch else 0, int(label.get_meta("shop_font"))))
