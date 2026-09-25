extends RefCounted
const Art = preload("res://scripts/build_illustration.gd")
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
		h._heading("Choose your way to farm", "Equip one profession; keep your discoveries and loaded jobs when you switch.")
		for entry in system.build_info():
			var card = h._surface("build", h.Cozy.BUILD_COLORS[entry.id], entry.active)
			h._body.add_child(card)
			var row = h._hbox(12)
			card.add_child(row)
			row.add_child(h._icon({"kind": "build", "id": entry.id}, 48))
			var words = h._vbox(3)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(words)
			words.add_child(h._label(entry.name + (" · equipped" if entry.active else ""), 18, h.INK, true))
			words.add_child(h._wrap(PURPOSE[entry.id], 13, h.MUTED))
			row.add_child(h._button("Explore" if entry.unlocked else "Preview", "build:inspect:" + entry.id))
		return
	h._heading(id.capitalize(), PURPOSE[id])
	var height: float = 552.0 if id == "farmer" else (634.0 if id == "scientist" else 600.0)
	h._modal_card.offset_top = -height * 0.5
	h._modal_card.offset_bottom = height * 0.5
	var nav = h._hbox(10)
	h._body.add_child(nav)
	nav.add_child(h._button("‹ All builds", "build:inspect:"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var equip = h._button("Equip", "build:select:" + id, true)
	nav.add_child(equip)
	h._refs.build_equip = equip
	var art = Art.new()
	art.kind = id
	art.custom_minimum_size = Vector2(0, 116 if id == "scientist" else 128)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h._body.add_child(art)
	h._refs.build_art = art
	var card = h._surface("build", h.Cozy.BUILD_COLORS[id])
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
	var status = h._wrap("", 13, h.GREEN, true)
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
	var details = h._details_section("build_details", "bonuses & progression")
	var label = h._wrap("", 13, h.MUTED)
	details.add_child(label)
	h._refs.prof_details = label
	refresh(h)
	_fit_height(h, id)
	h._refs["build_details:toggle"].pressed.connect(func(): _fit_height(h, id))

static func _fit_height(h, id: String) -> void:
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
	h._refs.build_equip.text = "Equipped · Lv.%d" % b.levels[id] if equipped else ("Equip · Lv.%d" % b.levels[id] if unlocked else "Find in a Build Crate")
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
	h._refs.prof_status.add_theme_color_override("font_color", h.GREEN if ready.get("ready", false) or (id == "scientist" and d.recipe in d.seedbank) else h.CHERRY)
	var passive: String = ""
	for entry in b.build_info():
		if entry.id == id: passive = entry.bonuses
	var extra: String = {"farmer": "One compost grows a giant potato with three times the ordinary harvest. Plant a crop first; water and harvest as usual. Each new harvest supplies one compost, up to 99.", "industrialist": "Grades: F · E · D · C · B · A · S · SS · SSS. Fresh harvests last 45s. Machine grade improves at levels 3, 10 and 20; queue slots at 10 and 20. SSS needs level 20, a fresh matching crop and two seed discoveries. Finished batches stay in the barn; sale prices follow the market.", "scientist": "Honeyheart: 50% more harvest. Sundew: half drought stress. Frostgold: avoids ordinary frost selection. Discovered traits are permanent and apply to future plantings with any build. Normal seeds are consumed as usual.", "investor": "Reserved prices last 180s. Delivery size becomes 100 at level 10. Completed deliveries improve future buyer premiums, capped after ten. An expired offer keeps all your crops.", "gambler": "20% chance of 3× · 55% of 1× · 25% of half. Outcomes use the locked stake price. Tables recover in 30s; a charm recharges in 180s. A charm replaces a result once per stake. The initial expected return is 1.275× before a charm; repeated play can still lose money."}[id]
	h._refs.prof_details.text = passive + "\n\n" + extra
	if id == "industrialist":
		var g: Dictionary = p.grade_preview()
		h._refs.prof_details.text += "\nGrade points: freshness %d/2 · matching process %d/2 · machine %d/3 · research %d/1." % [g.fresh, g.fit, g.tier, g.discovery]
