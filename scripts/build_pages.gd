extends RefCounted
const Art = preload("res://scripts/build_illustration.gd")
const BENEFITS: Dictionary = {
	"farmer": ["Grow a prize crop in a bed you choose", "Harvest scraps become reusable compost", "Bigger harvests and wider tools as you level"],
	"industrialist": ["Grade shipments from F to SSS", "Match the process to your crop", "Queue more batches at levels 10 and 20"],
	"scientist": ["Cross two crops into a named seed variety", "Keep useful traits in your seed bank", "Plant discovered varieties with any build"],
	"investor": ["Reserve today's price for a future shipment", "Build buyer reputation with deliveries", "Keep seed discounts while equipped"],
	"gambler": ["Choose exactly which harvest to stake", "Claim the result or use a lucky charm", "Keep better Roll House rewards while equipped"],
}

static func create(h) -> void:
	var system = h._build_system()
	if system == null: return
	var id: String = h._build_selection
	if id.is_empty():
		h._heading("Choose your way to farm", "One profession at a time. Your discoveries and loaded jobs stay with you.")
		for entry in system.build_info():
			var card = h._surface("build", h.Cozy.BUILD_COLORS[entry.id], entry.active)
			h._body.add_child(card)
			var row = h._hbox(12)
			card.add_child(row)
			row.add_child(h._icon({"kind": "build", "id": entry.id}, 56))
			var words = h._vbox(3)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(words)
			words.add_child(h._label(entry.name + (" · equipped" if entry.active else ""), 19, h.INK, true))
			words.add_child(h._wrap(entry.description, 13, h.MUTED))
			row.add_child(h._button("Explore" if entry.unlocked else "Preview", "build:inspect:" + entry.id))
		return
	h._heading(id.capitalize(), system.DESCRIPTIONS[id])
	var nav = h._hbox(10)
	h._body.add_child(nav)
	nav.add_child(h._button("‹ All builds", "build:inspect:"))
	var equip = h._button("Equip", "build:select:" + id, true)
	nav.add_child(equip)
	h._refs.build_equip = equip
	var art = Art.new()
	art.kind = id
	art.custom_minimum_size = Vector2(0, 132)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h._body.add_child(art)
	h._refs.build_art = art
	var card = h._surface("build", h.Cozy.BUILD_COLORS[id])
	h._body.add_child(card)
	var benefit_box = h._vbox(4)
	card.add_child(benefit_box)
	for benefit in BENEFITS[id]: benefit_box.add_child(h._wrap("• " + benefit, 14, h.INK))
	var status = h._wrap("", 14, h.GREEN, true)
	h._body.add_child(status)
	h._refs.prof_status = status
	if id in ["industrialist", "investor", "gambler"]:
		var crops = h._hbox(8)
		h._body.add_child(crops)
		var entries: Array = []
		for crop in system.state.available_crops(): entries.append([crop, "Crop · " + crop.capitalize()])
		choice(h, crops, "crop", entries)
	var row = h._hbox(8)
	h._body.add_child(row)
	match id:
		"farmer":
			add_action(h, row, "Choose a prize bed", "giant")
		"industrialist":
			choice(h, row, "method", [["polish", "Polish · golden / icecap / radioactive"], ["cure", "Cure · russet / giant / sunburst"]])
			choice(h, row, "batch", [["20", "20 crops"], ["100", "100 crops"]])
			var actions = h._hbox(8)
			h._body.add_child(actions)
			add_action(h, actions, "Load batch", "load")
			add_action(h, actions, "Sell graded shipment", "sell")
			var meter = h._meter(h.GOLD)
			meter.max_value = 1.0
			h._body.add_child(meter)
			h._refs.prof_progress = meter
		"scientist":
			choice(h, row, "recipe", [["hearty", "Honeyheart · russet + golden"], ["dry", "Sundew · giant + sunburst"], ["frost", "Frostgold · golden + icecap"]])
			add_action(h, row, "Crossbreed", "breed")
			h._body.add_child(h._wrap("Seed bank · choose a trait for future plantings; normal seeds are still used.", 12, h.MUTED))
			var bank = h._hbox(8)
			h._body.add_child(bank)
			choice(h, bank, "variety", [["", "Ordinary seeds"], ["hearty", "Honeyheart · generous harvest"], ["dry", "Sundew · drought tolerant"], ["frost", "Frostgold · frost hardy"]])
		"investor":
			add_action(h, row, "Reserve buyer", "reserve")
			add_action(h, row, "Load shipment", "deliver")
		"gambler":
			choice(h, row, "stake_size", [["5", "5 crops"], ["20", "20 crops"], ["100", "100 crops"]])
			add_action(h, row, "Stake harvest", "stake")
			h._body.add_child(h._wrap("20% → 3× · 55% → 1× · 25% → half. Only your selected crops are sold into this stake.", 13, h.MUTED))
			var actions = h._hbox(8)
			h._body.add_child(actions)
			add_action(h, actions, "Claim result", "claim")
			add_action(h, actions, "Use charm · replace result", "reroll")
	var details = h._details_section("build_details", "passive details & progression")
	var label = h._wrap("", 13, h.MUTED)
	details.add_child(label)
	h._refs.prof_details = label
	refresh(h)

static func add_action(h, row, title: String, action: String) -> void:
	var b = h._button(title, "profession:" + action, true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	h._refs["prof_" + action] = b

static func choice(h, row, key: String, entries: Array) -> void:
	var option := OptionButton.new()
	option.custom_minimum_size.y = 38
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for entry in entries:
		option.add_item(entry[1])
		option.set_item_metadata(option.item_count - 1, entry[0])
	option.item_selected.connect(func(index): h.action_requested.emit("crop:" + str(option.get_item_metadata(index)) if key == "crop" else "profession:%s:%s" % [key, option.get_item_metadata(index)]))
	row.add_child(option)
	h._refs["prof_" + key] = option

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
	h._refs.build_art.reward_text = "?" if d.wager.is_empty() else str(d.wager.factor) + "×"
	h._refs.build_art.motion = not b.processing.is_empty() if id == "industrialist" else equipped
	if h._refs.build_art.result_serial != p.event_serial:
		h._refs.build_art.result_serial = p.event_serial
		if p.event.get("kind", "") == "industrialist" and str(p.event.get("title", "")).ends_with("batch ready"):
			h._refs.build_art.stamp_left = 1.0
	for verb in ["giant", "load", "breed", "reserve", "stake"]:
		if h._refs.has("prof_" + verb): h._refs["prof_" + verb].disabled = not equipped
	for key in ["method", "batch", "recipe", "variety", "stake_size", "crop"]:
		if not h._refs.has("prof_" + key): continue
		var option: OptionButton = h._refs["prof_" + key]
		var value: String = farm.selected_crop if key == "crop" else str(d[{"batch": "batch_size", "stake_size": "stake"}.get(key, key)])
		for i in range(option.item_count):
			if str(option.get_item_metadata(i)) == value: option.select(i)
			if key == "variety": option.set_item_disabled(i, i > 0 and option.get_item_metadata(i) not in d.seedbank)
	var status: String = ""
	match id:
		"farmer":
			status = "%d compost · click a growing bed, then water and harvest normally." % d.compost
			h._refs.prof_giant.disabled = not equipped or d.compost == 0
		"industrialist":
			var preview: Dictionary = p.grade_preview()
			status = "Expected grade %s · %s · %s\n%s" % [preview.grade, "fresh harvest" if preview.fresh else "stored harvest", "matched process" if preview.fit else "try " + preview.desired, ("Last stamp · " + d.last_grade if d.last_grade != "" else "Choose your crop and process below.") if b.processing.is_empty() else "Processing · %d queued" % d.queue.size()]
			h._refs.prof_progress.visible = not b.processing.is_empty()
			h._refs.prof_progress.value = b.activity_info().progress
			h._refs.prof_load.text = "Load %d %s · %s" % [d.batch_size, farm.selected_crop, preview.grade]
			h._refs.prof_load.disabled = not equipped or farm.storage[farm.selected_crop] < d.batch_size or d.queue.size() + (0 if b.processing.is_empty() else 1) >= 1 + mini(2, int(b.levels.industrialist) / 10)
			h._refs.prof_sell.text = "Sell graded · " + farm.money(b.processed_value())
			h._refs.prof_sell.disabled = b.processed_value() <= 0
		"scientist":
			var recipe: Dictionary = p.RECIPES[d.recipe]
			status = "%s · %s\nCrossbreed with 10 %s + 10 %s. Discovered %d / 3." % [recipe.name, recipe.trait, recipe.a, recipe.b, d.seedbank.size()]
			h._refs.prof_breed.disabled = not equipped or d.recipe in d.seedbank or farm.storage[recipe.a] < 10 or farm.storage[recipe.b] < 10
		"investor":
			status = "Reserve a buyer for %s at today's price. %d deliveries completed." % [farm.selected_crop, d.deliveries]
			if not d.contract.is_empty(): status = "%d %s × %s = %s\nPrice locked · %.0fs left · Island %d" % [d.contract.quantity, d.contract.crop, farm.money(d.contract.quote), farm.money(d.contract.quantity * d.contract.quote), d.contract.remaining, d.contract.island]
			h._refs.prof_reserve.disabled = not equipped or not d.contract.is_empty()
			h._refs.prof_deliver.disabled = d.contract.is_empty() or farm.current_island != int(d.contract.get("island", 0)) or farm.storage.get(d.contract.get("crop", ""), 0) < int(d.contract.get("quantity", 1))
		"gambler":
			var value: float = float(d.stake) * float(farm.market[farm.selected_crop].sell)
			status = "%d %s · stake value %s\nCharm %s · next table %.0fs" % [d.stake, farm.selected_crop, farm.money(value), "ready" if d.charm else "recharging", b.cooldown]
			if not d.wager.is_empty(): status = "Result ×%s · %s ready to claim\nA charm replaces this result, even if the new result is lower." % [d.wager.factor, farm.money(d.wager.quantity * d.wager.quote * d.wager.factor)]
			h._refs.prof_stake.disabled = not equipped or not d.wager.is_empty() or b.cooldown > 0 or farm.storage[farm.selected_crop] < d.stake
			h._refs.prof_claim.disabled = d.wager.is_empty()
			h._refs.prof_reroll.disabled = d.wager.is_empty() or not d.charm
	h._refs.prof_status.text = status
	var passive: String = ""
	for entry in b.build_info():
		if entry.id == id: passive = entry.bonuses
	var extra: String = {"farmer": "Prize beds yield three times their ordinary harvest. Each new harvest supplies one compost, up to 99.", "industrialist": "Grades: F · E · D · C · B · A · S · SS · SSS. Fresh harvests last 45s; stored crops keep their base value. Machine grade points improve at levels 3, 10 and 20; queue slots at 10 and 20. SSS needs level 20, a fresh matching crop and two seed discoveries. Graded goods stay in barn storage until sold.", "scientist": "Honeyheart: 50% more harvest. Sundew: half drought stress. Frostgold: crops avoid ordinary frost selection. Discovery and seed traits remain available after switching.", "investor": "Reserved prices last 180s. Delivery size becomes 100 at level 10. Completed deliveries improve future buyer premiums, capped after ten. Expiry keeps all your crops.", "gambler": "Tables recover in 30s. One charm recharges in 180s. Outcomes use the locked stake price. The initial expected return is 1.275× before a charm; repeated play can still lose money."}[id]
	h._refs.prof_details.text = passive + "\n\n" + extra
	if id == "industrialist":
		var g: Dictionary = p.grade_preview()
		h._refs.prof_details.text += "\nGrade points: freshness %d/2 · matching process %d/2 · machine %d/3 · research %d/1." % [g.fresh,g.fit,g.tier,g.discovery]
