extends Control
## A purchase cannot silently exhaust the farm's tax-debt allowance.
var card: PanelContainer
var confirm_button: Button
var cancel_button: Button
var decision: Callable

static func cost_for(game, action: String) -> float:
	var parts := action.split(":")
	var farm = game.state
	if parts.size() < 2: return -1.0
	match parts[0]:
		"buy":
			if parts.size() == 3 and farm.market.has(parts[1]): return float(farm.market[parts[1]].seed) * int(parts[2])
		"upgrade":
			if parts[1] == "barn": return 500.0 * pow(5.0, int(farm.barn_level))
			if parts[1] == "expansion": return float(farm.field_expansion_info().cost)
			if farm.TOOL_COSTS.has(parts[1]):
				var rank: int = int(farm.tools[parts[1]])
				if rank < farm.TOOL_COSTS[parts[1]].size(): return float(farm.TOOL_COSTS[parts[1]][rank])
		"climate_fund":
			if farm.ClimateSystem.PROJECTS.has(parts[1]):
				var rank: int = int(farm.climate.data.projects[str(farm.current_island)].get(parts[1], 0))
				return float(farm.BlindRules.PROGRESSION_BASELINES[2 if parts[1] == "irrigation" else farm.current_island]) * float(farm.ClimateSystem.PROJECTS[parts[1]].cost) * (rank + 1)
		"activity":
			if parts[1] == "duck": return game.activities.duck_speed_cost() if parts.size() == 3 and parts[2] == "speed" else game.activities.duck_hire_cost()
	return -1.0

func present(hud, quote: Dictionary, callback: Callable, changed: bool = false) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	decision = callback
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 180
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", hud.Cozy.box(Color("382b36"), 22, 22, Color("e58b78")))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	var screen_scale: float = maxf(0.1, hud.root.get_screen_transform().get_scale().x)
	var action_height: float = maxf(68, 44 / screen_scale) if touch else 54.0
	var blocked: bool = not quote.affordable
	column.add_child(hud._wrap("Purchase blocked" if blocked else ("Purchase changed" if changed else "Close to bankruptcy"), 26, Color("ffb5a1"), true))
	var message: String
	if blocked:
		message = str(quote.reason)
	elif not quote.near_limit:
		message = "New cost: %s\nBalance after purchase: %s" % [hud._money(float(quote.cost)), hud._money(float(quote.after_balance))]
	else:
		message = "Debt after purchase: %s\nRoom before bankruptcy: %s\nFuture taxes can push you over the limit." % [hud._money(-float(quote.after_balance)), hud._money(float(quote.credit_left_after))]
	column.add_child(hud._wrap(message, 22 if touch else 18, Color("fff1dd")))
	confirm_button = hud._button("Buy · " + hud._money(float(quote.get("cost", 0))) + (" on account" if quote.uses_credit else ""), "")
	confirm_button.set_meta("hud_action", "purchase_review:confirm")
	confirm_button.custom_minimum_size.y = action_height
	_style_button(hud, confirm_button, true)
	if touch: confirm_button.add_theme_font_size_override("font_size", 22)
	confirm_button.visible = not blocked
	confirm_button.pressed.connect(func():
		if not visible: return
		hide()
		var accept: Callable = decision
		decision = Callable()
		if accept.is_valid(): accept.call()
	)
	column.add_child(confirm_button)
	cancel_button = hud._button("Back" if blocked else "Cancel", "")
	cancel_button.set_meta("hud_action", "purchase_review:cancel")
	cancel_button.custom_minimum_size.y = action_height
	_style_button(hud, cancel_button, false)
	if touch: cancel_button.add_theme_font_size_override("font_size", 22)
	cancel_button.pressed.connect(func(): hide(); decision = Callable())
	column.add_child(cancel_button)
	if not resized.is_connected(_fit): resized.connect(_fit)
	_fit()
	show()
	move_to_front()
	cancel_button.grab_focus()

func _style_button(hud, button: Button, accept: bool) -> void:
	var base := Color("ecb78b") if accept else Color("51424f")
	var ink := Color("30252a") if accept else Color("fff1dd")
	button.add_theme_font_size_override("font_size", 18)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, hud.Cozy.box(base.lightened(0.08) if state == "hover" else base, 12, 12))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_stylebox_override("focus", hud.Cozy.box(Color.TRANSPARENT, 12, 12, Color("ffb5a1")))

func _fit() -> void:
	if is_instance_valid(card): card.custom_minimum_size.x = maxf(240, minf(470, size.x - 32))

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		decision = Callable()
		get_viewport().set_input_as_handled()
