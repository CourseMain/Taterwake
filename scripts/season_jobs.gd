extends PanelContainer
## A live Winter note. Completed work stays ticked until the next season.
const Place = preload("res://scripts/place_ui.gd")
var hud
var heading: Button
var quote_key: Label
var scroll: ScrollContainer
var lines: VBoxContainer
var sleep_button: Button
var jobs: Dictionary = {}
var completed: Dictionary = {}
var collapsed: bool = false
var calendar: String = ""
var signature: String = ""

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "SeasonJobs"
	add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 10, 8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	heading = hud._button("Winter", "")
	heading.name = "CollapseWinterJobs"
	heading.pressed.connect(func(): collapsed = not collapsed; signature = ""; refresh())
	Place.pill(heading, Place.INK)
	column.add_child(heading)
	quote_key = hud._label("Store quotes · now → late Winter / t", 12, Place.MUTED)
	quote_key.name = "WinterQuoteKey"
	quote_key.clip_text = true
	column.add_child(quote_key)
	lines = VBoxContainer.new()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	sleep_button = hud._button("Sleep until Spring", "sleep_spring", true)
	sleep_button.name = "WinterSleepUntilSpring"
	sleep_button.tooltip_text = "Review stored tonnes and their late Winter value before sleeping. Stores stay unsold."
	column.add_child(sleep_button)
	var pin := preload("res://scripts/paper_detail.gd").new()
	pin.kind = "pin"
	add_child(pin)
	pin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func available() -> Dictionary:
	var farm = hud._state
	var result: Dictionary = {}
	if farm.season_clock.season != 3: return result
	if farm.climate.data.phase == "warning" and farm.climate.data.event == "blizzard":
		result.blizzard = ["Blizzard in %ds · sell / harvest →" % ceili(farm.climate.data.timer), "climate"]
	var iced: int = 0
	var ripe: int = 0
	var seeds: int = 0
	for index in range(farm.plots.size()):
		if not farm.plots[index].unlocked: continue
		if farm.ClimateSystem.Operations.frozen(farm, index): iced += 1
		if farm.plots[index].crop == "icecap" and farm.plots[index].stage == 3: ripe += 1
	if iced > 0: result.ice = ["%d iced beds · Hoe →" % iced, "winter_walk:ice"]
	for crop in farm.CROP_IDS:
		var held: int = farm.Stock.count(farm.trading.held, crop)
		if held > 0:
			# Quote the actual grades in this pile, rather than implying Standard prices.
			var now: float = 0
			var peak: float = 0
			for grade in farm.Quality.GRADES:
				var count: int = farm.Stock.count(farm.trading.held, crop, grade)
				now += count * farm.trading.stored_price(farm, crop, grade)
				peak += count * farm.trading.peak_price(crop, grade)
			result["stores:" + crop] = ["%s %d t · %s → %s/t" % [str(farm.CropTable.CROPS[crop].name).trim_suffix(" Potato"), held, farm.market_money(now / held), farm.market_money(peak / held)], "sell_potatoes"]
		var seed_space: int = farm.MAX_INVENTORY - int(farm.seed_inventory[crop]) - int(farm.trading.kept_seed[crop])
		var eligible: int = farm.stock_count(crop, "Table") + farm.stock_count(crop, "Standard")
		seeds += mini(maxi(0, seed_space), eligible)
	for id in farm.climate.data.protection.pending:
		result["project:" + id] = ["%s paid · %d / 3 →" % [farm.ClimateSystem.Protection.NAMES[id], farm.climate.data.protection.pending[id]], "project_site:" + id]
	var coverable: int = farm.ClimateSystem.Protection.coverable_beds(farm).size()
	if coverable > 0: result.covers = ["%d cleared beds · frost covers →" % coverable, "cover_all"]
	if ripe > 0: result.ripe = ["%d ripe Icecap beds · harvest →" % ripe, "winter_walk:ripe"]
	if seeds > 0: result.seed = ["%d t · keep as seed →" % seeds, "winter_seeds"]
	for id in farm.Diversification.NAMES:
		if farm.diversification.can_buy(farm, id): result["business:" + id] = [farm.Diversification.NAMES[id] + " · " + ("Free enrolment" if id == "grower" else farm.money(farm.Diversification.Balance.BUSINESS_COSTS[id])) + " →", "businesses"]
	return result

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var farm = hud._state
	var key: String = "%d:%d" % [farm.season_clock.year, farm.season_clock.season]
	if key != calendar:
		calendar = key; jobs.clear(); completed.clear(); signature = ""
	visible = farm.season_clock.season == 3 and not farm.accounts_open and not farm.run_over and not hud.is_panel_open() and hud._tutorial.is_empty()
	if not visible: return
	var next: Dictionary = available()
	if next.has("blizzard") and is_instance_valid(hud._climate_alert):
		# This note owns the live warning; a second banner would cover its header.
		hud._climate_alert.dismiss()
	for id in jobs:
		if not next.has(id): completed[id] = jobs[id]
	for id in next: completed.erase(id)
	for id in completed.keys():
		if str(id).begins_with("business:") and not farm.diversification.owns(str(id).get_slice(":", 1)): completed.erase(id)
	jobs = next
	var can_sleep: bool = farm.can_sleep_until_spring()
	var next_signature: String = str(jobs) + str(completed) + str(collapsed) + str(can_sleep)
	if next_signature != signature:
		signature = next_signature
		for child in lines.get_children(): lines.remove_child(child); child.queue_free()
		heading.text = "Winter · %d jobs left %s" % [jobs.size(), "+" if collapsed else "−"]
		scroll.visible = not collapsed
		sleep_button.visible = can_sleep and not collapsed
		quote_key.visible = not collapsed and jobs.keys().any(func(id): return str(id).begins_with("stores:"))
		for id in jobs:
			var button: Button = hud._button(jobs[id][0], jobs[id][1])
			button.name = "WinterJob_" + id.replace(":", "_")
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.clip_text = true
			button.tooltip_text = jobs[id][0]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_override("font", hud._plain_font)
			Place.pill(button, Place.INK)
			if id == "blizzard": button.add_theme_color_override("font_color", Color("a63529"))
			lines.add_child(button)
		for id in completed:
			var done: Label = hud._label("✓ " + completion_text(str(id)), 13, hud.MUTED)
			done.clip_text = true
			lines.add_child(done)
	layout()

func layout() -> void:
	var touch = hud.get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	var landscape: bool = phone and hud.root.size.x > hud.root.size.y
	var left: float = touch.stick.get_global_rect().end.x + 24 if landscape else (16 if phone else 28)
	var width: float = minf(560 if phone else 390, hud.root.size.x - left - (244 if landscape else 16))
	var scale: float = float(hud.get_tree().root.size.x) / hud.root.size.x
	var target: float = maxf(44, 44 / scale) if phone else 44
	for button in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = target
		button.custom_minimum_size.x = target
		var pixels: int = 20 if phone else 14
		var available_width: float = width - 20 - button.get_theme_stylebox("normal").get_minimum_size().x - 14
		var font: Font = button.get_theme_font("font")
		while pixels > 14 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > available_width: pixels -= 1
		button.add_theme_font_size_override("font_size", pixels)
	var key_pixels: int = 18 if phone else 12
	while key_pixels > 12 and quote_key.get_theme_font("font").get_string_size(quote_key.text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_pixels).x > width - 20: key_pixels -= 1
	quote_key.add_theme_font_size_override("font_size", key_pixels)
	for label in lines.find_children("*", "Label", true, false): label.add_theme_font_size_override("font_size", 20 if phone else 13)
	var top: float = 208 if phone else 154
	if phone and is_instance_valid(touch.status) and touch.status.visible:
		top = maxf(top, touch.status.get_global_rect().end.y + 14)
	position = Vector2(left, top)
	var bottom: float = hud.root.size.y - 20
	if phone and not landscape:
		bottom = touch.stick.get_global_rect().position.y - 12
		var hurry = touch.get("hurry_button")
		if is_instance_valid(hurry): bottom = minf(bottom, hurry.get_global_rect().position.y - 12)
	elif not phone: bottom = hud.root.size.y - 180
	var chrome: float = get_theme_stylebox("panel").get_minimum_size().y + heading.get_combined_minimum_size().y + 4
	if quote_key.visible: chrome += quote_key.get_combined_minimum_size().y + 2
	if sleep_button.visible: chrome += sleep_button.get_combined_minimum_size().y + 2
	scroll.custom_minimum_size = Vector2(width - 20, minf(lines.get_combined_minimum_size().y, maxf(target, bottom - top - chrome)))
	size.y = 0
	size.x = width

func completion_text(id: String) -> String:
	if id.begins_with("project:"): return hud._state.ClimateSystem.Protection.NAMES[id.get_slice(":", 1)] + " · work 3 / 3"
	if id.begins_with("business:"): return hud._state.Diversification.NAMES[id.get_slice(":", 1)] + " · ready"
	if id.begins_with("stores:"): return hud._crop_name(id.get_slice(":", 1)) + " · no stores left"
	return {"ice": "Bed ice cleared", "covers": "Cleared beds covered", "ripe": "No ripe Icecap left", "seed": "Seed selection finished", "blizzard": "Blizzard warning ended"}.get(id, "Finished")
