extends VBoxContainer
## A lively exchange over the real market, inventory and transaction actions.
const Chart = preload("res://scripts/market_chart.gd")
const State = preload("res://scripts/game_state.gd")
const Quantity = preload("res://scripts/market_quantity.gd")
const Portrait = preload("res://scripts/market_portrait.gd")
const Surface = preload("res://scripts/exchange_surface.gd")
const Type = preload("res://scripts/ui_type.gd")
const INK := Color("253b3b")
const MUTED := Color("617171")
const GAIN := Color("168366")
const LOSS := Color("be4964")
const HONEY := Color("edb64e")
const PAPER := Color("fffcf3")
const BOARD := Color("30493f")
const CHALK := Color("f2edda")
const TIMBER := Color("d4b382")
const ACCENTS := {"russet": Color("df9c42"), "giant": Color("e87c59"), "golden": Color("dcad24"), "radioactive": Color("73b64c"), "sunburst": Color("ed9737"), "icecap": Color("51aeca")}
var hud
var selling: bool = false
var crops: Array[String] = []
var selected: String = ""
var chart: Control
var grid: GridContainer
var tabs: HBoxContainer
var hero: PanelContainer
var footer: PanelContainer
var pager: HBoxContainer
var quantity: LineEdit
var sell_button: Button
var payout: Label
var status: Label
var crop_name: Label
var crop_quote: Label
var crop_owned: Label
var crop_change: Label
var crop_image: Control
var history_label: Label
var older: Button
var newer: Button
var minus: Button
var plus: Button
var maximum: Button
var wallet: Label
var _brand: Label
var _trade_row: BoxContainer
var _mobile_actions: HBoxContainer
var _amount_box: VBoxContainer
var _total_box: VBoxContainer
var _hero_words: VBoxContainer
var _hero_quote_row: HBoxContainer
var _hero_badges: HBoxContainer
var _card_icons: Dictionary = {}
var _card_badges: Dictionary = {}
var _finger: int = -1
var _touch_start := Vector2.ZERO
var _receipt_left: float = 0.0
var _receipt: String = ""
var _selection_tween: Tween
var _animated_portrait: Control
var _layout_key: String = ""
var _body_font: FontVariation = Type.face(Type.BODY, 600)
var _title_font: FontVariation = Type.face(Type.DISPLAY, 650)

func setup(owner_hud, sell_page: bool) -> void:
	hud = owner_hud
	_body_font.fallbacks = []
	_title_font.fallbacks = []
	selling = sell_page
	set_meta("market_responsive", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	crops = State.crops_by_base_price(hud._known_crops() if selling else hud._market_crops())
	hud._panel_crops = crops.duplicate()
	_build_navigation()
	wallet = _label("", 14, MUTED)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.visible = not selling
	add_child(wallet)
	if selling: _build_sell()
	else: _build_buy()
	hud._state.purchase_completed.connect(_purchased)
	hud._state.sale_completed.connect(_sold)
	resized.connect(_layout)
	if selling: hud._body.get_parent().resized.connect(_layout)
	refresh()
	_layout.call_deferred()

func _build_navigation() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._modal_market_nav.add_child(header)
	hud._modal_market_nav.show()
	_brand = _label("Spud Exchange", 25, INK, true)
	_brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_brand)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tabs)
	for tab: Array in [["Buy Seeds", "market"], ["Sell Potatoes", "sell_potatoes"]]:
		var active: bool = selling == (tab[1] == "sell_potatoes")
		var button: Button = hud._button(tab[0], tab[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, HONEY if not selling else GAIN, active)
		tabs.add_child(button)

func _label(text: String, font_size: int, color: Color = INK, display: bool = false) -> Label:
	var label: Label = hud._wrap(text, font_size, color)
	label.add_theme_font_override("font", _title_font if display else _body_font)
	return label

func _style_button(button: Button, accent: Color = GAIN, filled: bool = false) -> void:
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", _body_font)
	button.add_theme_font_size_override("font_size", 15)
	var on_color: Color = INK if accent.get_luminance() > 0.5 else Color.WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = accent if filled else PAPER
		if state == "hover": fill = accent.lightened(0.10) if filled else accent.lerp(PAPER, 0.84)
		if state == "pressed": fill = accent.darkened(0.08) if filled else accent.lerp(PAPER, 0.68)
		if state == "disabled": fill = Color("e6e9df")
		var skin: StyleBoxFlat = hud.Cozy.box(fill, 12, 14, Color.TRANSPARENT if filled else accent.lerp(PAPER, 0.6))
		skin.border_width_bottom = 3 if state not in ["pressed", "disabled"] else 1
		skin.border_color = accent.darkened(0.12) if filled else accent.lerp(PAPER, 0.45)
		skin.content_margin_top = 9
		skin.content_margin_bottom = 9
		button.add_theme_stylebox_override(state, skin)
	button.add_theme_color_override("font_color", on_color if filled else INK)
	button.add_theme_color_override("font_hover_color", on_color if filled else INK)
	button.add_theme_color_override("font_pressed_color", on_color if filled else INK)
	button.add_theme_color_override("font_disabled_color", Color("79867c"))

func _build_buy() -> void:
	var sign := HBoxContainer.new()
	sign.add_theme_constant_override("separation", 12)
	add_child(sign)
	var sign_words: VBoxContainer = hud._vbox(3)
	sign_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign.add_child(sign_words)
	sign_words.add_child(_label("Mara's seed counter", 29, INK, true))
	var counter := Surface.new()
	counter.name = "MaraProduceCounter"
	var counter_skin: StyleBoxFlat = hud.Cozy.box(Color("9a734d"), 10, 3, Color("725439"))
	counter_skin.set_border_width_all(3)
	counter.add_theme_stylebox_override("panel", counter_skin)
	add_child(counter)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 7)
	counter.add_child(grid)
	for crop: String in crops:
		var accent: Color = ACCENTS[crop]
		var card := Surface.new()
		card.name = crop.capitalize() + "SeedBin"
		var skin: StyleBoxFlat = hud.Cozy.box(TIMBER if crops.find(crop) % 2 == 0 else Color("c8aa7c"), 18, 2, Color("987448"))
		skin.border_width_bottom = 5
		skin.content_margin_top = 15
		skin.content_margin_bottom = 20
		card.add_theme_stylebox_override("panel", skin)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var body: VBoxContainer = hud._vbox(6)
		card.add_child(body)
		var preview := HBoxContainer.new()
		body.add_child(preview)
		var picture = Portrait.new()
		picture.crop = crop
		picture.accent = accent
		picture.seed_sack = true
		picture.custom_minimum_size = Vector2(90, 96)
		preview.add_child(picture)
		_card_icons[crop] = picture
		var identity: VBoxContainer = hud._vbox(4)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.add_child(identity)
		identity.add_child(_label(hud._crop_name(crop), 24, INK, true))
		var badge := _label("%ds to grow" % State.CROPS[crop].grow, 12, Color("4e563f"))
		identity.add_child(badge)
		_card_badges[crop] = badge
		var price: Label = _label("", 20, INK)
		identity.add_child(price)
		hud._refs[crop + ":seed_price"] = price
		var produce: Label = _label("", 14, INK)
		body.add_child(produce)
		hud._refs[crop + ":price"] = produce
		var owned: Label = _label("", 13, Color("4e563f"))
		body.add_child(owned)
		hud._refs[crop + ":quote"] = owned
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		body.add_child(actions)
		for count: int in [1, 5]:
			var action := "buy:%s:%d" % [crop, count]
			var button: Button = hud._button("Buy %d" % count, action)
			_style_button(button, accent if crop != "radioactive" else GAIN, count == 1)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.visible = not hud._tutorial_seed_market() or count == 1
			actions.add_child(button)
			hud._refs[action] = button
	var rule: Label = _label("Seeds cost 75% of the current potato price.", 13, MUTED)
	add_child(rule)

func _build_sell() -> void:
	selected = hud._sell_crop if hud._sell_crop in crops else str(hud._state.selected_crop)
	if selected not in crops: selected = crops[0]
	hero = Surface.new()
	hero.name = "ExchangeTradingBoard"
	hero.chalkboard = true
	hero.add_theme_stylebox_override("panel", _board_skin())
	add_child(hero)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	hero.add_child(row)
	row.add_child(_local_button("‹", "market_previous", func() -> void: navigate(-1)))
	crop_image = Portrait.new()
	crop_image.custom_minimum_size = Vector2(108, 108)
	row.add_child(crop_image)
	_hero_words = hud._vbox(2)
	_hero_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hero_words)
	_hero_words.add_child(_label("TODAY'S BUYING BOARD", 11, Color("c7d1b6")))
	crop_name = _label("", 30, CHALK, true)
	_hero_words.add_child(crop_name)
	_hero_quote_row = HBoxContainer.new()
	_hero_quote_row.add_theme_constant_override("separation", 12)
	_hero_words.add_child(_hero_quote_row)
	crop_quote = _label("", 30, CHALK)
	_hero_quote_row.add_child(crop_quote)
	_hero_badges = HBoxContainer.new()
	_hero_badges.add_theme_constant_override("separation", 8)
	_hero_words.add_child(_hero_badges)
	crop_change = _label("", 13, GAIN)
	crop_change.autowrap_mode = TextServer.AUTOWRAP_OFF
	crop_change.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	crop_change.tooltip_text = "Change from this potato's fixed base price."
	_hero_badges.add_child(crop_change)
	crop_owned = _label("", 13, Color("d5dac6"))
	crop_owned.autowrap_mode = TextServer.AUTOWRAP_OFF
	crop_owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_badges.add_child(crop_owned)
	row.add_child(_local_button("›", "market_next", func() -> void: navigate(1)))
	var graph_card: PanelContainer = hud._card(PAPER, 10)
	graph_card.add_theme_stylebox_override("panel", hud.Cozy.box(PAPER, 10, 3, Color("a4ab8f")))
	add_child(graph_card)
	chart = Chart.new()
	chart.custom_minimum_size.y = 300
	graph_card.add_child(chart)
	pager = HBoxContainer.new()
	pager.add_theme_constant_override("separation", 8)
	add_child(pager)
	older = _local_button("‹ Older", "history_older", func() -> void: chart.move_window(1))
	newer = _local_button("Newer ›", "history_newer", func() -> void: chart.move_window(-1))
	pager.add_child(older)
	history_label = _label("", 12, MUTED)
	history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pager.add_child(history_label)
	pager.add_child(newer)
	chart.window_changed.connect(_refresh_history_controls)
	_build_trade_bar()

func _board_skin() -> StyleBoxFlat:
	var skin: StyleBoxFlat = hud.Cozy.box(BOARD, 20, 3, Color("8b6849"))
	skin.set_border_width_all(5)
	skin.content_margin_bottom = 20
	return skin

func _build_trade_bar() -> void:
	footer = hud._card(PAPER, 12)
	footer.add_theme_stylebox_override("panel", hud.Cozy.box(Color("e4dfc7"), 12, 3, Color("a59772")))
	hud._modal_trade_footer.add_child(footer)
	hud._modal_trade_footer.show()
	var content: VBoxContainer = hud._vbox(8)
	footer.add_child(content)
	_trade_row = hud._hbox(14)
	content.add_child(_trade_row)
	sell_button = _local_button("Sell", "market_sell", _sell, true)
	sell_button.custom_minimum_size = Vector2(114, 58)
	sell_button.add_theme_font_size_override("font_size", 23)
	_trade_row.add_child(sell_button)
	_amount_box = hud._vbox(3)
	_trade_row.add_child(_amount_box)
	_amount_box.add_child(_label("AMOUNT", 11, MUTED))
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 5)
	_amount_box.add_child(amount_row)
	minus = _local_button("−", "quantity_minus", func() -> void: quantity.value -= 1)
	amount_row.add_child(minus)
	quantity = Quantity.new()
	quantity.custom_minimum_size = Vector2(84, 46)
	quantity.add_theme_stylebox_override("normal", hud.Cozy.box(PAPER, 8, 12, Color("bdcfae")))
	quantity.add_theme_stylebox_override("focus", hud.Cozy.box(Color.WHITE, 8, 12, GAIN))
	quantity.add_theme_stylebox_override("read_only", hud.Cozy.box(Color("e6e9df"), 8, 12, Color("c6d0bf")))
	quantity.add_theme_color_override("font_color", INK)
	quantity.add_theme_color_override("font_uneditable_color", MUTED)
	quantity.add_theme_font_override("font", _body_font)
	quantity.add_theme_font_size_override("font_size", 21)
	amount_row.add_child(quantity)
	plus = _local_button("+", "quantity_plus", func() -> void: quantity.value += 1)
	amount_row.add_child(plus)
	maximum = _local_button("Max", "market_all", func() -> void: quantity.value = int(hud._state.storage[selected]))
	amount_row.add_child(maximum)
	quantity.value_changed.connect(func(_value: float) -> void: refresh())
	_total_box = hud._vbox(2)
	_total_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_row.add_child(_total_box)
	_total_box.add_child(_label("YOU RECEIVE", 11, MUTED))
	payout = _label("", 29, GAIN)
	_total_box.add_child(payout)
	_mobile_actions = HBoxContainer.new()
	_mobile_actions.add_theme_constant_override("separation", 14)
	content.add_child(_mobile_actions)
	_mobile_actions.hide()
	status = _label("", 13, MUTED)
	content.add_child(status)

func _local_button(caption: String, key: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = hud._button(caption, "", primary)
	for connection: Dictionary in button.pressed.get_connections(): button.pressed.disconnect(connection.callable)
	button.set_meta("action", key)
	button.set_meta("hud_action", key)
	button.custom_minimum_size.x = 46
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(button, GAIN, primary)
	if caption in ["‹", "›", "−", "+"]: button.add_theme_font_size_override("font_size", 25)
	button.pressed.connect(callback)
	return button

func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	var narrow: bool = size.x < 650
	_brand.visible = not narrow
	for button: Node in tabs.get_children():
		button.custom_minimum_size.y = 68 if touch else 46
		button.add_theme_font_override("font", _body_font)
	if not selling:
		grid.columns = 1 if size.x < (610 if touch else 500) else 2
	else:
		var compact: bool = touch and get_viewport_rect().size.y < 700
		if compact and not narrow and _hero_badges.get_parent() != _hero_quote_row:
			_hero_badges.reparent(_hero_quote_row)
		elif (not compact or narrow) and _hero_badges.get_parent() != _hero_words:
			_hero_badges.reparent(_hero_words)
		if narrow and sell_button.get_parent() != _mobile_actions:
			sell_button.reparent(_mobile_actions)
			_total_box.reparent(_mobile_actions)
		elif not narrow and sell_button.get_parent() != _trade_row:
			sell_button.reparent(_trade_row)
			_trade_row.move_child(sell_button, 0)
			_total_box.reparent(_trade_row)
		_mobile_actions.visible = narrow
		crop_image.custom_minimum_size = Vector2.ONE * (74 if compact or narrow else 104)
		crop_name.add_theme_font_size_override("font_size", 24 if narrow or compact else 30)
		crop_quote.add_theme_font_size_override("font_size", 23 if compact else 30)
		chart.font_size = 19 if touch else 15
		chart.queue_redraw()
		for control: Control in [quantity, minus, plus, maximum]: control.custom_minimum_size.y = 68 if touch else 46
		for control: Control in [minus, plus, maximum]: control.custom_minimum_size.x = 68 if touch else 46
		quantity.custom_minimum_size.x = 110 if touch else 84
		_amount_box.get_child(0).visible = not compact
		_total_box.get_child(0).visible = not compact
	# Clear, compact numerals and controls; display face stays on headings only.
	for button: Node in find_children("*", "Button", true, false) + hud._modal_trade_footer.find_children("*", "Button", true, false):
		button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 68 if touch else 46)
		if touch: button.add_theme_font_size_override("font_size", maxi(20, button.get_theme_font_size("font_size")))
	for label: Node in find_children("*", "Label", true, false) + hud._modal_trade_footer.find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(18, label.get_theme_font_size("font_size")))
	if selling: _fit_chart.call_deferred()

func _fit_chart() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(chart): return
	# Measure the complete scroll contents after typography and the fixed trade
	# bar settle. This includes the ledger frame, pager and HUD bottom spacing.
	# A fixed 220px chart floor used to push the pager behind the trade bar on
	# tablet-sized windows. The chart itself switches to three ticks below 212px.
	var scroll: ScrollContainer = hud._body.get_parent()
	var surrounding: float = hud._body.get_combined_minimum_size().y - chart.get_combined_minimum_size().y
	var available: float = floorf(scroll.size.y - surrounding - 1.0)
	chart.custom_minimum_size.y = maxf(140.0, available)
	chart.queue_redraw()

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var state = hud._state
	wallet.text = _receipt if _receipt_left > 0 else "Balance %s · Credit left %s" % [state.market_money(state.coins), state.market_money(state.purchase_credit())]
	if not selling:
		for crop: String in crops:
			var quote: Dictionary = state.market[crop]
			hud._refs[crop + ":seed_price"].text = "%s / seed" % state.market_money(quote.seed)
			hud._refs[crop + ":price"].text = "Potato sells for %s" % state.market_money(quote.sell)
			hud._refs[crop + ":quote"].text = "%s seeds · %s potatoes owned" % [state.format_number(state.seed_inventory[crop]), state.format_number(state.storage[crop])]
			for count: int in [1, 5]:
				var key := "buy:%s:%d" % [crop, count]
				hud._set_button(key, "Buy 1 Russet" if hud._tutorial_seed_market() and count == 1 else state.purchase_caption("Buy %d" % count, quote.seed * count), not state.can_purchase(quote.seed * count) or int(state.seed_inventory[crop]) + count > State.MAX_INVENTORY)
		return
	hud._sell_crop = selected
	var quote: Dictionary = state.market.get(selected, {})
	var price: float = float(quote.get("sell", 0.0))
	var base: float = float(State.CROPS[selected].base)
	var owned: int = int(state.storage.get(selected, 0))
	quantity.set_available(owned)
	var amount: int = int(quantity.value)
	crop_name.text = hud._crop_name(selected) + " Potato"
	crop_quote.text = "%s / potato" % state.market_money(price)
	crop_owned.text = "%s owned" % state.format_number(owned)
	crop_change.text = Chart.percent_label(price, base)
	crop_change.add_theme_color_override("font_color", GAIN if price >= base else LOSS)
	crop_change.add_theme_stylebox_override("normal", hud.Cozy.box(Color("d7efe5") if price >= base else Color("f8e0e5"), 5, 8))
	crop_image.crop = selected
	crop_image.accent = ACCENTS[selected]
	crop_image.queue_redraw()
	chart.set_history(quote.get("history", []), base, state.market_money)
	payout.text = state.market_money(price * amount) if quantity.valid and amount > 0 else "$0.00"
	sell_button.disabled = not quantity.valid or amount < 1 or owned < amount or price <= 0 or state.run_over or not hud._tutorial_allows("sell:%s:%d" % [selected, amount])
	minus.disabled = not quantity.valid or amount <= 1
	plus.disabled = not quantity.valid or amount >= owned
	maximum.disabled = owned == 0
	status.text = "Enter a whole number of potatoes. We don't buy slices." if not quantity.valid else (_receipt if _receipt_left > 0 else ("Empty crate. Bring a harvest; we'll find a buyer." if owned == 0 else "Quoted on the board. Counted into the crate."))
	status.visible = not status.text.is_empty()
	status.add_theme_color_override("font_color", LOSS if not quantity.valid else (GAIN if _receipt_left > 0 else MUTED))
	_refresh_history_controls()
	_layout.call_deferred()

func _refresh_history_controls() -> void:
	if not is_instance_valid(chart): return
	var bounds: Vector2i = chart.window_bounds()
	older.disabled = bounds.x == 0
	newer.disabled = chart.history_offset == 0
	history_label.text = "No chalk on the ledger yet" if chart.samples.is_empty() else "%d–%d of %d · %s" % [bounds.x + 1, bounds.y, chart.samples.size(), "Live" if chart.history_offset == 0 else "History"]

func navigate(direction: int) -> void:
	if not selling or crops.size() < 2: return
	quantity.release_focus()
	selected = crops[posmod(crops.find(selected) + direction, crops.size())]
	chart.history_offset = 0
	quantity.set_available(int(hud._state.storage[selected]))
	quantity.set_value_no_signal(1)
	_receipt_left = 0
	refresh()
	_bounce(crop_image)

func _sell() -> void:
	if not quantity.apply():
		refresh()
		return
	refresh()
	if sell_button.disabled: return
	hud._act("sell:%s:%d" % [selected, int(quantity.value)])

func _sold(receipt: Dictionary) -> void:
	if not selling or not is_visible_in_tree() or str(receipt.id) != selected: return
	_receipt = "+%s · %s sold" % [hud._state.market_money(receipt.total), hud._state.format_number(receipt.quantity)]
	_receipt_left = 2.8
	hud._toast_box.hide()
	refresh()
	_bounce(crop_image)
	var tween := create_tween()
	footer.modulate = Color("d2f5ad")
	tween.tween_property(footer, "modulate", Color.WHITE, 0.45)

func _purchased(receipt: Dictionary) -> void:
	if selling or not is_visible_in_tree() or receipt.kind != "seeds": return
	_receipt = "+%d %s seeds · −%s" % [receipt.quantity, hud._crop_name(receipt.id), hud._state.market_money(receipt.cost)]
	_receipt_left = 2.8
	if _card_icons.has(receipt.id): _bounce(_card_icons[receipt.id])
	refresh()

func _bounce(control: Control) -> void:
	if is_instance_valid(_selection_tween): _selection_tween.kill()
	if is_instance_valid(_animated_portrait):
		_animated_portrait.rotation = 0.0
		_animated_portrait.scale = Vector2.ONE
	_animated_portrait = control
	control.pivot_offset = control.size * 0.5
	control.rotation = -0.055
	control.scale = Vector2.ONE * 0.96
	_selection_tween = create_tween().set_parallel(true)
	_selection_tween.tween_property(control, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_selection_tween.tween_property(control, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _receipt_left > 0:
		_receipt_left = maxf(0, _receipt_left - delta)
		if _receipt_left == 0: refresh()

func _input(event: InputEvent) -> void:
	if not selling or not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _finger != -1:
				_finger = -1
				return
			var swipe_rect: Rect2 = hero.get_global_rect().merge(chart.get_global_rect())
			if swipe_rect.has_point(event.position):
				_finger = event.index
				_touch_start = event.position
		elif event.index == _finger:
			_finger = -1
			var movement: Vector2 = event.position - _touch_start
			if absf(movement.x) >= 60 and absf(movement.x) > absf(movement.y) * 1.4:
				navigate(1 if movement.x < 0 else -1)
				get_viewport().set_input_as_handled()
