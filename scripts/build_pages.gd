extends RefCounted
const Art = preload("res://scripts/build_illustration.gd")
const Type = preload("res://scripts/ui_type.gd")
const PAPER := Color("eee5ce")
const INK := Color("30463a")
const ORDER: Array[String] = ["farmer", "industrialist", "scientist", "investor", "gambler"]
const ACCENTS: Dictionary = {"farmer": Color("42976d"), "industrialist": Color("d47a45"), "scientist": Color("6c79c7"), "investor": Color("238b92"), "gambler": Color("a568ab")}
const BENEFITS: Dictionary = {
	"farmer": "+5% yield per level. Faster growth from level 2; wider tools at 3, 10 and 20. +1 compost per harvested patch (max 99).",
	"industrialist": "Grades: F (1.05× sale value) to SSS (8×). Faster processing each level; better machine grades at 3, 10 and 20. Extra queue slots at 10 and 20.",
	"scientist": "Honeyheart: +50% yield. Sundew: half drought stress. Frostgold: ordinary frost immunity.",
	"investor": "Quotes start 20% above market. Each delivery adds 3 percentage points, up to 50%. Active bonus: more positive market events.",
	"gambler": "Odds: 20% triple, 55% unchanged, 25% half. Table cooldown: 30s. Charm recharge: 180s.",
}
const TRADEOFFS: Dictionary = {
	"farmer": "Compost: once per crop, before ripe; frozen crops must be thawed. The 3× harvest stays after switching builds; active bonuses do not.",
	"industrialist": "Loaded crops occupy barn space until sold. Payout follows the market while processing.",
	"scientist": "Both ingredients are consumed. Traits apply to future plantings and stay unlocked after switching.",
	"investor": "The locked quote cannot rise. Expired offers pay nothing; crops stay in your barn. Switching builds keeps the deadline running.",
	"gambler": "Staked crops are consumed. Half-value results lose half the stake. Charms can lower the payout. Pending results remain claimable after switching.",
}
const UNLOCK_NOTE: String = "Choose any build. Farming activities earn its levels."
const PURPOSE: Dictionary = {
	"farmer": "3× harvest · 1 compost",
	"industrialist": "Grade crops for higher prices",
	"scientist": "Discover planting traits",
	"investor": "Reserve a buyer's price",
	"gambler": "Stake crops for Spudion payouts",
}
const ACTION_TITLE: Dictionary = {"farmer": "Compost · Farmer perk", "industrialist": "Grade a batch", "scientist": "Discover a variety", "investor": "Reserve a buyer", "gambler": "Stake a harvest"}

static func create(h) -> void:
	var system = h._build_system()
	if system == null: return
	var id: String = h._build_selection
	if id.is_empty():
		create_overview(h, system)
		return
	h._heading(id.capitalize(), "")
	_notebook(h, ACCENTS[id])
	var height: float = 552.0 if id == "farmer" else (634.0 if id == "scientist" else 600.0)
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5
	var nav = h._hbox(10)
	h._body.add_child(nav)
	nav.add_child(h._button("‹ All builds", "build:inspect:"))
	_progress(h, nav, id)
	var equip = h._button("Select build", "build:select:" + id, true)
	nav.add_child(equip)
	h._refs.build_equip = equip
	var selection_note = h._wrap("", 12, INK)
	h._body.add_child(selection_note)
	h._refs.build_selection_note = selection_note
	var art = Art.new()
	art.kind = id
	art.compact_layout = _touch(h)
	art.custom_minimum_size = Vector2(0, 82 if _touch(h) else 108)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h._body.add_child(art)
	h._refs.build_art = art
	var card = _folio(h, ACCENTS[id])
	h._body.add_child(card)
	var body = h._vbox(6 if id == "scientist" else 8)
	if id == "scientist":
		var skin: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		skin.content_margin_top = 10
		skin.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", skin)
	card.add_child(body)
	var title = h._wrap(ACTION_TITLE[id], 19, h.INK, true)
	body.add_child(title)
	h._refs.prof_title = title
	var resource = h._wrap("", 14, h.INK)
	body.add_child(resource)
	h._refs.prof_resource = resource
	var inputs = h._vbox(8)
	inputs.visible = id != "farmer"
	body.add_child(inputs)
	h._refs.prof_inputs = inputs
	var row = h._hbox(10)
	inputs.add_child(row)
	if id in ["industrialist", "investor", "gambler"]:
		var entries: Array = []
		for crop in system.state.available_crops(): entries.append([crop, crop.capitalize()])
		choice(h, row, "crop", "Crop", entries)
	match id:
		"industrialist":
			choice(h, row, "batch", "Batch size", [["20", "20 crops"], ["100", "100 crops"]])
			choice(h, row, "method", "Process", [["polish", "Polish"], ["cure", "Cure"]])
		"scientist":
			choice(h, row, "recipe", "Cross to discover", [["hearty", "Honeyheart"], ["dry", "Sundew"], ["frost", "Frostgold"]])
		"gambler":
			choice(h, row, "stake_size", "Crops to stake", [["5", "5 crops"], ["20", "20 crops"], ["100", "100 crops"]])
	var status = h._wrap("", 13, h.MUTED)
	body.add_child(status)
	h._refs.prof_status = status
	var actions = h._hbox(8)
	body.add_child(actions)
	match id:
		"farmer":
			add_action(h, actions, "Grow giant · 1 compost → 3× harvest", "giant")
			var prepare = h._button("Plant a crop", "close")
			prepare.set_meta("tool", "plant")
			prepare.pressed.connect(func(): h.action_requested.emit("tool:" + str(prepare.get_meta("tool"))))
			body.add_child(prepare)
			h._refs.prof_prepare = prepare
		"industrialist":
			add_action(h, actions, "Load batch", "load")
			add_action(h, actions, "Sell graded harvest", "sell", false)
			var job = h._wrap("", 13, h.MUTED)
			body.add_child(job)
			h._refs.prof_job = job
			var meter = h._meter(h.GOLD)
			meter.custom_minimum_size.y = 6
			meter.max_value = 1.0
			body.add_child(meter)
			h._refs.prof_progress = meter
		"scientist":
			add_action(h, actions, "Crossbreed · 10 + 10 crops", "breed")
			var bank = h._hbox(10)
			body.add_child(bank)
			choice(h, bank, "variety", "Trait for future plantings", [["", "Ordinary crops"], ["hearty", "Honeyheart · larger harvest"], ["dry", "Sundew · drought tolerant"], ["frost", "Frostgold · frost hardy"]])
		"investor":
			add_action(h, actions, "Reserve price", "reserve")
			add_action(h, actions, "Deliver crops", "deliver")
		"gambler":
			add_action(h, actions, "Stake harvest", "stake")
			add_action(h, actions, "Claim payout", "claim")
			add_action(h, actions, "Replace result · 1 charm", "reroll", false)
			var note = h._wrap("", 12, h.MUTED)
			body.add_child(note)
			h._refs.prof_note = note
	var details = h._details_section("build_details", "details")
	h._refs.build_details.add_theme_stylebox_override("panel", _paper_skin(ACCENTS[id]))
	for entry in [["Bonuses", BENEFITS[id]], ["Limits", TRADEOFFS[id]]]:
		details.add_child(_display(h, entry[0], 17, h.INK))
		details.add_child(h._wrap(entry[1], 13, h.MUTED))
	var label = h._wrap("", 13, h.MUTED)
	details.add_child(label)
	h._refs.prof_details = label
	refresh(h)
	_fit_height(h, id)
	h._refs["build_details:toggle"].pressed.connect(func(): _fit_height(h, id))

static func _display(h, text: String, size: int, color: Color) -> Label:
	var label: Label = h._wrap(text, size, color, true)
	var font = Type.face(Type.DISPLAY, 600)
	font.fallbacks = [Type.SPUDION]
	label.add_theme_font_override("font", font)
	label.add_theme_constant_override("outline_size", 0)
	return label

static func _progress(h, parent: Control, id: String) -> void:
	var column = h._vbox(3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(column)
	h._refs["build_xp_box:" + id] = column
	var caption = h._wrap("", 13, INK, true)
	column.add_child(caption)
	h._refs["build_xp:" + id] = caption
	var meter = h._meter(ACCENTS[id])
	meter.custom_minimum_size.y = 6
	column.add_child(meter)
	h._refs["build_xp_meter:" + id] = meter
	_refresh_progress(h, id)

static func _refresh_progress(h, id: String) -> void:
	if not h._refs.has("build_xp:" + id): return
	var info: Dictionary = h._build_system().progression(id)
	h._refs["build_xp_box:" + id].visible = info.level > 0
	h._refs["build_xp:" + id].text = "Lv.%d · MAX" % info.level if info.maxed else "Lv.%d · %d / %d XP" % [info.level, info.xp, info.required]
	h._refs["build_xp:" + id].tooltip_text = info.source
	var meter: ProgressBar = h._refs["build_xp_meter:" + id]
	meter.max_value = maxi(1, int(info.required))
	meter.value = meter.max_value if info.maxed else info.xp

static func _compact_type(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		var font: Font = node.get_theme_font("font").duplicate()
		font.fallbacks = [Type.SPUDION]
		node.add_theme_font_override("font", font)
	for child in node.get_children(): _compact_type(child)

static func _finish_type(h) -> void:
	# The shared HUD applies its type pass after this page is created.
	var page: String = h._panel_kind
	var inspected: String = h._build_selection
	await h.get_tree().process_frame
	if not is_instance_valid(h) or h._panel_kind != page or h._build_selection != inspected: return
	_compact_type(h._body)
	_compact_type(h._modal_title)
	_compact_type(h._modal_subtitle)

static func _overview_size(h) -> void:
	var width: float = minf(980, h.root.size.x - 48)
	var height: float = minf(710, h.root.size.y - 48)
	h._modal_card.offset_left = -width * 0.5
	h._modal_card.offset_right = width * 0.5
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5

static func _touch(h) -> bool:
	var touch = h.get_parent().get("touch_controls")
	return is_instance_valid(touch) and touch.enabled

static func _paper_skin(accent: Color, selected: bool = false) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("f6efdc") if selected else Color("eee5ce")
	skin.border_color = accent.darkened(0.1) if selected else Color("b3b199")
	skin.border_width_left = 4 if selected else 1
	skin.border_width_bottom = 1
	skin.set_corner_radius_all(2)
	skin.content_margin_left = 12
	skin.content_margin_right = 10
	skin.content_margin_top = 8
	skin.content_margin_bottom = 10
	return skin

static func _folio(h, accent: Color, selected: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _paper_skin(accent, selected))
	return panel

static func _notebook(h, accent: Color = INK) -> void:
	var skin: StyleBoxFlat = h._modal_card.get_theme_stylebox("panel").duplicate()
	skin.bg_color = PAPER
	skin.border_color = Color("647056")
	skin.set_border_width_all(2)
	skin.border_width_left = 10
	skin.border_width_bottom = 5
	skin.set_corner_radius_all(5)
	skin.shadow_color = Color("172a20", 0.3)
	skin.shadow_size = 12
	h._modal_card.add_theme_stylebox_override("panel", skin)
	h._modal_title.add_theme_color_override("font_color", INK)
	h._modal_subtitle.add_theme_color_override("font_color", accent.darkened(0.25))

static func create_overview(h, system) -> void:
	h._heading("Builds", "")
	_notebook(h)
	_overview_size(h)
	var intro = h._hbox(12)
	h._body.add_child(intro)
	var selected = h._badge("Selected · " + system.active.capitalize(), "active")
	selected.add_theme_font_size_override("font_size", 14)
	intro.add_child(selected)
	h._refs.build_selected_summary = selected
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(spacer)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	h._body.add_child(grid)
	h._refs.build_overview = grid
	grid.resized.connect(func():
		var columns: int = 2 if grid.size.x >= 620 else 1
		if grid.columns != columns: grid.columns = columns)
	var entries: Dictionary = {}
	for entry in system.build_info(): entries[entry.id] = entry
	for id in ORDER:
		var entry: Dictionary = entries[id]
		var accent: Color = ACCENTS[id]
		var card = _folio(h, accent, entry.active)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		h._refs["build_card:" + id] = card
		var hero := HBoxContainer.new()
		hero.add_theme_constant_override("separation", 10)
		card.add_child(hero)
		var sketch = h._vbox(1)
		hero.add_child(sketch)
		var picture = Art.new()
		picture.kind = id
		picture.specimen = true
		picture.custom_minimum_size = Vector2(110, 105) if _touch(h) else Vector2(86, 82)
		sketch.add_child(picture)
		h._refs["build_preview:" + id] = picture
		var title = h._vbox(4)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero.add_child(title)
		var heading = h._hbox(8)
		title.add_child(heading)
		var name_label = _display(h, entry.name, 23, INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		var badge = h._badge("Selected" if entry.active else ("Lv.%d · Ready" % entry.level if entry.unlocked else "Locked"), "active" if entry.active else ("ready" if entry.unlocked else "locked"))
		title.add_child(badge)
		h._refs["build_status:" + id] = badge
		var effect = h._wrap(PURPOSE[id], 13, INK)
		title.add_child(effect)
		_progress(h, title, id)
		var explore = h._button("Open" if entry.unlocked else "Preview", "build:inspect:" + id, entry.active)
		title.add_child(explore)
		h._refs["build_explore:" + id] = explore
	_fit_height(h, "")

static func _fit_height(h, id: String) -> void:
	_finish_type(h)
	var touch = h.get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		touch.fit_modal()
		await h.get_tree().process_frame
		await h.get_tree().process_frame
		if is_instance_valid(h) and h._panel_kind == "builds" and h._build_selection == id:
			touch.fit_modal()
		return
	# Measure once after layout, and when the optional drawer changes. Live
	# resource refreshes must not move a button under the pointer.
	await h.get_tree().process_frame
	if not is_instance_valid(h): return
	await h.get_tree().process_frame
	if not is_instance_valid(h): return
	if h._panel_kind != "builds" or h._build_selection != id: return
	var height: float = content_height(h)
	if id == "industrialist" and not h._refs.prof_job.visible:
		# Reserve the later job label, meter and their gaps before the first load.
		# Starting a batch must not resize the modal or hide the details toggle.
		var job: Label = h._refs.prof_job
		height += job.get_theme_font("font").get_height(job.get_theme_font_size("font_size"))
		height += h._refs.prof_progress.get_combined_minimum_size().y
		height += 2 * job.get_parent().get_theme_constant("separation")
	height = clampf(height, 360, 634)
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5

static func content_height(h) -> float:
	var column: VBoxContainer = h._modal_card.get_child(0)
	var extra: float = h._modal_card.get_theme_stylebox("panel").get_minimum_size().y
	var visible_children: int = 0
	for child in column.get_children():
		if not child is Control or not child.visible: continue
		visible_children += 1
		if child != h._body.get_parent(): extra += child.get_combined_minimum_size().y
	extra += maxf(0, visible_children - 1) * column.get_theme_constant("separation")
	return h._body.get_combined_minimum_size().y + extra

static func add_action(h, row, title: String, action: String, primary: bool = true) -> void:
	var button = h._button(title, "profession:" + action, primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	h._refs["prof_" + action] = button

static func choice(h, row, key: String, caption: String, entries: Array) -> void:
	var field = h._vbox(3)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	field.add_child(h._label(caption, 12, h.MUTED, true))
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.custom_minimum_size = Vector2(100, 38)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h._style_choice(option)
	for entry in entries:
		option.add_item(entry[1])
		option.set_item_metadata(option.item_count - 1, entry[0])
	option.item_selected.connect(func(index): h.action_requested.emit("crop:" + str(option.get_item_metadata(index)) if key == "crop" else "profession:%s:%s" % [key, option.get_item_metadata(index)]))
	field.add_child(option)
	h._refs["prof_" + key] = option

static func _readiness(h, p, verb: String) -> Dictionary:
	var info: Dictionary = p.readiness(verb)
	if h._refs.has("prof_" + verb):
		h._refs["prof_" + verb].disabled = not bool(info.ready)
		h._refs["prof_" + verb].tooltip_text = str(info.reason)
	return info

static func refresh(h) -> void:
	var b = h._build_system()
	if b == null: return
	for build_id in ORDER: _refresh_progress(h, build_id)
	if not h._refs.has("prof_status"): return
	var p = b.professions
	var d: Dictionary = p.data
	var farm = b.state
	var id: String = h._build_selection
	var equipped: bool = b.active == id
	var unlocked: bool = int(b.levels[id]) > 0
	h._refs.build_equip.text = "Selected · Lv.%d" % b.levels[id] if equipped else ("Select build · Free" if unlocked else "Unavailable")
	h._refs.build_selection_note.visible = not unlocked or int(b.levels[id]) < b.MAX_LEVEL
	h._refs.build_selection_note.text = UNLOCK_NOTE if not unlocked else str(b.XP_SOURCES[id])
	h._refs.build_equip.tooltip_text = "Replaces %s bonuses" % b.active.capitalize() if unlocked and not equipped else ""
	h._refs.build_equip.disabled = equipped or not unlocked
	h._refs.build_art.grade = str(d.last_grade) if d.last_grade != "" else p.grade_preview().grade
	h._refs.build_art.grade_caption = "Last stamped batch" if d.last_grade != "" else "Expected grade"
	h._refs.build_art.reward_text = "?" if d.wager.is_empty() else str(d.wager.factor) + "×"
	h._refs.build_art.motion = not b.processing.is_empty() if id == "industrialist" else equipped
	if h._refs.build_art.result_serial != p.event_serial:
		h._refs.build_art.result_serial = p.event_serial
		if p.event.get("kind", "") == "industrialist" and str(p.event.get("title", "")).ends_with("batch ready"):
			h._refs.build_art.stamp_left = 1.0
	for key in ["method", "batch", "recipe", "variety", "stake_size", "crop"]:
		if not h._refs.has("prof_" + key): continue
		var option: OptionButton = h._refs["prof_" + key]
		var value: String = farm.selected_crop if key == "crop" else str(d[{"batch": "batch_size", "stake_size": "stake"}.get(key, key)])
		for i in range(option.item_count):
			if str(option.get_item_metadata(i)) == value:
				option.select(i)
				option.tooltip_text = option.get_item_text(i)
			if key == "variety": option.set_item_disabled(i, i > 0 and option.get_item_metadata(i) not in d.seedbank)
	var ready: Dictionary = {}
	var status: String = ""
	match id:
		"farmer":
			ready = _readiness(h, p, "giant")
			var growing: Dictionary = p.cultivation_info()
			h._refs.prof_resource.text = "%d compost available · %d growing crop%s ready" % [d.compost, growing.eligible.size(), "" if growing.eligible.size() == 1 else "s"]
			status = "" if ready.ready else str(ready.reason)
			var ripe: bool = false
			var frozen: bool = false
			var empty: bool = false
			for plot in farm.plots:
				if not plot.unlocked: continue
				ripe = ripe or (int(plot.stage) == 3 and not bool(plot.get("frozen", false)))
				frozen = frozen or (int(plot.stage) in [1, 2] and bool(plot.get("frozen", false)))
				empty = empty or int(plot.stage) == 0
			h._refs.prof_prepare.visible = equipped and not ready.ready and (ripe or (growing.eligible.is_empty() and d.compost > 0 and (frozen or empty)))
			if h._refs.prof_prepare.visible:
				var tool: String = "harvest" if ripe else ("hoe" if frozen else "plant")
				h._refs.prof_prepare.set_meta("tool", tool)
				h._refs.prof_prepare.text = {"harvest": "Harvest ripe crops", "hoe": "Thaw a crop", "plant": "Plant a crop"}[tool]
				if growing.eligible.is_empty() and d.compost > 0:
					if ripe: status = "Plant a new crop before adding compost."
					elif frozen: status = "Thaw with your hoe before adding compost."
			elif equipped and growing.eligible.is_empty() and d.compost > 0:
				status = "All growing crops already have compost."
		"industrialist":
			ready = _readiness(h, p, "load")
			var preview: Dictionary = p.grade_preview()
			var held: int = int(farm.storage[farm.selected_crop])
			h._refs.prof_resource.text = "Next batch: grade %s · %s× sale value · %d / %d %s in barn" % [preview.grade, String.num(preview.multiplier, 2), mini(held, int(d.batch_size)), d.batch_size, farm.selected_crop.capitalize()]
			status = ("Matched process · " + ("fresh" if preview.fresh else "stored")) if preview.fit else "Better grade with %s" % str(preview.desired).capitalize()
			if not ready.ready: status = str(ready.reason)
			h._refs.prof_load.text = "Load %d %s" % [d.batch_size, farm.selected_crop.capitalize()]
			h._refs.prof_sell.text = "Sell graded · " + farm.money(b.processed_value())
			h._refs.prof_sell.disabled = b.processed_value() <= 0
			h._refs.prof_sell.visible = b.processed_value() > 0
			h._refs.prof_progress.visible = not b.processing.is_empty()
			h._refs.prof_progress.value = b.activity_info().progress
			h._refs.prof_job.visible = not b.processing.is_empty()
			if not b.processing.is_empty():
				h._refs.prof_job.text = "Processing %d %s · grade %s · %ds left%s" % [b.processing.quantity, str(b.processing.crop).capitalize(), str(b.processing.get("grade", "Legacy")), ceili(float(b.processing.duration) - float(b.processing.elapsed)), " · %d queued" % d.queue.size() if not d.queue.is_empty() else ""]
		"scientist":
			ready = _readiness(h, p, "breed")
			var recipe: Dictionary = p.RECIPES[d.recipe]
			h._refs.prof_title.text = "%s · %s" % [recipe.name, recipe.trait]
			h._refs.prof_resource.text = "10 %s + 10 %s" % [str(recipe.a).capitalize(), str(recipe.b).capitalize()]
			status = "%d / 10 %s · %d / 10 %s in barn" % [mini(10, int(farm.storage[recipe.a])), str(recipe.a).capitalize(), mini(10, int(farm.storage[recipe.b])), str(recipe.b).capitalize()] if ready.ready else str(ready.reason)
			h._refs.prof_breed.text = "Already discovered" if d.recipe in d.seedbank else "Crossbreed · 10 + 10 crops"
			if d.recipe in d.seedbank: status = ""
		"investor":
			var contract: Dictionary = d.contract
			var active: bool = not contract.is_empty()
			h._refs.prof_title.text = "Your reserved buyer" if active else ACTION_TITLE[id]
			h._refs.prof_inputs.visible = not active
			h._refs.prof_reserve.visible = not active
			h._refs.prof_deliver.visible = active
			_readiness(h, p, "reserve")
			_readiness(h, p, "deliver")
			ready = p.readiness("deliver" if active else "reserve")
			if active:
				h._refs.prof_resource.text = "%d %s · %s locked payout · %ds left" % [contract.quantity, str(contract.crop).capitalize(), farm.money(contract.quantity * contract.quote), ceili(contract.remaining)]
				status = "%d / %d crops · deliver from Island %d" % [mini(int(contract.quantity), int(farm.storage[contract.crop])), contract.quantity, contract.island] if ready.ready else str(ready.reason)
				h._refs.prof_deliver.text = "Deliver %d %s · %s" % [contract.quantity, str(contract.crop).capitalize(), farm.money(contract.quantity * contract.quote)]
			else:
				var quote: Dictionary = p.contract_preview()
				h._refs.prof_resource.text = "%d %s · %s locked payout" % [quote.quantity, str(quote.crop).capitalize(), farm.money(quote.total)]
				status = "Free reservation · deliver here within 3 minutes" if ready.ready else str(ready.reason)
		"gambler":
			var active: bool = not d.wager.is_empty()
			h._refs.prof_title.text = "Your harvest stake result" if active else ACTION_TITLE[id]
			h._refs.prof_inputs.visible = not active
			h._refs.prof_stake.visible = not active
			h._refs.prof_claim.visible = active
			h._refs.prof_reroll.visible = active
			for verb in ["stake", "claim", "reroll"]: _readiness(h, p, verb)
			ready = p.readiness("claim" if active else "stake")
			if active:
				var payout: String = farm.money(d.wager.quantity * d.wager.quote * d.wager.factor)
				h._refs.prof_resource.text = "%s× result · %s ready to claim" % [d.wager.factor, payout]
				h._refs.prof_claim.text = "Claim " + payout
				status = "Staked: %d %s" % [d.wager.quantity, str(d.wager.crop).capitalize()]
				h._refs.prof_note.text = "Charm: one replacement; payout may fall." if p.readiness("reroll").ready else str(p.readiness("reroll").reason)
			else:
				var value: float = float(d.stake) * float(farm.market[farm.selected_crop].sell)
				h._refs.prof_resource.text = "%d %s · %s stake value" % [d.stake, farm.selected_crop.capitalize(), farm.money(value)]
				status = "%d / %d crops in barn" % [mini(int(d.stake), int(farm.storage[farm.selected_crop])), d.stake] if ready.ready else str(ready.reason)
				h._refs.prof_stake.text = "Stake %d %s" % [d.stake, farm.selected_crop.capitalize()]
				h._refs.prof_note.text = "Odds: 20% triple · 55% unchanged · 25% half"
	h._refs.prof_status.text = status
	h._refs.prof_status.visible = not status.is_empty()
	h._refs.prof_status.add_theme_color_override("font_color", h.MUTED if ready.get("ready", false) or (id == "scientist" and d.recipe in d.seedbank) else h.CHERRY)
	var passive: String = ""
	for entry in b.build_info():
		if entry.id == id: passive = entry.bonuses
	h._refs.prof_details.text = "Your build bonuses\n" + passive
	if id == "industrialist":
		var g: Dictionary = p.grade_preview()
		h._refs.prof_details.text += "\nSSS needs level 20, a fresh matching crop and two seed discoveries.\nGrade points: freshness %d/2 · matching process %d/2 · machine %d/3 · research %d/1." % [g.fresh, g.fit, g.tier, g.discovery]
