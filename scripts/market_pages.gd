extends VBoxContainer
## Seed and crop counters with prices, quantities and transaction confirmation.
const State = preload("res://scripts/game_state.gd")
const Sparkline = preload("res://scripts/price_sparkline.gd")
const Quantity = preload("res://scripts/market_quantity.gd")
const Seeds = preload("res://scripts/seed_packets.gd")
const Place = preload("res://scripts/place_ui.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const Type = preload("res://scripts/ui_type.gd")
const SaleUndo = preload("res://scripts/sale_undo.gd")
const ACCENT = Seeds.ACCENT
const INK := Color("3f2c1c")
const MUTED := Color("705236")
const GAIN := Color("436733")
const LOSS := Color("a63529")
const PAPER := Kit.CREAM
const FRAME := Color("795b32")
const PRICE_TAG := Kit.PAPER
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
var wallet: Label
var _receipt_left: float = 0.0
var _receipt: String = ""
var _undo_sale: RefCounted
var _undo_button: Button
var _guided_close: bool = false
var _guided_sale_baseline: float = 0.0
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
	if not selling: move_child(tabs, 1)
	wallet.visible = not selling
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
	var u: float = Kit.unit(hud)
	add_theme_constant_override("separation", ceili(2 * u))
	Place.header(hud, self, "Mara", ACCENT, "mara")
	find_child("PlaceHeader",false,false).add_theme_stylebox_override("panel",Kit.skin(ACCENT,ACCENT,6,12,u,false))
	# The close and field-notes controls share the navigation row on this page.
	hud._modal_close.get_parent().hide()
	var navigation := HBoxContainer.new(); navigation.name = "SaleNavigation"; navigation.add_theme_constant_override("separation", ceili(6 * u)); add_child(navigation)
	tabs.reparent(navigation); tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_note = _label("Stored prices rise until Winter ends.", 14, Kit.MUTED)
	storage_note.hide(); add_child(storage_note)
	Place.help(hud, navigation, "Tonnes left in the barn at Winter start become stores. Storage costs a flat %s, spoils 5%% and lowers quality by 10. Store prices rise through Winter; the dashed sparkline marker is the late-Winter quote. Charts zoom to recent prices. An arrow marks a Winter target outside the labelled range." % hud._state.money(State.MarketDecisions.STORAGE_FEE))
	navigation.add_child(Kit.button(hud, "×", "close", Kit.PAPER))
	selected = hud._sell_crop if hud._sell_crop in crops else str(hud._state.selected_crop)
	if selected not in crops: selected = crops[0]
	_choose_grade()
	grid = GridContainer.new(); grid.columns = 1
	grid.add_theme_constant_override("h_separation", ceili(8 * u)); grid.add_theme_constant_override("v_separation", ceili(4 * u)); add_child(grid)
	for crop: String in crops:
		var card := PanelContainer.new(); card.name = "SaleRow_" + crop
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", Kit.skin(Kit.PAPER, Kit.RULE, 2, 8, u, false)); grid.add_child(card)
		var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 0); card.add_child(column)
		var top := BoxContainer.new(); top.add_theme_constant_override("separation", ceili(6 * u)); column.add_child(top)
		var names := VBoxContainer.new(); names.custom_minimum_size.x = 86 * u; names.add_theme_constant_override("separation", 0); top.add_child(names)
		var picture: Control = hud._icon({"kind":"crop", "crop":crop}, 22 * u); picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; names.add_child(picture)
		var caption := HBoxContainer.new(); caption.add_theme_constant_override("separation",ceili(4*u)); names.add_child(caption)
		var title := _label(hud._crop_name(crop), 14, Kit.CROPS[crop], true); title.autowrap_mode = TextServer.AUTOWRAP_OFF; caption.add_child(title)
		var owned := _label("", 14); owned.autowrap_mode = TextServer.AUTOWRAP_OFF; caption.add_child(owned)
		var quotes := VBoxContainer.new(); quotes.size_flags_horizontal = Control.SIZE_EXPAND_FILL; quotes.add_theme_constant_override("separation", 0); top.add_child(quotes)
		var quote_row := HBoxContainer.new(); quotes.add_child(quote_row)
		var price := _label("", 14, Kit.INK, true); price.size_flags_horizontal = Control.SIZE_EXPAND_FILL; price.autowrap_mode = TextServer.AUTOWRAP_OFF; quote_row.add_child(price)
		var change := _label("", 14); change.autowrap_mode = TextServer.AUTOWRAP_OFF; quote_row.add_child(change)
		var history := _sparkline(quotes); history.custom_minimum_size = Vector2(0, 32 * u); history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var actions := BoxContainer.new(); actions.add_theme_constant_override("separation", ceili(4 * u)); column.add_child(actions)
		var grades := HBoxContainer.new(); grades.add_theme_constant_override("separation", ceili(2 * u)); actions.add_child(grades)
		var buttons: Dictionary = {}
		for word in State.Quality.GRADES:
			var button := _local_button(word, "grade:" + crop + ":" + word, func(): select_variety(crop, word))
			button.toggle_mode = true; button.set_meta("text_tier", 14); button.custom_minimum_size = Vector2(44,44) * u
			grades.add_child(button); buttons[word] = button
		var sales := HBoxContainer.new(); sales.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sales.add_theme_constant_override("separation", ceili(4 * u)); actions.add_child(sales)
		var sale_buttons: Dictionary = {}
		for amount: int in [1,5]:
			var button := Kit.button(hud, "1 tonne" if amount == 1 else "5 tonnes", "", ACCENT, {"kind":"crop", "crop":crop})
			for connection in button.pressed.get_connections(): button.pressed.disconnect(connection.callable)
			button.set_meta("action", "sell_amount:%s:%d" % [crop,amount]); button.set_meta("hud_action", "sell_amount:%s:%d" % [crop,amount]); button.set_meta("text_tier",14)
			button.picture_pixels = 14
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for variant in ["normal","hover","pressed","disabled"]: button.add_theme_stylebox_override(variant, Kit.skin(ACCENT, ACCENT, 3, 8, u, false))
			button.pressed.connect(func(): _sell_amount(crop,amount))
			sales.add_child(button); sale_buttons[amount] = button
		sale_rows[crop] = {"card":card,"top":top,"actions":actions,"title":title,"price":price,"change":change,"history":history,"grades":buttons,"owned":owned,"sales":sale_buttons,"grade":_grade_for(crop)}
	_build_quantity_model()
	trade_open = true
	footer = hud._card(PAPER, 0); footer.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); hud._modal_trade_footer.add_child(footer)
	var seed_row := HBoxContainer.new(); footer.add_child(seed_row)
	seed_button = Kit.button(hud,"Keep 1 tonne as seed","",Kit.PAPER,{"kind":"crop","crop":selected})
	seed_button.set_meta("text_tier",14); seed_button.picture_pixels = 14
	for variant in ["normal","hover","pressed","disabled"]: seed_button.add_theme_stylebox_override(variant,Kit.skin(Kit.PAPER,Kit.RULE,3,8,u,false))
	for connection in seed_button.pressed.get_connections(): seed_button.pressed.disconnect(connection.callable)
	seed_button.pressed.connect(func(): hud._act("keep_seed:" + selected + ":" + selected_grade))
	seed_row.add_child(seed_button)
	var seed_capacity: Label = _label("",14); seed_row.add_child(seed_capacity); seed_capacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_button.set_meta("capacity_label",seed_capacity)

func _grade_for(crop: String) -> String:
	for grade: String in State.Quality.GRADES:
		if stock(crop,grade) > 0: return grade
	return "Standard"

func _sell_amount(crop: String, amount: int) -> void:
	var target: Button = sale_rows[crop].sales[amount]
	if target.disabled:
		hud.show_refusal("Not enough tonnes.",target); return
	if target == _undo_button and is_instance_valid(_undo_sale) and _undo_sale.available(hud._state):
		_sell(); return
	select_variety(crop,str(sale_rows[crop].grade))
	quantity.set_value_no_signal(amount)
	_undo_button = target
	_sell()

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
	if sale_rows.has(crop): sale_rows[crop].grade = selected_grade
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

func _build_quantity_model() -> void:
	# The bounded amount parser is also used by transaction checks. The page's
	# visible controls send the owner's two explicit amounts to this model.
	quantity = Quantity.new(); quantity.hide(); add_child(quantity)
	quantity.value_changed.connect(func(_value: float): refresh())
	payout = _label("",14); payout.hide(); add_child(payout)
	status = _label("",14); status.hide(); add_child(status)

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
	var u: float = Kit.unit(hud)
	for button in tabs.get_children():
		button.custom_minimum_size.y = 44*u
		button.add_theme_font_size_override("font_size",Kit.pixels(hud,14))
	if not selling:
		Seeds.layout(self,minf(size.x,hud.root.size.x-88),not Kit.desktop(hud))
		return
	var short: bool = hud.root.size.y < 600*u and hud.root.size.x > hud.root.size.y
	grid.columns = 5 if short else 1
	var seed_row: Control = seed_button.get_parent()
	var navigation: Control = find_child("SaleNavigation",false,false)
	if short and seed_row.get_parent() != navigation: seed_row.reparent(navigation)
	elif not short and seed_row.get_parent() != footer: seed_row.reparent(footer)
	footer.visible = seed_button.visible and not short
	hud._modal_trade_footer.visible = footer.visible
	storage_note.visible = stored_mode and not short
	for entry in sale_rows.values():
		entry.top.vertical = short
		entry.actions.vertical = short
		for button in entry.grades.values():
			preload("res://scripts/grade_stamp.gd").apply(button,button.get_meta("grade_word"))
			button.add_theme_font_size_override("font_size",Kit.pixels(hud,14))
			button.custom_minimum_size = Vector2(44,44) * u
			for variant in ["normal","hover","pressed","disabled"]:
				var style = button.get_theme_stylebox(variant).duplicate(); style.content_margin_left = 2*u; style.content_margin_right = 2*u; button.add_theme_stylebox_override(variant,style)

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var state = hud._state
	wallet.text = _receipt if _receipt_left > 0 else "Balance %s" % state.market_money(state.coins)
	if not selling:
		Seeds.refresh(self)
		return
	hud._sell_crop = selected
	sale_rows[selected].grade = selected_grade
	var can_undo: bool = is_instance_valid(_undo_sale) and _undo_sale.available(state)
	for crop in sale_rows:
		var entry: Dictionary = sale_rows[crop]
		var grade: String = entry.grade
		entry.card.show()
		entry.price.text = state.market_money(price_for(crop,grade)) + "/tonne"
		entry.price.tooltip_text = "Sale price per tonne"
		_show_price_change(entry.change,crop,grade)
		for word in entry.grades:
			var button: Button = entry.grades[word]
			button.text = word; button.visible = stock(crop,word) > 0 or word == grade
			button.set_pressed_no_signal(word == grade)
			preload("res://scripts/grade_stamp.gd").apply(button,word); button.set_meta("grade_word",word)
		entry.history.set_history(price_history(crop,grade),Kit.CROPS[crop])
		entry.history.set_expected_price(state.trading.peak_price(crop,grade))
		entry.owned.text = "%d tonnes" % stock(crop,grade)
		for amount: int in entry.sales:
			var button: Button = entry.sales[amount]
			var undo: bool = can_undo and button == _undo_button
			button.text = "Undo" if undo else "1 tonne" if amount == 1 else "5 tonnes"
			button.disabled = not undo and (stock(crop,grade) < amount or state.run_over or not hud._tutorial_allows("sell:%s:%d" % [crop,amount]))
	var chosen: Dictionary = sale_rows[selected]
	crop_quote = chosen.price; crop_change = chosen.change; crop_history = chosen.history; crop_owned = chosen.owned; grade_buttons = chosen.grades
	sell_button = chosen.sales[1]
	quantity.set_available(stock(selected,selected_grade))
	var amount: int = int(quantity.value)
	payout.text = state.market_money(price_for(selected,selected_grade,amount)*amount) if quantity.valid and amount > 0 else state.money(0)
	status.text = "Enter a whole number." if not quantity.valid else (_receipt if _receipt_left > 0 else "No potatoes to sell." if stock(selected,selected_grade) == 0 else "")
	seed_button.visible = state.season_clock.season == 3 and selected_grade != "Feed" and stock(selected,selected_grade) > 0
	seed_button.picture = {"kind":"crop","crop":selected}
	var capacity: Label = seed_button.get_meta("capacity_label")
	capacity.visible = seed_button.visible; capacity.text = "Keep up to %d tonnes." % preload("res://scripts/farm_advice.gd").seed_capacity(state,selected)
	seed_button.disabled = state.seed_inventory[selected] + state.trading.kept_seed[selected] >= State.MAX_INVENTORY
	hud._modal_trade_footer.visible = seed_button.visible; footer.visible = seed_button.visible
	storage_note.visible = state.season_clock.season == 3
	_layout.call_deferred()

func _sell() -> void:
	if is_instance_valid(_undo_sale) and _undo_sale.available(hud._state) and (not is_instance_valid(_undo_button) or _undo_button.text == "Undo"):
		if _undo_sale.undo(hud._state):
			if _guided_close: hud.get_parent().tutorial.sale_baseline = _guided_sale_baseline
			_guided_close = false
			_receipt_left = 0
			if hud.get_parent().tutorial.active: hud.get_parent().tutorial.refresh()
			refresh()
			if not hud.get_parent().test_mode: hud._state.save_game()
		return
	if not quantity.apply():
		refresh()
		return
	refresh()
	if not quantity.valid or quantity.value < 1 or stock(selected,selected_grade) < int(quantity.value) or hud._state.run_over or not hud._tutorial_allows("sell:%s:%d" % [selected,int(quantity.value)]): return
	if not is_instance_valid(_undo_button): _undo_button = sell_button
	var guide = hud.get_parent().get("tutorial")
	_guided_close = is_instance_valid(guide) and guide.active and guide.current_id() == "sell"
	_guided_sale_baseline = guide.sale_baseline if is_instance_valid(guide) else 0
	var reversal: RefCounted = SaleUndo.new(hud._state)
	hud._act("current_sell:%s:%d:%s" % [selected, int(quantity.value), selected_grade])
	_undo_sale = reversal if reversal.commit(hud._state) else null
	refresh()

func _sold(receipt: Dictionary) -> void:
	if not selling or not is_visible_in_tree() or str(receipt.id) != selected: return
	_receipt = "+%s · %s tonnes sold" % [hud._state.market_money(receipt.total), hud._state.format_number(receipt.quantity)]
	_receipt_left = 2.8
	hud._toast_box.hide()
	refresh()

func _purchased(receipt: Dictionary) -> void:
	if selling or not is_visible_in_tree() or receipt.kind != "seeds": return
	_receipt = "+%d %s seeds · −%s" % [receipt.quantity, hud._crop_name(receipt.id), hud._state.market_money(receipt.cost)]
	_receipt_left = 2.8
	refresh()
	var card: Control = seed_cards.get(str(receipt.id))
	if is_instance_valid(card):
		card.pivot_offset = card.size * .5
		var old = card.get_meta("purchase_tween") if card.has_meta("purchase_tween") else null
		if old is Tween and old.is_valid(): old.kill()
		card.scale = Vector2(.985,.985)
		var tween := card.create_tween(); card.set_meta("purchase_tween",tween)
		tween.tween_property(card,"scale",Vector2(1.015,1.015),.10)
		tween.tween_property(card,"scale",Vector2.ONE,.18)

func _process(delta: float) -> void:
	if is_instance_valid(_undo_sale) and not _undo_sale.available(hud._state):
		_undo_sale = null
		_undo_button = null
		if _guided_close and hud.get_parent().tutorial.active and hud.get_parent().tutorial.current_id() == "winter":
			hud.close_panel(); return
		refresh()
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
