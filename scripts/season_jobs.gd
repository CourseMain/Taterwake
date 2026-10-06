extends PanelContainer
## A live Winter note. Completed work stays ticked until the next season.
const Kit = preload("res://scripts/ui_kit.gd")
const Place = preload("res://scripts/place_ui.gd")
var hud
var heading: Button
var quote_key: Label
var scroll: ScrollContainer
var lines: VBoxContainer
var sleep_button: Button
var stores_heading: Label
var stores_lines: VBoxContainer
var stores: Dictionary = {}
var jobs: Dictionary = {}
var completed: Dictionary = {}
var collapsed: bool = false
var calendar: String = ""
var signature: String = ""
var _layout_queued: bool = false

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "SeasonJobs"
	add_theme_stylebox_override("panel", Kit.skin(Kit.INK2, Kit.WOOD, 12, 14, Kit.unit(hud)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	heading = hud._button("Winter", "")
	heading.name = "CollapseWinterJobs"
	heading.pressed.connect(func(): collapsed = not collapsed; signature = ""; refresh())
	heading.set_meta("plain_control", true)
	heading.set_meta("kit_type", true)
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.set_meta("text_tier", 22)
	heading.add_theme_font_override("font", Kit.Type.face(Kit.Type.DISPLAY))
	for variant in ["normal", "hover", "pressed", "disabled"]: heading.add_theme_stylebox_override(variant, StyleBoxEmpty.new())
	for colour in ["font_color", "font_hover_color", "font_pressed_color"]: heading.add_theme_color_override(colour, Kit.CREAM)
	column.add_child(heading)
	lines = VBoxContainer.new()
	scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var contents := VBoxContainer.new(); contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(contents)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(lines)
	stores_heading = Kit.label(hud, "Stores", 22, Kit.CREAM, true); stores_heading.name = "WinterStoresHeading"; contents.add_child(stores_heading)
	quote_key = Kit.label(hud, "Store quotes · now → late Winter / t", 14, Kit.CREAM)
	quote_key.name = "WinterQuoteKey"; quote_key.clip_text = true; contents.add_child(quote_key)
	stores_lines = VBoxContainer.new(); stores_lines.name = "WinterStoresFacts"; contents.add_child(stores_lines)
	sleep_button = Kit.button(hud, "Sleep until Spring", "sleep_spring")
	sleep_button.name = "WinterSleepUntilSpring"
	sleep_button.tooltip_text = "Review stored tonnes and their late Winter value before sleeping. Stores stay unsold."
	column.add_child(sleep_button)
	minimum_size_changed.connect(_queue_layout)

func _queue_layout() -> void:
	if _layout_queued or not visible: return
	_layout_queued = true
	call_deferred("_settle_layout")

func _settle_layout() -> void:
	_layout_queued = false
	if visible: layout()

func available() -> Dictionary:
	var farm = hud._state
	var result: Dictionary = {}
	if farm.season_clock.season != 3: return result
	var iced: int = 0
	var ripe: int = 0
	for index in range(farm.plots.size()):
		if not farm.plots[index].unlocked: continue
		if farm.ClimateSystem.Operations.frozen(farm, index): iced += 1
		if farm.plots[index].crop == "icecap" and farm.plots[index].stage == 3: ripe += 1
	if iced > 0: result.ice = ["%d iced beds · Hoe →" % iced, "winter_walk:ice"]
	if ripe > 0: result.ripe = ["%d ripe Icecap beds · harvest →" % ripe, "winter_walk:ripe"]
	var coverable: int = farm.ClimateSystem.Protection.coverable_beds(farm).size()
	if coverable > 0: result.covers = ["%d cleared beds · frost covers →" % coverable, "cover_all"]
	for id in farm.climate.data.protection.pending:
		result["project:" + id] = ["%s paid · %d / 3 →" % [farm.ClimateSystem.Protection.NAMES[id], farm.climate.data.protection.pending[id]], "project_site:" + id]
	for id in farm.Diversification.NAMES:
		if farm.diversification.can_buy(farm, id): result["business:" + id] = [farm.Diversification.NAMES[id] + " · " + ("Free enrolment" if id == "grower" else farm.money(farm.Diversification.Balance.BUSINESS_COSTS[id])) + "", ""]
	return result

func store_facts() -> Dictionary:
	var farm = hud._state
	var result: Dictionary = {}
	if farm.season_clock.season != 3: return result
	var seed_available: bool = false
	for crop in farm.CROP_IDS:
		var held: int = farm.Stock.count(farm.trading.held, crop)
		if held > 0:
			var now: float = 0
			var peak: float = 0
			for grade in farm.Quality.GRADES:
				var count: int = farm.Stock.count(farm.trading.held, crop, grade)
				now += count * farm.trading.stored_price(farm, crop, grade)
				peak += count * farm.trading.peak_price(crop, grade)
			result["stores:" + crop] = ["%s · %d t · %s/t now, %s/t late Winter" % [str(farm.CropTable.CROPS[crop].name).trim_suffix(" Potato"), held, farm.market_money(now / held), farm.market_money(peak / held)], ""]
		seed_available = seed_available or preload("res://scripts/farm_advice.gd").seed_capacity(farm, crop) > 0
	if seed_available: result.seed = ["Keep some as next Spring's seed", ""]
	return result

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var farm = hud._state
	var key: String = "%d:%d" % [farm.season_clock.year, farm.season_clock.season]
	if key != calendar:
		calendar = key; jobs.clear(); completed.clear(); stores.clear(); signature = ""
	visible = farm.season_clock.season == 3 and not farm.accounts_open and not farm.run_over and not hud.farm_page_open() and hud._tutorial.is_empty()
	if not visible: return
	var next: Dictionary = available()
	for id in jobs:
		if not next.has(id): completed[id] = jobs[id]
	for id in next: completed.erase(id)
	for id in completed.keys():
		if str(id).begins_with("business:") and not farm.diversification.owns(str(id).get_slice(":", 1)): completed.erase(id)
	jobs = next
	stores = store_facts()
	var can_sleep: bool = farm.can_sleep_until_spring()
	var next_signature: String = str(jobs) + str(stores) + str(completed) + str(collapsed) + str(can_sleep)
	if next_signature != signature:
		signature = next_signature
		for container in [lines, stores_lines]:
			for child in container.get_children(): container.remove_child(child); child.queue_free()
		heading.text = "Winter · %d jobs left %s" % [jobs.size(), "+" if collapsed else "−"]
		scroll.visible = not collapsed
		sleep_button.visible = can_sleep and not collapsed
		quote_key.visible = not collapsed and stores.keys().any(func(id): return str(id).begins_with("stores:"))
		for id in jobs:
			if str(id).begins_with("business:"):
				var fact: Label = Kit.label(hud, jobs[id][0], 14, Kit.CREAM)
				fact.name = "WinterJob_" + id.replace(":", "_")
				lines.add_child(fact)
				continue
			var button: Button = hud._button(jobs[id][0], jobs[id][1])
			button.name = "WinterJob_" + id.replace(":", "_")
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_job_style(button, id)
			lines.add_child(button)
		stores_heading.text = "Stores" if stores.keys().any(func(id): return str(id).begins_with("stores:")) else "Stores · empty"
		for id in stores:
			var fact: Label = Kit.label(hud, stores[id][0], 16, Kit.INK)
			var skin := Kit.skin(Kit.PAPER, Kit.KEEPERS.mara if id == "seed" else Kit.CROPS.get(str(id).get_slice(":", 1), Kit.MONEY), 8, 10, Kit.unit(hud), false)
			skin.content_margin_left = 42 * Kit.unit(hud)
			skin.border_width_left = ceili(8 * Kit.unit(hud)); skin.border_width_top = 0; skin.border_width_right = 0; skin.border_width_bottom = 0
			fact.add_theme_stylebox_override("normal", skin)
			fact.name = "WinterStore_" + id.replace(":", "_")
			stores_lines.add_child(fact)
			var drawing: Control = hud._icon({"kind":"seed"} if id == "seed" else {"kind":"crop", "crop":str(id).get_slice(":",1)}, 26 * Kit.unit(hud))
			fact.add_child(drawing); drawing.position = Vector2(12,8) * Kit.unit(hud)
		for id in completed:
			var done: Label = Kit.label(hud, "✓ " + completion_text(str(id)), 14, Kit.CREAM)
			done.clip_text = true
			lines.add_child(done)
	layout()

func layout() -> void:
	var touch = hud.get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	var landscape: bool = phone and hud.root.size.x > hud.root.size.y
	var left: float = maxf(touch.stick.get_global_rect().end.x, touch.sell_button.get_global_rect().end.x) + 24 if landscape else (16 if phone else 28)
	var width: float = minf(560 if phone else 390, hud.root.size.x - left - (244 if landscape else 16))
	var scale: float = float(hud.get_tree().root.size.x) / hud.root.size.x
	var target: float = maxf(44, 44 / scale) if phone else 44
	for button in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = target
		button.custom_minimum_size.x = target
		button.add_theme_font_size_override("font_size", hud.text_pixels(22 if button == heading else 16))
	hud.fit_text(self)
	var top: float = hud._play_band.get_global_rect().end.y + 16
	if not landscape and hud._weather_button.visible: top = maxf(top, hud._weather_button.get_global_rect().end.y + 14)
	position = Vector2(left, top)
	var bottom: float = hud.root.size.y - 20
	if phone and not landscape:
		bottom = touch.sell_button.get_global_rect().position.y - 12
	elif not phone: bottom = hud.root.size.y - 180
	var chrome: float = get_theme_stylebox("panel").get_minimum_size().y + heading.get_combined_minimum_size().y + 4

	if sleep_button.visible: chrome += sleep_button.get_combined_minimum_size().y + 2
	# The viewport may be shorter than a job's touch target in landscape.
	# The buttons keep their full targets inside the vertically scrollable list.
	scroll.custom_minimum_size = Vector2(width - 20, minf(scroll.get_child(0).get_combined_minimum_size().y, maxf(0, bottom - top - chrome)))
	size.y = 0
	size.x = width

func completion_text(id: String) -> String:
	if id.begins_with("project:"): return hud._state.ClimateSystem.Protection.NAMES[id.get_slice(":", 1)] + " · work 3 / 3"
	if id.begins_with("business:"): return hud._state.Diversification.NAMES[id.get_slice(":", 1)] + " · ready"
	return {"ice": "Bed ice cleared", "covers": "Cleared beds covered", "ripe": "No ripe Icecap left"}.get(id, "Finished")

func _job_style(button: Button, id: String) -> void:
	button.set_meta("plain_control", true)
	button.set_meta("kit_type", true)
	button.add_theme_font_override("font", Kit.Type.face(Kit.Type.BODY))
	var accent: Color = Kit.CROPS.icecap if id == "ice" or id == "ripe" else Kit.KEEPERS.tess
	for variant in ["normal", "hover", "pressed", "disabled"]:
		var style := Kit.skin(Kit.PAPER, Kit.PAPER, 8, 10, Kit.unit(hud), false)
		style.content_margin_left = 42 * Kit.unit(hud)
		style.border_color = accent; style.border_width_left = ceili(8 * Kit.unit(hud)); style.border_width_top = 0; style.border_width_right = 0; style.border_width_bottom = 0
		button.add_theme_stylebox_override(variant, style)

	var icon: Control = hud._icon({"kind":"winter_job", "id":id}, 26 * Kit.unit(hud))
	button.add_child(icon); icon.position = Vector2(12,8) * Kit.unit(hud)
