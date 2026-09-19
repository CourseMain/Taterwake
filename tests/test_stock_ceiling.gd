extends SceneTree
## Quote ceilings, scheduled/natural distributions, and readable large balances.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
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

func enter_island(state, island: int) -> void:
	if island >= 2:
		state.island2_unlocked = true
		for plot in state.island_plots["2"]:
			plot.unlocked = true
	if island >= 3:
		state.island3_unlocked = true
		for plot in state.island_plots["3"]:
			plot.unlocked = true
	state.travel_to(island)

func scheduled_sample(state, luck: float) -> Dictionary:
	state.debug_luck_multiplier = luck
	state.rng.seed = 92013
	var low: float = 31.0 if state.current_island >= 3 else 6.0
	var total: float = 0.0
	var bottom: int = 0
	var top: int = 0
	var bounded: bool = true
	for _index in range(4000):
		state._start_surge()
		var normalized: float = (state.surge_factor - low) / (state.stock_cap() - low)
		total += normalized
		bottom += int(normalized < 0.25)
		top += int(normalized > 0.75)
		bounded = bounded and normalized >= 0.0 and normalized <= 1.0 and state.surge_crop == state.selected_crop and state.surge_kind == "normal"
	return {"mean": total / 4000.0, "bottom": bottom, "top": top, "bounded": bounded}

func natural_sample(state, luck: float, debug_luck: float = 1.0) -> Dictionary:
	state.luck = luck
	state.debug_luck_multiplier = debug_luck
	state.rng.seed = 57241
	state.surge_remaining = 0.0
	state.surge_factor = 1.0
	var hits: int = 0
	var hit_ticks: Array[int] = []
	var factors: Array[float] = []
	var quotes: Array[float] = []
	var total: float = 0.0
	var bounded: bool = true
	var low: float = 71.0 if state.current_island >= 3 else 21.0
	for _index in range(10000):
		# Count eligible ticks, excluding ticks hidden behind a ten-second spike.
		state.natural_remaining = 0.0
		state.natural_factor = 1.0
		state._market_tick()
		if state.natural_remaining > 0.0:
			hits += 1
			hit_ticks.append(_index)
			factors.append(state.natural_factor)
			quotes.append(state.market[state.selected_crop].sell)
			total += (state.natural_factor - low) / (state.stock_cap() - low)
			bounded = bounded and state.natural_remaining == 10.0 and state.natural_crop == state.selected_crop
			bounded = bounded and state.natural_factor >= low and state.natural_factor <= state.stock_cap()
			bounded = bounded and state.market[state.selected_crop].change >= (low - 1.0) * 100.0 - 0.000001
			bounded = bounded and state.market[state.selected_crop].sell <= state.CROPS[state.selected_crop].base * state.stock_cap() + 0.000001
	return {"hits": hits, "mean": total / maxi(hits, 1), "bounded": bounded, "hit_ticks": hit_ticks, "factors": factors, "quotes": quotes, "chance": state.natural_stock_chance()}

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(State.SURGE_INTERVAL == 180.0 and State.SURGE_DURATION == 10.0, "scheduled stocks retain a three-minute cadence with a ten-second window")
	for island in [1, 2, 3]:
		state.reset_game()
		enter_island(state, island)
		var crop: String = ["golden", "sunburst", "icecap"][island - 1]
		state.select_crop(crop)
		var cap: float = 101.0 if island == 3 else 30.99
		var percent: float = 10000.0 if island == 3 else 2999.0
		check(is_equal_approx(state.stock_cap(), cap), "island %d has the intended normal stock cap" % island)
		var ordinary: Dictionary = scheduled_sample(state, 1.0)
		var lucky: Dictionary = scheduled_sample(state, 10.0)
		check(ordinary.bounded and lucky.bounded, "island %d scheduled factors stay in range at both luck levels" % island)
		check(ordinary.mean > 0.15 and ordinary.mean < 0.40 and ordinary.bottom > ordinary.top * 2, "island %d ordinary scheduled booms favor the low end" % island)
		check(lucky.mean > ordinary.mean + 0.025 and lucky.mean < 0.32 and lucky.bottom > lucky.top, "island %d luck modestly improves boom strength while high values remain rarer" % island)
		state.debug_luck_multiplier = 1.0
		state.surge_factor = cap
		state._refresh_market(false)
		check(is_equal_approx(state.market[crop].change, percent) and is_equal_approx(state.surge_info().percent, percent), "island %d quote and banner report the exact maximum" % island)
		check(is_equal_approx(state.market[crop].seed, state.market[crop].sell * state.CROPS[crop].yield * state.SEED_YIELD_RATIO), "island %d seed price follows the final capped sell quote" % island)
		check(state.save_game(SAVE) and state.load_game(SAVE) and is_equal_approx(state.surge_factor, cap), "island %d normal maximum survives save/load" % island)
		var regular_spikes: Dictionary = natural_sample(state, 1.0)
		var lucky_spikes: Dictionary = natural_sample(state, 10.0)
		var debug_spikes: Dictionary = natural_sample(state, 10.0, State.DEBUG_LUCK_LIMIT)
		var builds = Builds.new()
		root.add_child(builds)
		builds.state = state
		builds.active = "investor"
		builds.levels.investor = 20
		state.build_system = builds
		var build_spikes: Dictionary = natural_sample(state, 10.0, State.DEBUG_LUCK_LIMIT)
		check(builds.event_chance_bonus() > 0.0, "investor setup exercises a real positive-event bonus")
		for id in ["prospectors_hat", "market_monocle", "investor_shirt", "investor_pants", "investor_shoes"]:
			state._grant_item(id)
		var outfit_spikes: Dictionary = natural_sample(state, 10.0, State.DEBUG_LUCK_LIMIT)
		check(is_equal_approx(state.item_stock_factor(), 1.525), "natural independence includes the maximum stock outfit")
		state.build_system = null
		builds.free()
		check(regular_spikes.hits >= 100 and regular_spikes.hits <= 200, "island %d natural spikes occur about 1.5 percent of eligible ticks" % island)
		check(regular_spikes.mean > 0.15 and regular_spikes.mean < 0.40, "island %d natural strength still favors low values" % island)
		for sample in [regular_spikes, lucky_spikes, debug_spikes, build_spikes, outfit_spikes]:
			check(sample.chance == 0.015, "island %d natural odds stay exactly 1.5 percent across luck, debug luck, and investor bonuses" % island)
			check(sample.bounded, "island %d natural spikes use the selected crop, correct band, and full ten seconds" % island)
			check(sample.hit_ticks == regular_spikes.hit_ticks and sample.factors == regular_spikes.factors and sample.quotes == regular_spikes.quotes, "island %d identical seeded natural occurrences and magnitudes are independent of luck, stock gear, and build bonuses" % island)
	state.reset_game()
	state.select_crop("golden")
	state.surge_timer = 0.25
	state._event_in = 11.0
	state.update(0.249)
	check(state.surge_remaining == 0.0, "scheduled surge does not start before its boundary")
	state.update(0.001)
	state.surge_factor = 30.99
	state._refresh_market(false)
	check(state.surge_remaining == 10.0 and state.surge_timer == 180.0, "scheduled surge begins with its complete window")
	var scheduled_seed_price: float = state.market.golden.seed
	state.update(5.0)
	check(is_equal_approx(state.surge_remaining, 5.0), "scheduled boom remains live at the former five-second cutoff")
	state.update(4.999)
	check(state.surge_remaining > 0.0 and is_equal_approx(state.market.golden.change, 2999.0), "maximum quote remains active until ten seconds finish")
	state.update(0.001)
	check(state.surge_remaining == 0.0 and state.surge_factor == 1.0 and is_equal_approx(state.surge_timer, 170.0), "scheduled expiry preserves the next three-minute boundary")
	check(is_equal_approx(state.market.golden.sell, state._market_core.golden.sell), "scheduled expiry removes the temporary quote")
	check(state.market.golden.seed < scheduled_seed_price and is_equal_approx(state.market.golden.seed, state.market.golden.sell * state.CROPS.golden.yield * State.SEED_YIELD_RATIO), "scheduled expiry lowers the actual purchase price with its sale quote")
	state.reset_game()
	state.select_crop("golden")
	state.natural_crop = "golden"
	state.natural_factor = 28.0
	state.natural_remaining = 10.0
	state._event_in = 11.0
	state._refresh_market(false)
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.natural_remaining == 10.0, "a full ten-second natural spike survives save/load")
	var natural_seed_price: float = state.market.golden.seed
	state.select_crop("russet")
	state.rng.seed = 4401
	for _index in range(100):
		state._market_tick()
	check(state.natural_crop == "golden" and state.natural_factor == 28.0 and state.natural_remaining == 10.0, "natural cooldown prevents rerolls and changing selection cannot transfer a spike")
	state._market_clock = 0.0
	state.update(5.0)
	check(is_equal_approx(state.natural_remaining, 5.0), "natural spike remains live at the former five-second cutoff")
	state.update(4.999)
	check(state.natural_remaining > 0.0 and is_equal_approx(state.market.golden.change, 2700.0), "natural stock quote also lasts the complete ten seconds")
	state.update(0.001)
	check(state.natural_remaining == 0.0 and state.natural_factor == 1.0 and is_equal_approx(state.market.golden.sell, state._market_core.golden.sell), "natural expiry restores its underlying quote")
	check(state.market.golden.seed < natural_seed_price and is_equal_approx(state.market.golden.seed, state.market.golden.sell * state.CROPS.golden.yield * State.SEED_YIELD_RATIO), "natural expiry lowers the actual seed purchase price with its sale quote")
	for island in [1, 3]:
		state.reset_game()
		enter_island(state, island)
		for id in ["prospectors_hat", "market_monocle", "investor_shirt", "investor_pants", "investor_shoes", "trader_token"]:
			state._grant_item(id)
		state._start_event("shortage")
		state.event_strength = 16.0
		state.boost_remaining = 5.0
		state.boost_factor = 3.0
		if island == 3:
			state.thaw_remaining = 5.0
		for id in state.CROP_IDS:
			state._market_core[id].sell = state.CROPS[id].base * 3.0
		state._refresh_market(false)
		var capped: bool = true
		var linked: bool = true
		for id in state.CROP_IDS:
			capped = capped and is_equal_approx(state.market[id].sell, state.CROPS[id].base * state.stock_cap())
			linked = linked and is_equal_approx(state.market[id].seed, state.market[id].sell * state.CROPS[id].yield * 0.45 * 0.98)
		check(capped and state.item_stock_factor() > 1.0, "island %d ordinary event, gear, and offer stacks respect the local ceiling" % island)
		check(linked, "island %d seed-token discount applies to capped final quotes" % island)
		var quote: float = state.market.golden.sell
		for _index in range(20):
			state._refresh_market(false)
		check(state.market.golden.sell == quote, "repeated refreshes never compound equipped stock gear")
		state._end_event()
		state.boost_remaining = 0.0
		state.boost_factor = 1.0
		state.thaw_remaining = 0.0
		state._market_core.golden.sell = state.CROPS.golden.base
		state._refresh_market(false)
		check(is_equal_approx(state.market.golden.sell, state.CROPS.golden.base * state.item_stock_factor()), "ending temporary offers leaves only the permanent equipped benefit")
	var suffixes: Array[String] = ["Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	for index in range(suffixes.size()):
		var value: float = pow(10.0, 15 + index * 3)
		check(state.money(value) == "$1.0" + suffixes[index] and state.money(value * 12.5) == "$12.5" + suffixes[index], "large money formats with " + suffixes[index])
	check(state.money(1e36) == "$1e36" and state.money(8.4e71) == "$8.4e71", "balances beyond decillions retain scientific notation")
	check(state.money(0.24) == "$0.24" and state.money(1e-20) == "$1e-20" and state.money(-9e19) == "$-90.0Qi", "extended suffixes preserve fractional, tiny, and signed balances")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("STOCK CEILINGS AND DISTRIBUTIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
