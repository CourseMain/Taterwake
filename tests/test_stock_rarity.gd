extends SceneTree
## Seeded probability bands and quantiles across every capped boom range.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAMPLE_COUNT: int = 50000
const BASE_BANDS: Array[float] = [27.1, 21.7, 16.9, 12.7, 9.1, 6.1, 3.7, 1.9, 0.7, 0.1]
const OUTFIT_BANDS: Array[float] = [21.668934345548983, 18.71512869891845, 15.8700816992424, 13.143552731025625, 10.547804335314718, 8.098821192280917, 5.818538791656756, 3.739487178918393, 1.9168141452639256, 0.4808368818298307]
const QUANTILES: Array[float] = [0.1, 0.25, 0.5, 0.75, 0.9, 0.99]
const BASE_QUANTILES: Array[float] = [0.03451062, 0.0914397, 0.20629947, 0.37003948, 0.53584112, 0.78455653]
const OUTFIT_QUANTILES: Array[float] = [0.04443563551918761, 0.11671535015415735, 0.2584612292927758, 0.4501202515380188, 0.6296656215717851, 0.8628524481541876]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func configure(state, profile: int, island: int) -> void:
	state.reset_game()
	if island == 3:
		state.island2_unlocked = true
		state.island3_unlocked = true
		for id in ["2", "3"]:
			state.field_expansions[id] = true
			for plot in state.island_plots[id]:
				plot.unlocked = true
		state.travel_to(3)
		state.climate.acknowledge(state)
		state.select_crop("icecap")
	if profile == 2:
		state.build_system.active = "investor"
		state.build_system.levels.investor = 20
		for id in ["prospectors_hat", "market_monocle", "investor_shirt", "investor_pants", "investor_shoes"]:
			state._grant_item(id)
		check(is_equal_approx(state.item_stock_factor(), 1.675), "full Investor outfit exercises the strongest ordinary stock bonus")
	state.rng.seed = 92013015

func sample(state, low: float, high: float, kind: String) -> Dictionary:
	var bins: Array[int] = []
	bins.resize(10)
	bins.fill(0)
	var values: Array[float] = []
	var bounded: bool = true
	var caps: int = 0
	for _index in range(SAMPLE_COUNT):
		var factor: float
		if kind == "natural":
			factor = state._natural_boom_roll(low, high)
		elif kind == "rocket":
			state._prepare_rocket()
			factor = state.rocket_factor
		else:
			factor = state._boom_roll(low, high)
		var value: float = (factor - low) / (high - low)
		bounded = bounded and is_finite(value) and value >= 0.0 and value <= 1.0
		caps += int(factor == high)
		bins[clampi(int(value * 10.0), 0, 9)] += 1
		values.append(value)
	values.sort()
	return {"bins": bins, "values": values, "bounded": bounded, "caps": caps}

func verify_profile(result: Dictionary, expected_bands: Array[float], expected_quantiles: Array[float], label: String) -> void:
	check(result.bounded, label + " respects its exact capped interval")
	check(result.caps == 0, label + " has no artificial probability pile-up at the cap")
	for band in range(10):
		var expected: float = expected_bands[band] / 100.0
		var observed: float = float(result.bins[band]) / SAMPLE_COUNT
		var tolerance: float = 5.0 * sqrt(expected * (1.0 - expected) / SAMPLE_COUNT) + 2.0 / SAMPLE_COUNT
		check(absf(observed - expected) <= tolerance, label + " matches the intended probability in range decile %d" % (band + 1))
		if band > 0:
			check(result.bins[band] < result.bins[band - 1], label + " makes every higher equal-width band less likely")
	for index in range(QUANTILES.size()):
		var observed: float = float(result.values[int(QUANTILES[index] * SAMPLE_COUNT)])
		check(absf(observed - expected_quantiles[index]) < 0.009, label + " has the intended %.0fth percentile" % (QUANTILES[index] * 100.0))

func check_live_outfit_quotes(state, rocket: bool) -> void:
	configure(state, 2, 3)
	var low: float = 351.0 if rocket else 31.0
	var high: float = State.MAX_PRICE_MULTIPLIER if rocket else state.stock_cap()
	var at_cap: int = 0
	var exact: bool = true
	for _index in range(2000):
		if rocket:
			state._prepare_rocket()
			state.complete_rocket_launch()
		else:
			state._start_surge()
		var final_factor: float = state.market.icecap.sell / state.CROPS.icecap.base
		at_cap += int(is_equal_approx(final_factor, high))
		exact = exact and is_equal_approx(final_factor, state.surge_factor) and final_factor >= low and final_factor <= high and state.surge_remaining == 10.0
	check(exact and at_cap == 0, "live %s outfit quotes retain the sampled range and ten-second duration without post-roll cap clipping" % ("rocket" if rocket else "scheduled"))

func check_offer_stacks(state) -> void:
	for crop in ["golden", "icecap"]:
		configure(state, 2, 3)
		state.select_crop(crop)
		state._start_event("shortage")
		state.event_strength = 16.0
		state._toggle_export()
		state.export_factor = 6.0
		state.thaw_remaining = 5.0
		state._market_core[crop].sell = state.CROPS[crop].base * 3.0
		state._refresh_market(false)
		check(is_equal_approx(state.market[crop].sell, state.CROPS[crop].base * 101.0), "stack fixture reaches the ordinary ceiling before an explicit boom")
		state.natural_crop = crop
		state.natural_remaining = 10.0
		state.natural_factor = 75.0
		state._refresh_market(false)
		check(is_equal_approx(state.market[crop].sell, state.CROPS[crop].base * 75.0), "natural quote keeps its draw despite simultaneous gear, roll boost, flash offer and export/thaw effects")
		state._start_surge()
		state.surge_factor = 35.0
		state._refresh_market(false)
		check(is_equal_approx(state.market[crop].sell, state.CROPS[crop].base * 35.0), "scheduled draw takes priority over overlapping natural spikes and ordinary offer stacks")
		state._prepare_rocket()
		state.rocket_factor = 375.0
		state.complete_rocket_launch()
		check(is_equal_approx(state.market[crop].sell, state.CROPS[crop].base * 375.0) and state.surge_remaining == 10.0, "post-film rocket keeps its sampled quote and full duration despite every overlapping offer")
		check(is_equal_approx(state.market[crop].seed, State.seed_price_for(state.market[crop].sell)), "seed purchases follow the final unmultiplied boom quote at the fixed 75% rate")

func run() -> void:
	var state = State.new()
	root.add_child(state)
	var builds = Builds.new()
	root.add_child(builds)
	builds.state = state
	state.build_system = builds
	for band in [{"low": 6.0, "high": 30.99, "kind": "scheduled", "island": 1}, {"low": 31.0, "high": 101.0, "kind": "scheduled", "island": 3}, {"low": 351.0, "high": 1001.0, "kind": "rocket", "island": 3}]:
		for profile in [0, 2]:
			configure(state, profile, band.island)
			var result: Dictionary = sample(state, band.low, band.high, band.kind)
			verify_profile(result, BASE_BANDS if profile == 0 else OUTFIT_BANDS, BASE_QUANTILES if profile == 0 else OUTFIT_QUANTILES, "%s %.0f..%.2f profile %d" % [band.kind, band.low, band.high, profile])
	for band in [{"low": 21.0, "high": 30.99, "island": 1}, {"low": 71.0, "high": 101.0, "island": 3}]:
		configure(state, 0, band.island)
		var ordinary: Dictionary = sample(state, band.low, band.high, "natural")
		verify_profile(ordinary, BASE_BANDS, BASE_QUANTILES, "natural %.0f..%.2f" % [band.low, band.high])
		configure(state, 2, band.island)
		var equipped: Dictionary = sample(state, band.low, band.high, "natural")
		check(ordinary.values == equipped.values and ordinary.bins == equipped.bins and state.natural_stock_chance() == 0.015, "natural strength and 1.5 percent trigger remain independent of luck, debug luck, stock gear and build")
	check_live_outfit_quotes(state, false)
	check_live_outfit_quotes(state, true)
	check_offer_stacks(state)
	state.build_system = null
	builds.free()
	state.free()
	print("STOCK RARITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
