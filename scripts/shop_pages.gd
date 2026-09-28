extends VBoxContainer
## Painted workbench and timber stock bins, with clear labels and real dividers.
const Surface = preload("res://scripts/shop_surface.gd")
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
var _capacity: ProgressBar
var _ledger_trade: Button
var _wallet: Label
var _levels: Dictionary = {}
var _item_quantities: Dictionary = {}
var _ledger: Dictionary = {}
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

func _rule(vertical: bool = false) -> Separator:
	var rule: Separator = VSeparator.new() if vertical else HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("906643") if barn else Color("7b6d58")
	line.thickness = 2
	line.vertical = vertical
	rule.add_theme_stylebox_override("separator", line)
	rule.add_theme_constant_override("separation", 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

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
	links.add_child(_button("Islands", "island"))

func _build_barn() -> void:
	var board := _timber(self, "NellStockLedger")
	var tally: VBoxContainer = hud._vbox(7)
	board.add_child(tally)
	var total := _label("", 19)
	total.hide()
	tally.add_child(total)
	hud._refs.inventory_total = total
	var ledger_row := HBoxContainer.new()
	ledger_row.add_theme_constant_override("separation", 12)
	tally.add_child(ledger_row)
	for key: String in ["value", "stored", "capacity"]:
		if ledger_row.get_child_count() > 0: ledger_row.add_child(_rule(true))
		var cell: VBoxContainer = hud._vbox(3)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ledger_row.add_child(cell)
		cell.add_child(_label({"value": "HELD VALUE", "stored": "STORED", "capacity": "CAPACITY"}[key], 11, MUTED))
		var value := _label("", 21, INK, true)
		cell.add_child(value)
		_ledger[key] = value
	_capacity = ProgressBar.new()
	_capacity.custom_minimum_size.y = 7
	_capacity.show_percentage = false
	_capacity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capacity.add_theme_stylebox_override("background", hud.Cozy.box(Color("bd9a71"), 0, 1))
	_capacity.add_theme_stylebox_override("fill", hud.Cozy.box(Color("93462f"), 0, 1))
	tally.add_child(_capacity)
	_ledger_trade = _button("Sell potatoes", "sell_potatoes", GREEN, true)
	tally.add_child(_ledger_trade)
	_tabs = GridContainer.new()
	_tabs.columns = 2
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	add_child(_tabs)
	hud._panel_crops = hud._known_crops()
	hud._inventory_sections.clear()
	var section_names := {"crops": "Crops & seeds", "tools": "Tools"}
	for section: String in ["crops", "tools"]:
		var tab := _button(section_names[section], "inventory_tab:" + section)
		tab.pressed.connect(refresh.call_deferred)
		_tabs.add_child(tab)
		hud._refs["tab:" + section] = tab
		var column: VBoxContainer = hud._vbox(9)
		hud._inventory_sections[section] = column
		add_child(column)
		column.visibility_changed.connect(refresh.call_deferred)
	var shelves: Dictionary = {}
	for section: String in ["crops", "tools"]:
		var shelf := _timber(hud._inventory_sections[section], section.capitalize() + "BarnShelf", 0, true)
		shelves[section] = _grid(shelf)
	var entries: Array[Dictionary] = hud._inventory_data()
	hud._inventory_signature = hud._inventory_id_string(entries)
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", "crop"))
		var section: String = "tools" if kind == "tool" else "crops"
		var shelf: GridContainer = shelves[section]
		var bin := _timber(shelf, "BarnBin" + str(shelf.get_child_count()), shelf.get_child_count())
		var contents: VBoxContainer = hud._vbox(7)
		bin.add_child(contents)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		contents.add_child(row)
		row.add_child(hud._icon(entry, 82))
		var description: VBoxContainer = hud._vbox(3)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var title := _label("", 21, INK, true)
		description.add_child(title)
		hud._refs["item:" + id + ":title"] = title
		if kind in ["seed", "crop"]:
			contents.add_child(_rule())
			var quantity_row := HBoxContainer.new()
			quantity_row.add_theme_constant_override("separation", 12)
			contents.add_child(quantity_row)
			var kind_label := _label("SEEDS" if kind == "seed" else "POTATOES", 12, MUTED)
			kind_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			quantity_row.add_child(kind_label)
			quantity_row.add_child(_rule(true))
			var quantity := _label("", 20, INK, true)
			quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			quantity_row.add_child(quantity)
			_item_quantities[id] = quantity
		var detail := _label("", 13, MUTED)
		contents.add_child(detail)
		hud._refs["item:" + id + ":detail"] = detail
		var action: String = str(entry.get("action", ""))
		if kind == "crop": action = "sell:" + str(entry.get("crop", "russet")) + ":-1"
		if not action.is_empty():
			var button := _button("Select", action, GREEN if kind in ["crop"] else HONEY, kind == "crop")
			contents.add_child(button)
			hud._refs["item:" + id + ":action"] = button
	for section: String in ["crops", "tools"]:
		if shelves[section].get_child_count() == 0:
			shelves[section].get_parent().hide()
			var empty: String = {"crops": "No crops or seeds.", "tools": "No tools."}[section]
			hud._inventory_sections[section].add_child(_label(empty, 14, CHALK))
	var upgrade := _timber(self, "BarnExtensionPlan")
	move_child(upgrade, 1)
	hud._refs["upgrade:barn:card"] = upgrade
	var extension_row: BoxContainer = hud._hbox(12)
	upgrade.add_child(extension_row)
	var plan: VBoxContainer = hud._vbox(6)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extension_row.add_child(plan)
	plan.add_child(_label("Barn capacity", 21, INK, true))
	var detail := _label("", 14)
	plan.add_child(detail)
	hud._refs["upgrade:barn:detail"] = detail
	var expand := _button("Upgrade", "upgrade:barn", HONEY, true)
	expand.custom_minimum_size.x = 160
	expand.size_flags_horizontal = Control.SIZE_SHRINK_END
	expand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	extension_row.add_child(expand)
	hud._refs["upgrade:barn"] = expand

func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud) or not is_instance_valid(hud._state): return
	if hud._refs.get("shop_page") != self: return
	if not barn:
		_wallet.text = "Balance " + hud._money(float(hud._state.coins))
		for tool: String in _levels:
			_levels[tool].text = "LEVEL %d" % int(hud._state.tools.get(tool, 0))
		return
	_ledger.value.text = hud._money(float(hud._state.barn_value()))
	_ledger.stored.text = hud._number(float(hud._state.storage_used()))
	_ledger.capacity.text = hud._number(float(hud._state.capacity))
	_capacity.max_value = maxf(1.0, float(hud._state.capacity))
	_capacity.value = float(hud._state.storage_used())
	# Show the crop ledger beside the crop shelves.
	var crop_shelves: bool = hud._inventory_tab == "crops"
	_capacity.visible = crop_shelves
	_ledger_trade.visible = crop_shelves
	hud._refs["upgrade:barn:card"].show()
	for section: String in hud._inventory_sections:
		_style_button(hud._refs["tab:" + section], HONEY, section == hud._inventory_tab)
	for entry: Dictionary in hud._inventory_data():
		var id: String = str(entry.id)
		if _item_quantities.has(id):
			_item_quantities[id].text = hud._number(float(entry.get("count", 0)))
			hud._refs["item:" + id + ":title"].text = str(entry.get("name", ""))
	_layout.call_deferred()

func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	for grid: GridContainer in _grids:
		grid.columns = 1 if grid.get_child_count() <= 1 or size.x < (610 if touch else 560) else 2
	if barn:
		_tabs.columns = 2
		hud._refs["upgrade:barn:card"].get_child(0).vertical = size.x < 560
		hud._refs["upgrade:barn"].size_flags_horizontal = Control.SIZE_EXPAND_FILL if size.x < 560 else Control.SIZE_SHRINK_END
	for button: Node in find_children("*", "Button", true, false):
		button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(68 if touch else 46, button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", 20 if touch else 15)
	for label: Node in find_children("*", "Label", true, false):
		if label.has_meta("shop_font"):
			label.add_theme_font_size_override("font_size", maxi(18 if touch else 0, int(label.get_meta("shop_font"))))
