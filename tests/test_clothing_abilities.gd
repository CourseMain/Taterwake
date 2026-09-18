extends SceneTree
## Verify equipment reaches the actual activities, not only stat descriptions.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var state = State.new()
	var builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(state)
	root.add_child(builds)
	builds.levels.scientist = 1
	builds.select_build("scientist")
	var base_chance: float = builds.experiment_chance()
	state._grant_item("scientist_coat")
	var geared_chance: float = builds.experiment_chance()
	check(is_equal_approx(geared_chance, base_chance * 1.3125), "lab coat improves actual experiment odds including Scientist synergy")
	check(str(builds.activity_info().description).contains("%.1f%%" % (geared_chance * 100.0)), "experiment panel reports the chance that will actually be used")
	var success_seed: int = -1
	var chooser := RandomNumberGenerator.new()
	for candidate in range(1000):
		chooser.seed = candidate
		var chance: float = chooser.randf()
		if chance > base_chance and chance < geared_chance:
			success_seed = candidate
			break
	check(success_seed >= 0, "deterministic draw exists between equipped and unequipped experiment odds")
	state.unequip_gear("body")
	state.storage.russet = 100
	state.rng.seed = success_seed
	var without_gear: String = builds.use_ability()
	check(without_gear.contains("no mutation") and state.mutations.is_empty(), "actual experiment fails at a draw outside unequipped odds")
	builds.research = 0
	builds.cooldown = 0.0
	state.equip_gear("scientist_coat")
	state.rng.seed = success_seed
	var with_gear: String = builds.use_ability()
	check(with_gear.contains("succeeded") and state.mutations.size() == 1, "same actual draw produces a stored mutation while wearing the coat")
	state.unequip_gear("body")
	builds.research = 0
	check(is_equal_approx(builds.experiment_chance(), base_chance), "removing clothes removes experimental bonuses immediately")
	builds.levels.scientist = 30
	builds.research = 10000
	state.equip_gear("scientist_coat")
	check(builds.experiment_chance() == 0.55, "mutation gear preserves the experiment success ceiling")
	builds.levels.industrialist = 1
	builds.select_build("industrialist")
	builds.cooldown = 0.0
	state.storage.russet = 150
	state._grant_item("industrialist_overalls")
	state.equip_gear("industrialist_overalls")
	builds.use_ability()
	builds.cooldown = 10.0
	builds.update(1.0, 3.0)
	check(is_equal_approx(float(builds.processing.elapsed), 3.0 * 1.3125), "furnace work and Factory Overalls both speed the real processing job once")
	check(builds.cooldown == 9.0, "processing clothes do not speed unrelated ability cooldowns")
	state.unequip_gear("body")
	var before: float = float(builds.processing.elapsed)
	builds.update(1.0)
	check(is_equal_approx(float(builds.processing.elapsed) - before, 1.0), "removing overalls stops their processing bonus immediately")
	builds.free()
	state.free()
	print("CLOTHING ABILITIES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
