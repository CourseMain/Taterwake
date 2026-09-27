extends VBoxContainer
## Bram's workbench and Nell's shelves share Mara's painted timber counter.
const Surface = preload("res://scripts/exchange_surface.gd")
const Type = preload("res://scripts/ui_type.gd")
const INK := Color("253b3b")
const MUTED := Color("617171")
const PAPER := Color("fffcf3")
const TIMBER := Color("d4b382")
const HONEY := Color("edb64e")
const GREEN := Color("168366")
const CHALK := Color("f2edda")
var hud
var barn: bool = false
var _grids: Array[GridContainer] = []
var _tabs: GridContainer
var _capacity: ProgressBar
var _ledger_title: Label
var _ledger_trade: Button
var _wallet: Label
var _levels: Dictionary = {}
var _title_font: FontVariation = Type.face(Type.DISPLAY, 650)
var _body_font: FontVariation = Type.face(Type.BODY, 600)

func setup(owner_hud, barn_page: bool) -> void:
	hud = owner_hud
	barn = barn_page
	_title_font.fallbacks = []
	_body_font.fallbacks = []
	set_meta("market_responsive", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var modal: StyleBoxFlat = hud.Cozy.modal()
	modal.bg_color = Color("f7f4e6")
	modal.border_color = Color("d3dbbe")
	modal.set_corner_radius_all(28)
	hud._modal_card.add_theme_stylebox_override("panel", modal)
	hud._modal_card.offset_left = -500
	hud._modal_card.offset_right = 500
	hud._modal_card.offset_top = -380
	hud._modal_card.offset_bottom = 380
	hud._modal_title.text = "Nell's barn" if barn else "Bram's workbench"
	hud._modal_title.add_theme_font_override("font", _title_font)
	hud._modal_title.add_theme_font_size_override("font_size", 29)
	hud._modal_subtitle.hide()
	if barn: _build_barn()
	else: _build_tools()
	resized.connect(_layout)
	_layout.call_deferred()

func _label(words: String, pixels: int = 14, color: Color = INK, display: bool = false) -> Label:
	var result: Label = hud._wrap(words, pixels, color)
	result.add_theme_font_override("font", _title_font if display else _body_font)
	result.set_meta("shop_font", pixels)
	return result

func _style_button(button: Button, accent: Color = HONEY, filled: bool = false) -> void:
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", _body_font)
	button.add_theme_font_size_override("font_size", 15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foreground: Color = INK if accent.get_luminance() > 0.5 else Color.WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = accent if filled else PAPER
		if state == "hover": fill = accent.lightened(0.1) if filled else accent.lerp(PAPER, 0.84)
		if state == "pressed": fill = accent.darkened(0.08) if filled else accent.lerp(PAPER, 0.68)
		if state == "disabled": fill = Color("e6e9df")
		var skin: StyleBoxFlat = hud.Cozy.box(fill, 12, 14, Color.TRANSPARENT)
		skin.border_width_bottom = 1 if state in ["pressed", "disabled"] else 3
		skin.border_color = accent.darkened(0.12) if filled else accent.lerp(PAPER, 0.45)
		skin.content_margin_top = 9
		skin.content_margin_bottom = 9
		button.add_theme_stylebox_override(state, skin)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, foreground if filled else INK)
	button.add_theme_color_override("font_disabled_color", Color("79867c"))

func _button(words: String, action: String, accent: Color = HONEY, filled: bool = false) -> Button:
	var result: Button = hud._button(words, action)
	_style_button(result, accent, filled)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _timber(parent: Control, name_value: String, index: int = 0, frame: bool = false) -> PanelContainer:
	var panel := Surface.new()
	panel.name = name_value
	var color: Color = Color("9a734d") if frame else (TIMBER if index % 2 == 0 else Color("c8aa7c"))
	var skin: StyleBoxFlat = hud.Cozy.box(color, 10 if frame else 18, 3 if frame else 2, Color("725439") if frame else Color("987448"))
	skin.border_width_bottom = 3 if frame else 5
	if not frame:
		skin.content_margin_top = 15
		skin.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", skin)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

func _grid(parent: Control) -> GridContainer:
	var result := GridContainer.new()
	result.columns = 2
	result.add_theme_constant_override("h_separation", 5)
	result.add_theme_constant_override("v_separation", 7)
	parent.add_child(result)
	_grids.append(result)
	return result

func _build_tools() -> void:
	_wallet = _label("", 14, MUTED)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_wallet)
	var bench := _timber(self, "BramWorkbench", 0, true)
	var grid := _grid(bench)
	var titles := {"hoe": "The trusty hoe", "water": "Watering can", "harvest": "Harvest scythe", "expansion": "Open the far beds"}
	for tool: String in ["hoe", "water", "harvest", "expansion"]:
		var action := "upgrade:" + tool
		var tray := _timber(grid, tool.capitalize() + "ToolTray", grid.get_child_count())
		hud._refs[action + ":card"] = tray
		var contents: VBoxContainer = hud._vbox(6)
		tray.add_child(contents)
		var display := HBoxContainer.new()
		display.add_theme_constant_override("separation", 10)
		contents.add_child(display)
		display.add_child(hud._icon({"kind": "metric" if tool == "expansion" else "tool", "id": "beds" if tool == "expansion" else tool}, 90))
		var names: VBoxContainer = hud._vbox(4)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display.add_child(names)
		names.add_child(_label(titles[tool], 24, INK, true))
		var level := _label("", 12, Color("4e563f"))
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
	links.add_child(_button("Explore the islands", "island"))

func _build_barn() -> void:
	var board := Surface.new()
	board.name = "NellStockLedger"
	board.chalkboard = true
	var board_skin: StyleBoxFlat = hud.Cozy.box(Color("30493f"), 12, 16, Color("795a3c"))
	board_skin.set_border_width_all(3)
	board.add_theme_stylebox_override("panel", board_skin)
	add_child(board)
	var tally: VBoxContainer = hud._vbox(7)
	board.add_child(tally)
	_ledger_title = _label("COUNTED & STORED", 11, Color("c7d1b6"))
	tally.add_child(_ledger_title)
	var total := _label("", 19, CHALK)
	tally.add_child(total)
	hud._refs.inventory_total = total
	_capacity = ProgressBar.new()
	_capacity.custom_minimum_size.y = 7
	_capacity.show_percentage = false
	_capacity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capacity.add_theme_stylebox_override("background", hud.Cozy.box(Color("213b30"), 3, 0))
	_capacity.add_theme_stylebox_override("fill", hud.Cozy.box(HONEY, 3, 0))
	tally.add_child(_capacity)
	_ledger_trade = _button("Check the selling board", "sell_potatoes", GREEN, true)
	tally.add_child(_ledger_trade)
	_tabs = GridContainer.new()
	_tabs.columns = 4
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	add_child(_tabs)
	hud._panel_crops = hud._known_crops()
	hud._inventory_sections.clear()
	var section_names := {"crops": "Crops & seeds", "gear": "Gear", "items": "Items & mutations", "builds": "Builds & crates"}
	for section: String in ["crops", "gear", "items", "builds"]:
		var tab := _button(section_names[section], "inventory_tab:" + section)
		tab.pressed.connect(refresh.call_deferred)
		_tabs.add_child(tab)
		hud._refs["tab:" + section] = tab
		var column: VBoxContainer = hud._vbox(9)
		hud._inventory_sections[section] = column
		add_child(column)
	# The familiar equipment controls keep their slots and turnable farmer.
	hud._build_equipment_header(hud._inventory_sections.gear)
	var gear_grid := _grid(hud._inventory_sections.gear)
	var shelves: Dictionary = {}
	for section: String in ["crops", "items", "builds"]:
		var shelf := _timber(hud._inventory_sections[section], section.capitalize() + "BarnShelf", 0, true)
		shelves[section] = _grid(shelf)
	var entries: Array[Dictionary] = hud._inventory_data()
	hud._inventory_signature = hud._inventory_id_string(entries)
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", "relic"))
		if kind == "gear":
			hud._build_gear_card(gear_grid, entry)
			continue
		var section: String = "crops" if kind in ["seed", "crop"] else ("builds" if kind in ["build", "build_crate"] else "items")
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
		description.add_child(_label("SEED SACK" if kind == "seed" else ("HARVEST CRATE" if kind == "crop" else kind.replace("_", " ").to_upper()), 11, Color("4e563f")))
		var title := _label("", 21, INK, true)
		description.add_child(title)
		hud._refs["item:" + id + ":title"] = title
		var detail := _label("", 13, Color("534d36"))
		contents.add_child(detail)
		hud._refs["item:" + id + ":detail"] = detail
		var action: String = str(entry.get("action", ""))
		if kind == "crop": action = "sell:" + str(entry.get("crop", "russet")) + ":-1"
		elif kind == "processed" and action in ["", "sell"]: action = "build:sell_processed"
		if not action.is_empty():
			var button := _button("Select", action, GREEN if kind in ["crop", "processed", "mutation"] else HONEY, kind == "crop")
			contents.add_child(button)
			hud._refs["item:" + id + ":action"] = button
	for section: String in ["crops", "items", "builds"]:
		if shelves[section].get_child_count() == 0:
			shelves[section].get_parent().hide()
			hud._inventory_sections[section].add_child(_label("Nothing stored here yet.", 14, MUTED))
	if gear_grid.get_child_count() == 0:
		hud._inventory_sections.gear.add_child(_label("No spare gear. Find clothing at the Roll House.", 14, MUTED))
	var upgrade := _timber(self, "BarnExtensionPlan")
	move_child(upgrade, 1)
	hud._refs["upgrade:barn:card"] = upgrade
	var extension_row: BoxContainer = hud._hbox(12)
	upgrade.add_child(extension_row)
	var plan: VBoxContainer = hud._vbox(6)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extension_row.add_child(plan)
	plan.add_child(_label("Make room in the barn", 21, INK, true))
	var detail := _label("", 14)
	plan.add_child(detail)
	hud._refs["upgrade:barn:detail"] = detail
	var expand := _button("Upgrade", "upgrade:barn", HONEY, true)
	expand.custom_minimum_size.x = 160
	expand.size_flags_horizontal = Control.SIZE_SHRINK_END
	expand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	extension_row.add_child(expand)
	hud._refs["upgrade:barn"] = expand
	var sell_mutations := _button("Sell all mutation crates", "sell_mutations", GREEN, true)
	hud._inventory_sections.items.add_child(sell_mutations)
	hud._refs.sell_mutations = sell_mutations
	hud._set_inventory_tab()

func refresh() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(hud._state): return
	if not barn:
		_wallet.text = "Balance %s · Credit left %s" % [hud._money(float(hud._state.coins)), hud._money(hud._state.purchase_credit())]
		for tool: String in _levels:
			_levels[tool].text = "FENCE WORK" if tool == "expansion" else "LEVEL %d" % int(hud._state.tools.get(tool, 0))
		return
	_capacity.max_value = maxf(1.0, float(hud._state.capacity))
	_capacity.value = float(hud._state.storage_used())
	# Gear needs room for the farmer and worn-slot totals. Keep the tally and
	# expansion nearby, and save the full crop ledger for the crop shelves.
	var crop_shelves: bool = hud._inventory_tab == "crops"
	_capacity.visible = crop_shelves
	_ledger_title.visible = crop_shelves
	_ledger_trade.visible = crop_shelves
	hud._refs["upgrade:barn:card"].show()
	for section: String in hud._inventory_sections:
		_style_button(hud._refs["tab:" + section], HONEY, section == hud._inventory_tab)
	for entry: Dictionary in hud._inventory_data():
		if str(entry.get("kind", "")) != "gear": continue
		var key: String = "item:" + str(entry.id)
		var card: PanelContainer = hud._refs.get(key + ":card")
		if card == null: continue
		var skin: StyleBoxFlat = hud.Cozy.box(TIMBER, 18, 12, Color("987448"))
		skin.border_width_bottom = 5
		card.add_theme_stylebox_override("panel", skin)
		_style_button(hud._refs[key + ":action"], HONEY, not bool(entry.get("equipped", false)))
	_layout.call_deferred()

func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	for grid: GridContainer in _grids:
		grid.columns = 1 if size.x < (610 if touch else 560) else 2
	if barn:
		_tabs.columns = 2 if size.x < 700 else 4
		hud._refs["upgrade:barn:card"].get_child(0).vertical = size.x < 560
		hud._refs["upgrade:barn"].size_flags_horizontal = Control.SIZE_EXPAND_FILL if size.x < 560 else Control.SIZE_SHRINK_END
		if touch: hud.get_parent().touch_controls.adapt(hud._inventory_sections.gear, size.x, true)
	for button: Node in find_children("*", "Button", true, false):
		button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(68 if touch else 46, button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", 20 if touch else 15)
	for label: Node in find_children("*", "Label", true, false):
		if label.has_meta("shop_font"):
			label.add_theme_font_size_override("font_size", maxi(18 if touch else 0, int(label.get_meta("shop_font"))))
