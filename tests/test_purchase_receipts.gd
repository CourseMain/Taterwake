extends SceneTree
## Transaction-level receipt checks. Creates fresh farms; never reads or writes saves.
const State = preload("res://scripts/game_state.gd")
const Activities = preload("res://scripts/island_activities.gd")
const Builds = preload("res://scripts/player_builds.gd")
var checks: int = 0
var failures: int = 0
var state
var activities
var builds
var receipts: Array[Dictionary] = []
var rejected: Array[String] = []
var notices: Array[String] = []
var order: Array[String] = []
var receipt_snapshots: Array[Dictionary] = []
var changed_snapshots: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _fresh() -> void:
	if is_instance_valid(state):
		builds.free()
		activities.free()
		state.free()
	state = State.new()
	activities = Activities.new()
	activities.setup(state)
	builds = Builds.new()
	builds.state = state
	state.build_system = builds
	state.activity_system = activities
	root.add_child(state)
	root.add_child(activities)
	root.add_child(builds)
	state.rng.seed = 6103
	state.purchase_completed.connect(_on_purchase)
	state.purchase_rejected.connect(func(message: String): rejected.append(message); order.append("rejected"))
	state.notified.connect(func(message: String): notices.append(message); order.append("notified"))
	state.changed.connect(func(): changed_snapshots.append(_snapshot()); order.append("changed"))
	_clear_signals()

func _snapshot() -> Dictionary:
	return {"coins": state.coins, "seeds": state.seed_inventory.duplicate(true),
		"tools": state.tools.duplicate(true), "storage": state.storage.duplicate(true),
		"capacity": state.capacity, "barn": state.barn_level, "expansion": state.expansion,
		"island2": state.island2_unlocked, "island3": state.island3_unlocked,
		"plots": state.island_plots.duplicate(true), "duck_level": activities.duck_level,
		"cooldown": builds.cooldown, "scout": builds.next_roll_charge,
		"event": state.current_event, "event_remaining": state.event_remaining}

func _clear_signals() -> void:
	receipts.clear()
	rejected.clear()
	notices.clear()
	order.clear()
	receipt_snapshots.clear()
	changed_snapshots.clear()

func _on_purchase(receipt: Dictionary) -> void:
	receipts.append(receipt.duplicate(true))
	receipt_snapshots.append(_snapshot())
	order.append("receipt")

func _success(action: Callable, kind: String, id: String, quantity: int, cost: float, label: String, permit_notice: bool = false) -> Dictionary:
	var before: float = state.coins
	_clear_signals()
	var message: String = action.call()
	check(not message.is_empty(), label + " retains its readable return message")
	check(receipts.size() == 1 and rejected.is_empty(), label + " emits one committed receipt and no rejection")
	check(state.coins == maxf(0.0, before - cost), label + " charges the exact agreed price")
	check(not changed_snapshots.is_empty() and changed_snapshots.back() == _snapshot(), label + " refresh listeners see the committed state")
	check(receipt_snapshots.size() == 1 and receipt_snapshots[0] == _snapshot(), label + " receipt listeners see final inventory and balance")
	check(order.find("changed") >= 0 and order.find("changed") < order.find("receipt"), label + " refreshes the HUD before showing the receipt")
	if not permit_notice:
		check(notices.is_empty(), label + " does not also emit a duplicate generic notification")
	if receipts.is_empty():
		return {}
	var receipt: Dictionary = receipts[0]
	check(str(receipt.get("kind", "")) == kind and str(receipt.get("id", "")) == id, label + " identifies the actual purchased item")
	check(int(receipt.get("quantity", -1)) == quantity and float(receipt.get("cost", -1.0)) == cost, label + " reports exact quantity and charged price")
	check(not str(receipt.get("name", "")).is_empty(), label + " includes a display name")
	return receipt

func _failure(action: Callable, label: String) -> void:
	var before: Dictionary = _snapshot()
	_clear_signals()
	var message: String = action.call()
	check(_snapshot() == before, label + " leaves money, inventory and progress unchanged")
	check(receipts.is_empty() and rejected.size() == 1, label + " emits a rejection without a success receipt")
	check(rejected.size() == 1 and rejected[0] == message and not message.is_empty(), label + " returns the same useful error shown to the player")
	check(changed_snapshots.is_empty() and notices.is_empty(), label + " avoids redundant refreshes and duplicate error popups")

func _test_seeds() -> void:
	_fresh()
	state.coins = 1000000.0
	var old_count: int = state.seed_inventory.russet
	var cost: float = float(state.market.russet.seed) * 5
	var receipt: Dictionary = _success(func(): return state.buy_seeds("russet", 5), "seeds", "russet", 5, cost, "five-seed bundle")
	check(state.seed_inventory.russet == old_count + 5 and int(receipt.get("total", -1)) == old_count + 5, "seed receipt total includes the seeds already owned")
	_success(func(): return state.buy_seeds("russet", 50), "seeds", "russet", 50, float(state.market.russet.seed) * 50, "second consecutive seed bundle")
	_failure(func(): return state.buy_seeds("unknown", 5), "invalid seed identifier")
	_failure(func(): return state.buy_seeds("russet", 0), "zero seed quantity")
	_failure(func(): return state.buy_seeds("russet", -5), "negative seed quantity")
	_failure(func(): return state.buy_seeds("russet", 1000000001), "oversized seed request")
	_failure(func(): return state.buy_seeds("sunburst", 5), "wrong-island seeds")
	state.coins = float(state.market.russet.seed) * 5 - 0.5
	_failure(func(): return state.buy_seeds("russet", 5), "unaffordable seeds")
	state.coins = float(state.market.russet.seed) * 5
	_success(func(): return state.buy_seeds("russet", 5), "seeds", "russet", 5, state.coins, "exact-wallet seed checkout")
	check(state.coins == 0.0, "exact-wallet seed checkout cannot leave negative money")
	state.coins = 1.0e18
	state.seed_inventory.russet = State.MAX_INVENTORY - 5
	_success(func(): return state.buy_seeds("russet", 5), "seeds", "russet", 5, float(state.market.russet.seed) * 5, "last available seed spaces")
	check(state.seed_inventory.russet == State.MAX_INVENTORY, "seed limit is reached without overflow")
	_failure(func(): return state.buy_seeds("russet", 1), "full seed inventory")
	for island in [1, 2, 3]:
		_fresh()
		state.island2_unlocked = true
		state.island3_unlocked = true
		state.travel_to(island)
		state.coins = 1.0e18
		builds.active = "investor"
		builds.levels.investor = 9
		state.inventory_items.trader_token = 3
		state._start_event("seed_fair")
		var crop: String = "russet" if island == 1 else ("sunburst" if island == 2 else "icecap")
		var old_quote: float = float(state.market[crop].seed)
		state._start_event("shortage")
		cost = float(state.market[crop].seed) * 17
		check(float(state.market[crop].seed) != old_quote, "island %d live quote changed before checkout" % island)
		receipt = _success(func(): return state.buy_seeds(crop, 17), "seeds", crop, 17, cost, "island %d discounted live-price seeds" % island)
		check(int(receipt.get("total", -1)) == state.seed_inventory[crop], "island %d receipt inventory is current" % island)
	_fresh()
	state.coins = 100000.0
	state._start_event("crash")
	_success(func(): return state.buy_seeds("russet", 10), "seeds", "russet", 10, float(state.market.russet.seed) * 10, "quest-completing seed purchase", true)
	check(state.quest_progress.starter_crash == 10 and notices.size() == 1 and notices[0].begins_with("QUEST COMPLETE"), "seed quest milestone stays distinct from the single purchase receipt")

func _test_tools_and_space() -> void:
	_fresh()
	_failure(func(): return state.upgrade_tool("pest"), "non-upgradeable tool")
	_failure(func(): return state.upgrade_tool("hoe"), "unaffordable tool")
	state.coins = 1.0e15
	for tool: String in ["hoe", "water", "harvest"]:
		for rank in [1, 2]:
			var receipt: Dictionary = _success(func(): return state.upgrade_tool(tool), "tool", tool, 1, State.TOOL_COSTS[tool][rank - 1], "%s rank %d" % [tool, rank])
			check(state.tools[tool] == rank and int(receipt.get("level", -1)) == rank, "receipt shows purchased %s rank %d" % [tool, rank])
		_failure(func(): return state.upgrade_tool(tool), tool + " rank-three gate on island one")
	state.island2_unlocked = true
	state.island3_unlocked = true
	state.travel_to(2)
	_failure(func(): return state.upgrade_tool("hoe"), "rank-three gate on island two")
	state.travel_to(3)
	for tool: String in ["hoe", "water", "harvest"]:
		var receipt: Dictionary = _success(func(): return state.upgrade_tool(tool), "tool", tool, 1, State.TOOL_COSTS[tool][2], tool + " winter rank three")
		check(state.tools[tool] == 3 and int(receipt.get("level", -1)) == 3, tool + " winter receipt reports final rank")
		_failure(func(): return state.upgrade_tool(tool), tool + " maximum rank")
	_fresh()
	_failure(func(): return state.upgrade_barn(), "unaffordable barn")
	state.coins = 100000.0
	state._grant_item("winter_weave")
	var old_capacity: int = state.capacity
	var receipt: Dictionary = _success(func(): return state.upgrade_barn(), "barn", "barn", 210, 500.0, "barn with capacity equipment")
	check(state.capacity - old_capacity == 210 and int(receipt.get("total", -1)) == state.capacity, "barn receipt reports actual capacity gain including owned upgrades")
	state.barn_level = 20
	state._recompute_capacity()
	_failure(func(): return state.upgrade_barn(), "maximum barn")
	state.coins = 1799.0
	_failure(func(): return state.expand_field(), "unaffordable field")
	state.coins = 1800.0
	_success(func(): return state.expand_field(), "field", "expansion", 12, 1800.0, "starter field expansion")
	check(state.plots.all(func(plot: Dictionary): return bool(plot.unlocked)), "field receipt is emitted after all new beds are unlocked")
	_failure(func(): return state.expand_field(), "already expanded field")
	for island in [2, 3]:
		state.current_island = island
		_failure(func(): return state.expand_field(), "island %d already open field" % island)

func _test_islands() -> void:
	_fresh()
	state.coins = State.ISLAND2_UNLOCK_COST
	_failure(func(): return state.unlock_island2(), "island two harvest gate")
	state.mastery.russet = State.ISLAND2_UNLOCK_HARVEST
	state.coins -= 1.0
	_failure(func(): return state.unlock_island2(), "island two money gate")
	state.coins += 1.0
	_success(func(): return state.unlock_island2(), "island", "2", 1, State.ISLAND2_UNLOCK_COST, "Golden Shores unlock")
	check(state.island2_unlocked and state.island_plots["2"].all(func(plot: Dictionary): return bool(plot.unlocked)), "Golden Shores receipt follows all 48 beds unlocking")
	_failure(func(): return state.unlock_island2(), "duplicate island two unlock")
	state.coins = State.ISLAND3_UNLOCK_COST
	_failure(func(): return state.unlock_island3(), "winter harvest gate")
	state.mastery.russet = State.ISLAND3_UNLOCK_HARVEST
	state.island2_unlocked = false
	_failure(func(): return state.unlock_island3(), "winter prior-island gate")
	state.island2_unlocked = true
	state.coins -= 1.0
	_failure(func(): return state.unlock_island3(), "winter money gate")
	state.coins += 1.0
	_success(func(): return state.unlock_island3(), "island", "3", 1, State.ISLAND3_UNLOCK_COST, "Frosthollow unlock")
	check(state.island3_unlocked and state.island_plots["3"].all(func(plot: Dictionary): return bool(plot.unlocked)), "Frosthollow receipt follows all 80 beds unlocking")
	_failure(func(): return state.unlock_island3(), "duplicate winter unlock")

func _test_ducks_and_services() -> void:
	_fresh()
	_failure(func(): return activities.buy_duck(), "unaffordable duck training")
	state.coins = 1000000.0
	for rank in [1, 2, 3]:
		var receipt: Dictionary = _success(func(): return activities.buy_duck(), "duck", "duck_patrol", 1, Activities.DUCK_COSTS[rank - 1], "duck training level %d" % rank)
		check(activities.duck_level == rank and int(receipt.get("level", -1)) == rank, "duck receipt shows committed training level %d" % rank)
		check(activities.duck_patrols["1"].size() == 1 and activities.duck_patrols["2"].size() == 2 and activities.duck_patrols["3"].size() == 3, "training level %d keeps every island's flock" % rank)
	_failure(func(): return activities.buy_duck(), "maximum duck training")
	state.current_island = 2
	_failure(func(): return activities.buy_duck(), "maximum duck training after travel")
	for island in [1, 2, 3]:
		_fresh()
		state.island2_unlocked = island >= 2
		state.island3_unlocked = island == 3
		state.travel_to(island)
		builds.active = "gambler"
		builds.levels.gambler = 1
		var cost: float = state.roll_cost("normal") * 0.5
		state.coins = cost - 1.0
		_failure(func(): return builds.use_ability(), "island %d unaffordable scouting" % island)
		state.coins = cost
		_success(func(): return builds.use_ability(), "service", "scout", 1, cost, "island %d scouting" % island)
		check(builds.next_roll_charge == 0.5 and builds.cooldown == 30.0, "scout receipt follows applying the paid reward boost")
		state.coins = cost * 10
		_failure(func(): return builds.use_ability(), "island %d duplicate scouting charge" % island)
	_fresh()
	builds.active = "investor"
	builds.levels.investor = 5
	state._refresh_market(false)
	var cost: float = float(state.market.russet.seed) * 10
	state.coins = cost - 1.0
	_failure(func(): return builds.use_ability(), "unaffordable market call")
	state.coins = cost
	_success(func(): return builds.use_ability(), "service", "market_call", 1, cost, "paid market call", true)
	check(state.current_event == "shortage" and builds.cooldown == 45.0 and notices.size() == 1, "market call keeps its distinct event notification and applies the bought service")
	state.coins = 1000000.0
	_failure(func(): return builds.use_ability(), "market-call cooldown")
	_clear_signals()
	state.storage.russet = 1
	state.sell_crop("russet")
	state.select_crop("giant")
	check(receipts.is_empty() and rejected.is_empty(), "selling and selecting do not masquerade as purchases")

func _run() -> void:
	_test_seeds()
	_test_tools_and_space()
	_test_islands()
	_test_ducks_and_services()
	builds.free()
	activities.free()
	state.free()
	print("PURCHASE RECEIPTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
