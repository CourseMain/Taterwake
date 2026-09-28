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
		for entry: Dictionary in farm.quest_info():
			check(entry.coins == 100.0, "quest reward is a flat hundred Spudions on every island")
			check(entry.reward_text.begins_with(farm.money(entry.coins)), "displayed quest cash matches payout")
			farm.quest_progress[entry.id] = entry.target
			var balance: float = farm.coins
			farm.claim_quest(entry.id)
			check(is_equal_approx(farm.coins - balance, entry.coins), "quest pays exact advertised amount")
			farm.claim_quest(entry.id)
			check(is_equal_approx(farm.coins - balance, entry.coins), "quest cannot be claimed twice")
	farm.queue_free()
	await process_frame
	print("ISLAND REWARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
