extends RefCounted
## Progression references, pressure limits, and ranks; never scale to player wealth.
const PROGRESSION_BASELINES: Dictionary = {1: 1000000.0, 2: 100000000000.0, 3: 5000000000000000.0}
const STOCK_REFERENCE_PERCENT: float = 0.08
const BANKRUPTCY_PERCENT: float = 0.05
const BOOMS_PER_BLIND: int = 3
const TAX_RATE: float = 0.05
const TAX_BOOM_CHANCE: float = 0.20
const TAX_BOOM_MIN: float = 1.0
const TAX_BOOM_MAX: float = 2.5
const TAX_BOOM_MAX_INCREASE: int = 150
const WEALTH_RANKS: Array[Dictionary] = [
	{"ratio": 2.0, "name": "OVERKILL"},
	{"ratio": 5.0, "name": "ULTRA KILL"},
	{"ratio": 10.0, "name": "GODLIKE"},
	{"ratio": 25.0, "name": "OMNIPOTENT"},
	{"ratio": 100.0, "name": "RULER"},
	{"ratio": 1000.0, "name": "COSMIC RULER"},
	{"ratio": 1e6, "name": "REALITY BREAKER"},
]

static func new_cycle(island: int = 1) -> Dictionary:
	return {"island": island, "kind": "small", "booms": 0, "due_in": 0.0,
		"tax_multiplier": 1.0, "tax_rolled": false, "clears": 0,
		"run_over": false, "reason": "", "last_result": {}}

static func target(cycle: Dictionary) -> float:
	return float(PROGRESSION_BASELINES[int(cycle.island)])

static func bankruptcy(island: int) -> float:
	return -float(PROGRESSION_BASELINES[island]) * BANKRUPTCY_PERCENT

static func estimated_tax(cycle: Dictionary, _balance: float = 0.0) -> float:
	return target(cycle) * TAX_RATE * float(cycle.tax_multiplier)

static func wealth_rank(ratio: float) -> String:
	var title: String = "COVERED" if ratio >= 1.0 else "SHORTFALL"
	for rank in WEALTH_RANKS:
		if ratio < float(rank.ratio):
			break
		title = str(rank.name)
	return title

static func valid_cycle(raw: Variant, max_money: float, surge_duration: float, legacy: bool = false) -> bool:
	if not raw is Dictionary:
		return false
	for key: String in ["island", "booms", "clears"]:
		if not number(raw.get(key), 0.0, 1e15, true):
			return false
	if int(raw.island) not in [1, 2, 3] or raw.get("kind") not in ["small", "big"]:
		return false
	var multiplier_cap: float = 14.0 if legacy else TAX_BOOM_MAX
	var booms_required: int = 2 if legacy else BOOMS_PER_BLIND
	if not number(raw.get("due_in"), 0.0, surge_duration) or not number(raw.get("tax_multiplier"), 1.0, multiplier_cap):
		return false
	if not raw.get("run_over") is bool or not raw.get("tax_rolled") is bool or raw.get("reason") not in ["", "bankrupt", "blind_missed", "tax_unpaid"]:
		return false
	if bool(raw.run_over) != (str(raw.reason) != "") or int(raw.booms) > booms_required:
		return false
	if not raw.run_over and ((int(raw.booms) == booms_required) != (float(raw.due_in) > 0.0)):
		return false
	if (int(raw.booms) > 0 or float(raw.tax_multiplier) > 1.0) and not raw.tax_rolled:
		return false
	var result: Variant = raw.get("last_result")
	if not result is Dictionary:
		return false
	if not result.is_empty():
		if result.get("kind") not in ["small", "big"] or not number(result.get("island"), 1.0, 3.0, true) or not result.get("cleared") is bool:
			return false
		for key: String in ["balance", "after"]:
			if not number(result.get(key), -max_money, max_money):
				return false
		for key: String in ["target", "tax", "ratio"]:
			if not number(result.get(key), 0.0, max_money):
				return false
		if not number(result.get("tax_multiplier"), 1.0, multiplier_cap):
			return false
	return true

static func number(value: Variant, low: float, high: float, whole: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not whole or float(value) == floor(float(value)))
