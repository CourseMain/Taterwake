extends SceneTree
## The eligible-time clock, cinematic handoff, persistence, and safe travel.
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://spud_stock_rocket_state_test_only.json"
const NEW_FIELDS: Array[String] = ["surge_kind", "rocket_timer", "rocket_pending", "rocket_factor", "rocket_crop", "natural_remaining", "natural_factor", "natural_crop"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func winter(state) -> void:
	state.island2_unlocked = true
	state.island3_unlocked = true
	for island in ["2", "3"]:
		for plot in state.island_plots[island]:
			plot.unlocked = true
	state.travel_to(3)
	state.select_crop("icecap")

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func same_plots(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		for key in expected[index]:
			if actual[index].get(key) != expected[index][key]:
				return false
	return true

func reject_patch(state, source: Dictionary, patch: Dictionary, description: String) -> void:
	var invalid: Dictionary = source.duplicate(true)
	invalid.merge(patch, true)
	var before: Dictionary = state._save_data().duplicate(true)
	write_save(invalid)
	check(not state.load_game(SAVE) and state._save_data() == before, description)

func check_boundary_clocks(state) -> void:
	for expires_at_boundary in [false, true]:
		state.reset_game()
		winter(state)
		state._start_event("shortage")
		state._toggle_export()
		var effect_time: float = 0.75 if expires_at_boundary else 3.0
		state.event_remaining = effect_time
		state.export_timer = effect_time
		state.frost_timer = effect_time
		state.thaw_remaining = effect_time
		state.combo_time = effect_time
		state.combo_count = 4
		state.combo_multiplier = 8
		state.boost_remaining = effect_time
		state.boost_factor = 2.0
		state.rocket_timer = 0.75
		state.surge_timer = 0.75
		state._market_clock = 4.25
		state._relief_clock = 14.25
		state.rng.seed = 800123
		state._refresh_market(false)
		state.update(2.0)
		check(state.rocket_pending and is_equal_approx(state.elapsed, 0.75) and state.surge_remaining == 0.0, "rocket consumes only its final substep and suppresses the coincident ordinary surge")
		check(is_zero_approx(state._market_clock) and is_zero_approx(state._relief_clock), "market and relief boundaries finish before the cinematic begins")
		if expires_at_boundary:
			check(not state.export_active and state.export_factor == 1.0 and state.export_timer >= State.EXPORT_MIN_WAIT, "export expires on the rocket boundary before simulation freezes")
			check(state.frost_active and state.frost_timer == 20.0 and state.thaw_remaining == 0.0, "frost starts and the previous thaw ends on their exact rocket boundary")
			check(state.combo_time == 0.0 and state.combo_count == 0 and state.combo_multiplier == 1, "combo expiry is resolved before the cinematic")
			check(state.boost_remaining == 0.0 and state.boost_factor == 1.0 and state.current_event == "" and state.event_remaining == 0.0, "roll boost and flash offer expiry cannot be deferred until after the cinematic")
		else:
			for timer: String in ["export_timer", "frost_timer", "thaw_remaining", "combo_time", "boost_remaining", "event_remaining"]:
				check(is_equal_approx(float(state.get(timer)), 2.25), "%s consumes the same final 0.75 seconds as the rocket clock" % timer)
		var paused: Dictionary = state._save_data().duplicate(true)
		state.update(60.0)
		check(state._save_data() == paused, "every resolved clock and effect freezes together while the rocket is pending")
		check(state.save_game(SAVE) and state.load_game(SAVE), "the fully resolved rocket boundary remains a valid save")
	state.reset_game()
	winter(state)
	state.rocket_timer = 0.75
	state._event_in = 1.5
	state.update(2.0)
	check(state.rocket_pending and is_equal_approx(state._event_in, 0.75), "an idle event countdown also consumes the final pre-cinematic substep")
	state.reset_game()
	winter(state)
	state.rocket_timer = 0.000001
	check(state.save_game(SAVE) and state.load_game(SAVE), "the minimum permitted rocket timer survives a valid save/load")
	state.update(state.rocket_timer)
	check(state.rocket_pending and is_equal_approx(state.elapsed, 0.000001) and state.rocket_timer == State.ROCKET_INTERVAL, "exact minimum rocket interval advances once instead of freezing at the loop threshold")

func _run() -> void:
	var state = State.new()
	root.add_child(state)
	check(State.MECHANICS_REVISION == 8 and state.rocket_timer == 1800.0 and not state.rocket_pending, "revision eight starts with a fresh thirty-minute rocket clock")
	state.update(60.0)
	check(state.rocket_timer == 1800.0 and not state.rocket_pending, "starter-island time does not advance the rocket")
	winter(state)
	state.update(10.25)
	check(is_equal_approx(state.rocket_timer, 1789.75), "winter advances eligible rocket time precisely")
	state.travel_to(2)
	state.update(60.0)
	check(is_equal_approx(state.rocket_timer, 1789.75) and not state.rocket_pending, "island two pauses rather than resets eligible time")
	state.travel_to(3)
	state.tutorial_active = true
	state.update(45.0)
	check(is_equal_approx(state.rocket_timer, 1789.75) and not state.rocket_pending, "tutorial time cannot count toward the rocket")
	state.tutorial_active = false
	check(state.save_game(SAVE) and state.load_game(SAVE) and is_equal_approx(state.rocket_timer, 1789.75), "partly earned eligible time persists")
	state.update(0.25)
	check(is_equal_approx(state.rocket_timer, 1789.5), "returning to winter resumes the saved clock")

	state.reset_game()
	winter(state)
	state.rng.seed = 70312
	var messages: Array[String] = []
	state.notified.connect(func(message: String) -> void:
		if message.begins_with("STOCK SURGE!"):
			messages.append(message)
	)
	state.update(1799.999)
	check(not state.rocket_pending and state.rocket_timer < 0.01 and messages.size() == 9, "nine regular booms precede the first thirty-minute rocket boundary")
	state.update(0.001)
	check(state.rocket_pending and state.rocket_timer == 1800.0 and state.surge_remaining == 0.0, "thirty-minute boundary prepares the cinematic before activating any boost")
	check(messages.size() == 9, "rocket preparation takes priority when three-minute and thirty-minute clocks coincide")
	check(state.rocket_crop == "icecap" and state.rocket_factor >= 151.0 and state.rocket_factor <= 501.0, "rocket chooses the selected crop and a fifteen-thousand to fifty-thousand percent factor")
	var prepared_factor: float = state.rocket_factor
	var paused_at: float = state.elapsed
	var market_clock: float = state._market_clock
	var rng_state: int = state.rng.state
	state.update(60.0)
	check(state.elapsed == paused_at and state._market_clock == market_clock and state.rng.state == rng_state and state.surge_remaining == 0.0, "pending cinematic freezes simulation and does not consume or reroll the ten-second prize")
	state.travel_to(1)
	check(state.current_island == 3 and state.rocket_pending and state.rocket_factor == prepared_factor, "travel cannot escape or replace a pending rocket")
	check(state.save_game(SAVE) and state.load_game(SAVE), "a save made at the exact pending boundary remains loadable")
	check(state.rocket_pending and is_equal_approx(state.rocket_factor, prepared_factor) and state.rocket_timer == 1800.0 and state.rocket_crop == "icecap", "pending save retains the predetermined crop, multiplier, and next clock")
	state.select_crop("russet")
	state.complete_rocket_launch()
	check(not state.rocket_pending and state.rocket_factor == 1.0 and state.surge_kind == "rocket" and state.surge_remaining == 10.0, "only the cinematic completion starts the entire ten-second rocket boost")
	check(state.surge_crop == "icecap" and is_equal_approx(state.surge_factor, prepared_factor) and state.surge_timer == 180.0 and messages.size() == 10, "completion honors the originally chosen crop and resets the regular clock")
	check(is_equal_approx(state.market.icecap.sell, state.CROPS.icecap.base * prepared_factor), "first sellable rocket quote reflects the saved multiplier")
	state.complete_rocket_launch()
	check(messages.size() == 10 and state.surge_remaining == 10.0 and is_equal_approx(state.surge_factor, prepared_factor), "duplicate completion cannot start a second rocket or change its factor")
	state.surge_factor = 501.0
	state._refresh_market(false)
	check(is_equal_approx(state.market.icecap.change, 50000.0) and is_equal_approx(state.surge_info().percent, 50000.0), "rocket selected quote and banner allow the exact fifty-thousand percent maximum")
	check(is_equal_approx(state.market.icecap.seed, state.market.icecap.sell * state.CROPS.icecap.yield * state.SEED_YIELD_RATIO), "rocket seeds follow the same final sale value")
	state._start_event("shortage")
	state.event_strength = 16.0
	state.boost_remaining = 5.0
	state.boost_factor = 3.0
	for id in state.CROP_IDS:
		state._market_core[id].sell = state.CROPS[id].base * 3.0
	state._refresh_market(false)
	var other_quotes_capped: bool = true
	for id in state.CROP_IDS:
		if id != "icecap":
			other_quotes_capped = other_quotes_capped and is_equal_approx(state.market[id].sell, state.CROPS[id].base * 101.0)
	check(other_quotes_capped and is_equal_approx(state.market.icecap.change, 50000.0), "only the rocket crop receives the exceptional cap during stacked offers")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.surge_kind == "rocket" and state.surge_factor == 501.0 and state.surge_remaining == 10.0, "an active maximum rocket survives a save/load round trip")
	var rocket_seed_price: float = state.market.icecap.seed
	state.update(5.0)
	check(is_equal_approx(state.surge_remaining, 5.0) and is_equal_approx(state.market.icecap.change, 50000.0), "rocket boom remains live after the former five-second cutoff")
	state.update(4.999)
	check(state.surge_remaining > 0.0 and is_equal_approx(state.market.icecap.change, 50000.0), "rocket sale window stays open until ten whole seconds elapse")
	state.update(0.001)
	check(state.surge_remaining == 0.0 and state.surge_factor == 1.0 and state.surge_kind == "normal" and is_equal_approx(state.surge_timer, 170.0), "rocket expiry removes the exception without delaying the next regular boom")
	check(state.market.icecap.sell <= state.CROPS.icecap.base * 101.0 and is_equal_approx(state.rocket_timer, 1790.0), "after expiry the normal ceiling and eligible rocket countdown resume")
	var seed_event_factor: float = state.event_strength if state.current_event in ["seed_panic", "seed_fair"] else 1.0
	check(state.market.icecap.seed < rocket_seed_price and is_equal_approx(state.market.icecap.seed, state.market.icecap.sell * state.CROPS.icecap.yield * State.SEED_YIELD_RATIO * seed_event_factor), "rocket expiry lowers actual seed costs along with the sell price while preserving independent seed offers")

	state.reset_game()
	winter(state)
	state.update(3600.0)
	check(state.rocket_pending and is_equal_approx(state.elapsed, 1800.0) and state.surge_remaining == 0.0, "one long update stops at the first cinematic instead of spending its boost invisibly")
	state.complete_rocket_launch()
	state.update(1.25)
	var carried_clock: float = state.rocket_timer
	state.travel_to(1)
	check(state.surge_remaining == 0.0 and state.surge_factor == 1.0 and state.surge_kind == "normal" and state.rocket_timer == carried_clock, "leaving winter cancels an active rocket while preserving earned clock progress")
	check(state.save_game(SAVE) and state.load_game(SAVE), "leaving a rocket cannot create an invalid off-island save")
	state.travel_to(3)
	state._start_surge()
	state.surge_factor = 101.0
	state.natural_crop = "icecap"
	state.natural_factor = 90.0
	state.natural_remaining = 3.75
	state._refresh_market(false)
	state.travel_to(2)
	check(state.surge_remaining == 10.0 and state.surge_kind == "normal" and is_equal_approx(state.surge_factor, 30.99), "travel clamps an active normal winter surge to the earlier-island ceiling")
	check(state.natural_remaining == 0.0 and state.natural_factor == 1.0 and state.rocket_timer == carried_clock, "travel clears a natural spike and keeps the independent rocket clock")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.current_island == 2, "a clamped winter surge remains a valid earlier-island save")

	state.reset_game()
	winter(state)
	state.natural_crop = "icecap"
	state.natural_factor = 90.0
	state.natural_remaining = 3.75
	state.rocket_timer = 611.25
	state._refresh_market(false)
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.natural_crop == "icecap" and state.natural_factor == 90.0 and state.natural_remaining == 3.75 and state.rocket_timer == 611.25, "natural stock factor, target, fractional duration, and rocket countdown all persist")
	state.reset_game()
	check(state.natural_remaining == 0.0 and state.natural_factor == 1.0 and state.rocket_timer == 1800.0 and not state.rocket_pending and state.rocket_factor == 1.0 and state.surge_kind == "normal", "fresh-game reset removes every stock-event state")

	state.select_crop("golden")
	state.coins = 8.4e71
	state.storage.russet = 7
	state.mastery.russet = 19
	state.surge_remaining = 2.25
	state.surge_factor = 30.99
	state.surge_crop = "golden"
	state.surge_timer = 177.25
	state._refresh_market(false)
	var legacy: Dictionary = state._save_data().duplicate(true)
	for field in NEW_FIELDS:
		legacy.erase(field)
	legacy.surge_factor = 31.0
	legacy.market.golden.sell = state.CROPS.golden.base * 31.0
	legacy.market.golden.change = 3000.0
	legacy.market.golden.seed = legacy.market.golden.sell * state.CROPS.golden.yield * state.SEED_YIELD_RATIO
	for revision in [4, 5, 6, 7]:
		legacy.mechanics_revision = revision
		write_save(legacy)
		check(state.load_game(SAVE), "revision %d farm migrates without requiring newly introduced stock fields" % revision)
		check(state.coins == 8.4e71 and state.storage.russet == 7 and state.mastery.russet == 19 and same_plots(state.plots, legacy.plots) and str(state.rng.state) == legacy.rng_state, "revision %d migration preserves the normal farm and its RNG" % revision)
		check(is_equal_approx(state.surge_factor, 30.99) and state.surge_remaining == 2.25 and state.surge_timer == 177.25 and is_equal_approx(state.market.golden.change, 2999.0), "revision %d migration clamps the old early-island 31x quote without discarding its remaining duration" % revision)
		check(state.rocket_timer == 1800.0 and not state.rocket_pending and state.rocket_factor == 1.0 and state.natural_remaining == 0.0 and state.natural_factor == 1.0 and state.surge_kind == "normal", "revision %d migration initializes new stock mechanics safely" % revision)
		check(state.save_game(SAVE) and state.load_game(SAVE) and state._save_data().mechanics_revision == 8, "revision %d migration can be saved and loaded again as revision eight" % revision)

	# Revision-eight saves written before the duration increase keep their
	# original remaining time; loading never restarts or lengthens a live boom.
	for kind in ["normal", "natural", "rocket"]:
		for old_remaining in [5.0, 2.25]:
			state.reset_game()
			state.coins = 8.4e71
			state.storage.russet = 7
			if kind == "rocket":
				winter(state)
				state._prepare_rocket()
				state.complete_rocket_launch()
			elif kind == "normal":
				state._start_surge()
			if kind == "natural":
				state.natural_remaining = old_remaining
				state.natural_factor = 25.0
			else:
				state.surge_remaining = old_remaining
			state._event_in = 11.0
			state._refresh_market(false)
			var old_save: Dictionary = state._save_data().duplicate(true)
			write_save(old_save)
			check(state.load_game(SAVE) and state._save_data().mechanics_revision == 8, "old revision-eight %s with %.2f seconds remaining loads without a format bump" % [kind, old_remaining])
			var loaded_remaining: float = state.natural_remaining if kind == "natural" else state.surge_remaining
			check(loaded_remaining == old_remaining and state.coins == 8.4e71 and state.storage.russet == 7 and str(state.rng.state) == old_save.rng_state, "old %s keeps its original remaining duration, wealth, inventory, and RNG" % kind)
			state.update(old_remaining)
			check(state.surge_remaining == 0.0 and state.natural_remaining == 0.0, "old %s expires after only its saved remaining duration" % kind)

	state.reset_game()
	var safe: Dictionary = state._save_data().duplicate(true)
	reject_patch(state, safe, {"surge_remaining": 5.0, "surge_factor": 31.0}, "revision eight rejects a normal early-island factor above 30.99 without changing the farm")
	reject_patch(state, safe, {"surge_remaining": 10.01, "surge_factor": 25.0}, "normal surge duration cannot exceed ten seconds")
	reject_patch(state, safe, {"rocket_pending": true, "rocket_factor": 151.0}, "pending rockets cannot be loaded on an ineligible island")
	reject_patch(state, safe, {"rocket_factor": 151.0}, "a nonpending rocket cannot retain a hidden prepared factor")
	reject_patch(state, safe, {"rocket_timer": 0.0}, "a zero rocket timer is rejected instead of producing a stalled update loop")
	reject_patch(state, safe, {"natural_factor": 25.0}, "an expired natural spike cannot retain a stale multiplier")
	reject_patch(state, safe, {"natural_remaining": 10.01, "natural_factor": 25.0}, "natural spike duration cannot exceed ten seconds")
	winter(state)
	state.rocket_timer = 0.1
	state.update(0.1)
	var pending: Dictionary = state._save_data().duplicate(true)
	reject_patch(state, pending, {"rocket_factor": 150.99}, "a pending rocket factor below its promised band is rejected atomically")
	reject_patch(state, pending, {"rocket_factor": 501.01}, "a pending rocket factor above its maximum is rejected atomically")
	reject_patch(state, pending, {"rocket_timer": 1799.0}, "a pending rocket must retain the reset thirty-minute clock")
	state.complete_rocket_launch()
	state.surge_factor = 501.0
	state._refresh_market(false)
	var active: Dictionary = state._save_data().duplicate(true)
	reject_patch(state, active, {"surge_remaining": 10.01}, "rocket duration cannot exceed ten seconds")
	reject_patch(state, active, {"surge_factor": 501.01}, "an active rocket cannot exceed its exceptional cap")
	var invalid_market: Dictionary = active.market.duplicate(true)
	invalid_market.golden.sell = state.CROPS.golden.base * 101.01
	reject_patch(state, active, {"market": invalid_market}, "a rocket save cannot grant its higher quote ceiling to another crop")
	invalid_market = active.market.duplicate(true)
	invalid_market.icecap.sell = state.CROPS.icecap.base * 501.01
	reject_patch(state, active, {"market": invalid_market}, "the selected rocket quote itself remains bounded in save validation")
	check_boundary_clocks(state)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	state.free()
	print("ROCKET STOCK STATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
