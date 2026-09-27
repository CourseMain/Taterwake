extends RefCounted
const Art = preload("res://scripts/build_illustration.gd")
const Type = preload("res://scripts/ui_type.gd")
const HAND = preload("res://assets/fonts/PatrickHand.ttf")
const PAPER := Color("eee5ce")
const INK := Color("30463a")
const MARGIN_NOTES: Dictionary = {
	"farmer": "Mara: Use the whole scoop. Stand back.",
	"industrialist": "Ada: It only jams when somebody watches.",
	"scientist": "Keep the labels. They all look like potatoes.",
	"investor": "Nell: Count them before you seal the crate.",
	"gambler": "Rook: Count your seed money before your winnings.",
}
const ORDER: Array[String] = ["farmer", "industrialist", "scientist", "investor", "gambler"]
const ACCENTS: Dictionary = {"farmer": Color("42976d"), "industrialist": Color("d47a45"), "scientist": Color("6c79c7"), "investor": Color("238b92"), "gambler": Color("a568ab")}
const PLAYSTYLE: Dictionary = {
	"farmer": "A scoop of compost. A potato that needs two hands.",
	"industrialist": "Brush off the mud. Give Ada's sorter a fighting chance.",
	"scientist": "Cross two harvests. Keep the useful oddities.",
	"investor": "Get the price in writing. Then fill the crates.",
	"gambler": "Put a harvest on the table. Half can walk away.",
}
const HOW: Dictionary = {
	"farmer": "Plant a crop, choose Grow a giant potato, then click a highlighted growing patch. Spend 1 compost for 3× its harvest; water and harvest normally.",
	"industrialist": "Load 20 or 100 harvested crops. Polish Golden, Icecap or Radioactive; cure the others. A matching process and crops harvested within 45 seconds improve the grade.",
	"scientist": "Choose a recipe and spend 10 of each listed crop. Select the discovered trait for future plantings; ordinary seeds are still used.",
	"investor": "Reserve a buyer at the displayed price, then deliver 20 crops within 180 seconds from the same island. Shipment size becomes 100 at level 10.",
	"gambler": "Stake 5, 20 or 100 harvested crops at their current value. Claim coins worth half, the same or triple that locked value. A charm can replace the result once.",
}
const BENEFITS: Dictionary = {
	"farmer": "Active Farmer adds 5% yield per level. Growth speed rises from level 2; tool area widens at levels 3, 10 and 20. Each new patch harvested earns 1 compost (up to 99).",
	"industrialist": "Grades range from F (1.05× sale value) to SSS (8×). Higher build levels process faster; machine grade improves at 3, 10 and 20, with extra queue slots at 10 and 20.",
	"scientist": "Honeyheart gives 50% more harvest; Sundew halves drought stress; Frostgold avoids ordinary frost selection. Active Scientist also improves mutation chance.",
	"investor": "The buyer starts at 20% above the current price. Each completed delivery adds 3 percentage points, capped after ten. Active Investor raises the chance of positive market events.",
	"gambler": "Active Gambler adds 8% Roll House reward quality per level. Stake results: 20% triple, 55% unchanged, 25% half. The table recovers in 30 seconds; a used charm recharges in 180 seconds.",
}
const TRADEOFFS: Dictionary = {
	"farmer": "Compost only works on a planted, still-growing, unfrozen patch, once per crop. Switching removes Farmer's active yield, speed and tool-area bonuses; a composted patch keeps its 3× harvest.",
	"industrialist": "Loading removes raw crops and keeps that barn space occupied. Wait for processing before selling. The final payout follows the market, so it can fall while you wait.",
	"scientist": "Crossbreeding consumes both ingredients. Traits affect future plantings, not crops already growing. Discoveries stay available with every build; the active mutation bonus changes when you switch.",
	"investor": "A locked quote misses later price rises. An expired offer pays nothing and leaves your crops untouched. Switching builds keeps the offer and its running deadline; delivery is still available.",
	"gambler": "The staked crops leave your barn. A half-value result loses half their locked value, and a charm can produce a worse result. Switching keeps a pending result available to claim.",
}
const SWITCH_NOTE: String = "Switching is free and immediate. Only one build's active bonuses apply; discoveries and loaded jobs stay with you."
const UNLOCK_NOTE: String = "Find its card in a Build Crate. Crates have a 5% chance to drop from paid Roll House rolls; open them in Inventory."
const PURPOSE: Dictionary = {
	"farmer": "Turn a growing crop into a giant potato.",
	"industrialist": "Match a crop to its process, then sell the graded harvest.",
	"scientist": "Cross harvested crops to discover a permanent planting trait.",
	"investor": "Lock a buyer's price, then deliver the promised crops.",
	"gambler": "Stake part of your harvest for a coin payout that can rise or fall.",
}
const ACTION_TITLE: Dictionary = {"farmer": "Grow a giant potato", "industrialist": "Grade a batch", "scientist": "Discover a variety", "investor": "Reserve a buyer", "gambler": "Stake a harvest"}

static func create(h) -> void:
	var system = h._build_system()
	if system == null: return
	var id: String = h._build_selection
	if id.is_empty():
		create_overview(h, system)
		return
	h._heading(id.capitalize(), PLAYSTYLE[id])
	_notebook(h, ACCENTS[id])
	var height: float = 552.0 if id == "farmer" else (634.0 if id == "scientist" else 600.0)
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5
	var nav = h._hbox(10)
	h._body.add_child(nav)
	nav.add_child(h._button("‹ All builds", "build:inspect:"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var equip = h._button("Select build", "build:select:" + id, true)
	nav.add_child(equip)
	h._refs.build_equip = equip
	var selection_note = h._wrap("", 12, h.MUTED)
	h._body.add_child(selection_note)
	h._refs.build_selection_note = selection_note
	var art = Art.new()
	art.kind = id
	art.compact_layout = _touch(h)
	art.custom_minimum_size = Vector2(0, 196 if _touch(h) else (116 if id == "scientist" else 128))
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
			add_action(h, actions, "Grow a giant potato · 1 compost", "giant")
			var prepare = h._button("Plant a crop first [2]", "close")
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
			body.add_child(h._wrap("Plant with normal seeds; your selected trait stays available with every build.", 12, h.MUTED))
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
	var details = h._details_section("build_details", "field notes & progression")
	h._refs.build_details.add_theme_stylebox_override("panel", _paper_skin(ACCENTS[id]))
	for entry in [["Method", HOW[id]], ["What the village has measured", BENEFITS[id]], ["Read before trying", TRADEOFFS[id]]]:
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
	font.fallbacks = []
	label.add_theme_font_override("font", font)
	label.add_theme_constant_override("outline_size", 0)
	return label

static func _compact_type(node: Node) -> void:
	if node is Label and node.has_meta("field_annotation"):
		node.add_theme_font_override("font", HAND)
		node.add_theme_font_size_override("font_size", 17)
	elif node is Label or node is Button or node is LineEdit:
		var font: Font = node.get_theme_font("font").duplicate()
		font.fallbacks = []
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

static func _annotation(h, words: String, color: Color = INK) -> Label:
	var label = h._wrap(words, 17, color)
	label.add_theme_font_override("font", HAND)
	label.add_theme_constant_override("outline_size", 0)
	label.set_meta("field_annotation", true)
	return label

static func create_overview(h, system) -> void:
	h._heading("The village field guide", "Five ways to put a potato to work. Notes from muddy hands.")
	_notebook(h)
	_overview_size(h)
	var intro = h._hbox(12)
	h._body.add_child(intro)
	var selected = h._badge("✓ Selected · " + system.active.capitalize(), "active")
	selected.add_theme_font_size_override("font_size", 14)
	intro.add_child(selected)
	h._refs.build_selected_summary = selected
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(spacer)
	intro.add_child(h._button("Read the guide", "build_guide"))
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
		var leaf = h._label("LEAF %02d" % (ORDER.find(id) + 1), 11, accent.darkened(0.25), true)
		sketch.add_child(leaf)
		var picture = Art.new()
		picture.kind = id
		picture.specimen = true
		picture.custom_minimum_size = Vector2(110, 128) if _touch(h) else Vector2(86, 100)
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
		var badge = h._badge("✓ Selected" if entry.active else ("Lv.%d · Ready" % entry.level if entry.unlocked else "Locked"), "active" if entry.active else ("ready" if entry.unlocked else "locked"))
		title.add_child(badge)
		h._refs["build_status:" + id] = badge
		var tagline = h._wrap(PLAYSTYLE[id], 13, INK)
		tagline.custom_minimum_size.y = 36
		title.add_child(tagline)
		var explore = h._button("Open notes" if entry.unlocked else "Preview notes", "build:inspect:" + id, entry.active)
		title.add_child(explore)
		h._refs["build_explore:" + id] = explore
	var guide = _folio(h, h.GOLD)
	grid.add_child(guide)
	var guide_body = h._vbox(6)
	guide.add_child(guide_body)
	guide_body.add_child(h._label("A NOTE INSIDE THE COVER", 11, INK, true))
	guide_body.add_child(_annotation(h, "Mara: Start with the soil. The other schemes will keep.", Color("496744")))
	guide_body.add_child(h._wrap("Farmer is your starter. Other builds come in Build Crates. Looking through these pages changes nothing; select an unlocked build for free.", 13, h.MUTED))
	guide_body.add_child(h._button("How builds work", "build_guide"))
	_finish_type(h)

static func create_guide(h) -> void:
	h._heading("Field notes: builds", "Written down before somebody tries it twice.")
	_notebook(h)
	h._body.add_child(h._button("‹ Browse all builds", "build:inspect:"))
	var intro = _folio(h, h.GOLD)
	h._body.add_child(intro)
	var body = h._vbox(8)
	intro.add_child(body)
	body.add_child(_display(h, "First, a working pair of hands", 22, h.INK))
	body.add_child(h._wrap("A build adds active bonuses and a special way to use your crops. You start as Farmer: bigger harvests and compost-powered giants.", 14, h.INK))
	body.add_child(h._wrap("Open Builds [C] to compare all five. Open notes shows the appearance, actions and tradeoffs. Only Select build changes your active build; the Selected badge always marks it.", 14, h.MUTED))
	body.add_child(h._wrap(SWITCH_NOTE, 14, h.INK))
	var unlock = _folio(h, ACCENTS.scientist)
	h._body.add_child(unlock)
	var unlock_body = h._vbox(6)
	unlock.add_child(unlock_body)
	unlock_body.add_child(_display(h, "Where the other build cards turn up", 20, h.INK))
	unlock_body.add_child(h._wrap(UNLOCK_NOTE + " A card unlocks its build or adds a level, up to 30. A crate does not guarantee a particular build.", 14, h.MUTED))
	unlock_body.add_child(h._wrap("Paid rolls spend coins and can return little. Keep seed and tax money before trying for a crate.", 13, h.CHERRY))
	for id in ORDER:
		var card = _folio(h, ACCENTS[id])
		h._body.add_child(card)
		var column = h._vbox(8)
		card.add_child(column)
		var heading = h._hbox(9)
		column.add_child(heading)
		heading.add_child(h._icon({"kind": "build", "id": id}, 52))
		var heading_text = _display(h, "%02d  %s" % [ORDER.find(id) + 1, id.capitalize()], 21, h.INK)
		heading_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(heading_text)
		column.add_child(_annotation(h, MARGIN_NOTES[id]))
		column.add_child(h._wrap(HOW[id], 14, h.INK))
		column.add_child(h._wrap(TRADEOFFS[id], 13, h.MUTED))
		column.add_child(h._button("Explore " + id.capitalize(), "build:inspect:" + id))
	h._body.add_child(h._wrap("Loaded workshop batches keep processing after a switch. Discovered traits stay in your seed bank; reserved buyers keep their deadlines and harvest stakes remain claimable.", 13, h.MUTED))
	_finish_type(h)

static func _fit_height(h, id: String) -> void:
	_finish_type(h)
	var touch = h.get_parent().get("touch_controls")
	if is_instance_valid(touch) and touch.enabled:
		touch.fit_modal()
		return
	# Measure once after layout, and when the optional drawer changes. Live
	# resource refreshes must not move a button under the pointer.
	await h.get_tree().process_frame
	if not is_instance_valid(h): return
	await h.get_tree().process_frame
	if not is_instance_valid(h): return
	if h._panel_kind != "builds" or h._build_selection != id: return
	var column: VBoxContainer = h._modal_card.get_child(0)
	var extra: float = h._modal_card.get_theme_stylebox("panel").get_minimum_size().y
	var visible_children: int = 0
	for child in column.get_children():
		if not child is Control or not child.visible: continue
		visible_children += 1
		if child != h._body.get_parent(): extra += child.get_combined_minimum_size().y
	extra += maxf(0, visible_children - 1) * column.get_theme_constant("separation")
	if id == "industrialist" and not h._refs.prof_job.visible:
		# Reserve the later job label, meter and their gaps before the first load.
		# Starting a batch must not resize the modal or hide the details toggle.
		var job: Label = h._refs.prof_job
		extra += job.get_theme_font("font").get_height(job.get_theme_font_size("font_size"))
		extra += h._refs.prof_progress.get_combined_minimum_size().y
		extra += 2 * job.get_parent().get_theme_constant("separation")
	var height: float = clampf(h._body.get_combined_minimum_size().y + extra, 360, 634)
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5

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
	if not h._refs.has("prof_status"): return
	var b = h._build_system()
	var p = b.professions
	var d: Dictionary = p.data
	var farm = b.state
	var id: String = h._build_selection
	var equipped: bool = b.active == id
	var unlocked: bool = int(b.levels[id]) > 0
	h._refs.build_equip.text = "✓ Selected · Lv.%d" % b.levels[id] if equipped else ("Select build · Free" if unlocked else "Locked · Build Crate")
	h._refs.build_selection_note.visible = not equipped
	h._refs.build_selection_note.text = "Free switch · replaces %s's active bonuses. Your progress stays." % b.active.capitalize() if unlocked else UNLOCK_NOTE
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
			status = "Choose a highlighted growing crop; then water, grow and harvest normally." if ready.ready else str(ready.reason)
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
				h._refs.prof_prepare.text = {"harvest": "Harvest ripe crops first [4]", "hoe": "Thaw a growing crop first [1]", "plant": "Plant a crop first [2]"}[tool]
				if growing.eligible.is_empty() and d.compost > 0:
					if ripe: status = "Harvest a ripe crop, then plant a new seed before adding compost."
					elif frozen: status = "Clear the ice with your hoe before adding compost to a growing crop."
			elif equipped and growing.eligible.is_empty() and d.compost > 0:
				status = "Your growing crops already have compost; let them grow, then harvest."
		"industrialist":
			ready = _readiness(h, p, "load")
			var preview: Dictionary = p.grade_preview()
			var held: int = int(farm.storage[farm.selected_crop])
			h._refs.prof_resource.text = "Next batch: grade %s · %s× sale value · %d / %d %s in barn" % [preview.grade, String.num(preview.multiplier, 2), mini(held, int(d.batch_size)), d.batch_size, farm.selected_crop.capitalize()]
			status = ("Process matched · " + ("freshly harvested." if preview.fresh else "stored harvest.")) if preview.fit else "Choose %s to improve this crop's grade." % str(preview.desired).capitalize()
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
			h._refs.prof_resource.text = "10 %s + 10 %s · a permanent planting trait" % [str(recipe.a).capitalize(), str(recipe.b).capitalize()]
			status = "%d / 10 %s · %d / 10 %s in barn" % [mini(10, int(farm.storage[recipe.a])), str(recipe.a).capitalize(), mini(10, int(farm.storage[recipe.b])), str(recipe.b).capitalize()] if ready.ready else str(ready.reason)
			h._refs.prof_breed.text = "Already discovered" if d.recipe in d.seedbank else "Crossbreed · 10 + 10 crops"
			if d.recipe in d.seedbank: status = "Saved to your seed bank; select this trait for future plantings below."
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
				status = "%d / %d crops in barn · deliver from Island %d." % [mini(int(contract.quantity), int(farm.storage[contract.crop])), contract.quantity, contract.island] if ready.ready else str(ready.reason)
				h._refs.prof_deliver.text = "Deliver %d %s · %s" % [contract.quantity, str(contract.crop).capitalize(), farm.money(contract.quantity * contract.quote)]
			else:
				var quote: Dictionary = p.contract_preview()
				h._refs.prof_resource.text = "%d %s · %s locked payout" % [quote.quantity, str(quote.crop).capitalize(), farm.money(quote.total)]
				status = "No upfront cost; deliver within 3 minutes from this island." if ready.ready else str(ready.reason)
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
				status = "%d %s were staked at their locked value." % [d.wager.quantity, str(d.wager.crop).capitalize()]
				h._refs.prof_note.text = "A charm replaces this payout once; the replacement can be lower." if p.readiness("reroll").ready else str(p.readiness("reroll").reason)
			else:
				var value: float = float(d.stake) * float(farm.market[farm.selected_crop].sell)
				h._refs.prof_resource.text = "%d %s · %s stake value" % [d.stake, farm.selected_crop.capitalize(), farm.money(value)]
				status = "%d / %d crops in barn · only this quantity is removed." % [mini(int(d.stake), int(farm.storage[farm.selected_crop])), d.stake] if ready.ready else str(ready.reason)
				h._refs.prof_stake.text = "Stake %d %s" % [d.stake, farm.selected_crop.capitalize()]
				h._refs.prof_note.text = "Receive half, the same, or triple this value in coins; your other crops stay in the barn."
	h._refs.prof_status.text = status
	h._refs.prof_status.add_theme_color_override("font_color", h.MUTED if ready.get("ready", false) or (id == "scientist" and d.recipe in d.seedbank) else h.CHERRY)
	var passive: String = ""
	for entry in b.build_info():
		if entry.id == id: passive = entry.bonuses
	h._refs.prof_details.text = "Your build bonuses\n" + passive
	if id == "industrialist":
		var g: Dictionary = p.grade_preview()
		h._refs.prof_details.text += "\nSSS needs level 20, a fresh matching crop and two seed discoveries.\nGrade points: freshness %d/2 · matching process %d/2 · machine %d/3 · research %d/1." % [g.fresh, g.fit, g.tier, g.discovery]
