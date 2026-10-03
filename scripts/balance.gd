extends RefCounted
## Shared economy and climate tuning. Regression evidence: tests/test_tuning_bot.gd.
const MONEY_SCALE: float = 40.0
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 6.75 * MONEY_SCALE, "base": 9.0 * MONEY_SCALE, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 3, "grow_seasons": 1, "grow": 60.0, "yield": 3, "color": "a87b45"},
	"giant": {"name": "Giant Potato", "seed": 9.0 * MONEY_SCALE, "base": 12.0 * MONEY_SCALE, "volatility": "low", "water_need": 1, "heat_tolerance": 3, "cold_tolerance": 2, "grow_seasons": 1, "grow": 110.0, "yield": 5, "color": "c7855d"},
	"golden": {"name": "Golden Potato", "seed": 12.6 * MONEY_SCALE, "base": 16.8 * MONEY_SCALE, "volatility": "mid", "water_need": 1, "heat_tolerance": 2, "cold_tolerance": 2, "grow_seasons": 1, "grow": 90.0, "yield": 4, "color": "efc74c"},
	"sunburst": {"name": "Sunburst Potato", "seed": 17.1 * MONEY_SCALE, "base": 22.8 * MONEY_SCALE, "volatility": "high", "water_need": 2, "heat_tolerance": 3, "cold_tolerance": 1, "grow_seasons": 2, "grow": 160.0, "yield": 3, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 30.0 * MONEY_SCALE, "base": 30.0 * MONEY_SCALE, "volatility": "high", "water_need": 3, "heat_tolerance": 1, "cold_tolerance": 3, "grow_seasons": 2, "grow": 200.0, "yield": 2, "color": "aeeaff"},
}
const VOLATILITY: Dictionary = {
	"low": {"drift": 0.05, "storage_peak_factor": 1.2},
	"mid": {"drift": 0.10, "storage_peak_factor": 1.4},
	"high": {"drift": 0.15, "storage_peak_factor": 1.6},
}
const STARTING_CASH: float = 2000.0 * MONEY_SCALE
const OVERDRAFT_LIMIT: float = -5000.0 * MONEY_SCALE
const INITIAL_LOAN: float = 12000.0 * MONEY_SCALE
const FIXED_COSTS: Array[Dictionary] = [
	{"category": "mortgage", "label": "Mortgage interest", "amount": -600.0 * MONEY_SCALE},
	{"category": "mortgage", "label": "Mortgage principal", "amount": -600.0 * MONEY_SCALE},
	{"category": "rent", "label": "Rent and land tax", "amount": -300.0 * MONEY_SCALE},
	{"category": "living", "label": "Living costs", "amount": -800.0 * MONEY_SCALE},
	{"category": "upkeep", "label": "Annual equipment upkeep", "amount": -300.0 * MONEY_SCALE},
]
const TABLE_THRESHOLD: int = 80
const GRADE_MULTIPLIER := {"Table": 1.2, "Standard": 1.0, "Feed": 0.5}
const PROTECTION_COSTS: Dictionary = {"rainwater":900.0 * MONEY_SCALE, "drainage":1200.0 * MONEY_SCALE, "windbreaks":1500.0 * MONEY_SCALE, "frost":900.0 * MONEY_SCALE}
const PROTECTION_UPKEEP: float = 60.0 * MONEY_SCALE
const INSURANCE_PREMIUM: float = 240.0 * MONEY_SCALE
const INSURANCE_PAYOUT: float = 0.4
const PROTECTION_REDUCTION: Array[float] = [0.0, 0.5, 0.75]
const STORAGE_FEE: float = 120.0 * MONEY_SCALE
const SPOILAGE: float = 0.05
const SHORTFALL_FEE: float = 5.0 * MONEY_SCALE
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
const PEST_CHANCE: float = 0.16
const FIELD_RENTS := {"low": 1375.0 * MONEY_SCALE, "hill": 225.0 * MONEY_SCALE}
const FIELD_EXPANSION_COST: float = 1200.0 * MONEY_SCALE
const CONTRACT_QUANTITY: int = 20
const CONTRACT_PRICE_FACTOR: float = 1.1
# Winter diversification, available from year three. Payments start next Winter.
const DIVERSIFY_YEAR: int = 3
const BUSINESS_COSTS: Dictionary = {"shop": 3000.0 * MONEY_SCALE, "grower": 0.0 * MONEY_SCALE, "lodging": 2500.0 * MONEY_SCALE}
const SHOP_INCOME: float = 850.0 * MONEY_SCALE
const SHOP_SUMMER_SECONDS: float = 30.0
const LODGING_INCOME: float = 700.0 * MONEY_SCALE
const GROWER_PRICE_FACTOR: float = 1.2

# Other purchases share the same currency scale; counts and speeds stay local.
const TOOL_COSTS: Dictionary = {"hoe": [300.0 * MONEY_SCALE, 600.0 * MONEY_SCALE, 1200.0 * MONEY_SCALE], "water": [400.0 * MONEY_SCALE, 800.0 * MONEY_SCALE, 1400.0 * MONEY_SCALE], "harvest": [500.0 * MONEY_SCALE, 1000.0 * MONEY_SCALE, 1500.0 * MONEY_SCALE]}
const BARN_COSTS: Array[float] = [300.0 * MONEY_SCALE, 800.0 * MONEY_SCALE, 2000.0 * MONEY_SCALE]
const DUCK_HIRE_COST: float = 500.0 * MONEY_SCALE
const DUCK_TRAINING_COSTS: Array[float] = [800.0 * MONEY_SCALE, 1500.0 * MONEY_SCALE]
const IRRIGATION_COST: float = 500.0 * MONEY_SCALE
const STATION_COST: float = 500.0 * MONEY_SCALE
const QUEST_REWARD: float = 100.0 * MONEY_SCALE
const MAX_MONEY: float = 100000.0 * MONEY_SCALE
const DEBUG_BALANCES: Dictionary = {"Starter funds": STARTING_CASH, "Tool funds": 5000.0 * MONEY_SCALE, "Farm funds": 10000.0 * MONEY_SCALE}
