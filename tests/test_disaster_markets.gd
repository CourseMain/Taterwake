extends SceneTree
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	var farm = State.new()
	root.add_child(farm)
	for event: String in ["freeze", "drought", "flood", "storm"]:
		for severity: float in [0.5, 1.0]:
			farm.reset_game()
			farm.debug_unlock_island(3)
			farm.travel_to(3)
			farm.climate.acknowledge(farm)
			farm.elapsed = 150.0
			farm._refresh_market()
			var before: Dictionary = farm.market.duplicate(true)
			farm.climate.begin_warning(farm, event, severity)
			farm.climate._impact(farm)
			farm._refresh_market()
			check(farm.market == before, event + " damage does not alter placeholder prices")
			farm._toggle_export()
			farm._end_frost(true)
			check(farm.market == before, "ship and frost rewards do not multiply prices")
			farm.climate.data.phase = "recovery"
			farm.climate.data.timer = 37.5
			farm._refresh_market()
			check(farm.market == before, "recovery does not alter placeholder prices")
	farm.free()
	print("DISASTER MARKETS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
