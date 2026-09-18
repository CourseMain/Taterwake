extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE: String = "user://spud_builds_test_only.json"
var checks: int = 0
var failures: int = 0
var state
var builds

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	state = State.new()
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(state)
	root.add_child(builds)
	state.rng.seed = 87923
	check(builds.active == "farmer" and builds.levels.farmer == 1, "every new farm starts with the Farmer build")
	builds.select_build("scientist")
	check(builds.active == "farmer", "unearned builds cannot be equipped")
	var starting_levels: Dictionary = builds.levels.duplicate()
	var starting_rng: int = state.rng.state
	check(builds.open_crate().is_empty() and builds.levels == starting_levels and state.rng.state == starting_rng, "zero crates reject rewards before RNG advances")
	builds.build_crates = -2
	check(builds.open_crate().is_empty() and builds.build_crates == 0 and state.rng.state == starting_rng, "negative quantities cannot grant a reward or advance RNG")
	builds.build_crates = 1
	var result: Dictionary = builds.open_crate()
	check(result.has("build_id") and result.tier == "build" and builds.build_crates == 0, "crate consumes one item and grants a build-only result")
	check(builds.open_crate().is_empty(), "one crate cannot be opened twice")
	builds.build_crates = 2
	starting_rng = state.rng.state
	starting_levels = builds.levels.duplicate()
	check(builds.open_crate().is_empty() and builds.build_crates == 2 and builds.levels == starting_levels and state.rng.state == starting_rng, "overlapping requests reject even when another crate is owned")
	builds.finish_crate_reveal()
	var observed: Array[bool] = []
	var on_reward_change: Callable = func():
		observed.append(builds.build_crates == 1 and builds.open_crate().is_empty())
	state.changed.connect(on_reward_change, CONNECT_ONE_SHOT)
	check(not builds.open_crate().is_empty() and builds.build_crates == 1, "next crate can be opened after the prior reveal finishes")
	check(observed == [true], "reward callbacks observe consumption first and cannot reenter opening")
	builds.finish_crate_reveal()
	for id in builds.IDS:
		builds.levels[id] = 3
	builds.select_build("farmer")
	check(state.crop_grow_time("russet") < 10.0 and state.affected_tiles(7, "hoe").size() > 1, "Farmer upgrades change real growth speed and manual tool area")
	builds.select_build("scientist")
	var scientific_chance: float = state.mutation_chance("russet")
	builds.select_build("farmer")
	check(scientific_chance > state.mutation_chance("russet"), "Scientist increases actual mutation chances")
	var regular_seed: float = state.market.russet.seed
	builds.select_build("investor")
	check(state.market.russet.seed < regular_seed, "Investor discount changes the real seed quote")
	state.coins = 1000000.0
	var before: float = state.coins
	builds.use_ability()
	check(state.coins < before and state.current_event == "shortage" and state.event_remaining <= 5.0, "Investor pays for a real temporary buying opportunity")
	state._end_event()
	builds.cooldown = 0.0
	builds.select_build("gambler")
	var odds_before: Array[Dictionary] = state.roll_odds("normal")
	builds.use_ability()
	var odds_after: Array[Dictionary] = state.roll_odds("normal")
	check(odds_after[0].chance < odds_before[0].chance, "Gambler scouting improves displayed and actual reward quality")
	state.roll("normal")
	check(builds.next_roll_charge == 0.0, "scouted quality is consumed by exactly one paid roll")
	builds.cooldown = 0.0
	builds.select_build("scientist")
	state.storage.russet = 40
	builds.use_ability()
	check(builds.research == 1 and state.storage.russet == 20, "research consumes held crops and records actual progress")
	builds.cooldown = 0.0
	builds.select_build("industrialist")
	state.upgrade_barn()
	state.storage.russet = 200
	before = state.coins
	var used_before: int = state.storage_used()
	builds.use_ability()
	check(builds.processing.quantity == 100 and state.storage.russet == 100, "processor accepts one manually loaded batch")
	check(state.storage_used() == used_before, "loaded potatoes continue to occupy barn capacity")
	builds.select_build("farmer")
	check(builds.active == "industrialist", "loaded machinery finishes before changing specializations")
	builds.update(10.1)
	check(builds.processing.is_empty() and int(builds.processed.russet.count) == 100, "loaded processing job finishes into held inventory")
	check(state.coins == before and state.storage_used() == used_before, "finished processing never sells itself or frees occupied storage")
	var value: float = builds.processed_value()
	check(value > 100.0 * state.market.russet.sell, "processed crop batch is worth more at the live quote")
	builds.sell_processed()
	check(is_equal_approx(state.coins, before + value) and builds.processed.is_empty(), "processed sale pays exactly once when requested")
	# Save and reload an unfinished batch, build levels and an unopened crate.
	builds.use_ability()
	builds.update(2.0)
	var saved_processing_work: float = float(builds.processing.elapsed)
	builds.build_crates = 2
	builds.levels.farmer = 30
	check(state.save_game(SAVE), "state saves builds and processing with the same farm snapshot")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	state.reset_game()
	check(builds.levels.farmer == 1 and builds.build_crates == 0, "reset restores the default build without retaining old rewards")
	check(state.load_game(SAVE), "build-bearing farm save reloads")
	check(builds.active == "industrialist" and builds.levels.farmer == 30 and builds.build_crates == 2, "equipped role, level thirty and crates persist")
	check(is_equal_approx(builds.processing.elapsed, saved_processing_work), "processing resumes from exact saved progress, including equipped speed, without offline production")
	var bad: Dictionary = saved.duplicate(true)
	bad.builds.levels.scientist = 31
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	check(not state.load_game(SAVE) and builds.levels.farmer == 30, "invalid build data is rejected without mutating the farm")
	state.reset_game()
	state.rng.seed = 182
	for index in range(1000):
		builds.grant_roll_build("common")
	check(builds.build_crates >= 30 and builds.build_crates <= 70, "independent common rolls include the five percent crate drop")
	check(builds.levels.farmer == 1, "common crate drops do not silently grant a build before opening")
	starting_levels = builds.levels.duplicate()
	for tier in ["rare", "epic", "legendary", "mythic", "jackpot", "relic", "mystery"]:
		for index in range(50):
			builds.grant_roll_build(tier)
	check(builds.levels == starting_levels, "no paid-roll rarity silently grants or improves a build")
	builds.build_crates = 200
	for index in range(200):
		builds.open_crate()
		builds.finish_crate_reveal()
	var all_capped: bool = true
	for id in builds.IDS:
		all_capped = all_capped and int(builds.levels[id]) == 30
	check(all_capped, "build-only crates develop all five builds to thirty levels without overflow")
	check(builds.build_crates == 51, "fully capped builds preserve unused crates instead of consuming them for nothing")
	var invalid_crates: Dictionary = builds.save_data()
	invalid_crates.build_crates = -1
	check(not builds.load_data(invalid_crates) and builds.build_crates == 51, "negative saved crate ownership is rejected without mutation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	builds.queue_free()
	state.queue_free()
	await process_frame
	print("PLAYER BUILDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
