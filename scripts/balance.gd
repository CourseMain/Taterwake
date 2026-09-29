extends RefCounted
## Shared economy and climate tuning. Regression evidence: tests/test_tuning_bot.gd.
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 6.75, "base": 9.0, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 3, "grow_seasons": 1, "grow": 75.0, "yield": 3, "color": "a87b45"},
	"giant": {"name": "Giant Potato", "seed": 9.0, "base": 12.0, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 2, "grow_seasons": 1, "grow": 135.0, "yield": 5, "color": "c7855d"},
	"golden": {"name": "Golden Potato", "seed": 12.6, "base": 16.8, "volatility": "mid", "water_need": 1, "heat_tolerance": 2, "cold_tolerance": 2, "grow_seasons": 1, "grow": 105.0, "yield": 4, "color": "efc74c"},
	"sunburst": {"name": "Sunburst Potato", "seed": 17.1, "base": 22.8, "volatility": "high", "water_need": 2, "heat_tolerance": 3, "cold_tolerance": 1, "grow_seasons": 2, "grow": 195.0, "yield": 3, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 30.0, "base": 30.0, "volatility": "high", "water_need": 3, "heat_tolerance": 1, "cold_tolerance": 3, "grow_seasons": 2, "grow": 225.0, "yield": 2, "color": "aeeaff"},
}
const VOLATILITY: Dictionary = {
	"low": {"drift": 0.05, "storage_peak_factor": 1.2},
	"mid": {"drift": 0.10, "storage_peak_factor": 1.4},
	"high": {"drift": 0.15, "storage_peak_factor": 1.6},
}
const STARTING_CASH: float = 2000.0
const OVERDRAFT_LIMIT: float = -5000.0
const INITIAL_LOAN: float = 12000.0
const FIXED_COSTS: Array[Dictionary] = [
	{"category": "mortgage", "label": "Mortgage interest", "amount": -600.0},
	{"category": "mortgage", "label": "Mortgage principal", "amount": -600.0},
	{"category": "rent", "label": "Rent and land tax", "amount": -300.0},
	{"category": "living", "label": "Living costs", "amount": -800.0},
	{"category": "upkeep", "label": "Annual equipment upkeep", "amount": -300.0},
]
const TABLE_THRESHOLD: int = 80
const GRADE_MULTIPLIER := {"Table": 1.2, "Standard": 1.0, "Feed": 0.5}
const PROTECTION_COSTS: Dictionary = {"rainwater":900.0, "drainage":1200.0, "windbreaks":1500.0, "frost":900.0}
const PROTECTION_UPKEEP: float = 60.0
const INSURANCE_PREMIUM: float = 240.0
const INSURANCE_PAYOUT: float = 0.4
const PROTECTION_REDUCTION: Array[float] = [0.0, 0.5, 0.75]
const STORAGE_FEE: float = 120.0
const SPOILAGE: float = 0.05
const SHORTFALL_FEE: float = 5.0
const CLIMATE_BASE_CHANCE: float = 0.15
const CLIMATE_CHANCE_STEP: float = 0.04
const CLIMATE_MAX_CHANCE: float = 0.6
const CLIMATE_BASE_SEVERITY: float = 0.5
const CLIMATE_SEVERITY_STEP: float = 0.03
const CLIMATE_SEVERITY_SPREAD: float = 0.15
const CLIMATE_SIGNAL_CHANCE: float = 0.7
const CLIMATE_FALSE_ALARM_CHANCE: float = 0.1
const CLIMATE_ANNUAL_CAP: int = 3
const CLIMATE_WINTER_LOSS: Dictionary = {"deep_freeze": 0.20, "blizzard": 0.30}
const FIELD_EXPANSION_COST: float = 1200.0
const CONTRACT_QUANTITY: int = 20
const CONTRACT_PRICE_FACTOR: float = 1.1
# Winter diversification, available from year three. Payments start next Winter.
const DIVERSIFY_YEAR: int = 3
const BUSINESS_COSTS: Dictionary = {"shop": 3000.0, "grower": 0.0, "lodging": 2500.0}
const SHOP_INCOME: float = 800.0
const SHOP_SUMMER_SECONDS: float = 30.0
const LODGING_INCOME: float = 600.0
const GROWER_PRICE_FACTOR: float = 1.2
