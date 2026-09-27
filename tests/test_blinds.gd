extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/blind_rules.gd")
const SAVE: String = "user://taterland_blind_test_only.json"
var checks: int = 0
var failures: int = 0
var state

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + detail)

func fresh(island: int = 1) -> void:
	state.reset_game()
	state.rng.seed = 31047
	if island > 1:
		state.island2_unlocked = true
		state.island3_unlocked = island == 3
		for id in range(2, island + 1):
			state.field_expansions[str(id)] = true
			for plot in state.island_plots[str(id)]:
				plot.unlocked = true
		state.travel_to(island)
		state.climate.acknowledge(state)
	state.blind_cycle.tax_rolled = true

func third_boom() -> void:
	for _event in range(2):
		state._start_surge()
		state.update(State.SURGE_DURATION)
	state._start_surge()

func settle(balance: float, multiplier: float = 1.0) -> void:
	state.coins = balance
	state.blind_cycle.tax_multiplier = multiplier
	third_boom()
	state.update(State.SURGE_DURATION)

func roundtrip() -> void:
	var before: Dictionary = state._save_data().duplicate(true)
	check(state.save_game(SAVE), "save complete blind checkpoint")
	check(state.load_game(SAVE), "load complete blind checkpoint")
	check(same_values(state.blind_cycle, before.blind_cycle) and is_equal_approx(state.coins, float(before.coins)), "balance, deadline, outcome and tax survive together")

func same_values(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not same_values(actual[key], expected[key]):
				return false
		return true
	if expected is int or expected is float:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected

func reject_cycle(patch: Dictionary) -> void:
	var before: Dictionary = state._save_data().duplicate(true)
	var data: Dictionary = before.duplicate(true)
	data.blind_cycle.merge(patch, true)
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(not state.load_game(SAVE) and state._save_data() == before, "corrupt blind data rejected atomically: " + str(patch))

func _run() -> void:
	state = State.new()
	root.add_child(state)
	for island in [1, 2, 3]:
		fresh(island)
		var small: float = [1e6, 1e11, 5e15][island - 1]
		var big: float = small
		check(state.blind_info().target == small * 0.05 and state.bankruptcy_limit() == -big * 0.05, "fixed island %d targets and five-percent bankruptcy" % island)
		settle(small)
		check(not state.run_over and state.blind_cycle.kind == "big" and state.blind_cycle.clears == 1, "cover first tax on island %d" % island)
		check(is_equal_approx(state.coins, small * 0.95) and state.blind_info().target == big * 0.05, "exact first bill and next progression-based tax")
		state.blind_cycle.tax_rolled = true
		settle(big)
		check(not state.run_over and state.blind_cycle.kind == "small" and state.blind_cycle.clears == 2, "cover second tax and repeat on island %d" % island)
		check(is_equal_approx(state.coins, big * 0.95), "second tax charged once")
		fresh(island)
		state.coins = state.bankruptcy_limit()
		check(not state.run_over, "exact bankruptcy boundary remains alive")
		state.coins -= 1.0
		check(state.run_over and state.blind_cycle.reason == "bankrupt", "crossing bankruptcy ends immediately")
		var dead_balance: float = state.coins
		state.coins = 1e100
		check(state.coins == dead_balance and state.run_over, "late rewards cannot resurrect a finished run")

	fresh(2)
	state.coins = -4e9
	check(not state.run_over and state.money(state.coins) == "-$4.0B", "negative balance stays playable and reads clearly")
	roundtrip()
	state.storage.sunburst = 10000
	state.sell_crop("sunburst")
	check(state.coins > -4e9 and not state.run_over, "stored crops can recover a negative wallet")
	fresh(2)
	state.coins = -5.001e9
	check(state.run_over, "scaled bankruptcy is enforced on island two")
	roundtrip()

	fresh()
	settle(72 * 50000.0)
	check(state.blind_cycle.last_result.ratio == 72.0 and state.blind_progress_text(72.0) == "72× OMNIPOTENT", "massive overkill keeps a meaningful fixed denominator")
	check(state.blind_cycle.last_result.target == 50000.0 and state.coins == 3550000.0, "surplus remains valuable after tax")
	fresh()
	settle(8.4e103)
	check(not state.run_over and state.coins == 8.4e103 and state.blind_cycle.last_result.tax == 50000.0, "huge wealth never increases the fixed tax bill")
	check(state.money(8.4e103) == "$8.4e103" and state.money(-8.4e103) == "-$8.4e103", "positive and negative huge numbers")
	check(state.money(-1.25e12, true) == "-$1.25T", "critical winter bankruptcy threshold is never rounded to -1.2T")
	check(state.blind_progress_text(8.4e103 / 1e104) == "84%", "large-number progress example retains 84 percent")
	roundtrip()
	fresh()
	state.coins = -8.4e103
	roundtrip()
	check(state.run_over and state.coins == -8.4e103, "negative huge bankruptcy balance persists without a zero clamp")

	fresh()
	settle(49999.0)
	check(not state.run_over and state.coins == -1.0, "uncovered tax becomes debt rather than ending the run")
	check(not state.blind_cycle.last_result.cleared and state.blind_cycle.kind == "big", "borrowed bill advances to next tax cycle")
	roundtrip()
	state.coins = state.bankruptcy_limit() - 1.0
	var frozen: Dictionary = state._save_data().duplicate(true)
	state.update(3600)
	state.buy_seeds("russet", 1)
	state.sell_crop("russet")
	state.interact_plot(0, "hoe")
	state.roll("normal")
	check(state._save_data() == frozen, "all clocks and economy actions stop after failure")
	roundtrip()

	fresh()
	settle(100000.0, 2.5)
	check(not state.run_over and is_equal_approx(state.coins, -25000.0), "maximum 150-percent Tax Boom can create survivable debt")
	check(state.blind_cycle.kind == "big" and state.blind_cycle.tax_multiplier == 1.0, "Tax Boom expires after exactly one collection")
	roundtrip()
	state.coins = 250000.0
	state.blind_cycle.tax_rolled = true
	settle(0.0, 2.5)
	check(state.run_over and state.blind_cycle.reason == "bankrupt" and not state.blind_cycle.last_result.cleared, "uncovered tax can cross bankruptcy and end the run")
	check(is_equal_approx(state.coins, -125000.0), "bankrupt tax payment is not clamped to zero")
	roundtrip()

	fresh(2)
	state.blind_cycle.kind = "big"
	state.coins = 13.8e9
	check(is_equal_approx(state.blind_info().tax, 5e9) and is_equal_approx(state.blind_info().projected, 8.8e9), "5-percent baseline has no wealth-dependent surplus fee")
	state.blind_cycle.tax_multiplier = 2.5
	check(is_equal_approx(state.blind_info().tax, 12.5e9) and state.blind_info().tax_boom, "150-percent increase means 2.5 times baseline")

	fresh()
	state.coins = 1e9
	state.climate.data.timer = 1e6
	state.update(179.999)
	check(state.blind_cycle.booms == 0, "elapsed time and natural spikes do not count as a major boom")
	state.update(0.001)
	check(state.blind_cycle.booms == 1 and state.surge_remaining == 10.0, "first actual major boom increments once")
	state._start_surge()
	check(state.blind_cycle.booms == 1, "duplicate start during a live event cannot double count")
	state.update(180.0)
	check(state.blind_cycle.booms == 2 and state.blind_cycle.due_in == 0.0, "second major stock no longer starts collection")
	state.update(180.0)
	check(state.elapsed == 540.0 and state.blind_cycle.booms == 3 and state.blind_cycle.due_in == 10.0, "nine-minute third stock starts the full final selling window")
	state.update(9.75)
	check(state.blind_cycle.clears == 0 and state.blind_cycle.due_in == 0.25, "no premature tax before the whole selling window")
	state.climate.data.timer = 240.0
	roundtrip()
	state.update(0.25)
	check(state.blind_cycle.clears == 1 and state.blind_cycle.booms == 0, "saved final quarter-second resolves exactly once")
	var after: float = state.coins
	state.update(0.25)
	check(state.coins == after and state.blind_cycle.clears == 1, "subsequent frames never double charge")

	fresh(3)
	state.coins = 1e16
	state._start_surge()
	state.update(10.0)
	state._start_surge()
	state.update(10.0)
	state._prepare_rocket()
	state.update(60.0)
	check(state.blind_cycle.booms == 2 and state.blind_cycle.due_in == 0.0, "rocket preparation and cutscene do not count")
	check(state.rocket_factor >= 351.0 and state.rocket_factor <= 1001.0, "Rocket uses new 35000 to 100000 percent range")
	state.complete_rocket_launch()
	check(state.blind_cycle.booms == 3 and state.blind_cycle.due_in == 10.0, "actual rocket price boom counts once after its cinematic")
	state.update(10.0)
	check(state.blind_cycle.clears == 1, "rocket gives full window before blind resolution")

	fresh()
	state.tutorial_active = true
	state.update(3600.0)
	state._start_surge()
	check(state.blind_cycle.booms == 0 and not state.run_over, "tutorial never consumes blind events")
	fresh(2)
	state._start_surge()
	state.update(10.0)
	state.travel_to(1)
	state.climate.acknowledge(state)
	check(state.blind_cycle.island == 2 and state.blind_cycle.booms == 1, "returning to island one cannot erase or lower current obligations")
	roundtrip()
	state.island3_unlocked = true
	state.field_expansions["3"] = true
	for plot in state.island_plots["3"]:
		plot.unlocked = true
	state.travel_to(3)
	state.climate.acknowledge(state)
	check(state.blind_cycle.island == 3 and state.blind_cycle.booms == 0 and state.blind_cycle.kind == "small", "new harder island grants a fresh three-stock tax cycle")

	fresh()
	state.coins = 1e9
	var found: bool = false
	for seed_value in range(100):
		state.rng.seed = seed_value
		state.blind_cycle = Rules.new_cycle()
		state.surge_remaining = 0.0
		state._start_surge()
		if state.blind_info().tax_boom:
			found = true
			break
	check(found and state.blind_cycle.booms == 1 and state.blind_cycle.due_in == 0.0, "random Tax Boom is announced a full major event before collection")
	var promised: float = state.blind_cycle.tax_multiplier
	roundtrip()
	check(is_equal_approx(state.blind_cycle.tax_multiplier, promised), "reload cannot reroll a Tax Boom")
	for patch in [{"booms": 4}, {"due_in": 11.0}, {"tax_multiplier": -1}, {"tax_rolled": false}, {"run_over": false, "reason": "bankrupt"}, {"last_result": {"tax": "bad"}}]:
		reject_cycle(patch)
	fresh()
	state.coins = 42e6
	var old_save: Dictionary = state._save_data()
	old_save.mechanics_revision = 8
	old_save.erase("blind_cycle")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	check(state.load_game(SAVE) and state.coins == 42e6 and state.blind_cycle.booms == 0 and state.blind_cycle.kind == "small", "old save starts a fresh cycle without retroactive tax")
	fresh()
	state.coins = 123456.0
	var previous: Dictionary = state._save_data().duplicate(true)
	previous.mechanics_revision = 9
	previous.blind_cycle.booms = 2
	previous.blind_cycle.due_in = 0.25
	previous.blind_cycle.tax_rolled = true
	previous.blind_cycle.tax_multiplier = 14.0
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(previous))
	file.close()
	check(state.load_game(SAVE) and state.coins == 123456.0, "previous blind save migrates without charging money")
	check(state.blind_cycle.booms == 0 and state.blind_cycle.due_in == 0.0 and state.blind_cycle.tax_multiplier == 1.0, "progression-economy migration gives a full fresh climate preparation cycle")
	roundtrip()
	state.blind_cycle.tax_rolled = true
	third_boom()
	state.update(10.0)
	check(state.blind_cycle.clears == 1 and state.coins == 73456.0, "migrated tax waits for three complete stock opportunities")
	for tier in [{"ratio": 2.0, "name": "OVERKILL"}, {"ratio": 5.0, "name": "ULTRA KILL"}, {"ratio": 10.0, "name": "GODLIKE"}, {"ratio": 25.0, "name": "OMNIPOTENT"}, {"ratio": 100.0, "name": "RULER"}, {"ratio": 1000.0, "name": "COSMIC RULER"}, {"ratio": 1e6, "name": "REALITY BREAKER"}]:
		check(Rules.wealth_rank(tier.ratio) == tier.name and Rules.wealth_rank(tier.ratio - 0.001) != tier.name, "wealth rank activates at exact threshold: " + str(tier.name))
	fresh()
	var strongest: float = 1.0
	var weakest: float = 2.5
	var tax_booms: int = 0
	for sample in range(2000):
		state.blind_cycle = Rules.new_cycle()
		state.surge_remaining = 0.0
		state.rng.seed = sample
		state._start_surge()
		var factor: float = state.blind_cycle.tax_multiplier
		strongest = maxf(strongest, factor)
		weakest = minf(weakest, factor)
		tax_booms += int(factor > 1.0)
	check(weakest == 1.0 and strongest == 2.5, "sampled tax increases include zero and 150 percent, never exceed the range")
	check(tax_booms > 250 and tax_booms < 550, "Tax Booms remain occasional at configured 20-percent frequency")
	state.reset_game()
	check(not state.run_over and state.coins == 240.0 and state.blind_cycle == Rules.new_cycle(), "new run fully resets blind/debt state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.queue_free()
	print("TAXES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
