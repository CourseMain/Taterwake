extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const ACCENT := Color("a17c42")
static func build(hud) -> void:
	Place.header(hud, hud._body, "BUYER BOARD", ACCENT)
	var help_row := HBoxContainer.new(); hud._body.add_child(help_row)
	Place.help(hud, help_row, "Accepting an order is binding. The buyer collects Standard or Table tonnes at Autumn end, before Winter storage. Feed cannot fulfil an order. Each missing tonne costs %s." % hud._state.money(hud._state.MarketDecisions.SHORTFALL_FEE))
	for slot in range(hud._state.trading.order_limit(hud._state)):
		var suffix: String = "" if slot == 0 else ":%d" % slot
		var slip := PanelContainer.new(); slip.name = "BuyerOrderSlip%d" % slot
		slip.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 22, 7)); hud._body.add_child(slip)
		var body: VBoxContainer = hud._vbox(10); slip.add_child(body)
		var order: Dictionary = hud._state.trading.offer(hud._state.season_clock.year, slot, hud._state.trading.grower_active(hud._state))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); body.add_child(row)
		row.add_child(hud._icon({"kind":"crop", "crop":order.crop}, 84))
		hud._refs["contract_details" + suffix] = hud._wrap("", 32, Place.INK, true); row.add_child(hud._refs["contract_details" + suffix])
		hud._refs["contract_price" + suffix] = hud._wrap("", 27, Place.INK, true); body.add_child(hud._refs["contract_price" + suffix])
		body.add_child(hud._wrap("DUE AUTUMN END", 15, Place.MUTED))
		hud._refs["contract_status" + suffix] = hud._wrap("", 15, Place.INK); body.add_child(hud._refs["contract_status" + suffix])
		body.add_child(hud._wrap("Missing tonne penalty · " + hud._state.money(hud._state.MarketDecisions.SHORTFALL_FEE), 13, Place.MUTED))
		var stamp: Button = hud._button("ACCEPT ORDER", "contract_accept:%d" % slot, true)
		stamp.custom_minimum_size.x = 230; stamp.autowrap_mode = TextServer.AUTOWRAP_OFF
		stamp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; Place.pill(stamp, ACCENT, true)
		body.add_child(stamp); hud._refs["contract_accept" + suffix] = stamp
		var pin = preload("res://scripts/paper_detail.gd").new(); pin.kind = "pin"; slip.add_child(pin); pin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh(hud)
static func refresh(hud) -> void:
	var trade = hud._state.trading; var year: int = hud._state.season_clock.year
	for slot in range(trade.order_limit(hud._state)):
		var suffix: String = "" if slot == 0 else ":%d" % slot
		var active: Dictionary = trade.active_order(slot); var completed: Dictionary = trade.completed_order(year, slot)
		var order: Dictionary = active if not active.is_empty() else trade.offer(year, slot, trade.grower_active(hud._state))
		hud._refs["contract_details" + suffix].text = "%d t %s" % [order.quantity, hud._crop_name(order.crop)]
		hud._refs["contract_price" + suffix].text = hud._state.market_money(order.price) + " / t"
		var status: String = ""
		if not completed.is_empty():
			if completed.delivered > 0: status = "%d t collected" % completed.delivered
			if completed.shortfall > 0: status += (" · " if not status.is_empty() else "") + "Penalty " + hud._state.money(completed.shortfall * hud._state.MarketDecisions.SHORTFALL_FEE)
		elif not active.is_empty(): status = "Accepted" + (" · %d t ready" % trade.eligible_contract(hud._state, order.crop) if trade.eligible_contract(hud._state, order.crop) > 0 else "")
		elif hud._state.season_clock.season != 0: status = "Next offer in Spring"
		hud._refs["contract_status" + suffix].text = status; hud._refs["contract_status" + suffix].visible = not status.is_empty()
		hud._refs["contract_accept" + suffix].disabled = hud._state.run_over or hud._state.season_clock.season != 0 or not active.is_empty() or not completed.is_empty()
		hud._refs["contract_accept" + suffix].text = "ACCEPTED" if not active.is_empty() else "ACCEPT ORDER"
