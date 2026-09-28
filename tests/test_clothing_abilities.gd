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
	var base_chance: float = state.mutation_chance("russet")
	state._grant_item("scientist_coat")
	var geared_chance: float = state.mutation_chance("russet")
	check(is_equal_approx(geared_chance, base_chance * 1.3125), "lab coat improves field mutations including Scientist synergy")
	state.unequip_gear("body")
	check(is_equal_approx(state.mutation_chance("russet"), base_chance), "removing the coat removes its field bonus")
	state.storage.russet = 20
	state.storage.golden = 20
	var recipe: String = builds.professions.data.recipe
	var before_rng: int = state.rng.state
	builds.use_ability()
	check(builds.professions.data.seedbank.has(recipe) and state.storage.russet == 10 and state.storage.golden == 10, "breeding consumes both parent crops and stores the selected variety")
	check(state.rng.state == before_rng, "seed-bank discovery is deterministic")
	state.equip_gear("scientist_coat")
	check(state.mutation_chance("russet") > base_chance, "equipped coat continues to affect field harvests after research")
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
