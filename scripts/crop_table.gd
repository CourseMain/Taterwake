extends RefCounted
const Balance = preload("res://scripts/balance.gd")
## Water bars mean demand; heat/cold bars mean tolerance (higher is tougher).
const IDS: Array[String] = ["russet", "giant", "golden", "sunburst", "icecap"]
const CROPS: Dictionary = Balance.CROPS
const VOLATILITY: Dictionary = Balance.VOLATILITY
static func empty_stock() -> Dictionary:
	var stock: Dictionary = {}
	for id in IDS: stock[id] = 0
	return stock
static func drift(id: String) -> float:
	return float(VOLATILITY[CROPS[id].volatility].drift)
static func total_tolerance(id: String) -> int:
	var crop: Dictionary = CROPS[id]
	# Water resilience is the inverse of demand, alongside heat/cold resilience.
	return 4 - int(crop.water_need) + int(crop.heat_tolerance) + int(crop.cold_tolerance)
static func heat_factor(id: String) -> float:
	return 1.75 - 0.25 * float(CROPS[id].heat_tolerance)
static func cold_factor(id: String) -> float:
	return 1.75 - 0.25 * float(CROPS[id].cold_tolerance)
