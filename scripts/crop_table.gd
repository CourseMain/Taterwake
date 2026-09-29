extends RefCounted
## Water bars mean demand; heat/cold bars mean tolerance (higher is tougher).
const IDS: Array[String] = ["russet", "giant", "golden", "sunburst", "icecap"]
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 11.25, "base": 15.0, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 3, "grow_seasons": 1, "grow": 75.0, "yield": 3, "color": "a87b45"},
	"giant": {"name": "Giant Potato", "seed": 13.5, "base": 18.0, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 2, "grow_seasons": 1, "grow": 135.0, "yield": 5, "color": "c7855d"},
	"golden": {"name": "Golden Potato", "seed": 15.75, "base": 21.0, "volatility": "mid", "water_need": 1, "heat_tolerance": 2, "cold_tolerance": 2, "grow_seasons": 1, "grow": 105.0, "yield": 4, "color": "efc74c"},
	"sunburst": {"name": "Sunburst Potato", "seed": 20.25, "base": 27.0, "volatility": "high", "water_need": 2, "heat_tolerance": 3, "cold_tolerance": 1, "grow_seasons": 2, "grow": 195.0, "yield": 3, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 22.5, "base": 30.0, "volatility": "high", "water_need": 3, "heat_tolerance": 1, "cold_tolerance": 3, "grow_seasons": 2, "grow": 225.0, "yield": 3, "color": "aeeaff"},
}
const VOLATILITY: Dictionary = {
	"low": {"drift": 0.05, "spring_storage_factor": 1.2},
	"mid": {"drift": 0.10, "spring_storage_factor": 1.4},
	"high": {"drift": 0.15, "spring_storage_factor": 1.6},
}
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
