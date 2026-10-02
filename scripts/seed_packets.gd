extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const Board = preload("res://scripts/place_board.gd")
const ACCENT := Color("c98335")
static func build(page) -> void:
	Place.header(page.hud, page, "MARA’S SEEDS", ACCENT, "mara")
	page.hud._modal_market_nav.hide()
	page.wallet.reparent(page); page.move_child(page.wallet, 1)
	page.wallet.add_theme_color_override("font_color", Place.PAPER)
	page.hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Color("304d3d"), 18, 3, Color("5a6d50")))
	var counter := Board.new(); counter.name = "MaraChalkboard"
	counter.add_theme_stylebox_override("panel", Place.skin(Color("304d3d"), 12, 3, Color("304d3d")))
	page.add_child(counter)
	var swipe := ScrollContainer.new(); swipe.name = "SeedPacketSwipe"
	swipe.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	swipe.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	swipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.add_child(swipe)
	page.grid = GridContainer.new(); page.grid.columns = page.crops.size()
	page.grid.add_theme_constant_override("h_separation", 16); page.grid.add_theme_constant_override("v_separation", 16)
	swipe.add_child(page.grid)
	for crop: String in page.crops:
		var card := PanelContainer.new(); card.name = crop.capitalize() + "SeedPacket"
		card.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 12, 8))
		card.custom_minimum_size.x = 176; card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.grid.add_child(card); page.seed_cards[crop] = card
		var body: VBoxContainer = page.hud._vbox(7); card.add_child(body)
		var ribbon: Button = page.hud._button(page.hud._crop_name(crop).to_upper(), "crop:" + crop)
		ribbon.toggle_mode = true
		for state in ["normal", "hover", "pressed", "disabled"]: ribbon.add_theme_stylebox_override(state, Place.skin(page.ACCENTS[crop], 6, 6, page.ACCENTS[crop]))
		ribbon.add_theme_font_size_override("font_size", 18); body.add_child(ribbon)
		page.hud._refs[crop + ":select"] = ribbon
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: page.hud._act("crop:" + crop))
		var picture = page.hud._icon({"kind": "crop", "crop": crop}, 100)
		picture.custom_minimum_size = Vector2(100, 104); body.add_child(picture)
		var price: Label = page._label("", 32, Place.INK, true); price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(price); page.hud._refs[crop + ":seed_price"] = price
		var unit: Label = page._label("PER SEED", 11, Place.MUTED); unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(unit)
		var definition: Dictionary = page.State.CropTable.CROPS[crop]
		body.add_child(page._label("%s · %d t" % [Place.pips(int(definition.grow_seasons), 2), definition["yield"]], 14))
		body.get_child(-1).tooltip_text = "%d season%s to harvest" % [definition.grow_seasons, "s" if definition.grow_seasons > 1 else ""]
		for dial in [["water_need", "drop", "Thirst"], ["heat_tolerance", "sun", "Heat"], ["cold_tolerance", "snowflake", "Cold"]]:
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5); body.add_child(row)
			row.add_child(page.hud._icon({"kind": "metric", "id": dial[1]}, 24))
			var bars := HBoxContainer.new(); bars.name = crop + "_" + dial[0]; bars.set_meta("value", int(definition[dial[0]])); row.add_child(bars)
			bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for level in range(3):
				var bar := PanelContainer.new(); bar.custom_minimum_size = Vector2(14, 9); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				bar.add_theme_stylebox_override("panel", Place.skin(Place.INK if level < int(definition[dial[0]]) else Color("e3dcc6"), 0, 5, Color.TRANSPARENT)); bars.add_child(bar)
			row.add_child(page._label(dial[2], 11, Place.MUTED))
		var badge: Label = page._label({"low":"STEADY PRICE", "mid":"VARIABLE PRICE", "medium":"VARIABLE PRICE", "high":"VOLATILE PRICE"}.get(str(definition.volatility), str(definition.volatility).to_upper()), 11, Place.INK)
		badge.add_theme_stylebox_override("normal", Place.skin(Color("e9e6d5"), 5, 100)); body.add_child(badge)
		body.add_child(page._rule())
		var owned: Label = page._label("", 15); body.add_child(owned); page.hud._refs[crop + ":quote"] = owned
		var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 6); body.add_child(actions)
		for count in [1, 5]:
			var key: String = "buy:%s:%d" % [crop, count]
			var button: Button = page.hud._button("Buy %d" % count, key); Place.pill(button, ACCENT, count == 1)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(button); page.hud._refs[key] = button
			button.visible = not page.hud._tutorial_seed_market() or count == 1
static func refresh(page) -> void:
	var state = page.hud._state
	for crop in page.crops:
		var chosen: bool = state.selected_crop == crop
		page.hud._refs[crop + ":select"].set_pressed_no_signal(chosen)
		var skin: StyleBoxFlat = Place.skin(Place.PAPER, 12, 8, Place.INK if chosen else Color("d7c9aa"))
		skin.shadow_size = 5 if chosen else 0; skin.shadow_offset = Vector2(0, 4)
		page.seed_cards[crop].add_theme_stylebox_override("panel", skin)
		page.hud._refs[crop + ":seed_price"].text = state.market_money(state.market[crop].seed)
		page.hud._refs[crop + ":quote"].text = "%d seeds owned" % state.seed_inventory[crop] if state.seed_inventory[crop] > 0 else ""
		page.hud._refs[crop + ":quote"].visible = state.seed_inventory[crop] > 0
		for count in [1, 5]: page.hud._set_purchase_button("buy:%s:%d" % [crop, count], "Buy 1 Russet" if page.hud._tutorial_seed_market() and count == 1 else "Buy %d" % count, state.market[crop].seed * count, int(state.seed_inventory[crop]) + int(state.trading.kept_seed[crop]) + count > page.State.MAX_INVENTORY)
static func layout(page, width: float, touch: bool) -> void:
	# Packets keep their shape and swipe horizontally on a phone.
	page.grid.columns = page.crops.size()
	var narrow: bool = width < 700
	page.grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if narrow or page.crops.size() == 1 else Control.SIZE_EXPAND_FILL
	for card in page.seed_cards.values(): card.custom_minimum_size.x = 340 if narrow and touch else (220 if narrow or page.crops.size() == 1 else 164)
