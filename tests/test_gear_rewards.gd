extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE := "user://spud_gear_rewards_test_only.json"
var checks: int = 0
var failures: int = 0

class ActivityFixture extends Node:
	var state
	var timer: float = 1.0
	func next_boundary() -> float:
		return timer if timer > 0.0 else 3600.0
	func growth_speed_multiplier() -> float:
		return 2.5 if timer > 0.0 and state.current_island == 3 else 1.0
	func update(delta: float) -> bool:
		timer = maxf(0.0, timer - delta)
		return false
	func reset() -> void:
		timer = 0.0
	func save_data() -> Dictionary:
		return {"timer": timer}
	func valid_data(data: Variant) -> bool:
		return data is Dictionary and data.get("timer") is float and is_finite(data.timer) and data.timer >= 0.0 and data.timer <= 30.0
	func load_data(data: Dictionary) -> void:
		timer = float(data.timer)

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func winter(state) -> void:
	state.island2_unlocked = true
	state.island3_unlocked = true
	for id in ["2", "3"]:
		state.field_expansions[id] = true
		for plot in state.island_plots[id]:
			plot.unlocked = true
	state.travel_to(3)
	state.climate.acknowledge(state)

func _run() -> void:
	var state = State.new()
	var builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(state)
	root.add_child(builds)
	state.rng.seed = 59267
	var seeds: Dictionary = state.seed_inventory.duplicate(true)
	state.reset_game()
	var quote: float = state.market.russet.sell
	var seed_price: float = state.market.russet.seed
	state._grant_item("traders_visor")
	check(is_equal_approx(state.market.russet.sell, quote * 1.08), "auto-equipped stock gear affects actual sale price")
	check(is_equal_approx(state.market.russet.seed, seed_price * 1.08), "seed prices follow equipped stock bonuses")
	for _index in range(50):
		state._refresh_market(false)
	check(is_equal_approx(state.market.russet.sell, quote * 1.08) and is_equal_approx(state._market_core.russet.sell, quote), "refresh never compounds equipped stock gear")
	for id in ["traders_visor", "prospectors_hat", "market_monocle"]:
		state.inventory_items[id] = int(state.ITEM_CATALOG[id].max_count)
	state.equip_gear("prospectors_hat")
	state.equip_gear("market_monocle")
	state._refresh_market()
	check(is_equal_approx(state.item_stock_factor(), 1.40), "only equipped stock gear applies, with no duplicate stacking")
	state.surge_crop = "russet"
	state.surge_remaining = State.SURGE_DURATION
	state.surge_factor = state.stock_cap()
	state._refresh_market()
	check(is_equal_approx(state.market.russet.sell, quote * state.stock_cap()) and is_equal_approx(state.surge_info().percent, 2999.0), "gear preserves the early-island +2999 percent normal-boom ceiling")
	state.surge_factor = 12.0
	state._refresh_market()
	check(is_equal_approx(state.market.russet.sell, quote * 12.0), "stock gear improves boom roll odds without multiplying an already selected quote")
	state.surge_remaining = 0.0
	state.surge_factor = 1.0
	state._refresh_market()
	check(is_equal_approx(state.market.russet.sell, quote * 1.40), "surge expiry returns to ordinary quote with equipped gear bonus")
	state.reset_game()
	state._grant_item("straw_hat")
	state._grant_item("harvest_gloves")
	state.equip_gear("straw_hat")
	check(is_equal_approx(state.item_yield_bonus(), 0.20), "equipped farming gear changes actual yield bonus")
	state._grant_item("aurora_crown")
	state.equip_gear("aurora_crown")
	check(state.best_gear_hat() == "aurora_crown", "chosen hat can be worn in world")
	var gear_count: int = 0
	for item in state.inventory_info():
		if item.kind == "gear":
			gear_count += 1
	check(gear_count == 3, "gear is present with images and stats in full inventory")
	state.reset_game()
	state.inventory_items.straw_hat = 10
	var before_coins: float = state.coins
	seeds = state.seed_inventory.duplicate(true)
	state._grant_item("straw_hat")
	check(state.coins == before_coins and state.seed_inventory == seeds and state.inventory_items.straw_hat == 10, "capped gear preserves money, seeds and ownership")
	state._grant_item("straw_hat")
	check(state.coins == before_coins, "non-gacha duplicate cannot mint a refund")
	state.reset_game()
	state._grant_item("traders_visor")
	state._grant_item("patchwork_cap")
	state.equip_gear("patchwork_cap")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.inventory_items.traders_visor == 1 and state.equipment.head == "patchwork_cap", "equipped gear and its effective bonuses survive save/load")
	var old_save: Dictionary = state._save_data().duplicate(true)
	old_save.mechanics_revision = 4
	old_save.erase("equipment")
	for id in state.ITEM_CATALOG:
		if state.ITEM_CATALOG[id].get("kind", "") == "gear":
			old_save.inventory_items.erase(id)
	write_save(old_save)
	check(state.load_game(SAVE) and state.inventory_items.size() == State.ITEM_CATALOG.size() and state.inventory_items.patchwork_cap == 0, "old eight-collectible farms load with new gear initially unowned")
	var malformed: Dictionary = state._save_data().duplicate(true)
	malformed.inventory_items.patchwork_cap = 999
	check(not state._valid_save(malformed), "invalid gear counts rejected by save validation")
	state.reset_game()
	winter(state)
	var activity := ActivityFixture.new()
	activity.state = state
	root.add_child(activity)
	state.activity_system = activity
	for island in ["1", "3"]:
		var plot: Dictionary = state.island_plots[island][4]
		plot.stage = 2
		plot.watered = true
		plot.tilled = true
		plot.elapsed = 0.0
	check(is_equal_approx(state.crop_grow_time("russet"), 4.0), "furnace hook changes displayed winter growth time")
	state.update(2.0)
	check(is_equal_approx(state.island_plots["3"][4].elapsed, 3.5) and is_equal_approx(state.island_plots["1"][4].elapsed, 2.0), "furnace expiry divides long frames correctly and boosts only winter field")
	activity.timer = 7.5
	check(state.save_game(SAVE) and state.load_game(SAVE) and activity.timer == 7.5, "activities module persists via state save hook")
	malformed = state._save_data().duplicate(true)
	malformed.activities.timer = -1.0
	check(not state._valid_save(malformed), "activities module validates save data before load")
	state.reset_game()
	check(activity.timer == 0.0, "new-game reset clears activities through optional hook")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	activity.free()
	builds.free()
	state.free()
	print("SPUD GEAR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
