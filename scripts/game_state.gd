class_name FarmState
extends Node

signal changed
signal notified(message: String)
signal reward_received(title: String, detail: String, rarity: String)
signal island_changed(id: int)
signal export_changed(active: bool)
signal quest_completed(id: String)
signal purchase_completed(receipt: Dictionary)
signal sale_completed(receipt: Dictionary)
signal purchase_rejected(message: String)
signal run_ended
signal climate_changed(phase: String)

const NpcRoster = preload("res://scripts/npc_roster.gd")
const ClimateSystem = preload("res://scripts/climate_system.gd")
const CURRENCY_NAME: String = "Spudions"
const CURRENCY_SYMBOL: String = "\uE000"
const SAVE_VERSION: int = 3
const ECONOMY_REVISION: int = 3
const MECHANICS_REVISION: int = 26
const FIELD_EXPANSION_COSTS: Dictionary = {1: 1200.0, 2: 1200.0, 3: 1200.0}
const PRICE_CYCLE_SECONDS: float = 600.0
const PRICE_HISTORY_LIMIT: int = 12
const PRICE_QUOTE_SECONDS: float = 15.0
const PEST_TICK_SECONDS: float = 5.0
const ISLAND2_UNLOCK_COST: float = 5000.0
const ISLAND2_UNLOCK_HARVEST: int = 500
const ISLAND3_UNLOCK_COST: float = 10000.0
const ISLAND3_UNLOCK_HARVEST: int = 25000
const EXPORT_MIN_WAIT: float = 75.0
const EXPORT_MAX_WAIT: float = 180.0
const SEED_PRICE_RATIO: float = 0.75
const QUEST_TARGETS: Dictionary = {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 3.0, "starter_crash": 10.0, "starter_spike": 10.0, "starter_combo": 12.0, "winter_ground": 80.0, "winter_harvest": 100000.0, "winter_frost": 3.0}
const DEFAULT_SAVE_PATH: String = "user://spud_valley_save_v3.json"
const LEGACY_SAVE_PATH: String = "user://spud_valley_save.json"
const CROP_IDS: Array[String] = ["russet", "golden", "giant", "radioactive", "sunburst", "icecap"]
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 11.25, "base": 15.0, "grow": 10.0, "yield": 3, "color": "a87b45"},
	"golden": {"name": "Golden Potato", "seed": 15.75, "base": 21.0, "grow": 25.0, "yield": 4, "color": "efc74c"},
	"giant": {"name": "Giant Potato", "seed": 13.5, "base": 18.0, "grow": 40.0, "yield": 5, "color": "c7855d"},
	"radioactive": {"name": "Radioactive Potato", "seed": 18.0, "base": 24.0, "grow": 50.0, "yield": 4, "color": "b6f064"},
	"sunburst": {"name": "Sunburst Potato", "seed": 20.25, "base": 27.0, "grow": 55.0, "yield": 3, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 22.5, "base": 30.0, "grow": 60.0, "yield": 3, "color": "aeeaff"},
}
const OLD_GROW_TIMES: Dictionary = {"russet": 10.0, "golden": 30.0, "giant": 45.0, "radioactive": 90.0, "sunburst": 45.0, "icecap": 60.0}
const MAX_GROW_SECONDS: float = 60.0
const TOOL_COSTS: Dictionary = {"hoe": [300.0, 600.0, 1200.0], "water": [400.0, 800.0, 1400.0], "harvest": [500.0, 1000.0, 1500.0]}
const BARN_COSTS: Array[float] = [300.0, 800.0, 2000.0]
const OVERDRAFT_LIMIT: float = -5000.0
const DEBUG_MONEY_LIMIT: float = 100000.0
const QUEST_REWARD: float = 100.0
const MAX_MONEY: float = 100000.0
const MAX_INVENTORY: int = 100000
var activity_system: Node = null

# Progress is saved; the scene controller decides when to resume the guided lesson.
const FarmHelp = preload("res://scripts/farm_help.gd")
var farm_help = FarmHelp.new()
var npc_history: Dictionary = {}
var tutorial_progress: Dictionary = {"version": 2, "step": 0, "completed": false, "plot": 5}
var tutorial_active: bool = false
var climate = ClimateSystem.new()
var _restoring_balance: bool = false
var run_over: bool = false
var harvested_total: int = 0
var coins: float = 2000.0:
	set(value):
		if not is_finite(value) or (run_over and not _restoring_balance):
			return
		coins = clampf(value, -MAX_MONEY, MAX_MONEY)
		if not _restoring_balance and coins < bankruptcy_limit():
			_end_run("bankrupt")
var selected_crop: String = "russet"
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
var island_plots: Dictionary = {}
var field_expansions: Dictionary = {"2": false, "3": false}
# Older farms retain access to occupied beds beyond the new starting boundary.
var retained_beds: Dictionary = {"2": [], "3": []}
var export_timer: float = 120.0
var lifetime_sales: float = 0.0
var island_sales: Dictionary = {"1": 0.0, "2": 0.0, "3": 0.0}
var export_active: bool = false
var export_cycles: int = 0
var export_cycle_sold: int = 0
var export_qualified_cycles: Array[int] = []
var quest_progress: Dictionary = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
var quest_claimed: Array[String] = []
var market: Dictionary = {}
var news: String = "Harvest your Russets. Catch a good price. Sell with F!"
var elapsed: float = 0.0
var debug_money_modified: bool = false
var debug_islands_modified: bool = false
var expansion: int = 0
var barn_level: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _relief_clock: float = 0.0


func _init() -> void:
	rng.randomize()
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
	_refresh_market()


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
	if not island2_unlocked or harvested_total < ISLAND3_UNLOCK_HARVEST or coins < ISLAND3_UNLOCK_COST:
		return _reject_purchase("Frosthollow needs \uE000 10,000 and 25,000 harvested potatoes. Grow your Golden Shores fortune first.")
	coins -= ISLAND3_UNLOCK_COST
	island3_unlocked = true
	frost_timer = rng.randf_range(120.0, 220.0)
	_open_starting_beds(3)
	return _complete_purchase({"kind": "island", "id": "3", "name": "Frosthollow", "quantity": 1, "cost": ISLAND3_UNLOCK_COST}, "Frosthollow unlocked · 40 beds open · 40 more at Tools.")


func winter_info() -> Dictionary:
	return {"active": frost_active, "timer": frost_timer, "cleared": frost_cleared, "target": frost_target_count, "description": "Hoe every icy bed → 1 Icecap seed."}


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
		island_plots["3"][remaining[pick]]["frozen"] = true
		remaining.remove_at(pick)
	news = "FROSTBREAK! Hoe %d icy beds in 20 seconds. Clear the field to earn an Icecap seed!" % frost_target_count
	notified.emit(news)
	changed.emit()


func _end_frost(success: bool = false) -> void:
	for plot in island_plots["3"]:
		plot["frozen"] = false
	frost_active = false
	frost_timer = rng.randf_range(120.0, 220.0)
	if success:
		seed_inventory["icecap"] = mini(MAX_INVENTORY, int(seed_inventory["icecap"]) + 1)
		_progress_quest("winter_frost", 1.0)
		_refresh_market()
		news = "FROST CLEARED! +1 Icecap seed: your manual work paid off!"
	else:
		news = "The frost melted. No challenge reward this time; your crops are safe. Prepare your Hoe for the next storm."
	notified.emit(news)
	changed.emit()


func crop_grow_time(id: String) -> float:
	return float(CROPS[id]["grow"]) / crop_growth_speed(current_island, id)


func _growth_speed(island: int) -> float:
	var factor: float = 1.0
	if island == 3 and is_instance_valid(activity_system) and activity_system.has_method("growth_speed_multiplier"):
		factor *= maxf(1.0, float(activity_system.growth_speed_multiplier()))
	return factor * (1.0 if tutorial_active else climate.factor("growth", island))


func crop_growth_speed(island: int = 0, crop: String = "") -> float:
	var speed: float = _growth_speed(current_island if island == 0 else island)
	var id: String = selected_crop if crop.is_empty() else crop
	return maxf(speed, float(CROPS[id].grow) / MAX_GROW_SECONDS)


func debug_info() -> Dictionary:
	return {"money_modified": debug_money_modified, "islands_modified": debug_islands_modified,
		"active": debug_money_modified or debug_islands_modified, "money_min": 0.0, "money_limit": DEBUG_MONEY_LIMIT,
		"description": "Money changes once. Progress is kept."}


func valid_debug_settings(money_multiplier: float) -> bool:
	if not is_finite(money_multiplier) or money_multiplier < 0.0 or money_multiplier > DEBUG_MONEY_LIMIT:
		return false
	return not (coins > 0.0 and money_multiplier > 0.0 and coins * money_multiplier == 0.0)


func apply_debug(money_multiplier: float) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not valid_debug_settings(money_multiplier):
		if is_finite(money_multiplier) and coins > 0.0 and money_multiplier > 0.0 and coins * money_multiplier == 0.0:
			return _finish("That positive multiplier is too small to keep a nonzero balance. Use x0 explicitly if you want to clear your purse.")
		return _finish("Debug ranges: money x0 to x100,000. Decimals such as 0.1 and 1e-3 work; x0 clears your purse.")
	var previous: float = coins
	var after: float = minf(MAX_MONEY, coins * money_multiplier)
	coins = after
	debug_money_modified = debug_money_modified or coins != previous
	return _finish("DEBUG applied: purse %s. Money was multiplied once." % money(coins))


func debug_set_balance(amount: float) -> String:
	if run_over:
		return _finish("Use Recover test farm to resume this ended run.")
	if not is_finite(amount) or amount < 0.0 or amount > MAX_MONEY:
		return _finish("Enter a test balance from 0 to 100,000.")
	debug_money_modified = debug_money_modified or coins != amount
	coins = amount
	return _finish("DEBUG: balance set to %s. Progress kept." % money(coins, true))


func debug_recover(amount: float) -> String:
	# The scene controller authenticates this explicit test-only action. Ordinary
	# rewards and purchases still cannot change an ended run's balance.
	if not run_over:
		return _finish("This farm is still running. Use Set balance for test funds.")
	if not is_finite(amount) or amount <= 0.0 or amount > MAX_MONEY:
		return _finish("Recovery needs a positive test balance up to 100,000.")
	run_over = false
	debug_money_modified = true
	coins = amount
	climate.data.collapse.clear()
	_refresh_market()
	return _finish("DEBUG: farm recovered with %s. Progress kept." % money(coins, true))


func debug_unlock_island(id: int) -> String:
	if run_over:
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
	return _finish("DEBUG: %s unlocked; Spudions unchanged." % ("Golden Shores" if id == 2 else "Golden Shores and Frosthollow"))

func reset_debug() -> String:
	return _finish("Debug timing reset. Your current Spudions are unchanged.")


func _recompute_capacity() -> void:
	var base: int = 200
	for level in range(barn_level):
		base += int(200.0 * pow(4.0, level))
	capacity = mini(MAX_INVENTORY, base)


func inventory_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for crop in CROP_IDS:
		if int(seed_inventory[crop]) > 0:
			entries.append({"id": "seed:" + crop, "kind": "seed", "crop": crop, "name": str(CROPS[crop]["name"]) + " Seeds", "count": int(seed_inventory[crop]), "rarity": "seed", "description": "Plant on an island where this crop is available.", "effect": "Select these seeds for planting", "active": selected_crop == crop, "action": "crop:" + crop})
		if int(storage[crop]) > 0:
			entries.append({"id": "crop:" + crop, "kind": "crop", "crop": crop, "name": CROPS[crop]["name"], "count": int(storage[crop]), "rarity": "crop", "description": "Harvested potatoes held for the live market.", "effect": "Sell or hold", "active": true, "sell_value": float(market[crop]["sell"]) * int(storage[crop])})
	for tool in ["hoe", "plant", "water", "harvest", "pest"]:
		var title: String = {"hoe": "Hoe", "plant": "Seed pouch", "water": "Watering can", "harvest": "Scythe", "pest": "Pest sprayer"}[tool]
		entries.append({"id": "tool:" + tool, "kind": "tool", "name": title, "count": 1, "level": int(tools.get(tool, 0)) + 1, "effect": "Use this farming tool", "action": "tool:" + tool})
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


func bankruptcy_limit() -> float:
	return OVERDRAFT_LIMIT

func climate_info() -> Dictionary:
	return climate.info(self)


func _end_run(_reason: String) -> void:
	if run_over:
		return
	run_over = true
	climate.capture_collapse(self)
	run_ended.emit()
	changed.emit()


func unlock_island2() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if island2_unlocked:
		return _reject_purchase("Golden Shores is already unlocked. The ferry is ready whenever you are.")
	if harvested_total < ISLAND2_UNLOCK_HARVEST or coins < ISLAND2_UNLOCK_COST:
		return _reject_purchase("Golden Shores needs \uE000 5,000 and 500 potatoes harvested. You have %s harvested; keep farming and selling!" % format_number(harvested_total))
	coins -= ISLAND2_UNLOCK_COST
	island2_unlocked = true
	export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT)
	_open_starting_beds(2)
	return _complete_purchase({"kind": "island", "id": "2", "name": "Golden Shores", "quantity": 1, "cost": ISLAND2_UNLOCK_COST}, "Golden Shores unlocked · 24 beds open · 24 more at Tools.")


func travel_to(id: int) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if id not in [1, 2, 3]:
		return _finish("The ferry visits Spud Valley, Golden Shores, and Frosthollow.")
	if id == 3 and not island3_unlocked:
		return _finish("Frosthollow needs \uE000 10,000 and 25,000 potatoes harvested. Finish your Golden Shores journey first.")
	if id == 2 and not island2_unlocked:
		return _finish("Unlock Golden Shores with \uE000 5,000 and 500 potatoes harvested before boarding.")
	if id == current_island:
		return _finish("You are already on %s." % island_name().capitalize())
	island_plots[str(current_island)] = plots
	# The carried can travels with the farmer; island tanks stay independent.
	climate.data.operations.islands[str(id)].can = ClimateSystem.Operations.local(self).can
	current_island = id
	plots = island_plots[str(id)]
	if not available_crops().has(selected_crop):
		selected_crop = "russet"
	_refresh_market()
	island_changed.emit(id)
	climate.on_arrival(self)
	changed.emit()
	return _finish("Welcome to %s! Both farms keep growing while you travel. Your Spudions, tools, seeds, and barn come with you." % island_name().capitalize())


func _toggle_export() -> void:
	if tutorial_active:
		return
	export_active = not export_active
	if export_active:
		export_cycles += 1
		export_cycle_sold = 0
		export_timer = rng.randf_range(4.0, 5.0)
		news = "The export ship is buying Golden and Sunburst potatoes at the current price."
	else:
		export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT)
		news = "The export ship has sailed. Prepare for the next shipment."
	_refresh_market()
	export_changed.emit(export_active)
	notified.emit(news)
	changed.emit()


func quest_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"id": "ground", "title": "BREAK NEW GROUND", "description": "Hoe all 48 Shores beds.", "target": 48},
		{"id": "sunburst", "title": "A TASTE OF SUNSHINE", "description": "Harvest 10,000 Sunbursts by hand.", "target": 10000},
		{"id": "combo", "title": "CLEAR THE FIELD", "description": "Harvest 48 Shores beds.", "target": 48},
		{"id": "export", "title": "CATCH THE SHIP", "description": "Sell 100+ Golden/Sunburst per Export Rush. Do it 3 times.", "target": 3},
	]
	if current_island == 1:
		entries = [
			{"id": "starter_crash", "title": "SEEDS FOR TOMORROW", "description": "Buy 10 seeds.", "target": 10},
			{"id": "starter_spike", "title": "FIRST CUSTOMERS", "description": "Sell 10 potatoes.", "target": 10},
			{"id": "starter_combo", "title": "FIRST HARVESTS", "description": "Harvest 12 beds.", "target": 12},
		]
	elif current_island == 3:
		entries = [
			{"id": "winter_ground", "title": "BREAK THE FROZEN GROUND", "description": "Hoe all 80 new beds in Frosthollow.", "target": 80},
			{"id": "winter_harvest", "title": "WINTER HARVEST", "description": "Harvest 100,000 winter potatoes by hand.", "target": 100000},
			{"id": "winter_frost", "title": "FROSTBREAKER", "description": "Beat the clock in 3 full Frostbreaks.", "target": 3},
		]
	for entry in entries:
		entry.coins = QUEST_REWARD
		entry.reward_text = money(entry.coins)
		if entry.id == "starter_crash": entry.reward_text += " + 2 Golden seeds"
		elif entry.id == "ground": entry.reward_text += " + 5 Sunburst seeds"
		elif entry.id == "winter_ground": entry.reward_text += " + 5 Icecap seeds"
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
		if id == "winter_ground":
			seed_inventory["icecap"] = mini(MAX_INVENTORY, int(seed_inventory["icecap"]) + 5)
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
	pest_timer = rng.randf_range(25.0, 100.0)
	export_active = false
	export_timer = rng.randf_range(EXPORT_MIN_WAIT, EXPORT_MAX_WAIT) if island2_unlocked else 120.0
	frost_active = false
	frost_cleared = 0
	frost_timer = rng.randf_range(120.0, 220.0)
	_relief_clock = 0.0
	for field in island_plots.values():
		for plot in field:
			plot["pests"] = false
			plot["pest_elapsed"] = 0.0
			plot["ripe_age"] = 0.0
			plot["plant_age"] = 0.0
			plot["pest_delay"] = 0.0
			plot["frozen"] = false
	news = "Take your time. Your crops are safe during the farm tour." if active else "Your farm is ready. Plant, tend and harvest at your own pace."
	_refresh_market()
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
	_refresh_market()
	dirty = true
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
	# Resolve farming and weather boundaries in order.
	var remaining: float = minf(delta, 3600.0)
	var dirty: bool = false
	while remaining >= 0.000001:
		farm_help.refresh_pests(self)
		var step: float = remaining
		if climate.clock_running(self): step = minf(step, minf(float(climate.data.timer), 0.25))
		step = minf(step, 15.0 - _relief_clock)
		if is_instance_valid(activity_system) and activity_system.has_method("next_boundary"):
			step = minf(step, maxf(0.000001, float(activity_system.next_boundary())))
		for field in island_plots.values():
			for plot in field:
				if bool(plot.get("pests", false)) and int(plot["stage"]) > 0:
					step = minf(step, PEST_TICK_SECONDS - float(plot.get("pest_elapsed", 0.0)))
				if int(plot["stage"]) == 3 and not bool(plot.get("pests", false)):
					_schedule_pest(plot)
					var until_pest: float = maxf(40.0 - float(plot.get("plant_age", 0.0)), float(plot.pest_delay) - float(plot.ripe_age))
					if until_pest > 0.000001: step = minf(step, until_pest)
		if island2_unlocked:
			step = minf(step, export_timer)
			if not export_active and export_timer > 15.0:
				step = minf(step, export_timer - 15.0)
		if current_island == 3 and island3_unlocked and climate.data.phase == "calm":
			step = minf(step, frost_timer)
		step = maxf(0.000001, step)
		remaining -= step
		elapsed += step
		_refresh_market()
		dirty = true
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
		# Advance weather and its physical effects.
		if climate.update(self, step):
			_refresh_market()
			dirty = true
		if island2_unlocked:
			var previous_export_timer: float = export_timer
			export_timer = maxf(0.0, export_timer - step)
			if not export_active and previous_export_timer > 15.000001 and export_timer <= 15.000001:
				export_timer = 15.0
				news = "Export ship in 15s. Get Golden and Sunburst crops ready."
				notified.emit(news)
				dirty = true
			if export_timer < 0.000001:
				_toggle_export()
				dirty = true
		if current_island == 3 and island3_unlocked and climate.data.phase == "calm":
			frost_timer = maxf(0.0, frost_timer - step)
			if frost_timer < 0.000001:
				if frost_active:
					_end_frost(false)
				else:
					_start_frost()
				dirty = true
		if _relief_clock >= 15.0 - 0.000001:
			_relief_clock = maxf(0.0, _relief_clock - 15.0)
			if _seed_relief():
				dirty = true
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
		return _finish("Unlock more beds at Tools · \uE000 1,200")
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
		return _finish("Harvested %s potatoes from %d patches! Stored in your barn; sell whenever you choose.%s" % [format_number(harvested), affected, " Barn full; any remaining harvest stays on the plant." if storage_used() >= capacity else ""])
	if action == "hoe" and thawed > 0:
		var thaw_note: String = " Crops are safe; keep clearing before the frost timer ends!"
		return _finish("Cleared ice from %d beds. %d/%d cleared.%s" % [thawed, frost_cleared, frost_target_count, thaw_note])
	if ClimateSystem.Operations.scarce(self) and action in ["hoe", "water"]:
		return _finish("Tended %d beds · watch the danger rings. Reserves in Climate action." % affected)
	if action == "hoe":
		return _finish("Tilled %d patches. Plant your selected seeds next." % affected)
	if action == "plant":
		return _finish("Planted %d %s seeds. Water them to start growing." % [affected, CROPS[selected_crop]["name"]])
	return _finish("Watered %d patches. Growth is underway; check prices or prepare more soil." % affected)


func _harvest_plot(plot: Dictionary) -> int:
	var space: int = capacity - storage_used()
	if space <= 0:
		return 0
	var id: String = str(plot["crop"])
	var first_cut: bool = int(plot.get("yield_total", 0)) == 0 and int(plot["pending"]) == 0
	if first_cut:
		plot["yield_total"] = int(CROPS[id]["yield"])
		plot["yield_taken"] = 0
		plot["pending"] = maxi(0, int(floor(float(plot["yield_total"]) * (3 - int(plot.get("pest_ticks", 0))) / 3.0)))
		if current_island == 2:
			_progress_quest("combo", 1.0)
		elif current_island == 1:
			_progress_quest("starter_combo", 1.0)
	var quantity: int = maxi(0, mini(space, int(plot["pending"])))
	if quantity == 0:
		_clear_crop(plot, true)
		return 0
	plot["yield_taken"] = int(plot.get("yield_taken", 0)) + quantity
	storage[id] = int(storage[id]) + quantity
	harvested_total = mini(MAX_INVENTORY, harvested_total + quantity)
	plot["pending"] = int(plot["pending"]) - quantity
	if current_island == 3:
		_progress_quest("winter_harvest", float(quantity))
	if current_island == 2 and id == "sunburst":
		_progress_quest("sunburst", float(quantity))
	if int(plot["pending"]) == 0:
		_clear_crop(plot)
	return quantity


func select_crop(id: String) -> String:
	if not available_crops().has(id):
		return _finish("Choose an available crop. Sunburst potatoes are exclusive to Golden Shores.")
	selected_crop = id
	return _finish("Selected %s. You have %s seeds ready to plant." % [CROPS[id]["name"], format_number(seed_inventory[id])])


static func seed_price_for(base_price: float) -> float:
	return snappedf(base_price * SEED_PRICE_RATIO + 1e-9, 0.01)


static func crops_by_base_price(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids:
		if CROPS.has(id): result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return float(CROPS[a].base) < float(CROPS[b].base))
	return result


func market_money(value: float) -> String:
	return money(value)

func purchase_quote(cost: float) -> Dictionary:
	var valid_cost: bool = is_finite(cost) and cost >= 0.0
	var affordable: bool = valid_cost and not run_over and (cost == 0.0 or coins >= cost)
	return {"affordable": affordable, "reason": "" if affordable else ("Run over. Start a new farm." if run_over else "Not enough Spudions.")}

func can_purchase(cost: float) -> bool:
	return bool(purchase_quote(cost).affordable)


func purchase_refusal(cost: float = -1.0) -> String:
	return str(purchase_quote(cost).reason) if cost >= 0.0 else "Not enough Spudions."

func buy_seeds(id: String, quantity: int = 5) -> String:
	if run_over:
		return "Run over. Start a new farm."
	if not CROPS.has(id) or quantity < 1 or quantity > MAX_INVENTORY:
		return _reject_purchase("Choose a crop and a positive seed quantity.")
	if not available_crops().has(id):
		return _reject_purchase("These seeds are sold on their home island. Visit its market first.")
	var cost: float = float(market[id]["seed"]) * quantity
	if not can_purchase(cost):
		return _reject_purchase(purchase_refusal(cost))
	if int(seed_inventory[id]) + quantity > MAX_INVENTORY:
		return _reject_purchase("Your seed shed is full for this crop.")
	coins -= cost
	seed_inventory[id] = int(seed_inventory[id]) + quantity
	if current_island == 1:
		_progress_quest("starter_crash", float(quantity))
	return _complete_purchase({"kind": "seeds", "id": id, "name": str(CROPS[id]["name"]).trim_suffix(" Potato"), "quantity": quantity, "cost": cost, "total": int(seed_inventory[id])}, "Bought %s %s seeds for %s at the seed counter." % [format_number(quantity), CROPS[id]["name"], money(cost)])


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
	coins = minf(MAX_MONEY, coins + earnings)
	_record_sales(earnings)
	var sold_quote: float = float(market[id]["sell"])
	farm_help.observe_sale(self, id)
	if current_island == 1:
		_progress_quest("starter_spike", float(amount))
	if current_island == 2 and export_active and id in ["golden", "sunburst"]:
		_record_export_sale(amount)
	var message: String = _finish("Sold %s %s for %s at %s each." % [format_number(amount), CROPS[id]["name"], money(earnings), money(sold_quote)])
	sale_completed.emit({"id": id, "quantity": amount, "price": sold_quote, "total": earnings, "owned": int(storage[id])})
	return message


func _record_export_sale(amount: int) -> void:
	export_cycle_sold = mini(MAX_INVENTORY, export_cycle_sold + amount)
	if export_cycle_sold >= 100 and not export_qualified_cycles.has(export_cycles) and export_qualified_cycles.size() < 3:
		export_qualified_cycles.append(export_cycles)
		_progress_quest("export", 1.0)


func _record_sales(amount: float) -> void:
	lifetime_sales = minf(MAX_MONEY, lifetime_sales + amount)
	island_sales[str(current_island)] = minf(MAX_MONEY, float(island_sales[str(current_island)]) + amount)


func storage_used() -> int:
	var total: int = 0
	for id in CROP_IDS:
		total += int(storage[id])
	return total


func barn_value() -> float:
	var total: float = 0.0
	for id in CROP_IDS:
		total += float(market[id]["sell"]) * int(storage[id])
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
		return _reject_purchase(purchase_refusal(cost))
	coins -= cost
	tools[key] = rank + 1
	if key == "water":
		return _complete_purchase({"kind": "tool", "id": key, "name": "Bigger watering can", "quantity": 1, "cost": cost, "level": rank + 1}, "Can now carries %d water. Click the tank to fill the extra space." % int(ClimateSystem.Operations.can_capacity(self)))
	var names: Dictionary = {"hoe": "Hoe", "water": "Watering can", "harvest": "Harvest scythe"}
	return _complete_purchase({"kind": "tool", "id": key, "name": names[key], "quantity": 1, "cost": cost, "level": rank + 1}, "%s upgraded to rank %d. Your manual actions now cover a bigger area!" % [key.capitalize(), rank + 1])


func upgrade_barn() -> String:
	if run_over:
		return "Run over. Start a new farm."
	if barn_level >= BARN_COSTS.size():
		return _reject_purchase("Your barn has reached its maximum capacity.")
	var cost: float = BARN_COSTS[barn_level]
	if not can_purchase(cost):
		return _reject_purchase(purchase_refusal(cost))
	var old_capacity: int = capacity
	coins -= cost
	barn_level += 1
	_recompute_capacity()
	return _complete_purchase({"kind": "barn", "id": "barn", "name": "Barn space", "quantity": capacity - old_capacity, "cost": cost, "total": capacity, "level": barn_level}, "Barn expanded to %s potatoes. More room for your harvest." % format_number(capacity))


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
		return _reject_purchase(purchase_refusal(float(info.cost)))
	coins -= float(info.cost)
	if current_island == 1: expansion = 1
	else:
		field_expansions[str(current_island)] = true
		retained_beds[str(current_island)] = []
	for plot in plots:
		plot["unlocked"] = true
	return _complete_purchase({"kind": "field", "id": "expansion", "name": "Garden beds", "quantity": int(info.remaining), "cost": float(info.cost), "total": int(info.total), "island": current_island}, "%d more beds open." % int(info.remaining))


func seasonal_price_factor() -> float:
	# Placeholder four-season cycle until the season clock owns this phase.
	return _price_factor_at(elapsed)


func _price_factor_at(seconds: float) -> float:
	return 1.0 + 0.15 * sin(TAU * fposmod(seconds, PRICE_CYCLE_SECONDS) / PRICE_CYCLE_SECONDS)


func _refresh_market() -> void:
	var drift: float = seasonal_price_factor()
	for id in CROP_IDS:
		var base: float = float(CROPS[id].base)
		# The deterministic curve lets us reconstruct real past quotes after loading,
		# independent of frame rate. Keep the live quote as the final sample.
		var history: Array = []
		var end: int = ceili(elapsed / PRICE_QUOTE_SECONDS)
		for index: int in range(maxi(0, end - PRICE_HISTORY_LIMIT + 1), end):
			history.append(base * _price_factor_at(index * PRICE_QUOTE_SECONDS))
		history.append(base * drift)
		market[id] = {"seed": seed_price_for(base), "sell": base * drift, "history": history}


func price_percent(id: String) -> int:
	return roundi((float(market[id].sell) / float(CROPS[id].base) - 1.0) * 100.0)


func price_percent_text(id: String) -> String:
	var percent: int = price_percent(id)
	return ("+" if percent >= 0 else "−") + str(absi(percent)) + "%"


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


func format_number(value: float) -> String:
	if not is_finite(value): return "0"
	var digits: String = str(absi(roundi(value)))
	var grouped: String = ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0: grouped += ","
		grouped += digits[i]
	return ("-" if value < 0.0 else "") + grouped

func money(value: float, _precise: bool = false) -> String:
	return ("-" if value < 0.0 else "") + CURRENCY_SYMBOL + " " + format_number(absf(value))

func _saved_currency_text(text: String) -> String:
	return text.replace("$", CURRENCY_SYMBOL + " ").replace("game coins", "game Spudions")


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
	field_expansions = {"2": false, "3": false}
	retained_beds = {"2": [], "3": []}
	run_over = false
	harvested_total = 0
	climate.reset()
	tutorial_active = false
	tutorial_progress = {"version": 2, "step": 0, "completed": false, "plot": 5}
	farm_help.data = FarmHelp.fresh()
	if is_instance_valid(activity_system) and activity_system.has_method("reset"):
		activity_system.reset()
	current_island = 1
	island2_unlocked = false
	island3_unlocked = false
	frost_timer = 150.0
	pest_timer = rng.randf_range(25.0, 100.0)
	frost_active = false
	frost_cleared = 0
	frost_target_count = 12
	export_timer = 120.0
	lifetime_sales = 0.0
	island_sales = {"1": 0.0, "2": 0.0, "3": 0.0}
	export_active = false
	export_cycles = 0
	export_cycle_sold = 0
	export_qualified_cycles.clear()
	quest_progress = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
	quest_claimed.clear()
	coins = 2000.0
	selected_crop = "russet"
	seed_inventory = {"russet": 12, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	storage = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	capacity = 200
	tools = {"hoe": 0, "water": 0, "harvest": 0}
	news = "Harvest your Russets. Catch a good price. Sell with F!"
	elapsed = 0.0
	debug_money_modified = false
	debug_islands_modified = false
	expansion = 0
	barn_level = 0
	_relief_clock = 0.0
	_build_starters()
	island_changed.emit(1)
	export_changed.emit(false)
	_finish("A fresh farm and \uE000 2,000. Your farm starts with a potato.")


func _save_data() -> Dictionary:
	var data: Dictionary = {"schema_version": SAVE_VERSION, "economy_revision": ECONOMY_REVISION, "mechanics_revision": MECHANICS_REVISION,
		"field_expansions": field_expansions.duplicate(), "retained_beds": retained_beds.duplicate(true),
		"climate": climate.data.duplicate(true), "run_over": run_over, "harvested_total": harvested_total,
		"tutorial_progress": tutorial_progress.duplicate(true),
		"npc_history": npc_history.duplicate(true),
		"farm_help": farm_help.data.duplicate(true),
		"export_cycle_sold": export_cycle_sold, "export_qualified_cycles": export_qualified_cycles,

		"lifetime_sales": lifetime_sales, "island_sales": island_sales,
		"island3_unlocked": island3_unlocked, "frost_timer": frost_timer, "frost_active": frost_active,
		"frost_cleared": frost_cleared, "frost_target_count": frost_target_count, "pest_timer": pest_timer, "coins": coins, "selected_crop": selected_crop,



		"seed_inventory": seed_inventory, "storage": storage, "capacity": capacity, "tools": tools,
		"plots": plots, "current_island": current_island, "island2_unlocked": island2_unlocked,
		"island_plots": island_plots,
		"export_timer": export_timer, "export_active": export_active, "export_cycles": export_cycles,
		"quest_progress": quest_progress, "quest_claimed": quest_claimed,
		"news": news,
		"elapsed": elapsed,
		"debug_money_modified": debug_money_modified, "debug_islands_modified": debug_islands_modified,
		"expansion": expansion, "barn_level": barn_level,


		"relief_clock": _relief_clock,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}
	if is_instance_valid(activity_system) and activity_system.has_method("save_data"):
		data["activities"] = activity_system.save_data()
	return data


func backup_path(path: String = DEFAULT_SAVE_PATH) -> String:
	return path + ".bak"


func rejected_path(path: String = DEFAULT_SAVE_PATH) -> String:
	return path + ".rejected"


func _move_save(source: String, destination: String) -> bool:
	var target: String = ProjectSettings.globalize_path(destination)
	if FileAccess.file_exists(destination) and DirAccess.remove_absolute(target) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), target) == OK


func _reject_save(path: String) -> void:
	if path == LEGACY_SAVE_PATH:
		notified.emit("The original farm save is damaged or incompatible. It was left untouched.")
	elif _move_save(path, rejected_path(path)):
		notified.emit("This save is damaged or incompatible and was set aside at %s. Your current farm is unchanged." % rejected_path(path))
	else:
		notified.emit("Could not set aside the damaged or incompatible save. Your current farm is unchanged.")


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
	if write_error != OK:
		notified.emit("Saving failed. Your previous save is preserved.")
		return false
	var had_previous: bool = FileAccess.file_exists(path)
	if had_previous and not _move_save(path, backup_path(path)):
		notified.emit("Could not back up the farm. Saving stopped to preserve your previous save.")
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path)) != OK:
		if had_previous:
			# If restoration fails, the previous farm remains at the backup path.
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path(path)), ProjectSettings.globalize_path(path))
		notified.emit("Saving failed. Your previous save is preserved.")
		return false
	return true


func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	var candidates: Array[String] = [path]
	if path == DEFAULT_SAVE_PATH:
		candidates.append(LEGACY_SAVE_PATH)
	var data: Dictionary = {}
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			notified.emit("Could not read the farm save. Your current farm is unchanged.")
			continue
		if file.get_length() > 2000000:
			file.close()
			_reject_save(candidate)
			continue
		var json: JSON = JSON.new()
		var parse_error: Error = json.parse(file.get_as_text())
		file.close()
		if parse_error == OK and _valid_save(json.data):
			data = _current_save_fields(json.data)
			break
		_reject_save(candidate)
	if data.is_empty():
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
	run_over = bool(data.get("run_over", false))
	harvested_total = int(data.get("harvested_total", 0))
	tutorial_active = false
	farm_help.data = data.get("farm_help", FarmHelp.fresh()).duplicate(true)
	# An established farm gets its normal game back, without a surprise tutorial.
	npc_history = data.get("npc_history", {}).duplicate(true)
	for person in npc_history: npc_history[person].visits = int(npc_history[person].visits)
	tutorial_progress = data.get("tutorial_progress", {"version": 1, "step": 0, "completed": true, "plot": 5}).duplicate(true)
	for key in ["version", "step", "plot"]:
		tutorial_progress[key] = int(tutorial_progress[key])
	for key in ["coins", "elapsed", "export_timer", "lifetime_sales", "frost_timer", "pest_timer"]:
		set(key, float(data[key]))
	for key in ["capacity", "expansion", "barn_level", "current_island", "export_cycles", "frost_cleared", "frost_target_count", "export_cycle_sold"]:
		set(key, int(data[key]))
	for key in ["selected_crop", "news"]:
		set(key, str(data[key]))
	for key in ["island2_unlocked", "export_active", "island3_unlocked", "frost_active"]:
		set(key, bool(data[key]))
	for key in ["seed_inventory", "storage", "tools", "quest_progress", "island_sales"]:
		set(key, data[key].duplicate(true))
	_recompute_capacity()
	debug_money_modified = bool(data.get("debug_money_modified", false))
	debug_islands_modified = bool(data.get("debug_islands_modified", false))
	news = _saved_currency_text(news)
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
	export_qualified_cycles.clear()
	for cycle in data["export_qualified_cycles"]:
		export_qualified_cycles.append(int(cycle))
	quest_claimed.clear()
	for entry in data["quest_claimed"]:
		quest_claimed.append(str(entry))
	_relief_clock = float(data["relief_clock"])
	if is_instance_valid(activity_system):
		if data.has("activities") and activity_system.has_method("load_data"):
			activity_system.load_data(data["activities"])
		elif activity_system.has_method("reset"):
			activity_system.reset()
	rng.seed = int(data["rng_seed"])
	rng.state = int(data["rng_state"])
	_restoring_balance = false
	if run_over and climate.data.collapse.is_empty(): climate.capture_collapse(self)
	if not run_over and coins < bankruptcy_limit():
		_end_run("bankrupt")
	_refresh_market()
	island_changed.emit(current_island)
	export_changed.emit(export_active)
	_finish("Original farm restored. Golden Shores is waiting; your original save remains a backup." if migrated else "Farm loaded. Both islands resume their saved growth and Export Rush countdown; no offline farming.")
	return true


func _migrate_v2(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["schema_version"] = 3
	for key in ["seed_inventory", "storage"]:
		data[key]["sunburst"] = 0
	data["current_island"] = 1
	data["island2_unlocked"] = false
	data["island_plots"] = {"1": data["plots"], "2": _empty_shores(false)}
	data["export_timer"] = 75.0
	data["export_active"] = false
	data["export_cycles"] = 0
	data["quest_progress"] = {"ground": 0, "sunburst": 0, "combo": 0, "export": 0.0, "starter_crash": 0, "starter_spike": 0, "starter_combo": 0, "winter_ground": 0, "winter_harvest": 0, "winter_frost": 0}
	data["quest_claimed"] = []
	return data


func _migrate_economy(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["economy_revision"] = 2
	data["export_timer"] = minf(2.0, float(data["export_timer"])) if data["export_active"] else (minf(EXPORT_MAX_WAIT, float(data["export_timer"])) if data["island2_unlocked"] else 120.0)
	data["lifetime_sales"] = 0.0
	data["island_sales"] = {"1": 0.0, "2": 0.0}
	# Preserve already collected quest rewards without allowing a second payout.
	for id in data["quest_claimed"]:
		data["quest_progress"][id] = float(QUEST_TARGETS[id])
	return data


func _migrate_winter(original: Dictionary) -> Dictionary:
	var data: Dictionary = original.duplicate(true)
	data["economy_revision"] = ECONOMY_REVISION
	for key in ["seed_inventory", "storage"]:
		data[key]["icecap"] = 0
	data["island3_unlocked"] = false
	data["island_plots"]["3"] = _empty_winter(false)
	for field in data["island_plots"].values():
		for plot in field:
			plot["frozen"] = false
	data["plots"] = data["island_plots"][str(int(data["current_island"]))]
	data["island_sales"]["3"] = 0.0
	data["frost_timer"] = 150.0
	data["frost_active"] = false
	data["frost_cleared"] = 0
	data["frost_target_count"] = 12
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
	# This stage adds revision4 fields only. Later debug migrations
	# must still recognize older saves after this stage has run.
	data["mechanics_revision"] = 4
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


# Preserve only fields understood by this version. Retired systems cannot
# contaminate a fresh save. Stored potatoes retain their variety and count.
func _current_save_fields(raw: Variant) -> Variant:
	if not raw is Dictionary: return raw
	var data: Dictionary = raw.duplicate(true)
	if _number(data.get("mechanics_revision", 0), 0, 22, true):
		var retired: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/retired_save_fields.json"))
		var held: Variant = data.get(retired.stored_crops, [])
		if not held is Array: return null
		for batch in held:
			if not batch is Dictionary or not batch.get("crop") is String or not CROP_IDS.has(batch.crop) or not _number(batch.get("count"), 1, MAX_INVENTORY, true): return null
			if not data.get("storage") is Dictionary or not _number(data.storage.get(batch.crop), 0, MAX_INVENTORY, true): return null
			var total: int = int(data.storage[batch.crop]) + int(batch.count)
			if total > MAX_INVENTORY: return null
			data.storage[batch.crop] = total
		if data.get("quest_progress") is Dictionary: data.quest_progress.erase(retired.quest)
		if data.get("quest_claimed") is Array: data.quest_claimed.erase(retired.quest)
		if data.get("activities") is Dictionary and data.activities.get("contract") is Dictionary and data.activities.contract.get("kind") == retired.contract:
			data.activities.contract.kind = "bulk"
		if not _number(data.get("barn_level"), 0, 20, true) or not _number(data.get("capacity"), 200, MAX_INVENTORY, true): return null
		var base: int = 200
		for level in range(int(data.barn_level)): base += int(200.0 * pow(4.0, level))
		data.capacity = mini(MAX_INVENTORY, base)
	if _number(data.get("mechanics_revision", 0), 0, 25, true) and data.get("farm_help") is Dictionary:
		var help: Dictionary = data.farm_help
		for key in help.keys():
			if not FarmHelp.fresh().has(key): help.erase(key)
		if help.get("dismissed") is Array:
			help.dismissed = help.dismissed.filter(func(id): return id in FarmHelp.TIP_IDS)
	if data.get("climate") is Dictionary and data.climate.get("collapse") is Dictionary:
		for key: String in ["build", "seed_factor", "sell_factor", "market_crop", "market_change"]:
			data.climate.collapse.erase(key)
	var saved_fields: Array = []
	if data.get("plots") is Array: saved_fields.append(data.plots)
	if data.get("island_plots") is Dictionary: saved_fields.append_array(data.island_plots.values())
	for field in saved_fields:
		if field is Array:
			for plot in field:
				if plot is Dictionary:
					plot.erase("cultivated")
					plot.erase("variety")
	if data.get("npc_history") is Dictionary: data.npc_history.erase("ada")
	if _number(data.get("mechanics_revision", 0), 0, 25, true):
		if data.get("quest_progress") is Dictionary and not data.has("mechanics_revision"):
			var shipped: Variant = data.quest_progress.get("export")
			if (shipped is int or shipped is float) and is_finite(float(shipped)) and shipped > MAX_INVENTORY: data.quest_progress.export = MAX_INVENTORY
		data.run_over = false
		data.harvested_total = raw.get("harvested_total", 0)
		if raw.get("mastery") is Dictionary:
			for amount in raw.mastery.values():
				if not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 0: return null
				data.harvested_total = mini(MAX_INVENTORY, int(data.harvested_total) + int(minf(MAX_INVENTORY, float(amount))))
		for key: String in ["coins", "lifetime_sales"]:
			if data.has(key):
				if not (data[key] is int or data[key] is float) or not is_finite(float(data[key])): return null
				data[key] = clampf(float(data[key]), -MAX_MONEY if key == "coins" else 0.0, MAX_MONEY)
		data.run_over = float(data.get("coins", 0)) < OVERDRAFT_LIMIT
		if _number(data.get("barn_level"), 0, 20, true):
			data.barn_level = mini(3, int(data.barn_level))
			data.capacity = 200
			for level in range(int(data.barn_level)): data.capacity += int(200.0 * pow(4.0, level))
		if data.get("island_sales") is Dictionary:
			for key in data.island_sales:
				if not (data.island_sales[key] is int or data.island_sales[key] is float) or not is_finite(float(data.island_sales[key])): return null
				data.island_sales[key] = clampf(float(data.island_sales[key]), 0, MAX_MONEY)
	if data.get("climate") is Dictionary:
		if _number(data.get("mechanics_revision", 0), 0, 25, true): data.climate.collapse = {}
		for key in data.climate.keys():
			if not ClimateSystem.fresh_data().has(key): data.climate.erase(key)
	var fields: Dictionary = _save_data()
	fields["activities"] = {}
	for key in data.keys():
		if not fields.has(key): data.erase(key)
	if _number(data.get("mechanics_revision", 0), 0, 21, true):
		if data.get("tutorial_progress") is Dictionary:
			var progress: Dictionary = data.tutorial_progress
			if progress.get("tour_only") == true and _number(progress.get("version"), 2, 2, true) and _number(progress.get("step"), 8, 100, true):
				progress.step = int(progress.step) - 1
		if data.get("npc_history") is Dictionary:
			for id in data.npc_history.keys():
				if not NpcRoster.PEOPLE.has(id): data.npc_history.erase(id)
	if _number(data.get("mechanics_revision", 0), 0, 24, true) and data.get("tutorial_progress") is Dictionary:
		var progress: Dictionary = data.tutorial_progress
		if progress.get("tour_only") == true and _number(progress.get("version"), 2, 2, true) and _number(progress.get("step"), 6, 100, true):
			progress.step = int(progress.step) - 1
	return data


func _valid_save(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var normalized: Variant = _current_save_fields(raw)
	if not normalized is Dictionary: return false
	var data: Dictionary = normalized
	if data.has("npc_history") and not NpcRoster.valid_history(data.npc_history): return false
	if data.has("tutorial_progress"):
		var progress: Variant = data["tutorial_progress"]
		if not progress is Dictionary or not _number(progress.get("version"), 1.0, 2.0, true) or not _number(progress.get("step"), 0.0, 100.0, true) or not progress.get("completed") is bool or not _number(progress.get("plot"), 0.0, 23.0, true):
			return false
	if data.has("farm_help") and not FarmHelp.valid(data.farm_help):
		return false
	if data.has("activities") and is_instance_valid(activity_system) and activity_system.has_method("valid_data") and not activity_system.valid_data(data["activities"]):
		return false
	if not data.has("schema_version") or not _number(data["schema_version"], 2.0, 3.0, true):
		return false
	var legacy: bool = int(data["schema_version"]) == 2
	var rebalanced: bool = data.has("economy_revision")
	if rebalanced and (legacy or not _number(data["economy_revision"], 2.0, 3.0, true)):
		return false
	if not rebalanced and data.has("lifetime_sales"):
		return false
	var newest: bool = rebalanced and int(data["economy_revision"]) == 3
	if data.has("mechanics_revision") and (not newest or not _number(data["mechanics_revision"], 2.0, float(MECHANICS_REVISION), true)):
		return false
	if int(data.get("mechanics_revision", 0)) >= 21 and not _valid_field_access(data):
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
	if int(data.get("mechanics_revision", 0)) >= 26:
		if not data.get("run_over") is bool or not _number(data.get("harvested_total"), 0, MAX_INVENTORY, true): return false
		if _number(data.get("coins"), -MAX_MONEY, OVERDRAFT_LIMIT - 0.000001) and not data.run_over: return false
	var save_crops: Array[String] = ["russet", "golden", "giant", "radioactive"]
	if not legacy:
		save_crops.append("sunburst")
	if newest:
		save_crops.append("icecap")
	var ranges: Dictionary = {
		"schema_version": [2.0, 3.0, true], "coins": [-MAX_MONEY, MAX_MONEY, false],
		"capacity": [200.0, float(MAX_INVENTORY), true], "elapsed": [0.0, 1.0e15, false],
		"expansion": [0.0, 1.0, true], "barn_level": [0.0, 3.0, true],
		"relief_clock": [0.0, 15.0, false],
	}
	if rebalanced:
		ranges["lifetime_sales"] = [0.0, MAX_MONEY, false]
	if int(data.get("mechanics_revision", 0)) >= 3:
		ranges["pest_timer"] = [0.000001, 100.0, false]
	for key in ranges:
		if not data.has(key) or not _number(data[key], float(ranges[key][0]), float(ranges[key][1]), bool(ranges[key][2])):
			return false
	var has_debug_data: bool = int(data.get("mechanics_revision", 0)) >= 7
	if has_debug_data:
		if data.has("debug_islands_modified") and not data.debug_islands_modified is bool:
			return false
		if not data.get("debug_money_modified") is bool:
			return false
	for key in ["selected_crop", "news", "rng_seed", "rng_state"]:
		if not data.has(key) or not data[key] is String or data[key].length() > 4096:
			return false
	if not data["rng_seed"].is_valid_int() or not data["rng_state"].is_valid_int():
		return false
	if not save_crops.has(data["selected_crop"]):
		return false
	var expected_capacity: int = 200
	for level in range(int(data["barn_level"])):
		expected_capacity += int(200.0 * pow(4.0, level))
	if int(data["capacity"]) != mini(MAX_INVENTORY, expected_capacity):
		return false
	for key in ["seed_inventory", "storage"]:
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
	if not data.has("plots"):
		return false
	if legacy:
		if not _valid_plots(data["plots"], 1, data, true):
			return false
	else:
		if not _valid_islands(data):
			return false
	var used: int = 0
	for id in save_crops:
		used += int(data["storage"][id])
	# Older farms can be overfull after losing storage bonuses; selling frees room.
	if used > MAX_INVENTORY:
		return false
	return true

func _valid_islands(data: Dictionary) -> bool:
	var rebalanced: bool = data.has("economy_revision")
	var newest: bool = rebalanced and int(data["economy_revision"]) == 3
	for key in ["island2_unlocked", "export_active"]:
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
	var targets: Dictionary = {"ground": 12.0, "sunburst": 40.0, "combo": 16.0, "export": 100000.0}
	if rebalanced:
		targets = {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 100000.0}
	if newest:
		targets = QUEST_TARGETS if data.has("mechanics_revision") else {"ground": 48.0, "sunburst": 10000.0, "combo": 48.0, "export": 100000.0, "winter_ground": 80.0, "winter_harvest": 100000.0, "winter_frost": 3.0}
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
	if rebalanced:
		if not data.has("island_sales") or not data["island_sales"] is Dictionary or data["island_sales"].size() != (3 if newest else 2):
			return false
		for island in range(1, 4 if newest else 3):
			if not data["island_sales"].has(str(island)) or not _number(data["island_sales"][str(island)], 0.0, MAX_MONEY):
				return false
	if not data["island2_unlocked"]:
		if data["export_active"] or float(data["export_timer"]) != (120.0 if rebalanced else 75.0) or int(data["export_cycles"]) > 0 or (not data.has("mechanics_revision") and not seen.is_empty()):
			return false
		for id in targets:
			if str(id).begins_with("starter_"):
				continue
			if float(data["quest_progress"][id]) != 0.0:
				return false
		for key in ["seed_inventory", "storage"]:
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
		var frozen_count: int = 0
		for plot in data["island_plots"]["3"]:
			if plot["frozen"]: frozen_count += 1
		if frozen_count != (12 - int(data["frost_cleared"]) if data["frost_active"] else 0):
			return false
		if not data["island3_unlocked"]:
			if data["frost_active"] or int(data["frost_cleared"]) > 0:
				return false
			for id in ["winter_ground", "winter_harvest", "winter_frost"]:
				if float(data["quest_progress"][id]) != 0.0:
					return false
			for key in ["seed_inventory", "storage"]:
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
		if not plot.has("pending") or not _number(plot["pending"], 0.0, 100000.0, true):
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
				if not plot.has(key) or not _number(plot[key], 0.0, 3.0 if key == "pest_ticks" else 100000.0, true):
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
