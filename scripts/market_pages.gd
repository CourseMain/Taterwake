extends VBoxContainer
## Seed and crop counters with prices, quantities and transaction confirmation.
const State = preload("res://scripts/game_state.gd")
const Sparkline = preload("res://scripts/price_sparkline.gd")
const Quantity = preload("res://scripts/market_quantity.gd")
const Seeds = preload("res://scripts/seed_packets.gd")
const Place = preload("res://scripts/place_ui.gd")
const Type = preload("res://scripts/ui_type.gd")
const INK := Color("3f2c1c")
const MUTED := Color("705236")
const GAIN := Color("436733")
const LOSS := Color("a63529")
const PAPER := Color("fffbed")
const FRAME := Color("795b32")
const PRICE_TAG := Color("f3efdf")
const ACCENTS := {"russet": Color("df9c42"), "giant": Color("e87c59"), "golden": Color("dcad24"), "sunburst": Color("ed9737"), "icecap": Color("51aeca")}
var hud
var selling: bool = false
var crops: Array[String] = []
var selected_grade: String = "Standard"
var grade_buttons: Dictionary = {}
var selected: String = ""
var stored_mode: bool = false
var trade_open: bool = false
var seed_button: Button
var sale_rows: Dictionary = {}
var seed_cards: Dictionary = {}
var grid: GridContainer
var tabs: HBoxContainer
var footer: PanelContainer
var quantity: LineEdit
var sell_button: Button
var payout: Label
var status: Label
var crop_quote: Label
var crop_change: Label
var crop_history: Control
var storage_note: Label
var crop_owned: Label
var minus: Button
var plus: Button
var maximum: Button
var wallet: Label
var _trade_row: BoxContainer
var _mobile_actions: HBoxContainer
var _amount_box: VBoxContainer
var _total_box: VBoxContainer
var _receipt_left: float = 0.0
var _receipt: String = ""
var _body_font: FontVariation = Type.face(Type.BODY, 600)
var _title_font: FontVariation = Type.face(Type.DISPLAY, 650)

func setup(owner_hud, sell_page: bool) -> void:
	hud = owner_hud
	_body_font.fallbacks = [Type.SPUDION]
	_title_font.fallbacks = [Type.SPUDION]
	selling = sell_page
	stored_mode = selling and hud._state.season_clock.season == 3
	set_meta("market_responsive", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 18, 3))
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
	tabs = HBoxContainer.new()
	add_child(tabs)
	tabs.hide()

func _label(text: String, font_size: int, color: Color = INK, display: bool = false) -> Label:
	var label: Label = hud._wrap(text, font_size, color)
	label.add_theme_font_override("font", _title_font if display else _body_font)
	return label

func _style_button(button: Button, accent: Color = GAIN, filled: bool = false) -> void:
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", _body_font)
	button.add_theme_font_size_override("font_size", 15)
	Place.pill(button, accent, filled)

func _rule(vertical: bool = false) -> Separator:
	var line: Separator = VSeparator.new() if vertical else HSeparator.new()
	var stroke := StyleBoxLine.new()
	stroke.color = FRAME
	stroke.thickness = 2
	stroke.vertical = vertical
	line.add_theme_stylebox_override("separator", stroke)
	line.add_theme_constant_override("separation", 10)
	return line

func _build_buy() -> void:
	Seeds.build(self)

func _build_sell() -> void:
	Place.header(hud, self, "THE HARVEST MARKET", GAIN)
	var help_row := HBoxContainer.new(); add_child(help_row)
	storage_note = _label("", 14, MUTED)
	storage_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL; help_row.add_child(storage_note)
	Place.help(hud, help_row, "Tonnes left in the barn at Winter start become stores. Storage costs a flat %s, spoils 5%% and lowers quality by 10. Store prices rise through Winter; the dashed sparkline marker is the late-Winter quote." % hud._state.money(State.MarketDecisions.STORAGE_FEE))
	if hud._state.season_clock.season == 3:
		tabs.show()
		for mode in [true, false]:
			var button := _local_button("Winter stores" if mode else "Fresh harvest", "sale_stock:" + str(mode), func(): stored_mode = mode; trade_open = false; _choose_grade(); refresh())
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(button)
	selected = hud._sell_crop if hud._sell_crop in crops else str(hud._state.selected_crop)
	if selected not in crops: selected = crops[0]
	_choose_grade()
	for crop: String in crops:
		var card := PanelContainer.new(); card.name = "SaleRow_" + crop
		card.add_theme_stylebox_override("panel", Place.skin()); add_child(card)
		var column := BoxContainer.new(); column.add_theme_constant_override("separation", 12); card.add_child(column)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); column.add_child(row)
		row.add_child(hud._icon({"kind": "crop", "crop": crop}, 54))
		var words: VBoxContainer = hud._vbox(2); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(words)
		var title := _label(hud._crop_name(crop), 20, INK, true); words.add_child(title)
		var quotes := HBoxContainer.new(); quotes.add_theme_constant_override("separation", 8); words.add_child(quotes)
		var price := _label("", 22); price.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; price.autowrap_mode = TextServer.AUTOWRAP_OFF; quotes.add_child(price)
		var change := _label("", 14); change.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; change.autowrap_mode = TextServer.AUTOWRAP_OFF; change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		change.add_theme_stylebox_override("normal", Place.skin(Place.PAPER, 5, 100)); quotes.add_child(change)
		var tail: VBoxContainer = hud._vbox(5); tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_child(tail)
		var history := _sparkline(tail); history.size_flags_horizontal = Control.SIZE_EXPAND_FILL; history.custom_minimum_size.y = 32
		var grades := HFlowContainer.new(); grades.add_theme_constant_override("h_separation", 8); tail.add_child(grades)
		var buttons: Dictionary = {}
		for word in State.Quality.GRADES:
			var button := _local_button(word, "grade:" + crop + ":" + word, func(): select_variety(crop, word))
			button.toggle_mode = true; grades.add_child(button); buttons[word] = button
		var owned := _label("", 13, MUTED); column.add_child(owned); owned.hide()
		sale_rows[crop] = {"card": card, "title": title, "price": price, "change": change, "history": history, "grades": buttons, "owned": owned}
	_build_trade_bar()
	trade_open = hud._tutorial.get("id", "") == "sell"
	seed_button = _local_button("Keep 1 t as seed", "market_keep_seed", func(): hud._act("keep_seed:" + selected + ":" + selected_grade))
	footer.get_child(0).add_child(seed_button)

func stock(crop: String, grade: String = "") -> int:
	return hud._state.Stock.count(hud._state.trading.held, crop, grade) if stored_mode else hud._state.trading.fresh_count(hud._state, crop, grade)
func price_for(crop: String, grade: String) -> float:
	return hud._state.trading.stored_price(hud._state, crop, grade) if stored_mode else float(hud._state.market[crop].sell) * State.Quality.MULTIPLIER[grade]

func select_variety(crop: String, grade: String = "") -> void:
	selected = crop
	trade_open = true
	if grade.is_empty(): _choose_grade()
	else: selected_grade = grade
	quantity.set_value_no_signal(1)
	_receipt_left = 0
	refresh()

func _sparkline(parent: Control) -> Control:
	var chart := Sparkline.new()
	chart.name = "PriceHistory"
	chart.custom_minimum_size = Vector2(140, 28)
	chart.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.tooltip_text = "Recent sale prices · up to 12 quotes"
	parent.add_child(chart)
	return chart

func _show_price_change(label: Label, crop: String, grade: String) -> void:
	label.text = hud._state.price_percent_text(crop)
	label.add_theme_color_override("font_color", hud.price_change_color(crop))
	if stored_mode:
		var base: float = float(State.CropTable.CROPS[crop].base) * State.Quality.MULTIPLIER[grade]
		var percent: int = roundi((price_for(crop, grade) / base - 1.0) * 100.0)
		label.text = ("+" if percent >= 0 else "−") + str(absi(percent)) + "%"
		label.add_theme_color_override("font_color", GAIN if percent > 0 else (LOSS if percent < 0 else INK))
	label.tooltip_text = "Change from this grade’s base quote"

func _build_trade_bar() -> void:
	footer = hud._card(PAPER, 12)
	footer.add_theme_stylebox_override("panel", Place.skin(PAPER, 14, 8))
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
	_amount_box.add_child(_label("AMOUNT (t)", 11, MUTED))
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 5)
	_amount_box.add_child(amount_row)
	minus = _local_button("−", "quantity_minus", func() -> void: quantity.value -= 1)
	amount_row.add_child(minus)
	quantity = Quantity.new()
	quantity.custom_minimum_size = Vector2(84, 46)
	quantity.add_theme_stylebox_override("normal", hud.Cozy.box(PAPER, 8, 3, FRAME))
	quantity.add_theme_stylebox_override("focus", hud.Cozy.box(PRICE_TAG, 8, 3, INK))
	quantity.add_theme_stylebox_override("read_only", hud.Cozy.box(Color("cbbb92"), 8, 3, FRAME))
	quantity.add_theme_color_override("font_color", INK)
	quantity.add_theme_color_override("font_uneditable_color", MUTED)
	quantity.add_theme_font_override("font", _body_font)
	quantity.add_theme_font_size_override("font_size", 21)
	amount_row.add_child(quantity)
	plus = _local_button("+", "quantity_plus", func() -> void: quantity.value += 1)
	amount_row.add_child(plus)
	maximum = _local_button("Max", "market_all", func() -> void: quantity.value = stock(selected, selected_grade))
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
	var available_width: float = minf(size.x, hud.root.size.x - 88.0)
	var narrow: bool = available_width < 650
	for button: Node in tabs.get_children():
		button.custom_minimum_size.y = hud.touch_target() if touch else 46
		button.add_theme_font_override("font", _body_font)
	if not selling:
		Seeds.layout(self, available_width, touch)
	else:
		for entry in sale_rows.values(): entry.card.get_child(0).vertical = narrow
		if narrow and sell_button.get_parent() != _mobile_actions:
			sell_button.reparent(_mobile_actions)
			_total_box.reparent(_mobile_actions)
		elif not narrow and sell_button.get_parent() != _trade_row:
			sell_button.reparent(_trade_row)
			_trade_row.move_child(sell_button, 0)
			_total_box.reparent(_trade_row)
		_mobile_actions.visible = narrow
		for control: Control in [quantity, minus, plus, maximum]: control.custom_minimum_size.y = hud.touch_target() if touch else 46
		for control: Control in [minus, plus, maximum]: control.custom_minimum_size.x = hud.touch_target() if touch else 46
		quantity.custom_minimum_size.x = 110 if touch else 84
	# Clear, compact numerals and controls; display face stays on headings only.
	for button: Node in find_children("*", "Button", true, false) + hud._modal_trade_footer.find_children("*", "Button", true, false):
		button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, hud.touch_target() if touch else 46)
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, hud.touch_target() if touch else 46)
		if touch: button.add_theme_font_size_override("font_size", maxi(20, button.get_theme_font_size("font_size")))
	for label: Node in find_children("*", "Label", true, false) + hud._modal_trade_footer.find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(18, label.get_theme_font_size("font_size")))

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var state = hud._state
	wallet.text = _receipt if _receipt_left > 0 else "Balance %s" % state.market_money(state.coins)
	if not selling:
		Seeds.refresh(self)
		return
	hud._sell_crop = selected
	for crop in sale_rows:
		var entry: Dictionary = sale_rows[crop]
		var crop_quote_data: Dictionary = state.market[crop]
		entry.price.text = state.market_money(price_for(crop, selected_grade if crop == selected else "Standard")) + "/t"
		entry.price.tooltip_text = "Sale price per tonne"
		_show_price_change(entry.change, crop, selected_grade if crop == selected else "Standard")
		entry.card.add_theme_stylebox_override("panel", Place.skin())
		for word in entry.grades:
			entry.grades[word].text = "%s %d t" % [word, stock(crop, word)]
			entry.grades[word].visible = stock(crop, word) > 0
			entry.grades[word].set_pressed_no_signal(crop == selected and word == selected_grade)
			Place.pill(entry.grades[word], GAIN)
		var factor: float = State.Quality.MULTIPLIER[selected_grade] if crop == selected else 1.0
		var history: Array = []
		for point in crop_quote_data.history: history.append(float(point) * factor)
		entry.history.set_history(history, MUTED)
		entry.history.set_expected_price(state.trading.peak_price(crop, selected_grade if crop == selected else "Standard"))
		entry.owned.text = "%d fresh tonnes" % stock(crop)
	var chosen: Dictionary = sale_rows[selected]
	crop_quote = chosen.price
	crop_change = chosen.change
	crop_history = chosen.history
	crop_owned = chosen.owned
	grade_buttons = chosen.grades
	var quote: Dictionary = state.market.get(selected, {})
	var price: float = price_for(selected, selected_grade)
	var owned: int = stock(selected, selected_grade)
	quantity.set_available(owned)
	var amount: int = int(quantity.value)
	storage_note.text = "Stored prices rise until Winter ends."
	storage_note.visible = state.season_clock.season == 3
	hud._modal_trade_footer.visible = trade_open
	seed_button.visible = state.season_clock.season == 3 and selected_grade != "Feed" and state.stock_count(selected, selected_grade) > 0
	seed_button.disabled = state.seed_inventory[selected] + state.trading.kept_seed[selected] >= State.MAX_INVENTORY
	payout.text = state.market_money(price * amount) if quantity.valid and amount > 0 else state.money(0)
	sell_button.disabled = not quantity.valid or amount < 1 or owned < amount or price <= 0 or state.run_over or not hud._tutorial_allows("sell:%s:%d" % [selected, amount])
	minus.disabled = not quantity.valid or amount <= 1
	plus.disabled = not quantity.valid or amount >= owned
	maximum.disabled = owned == 0
	status.text = "Enter a whole number." if not quantity.valid else (_receipt if _receipt_left > 0 else ("No potatoes to sell." if owned == 0 else ""))
	status.visible = not status.text.is_empty()
	status.add_theme_color_override("font_color", LOSS if not quantity.valid else (GAIN if _receipt_left > 0 else MUTED))
	_layout.call_deferred()

func _sell() -> void:
	if not quantity.apply():
		refresh()
		return
	refresh()
	if sell_button.disabled: return
	if stored_mode:
		hud._act("stored_sell:%s:%d:%s" % [selected, int(quantity.value), selected_grade])
	else: hud._act("sell:%s:%d:%s" % [selected, int(quantity.value), selected_grade])

func _sold(receipt: Dictionary) -> void:
	if not selling or not is_visible_in_tree() or str(receipt.id) != selected: return
	_receipt = "+%s · %s t sold" % [hud._state.market_money(receipt.total), hud._state.format_number(receipt.quantity)]
	_receipt_left = 2.8
	hud._toast_box.hide()
	refresh()

func _purchased(receipt: Dictionary) -> void:
	if selling or not is_visible_in_tree() or receipt.kind != "seeds": return
	_receipt = "+%d %s seeds · −%s" % [receipt.quantity, hud._crop_name(receipt.id), hud._state.market_money(receipt.cost)]
	_receipt_left = 2.8
	refresh()

func _process(delta: float) -> void:
	if _receipt_left > 0:
		_receipt_left = maxf(0, _receipt_left - delta)
		if _receipt_left == 0: refresh()

func _choose_grade() -> void:
	selected_grade = "Standard"
	for word in State.Quality.GRADES:
		if stock(selected, word) > 0:
			selected_grade = word
			return
