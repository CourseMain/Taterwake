extends SceneTree
## Adversarial profession transactions and migrations. Never reads a player save.
const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE: String = "user://build_transactions_qa_only.json"
var farm
var builds
var p
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)

func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not same(a[i], b[i]): return false
		return true
	return a == b

func fresh(island: int = 1) -> void:
	farm.reset_game()
	farm.rng.seed = 557124
	farm.coins = 1000000000.0
	farm.barn_level = 3
	farm._recompute_capacity()
	for id in builds.IDS: builds.levels[id] = 20
	if island > 1:
		farm.debug_unlock_island(island)
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
	for field in farm.island_plots.values():
		for plot in field: farm._clear_crop(plot)

func crop(index: int, stage: int = 1) -> void:
	var plot: Dictionary = farm.plots[index]
	farm._clear_crop(plot)
	plot.tilled = true
	plot.stage = stage
	plot.watered = stage > 1
	plot.elapsed = 10.0 if stage == 3 else 0.0
	plot.crop = "russet"

func reload_builds() -> bool:
	return builds.load_data(JSON.parse_string(JSON.stringify(builds.save_data())))

func farmer() -> void:
	fresh()
	check(not p.readiness("giant").ready and p.readiness("giant").reason.contains("Plant"), "Farmer with empty fields explains the missing planted crop")
	crop(0)
	crop(1, 2)
	crop(2, 3)
	crop(3)
	farm.plots[3].frozen = true
	check(p.cultivation_info().eligible == [0, 1], "Farmer highlights only planted, growing, unfrozen, uncultivated plots")
	var before: int = p.data.compost
	for index in [-2, -1, 2, 3, 23, 900]: p.cultivate(index)
	check(p.data.compost == before, "empty, locked, ripe, frozen and invalid targets cannot consume compost")
	check(p.cultivation_info(3).reason.contains("ice") and p.cultivation_info(2).reason.contains("ripe"), "invalid targets explain the actual next step")
	builds.select_build("scientist")
	p.cultivate(0)
	check(p.data.compost == before and not p.cultivation_info(0).ready, "changing builds cannot bypass Farmer ownership")
	builds.select_build("farmer")
	p.cultivate(0)
	p.cultivate(0)
	check(p.data.compost == before - 1 and farm.plots[0].cultivated and 0 not in p.cultivation_info().eligible, "one compost changes one growing crop exactly once")
	farm.plots[3].frozen = false
	crop(3)
	p.data.compost = 0
	p.cultivate(3)
	check(not farm.plots[3].get("cultivated", false) and p.readiness("giant").reason.contains("Harvest"), "empty compost points to a real replenishment action")
	farm.plots[0].stage = 3
	farm.plots[0].watered = true
	farm.plots[0].elapsed = 10.0
	farm.storage.russet = farm.capacity - 1
	var harvested: int = farm._harvest_plot(farm.plots[0])
	var full_yield: int = farm.plots[0].yield_total
	check(harvested == 1 and full_yield >= 9 and p.data.compost == 1 and farm.plots[0].cultivated, "partial giant harvest stores only available space and earns compost once")
	farm._harvest_plot(farm.plots[0])
	check(p.data.compost == 1, "clicking a full barn cannot manufacture compost")
	farm.sell_crop("russet", 100)
	builds.select_build("scientist")
	var rest: int = farm._harvest_plot(farm.plots[0])
	check(rest == full_yield - 1 and p.data.compost == 1 and farm.plots[0].stage == 0 and not farm.plots[0].has("cultivated"), "remaining yield survives switching, cannot mint more compost, and clears its trait after harvest")

func scientist_and_freshness() -> void:
	fresh(3)
	builds.select_build("scientist")
	var old: Dictionary = farm.storage.duplicate()
	p.breed()
	check(farm.storage == old and p.data.seedbank.is_empty() and p.readiness("breed").reason.contains("10"), "missing recipe parents are explained without partial spending")
	for recipe: String in p.RECIPES:
		p.action("recipe", recipe)
		var parents: Dictionary = p.RECIPES[recipe]
		for id: String in [parents.a, parents.b]:
			farm.storage[id] = 30
			p.mark_fresh(id, 30)
		p.breed()
		check(recipe in p.data.seedbank and farm.storage[parents.a] == 20 and farm.storage[parents.b] == 20, recipe + " discovery consumes exactly ten of each parent")
		check(p.fresh_info(parents.a).count == 20 and p.fresh_info(parents.b).count == 20, recipe + " breeding consumes the parents' actual fresh inventory")
		old = farm.storage.duplicate()
		p.breed()
		check(farm.storage == old, "rediscovering " + recipe + " cannot consume parents twice")
	check(builds.research == 3 and p.data.seedbank.size() == 3, "all three discoveries record permanent research")
	builds.select_build("farmer")
	p.action("variety", "hearty")
	farm.seed_inventory.russet = 10
	farm.plots[5].tilled = true
	farm.interact_plot(5, "plant")
	check(farm.plots[5].get("variety", "") == "hearty", "selected seed-bank trait is inherited after switching build")
	p.action("variety", "")
	farm.plots[6].tilled = true
	farm.interact_plot(6, "plant")
	check(not farm.plots[6].has("variety"), "ordinary seeds can be restored without deleting discoveries")
	fresh()
	builds.select_build("industrialist")
	farm.storage.russet = 120
	p.mark_fresh("russet", 20)
	p.update(44)
	farm.storage.russet += 1
	p.mark_fresh("russet", 1)
	p.update(1.1)
	check(p.fresh_info("russet").count == 1 and p.grade_preview().fresh == 0, "one new harvest cannot refresh an older twenty-potato batch")
	farm.storage.golden = 40
	p.mark_fresh("golden", 20)
	check(p.fresh_info("russet").count == 1 and p.fresh_info("golden").count == 20, "different crop harvests retain independent freshness")
	farm.sell_crop("golden", 20)
	check(farm.storage.golden == 20 and p.fresh_info("golden").count == 0, "sold fresh stock cannot lend freshness to the old stock left behind")
	farm.storage.russet += 20
	p.mark_fresh("russet", 20)
	var saved: Dictionary = p.fresh_info("russet")
	check(reload_builds() and same(saved, p.fresh_info("russet")), "per-crop freshness survives JSON reload without restarting timers")
	p.update(45)
	check(p.fresh_info("russet").count == 0 and p.data.fresh_lots.is_empty(), "freshness expires without removing ordinary harvest inventory")
	p.mark_fresh("russet", 20)
	p.update(44.9999995)
	check(reload_builds(), "a save at a fractional freshness-expiry boundary remains valid")
	p.data.fresh_lots.clear()
	for id in farm.CROP_IDS: farm.storage[id] = 10000
	for tick in range(1200):
		for id in farm.CROP_IDS: p.mark_fresh(id, 1)
		p.update(0.1)
	check(p.data.fresh_lots.size() <= p.MAX_FRESH_LOTS and builds.valid_data(builds.save_data()), "two minutes of rapid mixed harvests keep freshness bookkeeping bounded and saveable")

func industrialist() -> void:
	for rank in [1, 10, 20]:
		fresh()
		builds.levels.industrialist = rank
		builds.select_build("industrialist")
		farm.storage.russet = 500
		p.mark_fresh("russet", 500)
		p.action("method", "cure")
		var occupied: int = farm.storage_used()
		var jobs: int = p.queue_slots()
		for i in range(jobs + 2): p.load_batch()
		check(p.data.queue.size() == jobs - 1 and farm.storage.russet == 500 - jobs * 20 and farm.storage_used() == occupied, "rank %d queue is bounded and conserves real barn inventory" % rank)
		check(p.fresh_info("russet").count == 500 - jobs * 20 and not p.readiness("load").ready, "rank %d loaded crops lose raw freshness and queue reports full" % rank)
		var multiplier: float = builds.processing.multiplier
		builds.select_build("scientist")
		p.action("method", "polish")
		farm.selected_crop = "golden"
		check(reload_builds(), "rank %d active and queued work survives reload after switching" % rank)
		builds.update(40)
		check(builds.processing.is_empty() and p.data.queue.is_empty() and builds.processed.russet.count == jobs * 20 and builds.processed.russet.multiplier == multiplier, "rank %d loaded jobs preserve grade while future choices change" % rank)
		var before: float = farm.coins
		var value: float = builds.processed_value()
		builds.sell_processed()
		builds.sell_processed()
		check(is_equal_approx(farm.coins - before, value), "rank %d graded shipment pays once" % rank)
	fresh(2)
	builds.select_build("industrialist")
	farm.storage.russet = 100
	p.mark_fresh("russet", 100)
	for i in range(3): p.load_batch()
	check(farm.climate.begin_warning(farm, "flood", 1.0), "flood fixture starts on the real farm")
	farm.update(45.0)
	check(builds.processing.quantity == 14 and p.data.queue[0].quantity == 14 and p.data.queue[1].quantity == 14 and farm.storage.russet == 28, "barn disaster damages raw, loaded and queued potatoes consistently")
	check(farm.climate.data.barn_lost == 30 and farm.storage_used() == 70 and p.fresh_info("russet").count <= 28, "disaster receipt equals actual inventory loss without ghost freshness")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and builds.processing.quantity == 14, "a legitimate partially damaged batch remains a valid full-farm save")
	builds.update(40)
	check(builds.processed.russet.count == 42 and farm.storage_used() == 70, "damaged queued jobs finish only their surviving potatoes")

func investor_and_gambler() -> void:
	fresh(3)
	builds.select_build("investor")
	farm.selected_crop = "russet"
	var offer: Dictionary = p.contract_preview()
	p.reserve()
	check(p.data.contract.quantity == offer.quantity and p.data.contract.quote == offer.quote, "reserved buyer exactly matches the preview")
	var order: Dictionary = p.data.contract.duplicate()
	p.reserve()
	check(p.data.contract == order, "reservation cannot overwrite an existing locked buyer")
	farm.storage.russet = 99
	check(not p.readiness("deliver").ready and p.readiness("deliver").reason.contains("1 more"), "shipment explains exact shortage")
	p.deliver()
	check(p.data.contract == order and farm.storage.russet == 99, "insufficient shipment cannot partially consume crops")
	farm.travel_to(2)
	check(not p.readiness("deliver").ready and p.readiness("deliver").reason.contains("Frosthollow"), "shipment names the island the player must return to")
	farm.travel_to(3)
	farm.storage.russet = 100
	p.mark_fresh("russet", 100)
	farm.market.russet.sell *= 2
	builds.select_build("farmer")
	var before: float = farm.coins
	p.deliver()
	p.deliver()
	check(is_equal_approx(farm.coins - before, offer.total) and p.data.deliveries == 1 and p.fresh_info("russet").count == 0, "locked shipment pays once after switching and consumes its actual fresh stock")
	builds.select_build("investor")
	p.reserve()
	farm.storage.russet = 100
	p.update(180)
	check(p.data.contract.is_empty() and farm.storage.russet == 100, "expired buyer releases only the offer, preserving crops")
	for quantity in [5, 20, 100]:
		fresh()
		builds.select_build("gambler")
		farm.storage.russet = 100
		p.mark_fresh("russet", 100)
		p.action("stake_size", str(quantity))
		var held: int = farm.storage_used()
		p.stake_harvest()
		check(farm.storage.russet == 100 - quantity and farm.storage_used() == held and p.fresh_info("russet").count == 100 - quantity, "%d-potato stake reserves only chosen inventory" % quantity)
		check(reload_builds(), "%d-potato unclaimed stake survives reload" % quantity)
		p.reroll()
		var result: Dictionary = p.data.wager.duplicate()
		builds.update(180)
		check(p.data.charm and not p.readiness("reroll").ready, "recharged charm cannot grant a second reroll on the same wager")
		var rng_state: int = farm.rng.state
		p.reroll()
		check(p.data.wager == result and farm.rng.state == rng_state, "rejected second reroll leaves result and RNG unchanged")
		check(reload_builds() and p.data.wager.rerolled, "one-reroll limit persists across reload")
		builds.select_build("farmer")
		before = farm.coins
		var payout: float = result.quantity * result.quote * result.factor
		p.claim()
		p.claim()
		check(is_equal_approx(farm.coins - before, payout) and p.data.wager.is_empty(), "%d-potato stake can be claimed exactly once after switching" % quantity)

func migration_and_rejections() -> void:
	fresh()
	builds.select_build("gambler")
	farm.storage.russet = 100
	p.stake_harvest()
	p.reroll()
	var legacy: Dictionary = builds.save_data()
	legacy.version = 2
	legacy.professions.erase("fresh_lots")
	legacy.professions.wager.erase("rerolled")
	legacy.professions.fresh_crop = "russet"
	legacy.professions.fresh_count = 999
	legacy.professions.fresh_left = 30
	check(builds.load_data(legacy) and p.fresh_info("russet").count == 80 and p.data.wager.rerolled, "version 2 migrates legitimate stake, used charm and inventory-capped freshness")
	check(builds.save_data().version == 3 and reload_builds(), "migrated build writes a valid version 3 checkpoint")
	var valid: Dictionary = builds.save_data()
	for bad_value in [null, "broken", [], {"bad": true}]:
		var bad: Dictionary = valid.duplicate(true)
		bad.processing = bad_value
		check(not builds.load_data(bad) and same(builds.save_data(), valid), "malformed loaded-job structure rejects atomically")
	for bad_value in [null, "broken", [{"crop": "russet", "quantity": 20, "remaining": -1}], [{"crop": "russet", "quantity": 20, "remaining": INF}]]:
		var bad: Dictionary = valid.duplicate(true)
		bad.professions.fresh_lots = bad_value
		check(not builds.load_data(bad) and same(builds.save_data(), valid), "invalid freshness structure rejects atomically")
	var bad: Dictionary = valid.duplicate(true)
	bad.professions.wager.rerolled = 1
	check(not builds.load_data(bad), "saved per-wager reroll flag requires a boolean")
	legacy = valid.duplicate(true)
	legacy.version = 1
	legacy.erase("professions")
	legacy.processing = {"crop": "russet", "quantity": 100, "elapsed": 4.0, "duration": 10.0, "multiplier": 1.8}
	check(builds.load_data(legacy) and builds.levels.gambler == 20 and p.data.compost == 3, "version 1 keeps unlocked levels and receives fresh profession defaults")
	check(reload_builds() and builds.processing.multiplier == 1.8 and not builds.processing.has("grade"), "legacy job without a grade survives version 3 resaving without losing its quoted multiplier")
	builds.update(6)
	check(builds.processed.russet.count == 100 and builds.processed.russet.multiplier == 1.8, "legacy grade-less batch finishes at its original value")
	fresh()
	builds.levels.scientist = 0
	builds.select_build("scientist")
	check(builds.active == "farmer", "locked specialization cannot be equipped")
	farm.storage.russet = 100
	farm.storage.golden = 100
	var checkpoint: Dictionary = builds.save_data()
	var inventory: Dictionary = farm.storage.duplicate()
	for verb in ["load", "breed", "reserve", "stake"]: p.action(verb)
	check(same(builds.save_data(), checkpoint) and farm.storage == inventory, "un-equipped transactions cannot consume resources or create jobs")
	fresh()
	crop(0)
	builds.select_build("gambler")
	farm.storage.russet = 100
	p.stake_harvest()
	farm.blind_cycle.run_over = true
	checkpoint = builds.save_data()
	inventory = farm.storage.duplicate()
	var money: float = farm.coins
	for verb in ["load", "breed", "reserve", "deliver", "stake", "reroll", "claim"]: p.action(verb)
	p.claim()
	p.reroll()
	p.cultivate(0)
	check(same(builds.save_data(), checkpoint) and farm.storage == inventory and farm.coins == money, "collapsed farm cannot transact through direct or routed build actions")

func run() -> void:
	farm = State.new()
	builds = Builds.new()
	builds.state = farm
	farm.build_system = builds
	root.add_child(farm)
	root.add_child(builds)
	p = builds.professions
	farmer()
	scientist_and_freshness()
	industrialist()
	investor_and_gambler()
	migration_and_rejections()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	builds.queue_free()
	farm.queue_free()
	await process_frame
	print("BUILD TRANSACTIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
