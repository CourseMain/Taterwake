extends RefCounted
## Winter investments and income; every payment is part of the annual journal.
const Balance = preload("res://scripts/balance.gd")
const Rules = preload("res://scripts/save_validation.gd")
const NAMES := {"shop": "Farm shop", "grower": "Contract grower", "lodging": "Lodging"}
const BUILD_LABELS := {"shop": "Farm shop construction", "grower": "Contract grower enrolment", "lodging": "Lodging construction"}
const INCOME_LABELS := {"shop": "Farm shop income", "lodging": "Lodging income"}
var built: Dictionary = {}
var winters: Dictionary = {}

func owns(id: String) -> bool:
	return built.has(id)

func can_buy(farm, id: String) -> bool:
	return NAMES.has(id) and not owns(id) and not farm.run_over and not farm.tutorial_active and farm.season_clock.year >= Balance.DIVERSIFY_YEAR and farm.season_clock.season == 3 and farm.can_purchase(Balance.BUSINESS_COSTS[id])

func buy(farm, id: String) -> String:
	if not NAMES.has(id): return farm._finish("Choose a business in annual accounts.")
	if not can_buy(farm, id): return farm._finish("Businesses open in Winter from year three; choose an unowned, affordable business.")
	# Accounts deliberately allow this purchase while the simulation is paused.
	farm.ledger.post(farm.season_clock.year, 3, "other", BUILD_LABELS[id], -Balance.BUSINESS_COSTS[id], true)
	built[id] = farm.season_clock.year
	return farm._finish(NAMES[id] + (" enrolled. Two premium orders from next Spring." if id == "grower" else " built. First income next Winter."))

static func protection_count(projects: Dictionary) -> int:
	var count: int = 0
	for id in ["rainwater", "drainage", "windbreaks", "frost"]:
		if int(projects.get(id, 0)) > 0: count += 1
	return count

func winter(farm) -> void:
	var year: int = farm.season_clock.year
	if farm.season_clock.season != 3 or winters.has(str(year)): return
	var count: int = protection_count(farm.climate.data.projects)
	var report := {"protections": count, "shop": 0.0, "lodging": 0.0}
	if owns("shop") and int(built.shop) < year: report.shop = Balance.SHOP_INCOME
	if owns("lodging") and int(built.lodging) < year: report.lodging = Balance.LODGING_INCOME * count / 4.0
	for id in INCOME_LABELS:
		if report[id] > 0: farm.post_money("other", INCOME_LABELS[id], report[id])
	winters[str(year)] = report

static func income_entry(entry: Dictionary) -> bool:
	return float(entry.amount) > 0 and (entry.label in INCOME_LABELS.values() or str(entry.label).begins_with("Contract grower collected "))

func income(farm) -> float:
	var result: float = 0
	for entry in farm.ledger.entries:
		if income_entry(entry): result += float(entry.amount)
	return result

func title(farm) -> String:
	if farm.run_outcome == "foreclosed": return "Sold Up"
	if farm.run_outcome != "completed": return ""
	var earned: float = 0
	for entry in farm.ledger.entries:
		if entry.category in ["sales", "contracts"] or income_entry(entry): earned += maxf(0, float(entry.amount))
	if income(farm) > earned / 2.0: return "Shopkeeper"
	var count: int = protection_count(farm.climate.data.projects)
	if count >= 3: return "Adapter"
	if count == 0: return "Stubborn"
	return "Survivor"

func save_data() -> Dictionary:
	return {"built": built.duplicate(), "winters": winters.duplicate(true)}

func load_data(raw: Dictionary) -> void:
	built = raw.built.duplicate()
	winters = raw.winters.duplicate(true)

static func valid(raw: Variant, saved: Dictionary) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("built") is Dictionary or not raw.get("winters") is Dictionary: return false
	for id in raw.built:
		if not NAMES.has(id) or not Rules.number(raw.built[id], Balance.DIVERSIFY_YEAR, int(saved.season_clock.year), true): return false
		if int(raw.built[id]) == int(saved.season_clock.year) and int(saved.season_clock.season) != 3: return false
		if not _posting(saved, int(raw.built[id]), BUILD_LABELS[id], -Balance.BUSINESS_COSTS[id], true): return false
	if raw.winters.size() != saved.ledger.closed_years.size(): return false
	for year in saved.ledger.closed_years:
		var row: Variant = raw.winters.get(str(int(year)))
		if not row is Dictionary or row.size() != 3 or not Rules.number(row.get("protections"), 0, 4, true): return false
		for id in INCOME_LABELS:
			var expected: float = 0.0
			if raw.built.has(id) and int(raw.built[id]) < int(year): expected = Balance.SHOP_INCOME if id == "shop" else Balance.LODGING_INCOME * int(row.protections) / 4.0
			if row.get(id) != expected or not _posting(saved, int(year), INCOME_LABELS[id], expected): return false
	# Neither ownership nor its journal can be forged independently.
	for entry in saved.ledger.entries:
		for id in BUILD_LABELS:
			if entry.label == BUILD_LABELS[id] and (not raw.built.has(id) or int(raw.built[id]) != int(entry.year)): return false
		if entry.label in INCOME_LABELS.values() and not raw.winters.has(str(int(entry.year))): return false
	return true

static func _posting(saved: Dictionary, year: int, label: String, amount: float, zero: bool = false) -> bool:
	var count: int = 0
	for entry in saved.ledger.entries:
		if int(entry.year) == year and entry.label == label:
			if entry.category != "other" or int(entry.season) != 3 or float(entry.amount) != amount: return false
			count += 1
	return count == (1 if amount != 0 or zero else 0)
