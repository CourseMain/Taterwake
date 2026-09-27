class_name FarmState
extends Node

signal changed
signal notified(message: String)
signal reward_received(title: String, detail: String, rarity: String)
signal harvest_chain(count: int, multiplier: int)
signal island_changed(id: int)
signal export_changed(active: bool)
signal quest_completed(id: String)
signal purchase_completed(receipt: Dictionary)
signal sale_completed(receipt: Dictionary)
signal purchase_rejected(message: String)
signal blind_resolved(result: Dictionary)
signal tax_boom_started
signal run_ended
signal climate_changed(phase: String)

const NpcRoster = preload("res://scripts/npc_roster.gd")
const BlindRules = preload("res://scripts/blind_rules.gd")
const ClimateSystem = preload("res://scripts/climate_system.gd")
const SAVE_VERSION: int = 3
const ECONOMY_REVISION: int = 3
const MECHANICS_REVISION: int = 21
const FIELD_EXPANSION_COSTS: Dictionary = {1: 1800.0, 2: 25000000.0, 3: 1000000000000.0}
const ROCKET_MIN_MULTIPLIER: float = 351.0
const MAX_PRICE_MULTIPLIER: float = 1001.0
const ROCKET_INTERVAL: float = 1800.0
const MARKET_TICK_SECONDS: float = 5.0
const STARTER_MARKET_SECONDS: float = 3.0
const SURGE_INTERVAL: float = 180.0
const SURGE_DURATION: float = 10.0
const NATURAL_STOCK_CHANCE: float = 0.015
const BOOM_TAIL_SHAPE: float = 3.0
const LUCKY_BOOM_TAIL_SHAPE: float = 2.5
const MIN_BOOM_TAIL_SHAPE: float = 2.0
const PEST_TICK_SECONDS: float = 5.0
const ISLAND2_UNLOCK_COST: float = BlindRules.PROGRESSION_BASELINES[1]
const ISLAND2_UNLOCK_HARVEST: int = 500
const ISLAND3_UNLOCK_COST: float = BlindRules.PROGRESSION_BASELINES[2]
const ISLAND3_UNLOCK_HARVEST: int = 25000
const EXPORT_MIN_WAIT: float = 75.0
const EXPORT_MAX_WAIT: float = 180.0
const SEED_PRICE_RATIO: float = 0.75
const QUEST_TARGETS: Dictionary = {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 3.0, "mutation": 3.0, "starter_crash": 10.0, "starter_spike": 10.0, "starter_combo": 12.0, "winter_ground": 80.0, "winter_harvest": 100000.0, "winter_frost": 3.0}
const DEFAULT_SAVE_PATH: String = "user://spud_valley_save_v3.json"
const LEGACY_SAVE_PATH: String = "user://spud_valley_save.json"
const CROP_IDS: Array[String] = ["russet", "golden", "giant", "radioactive", "sunburst", "icecap"]
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 28.5, "base": 38.0, "grow": 10.0, "yield": 3, "vol": 0.08, "color": "a87b45"},
	"golden": {"name": "Golden Potato", "seed": 675.0, "base": 900.0, "grow": 25.0, "yield": 2, "vol": 0.18, "color": "efc74c"},
	"giant": {"name": "Giant Potato", "seed": 135.0, "base": 180.0, "grow": 40.0, "yield": 8, "vol": 0.12, "color": "c7855d"},
	"radioactive": {"name": "Radioactive Potato", "seed": 5100.0, "base": 6800.0, "grow": 50.0, "yield": 4, "vol": 0.35, "color": "b6f064"},
	"sunburst": {"name": "Sunburst Potato", "seed": 67500.0, "base": 90000.0, "grow": 55.0, "yield": 3, "vol": 0.26, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 1500000000.0, "base": 2000000000.0, "grow": 60.0, "yield": 4, "vol": 0.30, "color": "aeeaff"},
}
const OLD_GROW_TIMES: Dictionary = {"russet": 10.0, "golden": 30.0, "giant": 45.0, "radioactive": 90.0, "sunburst": 45.0, "icecap": 60.0}
const MAX_GROW_SECONDS: float = 60.0
const TOOL_COSTS: Dictionary = {"hoe": [300.0, 12000.0, 250000000000.0], "water": [450.0, 15000.0, 400000000000.0], "harvest": [600.0, 20000.0, 600000000000.0]}
const MUTATION_IDS: Array[String] = ["golden", "crystal", "rainbow", "radioactive"]
const MUTATION_MULTIPLIERS: Dictionary = {"golden": 25.0, "crystal": 75.0, "rainbow": 200.0, "radioactive": 500.0}
const EVENT_IDS: Array[String] = ["shortage", "crash", "golden_craze", "seed_panic", "chaos", "mystery_buyer", "supply_collapse", "seed_fair", "festival"]
const EQUIPMENT_SLOTS: Array[String] = ["head", "body", "legs", "feet", "hands", "charm"]
const TROPHY_LIMIT: int = 16
const ROLL_TIERS: Array[String] = ["common", "rare", "epic", "legendary", "mythic", "jackpot", "relic", "mystery"]
const DEBUG_MONEY_LIMIT: float = 1000000.0
const DEBUG_LUCK_LIMIT: float = 1000.0
const ARTIFACT_POOLS: Dictionary = {
	1: {"relic": ["sunstone", "almanac", "trader_token"], "mystery": ["bottomless_sack"]},
	2: {"relic": ["lens", "market_monocle", "sunstone", "trader_token"], "mystery": ["compass", "bottomless_sack"]},
	3: {"relic": ["winter_weave", "lens", "market_monocle", "almanac"], "mystery": ["aurora", "loaded_dice", "compass"]},
}
const QUEST_REWARDS: Dictionary = {
	"starter_crash": {"share": 0.005}, "starter_spike": {"share": 0.015},
	"starter_combo": {"share": 0.03, "item": "almanac"},
	"ground": {"share": 0.002}, "sunburst": {"share": 0.025}, "combo": {"share": 0.01},
	"export": {"share": 0.05}, "mutation": {"share": 0.02, "item": "lens"},
	"winter_ground": {"share": 0.002}, "winter_harvest": {"share": 0.025},
	"winter_frost": {"share": 0.05, "item": "aurora"},
}
const ITEM_CATALOG: Dictionary = {
	"sunstone": {"name": "Sunstone Medallion", "rarity": "relic", "description": "Warmth for every harvest, even in winter.", "effect": "+10% crop yield per copy", "max_count": 10},
	"almanac": {"name": "Ancient Farmer's Almanac", "rarity": "relic", "description": "Every crop teaches a little more.", "effect": "+20% harvest mastery per copy", "max_count": 5},
	"lens": {"name": "Tideglass Mutation Lens", "rarity": "relic", "description": "Find unusual potatoes in every climate.", "effect": "+35% mutation chance per copy", "max_count": 10},
	"winter_weave": {"name": "Winter-Weave Barn Lining", "rarity": "relic", "description": "Store bigger harvests on every island.", "effect": "+20% barn capacity per copy", "max_count": 10},
	"trader_token": {"name": "Old Trader's Token", "rarity": "relic", "description": "Seed merchants remember this token.", "effect": "+5% crop sale quotes per copy · seed costs follow", "max_count": 5},
	"aurora": {"name": "Aurora Heart", "rarity": "mystery", "description": "A little northern light grows inside it.", "effect": "+30% crop yield per copy", "max_count": 3},
	"compass": {"name": "Evergreen Compass", "rarity": "mystery", "description": "Its needle follows rare mutations.", "effect": "+100% mutation chance per copy", "max_count": 3},
	"bottomless_sack": {"name": "Impossible Potato Sack", "rarity": "mystery", "description": "It has more inside than outside.", "effect": "+60% barn capacity per copy", "max_count": 3},
	"straw_hat": {"name": "Harvest Straw Hat", "kind": "gear", "slot": "head", "color": "d9b457", "rarity": "rare", "bonuses": {"yield": 0.08}, "description": "Bigger harvests. One hat at a time.", "effect": "+8% crop yield while equipped", "max_count": 10},
	"lucky_cap": {"name": "Lucky Patchwork Cap", "kind": "gear", "slot": "head", "color": "ae79df", "rarity": "rare", "bonuses": {"luck": 0.25}, "description": "Lucky patches. Permanent luck caps at 10×.", "effect": "+0.25x roll, mutation and market luck while equipped", "max_count": 10},
	"traders_visor": {"name": "Trader's Visor", "kind": "gear", "slot": "head", "color": "63b982", "rarity": "epic", "bonuses": {"stock": 0.08}, "description": "Better quotes. Seed costs follow.", "effect": "+8% stock prices while equipped", "max_count": 10},
	"harvest_gloves": {"name": "Harvest Gauntlets", "kind": "gear", "slot": "hands", "color": "c28349", "rarity": "epic", "bonuses": {"yield": 0.12}, "description": "Bring home a bigger harvest.", "effect": "+12% crop yield while equipped", "max_count": 10},
	"prospectors_hat": {"name": "Prospector's Gold Hat", "kind": "gear", "slot": "head", "color": "f0c750", "rarity": "legendary", "bonuses": {"stock": 0.15}, "description": "Golden deals. Higher caps in winter.", "effect": "+15% stock prices while equipped", "max_count": 5},
	"aurora_crown": {"name": "Aurora Crown", "kind": "gear", "slot": "head", "color": "70e9e1", "rarity": "mythic", "bonuses": {"luck": 1.0}, "description": "Equip before buying: +1 free pull per purchase, including batches. Never chains.", "effect": "+1x luck and +1 free roll per purchase while equipped", "max_count": 5},
	"market_monocle": {"name": "Bull Market Monocle", "kind": "gear", "slot": "charm", "color": "ead889", "rarity": "relic", "bonuses": {"stock": 0.25}, "description": "Better crop quotes. Seed costs follow.", "effect": "+25% stock prices while equipped", "max_count": 3},
	"loaded_dice": {"name": "Impossible Lucky Dice", "kind": "gear", "slot": "charm", "color": "ce8fe8", "rarity": "mystery", "bonuses": {"luck": 2.5}, "description": "Carry your luck. Permanent luck caps at 10×.", "effect": "+2.5x roll, mutation and market luck while equipped", "max_count": 3},
	"farmer_shirt": {"name": "Fieldwork Shirt", "kind": "gear", "slot": "body", "role": "farmer", "color": "75bc60", "rarity": "rare", "bonuses": {"yield": 0.08}, "description": "Farmer build: +25% gear bonuses.", "effect": "+8% crop yield while equipped", "max_count": 5},
	"farmer_pants": {"name": "Grower's Dungarees", "kind": "gear", "slot": "legs", "role": "farmer", "color": "528449", "rarity": "rare", "bonuses": {"growth": 0.08}, "description": "Farmer build: +25% gear bonuses.", "effect": "+8% crop growth speed while equipped", "max_count": 5},
	"farmer_boots": {"name": "Field Boots", "kind": "gear", "slot": "feet", "role": "farmer", "color": "8b713f", "rarity": "rare", "bonuses": {"growth": 0.06}, "description": "Farmer build: +25% gear bonuses.", "effect": "+6% crop growth speed while equipped", "max_count": 5},
	"gambler_shirt": {"name": "High Roller Jacket", "kind": "gear", "slot": "body", "role": "gambler", "color": "b776ec", "rarity": "epic", "bonuses": {"luck": 0.35}, "description": "Gambler build: +25% gear bonuses.", "effect": "+0.35x luck while equipped", "max_count": 5},
	"gambler_pants": {"name": "Lucky Pocket Trousers", "kind": "gear", "slot": "legs", "role": "gambler", "color": "7750a8", "rarity": "epic", "bonuses": {"luck": 0.20, "mutation": 0.10}, "description": "Gambler build: +25% gear bonuses.", "effect": "+0.20x luck and +10% mutation chance while equipped", "max_count": 5},
	"gambler_boots": {"name": "Seven-League Sneakers", "kind": "gear", "slot": "feet", "role": "gambler", "color": "d398f1", "rarity": "rare", "bonuses": {"luck": 0.15}, "description": "Gambler build: +25% gear bonuses.", "effect": "+0.15x luck while equipped", "max_count": 5},
	"investor_shirt": {"name": "Market Maker Waistcoat", "kind": "gear", "slot": "body", "role": "investor", "color": "ecc15e", "rarity": "epic", "bonuses": {"stock": 0.10}, "description": "Investor build: +25% gear bonuses.", "effect": "+10% stock prices while equipped", "max_count": 5},
	"investor_pants": {"name": "Broker's Trousers", "kind": "gear", "slot": "legs", "role": "investor", "color": "98763d", "rarity": "rare", "bonuses": {"stock": 0.05}, "description": "Investor build: +25% gear bonuses.", "effect": "+5% stock prices while equipped", "max_count": 5},
	"investor_shoes": {"name": "Closing Bell Shoes", "kind": "gear", "slot": "feet", "role": "investor", "color": "d5a946", "rarity": "epic", "bonuses": {"stock": 0.07}, "description": "Investor build: +25% gear bonuses.", "effect": "+7% stock prices while equipped", "max_count": 5},
	"scientist_coat": {"name": "Mutation Lab Coat", "kind": "gear", "slot": "body", "role": "scientist", "color": "b4eeea", "rarity": "epic", "bonuses": {"mutation": 0.25}, "description": "Scientist build: +25% gear bonuses.", "effect": "+25% mutation chance while equipped", "max_count": 5},
	"scientist_pants": {"name": "Research Cargo Pants", "kind": "gear", "slot": "legs", "role": "scientist", "color": "4a969a", "rarity": "rare", "bonuses": {"mutation": 0.15}, "description": "Scientist build: +25% gear bonuses.", "effect": "+15% mutation chance while equipped", "max_count": 5},
	"scientist_boots": {"name": "Growth Lab Boots", "kind": "gear", "slot": "feet", "role": "scientist", "color": "6fdbdc", "rarity": "epic", "bonuses": {"mutation": 0.10, "growth": 0.05}, "description": "Scientist build: +25% gear bonuses.", "effect": "+10% mutation chance and +5% growth speed while equipped", "max_count": 5},
	"industrialist_overalls": {"name": "Factory Overalls", "kind": "gear", "slot": "body", "role": "industrialist", "color": "f39858", "rarity": "epic", "bonuses": {"processing": 0.25}, "description": "Industrialist build: +25% gear bonuses.", "effect": "+25% processing speed while equipped", "max_count": 5},
	"industrialist_pants": {"name": "Workshop Workpants", "kind": "gear", "slot": "legs", "role": "industrialist", "color": "a35f3d", "rarity": "rare", "bonuses": {"processing": 0.15}, "description": "Industrialist build: +25% gear bonuses.", "effect": "+15% processing speed while equipped", "max_count": 5},
	"industrialist_boots": {"name": "Steel-Toe Harvest Boots", "kind": "gear", "slot": "feet", "role": "industrialist", "color": "db8045", "rarity": "epic", "bonuses": {"processing": 0.10, "yield": 0.03}, "description": "Industrialist build: +25% gear bonuses.", "effect": "+10% processing speed and +3% crop yield while equipped", "max_count": 5},
}

const MAX_MONEY: float = 1.0e300
const MAX_INVENTORY: int = 1000000000000000

var build_system: Node = null
var activity_system: Node = null
# Progress is saved; the scene controller decides when to resume the guided lesson.
const FarmHelp = preload("res://scripts/farm_help.gd")
var farm_help = FarmHelp.new()
var npc_history: Dictionary = {}
var tutorial_progress: Dictionary = {"version": 2, "step": 0, "completed": false, "plot": 5}
var tutorial_active: bool = false
var blind_cycle: Dictionary = BlindRules.new_cycle()
var climate = ClimateSystem.new()
var _restoring_balance: bool = false
var tax_credit_eligible: bool = false
var run_over: bool:
	get: return bool(blind_cycle.run_over)
var coins: float = 240.0:
	set(value):
		if not is_finite(value) or (run_over and not _restoring_balance):
			return
		coins = clampf(value, -MAX_MONEY, MAX_MONEY)
		if coins >= 0.0:
			tax_credit_eligible = false
		if not _restoring_balance and coins < bankruptcy_limit():
			_end_run("bankrupt")
var selected_crop: String = "russet"
var tracked_seeds: Array[String] = ["russet", "golden", "giant", "radioactive"]
var surge_timer: float = SURGE_INTERVAL
var surge_remaining: float = 0.0
var surge_crop: String = "russet"
var surge_factor: float = 1.0
var surge_kind: String = "normal"
var rocket_timer: float = ROCKET_INTERVAL
var rocket_pending: bool = false
var rocket_factor: float = 1.0
var rocket_crop: String = "icecap"
var natural_remaining: float = 0.0
var natural_factor: float = 1.0
var natural_crop: String = "russet"
var seed_inventory: Dictionary = {"russet": 12, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
var storage: Dictionary = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
var capacity: int = 200
var tools: Dictionary = {"hoe": 0, "water": 0, "harvest": 0}
var plots: Array[Dictionary] = []
var current_island: int = 1
var island2_unlocked: bool = false
var island3_unlocked: bool = false
var pest_timer: float = 60.0
var frost_timer: float = 150.0
var frost_active: bool = false
var frost_cleared: int = 0
var frost_target_count: int = 12
var thaw_remaining: float = 0.0
var inventory_items: Dictionary = {}
var equipment: Dictionary = {"head": "", "body": "", "legs": "", "feet": "", "hands": "", "charm": ""}
var island_plots: Dictionary = {}
var field_expansions: Dictionary = {"2": false, "3": false}
# Older farms retain access to occupied beds beyond the new starting boundary.
var retained_beds: Dictionary = {"2": [], "3": []}
var shores_first_mutation: bool = false
var export_timer: float = 120.0
var export_factor: float = 1.0
var event_strength: float = 1.0
var lifetime_sales: float = 0.0
var island_sales: Dictionary = {"1": 0.0, "2": 0.0, "3": 0.0}
var export_active: bool = false
var export_cycles: int = 0
var export_cycle_sold: int = 0
var export_qualified_cycles: Array[int] = []
var quest_progress: Dictionary = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "mutation": 0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
var quest_claimed: Array[String] = []
var golden_hat: bool = false
var market: Dictionary = {}
var news: String = "Harvest your Russets. Catch a good price. Sell with F!"
var event_name: String = "OPEN MARKET"
var event_remaining: float = 0.0
var elapsed: float = 0.0
var combo_count: int = 0
var combo_multiplier: int = 1
var combo_time: float = 0.0
var luck: float = 1.0
var debug_luck_multiplier: float = 1.0
var debug_money_modified: bool = false
var debug_islands_modified: bool = false
var trophies: Array[Dictionary] = []
var harvest_fraction: Dictionary = {"russet": 0.0, "golden": 0.0, "giant": 0.0, "radioactive": 0.0, "sunburst": 0.0, "icecap": 0.0}
var mastery: Dictionary = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
var dex: Array[String] = []
var permanent_yield: float = 0.0
var roll_count: int = 0
var last_roll: Dictionary = {}
var last_roll_results: Array[Dictionary] = []
var last_roll_accounting: Dictionary = {}
var expansion: int = 0
var barn_level: int = 0
var mutations: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_event: String = ""
var event_crop: String = "russet"
var boost_remaining: float = 0.0
var boost_factor: float = 1.0
var pending_roll_boost: float = 0.0
var _market_core: Dictionary = {}
var _market_clock: float = 0.0
var _event_in: float = 8.0
var _relief_clock: float = 0.0
var _rolling_reward: bool = false


func _init() -> void:
	rng.randomize()
	inventory_items = _empty_items()
	pest_timer = rng.randf_range(25.0, 100.0)
	_build_starters()


func _build_starters() -> void:
	plots = []
	for index in range(24):
		var stage: int = 3 if index < 2 else (2 if index < 4 else 0)
		plots.append({"unlocked": index < 12, "stage": stage, "watered": stage > 0,
			"elapsed": 10.0 if stage == 3 else (5.0 if stage == 2 else 0.0),
			"crop": "russet", "tilled": index < 4, "pending": 0, "frozen": false, "pests": false, "pest_damage": 0.0, "ripe_age": 0.0, "plant_age": 0.0, "pest_delay": 0.0, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_destroyed": false, "yield_total": 0, "yield_taken": 0})
	island_plots = {"1": plots, "2": _empty_shores(false), "3": _empty_winter(false)}
	market.clear()
	_market_core.clear()
	for id in CROP_IDS:
		_market_core[id] = {"seed": float(CROPS[id]["seed"]), "sell": float(CROPS[id]["base"])}
		var history: Array[float] = [float(CROPS[id]["base"])]
		market[id] = {"seed": float(CROPS[id]["seed"]), "sell": float(CROPS[id]["base"]), "change": 0.0, "history": history}
	_refresh_market(false)


func _empty_shores(unlocked: bool) -> Array[Dictionary]:
	var field: Array[Dictionary] = []
	for _index in range(48):
		field.append({"unlocked": unlocked, "stage": 0, "watered": false,
			"elapsed": 0.0, "crop": "russet", "tilled": false, "pending": 0, "frozen": false, "pests": false, "pest_damage": 0.0, "ripe_age": 0.0, "plant_age": 0.0, "pest_delay": 0.0, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_destroyed": false, "yield_total": 0, "yield_taken": 0})
	return field


func _empty_winter(unlocked: bool) -> Array[Dictionary]:
	var field: Array[Dictionary] = []
	for _index in range(80):
		field.append({"unlocked": unlocked, "stage": 0, "watered": false, "elapsed": 0.0, "crop": "russet", "tilled": false, "pending": 0, "frozen": false, "pests": false, "pest_damage": 0.0, "ripe_age": 0.0, "plant_age": 0.0, "pest_delay": 0.0, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_destroyed": false, "yield_total": 0, "yield_taken": 0})
	return field


func unlock_island3() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if island3_unlocked:
		return _reject_purchase("Frosthollow is already unlocked. The winter ferry is ready.")
	if not island2_unlocked or total_mastery() < ISLAND3_UNLOCK_HARVEST or coins < ISLAND3_UNLOCK_COST:
		return _reject_purchase("Frosthollow needs $100B and 25,000 harvested potatoes. Grow your Golden Shores fortune first.")
	coins -= ISLAND3_UNLOCK_COST
	island3_unlocked = true
	frost_timer = rng.randf_range(120.0, 220.0)
	_open_starting_beds(3)
	return _complete_purchase({"kind": "island", "id": "3", "name": "Frosthollow", "quantity": 1, "cost": ISLAND3_UNLOCK_COST}, "Frosthollow unlocked · 40 beds open · 40 more at Tools.")


func winter_info() -> Dictionary:
	return {"phase": "THAW AUCTION" if thaw_remaining > 0.0 else ("FROSTBREAK" if frost_active else "WINTER CALM"),
		"timer": thaw_remaining if thaw_remaining > 0.0 else frost_timer, "progress": frost_cleared,
		"target": frost_target_count, "description": "Hoe every icy bed → 1 seed + 5s of 8× Icecap prices."}


func _start_frost() -> void:
	if tutorial_active or not island3_unlocked:
		return
	frost_active = true
	frost_timer = 20.0
	frost_cleared = 0
	var remaining: Array[int] = []
	for index in range(80):
		island_plots["3"][index]["frozen"] = false
		if island_plots["3"][index]["unlocked"]:
			remaining.append(index)
	frost_target_count = 12
	for _index in range(frost_target_count):
		var pick: int = rng.randi_range(0, remaining.size() - 1)
		if str(island_plots["3"][remaining[pick]].get("variety", "")) == "frost": frost_cleared += 1
		else: island_plots["3"][remaining[pick]]["frozen"] = true
		remaining.remove_at(pick)
	if frost_cleared >= frost_target_count:
		_end_frost(true)
		return
	var icy_beds: int = frost_target_count - frost_cleared
	news = "FROSTBREAK! Hoe %d icy beds in 20 seconds. Clear the field to earn an Icecap x8 auction and a seed!" % icy_beds
	if disaster_market_active(): news = "FROSTBREAK! Hoe %d icy beds in 20 seconds to earn an Icecap seed. Disaster prices still apply." % icy_beds
	if frost_cleared > 0: news += " Frostgold sheltered %d beds." % frost_cleared
	notified.emit(news)
	changed.emit()


func _end_frost(success: bool = false) -> void:
	for plot in island_plots["3"]:
		plot["frozen"] = false
	frost_active = false
	frost_timer = rng.randf_range(120.0, 220.0)
	if success:
		thaw_remaining = 5.0
		seed_inventory["icecap"] = mini(MAX_INVENTORY, int(seed_inventory["icecap"]) + 1)
		_progress_quest("winter_frost", 1.0)
		_refresh_market()
		news = "FROST CLEARED! Icecap potatoes x8 for 5 seconds in the Thaw Auction. +1 Icecap seed: your manual work paid off!"
		if disaster_market_active(): news = "FROST CLEARED! +1 Icecap seed. The auction bonus cannot override disaster prices."
	else:
		news = "The frost melted. No challenge reward this time; your crops are safe. Prepare your Hoe for the next storm."
	notified.emit(news)
	changed.emit()


func _build_bonus(method: String, fallback: float) -> float:
	return float(build_system.call(method)) if is_instance_valid(build_system) and build_system.has_method(method) else fallback


func crop_grow_time(id: String) -> float:
	return float(CROPS[id]["grow"]) / crop_growth_speed(current_island, id)


func _growth_speed(island: int) -> float:
	var factor: float = maxf(0.1, _build_bonus("growth_factor", 1.0)) * equipment_growth_factor()
	if island == 3 and is_instance_valid(activity_system) and activity_system.has_method("growth_speed_multiplier"):
		factor *= maxf(1.0, float(activity_system.growth_speed_multiplier()))
	return factor * (1.0 if tutorial_active else climate.factor("growth", island))


func crop_growth_speed(island: int = 0, crop: String = "") -> float:
	var speed: float = _growth_speed(current_island if island == 0 else island)
	var id: String = selected_crop if crop.is_empty() else crop
	return maxf(speed, float(CROPS[id].grow) / MAX_GROW_SECONDS)


func _empty_items() -> Dictionary:
	var result: Dictionary = {}
	for id in ITEM_CATALOG:
		result[id] = 0
	return result


func item_yield_bonus() -> float:
	return int(inventory_items.get("sunstone", 0)) * 0.10 + int(inventory_items.get("aurora", 0)) * 0.30 + equipment_bonus("yield")


func item_stock_factor() -> float:
	return 1.0 + equipment_bonus("stock") + int(inventory_items.get("trader_token", 0)) * 0.05


func effective_luck() -> float:
	return normal_luck() * debug_luck_multiplier


func normal_luck() -> float:
	return clampf(luck + equipment_bonus("luck"), 1.0, 10.0)


func luck_breakdown() -> Dictionary:
	var normal: float = normal_luck()
	var total: float = effective_luck()
	return {"base": 1.0, "earned": luck - 1.0, "gear": equipment_bonus("luck"),
		"uncapped": luck + equipment_bonus("luck"), "normal": normal,
		"normal_percent": (normal - 1.0) * 100.0, "multiplier": debug_luck_multiplier,
		"total": total, "total_percent": (total - 1.0) * 100.0}

func debug_info() -> Dictionary:
	return {"luck_multiplier": debug_luck_multiplier, "normal_luck": normal_luck(), "effective_luck": effective_luck(),
		"money_modified": debug_money_modified, "islands_modified": debug_islands_modified, "active": debug_luck_multiplier > 1.0 or debug_money_modified or debug_islands_modified,
		"money_min": 0.0, "money_limit": DEBUG_MONEY_LIMIT, "luck_min": 1.0, "luck_limit": DEBUG_LUCK_LIMIT,
		"description": "Money changes once. Luck stays boosted until reset. Trophies are marked DEBUG."}


func valid_debug_settings(money_multiplier: float, luck_multiplier: float) -> bool:
	if not is_finite(money_multiplier) or not is_finite(luck_multiplier) or money_multiplier < 0.0 or money_multiplier > DEBUG_MONEY_LIMIT or luck_multiplier < 1.0 or luck_multiplier > DEBUG_LUCK_LIMIT:
		return false
	return not (coins > 0.0 and money_multiplier > 0.0 and coins * money_multiplier == 0.0)


func apply_debug(money_multiplier: float, luck_multiplier: float) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if _rolling_reward:
		return "Wait for the current roll purchase to settle."
	if not valid_debug_settings(money_multiplier, luck_multiplier):
		if is_finite(money_multiplier) and coins > 0.0 and money_multiplier > 0.0 and coins * money_multiplier == 0.0:
			return _finish("That positive multiplier is too small to keep a nonzero balance. Use x0 explicitly if you want to clear your purse.")
		return _finish("Debug ranges: money x0 to x1M, luck x1 to x1000. Decimals such as 0.1 and 1e-3 work; x0 clears your purse.")
	var previous: float = coins
	var after: float = minf(MAX_MONEY, coins * money_multiplier)
	var receipt: Dictionary = blind_cycle.last_result
	var debug_collapse: bool = after < bankruptcy_limit()
	# A Debug edit can match an old receipt exactly. Keep that history, but do
	# not let the synchronous collapse snapshot treat it as a new collection.
	if debug_collapse: blind_cycle.last_result = {}
	coins = after
	if debug_collapse: blind_cycle.last_result = receipt
	debug_money_modified = debug_money_modified or coins != previous
	debug_luck_multiplier = luck_multiplier
	return _finish("DEBUG applied: purse %s; luck %.2fx (normal %.2fx x debug %.2fx). Money was multiplied once." % [money(coins), effective_luck(), normal_luck(), debug_luck_multiplier])


func debug_set_balance(amount: float) -> String:
	if run_over:
		return _finish("Use Recover test farm to resume this ended run.")
	if _rolling_reward or rocket_pending:
		return _finish("Finish the current event before changing the test balance.")
	if not is_finite(amount) or amount < 0.0 or amount > MAX_MONEY:
		return _finish("Enter a test balance from 0 to 1e300.")
	debug_money_modified = debug_money_modified or coins != amount
	coins = amount
	return _finish("DEBUG: balance set to %s. Progress kept; taxes still apply." % money(coins, true))


func debug_recover(amount: float) -> String:
	# The scene controller authenticates this explicit test-only action. Ordinary
	# rewards and purchases still cannot change an ended run's balance.
	if not run_over:
		return _finish("This farm is still running. Use Set balance for test funds.")
	if _rolling_reward or not is_finite(amount) or amount <= 0.0 or amount > MAX_MONEY:
		return _finish("Recovery needs a positive test balance up to 1e300.")
	var previous: Dictionary = blind_cycle.duplicate(true)
	blind_cycle = BlindRules.new_cycle(int(previous.island))
	blind_cycle.clears = int(previous.clears)
	blind_cycle.last_result = previous.last_result.duplicate(true)
	debug_money_modified = true
	coins = amount
	climate.data.collapse.clear()
	climate.data.tax_events.clear()
	surge_timer = SURGE_INTERVAL
	surge_remaining = 0.0
	surge_factor = 1.0
	surge_kind = "normal"
	_refresh_market(false)
	return _finish("DEBUG: farm recovered with %s. Progress kept; three fresh stocks before tax. Future trophies remain DEBUG." % money(coins, true))


func debug_unlock_island(id: int) -> String:
	if run_over or _rolling_reward or rocket_pending:
		return _finish("Finish the current event before unlocking islands.")
	if id not in [2, 3]: return _finish("Choose Golden Shores or Frosthollow.")
	if (id == 2 and island2_unlocked) or (id == 3 and island3_unlocked):
		return _finish("That island is already unlocked.")
	debug_islands_modified = true
	if not island2_unlocked:
		island2_unlocked = true
		export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT)
		_open_starting_beds(2)
	if id == 3:
		island3_unlocked = true
		frost_timer = rng.randf_range(120.0, 220.0)
		_open_starting_beds(3)
	return _finish("DEBUG: %s unlocked; cash unchanged. Visiting raises base tax to %s, even after returning. Set test funds before travelling." % [("Golden Shores" if id == 2 else "Golden Shores and Frosthollow"), money(float(BlindRules.PROGRESSION_BASELINES[id]) * BlindRules.TAX_RATE, true)])

func reset_debug() -> String:
	if _rolling_reward:
		return "Wait for the current roll purchase to settle."
	debug_luck_multiplier = 1.0
	return _finish("Debug luck reset to x1. Your current coins are unchanged.%s" % (" Earlier coin edits remain marked in future trophy results." if debug_money_modified else ""))


func crown_bonus_active() -> bool:
	return str(equipment.get("head", "")) == "aurora_crown" and int(inventory_items.get("aurora_crown", 0)) > 0


func trophy_info() -> Array[Dictionary]:
	return trophies.duplicate(true)


func roll_accounting_info() -> Dictionary:
	return last_roll_accounting.duplicate(true)


func _trophy_key(result: Dictionary) -> String:
	return ("debug:" if bool(result.get("debug", false)) else "earned:") + str(result.get("item_id", "")) + ":" + str(result["tier"]) + ":" + str(result["title"])


func _trophy_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_priority: int = ROLL_TIERS.find(str(a["tier"]))
	var b_priority: int = ROLL_TIERS.find(str(b["tier"]))
	if a_priority != b_priority:
		return a_priority > b_priority
	if not is_equal_approx(float(a["best_probability"]), float(b["best_probability"])):
		return float(a["best_probability"]) < float(b["best_probability"])
	return str(a["key"]) < str(b["key"])


func _record_roll_trophy(result: Dictionary) -> void:
	if str(result["tier"]) == "common":
		return
	var key: String = _trophy_key(result)
	var probability: float = float(result["tier_probability"])
	for entry in trophies:
		if str(entry["key"]) != key:
			continue
		entry["count"] = mini(MAX_INVENTORY, int(entry["count"]) + 1)
		if probability < float(entry["best_probability"]):
			entry["best_probability"] = probability
			entry["roll_number"] = int(result["roll_number"])
			entry["island"] = current_island
		trophies.sort_custom(_trophy_precedes)
		return
	trophies.append({"key": key, "item_id": str(result.get("item_id", "")), "tier": str(result["tier"]), "title": str(result["title"]), "count": 1,
		"best_probability": probability, "roll_number": int(result["roll_number"]), "island": current_island, "debug": bool(result["debug"])})
	trophies.sort_custom(_trophy_precedes)
	if trophies.size() > TROPHY_LIMIT:
		trophies.resize(TROPHY_LIMIT)


func best_gear_hat() -> String:
	# Kept for callers that used the former auto-worn highest-rarity hat.
	return str(equipment.get("head", ""))


func _empty_equipment() -> Dictionary:
	var slots: Dictionary = {}
	for slot in EQUIPMENT_SLOTS:
		slots[slot] = ""
	return slots


func equipment_loadout() -> Dictionary:
	return equipment.duplicate()


func equipment_synergy(id: String) -> float:
	if not ITEM_CATALOG.has(id) or not ITEM_CATALOG[id].has("role") or not is_instance_valid(build_system):
		return 1.0
	return 1.25 if str(build_system.get("active")) == str(ITEM_CATALOG[id]["role"]) else 1.0


func equipment_bonus(stat: String) -> float:
	var total: float = 0.0
	for slot in EQUIPMENT_SLOTS:
		var id: String = str(equipment.get(slot, ""))
		if not ITEM_CATALOG.has(id) or int(inventory_items.get(id, 0)) <= 0 or str(ITEM_CATALOG[id].get("slot", "")) != slot:
			continue
		total += float(ITEM_CATALOG[id].get("bonuses", {}).get(stat, 0.0)) * equipment_synergy(id)
	return total


func equipment_growth_factor() -> float:
	return 1.0 + equipment_bonus("growth")


func equipment_mutation_factor() -> float:
	return 1.0 + equipment_bonus("mutation")


func equipment_processing_factor() -> float:
	return 1.0 + equipment_bonus("processing")


func equipment_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot in EQUIPMENT_SLOTS:
		var id: String = str(equipment.get(slot, ""))
		var empty: bool = id.is_empty()
		var entry: Dictionary = {} if empty else ITEM_CATALOG[id].duplicate(true)
		entry.merge({"slot": slot, "id": id, "item": id, "kind": "gear", "empty": empty, "equipped": not empty, "active": not empty, "count": int(inventory_items.get(id, 0)), "synergy": equipment_synergy(id)}, true)
		if empty:
			entry.merge({"name": "Empty " + slot.capitalize(), "effect": "Equip owned gear in this slot", "description": "One item per slot. Extra copies do not stack.", "stats": {}}, true)
		else:
			entry["stats"] = entry["bonuses"].duplicate()
			entry["action"] = "gear:unequip:" + slot
		entries.append(entry)
	return entries


func equip_gear(id: String) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not ITEM_CATALOG.has(id) or str(ITEM_CATALOG[id].get("kind", "")) != "gear" or not EQUIPMENT_SLOTS.has(str(ITEM_CATALOG[id].get("slot", ""))):
		return _finish("Choose a wearable piece of gear from your inventory.")
	if int(inventory_items.get(id, 0)) <= 0:
		return _finish("You do not own this gear yet. Find it in the Roll House.")
	var slot: String = str(ITEM_CATALOG[id]["slot"])
	if str(equipment[slot]) == id:
		return _finish("%s is already equipped." % ITEM_CATALOG[id]["name"])
	equipment[slot] = id
	_refresh_market(false)
	return _finish("Equipped %s. %s.%s" % [ITEM_CATALOG[id]["name"], ITEM_CATALOG[id]["effect"], " Matching build: bonuses are 25% stronger." if equipment_synergy(id) > 1.0 else ""])


func unequip_gear(slot: String) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not EQUIPMENT_SLOTS.has(slot):
		return _finish("Choose a valid equipment slot.")
	var id: String = str(equipment[slot])
	if id.is_empty():
		return _finish("Your %s slot is already empty." % slot)
	equipment[slot] = ""
	_refresh_market(false)
	return _finish("Unequipped %s. It is still in your inventory." % ITEM_CATALOG[id]["name"])


func _migrate_equipment() -> void:
	equipment = _empty_equipment()
	var rarity_order: Array[String] = ["rare", "epic", "legendary", "mythic", "relic", "mystery"]
	for id in ITEM_CATALOG:
		if int(inventory_items.get(id, 0)) <= 0 or not ITEM_CATALOG[id].has("slot"):
			continue
		var slot: String = str(ITEM_CATALOG[id]["slot"])
		var current: String = str(equipment[slot])
		if current.is_empty() or rarity_order.find(str(ITEM_CATALOG[id]["rarity"])) > rarity_order.find(str(ITEM_CATALOG[current]["rarity"])):
			equipment[slot] = id


func item_mastery_bonus() -> float:
	return int(inventory_items.get("almanac", 0)) * 0.20


func item_mutation_factor() -> float:
	return (1.0 + int(inventory_items.get("lens", 0)) * 0.35 + int(inventory_items.get("compass", 0)) * 1.0) * equipment_mutation_factor()


func item_seed_factor() -> float:
	return 1.0 - int(inventory_items.get("trader_token", 0)) * 0.02


func item_barn_factor() -> float:
	return 1.0 + int(inventory_items.get("winter_weave", 0)) * 0.20 + int(inventory_items.get("bottomless_sack", 0)) * 0.60


func _recompute_capacity() -> void:
	var base: int = 200
	for level in range(barn_level):
		base += int(200.0 * pow(4.0, level))
	capacity = mini(MAX_INVENTORY, int(floor(base * item_barn_factor() + 0.000001)))


func _grant_item(id: String, duplicate_refund: float = 0.0) -> String:
	if not ITEM_CATALOG.has(id):
		return "Unknown collectible."
	var item: Dictionary = ITEM_CATALOG[id]
	if int(inventory_items.get(id, 0)) >= int(item["max_count"]):
		var refund: float = clampf(duplicate_refund, 0.0, MAX_MONEY) if is_finite(duplicate_refund) else 0.0
		coins = minf(MAX_MONEY, coins + refund)
		return "%s collection complete.%s" % [item["name"], " Duplicate traded for %s." % money(refund) if refund > 0.0 else " You already own the maximum number of copies."]
	inventory_items[id] = int(inventory_items.get(id, 0)) + 1
	var is_gear: bool = str(item.get("kind", "")) == "gear"
	var auto_equipped: bool = is_gear and str(equipment.get(str(item.get("slot", "")), "")).is_empty()
	if auto_equipped:
		equipment[str(item["slot"])] = id
	_recompute_capacity()
	_refresh_market()
	if is_gear:
		return "%s collected! %s. %s Extra copies do not stack." % [item["name"], item["effect"], "Equipped in your empty %s slot." % item["slot"] if auto_equipped else "Stored in Inventory."]
	return "%s collected! %s. Permanently active on every island." % [item["name"], item["effect"]]


func inventory_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for crop in CROP_IDS:
		if int(seed_inventory[crop]) > 0:
			entries.append({"id": "seed:" + crop, "kind": "seed", "crop": crop, "name": str(CROPS[crop]["name"]) + " Seeds", "count": int(seed_inventory[crop]), "rarity": "seed", "description": "Plant on an island where this crop is available.", "effect": "Select these seeds for planting", "active": selected_crop == crop, "action": "crop:" + crop})
		if int(storage[crop]) > 0:
			entries.append({"id": "crop:" + crop, "kind": "crop", "crop": crop, "name": CROPS[crop]["name"], "count": int(storage[crop]), "rarity": "crop", "description": "Harvested potatoes held for the live market.", "effect": "Sell or hold", "active": true, "sell_value": float(market[crop]["sell"]) * int(storage[crop])})
	for crate in mutations:
		entries.append({"id": "mutation:" + str(crate["crop"]) + ":" + str(crate["id"]), "kind": "mutation", "crop": crate["crop"], "name": crate["name"], "count": crate["count"], "rarity": "mutation", "description": "A rare potato stored in your barn.", "effect": "x%s crop market value" % format_number(crate["multiplier"]), "active": true, "sell_value": float(market[crate["crop"]]["sell"]) * float(crate["multiplier"]) * int(crate["count"])})
	for id in ITEM_CATALOG:
		if int(inventory_items.get(id, 0)) <= 0:
			continue
		var entry: Dictionary = ITEM_CATALOG[id].duplicate(true)
		entry.merge({"id": id, "item": id, "kind": str(entry.get("kind", "relic")), "count": int(inventory_items[id]), "active": true}, true)
		if entry["kind"] == "gear":
			var slot: String = str(entry["slot"])
			var equipped: bool = str(equipment[slot]) == str(id)
			entry.merge({"equipped": equipped, "active": equipped, "synergy": equipment_synergy(id), "action": "gear:unequip:" + slot if equipped else "gear:equip:" + str(id)}, true)
		entries.append(entry)
	if is_instance_valid(build_system) and build_system.has_method("inventory_info"):
		for entry in build_system.inventory_info():
			entries.append(entry)
	return entries


func field_columns() -> int:
	return 10 if current_island == 3 else (8 if current_island == 2 else 6)


func field_rows() -> int:
	return 8 if current_island == 3 else (6 if current_island == 2 else 4)


func island_name() -> String:
	return "FROSTHOLLOW" if current_island == 3 else ("GOLDEN SHORES" if current_island == 2 else "SPUD VALLEY")


func available_crops() -> Array[String]:
	var result: Array[String] = ["russet", "golden", "giant", "radioactive"]
	if current_island >= 2 and island2_unlocked:
		result.append("sunburst")
	if current_island == 3 and island3_unlocked:
		result.append("icecap")
	return result


func market_tick_seconds() -> float:
	return STARTER_MARKET_SECONDS if current_island == 1 else MARKET_TICK_SECONDS


func tracked_seed_ids() -> Array[String]:
	var result: Array[String] = []
	for id in tracked_seeds:
		if available_crops().has(id):
			result.append(id)
	return result


func set_tracked_seed(id: String, enabled: bool) -> bool:
	if not available_crops().has(id):
		return false
	if enabled and not tracked_seeds.has(id):
		tracked_seeds.append(id)
	elif not enabled:
		tracked_seeds.erase(id)
	changed.emit()
	return true


func bankruptcy_limit() -> float:
	return BlindRules.bankruptcy(int(blind_cycle.island))


func blind_info() -> Dictionary:
	var tax_multiplier: float = minf(BlindRules.TAX_BOOM_MAX, float(blind_cycle.tax_multiplier) + climate.tax_pressure())
	var tax: float = BlindRules.target(blind_cycle) * BlindRules.TAX_RATE * tax_multiplier
	return {"kind": blind_cycle.kind, "name": "TAXES",
		"island": blind_cycle.island, "target": tax, "current": coins,
		"base_target": BlindRules.target(blind_cycle), "base_tax": BlindRules.target(blind_cycle) * BlindRules.TAX_RATE,
		"ratio": coins / tax, "cleared": coins >= tax, "tax": tax,
		"rank": BlindRules.wealth_rank(coins / tax),
		"projected": clampf(coins - tax, -MAX_MONEY, MAX_MONEY),
		"bankruptcy": bankruptcy_limit(), "tax_boom": tax_multiplier > 1.0,
		"climate_pressure": climate.tax_pressure(), "tax_multiplier": tax_multiplier, "booms": blind_cycle.booms,
		"booms_required": BlindRules.BOOMS_PER_BLIND, "due_in": blind_cycle.due_in,
		"run_over": run_over, "reason": blind_cycle.reason, "last_result": blind_cycle.last_result}


func blind_progress_text(ratio: float) -> String:
	if ratio >= 2.0:
		return format_number(ratio) + "× " + BlindRules.wealth_rank(ratio)
	if ratio < 0.0: return "Debt"
	var percent: float = ratio * 100.0
	if percent > 0.0 and percent < 0.01: return "<0.01%"
	return String.num(percent, 2).trim_suffix("00").trim_suffix("0").trim_suffix(".") + "%"


func stock_opportunity() -> Dictionary:
	var reference: float = float(BlindRules.PROGRESSION_BASELINES[current_island]) * BlindRules.STOCK_REFERENCE_PERCENT
	var crop: String = surge_crop if surge_remaining > 0.0 else selected_crop
	var quote: float = maxf(0.01, float(market[crop].sell))
	return {"reference": reference, "baseline": BlindRules.PROGRESSION_BASELINES[current_island],
		"crop": crop, "units": ceil(reference / quote), "quote": quote,
		"virtual": current_island == 3}


func climate_info() -> Dictionary:
	return climate.info(self)


func _promote_blind_island(id: int) -> void:
	# Returning to an old farm cannot lower the tax tier or reset its counter.
	# A first visit to a harder island gets three fresh booms to prepare its bill.
	if id <= int(blind_cycle.island):
		return
	var clears: int = int(blind_cycle.clears)
	blind_cycle = BlindRules.new_cycle(id)
	blind_cycle.clears = clears
	climate.data.tax_events.clear()


func _record_major_boom() -> void:
	if run_over or tutorial_active or float(blind_cycle.due_in) > 0.0:
		return
	if not bool(blind_cycle.tax_rolled):
		blind_cycle.tax_rolled = true
		# Warn at the FIRST boom, leaving two more major stocks to prepare.
		if rng.randf() < BlindRules.TAX_BOOM_CHANCE:
			blind_cycle.tax_multiplier = 1.0 + float(rng.randi_range(0, BlindRules.TAX_BOOM_MAX_INCREASE)) / 100.0
			if float(blind_cycle.tax_multiplier) > 1.0:
				tax_boom_started.emit()
	blind_cycle.booms = int(blind_cycle.booms) + 1
	if int(blind_cycle.booms) == BlindRules.BOOMS_PER_BLIND:
		blind_cycle.due_in = SURGE_DURATION


func _resolve_blind() -> void:
	if run_over:
		return
	var info: Dictionary = blind_info()
	var result: Dictionary = {"kind": blind_cycle.kind, "island": blind_cycle.island,
		"balance": coins, "target": info.target, "ratio": maxf(0.0, float(info.ratio)),
		"tax": info.tax, "tax_multiplier": info.tax_multiplier,
		"after": info.projected, "cleared": info.cleared}
	blind_cycle.last_result = result
	blind_cycle.due_in = 0.0
	climate.data.tax_paid = minf(MAX_MONEY, float(climate.data.tax_paid) + float(info.tax))
	# One bill is both the displayed threshold and the actual collection.
	# The balance setter makes bankruptcy immediate and gives it precedence.
	coins = float(info.projected)
	tax_credit_eligible = coins < 0.0 and not run_over
	if not run_over:
		blind_cycle.clears = int(blind_cycle.clears) + 1
		blind_cycle.kind = "big" if blind_cycle.kind == "small" else "small"
		blind_cycle.booms = 0
		blind_cycle.tax_multiplier = 1.0
		blind_cycle.tax_rolled = false
		climate.data.tax_events.clear()
	blind_resolved.emit(result.duplicate(true))
	changed.emit()


func _end_run(reason: String) -> void:
	if run_over:
		return
	blind_cycle.run_over = true
	blind_cycle.reason = reason
	climate.capture_collapse(self)
	run_ended.emit()
	changed.emit()


func surge_info() -> Dictionary:
	if disaster_market_active():
		return {"active": false, "crash": true, "timer": float(climate.data.timer), "phase": climate.data.phase,
			"crop": selected_crop, "percent": float(market[selected_crop].change), "kind": "crash",
			"rocket_timer": rocket_timer, "rocket_pending": false}
	return {"active": surge_remaining > 0.0, "timer": surge_remaining if surge_remaining > 0.0 else surge_timer,
		"crop": surge_crop if surge_remaining > 0.0 else selected_crop, "percent": float(market[surge_crop]["change"]) if surge_remaining > 0.0 else 500.0,
		"minimum": 3000 if current_island >= 3 else 500, "maximum": 10000 if current_island >= 3 else 2999,
		"rocket_timer": rocket_timer, "rocket_pending": rocket_pending, "kind": surge_kind}


func disaster_market_active() -> bool:
	return not tutorial_active and climate.data.phase in ["active", "recovery"] and int(climate.data.island) == current_island


func _clear_disaster_booms() -> void:
	# Old saves and travel can bring an already-running boom into bad weather.
	# Cancel it rather than letting it reappear after the recovery window.
	surge_remaining = 0.0
	surge_factor = 1.0
	surge_kind = "normal"
	natural_remaining = 0.0
	natural_factor = 1.0
	rocket_pending = false
	rocket_factor = 1.0
	rocket_timer = maxf(0.000001, rocket_timer)


func stock_cap() -> float:
	return 101.0 if current_island >= 3 else 30.99


func natural_stock_chance() -> float:
	return NATURAL_STOCK_CHANCE


func _natural_boom_roll(low: float, high: float) -> float:
	# Beta(1, 3): 87.5% in the bottom half; only 0.1% in the top tenth.
	# Natural strength, like its trigger chance, never depends on luck.
	return lerpf(low, high, 1.0 - pow(1.0 - rng.randf(), 1.0 / BOOM_TAIL_SHAPE))


func _boom_roll(low: float, high: float) -> float:
	# Every higher equal-width band is less likely, even at maximum luck.
	# Gear improves this smooth draw instead of clipping many rolls to the cap.
	return lerpf(low, high, 1.0 - pow(1.0 - rng.randf(), 1.0 / _boom_tail_shape()))


func _boom_tail_shape() -> float:
	var tail_shape: float = lerpf(BOOM_TAIL_SHAPE, LUCKY_BOOM_TAIL_SHAPE, (clampf(effective_luck(), 1.0, 10.0) - 1.0) / 9.0)
	return maxf(MIN_BOOM_TAIL_SHAPE, tail_shape / sqrt(clampf(item_stock_factor(), 1.0, 2.0)))


func _prepare_rocket() -> void:
	if disaster_market_active(): return
	rocket_pending = true
	rocket_timer = ROCKET_INTERVAL
	rocket_factor = _boom_roll(ROCKET_MIN_MULTIPLIER, MAX_PRICE_MULTIPLIER)
	rocket_crop = selected_crop


func complete_rocket_launch() -> void:
	if run_over or not rocket_pending or current_island < 3 or tutorial_active:
		return
	rocket_pending = false
	_start_surge(true)
	rocket_factor = 1.0
	changed.emit()


func _start_surge(rocket: bool = false) -> void:
	if run_over or tutorial_active:
		return
	if disaster_market_active():
		_clear_disaster_booms()
		surge_timer = SURGE_INTERVAL
		_refresh_market()
		# A crash supplies no selling opportunity and never advances the tax count.
		return
	var new_event: bool = surge_remaining <= 0.0 or (rocket and surge_kind != "rocket")
	surge_kind = "rocket" if rocket else "normal"
	surge_crop = rocket_crop if rocket else (selected_crop if available_crops().has(selected_crop) else "russet")
	surge_factor = rocket_factor if rocket else _boom_roll(31.0 if current_island >= 3 else 6.0, stock_cap())
	surge_remaining = SURGE_DURATION
	surge_timer = SURGE_INTERVAL
	if new_event:
		_record_major_boom()
	_refresh_market()
	notified.emit("STOCK SURGE! %s +%.0f%% for %.0f seconds!" % [CROPS[surge_crop]["name"], float(market[surge_crop]["change"]), SURGE_DURATION])


func total_mastery() -> int:
	var total: int = 0
	for id in CROP_IDS:
		total += int(mastery[id])
	return total


func unlock_island2() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if island2_unlocked:
		return _reject_purchase("Golden Shores is already unlocked. The ferry is ready whenever you are.")
	if total_mastery() < ISLAND2_UNLOCK_HARVEST or coins < ISLAND2_UNLOCK_COST:
		return _reject_purchase("Golden Shores needs $1M and 500 potatoes harvested. You have %s harvested; keep farming and selling!" % format_number(total_mastery()))
	coins -= ISLAND2_UNLOCK_COST
	island2_unlocked = true
	export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT)
	_open_starting_beds(2)
	return _complete_purchase({"kind": "island", "id": "2", "name": "Golden Shores", "quantity": 1, "cost": ISLAND2_UNLOCK_COST}, "Golden Shores unlocked · 24 beds open · 24 more at Tools.")


func travel_to(id: int) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if rocket_pending:
		return _finish("Rocket launching—boarding resumes after liftoff.")
	if id not in [1, 2, 3]:
		return _finish("The ferry visits Spud Valley, Golden Shores, and Frosthollow.")
	if id == 3 and not island3_unlocked:
		return _finish("Frosthollow needs $100B and 25,000 potatoes harvested. Finish your Golden Shores journey first.")
	if id == 2 and not island2_unlocked:
		return _finish("Unlock Golden Shores with $1M and 500 potatoes harvested before boarding.")
	if id == current_island:
		return _finish("You are already on %s." % island_name().capitalize())
	island_plots[str(current_island)] = plots
	# The carried can travels with the farmer; island tanks stay independent.
	climate.data.operations.islands[str(id)].can = ClimateSystem.Operations.local(self).can
	current_island = id
	farm_help.data.practice_remaining = 0.0
	_promote_blind_island(id)
	natural_remaining = 0.0
	natural_factor = 1.0
	if surge_kind == "rocket" and id < 3:
		surge_kind = "normal"
		surge_remaining = 0.0
		surge_factor = 1.0
	elif surge_kind == "normal":
		surge_factor = minf(surge_factor, stock_cap())
	_market_clock = fmod(_market_clock, market_tick_seconds())
	plots = island_plots[str(id)]
	combo_count = 0
	combo_multiplier = 1
	combo_time = 0.0
	if not available_crops().has(selected_crop):
		selected_crop = "russet"
	_refresh_market(false)
	harvest_chain.emit(0, 1)
	island_changed.emit(id)
	climate.on_arrival(self)
	changed.emit()
	return _finish("Welcome to %s! Both farms keep growing while you travel. Your coins, tools, seeds, and barn come with you." % island_name().capitalize())


func _toggle_export() -> void:
	if tutorial_active:
		return
	export_active = not export_active
	if export_active:
		export_cycles += 1
		export_cycle_sold = 0
		export_timer = rng.randf_range(4.0, 5.0)
		export_factor = snappedf(rng.randf_range(2.0, 6.0), 0.1)
		news = "EXPORT FLASH! Golden and Sunburst sale prices x%.1f for %.1f seconds. The ship is buying NOW!" % [export_factor, export_timer]
		if disaster_market_active(): news = "The export ship has arrived. Disaster prices still apply; check the market before selling."
	else:
		export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT)
		export_factor = 1.0
		news = "The export ship has sailed. Its price premium is gone; prepare for the next surprise shipment."
		if disaster_market_active(): news = "The export ship has sailed. The market is still recovering from the disaster."
	_refresh_market(true)
	export_changed.emit(export_active)
	notified.emit(news)
	changed.emit()


func quest_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"id": "ground", "title": "BREAK NEW GROUND", "description": "Hoe all 48 Shores beds.", "target": 48},
		{"id": "sunburst", "title": "A TASTE OF SUNSHINE", "description": "Harvest 10,000 Sunbursts by hand.", "target": 10000},
		{"id": "combo", "title": "CLEAR THE FIELD", "description": "Harvest all 48 Shores beds in one combo.", "target": 48},
		{"id": "export", "title": "CATCH THE SHIP", "description": "Sell 100+ Golden/Sunburst per Export Rush. Do it 3 times.", "target": 3},
		{"id": "mutation", "title": "STRUCK GOLD", "description": "Harvest 3 mutations on the Shores.", "target": 3},
	]
	if current_island == 1:
		entries = [
			{"id": "starter_crash", "title": "BUY THE DIP", "description": "Buy 10 seeds during a crash.", "target": 10},
			{"id": "starter_spike", "title": "SELL THE SPIKE", "description": "Sell 10 potatoes at 2× base price or better.", "target": 10},
			{"id": "starter_combo", "title": "TWELVE IN A ROW", "description": "Harvest 12 beds in one combo.", "target": 12},
		]
	elif current_island == 3:
		entries = [
			{"id": "winter_ground", "title": "BREAK THE FROZEN GROUND", "description": "Hoe all 80 new beds in Frosthollow.", "target": 80},
			{"id": "winter_harvest", "title": "WINTER HARVEST", "description": "Harvest 100,000 winter potatoes by hand.", "target": 100000},
			{"id": "winter_frost", "title": "FROSTBREAKER", "description": "Beat the clock in 3 full Frostbreaks.", "target": 3},
		]
	for entry in entries:
		var reward: Dictionary = QUEST_REWARDS[entry.id]
		entry.coins = float(BlindRules.PROGRESSION_BASELINES[current_island]) * float(reward.share)
		entry.reward_text = money(entry.coins)
		if entry.id == "starter_crash": entry.reward_text += " + 2 Golden seeds"
		elif entry.id == "ground": entry.reward_text += " + 5 Sunburst seeds"
		elif entry.id == "winter_ground": entry.reward_text += " + 5 Icecap seeds"
		elif entry.id == "mutation": entry.reward_text += " + Golden Hat"
		entry.item = str(reward.get("item", ""))
		if not entry.item.is_empty(): entry.reward_text += " + " + str(ITEM_CATALOG[entry.item].name)
		entry["progress"] = quest_progress[entry["id"]]
		entry["complete"] = float(entry["progress"]) >= float(entry["target"])
		entry["claimed"] = quest_claimed.has(str(entry["id"]))
	return entries


func _progress_quest(id: String, amount: float, take_maximum: bool = false) -> void:
	if amount <= 0.0:
		return
	for entry in quest_info():
		if entry["id"] != id or bool(entry["complete"]):
			continue
		var value: float = maxf(float(quest_progress[id]), amount) if take_maximum else float(quest_progress[id]) + amount
		quest_progress[id] = minf(float(entry["target"]), value)
		if float(quest_progress[id]) >= float(entry["target"]):
			quest_completed.emit(id)
			notified.emit("QUEST COMPLETE: %s! Collect %s at this island's quest board." % [entry["title"], entry["reward_text"]])
		return


func claim_quest(id: String) -> String:
	if run_over:
		return "Run over. Start a new farm."
	for entry in quest_info():
		if entry["id"] != id:
			continue
		if bool(entry["claimed"]):
			return _finish("This quest reward has already been collected.")
		if not bool(entry["complete"]):
			return _finish("Keep going: %s" % entry["description"])
		quest_claimed.append(id)
		coins = minf(MAX_MONEY, coins + float(entry["coins"]))
		if id == "starter_crash":
			seed_inventory["golden"] = mini(MAX_INVENTORY, int(seed_inventory["golden"]) + 2)
		if id == "ground":
			seed_inventory["sunburst"] = mini(MAX_INVENTORY, int(seed_inventory["sunburst"]) + 5)
		if id == "mutation":
			golden_hat = true
		if id == "winter_ground":
			seed_inventory["icecap"] = mini(MAX_INVENTORY, int(seed_inventory["icecap"]) + 5)
		if not str(entry.item).is_empty(): _grant_item(entry.item)
		reward_received.emit("QUEST REWARD!", "%s: %s" % [entry["title"], entry["reward_text"]], "legendary")
		return _finish("Collected %s!" % entry["reward_text"])
	return _finish("Choose a quest from this island’s board.")


func set_tutorial_active(active: bool) -> void:
	if active == tutorial_active:
		return
	tutorial_active = active
	# A repeat tour is a paused view of an established farm. Preserve every
	# timer, quote, crop and infestation so opening it cannot cleanse hazards.
	if bool(tutorial_progress.get("tour_only", false)):
		changed.emit()
		return
	# Start and finish without a queued flash, damaged lesson crop, or an
	# almost-expired countdown. Completing a lesson never ambushes the player.
	current_event = ""
	event_name = "OPEN MARKET"
	event_strength = 1.0
	event_remaining = 0.0
	_event_in = 8.0
	surge_remaining = 0.0
	surge_factor = 1.0
	surge_timer = SURGE_INTERVAL
	pest_timer = rng.randf_range(25.0, 100.0)
	surge_kind = "normal"
	natural_remaining = 0.0
	natural_factor = 1.0
	export_active = false
	export_factor = 1.0
	export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT) if island2_unlocked else 120.0
	frost_active = false
	frost_cleared = 0
	frost_timer = rng.randf_range(120.0, 220.0)
	thaw_remaining = 0.0
	boost_remaining = 0.0
	boost_factor = 1.0
	_market_clock = 0.0
	_relief_clock = 0.0
	for field in island_plots.values():
		for plot in field:
			plot["pests"] = false
			plot["pest_elapsed"] = 0.0
			plot["ripe_age"] = 0.0
			plot["plant_age"] = 0.0
			plot["pest_delay"] = 0.0
			plot["frozen"] = false
	if active:
		for id in CROP_IDS:
			var base: float = float(CROPS[id]["base"])
			_market_core[id] = {"seed": seed_price_for(base), "sell": base}
			market[id]["history"] = [base]
		news = "Take your time. Your crops are safe and the market is calm during the farm tour."
	else:
		news = "Your farm is ready. The market resumes shortly; your first stock surge is three minutes away."
	_refresh_market(false)
	export_changed.emit(false)
	changed.emit()


func spawn_tutorial_pest(index: int) -> bool:
	if not tutorial_active or bool(tutorial_progress.get("tour_only", false)) or current_island != 1 or index < 0 or index >= plots.size():
		return false
	var plot: Dictionary = plots[index]
	if not bool(plot["unlocked"]) or int(plot["stage"]) <= 0:
		return false
	# Only one harmless demonstration patch exists, even after a lesson resumes.
	for field in island_plots.values():
		for other_plot in field:
			other_plot["pests"] = false
			other_plot["pest_elapsed"] = 0.0
	plot["pests"] = true
	plot["pest_ticks"] = 0
	plot["pest_damage"] = 0.0
	plot["pest_destroyed"] = false
	plot["ripe_age"] = 0.0
	plot["plant_age"] = 0.0
	plot["pest_delay"] = 0.0
	changed.emit()
	return true


func _update_tutorial(delta: float) -> void:
	if bool(tutorial_progress.get("tour_only", false)):
		return
	var step: float = minf(delta, 3600.0)
	var dirty: bool = false
	elapsed += step
	# Keep growth genuine while freezing every source of background pressure.
	# Frozen timers never enter the ordinary event-boundary loop below.
	for field_id in island_plots:
		var growth_speed: float = _growth_speed(int(field_id))
		for plot in island_plots[field_id]:
			if plot["unlocked"] and int(plot["stage"]) in [1, 2] and plot["watered"] and not bool(plot.get("frozen", false)):
				plot["stage"] = 2
				plot["elapsed"] = minf(float(CROPS[plot["crop"]]["grow"]), float(plot["elapsed"]) + step * growth_speed)
				if float(plot["elapsed"]) >= float(CROPS[plot["crop"]]["grow"]):
					plot["stage"] = 3
					dirty = true
	if combo_time > 0.0:
		combo_time = maxf(0.0, combo_time - step)
		if combo_time < 0.000001:
			combo_time = 0.0
			combo_count = 0
			combo_multiplier = 1
			harvest_chain.emit(0, 1)
			dirty = true
	if dirty:
		changed.emit()


func update(delta: float) -> void:
	if ClimateSystem.Lesson.active(self): return
	if run_over or climate.data.intro_pending or not is_finite(delta) or delta <= 0.0:
		return
	if tutorial_active:
		if current_island == 1 and not bool(tutorial_progress.get("tour_only", false)):
			var supply: Dictionary = ClimateSystem.Operations.local(self)
			var before: float = float(supply.water)
			supply.water = minf(ClimateSystem.Operations.capacity(self, 1), before + delta * 6.0)
			if before != float(supply.water): changed.emit()
		_update_tutorial(delta)
		return
	if rocket_pending:
		return
	# Resolve timer boundaries in order, so a long frame cannot skip a price tick.
	var remaining: float = minf(delta, 3600.0)
	var dirty: bool = false
	while remaining >= 0.000001:
		farm_help.refresh_pests(self)
		var disaster_at_start: bool = disaster_market_active()
		var step: float = minf(remaining, market_tick_seconds() - _market_clock)
		if float(farm_help.data.practice_remaining) > 0.0:
			step = minf(step, float(farm_help.data.practice_remaining))
		var collecting: bool = float(blind_cycle.due_in) > 0.0
		if climate.clock_running(self): step = minf(step, minf(float(climate.data.timer), 0.25))
		if collecting:
			step = minf(step, float(blind_cycle.due_in))
		step = minf(step, 15.0 - _relief_clock)
		step = minf(step, surge_timer)
		if current_island >= 3 and not disaster_at_start:
			step = minf(step, rocket_timer)
		if natural_remaining > 0.0:
			step = minf(step, natural_remaining)
		if is_instance_valid(activity_system) and activity_system.has_method("next_boundary"):
			step = minf(step, maxf(0.000001, float(activity_system.next_boundary())))
		if surge_remaining > 0.0:
			step = minf(step, surge_remaining)
		for field in island_plots.values():
			for plot in field:
				if bool(plot.get("pests", false)) and int(plot["stage"]) > 0:
					step = minf(step, PEST_TICK_SECONDS - float(plot.get("pest_elapsed", 0.0)))
				if int(plot["stage"]) == 3 and not bool(plot.get("pests", false)):
					_schedule_pest(plot)
					var until_pest: float = maxf(40.0 - float(plot.get("plant_age", 0.0)), float(plot.pest_delay) - float(plot.ripe_age))
					if until_pest > 0.000001: step = minf(step, until_pest)
		step = minf(step, event_remaining if current_event != "" else _event_in)
		if island2_unlocked:
			step = minf(step, export_timer)
			if not export_active and export_timer > 15.0:
				step = minf(step, export_timer - 15.0)
		if current_island == 3 and island3_unlocked and climate.data.phase == "calm":
			step = minf(step, frost_timer)
		if thaw_remaining > 0.0:
			step = minf(step, thaw_remaining)
		if boost_remaining > 0.0:
			step = minf(step, boost_remaining)
		if combo_time > 0.0:
			step = minf(step, combo_time)
		step = maxf(0.000001, step)
		remaining -= step
		elapsed += step
		_market_clock += step
		_relief_clock += step
		var ripe_infestation: bool = false
		for field_id in island_plots:
			var island_growth: float = _growth_speed(int(field_id))
			for plot_index in range(island_plots[field_id].size()):
				var plot: Dictionary = island_plots[field_id][plot_index]
				if ClimateSystem.Operations.frozen(self, plot_index, int(field_id)): continue
				var growth_speed: float = maxf(island_growth, float(CROPS[plot.crop].grow) / MAX_GROW_SECONDS)
				var ripe_step: float = step if int(plot["stage"]) == 3 else 0.0
				if int(plot.stage) > 0: plot["plant_age"] = minf(1e9, float(plot.get("plant_age", 0)) + step)
				var was_infested: bool = bool(plot.get("pests", false))
				if plot["unlocked"] and int(plot["stage"]) in [1, 2] and plot["watered"] and not bool(plot.get("frozen", false)):
					plot["stage"] = 2
					var until_ripe: float = (float(CROPS[plot["crop"]]["grow"]) - float(plot["elapsed"])) / growth_speed
					ripe_step = maxf(0.0, step - until_ripe)
					plot["elapsed"] = minf(float(CROPS[plot["crop"]]["grow"]), float(plot["elapsed"]) + step * growth_speed)
					if float(plot["elapsed"]) >= float(CROPS[plot["crop"]]["grow"]):
						plot["stage"] = 3
						dirty = true
				if int(plot["stage"]) == 3:
					_schedule_pest(plot)
					plot["ripe_age"] = minf(1000000000.0, float(plot.get("ripe_age", 0.0)) + ripe_step)
					if float(plot["ripe_age"]) >= float(plot.pest_delay) - 0.000001 and float(plot.plant_age) >= 40.0 - 0.000001 and not bool(plot.get("pests", false)) and farm_help.can_infest():
						plot["pests"] = true
						plot["pest_elapsed"] = 0.0
						ripe_infestation = true
						dirty = true
				if was_infested and int(plot["stage"]) > 0:
					plot["pest_elapsed"] = float(plot.get("pest_elapsed", 0.0)) + step
					if float(plot["pest_elapsed"]) >= PEST_TICK_SECONDS - 0.000001:
						_pest_damage_tick(plot)
					dirty = true
		farm_help.capture_pests(self)
		if is_instance_valid(activity_system) and activity_system.has_method("update"):
			dirty = bool(activity_system.update(step)) or dirty
		if ripe_infestation and int(farm_help.data.pest_phase) != 1:
			notified.emit("An unattended ripe bed attracted pests! Use the Bug Sprayer: pests eat 1/3 yield every 5 seconds!")
		# Resolve weather first when a warning and stock timer share a boundary.
		if climate.update(self, step):
			_refresh_market(false)
			dirty = true
		surge_timer = maxf(0.0, surge_timer - step)
		if natural_remaining > 0.0:
			natural_remaining = maxf(0.0, natural_remaining - step)
			if natural_remaining < 0.000001:
				natural_remaining = 0.0
				natural_factor = 1.0
				_refresh_market()
				dirty = true
		if surge_remaining > 0.0:
			surge_remaining = maxf(0.0, surge_remaining - step)
			if surge_remaining < 0.000001:
				surge_remaining = 0.0
				surge_factor = 1.0
				surge_kind = "normal"
				_refresh_market()
				dirty = true
		if current_island >= 3 and not disaster_at_start:
			rocket_timer = maxf(0.0, rocket_timer - step)
		if disaster_market_active(): rocket_timer = maxf(0.000001, rocket_timer)
		var rocket_due: bool = current_island >= 3 and not disaster_market_active() and rocket_timer < 0.000001
		if surge_timer < 0.000001 and not rocket_due:
			_start_surge()
			dirty = true
		if island2_unlocked:
			var previous_export_timer: float = export_timer
			export_timer = maxf(0.0, export_timer - step)
			if not export_active and previous_export_timer > 15.000001 and export_timer <= 15.000001:
				export_timer = 15.0
				news = "EXPORT RUSH IN 15s! Get Golden and Sunburst crops ready."
				if disaster_market_active(): news = "Export ship in 15s. Disaster prices will still apply while the market recovers."
				notified.emit(news)
				dirty = true
			if export_timer < 0.000001:
				_toggle_export()
				dirty = true
		if thaw_remaining > 0.0:
			thaw_remaining = maxf(0.0, thaw_remaining - step)
			if thaw_remaining < 0.000001:
				thaw_remaining = 0.0
				_refresh_market()
				notified.emit("The Thaw Auction has ended. Icecap prices return to the ordinary market.")
				dirty = true
		if current_island == 3 and island3_unlocked and climate.data.phase == "calm":
			frost_timer = maxf(0.0, frost_timer - step)
			if frost_timer < 0.000001:
				if frost_active:
					_end_frost(false)
				else:
					_start_frost()
				dirty = true
		if combo_time > 0.0:
			combo_time = maxf(0.0, combo_time - step)
			if combo_time < 0.000001:
				combo_time = 0.0
				combo_count = 0
				combo_multiplier = 1
				harvest_chain.emit(0, 1)
				dirty = true
		if boost_remaining > 0.0:
			boost_remaining = maxf(0.0, boost_remaining - step)
			if boost_remaining < 0.000001:
				boost_remaining = 0.0
				boost_factor = 1.0
				_refresh_market()
				dirty = true
		if current_event != "":
			event_remaining = maxf(0.0, event_remaining - step)
			if event_remaining < 0.000001:
				_end_event()
				dirty = true
		else:
			_event_in = maxf(0.0, _event_in - step)
			if _event_in < 0.000001:
				_start_event()
				dirty = true
		if _market_clock >= market_tick_seconds() - 0.000001:
			_market_clock = maxf(0.0, _market_clock - market_tick_seconds())
			_market_tick()
			dirty = true
		if _relief_clock >= 15.0 - 0.000001:
			_relief_clock = maxf(0.0, _relief_clock - 15.0)
			if _seed_relief():
				dirty = true
		if farm_help.tick(self, step):
			dirty = true
		if collecting:
			blind_cycle.due_in = maxf(0.0, float(blind_cycle.due_in) - step)
			if float(blind_cycle.due_in) < 0.000001:
				_resolve_blind()
				dirty = true
				if run_over:
					rocket_timer = maxf(0.000001, rocket_timer)
					break
		if rocket_due:
			# Every clock consumes this final substep before the cinematic freezes
			# simulation. The coincident ordinary surge waits for the rocket.
			_prepare_rocket()
			surge_timer = maxf(0.000001, surge_timer)
			dirty = true
			break
	if dirty:
		changed.emit()


func _pest_damage_tick(plot: Dictionary) -> void:
	if tutorial_active or farm_help.protected_pest(self, plot):
		plot["pest_elapsed"] = 0.0
		return
	plot["pest_elapsed"] = 0.0
	plot["pest_ticks"] = mini(3, int(plot.get("pest_ticks", 0)) + 1)
	plot["pest_damage"] = float(plot["pest_ticks"]) / 3.0
	# Once harvesting has begun, damage always uses the original total, never
	# the remaining pile. Previously collected potatoes cannot be collected again.
	if int(plot.get("yield_total", 0)) > 0:
		plot["pending"] = maxi(0, int(floor(float(plot["yield_total"]) * (3 - int(plot["pest_ticks"])) / 3.0)) - int(plot.get("yield_taken", 0)))
	if int(plot["pest_ticks"]) >= 3 or (int(plot.get("yield_total", 0)) > 0 and int(plot["pending"]) == 0):
		_clear_crop(plot, true)


func _clear_crop(plot: Dictionary, destroyed: bool = false) -> void:
	plot.erase("cultivated")
	plot.erase("variety")
	plot["stage"] = 0
	plot["watered"] = false
	plot["elapsed"] = 0.0
	plot["pending"] = 0
	plot["pests"] = false
	plot["ripe_age"] = 0.0
	plot["plant_age"] = 0.0
	plot["pest_delay"] = 0.0
	plot["pest_elapsed"] = 0.0
	plot["pest_destroyed"] = destroyed
	plot["yield_total"] = 0
	plot["yield_taken"] = 0
	if not destroyed:
		plot["pest_ticks"] = 0
		plot["pest_damage"] = 0.0


func _schedule_pest(plot: Dictionary) -> void:
	if float(plot.get("pest_delay", 0)) <= 0:
		plot["pest_delay"] = rng.randf_range(15.0, 90.0)

func _infest_random_plots() -> int:
	# Retained for callers that request a pest check. No farm-wide wave.
	return 0


func affected_tiles(index: int, tool: String) -> Array[int]:
	var result: Array[int] = []
	if index < 0 or index >= plots.size():
		return result
	var action: String = tool
	if action == "plant":
		action = "hoe"
	if not tools.has(action) and action != "pest":
		return result
	var rank: int = int(tools["hoe"] if action == "pest" else tools[action])
	var columns: int = field_columns()
	var row: int = int(index / columns)
	var column: int = index % columns
	var row_radius: int = 0
	var column_radius: int = 0
	if action == "pest":
		row_radius = 2 if rank >= 3 else 1
		column_radius = row_radius
	elif action == "hoe":
		column_radius = 2 if rank >= 3 else (1 if rank > 0 else 0)
		row_radius = 2 if rank >= 3 else (1 if rank == 2 else 0)
	elif action == "water":
		row_radius = rank
		column_radius = rank
	elif action == "harvest" and rank > 0:
		column_radius = columns
		row_radius = 2 if rank >= 3 else (1 if rank == 2 else 0)
	var build_area: int = int(_build_bonus("area_bonus", 0.0))
	if action in ["hoe", "water", "pest"]:
		row_radius += build_area
		column_radius += build_area
	elif action == "harvest" and build_area > 0:
		row_radius += build_area
	for target_row in range(maxi(0, row - row_radius), mini(field_rows(), row + row_radius + 1)):
		for target_column in range(maxi(0, column - column_radius), mini(columns, column + column_radius + 1)):
			var target: int = target_row * columns + target_column
			if plots[target]["unlocked"]:
				result.append(target)
	return result


func interact_plot(index: int, tool: String = "hoe") -> String:
	if ClimateSystem.Lesson.active(self): return ClimateSystem.Lesson.water(self, index, tool)
	if run_over:
		return "Run over. Start a new farm."
	if index < 0 or index >= plots.size():
		return _finish("Choose a farm patch first.")
	if not plots[index]["unlocked"]:
		return _finish("Unlock more beds at Tools · $1.8K")
	var action: String = tool
	if action not in ["hoe", "plant", "water", "harvest", "pest"]:
		return _finish("Choose Hoe, Plant, Water, Harvest, or Bug Sprayer.")
	if action == "plant" and not available_crops().has(selected_crop):
		return _finish("Choose a seed for this island [2]")
	var climate_thawed: int = 0
	var ice_blocked: bool = false
	var affected: int = 0
	var thawed: int = 0
	var harvested: int = 0
	for target in affected_tiles(index, action):
		var plot: Dictionary = plots[target]
		var iced: bool = ClimateSystem.Operations.frozen(self, target)
		if ClimateSystem.Operations.tool(self, target, action):
			if iced: climate_thawed += 1
			affected += 1
			continue
		if iced:
			ice_blocked = true
			continue
		if action == "pest":
			if bool(plot.get("pests", false)):
				if not ClimateSystem.Operations.spend(self, "spray", 1.0): continue
				plot["pests"] = false
				plot["pest_elapsed"] = 0.0
				plot["ripe_age"] = 0.0
				plot["pest_delay"] = 0.0
				affected += 1
			continue
		if bool(plot.get("frozen", false)):
			if action == "hoe":
				plot["frozen"] = false
				frost_cleared += 1
				thawed += 1
				affected += 1
				if frost_active and frost_cleared >= frost_target_count:
					_end_frost(true)
			continue
		if action == "hoe" and int(plot["stage"]) == 0 and not plot["tilled"]:
			plot["tilled"] = true
			if current_island == 2:
				_progress_quest("ground", 1.0)
			elif current_island == 3:
				_progress_quest("winter_ground", 1.0)
			affected += 1
		elif action == "plant" and int(plot["stage"]) == 0 and plot["tilled"] and int(seed_inventory[selected_crop]) > 0:
			seed_inventory[selected_crop] = int(seed_inventory[selected_crop]) - 1
			_clear_crop(plot)
			plot["stage"] = 1
			plot["crop"] = selected_crop
			plot["elapsed"] = 0.0
			plot["watered"] = false
			plot["pending"] = 0
			if is_instance_valid(build_system): build_system.professions.planted(plot)
			farm_help.observe_plot(self, target, "plant")
			affected += 1
		elif action == "water" and int(plot["stage"]) in [1, 2] and not plot["watered"]:
			if not ClimateSystem.Operations.pour(self): continue
			plot["watered"] = true
			plot["stage"] = 2
			farm_help.observe_plot(self, target, "water")
			affected += 1
		elif action == "harvest" and int(plot["stage"]) == 3:
			var count: int = _harvest_plot(plot)
			if count > 0:
				farm_help.observe_plot(self, target, "harvest", count)
				affected += 1
				harvested += count
	farm_help.refresh_pests(self)
	if climate_thawed > 0:
		return _finish("Melted ice from %d crops · %ds of hoe heat left." % [climate_thawed, ceili(ClimateSystem.Operations.local(self).heat)])
	if ice_blocked and affected == 0:
		return _finish("Frozen crops · Visit the furnace, heat your hoe, then use Hoe [1] on the ice.")

	if affected == 0:
		if action == "water" and float(ClimateSystem.Operations.local(self).can) < 1.0:
			return _finish("Can empty · Click the tank to walk over and refill.")
		if ClimateSystem.Operations.scarce(self) and action == "pest" and float(ClimateSystem.Operations.local(self).spray) < 1.0:
			return _finish("Sprayer empty · Supplies replenish after the disaster.")
		var bed: Dictionary = plots[index]
		if bool(bed.get("frozen", false)) and action != "pest":
			return _finish("Break the ice first [1]")
		if action == "pest":
			return _finish("No pests here")
		if action == "harvest":
			if storage_used() >= capacity: return _finish("Barn full · Sell crops [F]")
			if int(bed.stage) == 0: return _finish("Nothing to harvest yet")
			return _finish("Still growing" if bed.watered else "Water this crop first [3]")
		if action == "plant":
			if int(seed_inventory[selected_crop]) == 0: return _finish("No %s seeds · Buy at Seeds [B]" % selected_crop.capitalize())
			return _finish("Already planted" if int(bed.stage) > 0 else "Till the soil first [1]")
		if action == "water":
			if int(bed.stage) == 0: return _finish("Plant a seed first [2]")
			return _finish("Ready to harvest [4]" if int(bed.stage) == 3 else "Already watered")
		return _finish("Already planted" if int(bed.stage) > 0 else "Soil ready · Plant a seed [2]")
	if action == "pest":
		return _finish("Cleared %d beds! Damage stopped. Harvest ripe crops soon." % affected)
	if action == "harvest":
		return _finish("Harvested %s potatoes from %d patches! Combo x%d. Stored in your barn; sell whenever you choose.%s" % [format_number(harvested), affected, combo_multiplier, " Barn full; any remaining harvest stays on the plant." if storage_used() >= capacity else ""])
	if action == "hoe" and thawed > 0:
		var thaw_note: String = " Crops are safe; keep clearing before the frost timer ends!"
		if thaw_remaining > 0.0:
			thaw_note = " +1 Icecap seed. Disaster prices still apply." if disaster_market_active() else " Thaw Auction: Icecap x8 for 5 seconds!"
		return _finish("Cleared ice from %d beds. %d/%d cleared.%s" % [thawed, frost_cleared, frost_target_count, thaw_note])
	if ClimateSystem.Operations.scarce(self) and action in ["hoe", "water"]:
		return _finish("Tended %d beds · watch the danger rings. Reserves in Climate action." % affected)
	if action == "hoe":
		return _finish("Tilled %d patches. Plant your selected seeds next." % affected)
	if action == "plant":
		return _finish("Planted %d %s seeds. Water them to start growing." % [affected, CROPS[selected_crop]["name"]])
	return _finish("Watered %d patches. Growth is underway; check prices, prepare soil, or visit the Roll House." % affected)


func _harvest_plot(plot: Dictionary) -> int:
	var space: int = capacity - storage_used()
	if space <= 0:
		return 0
	var id: String = str(plot["crop"])
	var first_cut: bool = int(plot.get("yield_total", 0)) == 0 and int(plot["pending"]) == 0
	if first_cut:
		combo_count += 1
		combo_multiplier = mini(16, int(pow(2.0, minf(4.0, float(combo_count - 1)))))
		combo_time = 3.5
		var yield_bonus: float = (1.0 + permanent_yield + item_yield_bonus() + _build_bonus("yield_bonus", 0.0) + minf(10.0, mastery_level(id) * 0.02)) * (3.0 if current_island == 3 else (2.0 if current_island == 2 else 1.0))
		# Keep fractional potatoes between harvests so a modest yield item really
		# earns more crops instead of being floored away on every small plant.
		if bool(plot.get("cultivated", false)): yield_bonus *= 3.0
		if str(plot.get("variety", "")) == "hearty": yield_bonus *= 1.5
		var precise_yield: float = float(CROPS[id]["yield"]) * yield_bonus * combo_multiplier + float(harvest_fraction[id])
		var whole_yield: float = floor(precise_yield + 0.000000001)
		plot["yield_total"] = maxi(1, int(whole_yield))
		harvest_fraction[id] = clampf(precise_yield - whole_yield, 0.0, 0.999999999)
		plot["yield_taken"] = 0
		plot["pending"] = maxi(0, int(floor(float(plot["yield_total"]) * (3 - int(plot.get("pest_ticks", 0))) / 3.0)))
		harvest_chain.emit(combo_count, combo_multiplier)
		if current_island == 2:
			_progress_quest("combo", float(combo_count), true)
		elif current_island == 1:
			_progress_quest("starter_combo", float(combo_count), true)
	var quantity: int = maxi(0, mini(space, int(plot["pending"])))
	if quantity == 0:
		_clear_crop(plot, true)
		return 0
	plot["yield_taken"] = int(plot.get("yield_taken", 0)) + quantity
	storage[id] = int(storage[id]) + quantity
	if is_instance_valid(build_system): build_system.professions.harvested(id, first_cut, quantity)
	mastery[id] = mini(MAX_INVENTORY, int(mastery[id]) + int(ceil(quantity * (1.0 + item_mastery_bonus()))))
	plot["pending"] = int(plot["pending"]) - quantity
	if current_island == 3:
		_progress_quest("winter_harvest", float(quantity))
	if current_island == 2 and id == "sunburst":
		_progress_quest("sunburst", float(quantity))
	if first_cut:
		var mutated: bool = false
		if current_island == 2 and id == "sunburst" and not shores_first_mutation:
			mutated = _add_mutation(id, 1, "golden", true) > 0
			shores_first_mutation = mutated
		else:
			mutated = _try_mutation(id)
		if current_island == 2 and mutated:
			_progress_quest("mutation", 1.0)
	if int(plot["pending"]) == 0:
		_clear_crop(plot)
	return quantity


func select_crop(id: String) -> String:
	if not available_crops().has(id):
		return _finish("Choose an available crop. Sunburst potatoes are exclusive to Golden Shores.")
	selected_crop = id
	return _finish("Selected %s. You have %s seeds ready to plant." % [CROPS[id]["name"], format_number(seed_inventory[id])])


static func seed_price_for(sale_price: float) -> float:
	return snappedf(sale_price * SEED_PRICE_RATIO + 1e-9, 0.01)


static func price_change(price: float, base_price: float) -> float:
	return ((price / base_price) - 1.0) * 100.0 if base_price > 0.0 else 0.0


static func crops_by_base_price(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids:
		if CROPS.has(id): result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return float(CROPS[a].base) < float(CROPS[b].base))
	return result


func market_money(value: float) -> String:
	# Keep cents explicit in small trade quotes; retain the game's large-value suffixes.
	return "$%.2f" % value if absf(value) < 1000.0 else money(value, true)


func has_tax_credit() -> bool:
	return tax_credit_eligible and coins < 0.0 and not run_over and not tutorial_active


func purchase_credit() -> float:
	return maxf(0.0, coins - bankruptcy_limit()) if has_tax_credit() else 0.0


func purchase_quote(cost: float) -> Dictionary:
	var valid_cost: bool = is_finite(cost) and cost >= 0.0
	var after: float = clampf(coins - cost, -MAX_MONEY, MAX_MONEY) if valid_cost else coins
	var borrowing: bool = valid_cost and cost > 0.0 and coins < cost and has_tax_credit()
	var affordable: bool = valid_cost and not run_over and (cost == 0.0 or coins >= cost or (borrowing and after >= bankruptcy_limit()))
	var remaining: float = maxf(0.0, after - bankruptcy_limit()) if has_tax_credit() else 0.0
	var reason: String = ""
	if not affordable:
		if run_over: reason = "Run over. Start a new farm."
		elif not valid_cost: reason = "Choose a valid purchase amount."
		elif not has_tax_credit(): reason = "Not enough cash. Buying on account is only available while repaying tax debt."
		else: reason = "Purchase blocked: it would exceed the %s bankruptcy limit. Sell crops or repay debt first." % money(-bankruptcy_limit())
	return {"affordable": affordable, "uses_credit": borrowing, "after_balance": after,
		"credit_left_after": remaining, "bankruptcy_limit": bankruptcy_limit(),
		"near_limit": borrowing and remaining <= -bankruptcy_limit() * 0.10, "reason": reason}


func can_purchase(cost: float) -> bool:
	return bool(purchase_quote(cost).affordable)


func purchase_caption(caption: String, cost: float) -> String:
	var quote: Dictionary = purchase_quote(cost)
	return caption + (" · On account" if quote.affordable and quote.uses_credit else "")


func credit_refusal(cost: float = -1.0) -> String:
	if cost >= 0.0: return str(purchase_quote(cost).reason)
	return "Account limit reached. Sell crops or repay debt first." if has_tax_credit() else "Not enough cash. Buying on account is only available while repaying tax debt."


func recovery_order() -> Dictionary:
	# A full credit line takes at most 100 ordinary potatoes to repay, on every
	# tax tier. Relief never produces cash or consumes rare mutation crates.
	var debt: float = maxf(0.0, -coins)
	var rate: float = -bankruptcy_limit() / 100.0
	var needed: int = ceili(debt / rate)
	var held: int = 0
	for crop: String in CROP_IDS: held += int(storage[crop])
	var quantity: int = mini(needed, held)
	return {"debt": debt, "rate": rate, "needed": needed, "held": held,
		"quantity": quantity, "payment": minf(debt, quantity * rate)}


func deliver_recovery() -> String:
	if run_over: return "Run over. Start a new farm."
	var order: Dictionary = recovery_order()
	if order.debt <= 0.0: return _finish("No debt to repay.")
	if order.quantity <= 0: return _finish("Harvest potatoes for the recovery order.")
	var remaining: int = int(order.quantity)
	for crop: String in crops_by_base_price(CROP_IDS):
		var amount: int = mini(remaining, int(storage[crop]))
		storage[crop] = int(storage[crop]) - amount
		if amount > 0 and is_instance_valid(build_system): build_system.professions.consumed(crop, amount)
		remaining -= amount
		if remaining == 0: break
	coins = minf(0.0, coins + float(order.payment))
	return _finish("Debt cleared." if coins >= 0.0 else "Repaid %s · %s debt left." % [money(order.payment), money(-coins)])


func can_claim_recovery_seeds() -> bool:
	if run_over or coins >= 0.0: return false
	for crop: String in CROP_IDS:
		if int(seed_inventory[crop]) > 0 or int(storage[crop]) > 0: return false
	for field in island_plots.values():
		for plot in field:
			if int(plot.stage) > 0: return false
	return true


func claim_recovery_seeds() -> String:
	if not can_claim_recovery_seeds(): return _finish("Use your existing seeds or harvest first.")
	seed_inventory.russet = 3
	return _finish("3 recovery seeds collected.")


func buy_seeds(id: String, quantity: int = 5) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not CROPS.has(id) or quantity < 1 or quantity > 1000000000:
		return _reject_purchase("Choose a crop and a positive seed quantity.")
	if not available_crops().has(id):
		return _reject_purchase("These seeds are sold on their home island. Visit its market first.")
	var cost: float = float(market[id]["seed"]) * quantity
	if not can_purchase(cost):
		return _reject_purchase(credit_refusal(cost))
	if int(seed_inventory[id]) + quantity > MAX_INVENTORY:
		return _reject_purchase("Your seed shed is full for this crop.")
	coins -= cost
	seed_inventory[id] = int(seed_inventory[id]) + quantity
	if current_island == 1 and current_event == "crash":
		_progress_quest("starter_crash", float(quantity))
	return _complete_purchase({"kind": "seeds", "id": id, "name": str(CROPS[id]["name"]).trim_suffix(" Potato"), "quantity": quantity, "cost": cost, "total": int(seed_inventory[id])}, "Bought %s %s seeds for %s at the live market price." % [format_number(quantity), CROPS[id]["name"], money(cost)])


func sell_crop(id: String, quantity: int = -1) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not CROPS.has(id) or quantity == 0 or quantity < -1:
		return _finish("Choose a crop and an amount to sell.")
	if quantity > int(storage[id]):
		return _finish("Not enough %s. You own %s; choose a smaller quantity." % [CROPS[id]["name"], format_number(storage[id])])
	var amount: int = int(storage[id]) if quantity == -1 else quantity
	if amount <= 0:
		return _finish("No %s in the barn yet. Harvest some, then decide when to sell." % CROPS[id]["name"])
	var earnings: float = float(market[id]["sell"]) * amount
	storage[id] = int(storage[id]) - amount
	if is_instance_valid(build_system): build_system.professions.consumed(id, amount)
	coins = minf(MAX_MONEY, coins + earnings)
	_record_sales(earnings)
	var sold_quote: float = float(market[id]["sell"])
	farm_help.observe_sale(self, id)
	if current_island == 1 and sold_quote >= float(CROPS[id]["base"]) * 2.0:
		_progress_quest("starter_spike", float(amount))
	if current_island == 2 and export_active and id in ["golden", "sunburst"]:
		_record_export_sale(amount)
	var message: String = _finish("Sold %s %s for %s at %s each." % [format_number(amount), CROPS[id]["name"], money(earnings), money(sold_quote)])
	sale_completed.emit({"id": id, "quantity": amount, "price": sold_quote, "total": earnings, "owned": int(storage[id])})
	return message


func sell_mutations() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if mutations.is_empty():
		return _finish("No mutation crates yet. Every manual harvest has a rare mutation chance.")
	var earnings: float = 0.0
	var quantity: int = 0
	for crate in mutations:
		earnings += float(market[crate["crop"]]["sell"]) * float(crate["multiplier"]) * int(crate["count"])
		quantity += int(crate["count"])
		if current_island == 2 and export_active and crate["crop"] in ["golden", "sunburst"]:
			_record_export_sale(int(crate["count"]))
	coins = minf(MAX_MONEY, coins + earnings)
	_record_sales(earnings)
	for crate in mutations:
		farm_help.observe_sale(self, str(crate.crop))
	mutations.clear()
	return _finish("Sold %s rare mutation potatoes for %s. PotatoDex discoveries stay unlocked." % [format_number(quantity), money(earnings)])


func _record_export_sale(amount: int) -> void:
	export_cycle_sold = mini(MAX_INVENTORY, export_cycle_sold + amount)
	if export_cycle_sold >= 100 and not export_qualified_cycles.has(export_cycles) and export_qualified_cycles.size() < 3:
		export_qualified_cycles.append(export_cycles)
		_progress_quest("export", 1.0)


func _record_sales(amount: float) -> void:
	lifetime_sales = minf(MAX_MONEY, lifetime_sales + amount)
	island_sales[str(current_island)] = minf(MAX_MONEY, float(island_sales[str(current_island)]) + amount)


func luck_stock_chance() -> float:
	return minf(0.95, 0.60 + (effective_luck() - 1.0) * 0.03 + _build_bonus("event_chance_bonus", 0.0))


func storage_used() -> int:
	var total: int = 0
	for id in CROP_IDS:
		total += int(storage[id])
	for crate in mutations:
		total += int(crate["count"])
	if is_instance_valid(build_system) and build_system.has_method("stored_count"):
		total += int(build_system.stored_count())
	return total


func barn_value() -> float:
	var total: float = 0.0
	for id in CROP_IDS:
		total += float(market[id]["sell"]) * int(storage[id])
	for crate in mutations:
		total += float(market[crate["crop"]]["sell"]) * int(crate["count"]) * float(crate["multiplier"])
	return minf(MAX_MONEY, total)


func upgrade_tool(key: String) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not TOOL_COSTS.has(key):
		return _reject_purchase("Choose a Hoe, Watering Can, or Scythe upgrade.")
	var rank: int = int(tools[key])
	if rank >= 3:
		return _reject_purchase("This tool is fully upgraded. Every action still needs your hand!")
	if rank == 2 and current_island != 3:
		return _reject_purchase("Rank 3 tools are sold in Frosthollow: unlock the winter island to upgrade further.")
	var cost: float = float(TOOL_COSTS[key][rank])
	if not can_purchase(cost):
		return _reject_purchase(credit_refusal(cost))
	coins -= cost
	tools[key] = rank + 1
	if key == "water":
		return _complete_purchase({"kind": "tool", "id": key, "name": "Bigger watering can", "quantity": 1, "cost": cost, "level": rank + 1}, "Can now carries %d water. Click the tank to fill the extra space." % int(ClimateSystem.Operations.can_capacity(self)))
	var names: Dictionary = {"hoe": "Hoe", "water": "Watering can", "harvest": "Harvest scythe"}
	return _complete_purchase({"kind": "tool", "id": key, "name": names[key], "quantity": 1, "cost": cost, "level": rank + 1}, "%s upgraded to rank %d. Your manual actions now cover a bigger area!" % [key.capitalize(), rank + 1])


func upgrade_barn() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if barn_level >= 20:
		return _reject_purchase("Your barn has reached its maximum capacity.")
	var cost: float = 500.0 * pow(5.0, barn_level)
	if not can_purchase(cost):
		return _reject_purchase(credit_refusal(cost))
	var old_capacity: int = capacity
	coins -= cost
	barn_level += 1
	_recompute_capacity()
	return _complete_purchase({"kind": "barn", "id": "barn", "name": "Barn space", "quantity": capacity - old_capacity, "cost": cost, "total": capacity, "level": barn_level}, "Barn expanded to %s potatoes. More room to hold crops for a price spike!" % format_number(capacity))


func _open_starting_beds(island: int) -> void:
	var field: Array = island_plots[str(island)]
	for index in range(field.size() / 2):
		field[index].unlocked = true


func field_expansion_info() -> Dictionary:
	var opened: int = 0
	for plot in plots:
		if plot.unlocked: opened += 1
	return {"island": current_island, "opened": opened, "total": plots.size(),
		"remaining": plots.size() - opened, "cost": float(FIELD_EXPANSION_COSTS[current_island]),
		"complete": opened == plots.size()}


func expand_field() -> String:
	if run_over:
		return "Run over. Start a new farm."
	var info: Dictionary = field_expansion_info()
	if info.complete:
		return _reject_purchase("All %d beds are already open." % int(info.total))
	if not can_purchase(float(info.cost)):
		return _reject_purchase(credit_refusal(float(info.cost)))
	coins -= float(info.cost)
	if current_island == 1: expansion = 1
	else:
		field_expansions[str(current_island)] = true
		retained_beds[str(current_island)] = []
	for plot in plots:
		plot["unlocked"] = true
	return _complete_purchase({"kind": "field", "id": "expansion", "name": "Garden beds", "quantity": int(info.remaining), "cost": float(info.cost), "total": int(info.total), "island": current_island}, "%d more beds open." % int(info.remaining))


func mastery_level(id: String) -> int:
	return int(floor(sqrt(float(mastery.get(id, 0)) / 25.0)))


func mutation_chance(id: String) -> float:
	return minf(0.25, effective_luck() * (1.0 + minf(1.0, mastery_level(id) * 0.01)) * item_mutation_factor() * _build_bonus("mutation_factor", 1.0) / 2500.0 * (6.0 if current_island == 3 else (4.0 if current_island == 2 else 1.0)))


func _try_mutation(id: String, force: bool = false) -> bool:
	if int(storage.get(id, 0)) < 1 or (not force and rng.randf() >= mutation_chance(id)):
		return false
	var kind: String = MUTATION_IDS[rng.randi_range(0, MUTATION_IDS.size() - 1)]
	return _add_mutation(id, 1, kind, true) > 0


func _add_mutation(id: String, count: int, kind: String, replace_normal: bool = false) -> int:
	if not CROPS.has(id) or not MUTATION_MULTIPLIERS.has(kind) or count <= 0:
		return 0
	var quantity: int = mini(count, int(storage[id]) if replace_normal else capacity - storage_used())
	if quantity <= 0:
		return 0
	if replace_normal:
		storage[id] = int(storage[id]) - quantity
	var combined: bool = false
	for crate in mutations:
		if crate["id"] == kind and crate["crop"] == id:
			crate["count"] = int(crate["count"]) + quantity
			combined = true
			break
	if not combined:
		mutations.append({"id": kind, "name": "%s %s" % [kind.capitalize(), CROPS[id]["name"]], "crop": id, "count": quantity, "multiplier": float(MUTATION_MULTIPLIERS[kind])})
	if not dex.has(kind):
		dex.append(kind)
	var bonus_seed: String = "radioactive" if kind == "radioactive" else ("giant" if kind == "rainbow" else "golden")
	seed_inventory[bonus_seed] = mini(MAX_INVENTORY, int(seed_inventory[bonus_seed]) + 1)
	reward_received.emit("%s MUTATION!" % kind.to_upper(), "%s rare potatoes stored at x%s market value. +1 %s seed; PotatoDex updated." % [format_number(quantity), format_number(MUTATION_MULTIPLIERS[kind]), CROPS[bonus_seed]["name"]], "mythic")
	return quantity


func roll_available() -> bool:
	if run_over:
		return false
	return not ((current_island == 1 and island2_unlocked) or (current_island == 2 and island3_unlocked))


func roll_lock_reason() -> String:
	return "This Roll House has retired. Visit your newest island for stakes that match your progress." if not roll_available() else ""


func roll_minimum_stake(kind: String = "normal") -> float:
	var base_stake: float = 20000000000000.0 if current_island == 3 else (2000000.0 if current_island == 2 else 200.0)
	match kind:
		"normal": return base_stake
		"big": return base_stake * 10.0
		"stupid": return base_stake * 100.0
		"all_in": return base_stake * (3.0 if current_island == 3 else 1.0)
	return -1.0


func roll_cost(kind: String) -> float:
	return coins if kind == "all_in" else roll_minimum_stake(kind)


func can_roll(kind: String) -> bool:
	if _rolling_reward or not roll_available() or not is_finite(coins):
		return false
	var minimum: float = roll_minimum_stake(kind)
	var bet: float = roll_cost(kind)
	if minimum <= 0.0 or not is_finite(bet) or coins < bet:
		return false
	return bet > minimum if kind == "all_in" else bet >= minimum


func stake_luck_bonus(kind: String) -> float:
	var stake: float = roll_cost(kind)
	if stake <= roll_cost("normal"):
		return 0.0
	return maxf(0.0, log(stake / roll_cost("normal")) / log(10.0) * 150.0)


func roll_odds(kind: String = "normal") -> Array[Dictionary]:
	return _roll_odds_with_stake(stake_luck_bonus(kind))


func _roll_odds_with_stake(stake_bonus: float) -> Array[Dictionary]:
	var bonus: float = effective_luck() - 1.0
	# Continue climbing the rarity ladder above the normal 10x cap. Without
	# this separation, a 1000x boost still left roughly a quarter of pulls Rare.
	var high_luck: float = maxf(1.0, effective_luck() / 10.0)
	var luck_quality: float = 1.0 + bonus * 0.12
	var stake_quality: float = (1.0 + stake_bonus / 100.0) * _build_bonus("roll_quality_factor", 1.0)
	# Luck moves probability up the rarity ladder. Multiplying every noncommon
	# tier equally only suppressed Commons and left rare-item ratios unchanged.
	var rarity_powers: Array[float] = [0.0, 1.0, 1.12, 1.25, 1.40, 1.52, 1.80, 2.15]
	var entries: Array[Dictionary] = [
		{"tier": "common", "chance": 55.0, "description": "70% empty · 30% chance of a 10% refund"},
		{"tier": "rare", "chance": 24.89, "description": "Hats, shirts, pants and shoes. Equip for bonuses."},
		{"tier": "epic", "chance": 12.0, "description": "Build gear or permanent luck/yield."},
		{"tier": "legendary", "chance": 5.0, "description": "Gold Hat + tool upgrades or a 5s offer."},
		{"tier": "mythic", "chance": 2.0, "description": "Aurora Crown + mutations worth up to 75% of stake."},
		{"tier": "jackpot", "chance": 1.0, "description": "20× your stake in game coins!"},
		{"tier": "relic", "chance": 0.1, "description": "Island artifact · Full collection: 2× stake"},
		{"tier": "mystery", "chance": 0.01, "description": "Island wonder · Full collection: 5× stake.", "hidden_chance": true},
	]
	var total: float = 0.0
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if index > 0:
			entry["chance"] = float(entry["chance"]) * stake_quality * pow(luck_quality, rarity_powers[index]) * pow(high_luck, float(index - 1) * 0.35)
		total += float(entry["chance"])
	for entry in entries:
		entry["chance"] = float(entry["chance"]) / total * 100.0
	# Ordinary luck keeps the cash jackpot within the existing economy range.
	# Excess cash-jackpot probability moves upward to collectible tiers, so luck
	# keeps helping rare gear. Explicit debug luck can exceed this payout limit.
	if debug_luck_multiplier <= 1.0 and float(entries[5]["chance"]) > 2.25:
		var excess: float = float(entries[5]["chance"]) - 2.25
		var collector_total: float = float(entries[6]["chance"]) + float(entries[7]["chance"])
		entries[5]["chance"] = 2.25
		for index in [6, 7]:
			entries[index]["chance"] = float(entries[index]["chance"]) + excess * float(entries[index]["chance"]) / collector_total
	return entries


func roll(kind: String) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if _rolling_reward:
		return "A roll is already being settled."
	last_roll_results.clear()
	last_roll_accounting.clear()
	if not roll_available():
		return _finish(roll_lock_reason())
	var bet: float = roll_cost(kind)
	if not can_roll(kind):
		if kind == "all_in":
			return _finish("All-in requires strictly more than %s on this island. No coins spent." % money(roll_minimum_stake("all_in")))
		return _finish("This island requires at least %s in earned coins per roll. Choose an affordable stake." % money(roll_cost("normal")))
	var chosen_odds: Array[Dictionary] = roll_odds(kind)
	var chosen_stake_bonus: float = stake_luck_bonus(kind)
	var has_crown: bool = crown_bonus_active()
	var is_debug: bool = bool(debug_info()["active"])
	var balance_before: float = coins
	_rolling_reward = true
	coins = maxf(0.0, coins - bet)
	var results: Array[Dictionary] = [_resolve_roll(bet, chosen_odds, chosen_stake_bonus)]
	if has_crown:
		results.append(_resolve_roll(bet, _roll_odds_with_stake(chosen_stake_bonus), chosen_stake_bonus))
	_complete_roll_transaction(results, 1, has_crown, is_debug, balance_before, bet)
	reward_received.emit(str(last_roll["title"]), str(last_roll["detail"]), str(last_roll["tier"]))
	var message: String = _finish("%s — %s%s" % [last_roll["title"], last_roll["detail"], " Aurora Crown granted one free bonus roll." if has_crown else ""])
	_rolling_reward = false
	return message


func roll_batch_cost(kind: String, count: int) -> float:
	if current_island != 3 or not island3_unlocked or not roll_available() or count not in [3, 5] or kind not in ["normal", "big", "stupid"]:
		return -1.0
	return roll_cost(kind) * count


func roll_batch(kind: String, count: int) -> Array[Dictionary]:
	if run_over:
		return []
	var results: Array[Dictionary] = []
	if _rolling_reward:
		return results
	last_roll_results.clear()
	last_roll_accounting.clear()
	var total: float = roll_batch_cost(kind, count)
	if total <= 0.0 or not is_finite(total):
		_finish("Multi-rolls are exclusive to Frosthollow: choose 3 or 5 rolls at a fixed stake.")
		return results
	if coins < total:
		_finish("You need %s upfront for all %d rolls. No coins spent." % [money(total), count])
		return results
	var has_crown: bool = crown_bonus_active()
	var is_debug: bool = bool(debug_info()["active"])
	var balance_before: float = coins
	_rolling_reward = true
	# Purchase the entire batch before RNG or rewards. A jackpot cannot fund a
	# batch that was unaffordable, and callbacks cannot re-enter settlement.
	coins = maxf(0.0, coins - total)
	var bet: float = roll_cost(kind)
	var stake_bonus: float = stake_luck_bonus(kind)
	for _index in range(count):
		var result: Dictionary = _resolve_roll(bet, roll_odds(kind), stake_bonus)
		results.append(result.duplicate(true))
	if has_crown:
		results.append(_resolve_roll(bet, _roll_odds_with_stake(stake_bonus), stake_bonus))
	_complete_roll_transaction(results, count, has_crown, is_debug, balance_before, total)
	_finish("%d paid rolls%s settled. %s spent; every reward is in your inventory." % [count, " + 1 free Crown roll" if has_crown else "", money(total)])
	_rolling_reward = false
	return results


func _complete_roll_transaction(results: Array[Dictionary], paid_count: int, has_crown: bool, is_debug: bool, balance_before: float, paid_total: float) -> void:
	var refunds: float = 0.0
	var duplicate_returns: float = 0.0
	var jackpot_returns: float = 0.0
	for index in range(results.size()):
		results[index]["paid_count"] = paid_count
		results[index]["crown_bonus"] = has_crown
		results[index]["bonus_roll"] = index >= paid_count
		results[index]["transaction_index"] = index
		results[index]["debug"] = is_debug
		match str(results[index].get("cash_kind", "")):
			"refund": refunds = minf(MAX_MONEY, refunds + float(results[index]["cash_awarded"]))
			"duplicate": duplicate_returns = minf(MAX_MONEY, duplicate_returns + float(results[index]["cash_awarded"]))
			"jackpot": jackpot_returns = minf(MAX_MONEY, jackpot_returns + float(results[index]["cash_awarded"]))
		if index >= paid_count:
			if str(results[index]["title"]) == "THE EMPTY SACK":
				results[index]["detail"] = "Free Aurora Crown pull: nothing this time. No extra coins were charged."
			else:
				results[index]["detail"] = "Free Aurora Crown pull. " + str(results[index]["detail"])
		_record_roll_trophy(results[index])
	last_roll_results.assign(results.duplicate(true))
	last_roll = results.back().duplicate(true)
	var balance_after_charge: float = maxf(0.0, balance_before - paid_total)
	last_roll_accounting = {"balance_before": balance_before, "paid_total": paid_total, "balance_after_charge": balance_after_charge,
		"cash_returned": maxf(0.0, coins - balance_after_charge), "balance_after": coins, "net_change": coins - balance_before,
		"paid_count": paid_count, "bonus_count": 1 if has_crown else 0, "refunds": refunds, "duplicate_returns": duplicate_returns, "jackpot_returns": jackpot_returns}


func _resolve_roll(bet: float, chosen_odds: Array[Dictionary], chosen_stake_bonus: float) -> Dictionary:
	roll_count += 1
	var draw: float = rng.randf() * 100.0
	var cumulative: float = 0.0
	var tier: String = "mystery"
	for entry in chosen_odds:
		cumulative += float(entry["chance"])
		if draw < cumulative:
			tier = str(entry["tier"])
			break
	var result: Dictionary = _grant_roll_reward(tier, bet)
	result["stake_bonus"] = chosen_stake_bonus
	result["odds"] = chosen_odds
	result["roll_number"] = roll_count
	result["island"] = current_island
	for entry in chosen_odds:
		if str(entry["tier"]) == tier:
			result["tier_probability"] = float(entry["chance"])
			break
	return result


func _roll_collectible(tier: String) -> String:
	var available: Array[String] = []
	var complete: Array[String] = []
	for id in ITEM_CATALOG:
		if ITEM_CATALOG[id]["rarity"] != tier:
			continue
		if tier in ["relic", "mystery"] and id not in ARTIFACT_POOLS[current_island][tier]:
			continue
		complete.append(str(id))
		if int(inventory_items.get(id, 0)) < int(ITEM_CATALOG[id]["max_count"]):
			available.append(str(id))
	var pool: Array[String] = available if not available.is_empty() else complete
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


func _grant_roll_reward(tier: String, bet: float) -> Dictionary:
	var coins_before_reward: float = coins
	var scale: int = maxi(1, int(minf(1000000000.0, floor(bet / roll_cost("normal")))))
	var title: String = tier.to_upper()
	var detail: String = ""
	var item_id: String = ""
	match tier:
		"common":
			if rng.randf() < 0.70:
				title = "THE EMPTY SACK"
				detail = "Nothing this time. Your %s stake is spent." % money(bet)
			else:
				var refund: float = bet * 0.10
				coins = minf(MAX_MONEY, coins + refund)
				title = "A LITTLE CHANGE"
				detail = "%s back: 10%% of your stake." % money(refund)
		"rare":
			item_id = _roll_collectible(tier)
			title = str(ITEM_CATALOG[item_id]["name"]).to_upper()
			detail = _grant_item(item_id, bet * 0.20)
		"epic":
			var reward_kind: int = rng.randi_range(0, 3)
			if reward_kind <= 1:
				item_id = _roll_collectible(tier)
				title = str(ITEM_CATALOG[item_id]["name"]).to_upper()
				detail = _grant_item(item_id, bet * 0.20)
			elif reward_kind == 2:
				var gain: float = maxf(0.0, minf(10.0 - luck, 0.1 * sqrt(float(scale))))
				luck += gain
				title = "LUCKY SPUD CHARM"
				detail = "+%.2fx permanent luck · Now %.2fx / 10x" % [gain, luck]
			else:
				var gain: float = maxf(0.0, minf(2.0 - permanent_yield, 0.005 * sqrt(float(scale))))
				permanent_yield += gain
				title = "HARVEST BLESSING"
				detail = "+%s%% permanent harvest yield (new bonus cap +200%%)." % format_number(gain * 100.0)
		"legendary":
			item_id = "prospectors_hat"
			var available: Array[String] = []
			for key in TOOL_COSTS:
				if int(tools[key]) < (3 if current_island == 3 else 2):
					available.append(str(key))
			if rng.randf() < 0.5 and not available.is_empty():
				var upgrades_received: int = 0
				for _upgrade in range(mini(6, scale)):
					if available.is_empty():
						break
					var key: String = available[rng.randi_range(0, available.size() - 1)]
					tools[key] = int(tools[key]) + 1
					upgrades_received += 1
					if int(tools[key]) >= (3 if current_island == 3 else 2):
						available.erase(key)
				title = "LEGENDARY TOOL CRATE"
				detail = "+%d tool upgrades" % upgrades_received
			else:
				pending_roll_boost = maxf(pending_roll_boost, 1.25 + minf(1.75, sqrt(float(scale)) * 0.10))
				title = "MARKET ROCKET"
				detail = "All crop prices ×%s for 5s after reveal." % format_number(pending_roll_boost)
			detail += " " + _grant_item(item_id, bet * 0.20)
		"mythic":
			item_id = "aurora_crown"
			var kind: String = MUTATION_IDS[rng.randi_range(0, MUTATION_IDS.size() - 1)]
			var crate_unit_value: float = maxf(float(CROPS["russet"]["base"]), float(market["russet"]["sell"])) * float(MUTATION_MULTIPLIERS[kind])
			var crate_count: int = int(minf(float(MAX_INVENTORY), floor(bet * 0.75 / crate_unit_value)))
			var added: int = _add_mutation("russet", crate_count, kind)
			title = "AURORA CROWN + MUTATION CACHE"
			detail = "%s mutation potatoes stored.%s %s" % [format_number(added), " Barn space limited the crate; upgrade it for future rewards." if added < crate_count else "", _grant_item(item_id, bet * 0.20)]
		"relic", "mystery":
			item_id = _roll_collectible(tier)
			title = str(ITEM_CATALOG[item_id]["name"]).to_upper()
			detail = _grant_item(item_id, minf(MAX_MONEY, bet * (2.0 if tier == "relic" else 5.0)))
		"jackpot":
			var reward: float = minf(MAX_MONEY, bet * 20.0)
			coins = minf(MAX_MONEY, coins + reward)
			title = "THE POTATO JACKPOT!"
			detail = "%s in earned game coins — 20 times your stake!" % money(reward)
	if is_instance_valid(build_system) and build_system.has_method("grant_roll_build"):
		var build_reward: String = str(build_system.grant_roll_build(tier))
		if not build_reward.is_empty():
			detail += " " + build_reward
	var cash_awarded: float = maxf(0.0, coins - coins_before_reward)
	var cash_kind: String = ("refund" if tier == "common" else ("jackpot" if tier == "jackpot" else "duplicate")) if cash_awarded > 0.0 else ""
	return {"tier": tier, "title": title, "detail": detail, "bet": bet, "item_id": item_id, "cash_awarded": cash_awarded, "cash_kind": cash_kind}


func activate_roll_boost() -> void:
	if run_over:
		return
	if tutorial_active or pending_roll_boost <= 0.0:
		return
	boost_factor = pending_roll_boost
	pending_roll_boost = 0.0
	boost_remaining = 5.0
	_refresh_market()
	notified.emit("MARKET ROCKET! All crop quotes x%.2f for 5 seconds. Your roll bonus starts NOW!" % boost_factor)
	changed.emit()


func _market_tick() -> void:
	if tutorial_active:
		return
	for id in CROP_IDS:
		var volatility: float = float(CROPS[id]["vol"]) * 0.55 * (event_strength if current_event == "chaos" else 1.0) * (1.8 if current_island == 2 else 1.0)
		volatility *= 1.0 + (1.0 - climate.factor("sell", current_island)) * 2.0
		var core: Dictionary = _market_core[id]
		var base: float = float(CROPS[id]["base"])
		# Revert toward a crop's real value rather than multiplying gains forever.
		var log_ratio: float = log(clampf(float(core["sell"]) / base, 0.35, 3.0))
		var movement: float = rng.randf_range(-volatility, volatility)
		if current_island == 1:
			movement = rng.randf_range(0.0, volatility * 0.8) if rng.randf() < 0.62 else rng.randf_range(-volatility, 0.0)
		core["sell"] = base * clampf(exp(log_ratio * 0.82 + movement), 0.35, 3.0)
		core["seed"] = seed_price_for(float(core["sell"]))
	if not disaster_market_active() and surge_remaining <= 0.0 and natural_remaining <= 0.0 and float(farm_help.data.practice_remaining) <= 0.0 and rng.randf() < natural_stock_chance():
		natural_crop = selected_crop
		natural_factor = _natural_boom_roll(71.0 if current_island >= 3 else 21.0, stock_cap())
		natural_remaining = SURGE_DURATION
	_refresh_market(true)


func _refresh_market(_record_history: bool = true) -> void:
	var crashing: bool = disaster_market_active()
	if crashing: _clear_disaster_booms()
	for id in CROP_IDS:
		var sale_factor: float = boost_factor if boost_remaining > 0.0 else 1.0
		match current_event:
			"shortage", "crash", "festival": sale_factor *= event_strength
			"golden_craze": sale_factor *= event_strength if id == "golden" else 1.0
			"mystery_buyer", "supply_collapse": sale_factor *= event_strength if id == event_crop else 1.0
		if export_active and id in ["golden", "sunburst"]:
			sale_factor *= export_factor
		if id == "icecap" and thaw_remaining > 0.0:
			sale_factor *= 8.0
		var current: float = minf(float(CROPS[id]["base"]) * stock_cap(), float(_market_core[id]["sell"]) * sale_factor * item_stock_factor())
		if not tutorial_active:
			if not crashing: current *= climate.factor("sell", current_island)
		if natural_remaining > 0.0 and id == natural_crop:
			# Explicit boom draws are final quotes. Stacked offers must not flatten
			# their decreasing rarity curves into a pile-up at the ceiling.
			current = float(CROPS[id]["base"]) * minf(stock_cap(), natural_factor)
		if surge_remaining > 0.0 and id == surge_crop:
			var ceiling: float = MAX_PRICE_MULTIPLIER if surge_kind == "rocket" and current_island >= 3 else stock_cap()
			current = float(CROPS[id]["base"]) * minf(ceiling, surge_factor)
		if float(farm_help.data.practice_remaining) > 0.0 and current_island == 1 and id == str(farm_help.data.practice_crop) and surge_remaining <= 0.0 and natural_remaining <= 0.0:
			current = float(CROPS[id]["base"]) * 2.0
		if tutorial_active:
			current = float(CROPS[id]["base"])
		elif crashing:
			var base: float = float(CROPS[id].base)
			# Final authority, after every offer, export, reward and gear multiplier.
			# Recovery eases the crash, but no positive quote returns before calm.
			current = clampf(minf(current, base) * climate.factor("sell", current_island), base * 0.05, base)
		# One seed costs 75% of one potato, rounded to the nearest cent.
		# This final quote takes precedence over legacy seed-only modifiers.
		market[id]["seed"] = seed_price_for(current)
		market[id]["sell"] = current
		market[id]["change"] = price_change(current, float(CROPS[id]["base"]))
		var history: Array = market[id]["history"]
		# Retain actual price changes, including gear, weather and boom endings.
		if history.is_empty() or not is_equal_approx(float(history.back()), current):
			history.append(current)
			if market[id]["history"].size() > 40:
				market[id]["history"].pop_front()


func _start_event(id: String = "") -> void:
	if tutorial_active:
		return
	if disaster_market_active(): id = "crash"
	if EVENT_IDS.has(id):
		current_event = id
	else:
		var positive: Array[String] = ["shortage", "golden_craze", "mystery_buyer", "supply_collapse", "seed_fair", "festival"]
		var other: Array[String] = ["crash", "seed_panic", "chaos"]
		var pool: Array[String] = positive if rng.randf() < luck_stock_chance() else other
		current_event = pool[rng.randi_range(0, pool.size() - 1)]
	var event_crops: Array[String] = available_crops()
	event_crop = event_crops[rng.randi_range(0, event_crops.size() - 1)]
	event_remaining = rng.randf_range(4.0, 5.0)
	match current_event:
		"shortage":
			event_strength = rng.randf_range(1.5, 3.0)
			event_name = "POTATO SHORTAGE"
			news = "A sudden shortage lifts all crop quotes x%.1f. This buying frenzy lasts %.1f seconds!" % [event_strength, event_remaining]
		"crash":
			event_strength = rng.randf_range(0.3, 0.6)
			event_name = "BUMPER HARVEST CRASH"
			news = "The market crashes %.0f%%! Crop and seed prices both fall for %.1f seconds. Buy seeds cheap or keep holding." % [(1.0 - event_strength) * 100.0, event_remaining]
		"golden_craze":
			event_strength = rng.randf_range(2.0, 4.0)
			event_name = "GOLDEN POTATO CRAZE"
			news = "Golden potato craze: x%.1f quotes for %.1f seconds. Watch the barn!" % [event_strength, event_remaining]
		"seed_panic":
			event_strength = rng.randf_range(1.4, 2.2)
			event_name = "SEED PANIC"
			news = "Seed panic! Merchants keep seeds at 75% of each potato’s live sale price."
		"chaos":
			event_strength = rng.randf_range(2.0, 3.5)
			event_name = "TOTALLY NORMAL MARKET"
			news = "Totally normal market! Quotes swing %.1fx harder for %.1f seconds, then calm down." % [event_strength, event_remaining]
		"mystery_buyer":
			event_strength = rng.randf_range(2.0, 5.0)
			event_name = "MYSTERY BUYER"
			news = "Mystery buyer: %s x%.1f for %.1f seconds. A brief offer on your stored crops!" % [CROPS[event_crop]["name"], event_strength, event_remaining]
		"supply_collapse":
			event_strength = rng.randf_range(8.0, 16.0) if current_island >= 2 else rng.randf_range(3.0, 6.0)
			event_name = "SUPPLY COLLAPSE"
			news = "%s supply collapsed! Its quote jumps x%.1f for %.1f seconds." % [CROPS[event_crop]["name"], event_strength, event_remaining]
		"seed_fair":
			event_strength = rng.randf_range(0.6, 0.8)
			event_name = "SEED FAIR"
			news = "Seed fair! Seeds cost 75% of each potato’s live sale price. Prepare your next manual harvest."
		"festival":
			event_strength = rng.randf_range(1.5, 2.5)
			event_name = "FRIES FESTIVAL"
			news = "The fries festival wants potatoes! All crops x%.1f for %.1f seconds." % [event_strength, event_remaining]
	_refresh_market()
	notified.emit(news)


func _end_event() -> void:
	current_event = ""
	event_name = "OPEN MARKET"
	event_strength = 1.0
	event_remaining = 0.0
	_event_in = rng.randf_range(2.0, 4.0) / (1.0 + (effective_luck() - 1.0) * 0.06)
	_refresh_market()
	news = "That flash offer ended. Its multiplier has expired; ordinary quotes resume."
	notified.emit(news)


func _seed_relief() -> bool:
	if coins >= float(market["russet"]["seed"]) or storage_used() > 0:
		return false
	for id in CROP_IDS:
		if int(seed_inventory[id]) > 0:
			return false
	for field in island_plots.values():
		for plot in field:
			if int(plot["stage"]) > 0:
				return false
	seed_inventory["russet"] = 3
	news = "Your neighbors left 3 emergency Russet seeds. Hoe, plant, and water them to get back on your feet."
	notified.emit(news)
	return true


func format_number(value: float, suffix_decimals: int = 1) -> String:
	if not is_finite(value):
		return "0"
	var absolute: float = absf(value)
	if absolute > 0.0 and absolute < 0.01:
		return String.num_scientific(value)
	if absolute >= 1.0e36:
		var exponent: int = int(floor(log(absolute) / log(10.0)))
		var mantissa: float = value / pow(10.0, exponent)
		if absf(snappedf(mantissa, 0.01)) >= 10.0:
			exponent += 1
			mantissa /= 10.0
		return ("%.2f" % mantissa).trim_suffix("0").trim_suffix("0").trim_suffix(".") + "e" + str(exponent)
	var suffixes: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var scaled: float = value
	var level: int = 0
	while absf(scaled) >= 1000.0 and level < suffixes.size() - 1:
		scaled /= 1000.0
		level += 1
	if level > 0 and absf(round(scaled)) >= 1000.0 and level < suffixes.size() - 1:
		scaled /= 1000.0
		level += 1
	if level == 0:
		return "%.0f" % scaled if is_equal_approx(scaled, round(scaled)) or absolute >= 100.0 else "%.2f" % scaled
	var display: String = "%.0f" % scaled if absf(scaled) >= 100.0 else "%.1f" % scaled
	if suffix_decimals != 1 and absf(scaled) < 100.0:
		display = String.num(scaled, suffix_decimals)
		if display.contains("."):
			display = display.rstrip("0").trim_suffix(".")
	return display + suffixes[level]


func money(value: float, precise: bool = false) -> String:
	return ("-$" if value < 0.0 else "$") + format_number(absf(value), 2 if precise else 1)


func _finish(message: String) -> String:
	changed.emit()
	notified.emit(message)
	return message


func _complete_purchase(receipt: Dictionary, message: String) -> String:
	# Emit only after the transaction commits and refreshed inventory is visible.
	# Receipts are transient UI feedback, never save data or inferred from text.
	changed.emit()
	purchase_completed.emit(receipt.duplicate(true))
	return message


func _reject_purchase(message: String) -> String:
	purchase_rejected.emit(message)
	return message


func reset_game() -> void:
	npc_history.clear()
	tax_credit_eligible = false
	field_expansions = {"2": false, "3": false}
	retained_beds = {"2": [], "3": []}
	blind_cycle = BlindRules.new_cycle()
	climate.reset()
	tutorial_active = false
	tutorial_progress = {"version": 2, "step": 0, "completed": false, "plot": 5}
	farm_help.data = FarmHelp.fresh()
	if is_instance_valid(build_system) and build_system.has_method("reset_builds"):
		build_system.reset_builds()
	if is_instance_valid(activity_system) and activity_system.has_method("reset"):
		activity_system.reset()
	_rolling_reward = false
	current_island = 1
	island2_unlocked = false
	island3_unlocked = false
	frost_timer = 150.0
	pest_timer = rng.randf_range(25.0, 100.0)
	frost_active = false
	frost_cleared = 0
	frost_target_count = 12
	thaw_remaining = 0.0
	inventory_items = _empty_items()
	equipment = _empty_equipment()
	shores_first_mutation = false
	export_timer = 120.0
	export_factor = 1.0
	event_strength = 1.0
	lifetime_sales = 0.0
	island_sales = {"1": 0.0, "2": 0.0, "3": 0.0}
	export_active = false
	export_cycles = 0
	export_cycle_sold = 0
	export_qualified_cycles.clear()
	quest_progress = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "mutation": 0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
	quest_claimed.clear()
	golden_hat = false
	coins = 240.0
	selected_crop = "russet"
	tracked_seeds = ["russet", "golden", "giant", "radioactive"]
	surge_timer = SURGE_INTERVAL
	surge_remaining = 0.0
	surge_crop = "russet"
	surge_factor = 1.0
	surge_kind = "normal"
	rocket_timer = ROCKET_INTERVAL
	rocket_pending = false
	rocket_factor = 1.0
	rocket_crop = "icecap"
	natural_remaining = 0.0
	natural_factor = 1.0
	natural_crop = "russet"
	seed_inventory = {"russet": 12, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	storage = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	capacity = 200
	tools = {"hoe": 0, "water": 0, "harvest": 0}
	news = "Harvest your Russets. Catch a good price. Sell with F!"
	event_name = "OPEN MARKET"
	event_remaining = 0.0
	elapsed = 0.0
	combo_count = 0
	combo_multiplier = 1
	combo_time = 0.0
	luck = 1.0
	debug_luck_multiplier = 1.0
	debug_money_modified = false
	debug_islands_modified = false
	trophies.clear()
	harvest_fraction = {"russet": 0.0, "golden": 0.0, "giant": 0.0, "radioactive": 0.0, "sunburst": 0.0, "icecap": 0.0}
	mastery = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	dex.clear()
	permanent_yield = 0.0
	roll_count = 0
	last_roll.clear()
	last_roll_results.clear()
	last_roll_accounting.clear()
	expansion = 0
	barn_level = 0
	mutations.clear()
	current_event = ""
	event_crop = "russet"
	boost_remaining = 0.0
	boost_factor = 1.0
	pending_roll_boost = 0.0
	_market_clock = 0.0
	_event_in = 8.0
	_relief_clock = 0.0
	_build_starters()
	island_changed.emit(1)
	export_changed.emit(false)
	_finish("A fresh farm and $240. Your next fortune starts with a potato.")


func _save_data() -> Dictionary:
	var data: Dictionary = {"schema_version": SAVE_VERSION, "economy_revision": ECONOMY_REVISION, "mechanics_revision": MECHANICS_REVISION,
		"tax_credit_eligible": tax_credit_eligible and coins < 0.0 and not run_over,
		"field_expansions": field_expansions.duplicate(), "retained_beds": retained_beds.duplicate(true),
		"blind_cycle": blind_cycle.duplicate(true),
		"climate": climate.data.duplicate(true),
		"tutorial_progress": tutorial_progress.duplicate(true),
		"npc_history": npc_history.duplicate(true),
		"farm_help": farm_help.data.duplicate(true),
		"export_cycle_sold": export_cycle_sold, "export_qualified_cycles": export_qualified_cycles,
		"export_factor": export_factor, "event_strength": event_strength,
		"lifetime_sales": lifetime_sales, "island_sales": island_sales,
		"pending_roll_boost": pending_roll_boost, "inventory_items": inventory_items, "equipment": equipment.duplicate(),
		"island3_unlocked": island3_unlocked, "frost_timer": frost_timer, "frost_active": frost_active,
		"frost_cleared": frost_cleared, "frost_target_count": frost_target_count, "thaw_remaining": thaw_remaining, "pest_timer": pest_timer, "coins": coins, "coins_scientific": String.num_scientific(coins), "selected_crop": selected_crop,
		"tracked_seeds": tracked_seeds, "surge_timer": surge_timer, "surge_remaining": surge_remaining, "surge_crop": surge_crop, "surge_factor": surge_factor,
		"surge_kind": surge_kind, "rocket_timer": rocket_timer, "rocket_pending": rocket_pending, "rocket_factor": rocket_factor, "rocket_crop": rocket_crop,
		"natural_remaining": natural_remaining, "natural_factor": natural_factor, "natural_crop": natural_crop,
		"seed_inventory": seed_inventory, "storage": storage, "capacity": capacity, "tools": tools,
		"plots": plots, "current_island": current_island, "island2_unlocked": island2_unlocked,
		"island_plots": island_plots, "shores_first_mutation": shores_first_mutation,
		"export_timer": export_timer, "export_active": export_active, "export_cycles": export_cycles,
		"quest_progress": quest_progress, "quest_claimed": quest_claimed, "golden_hat": golden_hat,
		"market": market, "market_core": _market_core, "news": news,
		"event_name": event_name, "event_remaining": event_remaining, "elapsed": elapsed,
		"combo_count": combo_count, "combo_multiplier": combo_multiplier, "combo_time": combo_time,
		"luck": luck, "mastery": mastery, "dex": dex, "permanent_yield": permanent_yield,
		"debug_luck_multiplier": debug_luck_multiplier, "debug_money_modified": debug_money_modified, "debug_islands_modified": debug_islands_modified,
		"trophies": trophies.duplicate(true), "harvest_fraction": harvest_fraction.duplicate(), "last_roll_results": last_roll_results.duplicate(true), "last_roll_accounting": last_roll_accounting.duplicate(),
		"roll_count": roll_count, "last_roll": last_roll, "expansion": expansion, "barn_level": barn_level,
		"mutations": mutations, "current_event": current_event, "event_crop": event_crop,
		"boost_remaining": boost_remaining, "boost_factor": boost_factor, "market_clock": _market_clock,
		"event_in": _event_in, "relief_clock": _relief_clock,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}
	if is_instance_valid(build_system) and build_system.has_method("save_data"):
		data["builds"] = build_system.save_data()
	if is_instance_valid(activity_system) and activity_system.has_method("save_data"):
		data["activities"] = activity_system.save_data()
	return data


func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if path == LEGACY_SAVE_PATH:
		notified.emit("The original farm save is preserved as a backup. Save to the current version instead.")
		return false
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		notified.emit("Could not save the farm. Check the save folder is writable.")
		return false
	file.store_string(JSON.stringify(_save_data()))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path)) != OK:
		notified.emit("Saving failed. Your previous save is preserved.")
		return false
	return true


func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	var candidates: Array[String] = [path]
	if path == DEFAULT_SAVE_PATH:
		candidates.append(LEGACY_SAVE_PATH)
	var data: Dictionary = {}
	var found_save: bool = false
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		found_save = true
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		if file.get_length() > 2000000:
			file.close()
			continue
		var json: JSON = JSON.new()
		var parse_error: Error = json.parse(file.get_as_text())
		file.close()
		if parse_error == OK and _valid_save(json.data):
			data = json.data
			break
	if data.is_empty():
		if found_save:
			notified.emit("This save is damaged or from an incompatible version. Your current farm is unchanged.")
		return false
	var migrated: bool = int(data["schema_version"]) == 2
	if migrated:
		data = _migrate_v2(data)
	var rebalanced: bool = not data.has("economy_revision")
	if rebalanced:
		data = _migrate_economy(data)
	var winter_migrated: bool = int(data.get("economy_revision", 0)) < 3
	if winter_migrated:
		data = _migrate_winter(data)
	var activities_migrated: bool = not data.has("mechanics_revision")
	if activities_migrated:
		data = _migrate_activities(data)
	if int(data.get("mechanics_revision", 0)) < 3:
		data = _migrate_pests(data)
	if int(data.get("mechanics_revision", 0)) < 4:
		data = _migrate_qol(data)
	_restoring_balance = true
	var mechanics: int = int(data.get("mechanics_revision", 0))
	climate.data = data.climate.duplicate(true) if mechanics >= 11 else ClimateSystem.fresh_data()
	if not climate.data.has("operations"): climate.data.operations = ClimateSystem.Operations.fresh()
	if not climate.data.operations.has("ice"): climate.data.operations.ice = {}
	for supply in climate.data.operations.islands.values():
		if not supply.has("heat"): supply.heat = 0.0
		if mechanics < 18 or not supply.has("can"): supply.can = 16.0 + 16.0 * int(data.tools.water)
		if not supply.has("refilled"): supply.refilled = false
		supply.shelter = 0
	if not climate.data.has("lesson"):
		climate.data.lesson = ClimateSystem.Lesson.fresh("done" if climate.data.get("introduced", false) else "off")
		climate.data.intro_pending = false
	if mechanics < 18:
		for supply in climate.data.operations.islands.values(): supply.mode = 0
		for id in ["2", "3"]:
			if int(climate.data.projects[id].get("rainwater", 0)) > 0 or (id == "2" and climate.data.get("introduced", false)):
				climate.data.projects[id].irrigation = maxi(1, int(climate.data.projects[id].get("irrigation", 0)))
	if mechanics < 19:
		var owned_irrigation: int = 0
		for project in climate.data.projects.values(): owned_irrigation = maxi(owned_irrigation, int(project.get("irrigation", 0)))
		if owned_irrigation > 0:
			for project in climate.data.projects.values(): project.irrigation = owned_irrigation

	if mechanics == 11:
		climate.data.introduced = false
		climate.data.intro_pending = false
		# The Valley now teaches farming without weather disasters.
		if int(climate.data.island) == 1:
			climate.data.phase = "calm"
			climate.data.event = ""
			climate.data.severity = 0.0
			climate.data.timer = ClimateSystem.FIRST_WARNING
			climate.data.tax_events.clear()
	blind_cycle = data.blind_cycle.duplicate(true) if mechanics >= 9 else BlindRules.new_cycle(int(data["current_island"]))
	if mechanics == 9 and blind_cycle.reason == "blind_missed":
		blind_cycle.reason = "tax_unpaid"
	if int(data.get("mechanics_revision", 0)) < 11:
		# New progression-based bills get a full preparation cycle on old farms.
		blind_cycle.booms = 0
		blind_cycle.due_in = 0.0
		blind_cycle.tax_multiplier = 1.0
		blind_cycle.tax_rolled = false
		blind_cycle.last_result = {}
	tutorial_active = false
	farm_help.data = data.get("farm_help", FarmHelp.fresh()).duplicate(true)
	# An established farm gets its normal game back, without a surprise tutorial.
	npc_history = data.get("npc_history", {}).duplicate(true)
	for person in npc_history: npc_history[person].visits = int(npc_history[person].visits)
	tutorial_progress = data.get("tutorial_progress", {"version": 1, "step": 0, "completed": true, "plot": 5}).duplicate(true)
	for key in ["version", "step", "plot"]:
		tutorial_progress[key] = int(tutorial_progress[key])
	tracked_seeds.assign(data["tracked_seeds"])
	for key in ["coins", "event_remaining", "elapsed", "combo_time", "luck", "permanent_yield", "boost_remaining", "boost_factor", "export_timer", "export_factor", "event_strength", "lifetime_sales", "pending_roll_boost", "frost_timer", "thaw_remaining", "pest_timer", "surge_timer", "surge_remaining", "surge_factor"]:
		set(key, float(data[key]))
	# Keep Godot's ordinary numeric balance whenever it survived JSON. Its
	# scientific parser can differ by one ULP for some large values; the extra
	# string is only needed when the numeric path lost a tiny positive balance.
	if data.has("coins_scientific") and coins == 0.0:
		coins = str(data["coins_scientific"]).to_float()
	# Earlier saves had no debt origin flag. A negative tax receipt is the
	# available evidence of tax debt; a negative balance alone is not enough.
	var old_receipt: Dictionary = blind_cycle.last_result
	var saved_tax_credit: bool = bool(data.tax_credit_eligible) if mechanics >= 21 else float(old_receipt.get("tax", 0.0)) > 0.0 and float(old_receipt.get("after", 0.0)) < 0.0
	tax_credit_eligible = coins < 0.0 and not run_over and saved_tax_credit
	for key in ["capacity", "combo_count", "combo_multiplier", "roll_count", "expansion", "barn_level", "current_island", "export_cycles", "frost_cleared", "frost_target_count", "export_cycle_sold"]:
		set(key, int(data[key]))
	for key in ["selected_crop", "news", "event_name", "current_event", "event_crop", "surge_crop"]:
		set(key, str(data[key]))
	for key in ["island2_unlocked", "shores_first_mutation", "export_active", "golden_hat", "island3_unlocked", "frost_active"]:
		set(key, bool(data[key]))
	surge_kind = str(data.get("surge_kind", "normal"))
	rocket_timer = float(data.get("rocket_timer", ROCKET_INTERVAL))
	rocket_pending = bool(data.get("rocket_pending", false))
	rocket_factor = float(data.get("rocket_factor", 1.0))
	rocket_crop = str(data.get("rocket_crop", "icecap"))
	natural_remaining = float(data.get("natural_remaining", 0.0))
	natural_factor = float(data.get("natural_factor", 1.0))
	natural_crop = str(data.get("natural_crop", "russet"))
	if int(data.get("mechanics_revision", 0)) < 8:
		surge_factor = minf(surge_factor, stock_cap())
	for key in ["seed_inventory", "storage", "tools", "market", "mastery", "last_roll", "quest_progress", "island_sales", "inventory_items"]:
		set(key, data[key].duplicate(true))
	# Old farms retain every collectible and receive zero owned copies of new gear.
	for item_id in ITEM_CATALOG:
		if not inventory_items.has(item_id):
			inventory_items[item_id] = 0
	_recompute_capacity()
	debug_luck_multiplier = float(data.get("debug_luck_multiplier", 1.0))
	debug_money_modified = bool(data.get("debug_money_modified", false))
	debug_islands_modified = bool(data.get("debug_islands_modified", false))
	trophies.clear()
	for entry in data.get("trophies", []):
		trophies.append(entry.duplicate(true))
	trophies.sort_custom(_trophy_precedes)
	last_roll_results.clear()
	for result in data.get("last_roll_results", []):
		last_roll_results.append(result.duplicate(true))
	last_roll_accounting = data.get("last_roll_accounting", {}).duplicate()
	harvest_fraction = {"russet": 0.0, "golden": 0.0, "giant": 0.0, "radioactive": 0.0, "sunburst": 0.0, "icecap": 0.0}
	for id in CROP_IDS:
		harvest_fraction[id] = float(data.get("harvest_fraction", {}).get(id, 0.0))
	if int(data.get("mechanics_revision", 0)) >= 6:
		equipment = data["equipment"].duplicate()
	else:
		_migrate_equipment()
	_market_core = data["market_core"].duplicate(true)
	island_plots = {}
	for id in ["1", "2", "3"]:
		var field: Array[Dictionary] = []
		for plot in data["island_plots"][id]:
			var restored: Dictionary = plot.duplicate(true)
			if mechanics < 15:
				restored["plant_age"] = 0.0
				restored["pest_delay"] = 0.0
				restored["ripe_age"] = 0.0
			if mechanics < 14:
				restored.elapsed = float(restored.elapsed) / float(OLD_GROW_TIMES[restored.crop]) * float(CROPS[restored.crop].grow)
			field.append(restored)
		island_plots[id] = field
	if mechanics >= 21:
		field_expansions = data.field_expansions.duplicate()
		retained_beds = data.retained_beds.duplicate(true)
	else:
		_migrate_field_access()
	plots = island_plots[str(current_island)]
	mutations.clear()
	for crate in data["mutations"]:
		mutations.append(crate.duplicate(true))
	dex.clear()
	for entry in data["dex"]:
		dex.append(str(entry))
	export_qualified_cycles.clear()
	for cycle in data["export_qualified_cycles"]:
		export_qualified_cycles.append(int(cycle))
	quest_claimed.clear()
	for entry in data["quest_claimed"]:
		quest_claimed.append(str(entry))
	_market_clock = fmod(float(data["market_clock"]), market_tick_seconds())
	_event_in = float(data["event_in"])
	_relief_clock = float(data["relief_clock"])
	if is_instance_valid(build_system):
		if data.has("builds") and build_system.has_method("load_data"):
			build_system.load_data(data["builds"])
		elif build_system.has_method("reset_builds"):
			build_system.reset_builds()
	if is_instance_valid(activity_system):
		if data.has("activities") and activity_system.has_method("load_data"):
			activity_system.load_data(data["activities"])
		elif activity_system.has_method("reset"):
			activity_system.reset()
	_rolling_reward = false
	rng.seed = int(data["rng_seed"])
	rng.state = int(data["rng_state"])
	# Older Rockets keep their saved prize, lifted into the new range once.
	if int(data.get("mechanics_revision", 0)) < 9:
		if rocket_pending:
			rocket_factor = maxf(ROCKET_MIN_MULTIPLIER, rocket_factor)
		if surge_kind == "rocket":
			surge_factor = maxf(ROCKET_MIN_MULTIPLIER, surge_factor)
	_restoring_balance = false
	if not run_over and coins < bankruptcy_limit():
		_end_run("bankrupt")
	_refresh_market(false)
	island_changed.emit(current_island)
	export_changed.emit(export_active)
	_finish("Original farm restored. Golden Shores is waiting; your original save remains a backup." if migrated else "Farm loaded. Both islands resume their saved growth and Export Rush countdown; no offline farming.")
	return true


func _migrate_v2(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["schema_version"] = 3
	for key in ["seed_inventory", "storage", "mastery"]:
		data[key]["sunburst"] = 0
	data["market_core"]["sunburst"] = {"seed": 67500.0, "sell": 90000.0}
	var seed_factor: float = 5.0 if data["current_event"] == "seed_panic" else (0.3 if data["current_event"] == "crash" else 1.0)
	var sale_factor: float = float(data["boost_factor"]) if float(data["boost_remaining"]) > 0.0 else 1.0
	if data["current_event"] == "shortage":
		sale_factor *= 6.0
	elif data["current_event"] == "crash":
		sale_factor *= 0.3
	var sell: float = 90000.0 * sale_factor
	data["market"]["sunburst"] = {"seed": 67500.0 * seed_factor, "sell": sell, "change": (sale_factor - 1.0) * 100.0, "history": [sell]}
	data["current_island"] = 1
	data["island2_unlocked"] = false
	data["island_plots"] = {"1": data["plots"], "2": _empty_shores(false)}
	data["shores_first_mutation"] = false
	data["export_timer"] = 75.0
	data["export_active"] = false
	data["export_cycles"] = 0
	data["quest_progress"] = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "mutation": 0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
	data["quest_claimed"] = []
	data["golden_hat"] = false
	return data


func _migrate_economy(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["economy_revision"] = 2
	data["luck"] = minf(10.0, float(data["luck"]))
	data["market_clock"] = fposmod(float(data["market_clock"]), MARKET_TICK_SECONDS)
	data["event_in"] = minf(11.0, float(data["event_in"]))
	data["event_remaining"] = minf(2.0, float(data["event_remaining"]))
	data["boost_remaining"] = minf(2.0, float(data["boost_remaining"]))
	data["boost_factor"] = minf(3.0, float(data["boost_factor"]))
	data["export_factor"] = 4.0 if data["export_active"] else 1.0
	data["export_timer"] = minf(2.0, float(data["export_timer"])) if data["export_active"] else (minf(EXPORT_MAX_WAIT, float(data["export_timer"])) if data["island2_unlocked"] else 120.0)
	var old_strengths: Dictionary = {"shortage": 2.0, "crash": 0.4, "golden_craze": 3.0, "seed_panic": 1.8, "chaos": 2.5, "mystery_buyer": 3.5, "supply_collapse": 4.5}
	data["event_strength"] = float(old_strengths.get(data["current_event"], 1.0))
	data["lifetime_sales"] = 0.0
	data["pending_roll_boost"] = 0.0
	data["island_sales"] = {"1": 0.0, "2": 0.0}
	for id in data["market_core"]:
		var base: float = float(CROPS[id]["base"])
		data["market_core"][id]["sell"] = clampf(float(data["market_core"][id]["sell"]), base * 0.35, base * 3.0)
		data["market_core"][id]["seed"] = seed_price_for(float(data["market_core"][id]["sell"]))
	# Preserve already collected rewards/cosmetics without allowing a second payout.
	for id in data["quest_claimed"]:
		data["quest_progress"][id] = float(QUEST_TARGETS[id])
	return data


func _migrate_winter(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["economy_revision"] = ECONOMY_REVISION
	for key in ["seed_inventory", "storage", "mastery"]:
		data[key]["icecap"] = 0
	data["market_core"]["icecap"] = {"seed": 1500000000.0, "sell": 2000000000.0}
	data["market"]["icecap"] = {"seed": 1500000000.0, "sell": 2000000000.0, "change": 0.0, "history": [2000000000.0]}
	data["island3_unlocked"] = false
	data["island_plots"]["3"] = _empty_winter(false)
	for field in data["island_plots"].values():
		for plot in field:
			plot["frozen"] = false
	data["plots"] = data["island_plots"][str(int(data["current_island"]))]
	data["inventory_items"] = _empty_items()
	data["island_sales"]["3"] = 0.0
	data["frost_timer"] = 150.0
	data["frost_active"] = false
	data["frost_cleared"] = 0
	data["frost_target_count"] = 12
	data["thaw_remaining"] = 0.0
	for id in ["winter_ground", "winter_harvest", "winter_frost"]:
		data["quest_progress"][id] = 0
	for id in data["quest_claimed"]:
		data["quest_progress"][id] = float(QUEST_TARGETS[id])
	return data


func _migrate_activities(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["mechanics_revision"] = 2
	data["export_cycle_sold"] = 0
	data["export_qualified_cycles"] = []
	data["quest_progress"]["export"] = 3 if data["quest_claimed"].has("export") else 0
	for id in ["starter_crash", "starter_spike", "starter_combo"]:
		data["quest_progress"][id] = 0
	return data


func _migrate_pests(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["mechanics_revision"] = 3
	data["pest_timer"] = 60.0
	for field in data["island_plots"].values():
		for plot in field:
			plot["pests"] = false
			plot["pest_damage"] = 0.0
			plot["ripe_age"] = 0.0
			plot["plant_age"] = 0.0
			plot["pest_delay"] = 0.0
	data["plots"] = data["island_plots"][str(int(data["current_island"]))]
	return data


func _migrate_qol(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	# This stage adds revision4 fields only. Later equipment/debug migrations
	# must still recognize older saves after this stage has run.
	data["mechanics_revision"] = 4
	data["tracked_seeds"] = ["russet", "golden", "giant", "radioactive"]
	data["surge_timer"] = SURGE_INTERVAL
	data["surge_remaining"] = 0.0
	data["surge_crop"] = str(data["selected_crop"])
	data["surge_factor"] = 1.0
	for field in data["island_plots"].values():
		for plot in field:
			# Migrate continuous old damage to completed thirds, never worsening it.
			plot["pest_ticks"] = mini(2, int(floor(float(plot.get("pest_damage", 0.0)) * 3.0)))
			plot["pest_damage"] = float(plot["pest_ticks"]) / 3.0
			plot["pest_elapsed"] = 0.0
			plot["pest_destroyed"] = false
			plot["yield_total"] = int(ceil(float(plot["pending"]) * 3.0 / (3 - int(plot["pest_ticks"])))) if int(plot["pending"]) > 0 else 0
			plot["yield_taken"] = 0
	data["plots"] = data["island_plots"][str(int(data["current_island"]))]
	return data


func _valid_equipment(raw: Variant, owned: Variant) -> bool:
	if not raw is Dictionary or not owned is Dictionary or raw.size() != EQUIPMENT_SLOTS.size():
		return false
	var seen: Array[String] = []
	for slot in EQUIPMENT_SLOTS:
		if not raw.has(slot) or not raw[slot] is String:
			return false
		var id: String = str(raw[slot])
		if id.is_empty():
			continue
		if not ITEM_CATALOG.has(id) or str(ITEM_CATALOG[id].get("slot", "")) != slot or seen.has(id):
			return false
		if not _number(owned.get(id), 1.0, float(ITEM_CATALOG[id]["max_count"]), true):
			return false
		seen.append(id)
	return true


func _valid_trophies(raw: Variant, maximum_roll: int) -> bool:
	if not raw is Array or raw.size() > TROPHY_LIMIT:
		return false
	var seen: Array[String] = []
	for entry in raw:
		if not entry is Dictionary:
			return false
		for key in ["key", "item_id", "tier", "title"]:
			if not entry.has(key) or not entry[key] is String or str(entry[key]).length() > 4096:
				return false
		if not ROLL_TIERS.has(str(entry["tier"])) or not entry.get("debug") is bool:
			return false
		if not str(entry["item_id"]).is_empty() and not ITEM_CATALOG.has(str(entry["item_id"])):
			return false
		if seen.has(str(entry["key"])) or str(entry["key"]) != _trophy_key(entry):
			return false
		if not _number(entry.get("count"), 1.0, float(maximum_roll), true) or not _number(entry.get("best_probability"), 0.000000000001, 100.0):
			return false
		if not _number(entry.get("roll_number"), 1.0, float(maximum_roll), true) or not _number(entry.get("island"), 1.0, 3.0, true):
			return false
		seen.append(str(entry["key"]))
	return true


func _valid_roll_results(raw: Variant, maximum_roll: int) -> bool:
	if not raw is Array or raw.size() > 6:
		return false
	for index in range(raw.size()):
		var result: Variant = raw[index]
		if not result is Dictionary:
			return false
		for key in ["tier", "title", "detail", "item_id"]:
			if not result.has(key) or not result[key] is String or str(result[key]).length() > 4096:
				return false
		if not ROLL_TIERS.has(str(result["tier"])) or (not str(result["item_id"]).is_empty() and not ITEM_CATALOG.has(str(result["item_id"]))):
			return false
		for key in ["crown_bonus", "bonus_roll", "debug"]:
			if not result.get(key) is bool:
				return false
		if not _number(result.get("paid_count"), 1, 5, true) or int(result["paid_count"]) not in [1, 3, 5]:
			return false
		var paid_count: int = int(result["paid_count"])
		if raw.size() != paid_count + (1 if bool(result["crown_bonus"]) else 0) or bool(result["bonus_roll"]) != (index >= paid_count):
			return false
		if not _number(result.get("transaction_index"), index, index, true) or not _number(result.get("bet"), 200.0, MAX_MONEY):
			return false
		if not _number(result.get("roll_number"), 1, float(maximum_roll), true) or not _number(result.get("island"), 1, 3, true):
			return false
		if not _number(result.get("tier_probability"), 0.000000000001, 100.0):
			return false
		if result.has("cash_awarded") or result.has("cash_kind"):
			if not _number(result.get("cash_awarded"), 0.0, MAX_MONEY) or not result.get("cash_kind") is String or result["cash_kind"] not in ["", "refund", "duplicate", "jackpot"]:
				return false
			if (float(result["cash_awarded"]) == 0.0) != str(result["cash_kind"]).is_empty():
				return false
		if not result.get("odds") is Array or result["odds"].size() != ROLL_TIERS.size():
			return false
		var seen_tiers: Array[String] = []
		var total_probability: float = 0.0
		for entry in result["odds"]:
			if not entry is Dictionary or not entry.get("tier") is String or not ROLL_TIERS.has(str(entry["tier"])) or seen_tiers.has(str(entry["tier"])):
				return false
			if not _number(entry.get("chance"), 0.000000000001, 100.0):
				return false
			if str(entry["tier"]) == str(result["tier"]) and not is_equal_approx(float(entry["chance"]), float(result["tier_probability"])):
				return false
			total_probability += float(entry["chance"])
			seen_tiers.append(str(entry["tier"]))
		if not is_equal_approx(total_probability, 100.0):
			return false
	return true


func _valid_roll_accounting(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	for key in ["balance_before", "paid_total", "balance_after_charge", "cash_returned", "balance_after", "refunds", "duplicate_returns", "jackpot_returns"]:
		if not _number(raw.get(key), 0.0, MAX_MONEY):
			return false
	if not _number(raw.get("net_change"), -MAX_MONEY, MAX_MONEY) or not _number(raw.get("paid_count"), 1, 5, true) or int(raw["paid_count"]) not in [1, 3, 5] or not _number(raw.get("bonus_count"), 0, 1, true):
		return false
	if float(raw["paid_total"]) <= 0.0 or float(raw["paid_total"]) > float(raw["balance_before"]):
		return false
	if not is_equal_approx(float(raw["balance_after_charge"]), maxf(0.0, float(raw["balance_before"]) - float(raw["paid_total"]))):
		return false
	if not is_equal_approx(float(raw["cash_returned"]), float(raw["refunds"]) + float(raw["duplicate_returns"]) + float(raw["jackpot_returns"])):
		return false
	return is_equal_approx(float(raw["balance_after"]), float(raw["balance_after_charge"]) + float(raw["cash_returned"])) and is_equal_approx(float(raw["net_change"]), float(raw["balance_after"]) - float(raw["balance_before"]))


func _valid_precise_coins(data: Dictionary) -> bool:
	if not data.has("coins_scientific"):
		return true
	var encoded: Variant = data["coins_scientific"]
	if not encoded is String or encoded.length() > 64 or not encoded.is_valid_float():
		return false
	var precise: float = encoded.to_float()
	if not _number(precise, -MAX_MONEY, MAX_MONEY) or not _number(data.get("coins"), -MAX_MONEY, MAX_MONEY):
		return false
	# Godot's numeric JSON path rounds tiny balances to zero. Keep its legacy
	# numeric field, but accept an exact scientific string only when that field
	# matches either the real value or Godot's own numeric round trip of it.
	var numeric: float = float(data["coins"])
	if numeric == precise:
		return true
	if signf(numeric) == signf(precise) and absf(numeric - precise) <= maxf(absf(numeric), absf(precise)) * 0.00000000000001:
		return true
	var json_value: Variant = JSON.parse_string(JSON.stringify(precise))
	return (json_value is int or json_value is float) and numeric == float(json_value)


func _saved_stock_cap(data: Dictionary, crop: String) -> float:
	if int(data.get("mechanics_revision", 0)) < 8:
		return 31.0
	if int(data["current_island"]) >= 3 and str(data["surge_kind"]) == "rocket" and crop == str(data["surge_crop"]) and float(data["surge_remaining"]) > 0.0:
		return MAX_PRICE_MULTIPLIER
	return 101.0 if int(data["current_island"]) >= 3 else 30.99


func _valid_stock_events(data: Dictionary) -> bool:
	if not _number(data.get("current_island"), 1, 3, true):
		return false
	var winter: bool = int(data["current_island"]) >= 3
	var cap: float = 101.0 if winter else 30.99
	if not data.get("surge_kind") is String or data["surge_kind"] not in ["normal", "rocket"] or not data.get("rocket_pending") is bool:
		return false
	if not _number(data.get("rocket_timer"), 0.000001, ROCKET_INTERVAL) or not _number(data.get("rocket_factor"), 1.0, MAX_PRICE_MULTIPLIER):
		return false
	if not _number(data.get("natural_remaining"), 0, SURGE_DURATION) or not _number(data.get("natural_factor"), 1.0, cap):
		return false
	for key: String in ["rocket_crop", "natural_crop", "surge_crop"]:
		if not data.get(key) is String or data[key] not in CROP_IDS:
			return false
	if not _number(data.get("surge_remaining"), 0, SURGE_DURATION) or not _number(data.get("surge_factor"), 1, MAX_PRICE_MULTIPLIER):
		return false
	if bool(data["rocket_pending"]):
		if not winter or float(data["rocket_factor"]) < (ROCKET_MIN_MULTIPLIER if int(data.get("mechanics_revision", 0)) >= 9 else 151.0) or not is_equal_approx(float(data["rocket_timer"]), ROCKET_INTERVAL):
			return false
	elif float(data["rocket_factor"]) != 1.0:
		return false
	if data["surge_kind"] == "rocket":
		if not winter or float(data["surge_remaining"]) <= 0.0 or float(data["surge_factor"]) < (ROCKET_MIN_MULTIPLIER if int(data.get("mechanics_revision", 0)) >= 9 else 151.0):
			return false
	elif float(data["surge_factor"]) > cap:
		return false
	if float(data["natural_remaining"]) == 0.0:
		return float(data["natural_factor"]) == 1.0
	return float(data["natural_factor"]) >= 21.0


func _migrate_field_access() -> void:
	# Only unoccupied land is reclaimed. Retained beds stay usable after harvest
	# and save/load; buying the expansion opens all remaining land once.
	field_expansions = {"2": false, "3": false}
	retained_beds = {"2": [], "3": []}
	for id: String in ["2", "3"]:
		var field: Array = island_plots[id]
		var available: bool = island2_unlocked if id == "2" else island3_unlocked
		if not available: continue
		for index in range(field.size() / 2, field.size()):
			var plot: Dictionary = field[index]
			var occupied: bool = int(plot.stage) > 0 or int(plot.pending) > 0 or bool(plot.frozen)
			plot.unlocked = occupied
			if occupied: retained_beds[id].append(index)
			else: plot.tilled = false
		if retained_beds[id].size() == field.size() / 2:
			field_expansions[id] = true
			retained_beds[id] = []


func _valid_field_access(data: Dictionary) -> bool:
	if not data.get("tax_credit_eligible") is bool: return false
	if not _number(data.get("coins"), -MAX_MONEY, MAX_MONEY) or not data.get("blind_cycle") is Dictionary: return false
	if bool(data.tax_credit_eligible) and (float(data.coins) >= 0.0 or bool(data.blind_cycle.get("run_over", false))): return false
	for key: String in ["field_expansions", "retained_beds"]:
		if not data.get(key) is Dictionary or data[key].size() != 2: return false
	for id: String in ["2", "3"]:
		if not data.field_expansions.get(id) is bool or not data.retained_beds.get(id) is Array: return false
		var available: bool = bool(data.get("island2_unlocked", false)) if id == "2" else bool(data.get("island3_unlocked", false))
		var retained: Array = data.retained_beds[id]
		if (not available and (data.field_expansions[id] or not retained.is_empty())) or (data.field_expansions[id] and not retained.is_empty()): return false
		var total: int = 48 if id == "2" else 80
		var seen: Array[int] = []
		if retained.size() > total / 2: return false
		for value in retained:
			if not _number(value, total / 2, total - 1, true) or seen.has(int(value)): return false
			seen.append(int(value))
	return true


func _valid_save(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var data: Dictionary = raw
	if data.has("npc_history") and not NpcRoster.valid_history(data.npc_history): return false
	if data.has("tutorial_progress"):
		var progress: Variant = data["tutorial_progress"]
		if not progress is Dictionary or not _number(progress.get("version"), 1.0, 2.0, true) or not _number(progress.get("step"), 0.0, 100.0, true) or not progress.get("completed") is bool or not _number(progress.get("plot"), 0.0, 23.0, true):
			return false
	if data.has("farm_help") and not FarmHelp.valid(data.farm_help):
		return false
	if data.has("builds") and is_instance_valid(build_system) and build_system.has_method("valid_data") and not build_system.valid_data(data["builds"]):
		return false
	if data.has("activities") and is_instance_valid(activity_system) and activity_system.has_method("valid_data") and not activity_system.valid_data(data["activities"]):
		return false
	if data.has("equipment") and not _valid_equipment(data["equipment"], data.get("inventory_items", {})):
		return false
	if data.has("last_roll_accounting") and not _valid_roll_accounting(data["last_roll_accounting"]):
		return false
	if not data.has("schema_version") or not _number(data["schema_version"], 2.0, 3.0, true):
		return false
	var legacy: bool = int(data["schema_version"]) == 2
	var rebalanced: bool = data.has("economy_revision")
	if rebalanced and (legacy or not _number(data["economy_revision"], 2.0, 3.0, true)):
		return false
	if not rebalanced and (data.has("export_factor") or data.has("lifetime_sales")):
		return false
	var newest: bool = rebalanced and int(data["economy_revision"]) == 3
	if data.has("mechanics_revision") and (not newest or not _number(data["mechanics_revision"], 2.0, float(MECHANICS_REVISION), true)):
		return false
	if int(data.get("mechanics_revision", 0)) >= 21 and not _valid_field_access(data):
		return false
	if int(data.get("mechanics_revision", 0)) >= 6 and not data.has("equipment"):
		return false
	if int(data.get("mechanics_revision", 0)) >= 8 and not _valid_stock_events(data):
		return false
	if int(data.get("mechanics_revision", 0)) >= 9:
		if not BlindRules.valid_cycle(data.get("blind_cycle"), MAX_MONEY, SURGE_DURATION, int(data.get("mechanics_revision", 0)) == 9):
			return false
		var cycle: Dictionary = data.blind_cycle
		if int(cycle.island) < int(data.get("current_island", 1)) or (int(cycle.island) >= 2 and not data.get("island2_unlocked", false)) or (int(cycle.island) >= 3 and not data.get("island3_unlocked", false)):
			return false
		if _number(data.get("coins"), -MAX_MONEY, MAX_MONEY) and float(data.coins) < BlindRules.bankruptcy(int(cycle.island)) and not bool(cycle.run_over):
			return false
	if int(data.get("mechanics_revision", 0)) >= 11:
		var saved_climate: Variant = data.get("climate")
		if saved_climate is Dictionary and int(data.mechanics_revision) == 11:
			saved_climate = saved_climate.duplicate(true)
			saved_climate.introduced = false
			saved_climate.intro_pending = false
		if int(data.mechanics_revision) >= 16 and (not saved_climate is Dictionary or not saved_climate.has("operations")): return false
		if int(data.mechanics_revision) >= 17 and (not saved_climate is Dictionary or not saved_climate.has("lesson")): return false
		if not ClimateSystem.valid(saved_climate, MAX_MONEY): return false
		if int(data.mechanics_revision) >= 18:
			for supply in saved_climate.operations.islands.values():
				if not supply.has("can") or not supply.has("refilled"): return false
	if not data.has("mechanics_revision") and (data.has("export_cycle_sold") or data.has("export_qualified_cycles")):
		return false
	var save_crops: Array[String] = ["russet", "golden", "giant", "radioactive"]
	if not legacy:
		save_crops.append("sunburst")
	if newest:
		save_crops.append("icecap")
	var ranges: Dictionary = {
		"schema_version": [2.0, 3.0, true], "coins": [-MAX_MONEY, MAX_MONEY, false],
		"capacity": [200.0, float(MAX_INVENTORY), true], "elapsed": [0.0, 1.0e15, false],
		"combo_count": [0.0, float(MAX_INVENTORY), true], "combo_multiplier": [1.0, 16.0, true],
		"combo_time": [0.0, 3.5, false], "luck": [1.0, 100.0, false], "permanent_yield": [0.0, 100.0, false],
		"roll_count": [0.0, float(MAX_INVENTORY), true], "expansion": [0.0, 1.0, true], "barn_level": [0.0, 20.0, true],
		"event_remaining": [0.0, 60.0, false], "boost_remaining": [0.0, 30.0, false], "boost_factor": [1.0, 25.0, false],
		"market_clock": [0.0, 3.0, false], "event_in": [0.0, 55.0, false], "relief_clock": [0.0, 15.0, false],
	}
	if rebalanced:
		ranges["luck"][1] = 10.0
		ranges["event_remaining"][1] = 5.0 if newest else 2.0
		ranges["boost_remaining"][1] = 5.0 if newest else 2.0
		ranges["boost_factor"][1] = 3.0
		ranges["market_clock"][1] = MARKET_TICK_SECONDS if newest else 1.0
		ranges["event_in"][1] = 11.0
		ranges["event_strength"] = [0.3, 16.0 if newest else 6.0, false]
		ranges["lifetime_sales"] = [0.0, MAX_MONEY, false]
		ranges["pending_roll_boost"] = [0.0, 3.0, false]
	if int(data.get("mechanics_revision", 0)) >= 3:
		ranges["pest_timer"] = [0.000001, 100.0, false]
	if int(data.get("mechanics_revision", 0)) >= 4:
		ranges["surge_timer"] = [0.000001, SURGE_INTERVAL, false]
		ranges["surge_remaining"] = [0.0, SURGE_DURATION, false]
		ranges["surge_factor"] = [1.0, MAX_PRICE_MULTIPLIER if int(data.get("mechanics_revision", 0)) >= 8 else 31.0, false]
		if not data.has("surge_crop") or not data["surge_crop"] is String or not CROP_IDS.has(data["surge_crop"]):
			return false
		if not data.has("tracked_seeds") or not data["tracked_seeds"] is Array or data["tracked_seeds"].size() > CROP_IDS.size():
			return false
		var tracked_seen: Array[String] = []
		for id in data["tracked_seeds"]:
			if not id is String or not CROP_IDS.has(id) or tracked_seen.has(id):
				return false
			tracked_seen.append(id)
	for key in ranges:
		if not data.has(key) or not _number(data[key], float(ranges[key][0]), float(ranges[key][1]), bool(ranges[key][2])):
			return false
	if not _valid_precise_coins(data):
		return false
	var has_debug_data: bool = int(data.get("mechanics_revision", 0)) >= 7 or data.has("debug_luck_multiplier") or data.has("trophies")
	if has_debug_data:
		if data.has("debug_islands_modified") and not data.debug_islands_modified is bool:
			return false
		if not _number(data.get("debug_luck_multiplier"), 1.0, DEBUG_LUCK_LIMIT) or not data.get("debug_money_modified") is bool:
			return false
		if not _valid_trophies(data.get("trophies"), int(data["roll_count"])) or not _valid_roll_results(data.get("last_roll_results"), int(data["roll_count"])):
			return false
		if not data.get("harvest_fraction") is Dictionary or data["harvest_fraction"].size() != CROP_IDS.size():
			return false
		for id in CROP_IDS:
			if not _number(data["harvest_fraction"].get(id), 0.0, 1.0) or float(data["harvest_fraction"][id]) >= 1.0:
				return false
	if int(data.get("mechanics_revision", 0)) >= 4:
		if (float(data["surge_remaining"]) == 0.0 and float(data["surge_factor"]) != 1.0) or (float(data["surge_remaining"]) > 0.0 and float(data["surge_factor"]) < 6.0):
			return false
	for key in ["selected_crop", "news", "event_name", "current_event", "event_crop", "rng_seed", "rng_state"]:
		if not data.has(key) or not data[key] is String or data[key].length() > 4096:
			return false
	if not data["rng_seed"].is_valid_int() or not data["rng_state"].is_valid_int():
		return false
	if not save_crops.has(data["selected_crop"]) or not save_crops.has(data["event_crop"]):
		return false
	if data["current_event"] != "" and not EVENT_IDS.has(data["current_event"]):
		return false
	if rebalanced and data["current_event"] == "" and float(data["event_strength"]) != 1.0:
		return false
	if (data["current_event"] == "") != (float(data["event_remaining"]) == 0.0):
		return false
	if float(data["boost_remaining"]) == 0.0 and float(data["boost_factor"]) != 1.0:
		return false
	if newest:
		if not data.has("inventory_items") or not data["inventory_items"] is Dictionary:
			return false
		for id in data["inventory_items"]:
			if not ITEM_CATALOG.has(id) or not _number(data["inventory_items"][id], 0.0, float(ITEM_CATALOG[id]["max_count"]), true):
				return false
		for id in ITEM_CATALOG:
			var revision: int = int(data.get("mechanics_revision", 0))
			var required: bool = revision >= 6 or (revision >= 5 and not ITEM_CATALOG[id].has("role")) or not ITEM_CATALOG[id].has("kind")
			if required and not data["inventory_items"].has(id):
				return false
	var expected_capacity: int = 200
	for level in range(int(data["barn_level"])):
		expected_capacity += int(200.0 * pow(4.0, level))
	if newest:
		var revised_artifacts: bool = int(data.get("mechanics_revision", 0)) >= 20
		expected_capacity = mini(MAX_INVENTORY, int(floor(expected_capacity * (1.0 + int(data["inventory_items"]["winter_weave"]) * (0.20 if revised_artifacts else 0.05) + int(data["inventory_items"]["bottomless_sack"]) * (0.60 if revised_artifacts else 0.20)) + (0.000001 if revised_artifacts else 0.0))))
	if int(data["capacity"]) != expected_capacity:
		return false
	if int(data["combo_multiplier"]) not in [1, 2, 4, 8, 16]:
		return false
	if int(data["combo_count"]) == 0 and (float(data["combo_time"]) > 0.0 or int(data["combo_multiplier"]) != 1):
		return false
	if int(data["combo_count"]) > 0 and (float(data["combo_time"]) == 0.0 or int(data["combo_multiplier"]) != mini(16, int(pow(2.0, minf(4.0, float(data["combo_count"]) - 1.0))))):
		return false
	for key in ["seed_inventory", "storage", "mastery"]:
		if not data.has(key) or not data[key] is Dictionary or data[key].size() != save_crops.size():
			return false
		for id in save_crops:
			if not data[key].has(id) or not _number(data[key][id], 0.0, float(MAX_INVENTORY), true):
				return false
	if not data.has("tools") or not data["tools"] is Dictionary or data["tools"].size() != 3:
		return false
	for key in TOOL_COSTS:
		if not data["tools"].has(key) or not _number(data["tools"][key], 0.0, 3.0 if newest else 2.0, true):
			return false
	if int(data.get("mechanics_revision", 0)) >= 18:
		for supply in data.climate.operations.islands.values():
			if float(supply.can) > 16.0 + 16.0 * int(data.tools.water): return false
	for key in ["market", "market_core"]:
		if not data.has(key) or not data[key] is Dictionary or data[key].size() != save_crops.size():
			return false
		for id in save_crops:
			if not data[key].has(id) or not data[key][id] is Dictionary:
				return false
			var entry: Dictionary = data[key][id]
			if not entry.has("seed") or not entry.has("sell") or not _number(entry["seed"], 0.0001, 1.0e30) or not _number(entry["sell"], 0.0001, 1.0e30):
				return false
			if rebalanced and key == "market_core" and not _number(entry["sell"], float(CROPS[id]["base"]) * 0.35 - 0.000001, float(CROPS[id]["base"]) * 3.0 + 0.000001):
				return false
			if data.has("mechanics_revision") and key == "market" and float(entry["sell"]) > float(CROPS[id]["base"]) * _saved_stock_cap(data, id) + 0.000001:
				return false
			if key == "market":
				if not entry.has("change") or not _number(entry["change"], -100.0, 1.0e22):
					return false
				if not entry.has("history") or not entry["history"] is Array or entry["history"].size() < 1 or entry["history"].size() > 40:
					return false
				for value in entry["history"]:
					if not _number(value, 0.0001, 1.0e30):
						return false
	if not data.has("plots"):
		return false
	if legacy:
		if not _valid_plots(data["plots"], 1, data, true):
			return false
	else:
		if not _valid_islands(data):
			return false
	if not data.has("dex") or not data["dex"] is Array or data["dex"].size() > 4:
		return false
	var seen: Array[String] = []
	for entry in data["dex"]:
		if not entry is String or not MUTATION_IDS.has(entry) or seen.has(entry):
			return false
		seen.append(entry)
	if not data.has("mutations") or not data["mutations"] is Array or data["mutations"].size() > save_crops.size() * MUTATION_IDS.size():
		return false
	var used: int = 0
	for id in save_crops:
		used += int(data["storage"][id])
	for raw_crate in data["mutations"]:
		if not raw_crate is Dictionary:
			return false
		var crate: Dictionary = raw_crate
		for key in ["id", "name", "crop"]:
			if not crate.has(key) or not crate[key] is String or crate[key].length() > 200:
				return false
		if not MUTATION_IDS.has(crate["id"]) or not save_crops.has(crate["crop"]) or not seen.has(crate["id"]):
			return false
		if not crate.has("count") or not _number(crate["count"], 1.0, float(MAX_INVENTORY), true):
			return false
		if not crate.has("multiplier") or not _number(crate["multiplier"], float(MUTATION_MULTIPLIERS[crate["id"]]), float(MUTATION_MULTIPLIERS[crate["id"]])):
			return false
		used += int(crate["count"])
	if data.has("builds") and is_instance_valid(build_system) and build_system.has_method("saved_storage_count"):
		used += int(build_system.saved_storage_count(data["builds"]))
	if used > int(data["capacity"]):
		return false
	if not data.has("last_roll") or not data["last_roll"] is Dictionary:
		return false
	if not data["last_roll"].is_empty():
		for key in ["tier", "title", "detail"]:
			if not data["last_roll"].has(key) or not data["last_roll"][key] is String or data["last_roll"][key].length() > 4096:
				return false
		if data["last_roll"]["tier"] not in (["common", "rare", "epic", "legendary", "mythic", "jackpot", "relic", "mystery"] if newest else ["common", "rare", "epic", "legendary", "mythic", "jackpot"]):
			return false
		if not data["last_roll"].has("bet") or not _number(data["last_roll"]["bet"], 200.0, MAX_MONEY):
			return false
	return true

func _valid_islands(data: Dictionary) -> bool:
	var rebalanced: bool = data.has("economy_revision")
	var newest: bool = rebalanced and int(data["economy_revision"]) == 3
	for key in ["island2_unlocked", "shores_first_mutation", "export_active", "golden_hat"]:
		if not data.has(key) or not data[key] is bool:
			return false
	if newest and (not data.has("island3_unlocked") or not data["island3_unlocked"] is bool):
		return false
	if not data.has("current_island") or not _number(data["current_island"], 1.0, 3.0 if newest else 2.0, true):
		return false
	if not data["island2_unlocked"] and int(data["current_island"]) != 1:
		return false
	if newest and ((int(data["current_island"]) == 3 and not data["island3_unlocked"]) or (data["island3_unlocked"] and not data["island2_unlocked"])):
		return false
	if data["selected_crop"] == "sunburst" and int(data["current_island"]) == 1:
		return false
	if data["selected_crop"] == "icecap" and int(data["current_island"]) != 3:
		return false
	if not data.has("island_plots") or not data["island_plots"] is Dictionary or data["island_plots"].size() != (3 if newest else 2):
		return false
	for island in range(1, 4 if newest else 3):
		var id: String = str(island)
		if not data["island_plots"].has(id) or not _valid_plots(data["island_plots"][id], island, data):
			return false
	if not data["plots"] is Array or data["plots"] != data["island_plots"][str(int(data["current_island"]))]:
		return false
	var max_timer: float = (5.0 if newest else 2.0) if data["export_active"] else EXPORT_MAX_WAIT
	if not rebalanced:
		max_timer = 25.0 if data["export_active"] else 90.0
	if not data.has("export_timer") or not _number(data["export_timer"], 0.000001, max_timer):
		return false
	if not data.has("export_cycles") or not _number(data["export_cycles"], 0.0, float(MAX_INVENTORY), true):
		return false
	if data["export_active"] and int(data["export_cycles"]) == 0:
		return false
	if not rebalanced and int(data["export_cycles"]) == 0 and float(data["export_timer"]) > 75.0:
		return false
	var targets: Dictionary = {"ground": 12.0, "sunburst": 40.0, "combo": 16.0, "export": 1000000.0, "mutation": 1.0}
	if rebalanced:
		targets = {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 10000000000.0, "mutation": 3.0}
	if newest:
		targets = QUEST_TARGETS if data.has("mechanics_revision") else {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 50000000000.0, "mutation": 3.0, "winter_ground": 80.0, "winter_harvest": 100000.0, "winter_frost": 3.0}
	if not data.has("quest_progress") or not data["quest_progress"] is Dictionary or data["quest_progress"].size() != targets.size():
		return false
	for id in targets:
		if not data["quest_progress"].has(id) or not _number(data["quest_progress"][id], 0.0, float(targets[id]), id != "export"):
			return false
	if not data.has("quest_claimed") or not data["quest_claimed"] is Array or data["quest_claimed"].size() > targets.size():
		return false
	var seen: Array[String] = []
	for id in data["quest_claimed"]:
		if not id is String or not targets.has(id) or seen.has(id) or float(data["quest_progress"][id]) < float(targets[id]):
			return false
		seen.append(id)
	if bool(data["golden_hat"]) != seen.has("mutation"):
		return false
	if data["shores_first_mutation"] and (not data.has("dex") or not data["dex"] is Array or int(data["mastery"]["sunburst"]) == 0 or not data["dex"].has("golden") or float(data["quest_progress"]["mutation"]) < 1.0):
		return false
	if rebalanced:
		if not data.has("export_factor") or not _number(data["export_factor"], 2.0 if data["export_active"] else 1.0, 6.0 if data["export_active"] else 1.0):
			return false
		if not data.has("island_sales") or not data["island_sales"] is Dictionary or data["island_sales"].size() != (3 if newest else 2):
			return false
		for island in range(1, 4 if newest else 3):
			if not data["island_sales"].has(str(island)) or not _number(data["island_sales"][str(island)], 0.0, MAX_MONEY):
				return false
	if not data["island2_unlocked"]:
		if data["export_active"] or float(data["export_timer"]) != (120.0 if rebalanced else 75.0) or int(data["export_cycles"]) > 0 or data["shores_first_mutation"] or (not data.has("mechanics_revision") and not seen.is_empty()):
			return false
		for id in targets:
			if str(id).begins_with("starter_"):
				continue
			if float(data["quest_progress"][id]) != 0.0:
				return false
		for key in ["seed_inventory", "storage", "mastery"]:
			if int(data[key]["sunburst"]) > 0:
				return false
	if data.has("mechanics_revision"):
		if not data.has("export_cycle_sold") or not _number(data["export_cycle_sold"], 0.0, float(MAX_INVENTORY), true):
			return false
		if not data.has("export_qualified_cycles") or not data["export_qualified_cycles"] is Array or data["export_qualified_cycles"].size() > 3:
			return false
		var seen_cycles: Array[int] = []
		for cycle in data["export_qualified_cycles"]:
			if not _number(cycle, 1.0, float(data["export_cycles"]), true) or seen_cycles.has(int(cycle)):
				return false
			seen_cycles.append(int(cycle))
		if not seen.has("export") and int(data["quest_progress"]["export"]) != seen_cycles.size():
			return false
	if newest:
		if not data.has("frost_active") or not data["frost_active"] is bool:
			return false
		if not data.has("frost_timer") or not _number(data["frost_timer"], 0.000001, 20.0 if data["frost_active"] else 220.0):
			return false
		if not data.has("frost_cleared") or not _number(data["frost_cleared"], 0.0, 12.0, true) or not data.has("frost_target_count") or not _number(data["frost_target_count"], 12.0, 12.0, true):
			return false
		if not data.has("thaw_remaining") or not _number(data["thaw_remaining"], 0.0, 5.0):
			return false
		var frozen_count: int = 0
		for plot in data["island_plots"]["3"]:
			if plot["frozen"]: frozen_count += 1
		if frozen_count != (12 - int(data["frost_cleared"]) if data["frost_active"] else 0):
			return false
		if not data["island3_unlocked"]:
			if data["frost_active"] or float(data["thaw_remaining"]) > 0.0 or int(data["frost_cleared"]) > 0:
				return false
			for id in ["winter_ground", "winter_harvest", "winter_frost"]:
				if float(data["quest_progress"][id]) != 0.0:
					return false
			for key in ["seed_inventory", "storage", "mastery"]:
				if int(data[key]["icecap"]) > 0:
					return false
	return true


func _valid_plots(raw: Variant, island: int, data: Dictionary, legacy: bool = false) -> bool:
	var newest: bool = int(data.get("economy_revision", 0)) >= 3
	var expected_size: int = 80 if island == 3 else (24 if island == 1 else 48)
	if not raw is Array or raw.size() != expected_size:
		return false
	for index in range(expected_size):
		if not raw[index] is Dictionary:
			return false
		var plot: Dictionary = raw[index]
		if plot.has("cultivated") and not plot.cultivated is bool: return false
		if plot.has("variety") and plot.variety not in ["hearty", "dry", "frost"]: return false
		for key in ["unlocked", "watered", "tilled"]:
			if not plot.has(key) or not plot[key] is bool:
				return false
		if not plot.has("crop") or not plot["crop"] is String or not CROPS.has(plot["crop"]):
			return false
		if newest and (not plot.has("frozen") or not plot["frozen"] is bool or (island != 3 and plot["frozen"])):
			return false
		if plot["crop"] == "icecap" and island != 3:
			return false
		if plot["crop"] == "sunburst" and (legacy or island == 1):
			return false
		if not plot.has("stage") or not _number(plot["stage"], 0.0, 3.0, true):
			return false
		var saved_grow: float = float(OLD_GROW_TIMES[plot.crop]) if int(data.get("mechanics_revision", 0)) < 14 else float(CROPS[plot.crop].grow)
		if not plot.has("elapsed") or not _number(plot["elapsed"], 0.0, saved_grow):
			return false
		if not plot.has("pending") or not _number(plot["pending"], 0.0, 1000000000.0, true):
			return false
		var expected_unlocked: bool = index < 12 or int(data["expansion"]) == 1
		if island == 2:
			expected_unlocked = bool(data["island2_unlocked"])
		elif island == 3:
			expected_unlocked = bool(data["island3_unlocked"])
		if island > 1 and int(data.get("mechanics_revision", 0)) >= 21:
			expected_unlocked = expected_unlocked and (index < expected_size / 2 or bool(data.field_expansions[str(island)]) or data.retained_beds[str(island)].any(func(value): return int(value) == index))
		if bool(plot["unlocked"]) != expected_unlocked:
			return false
		if int(data.get("mechanics_revision", 0)) >= 15:
			if not _number(plot.get("plant_age"), 0, 1e9) or not _number(plot.get("pest_delay"), 0, 90): return false
			if float(plot.pest_delay) != 0 and float(plot.pest_delay) < 15: return false
		var stage: int = int(plot["stage"])
		if int(data.get("mechanics_revision", 0)) >= 3:
			if not plot.has("pests") or not plot["pests"] is bool or not plot.has("pest_damage") or not _number(plot["pest_damage"], 0.0, 1.0 if int(data.get("mechanics_revision", 0)) >= 4 else 0.8) or not plot.has("ripe_age") or not _number(plot["ripe_age"], 0.0, 1000000000.0):
				return false
			if stage == 0 and (plot["pests"] or (float(plot["pest_damage"]) > 0.0 and not bool(plot.get("pest_destroyed", false))) or float(plot["ripe_age"]) > 0.0):
				return false
			if stage != 3 and float(plot["ripe_age"]) > 0.0:
				return false
		if int(data.get("mechanics_revision", 0)) >= 4:
			for key in ["pest_ticks", "yield_total", "yield_taken"]:
				if not plot.has(key) or not _number(plot[key], 0.0, 3.0 if key == "pest_ticks" else 1000000000.0, true):
					return false
			if not plot.has("pest_elapsed") or not _number(plot["pest_elapsed"], 0.0, PEST_TICK_SECONDS):
				return false
			if not plot.has("pest_destroyed") or not plot["pest_destroyed"] is bool:
				return false
			if not is_equal_approx(float(plot["pest_damage"]), float(plot["pest_ticks"]) / 3.0):
				return false
			if (plot["pest_destroyed"] and stage != 0) or (int(plot["pest_ticks"]) == 3 and stage != 0):
				return false
			if int(plot["yield_taken"]) > int(plot["yield_total"]) or int(plot["pending"]) > maxi(0, int(floor(float(plot["yield_total"]) * (3 - int(plot["pest_ticks"])) / 3.0)) - int(plot["yield_taken"])):
				return false
			if stage != 3 and (int(plot["yield_total"]) > 0 or int(plot["yield_taken"]) > 0):
				return false
		if not plot["unlocked"] and (stage > 0 or plot["tilled"]):
			return false
		if stage > 0 and not plot["tilled"]:
			return false
		if stage == 0 and (plot["watered"] or float(plot["elapsed"]) > 0.0 or int(plot["pending"]) > 0):
			return false
		if stage == 1 and (plot["watered"] or float(plot["elapsed"]) > 0.0):
			return false
		if stage >= 2 and not plot["watered"]:
			return false
		if stage == 3 and float(plot["elapsed"]) != saved_grow:
			return false
		if stage != 3 and int(plot["pending"]) > 0:
			return false
	return true


func _number(value: Variant, minimum: float, maximum: float, integer_only: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= maximum and (not integer_only or number == floor(number))
