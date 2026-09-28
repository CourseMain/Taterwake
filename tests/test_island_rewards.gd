extends SceneTree
const State = preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	farm.set_process(false)
	farm.rng.seed = 176
	for island in [1,2,3]:
		farm.current_island = island
		farm.inventory_items.clear()
		for entry: Dictionary in farm.quest_info():
			check(entry.coins >= float(farm.BlindRules.PROGRESSION_BASELINES[island]) * 0.002, "quest reward is useful at the local economy")
			check(entry.reward_text.begins_with(farm.money(entry.coins)), "displayed quest cash matches payout")
			farm.quest_progress[entry.id] = entry.target
			var balance: float = farm.coins
			farm.claim_quest(entry.id)
			check(is_equal_approx(farm.coins - balance, entry.coins), "quest pays exact advertised amount")
			farm.claim_quest(entry.id)
			check(is_equal_approx(farm.coins - balance, entry.coins), "quest cannot be claimed twice")
	farm.inventory_items = {"sunstone":1,"aurora":1,"almanac":1,"lens":1,"compass":1,"winter_weave":1,"bottomless_sack":1,"trader_token":1}
	farm.equipment = farm._empty_equipment()
	check(is_equal_approx(farm.item_yield_bonus(),0.4), "artifact yield matches the new descriptions")
	check(is_equal_approx(farm.item_mastery_bonus(),0.2), "almanac has a meaningful mastery bonus")
	check(is_equal_approx(farm.item_mutation_factor(),2.35), "mutation relic and wonder bonuses stack as advertised")
	check(is_equal_approx(farm.item_barn_factor(),1.8), "barn artifacts scale capacity in every economy")
	check(is_equal_approx(farm.item_stock_factor(),1.05), "trader token has a real sale-price benefit")
	farm._refresh_market()
	for crop: String in farm.CROP_IDS:
		check(is_equal_approx(farm.market[crop].seed, snappedf(farm.market[crop].sell*0.75+1e-9,0.01)), "token preserves fixed seed/quote ratio")
	farm.reset_game()
	farm._grant_item("winter_weave")
	farm._grant_item("bottomless_sack")
	farm.quest_progress.starter_combo = 12
	farm.claim_quest("starter_combo")
	var old: Dictionary = farm._save_data().duplicate(true)
	old.mechanics_revision = 19
	old.capacity = 250
	var path := "user://artifact_migration_test_only.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(farm.load_game(path) and farm.capacity == 360, "existing save loads with expanded artifact capacity")
	check(farm.quest_claimed.has("starter_combo"), "migration keeps previously collected quest rewards claimed")
	check(farm.save_game(path) and farm.load_game(path) and farm.capacity == 360, "updated artifact effects round trip through saves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	farm.queue_free()
	await process_frame
	print("ISLAND REWARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
