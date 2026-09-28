extends SceneTree
## Exercise real transactions, partial harvests and save migration, never a player save.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE = "user://build_xp_test_only.json"
var farm
var builds
var p
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func fresh() -> void:
	farm.reset_game()
	farm.coins = 1e6
	farm.barn_level = 4
	farm._recompute_capacity()
	for id in builds.IDS: builds.levels[id] = 1
func earned(id: String) -> int:
	var total: int = int(builds.xp[id])
	for rank in range(1, int(builds.levels[id])): total += builds.xp_required(rank)
	return total
func ripe(index: int, variety: String = "") -> void:
	var plot: Dictionary = farm.plots[index]
	farm._clear_crop(plot)
	plot.merge({"unlocked": true, "tilled": true, "watered": true, "stage": 3, "elapsed": 10.0, "crop": "russet", "variety": variety}, true)
	if variety.is_empty(): plot.erase("variety")

func run() -> void:
	farm = State.new()
	builds = Builds.new()
	builds.state = farm
	farm.build_system = builds
	root.add_child(farm)
	root.add_child(builds)
	p = builds.professions
	fresh()
	for index in range(10):
		ripe(index)
		farm._harvest_plot(farm.plots[index])
	check(builds.levels.farmer == 2 and builds.xp.farmer == 0, "ten successful patches reach Farmer level 2")
	check(farm.crop_grow_time("russet") < 10.0, "earned Farmer level immediately improves growth")
	for index in range(13):
		ripe(0)
		farm._harvest_plot(farm.plots[0])
	check(builds.levels.farmer == 3 and builds.xp.farmer == 2 and builds.area_bonus() == 1, "XP carries across a level and unlocks wider tools")
	fresh()
	ripe(0)
	farm.storage.russet = farm.capacity
	farm._harvest_plot(farm.plots[0])
	check(earned("farmer") == 0, "full barn awards no XP")
	farm.storage.russet -= 1
	farm._harvest_plot(farm.plots[0])
	check(earned("farmer") == 4 and farm.plots[0].pending > 0, "first partial harvest earns patch XP once")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "partial harvest and XP round-trip with the whole farm")
	farm.storage.russet = 0
	farm._harvest_plot(farm.plots[0])
	check(earned("farmer") == 4, "finishing a partial harvest after reload cannot duplicate XP")

	fresh()
	builds.select_build("industrialist")
	farm.storage.russet = 20
	p.load_batch()
	check(earned("industrialist") == 0, "loading work does not pre-award completion XP")
	builds.processing.quantity = 7 # surviving crop count after a disaster
	builds.select_build("farmer")
	builds.update(11)
	check(earned("industrialist") == 7 and earned("farmer") == 0, "completed work credits its owning build and surviving crops")
	builds.update(11)
	builds.sell_processed()
	builds.sell_processed()
	check(earned("industrialist") == 7, "timers and selling the same output cannot duplicate processing XP")

	fresh()
	builds.select_build("scientist")
	p.breed()
	check(earned("scientist") == 0, "rejected research earns nothing")
	farm.storage.russet = 20
	farm.storage.golden = 20
	p.breed()
	p.breed()
	check(earned("scientist") == 80 and p.data.seedbank == ["hearty"], "each new discovery grants XP once")
	ripe(0)
	farm._harvest_plot(farm.plots[0])
	check(earned("scientist") == 80, "ordinary crops do not count as scientific field trials")
	ripe(0, "hearty")
	farm._harvest_plot(farm.plots[0])
	check(earned("scientist") == 84, "discovered varieties provide repeatable Scientist XP")
	builds.select_build("farmer")
	ripe(0, "hearty")
	farm._harvest_plot(farm.plots[0])
	check(earned("scientist") == 84 and earned("farmer") == 4, "only the equipped harvest profession earns the patch XP")

	fresh()
	builds.select_build("investor")
	p.reserve()
	p.deliver()
	check(earned("investor") == 0, "reservations and incomplete shipments earn no XP")
	p.update(181)
	check(earned("investor") == 0, "expired deliveries earn no XP")
	p.reserve()
	farm.storage.russet = 20
	builds.select_build("farmer")
	p.deliver()
	p.deliver()
	check(earned("investor") == 40 and earned("farmer") == 0, "completed shipment credits Investor once after switching")

	for factor in [0.5, 1.0, 3.0]:
		fresh()
		builds.select_build("gambler")
		farm.storage.russet = 20
		p.stake_harvest()
		p.reroll()
		check(earned("gambler") == 0, "placing and rerolling do not award claim XP")
		p.data.wager.factor = factor
		builds.select_build("farmer")
		p.claim()
		p.claim()
		check(earned("gambler") == 20, "all stake outcomes earn the same one-time XP")

	fresh()
	builds.award_xp("farmer", 10000)
	check(builds.levels.farmer == 30 and builds.xp.farmer == 0, "large awards stop exactly at level thirty")
	fresh()
	builds.levels.scientist = 0
	builds.award_xp("scientist", 500)
	builds.award_xp("farmer", -5)
	builds.award_xp("unknown", 50)
	check(builds.levels.scientist == 0 and builds.xp.scientist == 0 and builds.xp.farmer == 0, "XP cannot unlock a locked build or accept invalid awards")
	farm.blind_cycle.run_over = true
	builds.award_xp("farmer", 50)
	check(builds.xp.farmer == 0, "ended runs cannot earn build levels")
	fresh()
	builds.award_xp("farmer", 17)
	var saved: Dictionary = builds.save_data()
	check(builds.load_data(JSON.parse_string(JSON.stringify(saved))) and builds.xp.farmer == 17, "version 4 preserves XP through JSON")
	saved = builds.save_data()
	for bad_xp in [null, [], {}, {"farmer": 1}, {"farmer": NAN, "scientist": 0, "industrialist": 0, "investor": 0, "gambler": 0}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.xp = bad_xp
		check(not builds.load_data(bad) and builds.save_data() == saved, "invalid XP rejects atomically")
	for amount in [-1, 0.5, 40, INF]:
		var bad: Dictionary = saved.duplicate(true)
		bad.xp.farmer = amount
		check(not builds.load_data(bad) and builds.xp.farmer == 17, "XP must be a whole amount below the next level threshold")
	for version in [1, 2, 3]:
		var old: Dictionary = saved.duplicate(true)
		old.version = version
		old.erase("xp")
		if version == 1: old.erase("professions")
		elif version == 2: old.professions.erase("fresh_lots")
		check(builds.load_data(old) and builds.levels == saved.levels and builds.xp.farmer == 0, "legacy saves keep levels and start XP at zero")
	fresh()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	builds.free()
	farm.free()
	print("BUILD XP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
