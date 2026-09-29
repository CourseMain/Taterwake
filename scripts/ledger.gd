extends RefCounted
## The purse is always opening cash plus the journal. No stored balance.
const STARTING_CASH: float = 2000.0
const OVERDRAFT_LIMIT: float = -5000.0
const INITIAL_LOAN: float = 20000.0
const CATEGORIES: Array[String] = ["sales", "seeds", "water_fuel", "labour", "upkeep", "protection", "insurance", "mortgage", "rent", "living", "storage", "contracts", "other"]
const LABELS: Dictionary = {"sales": "Crop sales", "seeds": "Seeds", "water_fuel": "Water & fuel", "labour": "Labour", "upkeep": "Equipment upkeep", "protection": "Protection", "insurance": "Insurance", "mortgage": "Mortgage", "rent": "Rent & land tax", "living": "Living costs", "storage": "Storage", "contracts": "Contracts", "other": "Other"}
# REDESIGN_PLAN §6. Interest is fixed for this ten-year model.
const FIXED_COSTS: Array[Dictionary] = [
	{"category": "mortgage", "label": "Mortgage interest", "amount": -1000.0},
	{"category": "mortgage", "label": "Mortgage principal", "amount": -1000.0},
	{"category": "rent", "label": "Rent and land tax", "amount": -500.0},
	{"category": "living", "label": "Living costs", "amount": -1500.0},
	{"category": "upkeep", "label": "Annual equipment upkeep", "amount": -500.0},
]
var _entries: Array[Dictionary] = []
var _closed_years: Array[int] = []
var entries: Array[Dictionary]:
	get: return _entries.duplicate(true)

func post(year: int, season: int, category: String, label: String, amount: float, record_zero: bool = false) -> bool:
	if year < 1 or year > 10 or season < 0 or season > 3 or category not in CATEGORIES: return false
	if label.is_empty() or label.length() > 256 or not is_finite(amount) or not is_finite(balance() + amount): return false
	if amount != 0.0 or record_zero: _entries.append({"year": year, "season": season, "category": category, "label": label, "amount": amount})
	return true

func entry_count() -> int:
	return _entries.size()

func total(year: int = 0, category: String = "") -> float:
	var result: float = 0.0
	for entry in _entries:
		if (year == 0 or int(entry.year) == year) and (category.is_empty() or entry.category == category): result += float(entry.amount)
	return result

func balance() -> float:
	return STARTING_CASH + total()

func category_totals(year: int) -> Dictionary:
	var result: Dictionary = {}
	for category in CATEGORIES: result[category] = total(year, category)
	return result

func year_totals(through_year: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for year in range(1, clampi(through_year, 1, 10) + 1):
		result.append({"year": year, "net": total(year), "closed": is_closed(year)})
	return result

func best_year() -> Dictionary:
	return _extreme_year(true)

func worst_year() -> Dictionary:
	return _extreme_year(false)

func _extreme_year(best: bool) -> Dictionary:
	var result: Dictionary = {}
	for year in _closed_years:
		var net: float = total(year)
		if result.is_empty() or (net > float(result.net) if best else net < float(result.net)):
			result = {"year": year, "net": net}
	return result

func years_in_profit() -> int:
	var count: int = 0
	for year in _closed_years:
		if total(year) > 0.0: count += 1
	return count

func is_closed(year: int) -> bool:
	return year in _closed_years

func fixed_cost_total() -> float:
	var amount: float = 0.0
	for cost in FIXED_COSTS: amount -= float(cost.amount)
	return amount

func post_fixed_costs(year: int) -> bool:
	if is_closed(year) or year < 1 or year > 10: return false
	for cost in FIXED_COSTS: post(year, 3, cost.category, cost.label, cost.amount)
	_closed_years.append(year)
	return true

func loan_remaining() -> float:
	return INITIAL_LOAN + _closed_years.size() * float(FIXED_COSTS[1].amount)

func save_data() -> Dictionary:
	return {"entries": entries, "closed_years": _closed_years.duplicate()}

func load_data(data: Dictionary) -> void:
	_entries.assign(data.entries.duplicate(true))
	for entry in _entries:
		entry.year = int(entry.year)
		entry.season = int(entry.season)
		entry.amount = float(entry.amount)
	_closed_years.clear()
	for year in data.closed_years: _closed_years.append(int(year))

static func valid(raw: Variant, current_year: int, current_season: int) -> bool:
	if not raw is Dictionary or not raw.get("entries") is Array or not raw.get("closed_years") is Array: return false
	var rules = preload("res://scripts/save_validation.gd")
	var balance: float = STARTING_CASH
	for entry in raw.entries:
		if not entry is Dictionary or entry.size() != 5: return false
		if not rules.number(entry.get("year"), 1, current_year, true) or not rules.number(entry.get("season"), 0, 3, true): return false
		if int(entry.year) == current_year and int(entry.season) > current_season: return false
		if entry.get("category") not in CATEGORIES or not entry.get("label") is String or entry.label.is_empty() or entry.label.length() > 256: return false
		if not (entry.get("amount") is float or entry.get("amount") is int) or not is_finite(float(entry.amount)): return false
		balance += float(entry.amount)
		if not is_finite(balance): return false
	var seen: Array[int] = []
	for year in raw.closed_years:
		if not rules.number(year, 1, current_year, true) or int(year) in seen: return false
		if int(year) == current_year and current_season != 3: return false
		seen.append(int(year))
		for cost in FIXED_COSTS:
			var matches: int = 0
			for entry in raw.entries:
				if int(entry.year) == int(year) and int(entry.season) == 3 and entry.category == cost.category and entry.label == cost.label and float(entry.amount) == float(cost.amount): matches += 1
			if matches != 1: return false
	for entry in raw.entries:
		for cost in FIXED_COSTS:
			if entry.category == cost.category and entry.label == cost.label:
				if int(entry.year) not in seen or int(entry.season) != 3 or float(entry.amount) != float(cost.amount): return false
	return true
