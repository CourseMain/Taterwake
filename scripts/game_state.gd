class_name FarmState
extends Node

signal changed
signal notified(message: String)
signal reward_received(title: String, detail: String, rarity: String)
signal quest_completed(id: String)
signal purchase_completed(receipt: Dictionary)
signal sale_completed(receipt: Dictionary)
signal purchase_rejected(message: String)
signal run_ended
signal climate_changed(phase: String)
signal season_changed
const SeasonClock = preload("res://scripts/season_clock.gd")
var season_clock = SeasonClock.new()
# Standalone fixtures never write a player save. Main assigns the live path.
var boundary_save_path: String = ""

const NpcRoster = preload("res://scripts/npc_roster.gd")
const ClimateSystem = preload("res://scripts/climate_system.gd")
const CURRENCY_NAME: String = "Spudions"
const CURRENCY_SYMBOL: String = "\uE000"
const SAVE_VERSION: int = 4
const MECHANICS_REVISION: int = 30
const FIELD_EXPANSION_COST: float = 1200.0
const PRICE_CYCLE_SECONDS: float = 600.0
const PRICE_HISTORY_LIMIT: int = 12
const PRICE_QUOTE_SECONDS: float = 15.0
const PEST_TICK_SECONDS: float = 5.0
const SEED_PRICE_RATIO: float = 0.75
const QUEST_TARGETS: Dictionary = {"starter_crash": 10.0, "starter_spike": 10.0, "starter_combo": 12.0}
const DEFAULT_SAVE_PATH: String = "user://taterland_save_v4.json"
const PROTECTED_SAVE_PATHS: Array[String] = ["user://spud_valley_save.json", "user://spud_valley_save_v3.json"]
const CROP_IDS: Array[String] = ["russet", "golden", "giant", "radioactive", "sunburst", "icecap"]
const CROPS: Dictionary = {
	"russet": {"name": "Russet Potato", "seed": 11.25, "base": 15.0, "grow": 75.0, "yield": 3, "color": "a87b45"},
	"golden": {"name": "Golden Potato", "seed": 15.75, "base": 21.0, "grow": 105.0, "yield": 4, "color": "efc74c"},
	"giant": {"name": "Giant Potato", "seed": 13.5, "base": 18.0, "grow": 135.0, "yield": 5, "color": "c7855d"},
	"radioactive": {"name": "Radioactive Potato", "seed": 18.0, "base": 24.0, "grow": 165.0, "yield": 4, "color": "b6f064"},
	"sunburst": {"name": "Sunburst Potato", "seed": 20.25, "base": 27.0, "grow": 195.0, "yield": 3, "color": "ffab42"},
	"icecap": {"name": "Icecap Potato", "seed": 22.5, "base": 30.0, "grow": 225.0, "yield": 3, "color": "aeeaff"},
}
const MAX_GROW_SECONDS: float = 450.0
const TOOL_COSTS: Dictionary = {"hoe": [300.0, 600.0, 1200.0], "water": [400.0, 800.0, 1400.0], "harvest": [500.0, 1000.0, 1500.0]}
const BARN_COSTS: Array[float] = [300.0, 800.0, 2000.0]
const Ledger = preload("res://scripts/ledger.gd")
const OVERDRAFT_LIMIT: float = Ledger.OVERDRAFT_LIMIT
var ledger = Ledger.new()
var run_outcome: String = ""
# Transient presentation pause, never part of a save.
var accounts_open: bool = false
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
var run_over: bool = false
var harvested_total: int = 0
var coins: float:
	get: return ledger.balance()
	set(value):
		# Compatibility for debug tools and fixtures: assignments are journaled,
		# never stored in a second purse variable.
		if is_finite(value) and not run_over:
			post_money("other", "Balance adjustment", clampf(value, -MAX_MONEY, MAX_MONEY) - coins)
var selected_crop: String = "russet"
var seed_inventory: Dictionary = {"russet": 12, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
var storage: Dictionary = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
var capacity: int = 200
var tools: Dictionary = {"hoe": 0, "water": 0, "harvest": 0}
var plots: Array[Dictionary] = []
var pest_timer: float = 60.0
# Older farms retain access to occupied beds beyond the new starting boundary.
var lifetime_sales: float = 0.0
var quest_progress: Dictionary = {"starter_crash": 0, "starter_spike": 0, "starter_combo": 0}
var quest_claimed: Array[String] = []
var market: Dictionary = {}
var news: String = "Harvest your Russets. Catch a good price. Sell with F!"
var elapsed: float = 0.0
var debug_money_modified: bool = false
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
		plots.append({"unlocked": index < 12, "winter_ice": false, "stage": stage, "watered": stage > 0,
			"elapsed": float(CROPS.russet.grow) if stage == 3 else (float(CROPS.russet.grow) * 0.5 if stage == 2 else 0.0),
			"crop": "russet", "tilled": index < 4, "pending": 0, "pests": false, "pest_damage": 0.0, "ripe_age": 0.0, "plant_age": 0.0, "pest_delay": 0.0, "pest_elapsed": 0.0, "pest_ticks": 0, "pest_destroyed": false, "yield_total": 0, "yield_taken": 0})
	market.clear()
	_refresh_market()


func crop_grow_time(id: String) -> float:
	return float(CROPS[id]["grow"]) / crop_growth_speed(id)


func _growth_speed() -> float:
	return 1.0 if tutorial_active else climate.factor("growth")

func crop_growth_speed(crop: String = "") -> float:
	var speed: float = _growth_speed()
	var id: String = selected_crop if crop.is_empty() else crop
	return maxf(speed, float(CROPS[id].grow) / MAX_GROW_SECONDS)


func debug_info() -> Dictionary:
	return {"money_modified": debug_money_modified,
		"active": debug_money_modified, "money_min": 0.0, "money_limit": DEBUG_MONEY_LIMIT,
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
	post_money("other", "Debug balance multiplier", after - coins)
	debug_money_modified = debug_money_modified or coins != previous
	return _finish("DEBUG applied: purse %s. Money was multiplied once." % money(coins))


func debug_set_balance(amount: float) -> String:
	if run_over:
		return _finish("Use Recover test farm to resume this ended run.")
	if not is_finite(amount) or amount < 0.0 or amount > MAX_MONEY:
		return _finish("Enter a test balance from 0 to 100,000.")
	debug_money_modified = debug_money_modified or coins != amount
	post_money("other", "Debug balance adjustment", amount - coins)
	return _finish("DEBUG: balance set to %s. Progress kept." % money(coins, true))


func debug_recover(amount: float) -> String:
	# The scene controller authenticates this explicit test-only action. Ordinary
	# rewards and purchases still cannot change an ended run's balance.
	if not run_over:
		return _finish("This farm is still running. Use Set balance for test funds.")
	if season_clock.year == SeasonClock.LAST_YEAR:
		return _finish("The ten-year run is finished. Start a new farm.")
	if not is_finite(amount) or amount <= 0.0 or amount > MAX_MONEY:
		return _finish("Recovery needs a positive test balance up to 100,000.")
	run_over = false
	run_outcome = ""
	debug_money_modified = true
	post_money("other", "Debug balance adjustment", amount - coins)
	climate.data.collapse.clear()
	_refresh_market()
	return _finish("DEBUG: farm recovered with %s. Progress kept." % money(coins, true))


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
			entries.append({"id": "seed:" + crop, "kind": "seed", "crop": crop, "name": str(CROPS[crop]["name"]) + " Seeds", "count": int(seed_inventory[crop]), "rarity": "seed", "description": "Plant in a prepared bed.", "effect": "Select these seeds for planting", "active": selected_crop == crop, "action": "crop:" + crop})
		if int(storage[crop]) > 0:
			entries.append({"id": "crop:" + crop, "kind": "crop", "crop": crop, "name": CROPS[crop]["name"], "count": int(storage[crop]), "rarity": "crop", "description": "Harvested potatoes held for the live market.", "effect": "Sell or hold", "active": true, "sell_value": float(market[crop]["sell"]) * int(storage[crop])})
	for tool in ["hoe", "plant", "water", "harvest", "pest"]:
		var title: String = {"hoe": "Hoe", "plant": "Seed pouch", "water": "Watering can", "harvest": "Scythe", "pest": "Pest sprayer"}[tool]
		entries.append({"id": "tool:" + tool, "kind": "tool", "name": title, "count": 1, "level": int(tools.get(tool, 0)) + 1, "effect": "Use this farming tool", "action": "tool:" + tool})
	return entries


func field_columns() -> int:
	return 6

func field_rows() -> int:
	return 4

func farm_name() -> String:
	return "SPUD VALLEY"

func available_crops() -> Array[String]:
	return CROP_IDS.duplicate()

func bankruptcy_limit() -> float:
	return OVERDRAFT_LIMIT

func climate_info() -> Dictionary:
	return climate.info(self)


func post_money(category: String, label: String, amount: float) -> bool:
	if run_over: return false
	return ledger.post(season_clock.year, season_clock.season, category, label, amount)

func _end_run(reason: String) -> void:
	if run_over:
		return
	run_over = true
	run_outcome = reason
	if reason == "foreclosed": climate.capture_collapse(self)


func quest_info() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"id": "starter_crash", "title": "SEEDS FOR TOMORROW", "description": "Buy 10 seeds.", "target": 10},
		{"id": "starter_spike", "title": "FIRST CUSTOMERS", "description": "Sell 10 potatoes.", "target": 10},
		{"id": "starter_combo", "title": "FIRST HARVESTS", "description": "Harvest 12 beds.", "target": 12},
	]
	for entry in entries:
		entry.coins = QUEST_REWARD
		entry.reward_text = money(entry.coins)
		if entry.id == "starter_crash": entry.reward_text += " + 2 Golden seeds"
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
			notified.emit("QUEST COMPLETE: %s! Collect %s at the quest board." % [entry["title"], entry["reward_text"]])
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
		post_money("other", "Quest: " + str(entry.title), float(entry.coins))
		if id == "starter_crash":
			seed_inventory["golden"] = mini(MAX_INVENTORY, int(seed_inventory["golden"]) + 2)
		reward_received.emit("QUEST REWARD!", "%s: %s" % [entry["title"], entry["reward_text"]], "legendary")
		return _finish("Collected %s!" % entry["reward_text"])
	return _finish("Choose a quest from the quest board.")


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
	_relief_clock = 0.0
	for plot in plots:
		plot["pests"] = false
		plot["pest_elapsed"] = 0.0
		plot["ripe_age"] = 0.0
		plot["plant_age"] = 0.0
		plot["pest_delay"] = 0.0
	news = "Take your time. Your crops are safe during the farm tour." if active else "Your farm is ready. Plant, tend and harvest at your own pace."
	_refresh_market()
	changed.emit()


func spawn_tutorial_pest(index: int) -> bool:
	if not tutorial_active or bool(tutorial_progress.get("tour_only", false)) or index < 0 or index >= plots.size():
		return false
	var plot: Dictionary = plots[index]
	if not bool(plot["unlocked"]) or int(plot["stage"]) <= 0:
		return false
	# Only one harmless demonstration patch exists, even after a lesson resumes.
	for other_plot in plots:
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
	var growth_speed: float = _growth_speed()
	for plot in plots:
		if plot["unlocked"] and int(plot["stage"]) in [1, 2] and plot["watered"]:
			plot["stage"] = 2
			plot["elapsed"] = minf(float(CROPS[plot["crop"]]["grow"]), float(plot["elapsed"]) + step * growth_speed)
			if float(plot["elapsed"]) >= float(CROPS[plot["crop"]]["grow"]):
				plot["stage"] = 3
				dirty = true
	if dirty:
		changed.emit()


func update(delta: float) -> void:
	if ClimateSystem.Lesson.active(self): return
	if run_over or accounts_open or not is_finite(delta) or delta <= 0.0:
		return
	if tutorial_active:
		if not bool(tutorial_progress.get("tour_only", false)):
			var supply: Dictionary = ClimateSystem.Operations.local(self)
			var before: float = float(supply.water)
			supply.water = minf(ClimateSystem.Operations.capacity(self), before + delta * 6.0)
			if before != float(supply.water): changed.emit()
		_update_tutorial(delta)
		return
	# Resolve farming and weather boundaries in order.
	var remaining: float = minf(delta, 3600.0)
	var dirty: bool = false
	while remaining >= 0.000001 and not run_over and not accounts_open:
		if season_clock.seconds == 0.0: climate.start_season(self)
		farm_help.refresh_pests(self)
		var step: float = minf(remaining, season_clock.remaining())
		if climate.clock_running(self): step = minf(step, minf(climate.next_boundary(), 0.25))
		step = minf(step, 15.0 - _relief_clock)
		if is_instance_valid(activity_system) and activity_system.has_method("next_boundary"):
			step = minf(step, maxf(0.000001, float(activity_system.next_boundary())))
		for plot in plots:
			if bool(plot.get("pests", false)) and int(plot["stage"]) > 0:
				step = minf(step, PEST_TICK_SECONDS - float(plot.get("pest_elapsed", 0.0)))
			if int(plot["stage"]) == 3 and not bool(plot.get("pests", false)):
				_schedule_pest(plot)
				var until_pest: float = maxf(40.0 - float(plot.get("plant_age", 0.0)), float(plot.pest_delay) - float(plot.ripe_age))
				if until_pest > 0.000001: step = minf(step, until_pest)
		step = maxf(0.000001, step)
		remaining -= step
		elapsed += step
		_refresh_market()
		dirty = true
		_relief_clock += step
		var ripe_infestation: bool = false
		var farm_growth: float = _growth_speed()
		for plot_index in range(plots.size()):
			var plot: Dictionary = plots[plot_index]
			if season_clock.season == 3 or ClimateSystem.Operations.frozen(self, plot_index): continue
			var growth_speed: float = maxf(farm_growth, float(CROPS[plot.crop].grow) / MAX_GROW_SECONDS)
			var ripe_step: float = step if int(plot["stage"]) == 3 else 0.0
			if int(plot.stage) > 0: plot["plant_age"] = minf(1e9, float(plot.get("plant_age", 0)) + step)
			var was_infested: bool = bool(plot.get("pests", false))
			if plot["unlocked"] and int(plot["stage"]) in [1, 2] and plot["watered"]:
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
		if _relief_clock >= 15.0 - 0.000001:
			_relief_clock = maxf(0.0, _relief_clock - 15.0)
			if _seed_relief():
				dirty = true
		if season_clock.advance(step): _season_boundary()
	if dirty:
		changed.emit()


func _season_boundary() -> void:
	var was_over: bool = run_over
	if season_clock.finished():
		_end_run("completed")
		news = "Ten years complete."
	elif season_clock.season == 3:
		season_clock.autumn_loss = 0
		for plot in plots:
			if int(plot.stage) > 0: season_clock.autumn_loss += 1
			_clear_crop(plot)
			plot.tilled = false
			plot.winter_ice = true
		climate.end_working_year()
		farm_help.refresh_pests(self)
		ledger.post_fixed_costs(season_clock.year)
		if coins < OVERDRAFT_LIMIT: _end_run("foreclosed")
		news = winter_notice()
	else:
		news = "Year %d · %s" % [season_clock.year, SeasonClock.NAMES[season_clock.season]]
	# The persisted state is complete before any listener opens the Winter UI.
	if not boundary_save_path.is_empty(): save_game(boundary_save_path)
	season_changed.emit()
	if run_over and not was_over: run_ended.emit()
	if season_clock.season == 3: notified.emit(news)

func winter_notice() -> String:
	return "Winter arrived: %d unharvested bed%s lost to the cold." % [season_clock.autumn_loss, " was" if season_clock.autumn_loss == 1 else "s were"] if season_clock.autumn_loss > 0 else "Winter arrived. No unharvested crops remained in the fields."

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
	if accounts_open: return "Close the accounts to return to the farm."
	if tool == "plant" and not season_clock.can_plant(): return _finish("Planting is open in Spring and Summer. Bring in your crops before Winter.")
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
		return _finish("Choose seeds [2]")
	var climate_thawed: int = 0
	var ice_blocked: bool = false
	var affected: int = 0
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
		if action == "hoe" and season_clock.can_plant() and int(plot["stage"]) == 0 and not plot["tilled"]:
			plot["tilled"] = true
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
		return _finish("Cleared ice from %d beds." % climate_thawed)
	if ice_blocked and affected == 0:
		return _finish("Frozen beds · Use Hoe [1] to clear the ice.")

	if affected == 0:
		if action == "hoe" and not season_clock.can_plant(): return _finish("Tilling is open in Spring and Summer. Harvest before Winter.")
		if action == "water" and float(ClimateSystem.Operations.local(self).can) < 1.0:
			return _finish("Can empty · Click the tank to walk over and refill.")
		if ClimateSystem.Operations.scarce(self) and action == "pest" and float(ClimateSystem.Operations.local(self).spray) < 1.0:
			return _finish("Sprayer empty · Supplies replenish after the disaster.")
		var bed: Dictionary = plots[index]
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
		_progress_quest("starter_combo", 1.0)
	var quantity: int = maxi(0, mini(space, int(plot["pending"])))
	if quantity == 0:
		_clear_crop(plot, true)
		return 0
	plot["yield_taken"] = int(plot.get("yield_taken", 0)) + quantity
	storage[id] = int(storage[id]) + quantity
	harvested_total = mini(MAX_INVENTORY, harvested_total + quantity)
	plot["pending"] = int(plot["pending"]) - quantity
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
	var affordable: bool = valid_cost and not run_over and (cost == 0.0 or coins - cost >= OVERDRAFT_LIMIT)
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
		return _reject_purchase("Choose a crop variety from the seed shop.")
	var cost: float = float(market[id]["seed"]) * quantity
	if not can_purchase(cost):
		return _reject_purchase(purchase_refusal(cost))
	if int(seed_inventory[id]) + quantity > MAX_INVENTORY:
		return _reject_purchase("Your seed shed is full for this crop.")
	post_money("seeds", "Bought %d %s seeds" % [quantity, id], -cost)
	seed_inventory[id] = int(seed_inventory[id]) + quantity
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
	post_money("sales", "Sold %d %s sacks" % [amount, id], earnings)
	_record_sales(earnings)
	var sold_quote: float = float(market[id]["sell"])
	farm_help.observe_sale(self, id)
	_progress_quest("starter_spike", float(amount))
	var message: String = _finish("Sold %s %s for %s at %s each." % [format_number(amount), CROPS[id]["name"], money(earnings), money(sold_quote)])
	sale_completed.emit({"id": id, "quantity": amount, "price": sold_quote, "total": earnings, "owned": int(storage[id])})
	return message


func _record_sales(amount: float) -> void:
	lifetime_sales = minf(MAX_MONEY, lifetime_sales + amount)


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
	var cost: float = float(TOOL_COSTS[key][rank])
	if not can_purchase(cost):
		return _reject_purchase(purchase_refusal(cost))
	post_money("upkeep", "%s upgrade %d" % [key, rank + 1], -cost)
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
	post_money("storage", "Barn expansion %d" % (barn_level + 1), -cost)
	barn_level += 1
	_recompute_capacity()
	return _complete_purchase({"kind": "barn", "id": "barn", "name": "Barn space", "quantity": capacity - old_capacity, "cost": cost, "total": capacity, "level": barn_level}, "Barn expanded to %s potatoes. More room for your harvest." % format_number(capacity))


func field_expansion_info() -> Dictionary:
	var opened: int = 0
	for plot in plots:
		if plot.unlocked: opened += 1
	return {"opened": opened, "total": plots.size(),
		"remaining": plots.size() - opened, "cost": float(FIELD_EXPANSION_COST),
		"complete": opened == plots.size()}


func expand_field() -> String:
	if run_over:
		return "Run over. Start a new farm."
	var info: Dictionary = field_expansion_info()
	if info.complete:
		return _reject_purchase("All %d beds are already open." % int(info.total))
	if not can_purchase(float(info.cost)):
		return _reject_purchase(purchase_refusal(float(info.cost)))
	post_money("rent", "Field expansion", -float(info.cost))
	expansion = 1
	for plot in plots:
		plot["unlocked"] = true
	return _complete_purchase({"kind": "field", "id": "expansion", "name": "Garden beds", "quantity": int(info.remaining), "cost": float(info.cost), "total": int(info.total)}, "%d more beds open." % int(info.remaining))


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
	for plot in plots:
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
	accounts_open = false
	ledger = Ledger.new()
	run_outcome = ""
	season_clock = SeasonClock.new()
	npc_history.clear()
	run_over = false
	harvested_total = 0
	climate.reset()
	tutorial_active = false
	tutorial_progress = {"version": 2, "step": 0, "completed": false, "plot": 5}
	farm_help.data = FarmHelp.fresh()
	if is_instance_valid(activity_system) and activity_system.has_method("reset"):
		activity_system.reset()
	pest_timer = rng.randf_range(25.0, 100.0)
	lifetime_sales = 0.0
	quest_progress = {"starter_crash": 0, "starter_spike": 0, "starter_combo": 0}
	quest_claimed.clear()
	selected_crop = "russet"
	seed_inventory = {"russet": 12, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	storage = {"russet": 0, "golden": 0, "giant": 0, "radioactive": 0, "sunburst": 0, "icecap": 0}
	capacity = 200
	tools = {"hoe": 0, "water": 0, "harvest": 0}
	news = "Harvest your Russets. Catch a good price. Sell with F!"
	elapsed = 0.0
	debug_money_modified = false
	expansion = 0
	barn_level = 0
	_relief_clock = 0.0
	_build_starters()
	_finish("A fresh farm and \uE000 2,000. Your farm starts with a potato.")


func _save_data() -> Dictionary:
	var data: Dictionary = {"schema_version": SAVE_VERSION, "mechanics_revision": MECHANICS_REVISION,
		"ledger": ledger.save_data(), "run_outcome": run_outcome, "season_clock": season_clock.save_data(), "climate": climate.data.duplicate(true), "run_over": run_over, "harvested_total": harvested_total,
		"tutorial_progress": tutorial_progress.duplicate(true), "npc_history": npc_history.duplicate(true),
		"farm_help": farm_help.data.duplicate(true), "lifetime_sales": lifetime_sales,
		"pest_timer": pest_timer, "selected_crop": selected_crop,
		"seed_inventory": seed_inventory.duplicate(), "storage": storage.duplicate(), "capacity": capacity, "tools": tools.duplicate(),
		"plots": plots.duplicate(true), "quest_progress": quest_progress.duplicate(), "quest_claimed": quest_claimed.duplicate(),
		"news": news, "elapsed": elapsed, "debug_money_modified": debug_money_modified,
		"expansion": expansion, "barn_level": barn_level, "relief_clock": _relief_clock,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}
	if is_instance_valid(activity_system): data.activities = activity_system.save_data()
	return data

func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if path in PROTECTED_SAVE_PATHS or not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		notified.emit("Could not read the farm save. Your current farm is unchanged.")
		return false
	if file.get_length() > 2000000:
		file.close()
		_reject_save(path)
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or not _valid_save(json.data):
		_reject_save(path)
		return false
	var data: Dictionary = json.data
	climate.data = data.climate.duplicate(true)
	season_clock.load_data(data.season_clock)
	ledger.load_data(data.ledger)
	accounts_open = false
	run_outcome = data.run_outcome
	run_over = data.run_over
	tutorial_progress = data.tutorial_progress.duplicate(true)
	tutorial_active = false
	npc_history = data.npc_history.duplicate(true)
	for person in npc_history: npc_history[person].visits = int(npc_history[person].visits)
	for key in ["version", "step", "plot"]: tutorial_progress[key] = int(tutorial_progress[key])
	farm_help.data = data.farm_help.duplicate(true)
	for key in ["elapsed", "lifetime_sales", "pest_timer"]: set(key, float(data[key]))
	for key in ["capacity", "expansion", "barn_level", "harvested_total"]: set(key, int(data[key]))
	for key in ["selected_crop", "news"]: set(key, str(data[key]))
	for key in ["seed_inventory", "storage", "tools", "quest_progress"]: set(key, data[key].duplicate(true))
	debug_money_modified = data.debug_money_modified
	plots.clear()
	for plot in data.plots: plots.append(plot.duplicate(true))
	quest_claimed.assign(data.quest_claimed)
	_relief_clock = float(data.relief_clock)
	if is_instance_valid(activity_system):
		if data.has("activities"): activity_system.load_data(data.activities)
		else: activity_system.reset()
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	_refresh_market()
	_finish("Farm loaded. Crops and weather resume where you left them; no offline farming.")
	return true

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
	if path in PROTECTED_SAVE_PATHS:
		notified.emit("The original farm save is damaged or incompatible. It was left untouched.")
	elif _move_save(path, rejected_path(path)):
		notified.emit("This save is damaged or incompatible and was set aside at %s. Your current farm is unchanged." % rejected_path(path))
	else:
		notified.emit("Could not set aside the damaged or incompatible save. Your current farm is unchanged.")


func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if path in PROTECTED_SAVE_PATHS:
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


func _valid_save(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	var data: Dictionary = raw
	if data.get("schema_version") != SAVE_VERSION or data.get("mechanics_revision") != MECHANICS_REVISION: return false
	if not NpcRoster.valid_history(data.get("npc_history")) or not FarmHelp.valid(data.get("farm_help")): return false
	var progress: Variant = data.get("tutorial_progress")
	if not progress is Dictionary or progress.get("version") != 2 or not _number(progress.get("step"), 0, 100, true) or not progress.get("completed") is bool or not _number(progress.get("plot"), 0, 23, true): return false
	if not SeasonClock.valid(data.get("season_clock")): return false
	if not ClimateSystem.valid(data.get("climate"), MAX_MONEY): return false
	if not data.get("run_over") is bool or not data.get("debug_money_modified") is bool: return false
	var ranges: Dictionary = {"elapsed": [0, 1e15, false], "capacity": [200, MAX_INVENTORY, true], "barn_level": [0, 3, true], "expansion": [0, 1, true], "harvested_total": [0, MAX_INVENTORY, true], "lifetime_sales": [0, MAX_MONEY, false], "pest_timer": [0.000001, 100, false], "relief_clock": [0, 15, false]}
	for key in ranges:
		if not _number(data.get(key), ranges[key][0], ranges[key][1], ranges[key][2]): return false
	if data.has("coins") or not Ledger.valid(data.get("ledger"), int(data.season_clock.year), int(data.season_clock.season)): return false
	if data.get("run_outcome") not in ["", "foreclosed", "completed"] or data.run_over != (data.run_outcome != ""): return false
	var saved_ledger = Ledger.new()
	saved_ledger.load_data(data.ledger)
	if (int(data.season_clock.season) == 3) and not saved_ledger.is_closed(int(data.season_clock.year)): return false
	if data.run_over and not (int(data.season_clock.season) == 3): return false
	var finished: bool = int(data.season_clock.year) == 10 and int(data.season_clock.season) == 3 and float(data.season_clock.seconds) == SeasonClock.SEASON_SECONDS
	if finished != (data.run_outcome == "completed"): return false
	if data.run_outcome == "foreclosed":
		var report: Dictionary = data.climate.collapse
		if saved_ledger.balance() >= OVERDRAFT_LIMIT or report.get("year") != data.season_clock.year: return false
		if not is_equal_approx(float(report.get("balance", NAN)), saved_ledger.balance()): return false
		if not _number(report.get("year_net"), -INF, INF) or not is_equal_approx(float(report.year_net), saved_ledger.total(int(data.season_clock.year))): return false
		if report.get("categories") != saved_ledger.category_totals(int(data.season_clock.year)): return false
	if data.run_outcome == "completed" and (not finished or saved_ledger.balance() < OVERDRAFT_LIMIT): return false
	if (int(data.season_clock.season) == 3) and not data.run_over and saved_ledger.balance() < OVERDRAFT_LIMIT: return false
	for key in ["selected_crop", "news", "rng_seed", "rng_state"]:
		if not data.get(key) is String or data[key].length() > 4096: return false
	if not data.rng_seed.is_valid_int() or not data.rng_state.is_valid_int() or not data.selected_crop in CROP_IDS: return false
	var expected_capacity: int = 200
	for level in range(int(data.barn_level)): expected_capacity += int(200.0 * pow(4.0, level))
	if int(data.capacity) != expected_capacity: return false
	for key in ["seed_inventory", "storage"]:
		if not data.get(key) is Dictionary or data[key].size() != CROP_IDS.size(): return false
		for id in CROP_IDS:
			if not _number(data[key].get(id), 0, MAX_INVENTORY, true): return false
	if not data.get("tools") is Dictionary or data.tools.size() != 3: return false
	for key in TOOL_COSTS:
		if not _number(data.tools.get(key), 0, 3, true): return false
	if float(data.climate.operations.supply.can) > 16.0 + 16.0 * int(data.tools.water): return false
	if not _valid_plots(data.get("plots"), data): return false
	if (int(data.season_clock.season) == 3):
		if data.climate.phase != "calm": return false
		for plot in data.plots:
			if int(plot.stage) != 0 or plot.tilled: return false
	if not data.get("quest_progress") is Dictionary or data.quest_progress.size() != QUEST_TARGETS.size(): return false
	for id in QUEST_TARGETS:
		if not _number(data.quest_progress.get(id), 0, QUEST_TARGETS[id], true): return false
	if not data.get("quest_claimed") is Array or data.quest_claimed.size() > QUEST_TARGETS.size(): return false
	var seen: Array = []
	for id in data.quest_claimed:
		if not id is String or not QUEST_TARGETS.has(id) or seen.has(id) or float(data.quest_progress[id]) < QUEST_TARGETS[id]: return false
		seen.append(id)
	var activities = preload("res://scripts/island_activities.gd").new()
	var valid_activities: bool = not data.has("activities") or activities.valid_data(data.activities)
	activities.free()
	if not valid_activities: return false
	var used: int = 0
	for id in CROP_IDS: used += int(data.storage[id])
	return used <= MAX_INVENTORY


func _valid_plots(raw: Variant, data: Dictionary) -> bool:
	var expected_size: int = 24
	if not raw is Array or raw.size() != expected_size:
		return false
	for index in range(expected_size):
		if not raw[index] is Dictionary:
			return false
		var plot: Dictionary = raw[index]
		for key in ["unlocked", "watered", "tilled", "winter_ice"]:
			if not plot.has(key) or not plot[key] is bool:
				return false
		if not plot.has("crop") or not plot["crop"] is String or not CROPS.has(plot["crop"]):
			return false
		if not plot.has("stage") or not _number(plot["stage"], 0.0, 3.0, true):
			return false
		var saved_grow: float = float(CROPS[plot.crop].grow)
		if not plot.has("elapsed") or not _number(plot["elapsed"], 0.0, saved_grow):
			return false
		if not plot.has("pending") or not _number(plot["pending"], 0.0, 100000.0, true):
			return false
		var expected_unlocked: bool = index < 12 or int(data["expansion"]) == 1
		if bool(plot["unlocked"]) != expected_unlocked:
			return false
		if not _number(plot.get("plant_age"), 0, 1e9) or not _number(plot.get("pest_delay"), 0, 90): return false
		if float(plot.pest_delay) != 0 and float(plot.pest_delay) < 15: return false
		var stage: int = int(plot["stage"])
		if not plot.has("pests") or not plot["pests"] is bool or not plot.has("pest_damage") or not _number(plot["pest_damage"], 0.0, 1.0) or not plot.has("ripe_age") or not _number(plot["ripe_age"], 0.0, 1000000000.0):
			return false
		if stage == 0 and (plot["pests"] or (float(plot["pest_damage"]) > 0.0 and not bool(plot.get("pest_destroyed", false))) or float(plot["ripe_age"]) > 0.0):
			return false
		if stage != 3 and float(plot["ripe_age"]) > 0.0:
			return false
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
