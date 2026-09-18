extends SceneTree

const State = preload("res://scripts/game_state.gd")
const SAVE := "user://spud_stock_ceiling_test_only.json"
var checks: int = 0
var failures: int = 0

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

func enter_island(state, island: int) -> void:
	if island >= 2:
		state.island2_unlocked = true
		for plot in state.island_plots["2"]:
			plot.unlocked = true
	if island == 3:
		state.island3_unlocked = true
		for plot in state.island_plots["3"]:
			plot.unlocked = true
	state.travel_to(island)

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(State.MAX_PRICE_MULTIPLIER == 31.0, "plus3000percent means31times the crop's base quote")
	check(State.SURGE_INTERVAL == 180.0 and State.SURGE_DURATION == 5.0, "stock ceiling change preserves three-minute cadence and five-second surge duration")
	for island in [1, 2, 3]:
		state.reset_game()
		enter_island(state, island)
		var crop: String = ["golden", "sunburst", "icecap"][island - 1]
		state.select_crop(crop)
		state.rng.seed = 92013 + island
		var largest: float = 0.0
		var within_range: bool = true
		for _index in range(128):
			state._start_surge()
			largest = maxf(largest, state.surge_factor)
			within_range = within_range and state.surge_factor >= 6.0 and state.surge_factor <= 31.0 and state.surge_crop == crop
			within_range = within_range and float(state.market[crop].change) >= 500.0 and float(state.market[crop].change) <= 3000.0
		check(within_range and largest > 30.0, "island%d natural selected-stock surges sample the expanded500-to3000percent range" % island)
		state.surge_factor = 31.0
		state._refresh_market(false)
		check(is_equal_approx(float(state.market[crop].sell), float(state.CROPS[crop].base) * 31.0) and is_equal_approx(float(state.surge_info().percent), 3000.0), "island%d selected quote and banner can report the new exact maximum" % island)
		check(is_equal_approx(float(state.market[crop].seed), float(state.market[crop].sell) * float(state.CROPS[crop].yield) * state.SEED_YIELD_RATIO), "island%d seed prices follow the entire new stock quote" % island)
	state.reset_game()
	state.select_crop("golden")
	state.surge_timer = 0.25
	state.update(0.249)
	check(state.surge_remaining == 0.0, "scheduled surge does not start before its boundary")
	state.update(0.001)
	state.surge_factor = 31.0
	state._refresh_market(false)
	check(state.surge_remaining == 5.0 and state.surge_timer == 180.0, "scheduled maximum surge begins with the unchanged timers")
	state.update(4.999)
	check(state.surge_remaining > 0.0 and is_equal_approx(state.market.golden.change, 3000.0), "maximum quote stays active until the full five-second window finishes")
	state.update(0.001)
	check(state.surge_remaining == 0.0 and state.surge_factor == 1.0 and is_equal_approx(state.surge_timer, 175.0), "maximum surge expires cleanly without postponing the next scheduled start")
	check(is_equal_approx(state.market.golden.sell, state._market_core.golden.sell) and state.market.golden.change < 500.0, "expired surge falls back to the ordinary underlying quote")
	state.reset_game()
	enter_island(state, 3)
	state.select_crop("icecap")
	for id in ["prospectors_hat", "market_monocle", "investor_shirt", "investor_pants", "investor_shoes", "trader_token"]:
		state._grant_item(id)
	state.surge_crop = "icecap"
	state.surge_remaining = 5.0
	state.surge_factor = 31.0
	state._start_event("shortage")
	state.event_strength = 16.0
	state.boost_remaining = 5.0
	state.boost_factor = 3.0
	state.thaw_remaining = 5.0
	state._refresh_market(false)
	check(state.item_stock_factor() > 1.0 and is_equal_approx(state.market.icecap.change, 3000.0), "equipped stock gear plus overlapping offers cannot exceed3000percent")
	check(is_equal_approx(state.market.icecap.seed, state.market.icecap.sell * 4.0 * 0.45 * 0.98), "live seeds use capped stock value and retain their existing seed-token discount")
	var quote: float = state.market.icecap.sell
	for _index in range(20):
		state._refresh_market(false)
	check(state.market.icecap.sell == quote, "refreshing a capped quote never compounds stock gear")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.surge_factor == 31.0 and is_equal_approx(state.market.icecap.change, 3000.0), "new maximum active surge remains valid through save/load")
	state.surge_remaining = 0.0
	state.surge_factor = 1.0
	state._market_core.icecap.sell = state.CROPS.icecap.base * 3.0
	state._refresh_market(false)
	check(is_equal_approx(state.market.icecap.change, 3000.0), "ordinary stacked event, gear, and thaw quotes share the same new ceiling")
	state._end_event()
	state.boost_remaining = 0.0
	state.boost_factor = 1.0
	state.thaw_remaining = 0.0
	state._market_core.icecap.sell = state.CROPS.icecap.base
	state._refresh_market(false)
	check(is_equal_approx(state.market.icecap.sell, state.CROPS.icecap.base * state.item_stock_factor()) and state.market.icecap.change < 500.0, "ending stacked temporary offers removes their premium while retaining equipped gear")
	for slot in State.EQUIPMENT_SLOTS:
		state.unequip_gear(slot)
	state.surge_remaining = 5.0
	state.surge_factor = 21.0
	state._refresh_market(false)
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.surge_factor == 21.0 and is_equal_approx(state.market.icecap.change, 2000.0), "previous21times active-surge saves remain valid without changing their stored multiplier")
	var saved: Dictionary = state._save_data().duplicate(true)
	var malformed: Dictionary = saved.duplicate(true)
	malformed.surge_factor = 31.01
	write_save(malformed)
	check(not state.load_game(SAVE) and state.surge_factor == 21.0, "over3000percent saved surge factor is rejected without mutating the live farm")
	malformed = saved.duplicate(true)
	malformed.market.icecap.sell = state.CROPS.icecap.base * 31.01
	write_save(malformed)
	check(not state.load_game(SAVE), "over-ceiling saved sale quotes are also rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("SPUD3000PERCENT STOCK CEILING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
