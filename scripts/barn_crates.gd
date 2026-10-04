extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const ACCENT := Color("a46e43")
static func build(page) -> void:
	var hud = page.hud
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Place.INK, 18, 3, Place.WOOD))
	Place.header(hud, page, "NELL’S BARN", ACCENT, "nell")
	var tally := PanelContainer.new(); tally.name = "BarnTallyBoard"; tally.add_theme_stylebox_override("panel", Place.skin()); page.add_child(tally)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); tally.add_child(row)
	var picture: Control = hud._icon({"kind":"place", "id":"barn"}, 64)
	picture.name = "BarnDrawing"; row.add_child(picture)
	var numbers: VBoxContainer = hud._vbox(2); numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(numbers)
	var total: Label = hud._wrap("", 28, Place.INK, true); numbers.add_child(total); hud._refs.inventory_total = total
	numbers.add_child(hud._wrap("TONNES / CAPACITY", 12, Place.MUTED))
	page._ledger_trade = hud._button("Sell", "sell_potatoes", true); page._ledger_trade.custom_minimum_size.x = 140
	Place.pill(page._ledger_trade, ACCENT, true); row.add_child(page._ledger_trade)
	page._tabs = GridContainer.new(); page._tabs.columns = 2; page._tabs.add_theme_constant_override("h_separation", 8); page.add_child(page._tabs)
	hud._panel_crops = hud._known_crops(); hud._inventory_sections.clear()
	var shelves: Dictionary = {}
	for section in ["crops", "tools"]:
		var tab: Button = hud._button("Crops & seeds" if section == "crops" else "Tools", "inventory_tab:" + section)
		Place.pill(tab, ACCENT); tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page._tabs.add_child(tab); hud._refs["tab:" + section] = tab
		var column: VBoxContainer = hud._vbox(10); page.add_child(column); hud._inventory_sections[section] = column
		shelves[section] = page._grid(column)
	var entries: Array[Dictionary] = hud._inventory_data(); hud._inventory_signature = hud._inventory_id_string(entries)
	for entry in entries:
		if entry.kind in ["seed", "crop"] and int(entry.count) == 0: continue
		var id: String = entry.id; var key: String = "item:" + id
		var shelf: GridContainer = shelves["tools" if entry.kind == "tool" else "crops"]
		var crate: PanelContainer = page._timber(shelf, "Crate_" + id)
		crate.radius = 6; crate.base = Place.WOOD; crate.edge = Place.WOOD.darkened(.25); crate.frame = true
		crate.add_theme_stylebox_override("panel", Place.skin(Place.WOOD, 16, 6, crate.edge))
		var body: VBoxContainer = hud._vbox(6); crate.add_child(body)
		body.add_child(hud._icon(entry, 64))
		var title: Label = hud._wrap("", 18, Place.PAPER, true); body.add_child(title); hud._refs[key + ":title"] = title
		var quantity: Label = hud._wrap("", 28, Place.PAPER, true); body.add_child(quantity); page._item_quantities[id] = quantity
		quantity.visible = entry.kind in ["seed", "crop"]
		if entry.kind == "crop":
			var grades := HFlowContainer.new(); grades.name = "BarnGradeChips_" + entry.crop
			grades.add_theme_constant_override("h_separation", 8); grades.add_theme_constant_override("v_separation", 8); body.add_child(grades)
			for word in hud._state.Quality.GRADES:
				var chip: Label = hud._label("", 22)
				preload("res://scripts/grade_stamp.gd").apply(chip, word)
				grades.add_child(chip); hud._refs[key + ":grade:" + word] = chip
		var detail: Label = hud._wrap("", 13, Place.PAPER.darkened(.1)); body.add_child(detail); hud._refs[key + ":detail"] = detail
		if entry.kind != "crop" and not str(entry.get("action", "")).is_empty():
			var button: Button = hud._button("Select", entry.action); Place.pill(button, ACCENT); body.add_child(button); hud._refs[key + ":action"] = button
	var upgrade := PanelContainer.new(); upgrade.add_theme_stylebox_override("panel", Place.skin()); page.add_child(upgrade)
	hud._refs["upgrade:barn:card"] = upgrade
	var body: VBoxContainer = hud._vbox(5); upgrade.add_child(body)
	body.add_child(hud._wrap("Barn extension", 18, Place.INK, true))
	var detail: Label = hud._wrap("", 14, Place.MUTED); body.add_child(detail); hud._refs["upgrade:barn:detail"] = detail
	var button: Button = hud._button("", "upgrade:barn"); Place.pill(button, ACCENT); body.add_child(button); hud._refs["upgrade:barn"] = button
static func refresh(page) -> void:
	var hud = page.hud; var state = hud._state
	hud._refs.inventory_total.text = "%d / %d t" % [state.storage_used(), state.capacity]
	page._ledger_trade.disabled = state.run_over or state.storage_used() == 0
	for entry in hud._inventory_data():
		var key: String = "item:" + entry.id
		if not hud._refs.has(key + ":title"): continue
		hud._refs[key + ":title"].text = hud._crop_name(entry.crop) + (" seeds" if entry.kind == "seed" else "") if entry.kind in ["crop", "seed"] else entry.name
		if entry.kind in ["seed", "crop"]: page._item_quantities[entry.id].text = "%d %s" % [entry.count, "t" if entry.kind == "crop" else "seeds"]
		if entry.kind == "crop":
			for word in state.Quality.GRADES:
				var chip: Label = hud._refs[key + ":grade:" + word]
				var count: int = state.stock_count(entry.crop, word)
				chip.text = "%s %d t" % [word, count]; chip.visible = count > 0
		if entry.kind == "tool": hud._refs[key + ":detail"].text = entry.effect
		if entry.kind == "seed": hud._refs[key + ":detail"].hide()
static func layout(page) -> void:
	var touch: bool = is_instance_valid(page.hud.get_parent().get("touch_controls")) and page.hud.get_parent().touch_controls.enabled
	for grid in page._grids: grid.columns = 1 if page.size.x < 650 else 3
	Place.compact(page)
	for button in page.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = page.hud.touch_target() if touch else 44
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, page.hud.touch_target() if touch else 44)
		button.add_theme_font_size_override("font_size", 22 if touch else 15)
	for label in page.find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(20, label.get_theme_font_size("font_size")))
