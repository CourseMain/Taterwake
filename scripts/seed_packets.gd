extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const ACCENT := Color("6f9a4a")
static func build(page) -> void:
	Kit.configure(page.hud)
	Place.header(page.hud, page, "Mara", ACCENT, "mara")
	page.wallet.reparent(page); page.move_child(page.wallet, 1)
	page.wallet.add_theme_color_override("font_color", Kit.MONEY)
	page.grid = GridContainer.new(); page.grid.columns = 5 if Kit.desktop(page.hud) else 2
	page.grid.add_theme_constant_override("h_separation", ceili(10 * Kit.unit(page.hud)))
	page.grid.add_theme_constant_override("v_separation", ceili(14 * Kit.unit(page.hud)))
	page.add_child(page.grid)
	for crop: String in page.crops:
		var card = preload("res://scripts/kit_card.gd").new(); card.unit = Kit.unit(page.hud); card.name = crop.capitalize() + "SeedPacket"
		card.add_theme_stylebox_override("panel", Kit.skin(Kit.PAPER, Kit.RARITIES.common, 10, 12, Kit.unit(page.hud)))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.grid.add_child(card); page.seed_cards[crop] = card
		var body: VBoxContainer = page.hud._vbox(ceili(6 * Kit.unit(page.hud))); card.add_child(body)
		var picture = page.hud._icon({"kind":"crop", "crop":crop}, 84 * Kit.unit(page.hud))
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(picture)
		var ribbon: Button = Kit.button(page.hud, page.hud._crop_name(crop), "crop:" + crop, Kit.PAPER)
		ribbon.toggle_mode = true; ribbon.set_meta("text_tier", 22)
		for variant in ["normal", "hover", "pressed", "disabled"]: ribbon.add_theme_stylebox_override(variant, StyleBoxEmpty.new())
		for colour in ["font_color", "font_hover_color", "font_pressed_color"]: ribbon.add_theme_color_override(colour, Kit.CROPS[crop])
		body.add_child(ribbon); page.hud._refs[crop + ":select"] = ribbon
		var price: Label = Kit.label(page.hud, "", 22, Kit.MONEY, true); price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(price); page.hud._refs[crop + ":seed_price"] = price
		price.add_theme_color_override("font_color", Kit.CROPS[crop])
		var unit: Label = Kit.label(page.hud, "Per seed", 14, Kit.MUTED); unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(unit)
		var definition: Dictionary = page.State.CropTable.CROPS[crop]
		body.add_child(Kit.label(page.hud, "%d seasons · %d t" % [definition.grow_seasons, definition["yield"]], 14))
		for dial in [["water_need", "drop", "Thirst"], ["heat_tolerance", "sun", "Heat"], ["cold_tolerance", "snowflake", "Cold"]]:
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", ceili(4 * Kit.unit(page.hud))); body.add_child(row)
			row.add_child(page.hud._icon({"kind":"metric", "id":dial[1]}, 18 * Kit.unit(page.hud)))
			var bars := HBoxContainer.new(); bars.name = crop + "_" + dial[0]; bars.set_meta("value", int(definition[dial[0]])); row.add_child(bars)
			bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for level in range(3):
				var bar := Panel.new(); bar.custom_minimum_size = Vector2(6,8) * Kit.unit(page.hud); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				bar.add_theme_stylebox_override("panel", Kit.skin(Kit.CROPS[crop] if level < int(definition[dial[0]]) else Kit.PAPER2, Kit.PAPER2, 0, 2, Kit.unit(page.hud), false)); bars.add_child(bar)
			row.add_child(Kit.label(page.hud, dial[2], 14, Kit.MUTED))
		var owned: Label = Kit.label(page.hud, "", 14); body.add_child(owned); page.hud._refs[crop + ":quote"] = owned
		var actions := VBoxContainer.new(); body.add_child(actions)
		for count in [1,5]:
			var key: String = "buy:%s:%d" % [crop,count]
			var button: Button = Kit.button(page.hud, "Buy %d" % count, key, ACCENT)
			button.set_meta("text_tier", 14); actions.add_child(button); page.hud._refs[key] = button
			button.visible = not page.hud._tutorial_seed_market() or count == 1
static func refresh(page) -> void:
	var state = page.hud._state
	for crop in page.crops:
		var chosen: bool = state.selected_crop == crop
		page.hud._refs[crop + ":select"].set_pressed_no_signal(chosen)
		page.seed_cards[crop].add_theme_stylebox_override("panel", Kit.skin(Kit.PAPER, Kit.MONEY if chosen else Kit.RARITIES.common, 10, 12, Kit.unit(page.hud)))
		page.hud._refs[crop + ":seed_price"].text = state.market_money(state.market[crop].seed)
		page.hud._refs[crop + ":quote"].text = "%d seeds owned" % state.seed_inventory[crop] if state.seed_inventory[crop] > 0 else ""
		page.hud._refs[crop + ":quote"].visible = state.seed_inventory[crop] > 0
		for count in [1,5]: page.hud._set_purchase_button("buy:%s:%d" % [crop,count], "Buy 1 Russet" if page.hud._tutorial_seed_market() and count == 1 else "Buy %d" % count, state.market[crop].seed * count, int(state.seed_inventory[crop]) + int(state.trading.kept_seed[crop]) + count > page.State.MAX_INVENTORY)
static func layout(page, width: float, _touch: bool) -> void:
	page.grid.columns = 1 if page.crops.size() == 1 else 5 if Kit.desktop(page.hud) else 2
	for card in page.seed_cards.values(): card.custom_minimum_size.x = maxf(0, (width - (page.grid.columns - 1) * 10 * Kit.unit(page.hud)) / page.grid.columns)
