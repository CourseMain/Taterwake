extends VBoxContainer
## Seed and crop counters with prices, quantities and transaction confirmation.
const State = preload("res://scripts/game_state.gd")
const Sparkline = preload("res://scripts/price_sparkline.gd")
const Quantity = preload("res://scripts/market_quantity.gd")
const Seeds = preload("res://scripts/seed_packets.gd")
const Place = preload("res://scripts/place_ui.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const Type = preload("res://scripts/ui_type.gd")
const ACCENT = Seeds.ACCENT
const INK := Color("3f2c1c")
const MUTED := Color("705236")
const GAIN := Color("436733")
const LOSS := Color("a63529")
const PAPER := Color("fffbed")
const FRAME := Color("795b32")
const PRICE_TAG := Color("f3efdf")
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
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Place.INK, 18, 3, Place.WOOD))
	crops = State.crops_by_base_price(hud._known_crops() if selling else hud._market_crops())
	hud._panel_crops = crops.duplicate()
	Kit.configure(hud)
	_build_navigation()
	wallet = _label("", 14, MUTED)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.visible = not selling
	add_child(wallet)
	if selling: _build_sell()
	else: _build_buy()
	var header = find_child("PlaceHeader", false, false)
	if header: move_child(header, 0)
	move_child(tabs, 1)
	wallet.visible = true
	hud._state.purchase_completed.connect(_purchased)
	hud._state.sale_completed.connect(_sold)
	resized.connect(_layout)
	if selling: hud._body.get_parent().resized.connect(_layout)
	refresh()
	_layout.call_deferred()

func _build_navigation() -> void:
	tabs = HBoxContainer.new(); tabs.add_theme_constant_override("separation", 12); add_child(tabs)
	for mode in [false, true]:
		var button := _local_button("Sell" if mode else "Buy", "market_mode:sell" if mode else "market_mode:buy", func(): hud.show_market(mode, hud._state))
		button.toggle_mode = true; button.set_pressed_no_signal(selling == mode)
		button.custom_minimum_size.x = 120 * Kit.unit(hud); tabs.add_child(button)
		for variant in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(variant, Kit.skin(Kit.KEEPERS.mara if selling == mode else Kit.PAPER2, Kit.KEEPERS.mara, 8, 12, Kit.unit(hud)))
		button.add_theme_color_override("font_color", Kit.CREAM if selling == mode else Kit.INK)

func _label(text: String, font_size: int, color: Color = INK, display: bool = false) -> Label:
	return Kit.label(hud, text, 22 if font_size >= 22 else 16 if font_size >= 16 else 14, Kit.INK if color == INK else Kit.MUTED if color == MUTED else color, display)

func _style_button(button: Button, accent: Color = ACCENT, filled: bool = false) -> void:
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", _body_font)
	button.add_theme_font_size_override("font_size", 15)
	Place.pill(button, accent, filled)

func _build_buy() -> void:
	Seeds.build(self)

func _build_sell() -> void:
	Place.header(hud, self, "Mara", ACCENT, "mara")
	var help_row := HBoxContainer.new(); add_child(help_row)
	storage_note = _label("", 14, Kit.MUTED)
	storage_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL; help_row.add_child(storage_note)
	Place.help(hud, help_row, "Tonnes left in the barn at Winter start become stores. Storage costs a flat %s, spoils 5%% and lowers quality by 10. Store prices rise through Winter; the dashed sparkline marker is the late-Winter quote. Charts zoom to recent prices. An arrow marks a Winter target outside the labelled range." % hud._state.money(State.MarketDecisions.STORAGE_FEE))
	var varieties := GridContainer.new(); varieties.columns = 5 if Kit.desktop(hud) else 2
	varieties.add_theme_constant_override("h_separation", 12); varieties.add_theme_constant_override("v_separation", 8); add_child(varieties)
	for crop in crops:
		var pick := _local_button(hud._crop_name(crop), "market_crop:" + crop, func(): select_variety(crop))
		pick.picture = {"kind":"crop", "crop":crop}; pick.picture_pixels = 38
		pick.set_meta("plain_control", false)
		pick.custom_minimum_size = Vector2(110, 76) * Kit.unit(hud); varieties.add_child(pick)
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
		var history := _sparkline(tail); history.size_flags_horizontal = Control.SIZE_EXPAND_FILL; history.custom_minimum_size.y = 52
		var grades := HFlowContainer.new(); grades.add_theme_constant_override("h_separation", 8); tail.add_child(grades)
		var buttons: Dictionary = {}
		for word in State.Quality.GRADES:
			var button := _local_button(word, "grade:" + crop + ":" + word, func(): select_variety(crop, word))
			button.toggle_mode = true; button.set_meta("plain_control", true); grades.add_child(button); buttons[word] = button
		var owned := _label("", 13, MUTED); column.add_child(owned); owned.hide()
		sale_rows[crop] = {"card": card, "title": title, "price": price, "change": change, "history": history, "grades": buttons, "owned": owned}
	_build_trade_bar()
	trade_open = true
	seed_button = _local_button("Keep 1 t as seed", "market_keep_seed", func(): hud._act("keep_seed:" + selected + ":" + selected_grade))
	footer.get_child(0).add_child(seed_button)
	var seed_capacity: Label = _label("", 14, MUTED)
	seed_capacity.name = "CropSeedCapacity"
	footer.get_child(0).add_child(seed_capacity)
	seed_button.set_meta("capacity_label", seed_capacity)

func stock(crop: String, grade: String = "") -> int:
	return hud._state.stock_count(crop, grade)
func price_for(crop: String, grade: String, amount: int = -1) -> float:
	var state = hud._state
	var total: int = stock(crop, grade) if amount < 0 else mini(amount, stock(crop, grade))
	var held: int = mini(total, state.Stock.count(state.trading.held, crop, grade)) if stored_mode else 0
	var fresh: float = float(state.market[crop].sell) * State.Quality.MULTIPLIER[grade]
	if stored_mode and total == 0: return state.trading.stored_price(state, crop, grade)
	return (held * state.trading.stored_price(state, crop, grade) + (total - held) * fresh) / total if total > 0 and held > 0 else fresh

func price_history(crop: String, grade: String) -> Array:
	var state = hud._state
	var history: Array = []
	var factor: float = State.Quality.MULTIPLIER[grade]
	if not stored_mode:
		for quote in state.market[crop].history: history.append(float(quote) * factor)
		return history
	# Stored prices follow the Winter clock, rather than the fresh harvest quote.
	var seconds: float = state.season_clock.seconds
	var end: int = ceili(seconds / State.PRICE_QUOTE_SECONDS)
	var base: float = float(State.CropTable.CROPS[crop].base) * factor
	var peak: float = state.trading.peak_price(crop, grade)
	for index in range(maxi(0, end - State.PRICE_HISTORY_LIMIT + 1), end):
		history.append(lerpf(base, peak, clampf(index * State.PRICE_QUOTE_SECONDS / state.SeasonClock.SEASON_SECONDS, 0, 1)))
	history.append(price_for(crop, grade))
	return history

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
	chart.mouse_filter = Control.MOUSE_FILTER_PASS
	chart.tooltip_text = "Recent sale prices, zoomed to their labelled range. A Winter arrow means the target is outside that range."
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
	_style_button(button, ACCENT, primary)
	button.set_meta("kit_type", true)
	button.set_meta("plain_control", true)
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
		for entry in sale_rows.values():
			entry.card.get_child(0).vertical = narrow
			entry.history.custom_minimum_size.y = 60 if touch else 52
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
		if not button.get_meta("kit_type", false): button.add_theme_font_override("font", _body_font)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, hud.touch_target() if touch else 46)
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, hud.touch_target() if touch else 46)
		if touch: button.add_theme_font_size_override("font_size", maxi(22 if button.has_meta("grade_stamp") else 20, button.get_theme_font_size("font_size")))
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
		entry.card.visible = crop == selected
		entry.price.text = state.market_money(price_for(crop, selected_grade if crop == selected else "Standard")) + "/t"
		entry.price.tooltip_text = "Sale price per tonne"
		_show_price_change(entry.change, crop, selected_grade if crop == selected else "Standard")
		entry.card.add_theme_stylebox_override("panel", Place.skin())
		for word in entry.grades:
			entry.grades[word].text = "%s %d t" % [word, stock(crop, word)]
			entry.grades[word].visible = stock(crop, word) > 0
			entry.grades[word].set_pressed_no_signal(crop == selected and word == selected_grade)
			preload("res://scripts/grade_stamp.gd").apply(entry.grades[word], word)
		entry.history.set_history(price_history(crop, selected_grade if crop == selected else "Standard"), MUTED)
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
	var seed_capacity: Label = seed_button.get_meta("capacity_label")
	seed_capacity.visible = seed_button.visible
	seed_capacity.text = "%s: keep up to %d t" % [State.CropTable.CROPS[selected].name.trim_suffix(" Potato"), preload("res://scripts/farm_advice.gd").seed_capacity(state, selected)]
	seed_button.disabled = state.seed_inventory[selected] + state.trading.kept_seed[selected] >= State.MAX_INVENTORY
	payout.text = state.market_money(price_for(selected, selected_grade, amount) * amount) if quantity.valid and amount > 0 else state.money(0)
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
	hud._act("current_sell:%s:%d:%s" % [selected, int(quantity.value), selected_grade])

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

func focus_seed(crop: String) -> void:
	if selling or not seed_cards.has(crop): return
	for frame in range(3): await get_tree().process_frame
	if is_queued_for_deletion(): return
	var swipe: ScrollContainer = grid.get_parent()
	swipe.ensure_control_visible(seed_cards[crop])
	hud._refs[crop + ":select"].grab_focus()
