extends RefCounted
const Land = preload("res://scripts/farm_land.gd")
const Balance = preload("res://scripts/balance.gd")
## Winter construction and a journal of physical crop losses.
const Table = preload("res://scripts/crop_table.gd")
const Rules = preload("res://scripts/save_validation.gd")
const REDUCTION: Array[float] = Balance.PROTECTION_REDUCTION
const PROJECT_FOR: Dictionary = {"drought": "rainwater", "flood": "drainage", "storm": "windbreaks", "freeze": "frost"}
const NAMES: Dictionary = {"rainwater":"Rainwater tank", "drainage":"Drainage", "windbreaks":"Windbreak", "frost":"Frost cover"}
const COSTS: Dictionary = Balance.PROTECTION_COSTS
const WORK_ACTIONS: int = 3
const UPKEEP: float = Balance.PROTECTION_UPKEEP
const PREMIUM: float = Balance.INSURANCE_PREMIUM
const PAYOUT: float = Balance.INSURANCE_PAYOUT
const STATION_COST: float = Balance.STATION_COST

static func fresh() -> Dictionary:
	return {"pending": {}, "covers": {}, "losses": [], "policies": [], "winters": {}, "station": 0, "revision": 0}

static func level(farm, event: String, index: int) -> int:
	var id: String = PROJECT_FOR.get(event, "")
	if id == "frost":
		var cover: Dictionary = farm.climate.data.protection.covers.get(str(index), {})
		return int(cover.get("level", 0)) if farm.season_clock.season == 0 and int(cover.get("year", 0)) == farm.season_clock.year else 0
	return int(farm.climate.data.projects.get(id, 0))

static func loss(quantity: int, reduction: float, exposure: float = 1.0) -> int:
	return clampi(roundi(quantity * (1.0 - reduction) * exposure), 0, quantity)

static func remaining(plot: Dictionary) -> int:
	if int(plot.stage) == 0: return 0
	var total: int = int(plot.yield_total) if int(plot.yield_total) > 0 else Land.yield_for(plot)
	return maxi(0, floori(total * (3 - int(plot.pest_ticks)) / 3.0) - int(plot.yield_taken) - int(plot.get("weather_lost", 0)))

static func damage(farm, index: int, event: String, exposed_limit: int = -1) -> void:
	var plot: Dictionary = farm.plots[index]
	var quantity: int = remaining(plot)
	if exposed_limit >= 0: quantity = mini(quantity, exposed_limit)
	if quantity <= 0: return
	var rank: int = level(farm, event, index)
	var id: String = PROJECT_FOR.get(event, "")
	var missing: String = "Water this bed" if id.is_empty() else str(NAMES[id]) + (" missing" if rank == 0 else " level %d" % rank)
	if id == "frost" and rank == 0: missing = "No frost cover on this bed"
	var alternative: float = 1.0 if id.is_empty() else REDUCTION[mini(2, rank + 1)]
	if id == "frost" and farm.season_clock.season != 0:
		missing = "Covers protect Spring only; clear ice with Hoe"
		alternative = 1.0
	var field: String = Land.id(index)
	var exposure: float = Land.exposure(field, event)
	var exposed: int = quantity
	var previous: int = 0
	var card: int = -1
	var group_key: String = "%d/%d/%s/%s/%d/%s/%s" % [farm.season_clock.year, farm.season_clock.season, event, plot.crop, rank, str(insured(farm)), field]
	var groups: Dictionary = farm.climate.data.operations.loss_groups
	if not event.is_empty() and groups.has(group_key):
		exposed += int(groups[group_key].exposed)
		previous = loss(int(groups[group_key].exposed), REDUCTION[rank], exposure)
		card = int(groups[group_key].card)
	var lost: int = loss(exposed, REDUCTION[rank], exposure) - previous
	card = record(farm, event if not event.is_empty() else "dry_bed", str(plot.crop), exposed, REDUCTION[rank], alternative, missing, "field", -1, card, field)
	if not event.is_empty(): groups[group_key] = {"exposed": exposed, "card": card}
	if lost == 0: return
	plot.weather_lost = int(plot.get("weather_lost", 0)) + lost
	if int(plot.yield_total) > 0: plot.pending = remaining(plot)
	if remaining(plot) == 0:
		farm._clear_crop(plot)
		if event == "flood": plot.tilled = false
		farm.climate.data.field_lost += 1
		if not event.is_empty():
			farm.climate.data.last.field_lost += 1
			farm.climate.data.last.field_total = maxi(int(farm.climate.data.last.field_total), int(farm.climate.data.last.field_lost))
			if not farm.climate.data.history.is_empty(): farm.climate.data.history[-1] = farm.climate.data.last.duplicate(true)

static func record(farm, event: String, crop: String, exposed: int, reduction: float, alternative: float, missing: String, source: String, season: int = -1, card: int = -1, field: String = "home") -> int:
	var exposure: float = Land.exposure(field, event) if source == "field" else 1.0
	var lost: int = loss(exposed, reduction, exposure)
	if lost <= 0: return -1
	var data: Dictionary = farm.climate.data.protection
	var entry: Dictionary = {"year": farm.season_clock.year, "season": farm.season_clock.season if season < 0 else season,
		"event": event, "crop": crop, "sacks": lost, "exposed": exposed, "reduction": reduction, "alternative": alternative,
		"field": field if source == "field" else "barn", "saved": lost - loss(exposed, alternative, exposure), "missing": missing, "source": source,
		"insured": insured(farm) and event not in ["spoilage", "lease_ended"] and (source == "field" or event in farm.ClimateSystem.WINTER_LOSS)}
	var previous: int = int(data.losses[card].sacks) if card >= 0 else 0
	if card >= 0: data.losses[card] = entry
	else:
		card = data.losses.size()
		data.losses.append(entry)
	if entry.insured and int(entry.season) == 3 and lost > previous and data.winters.has(str(farm.season_clock.year)):
		var payout: float = (lost - previous) * float(Table.CROPS[crop].base) * PAYOUT
		farm.post_money("insurance", "Winter crop loss payout", payout)
		data.winters[str(farm.season_clock.year)].payout += payout
	data.revision = int(data.revision) + 1
	if lost > previous: farm.notified.emit(text(entry))
	return card

static func text(entry: Dictionary) -> String:
	var prevention: String = {"dry_bed":"Watering in time", "pests":"Spraying in time", "autumn_cold":"Harvesting before Winter", "spoilage":"Selling before Winter", "lease_ended":"Harvesting before returning the field"}.get(entry.event, "")
	if entry.event in ["deep_freeze", "blizzard"]: prevention = "Selling before impact" if entry.source == "barn" else "Harvesting before impact"
	if entry.source == "field" and PROJECT_FOR.has(entry.event):
		prevention = "Clearing ice in time" if float(entry.alternative) == 1.0 else "%s level %d" % [NAMES[PROJECT_FOR[entry.event]], 1 if float(entry.alternative) == 0.5 else 2]
	var counterfactual: String = "%s would have saved %d t." % [prevention, entry.saved]
	if float(entry.alternative) == float(entry.reduction): counterfactual = "Maximum project protection; no further project saving."
	return "%s · Year %d · %s · %s · %s: %d t lost. %s. %s" % [Land.NAMES.get(entry.get("field", "home"), "Barn"), entry.year, ["Spring", "Summer", "Autumn", "Winter"][int(entry.season)], str(entry.event).replace("_", " ").capitalize(), Table.CROPS[entry.crop].name, entry.sacks, entry.missing, counterfactual]

static func work(farm, id: String) -> String:
	var p: Dictionary = farm.climate.data.protection
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 3: return farm._finish("Construction is Winter work.")
	if not p.pending.has(id): return farm._finish("Reserve this project at the weather station first.")
	p.pending[id] = int(p.pending[id]) + 1
	if int(p.pending[id]) < WORK_ACTIONS: return farm._finish("%s · Work %d / %d" % [farm.ClimateSystem.PROJECTS[id].name, p.pending[id], WORK_ACTIONS])
	p.pending.erase(id)
	farm.climate.data.projects[id] = int(farm.climate.data.projects.get(id, 0)) + 1
	farm.climate_changed.emit("construction")
	return farm._finish("%s completed. Level %d." % [farm.ClimateSystem.PROJECTS[id].name, farm.climate.data.projects[id]])

static func can_cover(farm, index: int) -> bool:
	var rank: int = int(farm.climate.data.projects.get("frost", 0))
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 3 or rank == 0: return false
	if index < 0 or index >= farm.plots.size() or not farm.plots[index].unlocked or farm.ClimateSystem.Operations.frozen(farm, index): return false
	var previous: Dictionary = farm.climate.data.protection.covers.get(str(index), {})
	return int(previous.get("year", 0)) != farm.season_clock.year + 1 or int(previous.get("level", 0)) != rank

static func coverable_beds(farm) -> Array[int]:
	var beds: Array[int] = []
	for index in range(farm.plots.size()):
		if can_cover(farm, index): beds.append(index)
	return beds

static func _place_cover(farm, index: int) -> void:
	farm.climate.data.protection.covers[str(index)] = {"year": farm.season_clock.year + 1, "level": int(farm.climate.data.projects.frost)}

static func cover_all(farm) -> String:
	var beds: Array[int] = coverable_beds(farm)
	if beds.is_empty(): return farm._finish("No cleared beds need covers. Build frost covers and clear bed ice in Winter first.")
	for index in beds: _place_cover(farm, index)
	farm.climate_changed.emit("cover")
	return farm._finish("Covered %d cleared beds for next Spring." % beds.size())

static func cover(farm, index: int) -> String:
	var rank: int = int(farm.climate.data.projects.get("frost", 0))
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 3 or rank == 0: return farm._finish("Build frost covers in Winter first.")
	if index < 0 or index >= farm.plots.size() or not farm.plots[index].unlocked: return farm._finish("Choose an open bed.")
	if farm.ClimateSystem.Operations.frozen(farm, index): return farm._finish("Clear this bed’s ice before placing a cover.")
	if not can_cover(farm, index): return farm._finish("This bed is already covered for next Spring.")
	_place_cover(farm, index)
	farm.climate_changed.emit("cover")
	return farm._finish("Bed %d covered for next Spring · %d%% freeze loss reduction." % [index + 1, roundi(REDUCTION[rank] * 100)])

static func insured(farm) -> bool:
	for year in farm.climate.data.protection.policies:
		if int(year) == farm.season_clock.year: return true
	return false

static func insure(farm) -> String:
	var p: Dictionary = farm.climate.data.protection
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 0: return farm._finish("Buy annual crop insurance in Spring.")
	if insured(farm): return farm._finish("This year's crops are already insured.")
	if not farm.can_purchase(PREMIUM): return farm._reject_purchase(farm.purchase_refusal(PREMIUM))
	farm.post_money("insurance", "Annual crop insurance", -PREMIUM)
	p.policies.append(farm.season_clock.year)
	return farm._finish("Crops insured: 40% at base prices. Field losses settle at Winter start; Winter crop and barn claims pay as losses occur.")

static func upgrade_station(farm) -> String:
	var p: Dictionary = farm.climate.data.protection
	if farm.run_over or farm.accounts_open or farm.tutorial_active or int(p.station) >= 2: return farm._finish("Weather station already at its limit.")
	var cost: float = STATION_COST * (int(p.station) + 1)
	if not farm.can_purchase(cost): return farm._reject_purchase(farm.purchase_refusal(cost))
	farm.post_money("protection", "Weather station upgrade", -cost)
	p.station = int(p.station) + 1
	return farm._finish("Forecast uncertainty narrowed.")

static func forecast(farm) -> Dictionary:
	var season: int = (farm.season_clock.season + 1) % 4
	var year: int = farm.season_clock.year + (1 if season == 0 else 0)
	var capped: bool = farm.climate.year_count(year) >= farm.ClimateSystem.ANNUAL_CAP
	var chance: float = 0.0 if capped else farm.ClimateSystem.chance(year)
	var margin: float = [0.20, 0.10, 0.05][int(farm.climate.data.protection.station)]
	var events: Dictionary = {}
	for event in farm.ClimateSystem.SEASON_EVENTS[season]:
		var risk: float = chance / 2.0
		events[event] = {"chance": risk, "low": maxf(0, risk - margin) if not capped else 0.0, "high": minf(1, risk + margin) if not capped else 0.0}
	return {"events": events, "year": year, "season": season, "chance": chance, "low": maxf(0, chance - margin) if not capped else 0.0, "high": minf(1, chance + margin) if not capped else 0.0}

static func winter(farm) -> void:
	if farm.season_clock.season != 3: return
	var p: Dictionary = farm.climate.data.protection
	var year: String = str(farm.season_clock.year)
	if p.winters.has(year): return
	var payout: float = 0.0
	for entry in p.losses:
		if int(entry.year) == farm.season_clock.year and entry.insured: payout += int(entry.sacks) * float(Table.CROPS[entry.crop].base) * PAYOUT
	if payout > 0: farm.post_money("insurance", "Crop loss payout", payout)
	var upkeep: float = 0.0
	for id in PROJECT_FOR.values():
		if int(farm.climate.data.projects.get(id, 0)) > 0:
			farm.post_money("upkeep", str(farm.ClimateSystem.PROJECTS[id].name) + " upkeep", -UPKEEP)
			upkeep += UPKEEP
	p.winters[year] = {"payout": payout, "upkeep": upkeep}

static func valid(raw: Variant, saved: Dictionary) -> bool:
	if not raw is Dictionary or raw.size() != 7: return false
	if not raw.get("pending") is Dictionary or not raw.get("covers") is Dictionary or not raw.get("losses") is Array or not raw.get("policies") is Array or not raw.get("winters") is Dictionary: return false
	if not Rules.number(raw.get("station"), 0, 2, true) or not Rules.number(raw.get("revision"), 0, 1000000000, true): return false
	for id in raw.pending:
		if id not in PROJECT_FOR.values() or int(saved.climate.projects.get(id, 0)) >= 2 or not Rules.number(raw.pending[id], 0, WORK_ACTIONS - 1, true): return false
		var paid: int = 0
		for entry in saved.ledger.entries:
			if entry.category == "protection" and entry.label == NAMES[id] and float(entry.amount) == -COSTS[id] * (int(saved.climate.projects.get(id, 0)) + 1) and int(entry.season) == 3: paid += 1
		if paid != 1: return false
	for key in raw.covers:
		if not str(key).is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) >= 72 or not saved.plots[int(key)].unlocked: return false
		var cover: Variant = raw.covers[key]
		if not cover is Dictionary or cover.size() != 2 or not Rules.number(cover.get("year"), 1, 11, true) or not Rules.number(cover.get("level"), 1, int(saved.climate.projects.get("frost", 0)), true): return false
		if int(cover.year) != int(saved.season_clock.year) + (1 if int(saved.season_clock.season) == 3 else 0) or int(saved.season_clock.season) in [1, 2]: return false
	if raw.losses.size() > 100000 or raw.policies.size() > 10 or raw.winters.size() > 10: return false
	var seen: Array = []
	for year in raw.policies:
		if not Rules.number(year, 1, int(saved.season_clock.year), true) or int(year) in seen: return false
		seen.append(int(year))
		if not _posting(saved, int(year), 0, "insurance", "Annual crop insurance", -PREMIUM): return false
	for e in raw.losses:
		if not e is Dictionary or e.size() != 13: return false
		if not Rules.number(e.get("year"), 1, int(saved.season_clock.year), true) or not Rules.number(e.get("season"), 0, 3, true): return false
		if int(e.year) == int(saved.season_clock.year) and int(e.season) > int(saved.season_clock.season): return false
		if e.get("event") not in ["drought", "flood", "storm", "freeze", "dry_bed", "pests", "autumn_cold", "lease_ended", "spoilage", "deep_freeze", "blizzard"] or e.get("crop") not in Table.IDS or e.get("source") not in ["field", "barn"]: return false
		if e.source == "barn" and e.event not in ["spoilage", "deep_freeze", "blizzard"]: return false
		if e.event in ["deep_freeze", "blizzard"] and int(e.season) != 3: return false
		if e.event == "spoilage" and e.source != "barn": return false
		if e.get("field") not in (Land.IDS if e.source == "field" else ["barn"]): return false
		if not e.get("missing") is String or e.missing.length() > 160 or not e.get("insured") is bool: return false
		for key in ["exposed", "sacks", "saved"]:
			if not Rules.number(e.get(key), 0, 100000, true): return false
		if e.get("reduction") not in REDUCTION or e.get("alternative") not in [0.0, 0.5, 0.75, 1.0] or float(e.alternative) < float(e.reduction): return false
		var exposure: float = Land.exposure(str(e.field), str(e.event)) if e.source == "field" else 1.0
		if int(e.sacks) <= 0 or int(e.sacks) != loss(int(e.exposed), float(e.reduction), exposure) or int(e.saved) != int(e.sacks) - loss(int(e.exposed), float(e.alternative), exposure): return false
		if e.insured and (int(e.year) not in seen or e.event in ["spoilage", "lease_ended"]): return false
	for group in saved.climate.operations.loss_groups.values():
		if int(group.card) >= raw.losses.size(): return false
		if int(group.card) >= 0:
			var entry: Dictionary = raw.losses[int(group.card)]
			if int(group.exposed) != int(entry.exposed) or entry.source != "field": return false
	for year in raw.winters:
		if not str(year).is_valid_int() or str(int(year)) != year or int(year) < 1 or int(year) > int(saved.season_clock.year): return false
		if int(year) == int(saved.season_clock.year) and int(saved.season_clock.season) != 3: return false
		var report: Variant = raw.winters[year]
		if not report is Dictionary or report.size() != 2 or not Rules.number(report.get("payout"), 0, INF) or not Rules.number(report.get("upkeep"), 0, UPKEEP * PROJECT_FOR.size()): return false
		var expected: float = 0.0
		for entry in raw.losses:
			if int(entry.year) == int(year) and entry.insured: expected += int(entry.sacks) * float(Table.CROPS[entry.crop].base) * PAYOUT
		if not is_equal_approx(float(report.payout), expected): return false
		var upkeep: float = 0.0
		for id in PROJECT_FOR.values():
			var label: String = str(NAMES[id]) + " upkeep"
			var matches: int = 0
			for e in saved.ledger.entries:
				if int(e.year) == int(year) and e.category == "upkeep" and e.label == label:
					if int(e.season) != 3 or float(e.amount) != -UPKEEP or int(saved.climate.projects.get(id, 0)) == 0: return false
					matches += 1
			if matches > 1: return false
			upkeep += matches * UPKEEP
		if not is_equal_approx(float(report.upkeep), upkeep): return false
		var posted: float = 0.0
		for entry in saved.ledger.entries:
			if int(entry.year) == int(year) and entry.category == "insurance" and entry.label in ["Crop loss payout", "Winter crop loss payout"]:
				if int(entry.season) != 3 or float(entry.amount) <= 0: return false
				posted += float(entry.amount)
		if not is_equal_approx(posted, float(report.payout)): return false
	if int(saved.season_clock.season) == 3 and not raw.winters.has(str(int(saved.season_clock.year))): return false
	for e in saved.ledger.entries:
		if e.category == "upkeep":
			for name in NAMES.values():
				if e.label == name + " upkeep" and not raw.winters.has(str(int(e.year))): return false
		if e.category == "insurance":
			if e.label == "Annual crop insurance" and int(e.year) not in seen: return false
			if e.label in ["Crop loss payout", "Winter crop loss payout"] and (not raw.winters.has(str(int(e.year))) or float(raw.winters[str(int(e.year))].payout) <= 0): return false
	return true

static func _posting(saved: Dictionary, year: int, season: int, category: String, label: String, amount: float) -> bool:
	var count: int = 0
	for e in saved.ledger.entries:
		if int(e.year) == year and e.category == category and e.label == label:
			if int(e.season) != season or not is_equal_approx(float(e.amount), amount): return false
			count += 1
	return count == 1
