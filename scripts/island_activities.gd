extends Node
## Small island jobs that use the same crops, prices, and pest rules as the farm.
signal duck_cleared(index: int)

const DUCK_COSTS: Array[float] = [1500.0, 15000.0, 150000.0]
const DUCK_INTERVALS: Array[float] = [4.0, 3.0, 2.0]
const DUCK_HIRE_COSTS: Array[float] = [1500.0, 25000000.0, 750000000000.0]
const FURNACE_FUEL: int = 25
const FURNACE_DURATION: float = 20.0
const FURNACE_COOLDOWN: float = 60.0
const CONTRACT_COOLDOWN: float = 25.0

var state
var duck_counts: Dictionary = {}
var duck_speeds: Dictionary = {}
# Compatibility for older debug/capture callers. New purchases use the two
# explicit controls below; both ownership and speed belong to each island.
var duck_level: int:
	get: return 1 + duck_speed() if duck_count() > 0 else 0
	set(value):
		var key: String = str(_island())
		duck_counts[key] = duck_capacity() if value > 0 else 0
		duck_speeds[key] = clampi(value - 1, 0, 2)
var duck_patrols: Dictionary = {}
# First-duck aliases keep existing callers and saved showcase fixtures working.
var duck_from: int:
	get: return int(_current_ducks()[0]["from"])
	set(value): _current_ducks()[0]["from"] = value
var duck_target: int:
	get: return int(_current_ducks()[0].target)
	set(value): _current_ducks()[0].target = value
var duck_elapsed: float:
	get: return float(_current_ducks()[0].elapsed)
	set(value): _current_ducks()[0].elapsed = value
var duck_peck: float:
	get: return float(_current_ducks()[0].peck)
	set(value): _current_ducks()[0].peck = value
var duck_clears: int = 0
var contract: Dictionary = {}
var contract_completed: int = 0
var contract_cooldown: float = 0.0
var furnace_remaining: float = 0.0
var furnace_cooldown: float = 0.0
var furnace_burned: int = 0

func setup(farm_state) -> void:
	state = farm_state

func reset() -> void:
	duck_counts.clear()
	duck_speeds.clear()
	duck_patrols.clear()
	duck_clears = 0
	contract = {}
	contract_completed = 0
	contract_cooldown = 0.0
	furnace_remaining = 0.0
	furnace_cooldown = 0.0
	furnace_burned = 0

func _island() -> int:
	return int(state.current_island) if state != null else 1

func duck_capacity() -> int:
	return _island()

func duck_count() -> int:
	return int(duck_counts.get(str(_island()), 0))

func duck_speed() -> int:
	return int(duck_speeds.get(str(_island()), 0))

func duck_interval() -> float:
	return DUCK_INTERVALS[duck_speed()]

func duck_hire_cost() -> float:
	return DUCK_HIRE_COSTS[mini(2, _island() - 1)] * (duck_count() + 1)

func duck_speed_cost() -> float:
	return DUCK_COSTS[mini(2, duck_speed() + 1)] * DUCK_HIRE_COSTS[mini(2, _island() - 1)] / DUCK_HIRE_COSTS[0]

func _active_ducks() -> Array:
	return _current_ducks().slice(0, duck_count())

func _default_flock(island: int) -> Array[Dictionary]:
	var ducks: Array[Dictionary] = []
	var field_size: int = state.island_plots[str(island)].size() if state != null and state.island_plots.has(str(island)) else 24
	for index in range(maxi(1, island)):
		var origin: int = mini(field_size - 1, index * maxi(1, field_size / maxi(1, island)))
		ducks.append({"from": origin, "target": (origin + 1) % field_size, "elapsed": 0.0, "peck": 0.0, "clears": 0})
	return ducks

func _flock(island: int) -> Array:
	var key: String = str(island)
	if not duck_patrols.has(key):
		duck_patrols[key] = _default_flock(island)
	return duck_patrols[key]

func _current_ducks() -> Array:
	return _flock(int(state.current_island) if state != null else 1)

func _ensure_patrols() -> void:
	for island in state.island_plots:
		_flock(int(island))
		if not duck_counts.has(island):
			duck_counts[island] = 0
		if not duck_speeds.has(island):
			duck_speeds[island] = 0

func buy_duck() -> String:
	return hire_duck() if duck_count() == 0 else train_ducks()

func hire_duck() -> String:
	if duck_count() >= duck_capacity():
		return state._reject_purchase("Flock full: %d / %d ducks." % [duck_count(), duck_capacity()])
	var cost: float = duck_hire_cost()
	if float(state.coins) < cost:
		return state._reject_purchase("Hire a duck · %s" % state.money(cost))
	state.coins -= cost
	duck_counts[str(_island())] = duck_count() + 1
	_ensure_patrols()
	_assign_targets(_active_ducks(), state.island_plots[str(_island())])
	return state._complete_purchase({"kind": "duck", "id": "duck_patrol", "name": "Patrol duck", "quantity": 1, "cost": cost, "total": duck_count(), "level": duck_level}, "Duck hired! %d / %d on patrol." % [duck_count(), duck_capacity()])

func train_ducks() -> String:
	if duck_count() == 0:
		return state._reject_purchase("Hire a duck first.")
	if duck_speed() >= 2:
		return state._reject_purchase("Top speed reached · 2s per bed.")
	var cost: float = duck_speed_cost()
	if float(state.coins) < cost:
		return state._reject_purchase("Faster ducks · %s" % state.money(cost))
	var previous_interval: float = duck_interval()
	state.coins -= cost
	duck_speeds[str(_island())] = duck_speed() + 1
	for duck in _current_ducks():
		duck.elapsed = float(duck.elapsed) / previous_interval * duck_interval()
	return state._complete_purchase({"kind": "duck", "id": "duck_speed", "name": "Duck speed", "quantity": 1, "cost": cost, "level": duck_speed(), "interval": duck_interval()}, "Faster flock! %.0fs between beds." % duck_interval())

func _infested(field: Array, index: int) -> bool:
	return index >= 0 and index < field.size() and bool(field[index].get("pests", false)) and int(field[index].get("stage", 0)) > 0

func _urgent_target(field: Array, reserved: Dictionary) -> int:
	var target: int = -1
	var urgency: float = -1.0
	for index in range(field.size()):
		if reserved.has(index) or not _infested(field, index):
			continue
		var plot: Dictionary = field[index]
		var danger: float = float(plot.get("pest_ticks", 0)) * 5.0 + float(plot.get("pest_elapsed", 0.0))
		if danger > urgency:
			target = index
			urgency = danger
	return target

func _assign_targets(flock: Array, field: Array, arrived: Array[int] = []) -> void:
	var reserved: Dictionary = {}
	# Existing chases keep their arrival times; other ducks claim separate beds.
	for index in range(flock.size()):
		var target: int = int(flock[index].target)
		if not index in arrived and _infested(field, target) and not reserved.has(target):
			reserved[target] = index
	for index in range(flock.size()):
		var duck: Dictionary = flock[index]
		var previous: int = int(duck.target)
		if reserved.get(previous, -1) == index:
			continue
		var target: int = _urgent_target(field, reserved)
		if target < 0 and not index in arrived and not reserved.has(previous) and bool(field[previous].get("unlocked", false)):
			target = previous
		if target < 0:
			for offset in range(1, field.size() + 1):
				var candidate: int = (int(duck["from"]) + offset) % field.size()
				if not reserved.has(candidate) and bool(field[candidate].get("unlocked", false)):
					target = candidate
					break
		if target < 0:
			target = int(duck["from"])
		if target != previous:
			# Approximate the nearest bed when a new outbreak redirects a patrol.
			if not index in arrived and float(duck.elapsed) >= duck_interval() * 0.5:
				duck["from"] = previous
			duck.target = target
			duck.elapsed = 0.0
		reserved[target] = index

func _update_ducks(delta: float) -> bool:
	if duck_count() == 0:
		return false
	var flock: Array = _active_ducks()
	var field: Array = state.island_plots[str(state.current_island)]
	_assign_targets(flock, field)
	var remaining: float = delta
	var changed: bool = false
	while remaining > 0.000001:
		var step: float = remaining
		for duck in flock:
			step = minf(step, maxf(0.000001, duck_interval() - float(duck.elapsed)))
		remaining -= step
		var arrived: Array[int] = []
		for index in range(flock.size()):
			var duck: Dictionary = flock[index]
			duck.peck = maxf(0.0, float(duck.peck) - step)
			duck.elapsed = float(duck.elapsed) + step
			if float(duck.elapsed) < duck_interval() - 0.000001:
				continue
			duck.elapsed = 0.0
			arrived.append(index)
			var target: int = int(duck.target)
			if _infested(field, target):
				var plot: Dictionary = field[target]
				plot["pests"] = false
				plot["pest_elapsed"] = 0.0
				plot["ripe_age"] = 0.0
				duck_clears = mini(1000000000, duck_clears + 1)
				duck.clears = mini(1000000000, int(duck.clears) + 1)
				duck.peck = 0.65
				changed = true
				duck_cleared.emit(target)
			duck["from"] = target
		if not arrived.is_empty():
			_assign_targets(flock, field, arrived)
	return changed

func _contract_crop() -> String:
	var crop: String = str(state.selected_crop)
	return crop if crop in ["russet", "golden", "giant", "radioactive", "sunburst"] else "sunburst"

func contract_offer(kind: String) -> Dictionary:
	var target: int = mini(1600, 400 + (contract_completed / 3) * 100) if kind == "bulk" else mini(3, 1 + contract_completed / 5)
	var crop: String = _contract_crop()
	var held: int = int(state.storage[crop]) if kind == "bulk" else 0
	if kind == "mutation":
		for crate in state.mutations:
			if str(crate.crop) == crop:
				held += int(crate.count)
	return {"target": target, "crop": crop, "held": held, "premium": 50 if kind == "mutation" else 25,
		"base_quote": float(state.market[crop].sell) * target * (1.5 if kind == "mutation" else 1.25)}

func choose_contract(kind: String) -> String:
	if int(state.current_island) != 2 or not state.island2_unlocked:
		return state._finish("Visit the Golden Shores buyer.")
	if kind not in ["bulk", "mutation"]:
		return state._finish("Choose a harvest shipment or a mutation commission.")
	if not contract.is_empty():
		return state._finish("Finish your current order first. No deadline.")
	if contract_cooldown > 0.0:
		return state._finish("The next buyer arrives in %.0f seconds." % ceilf(contract_cooldown))
	var target: int = int(contract_offer(kind).target)
	contract = {"kind": kind, "crop": _contract_crop(), "target": target, "delivered": 0, "credit": 0.0}
	return state._finish("Order booked · %s %s%s · +%d%%" % [state.format_number(target), str(state.CROPS[contract.crop].name), " mutations" if kind == "mutation" else "", 50 if kind == "mutation" else 25])

func _contract_held() -> int:
	if contract.is_empty():
		return 0
	if str(contract.kind) == "bulk":
		return int(state.storage[contract.crop])
	var count: int = 0
	for crate in state.mutations:
		if str(crate.crop) == str(contract.crop):
			count += int(crate.count)
	return count

func deliver_contract() -> String:
	if int(state.current_island) != 2 or not state.island2_unlocked:
		return state._finish("Visit the Golden Shores buyer to deliver a contract.")
	if contract.is_empty():
		return state._finish("Choose a buyer contract first.")
	var remaining: int = int(contract.target) - int(contract.delivered)
	var amount: int = mini(remaining, _contract_held())
	if amount <= 0:
		return state._finish("Needed: %s%s. Harvest more first." % [str(state.CROPS[contract.crop].name), " mutations" if str(contract.kind) == "mutation" else ""])
	var value: float = 0.0
	var crop: String = str(contract.crop)
	if str(contract.kind) == "bulk":
		state.storage[crop] -= amount
		value = float(amount) * float(state.market[crop].sell)
	else:
		var left: int = amount
		# Consume exactly the delivered mutations, retaining each other crate and
		# its discovery. Rare crops are never recreated as ordinary potatoes.
		for index in range(state.mutations.size() - 1, -1, -1):
			var crate: Dictionary = state.mutations[index]
			if str(crate.crop) != crop or left <= 0:
				continue
			var take: int = mini(left, int(crate.count))
			value += float(take) * float(crate.multiplier) * float(state.market[crop].sell)
			crate.count = int(crate.count) - take
			left -= take
			if int(crate.count) == 0:
				state.mutations.remove_at(index)
	contract.delivered = int(contract.delivered) + amount
	contract.credit = minf(state.MAX_MONEY, float(contract.credit) + value * (1.5 if str(contract.kind) == "mutation" else 1.25))
	if int(contract.delivered) < int(contract.target):
		return state._finish("Shipped %s / %s · %s banked" % [state.format_number(contract.delivered), state.format_number(contract.target), state.money(contract.credit)])
	var earnings: float = float(contract.credit)
	# Clear the order before any signal callback can request another payment.
	contract = {}
	contract_completed = mini(1000000, contract_completed + 1)
	contract_cooldown = CONTRACT_COOLDOWN
	state.coins = minf(state.MAX_MONEY, float(state.coins) + earnings)
	state._record_sales(earnings)
	return state._finish("ORDER COMPLETE! +%s · Next buyer in 25s" % state.money(earnings))

func charge_furnace(crop: String = "icecap") -> String:
	if int(state.current_island) != 3 or not state.island3_unlocked:
		return state._finish("The potato furnace is in Frosthollow.")
	if crop != "icecap":
		return state._finish("The Frosthollow furnace burns 25 Icecap potatoes per burst.")
	if furnace_remaining > 0.0 or furnace_cooldown > 0.0:
		return state._finish("The furnace is still hot. It can fire again in %.0f seconds." % ceilf(furnace_cooldown))
	if int(state.storage.icecap) < FURNACE_FUEL:
		return state._finish("Hold 25 spare Icecap potatoes to fuel the furnace.")
	state.storage.icecap -= FURNACE_FUEL
	furnace_burned = mini(1000000000, furnace_burned + FURNACE_FUEL)
	furnace_remaining = FURNACE_DURATION
	furnace_cooldown = FURNACE_COOLDOWN
	return state._finish("FURNACE BURST! 20s · 2.5× growth · 3× processing")

func growth_speed_multiplier() -> float:
	return 2.5 if furnace_remaining > 0.0 and int(state.current_island) == 3 else 1.0

func processing_speed_multiplier() -> float:
	return 3.0 if furnace_remaining > 0.0 and int(state.current_island) == 3 else 1.0

func processing_time(delta: float) -> float:
	if not is_finite(delta) or delta <= 0.0:
		return 0.0
	return delta + (processing_speed_multiplier() - 1.0) * minf(delta, furnace_remaining)

func next_boundary() -> float:
	var boundary: float = 3600.0
	if furnace_remaining > 0.0:
		boundary = minf(boundary, furnace_remaining)
	if duck_count() > 0:
		for duck in _active_ducks():
			boundary = minf(boundary, maxf(0.000001, duck_interval() - float(duck.elapsed)))
	return boundary

func update(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	var was_burning: bool = furnace_remaining > 0.0
	furnace_remaining = maxf(0.0, furnace_remaining - delta)
	furnace_cooldown = maxf(0.0, furnace_cooldown - delta)
	contract_cooldown = maxf(0.0, contract_cooldown - delta)
	var changed: bool = _update_ducks(delta)
	changed = changed or (was_burning and furnace_remaining == 0.0)
	if changed:
		state.changed.emit()
	return changed

func info() -> Dictionary:
	var island: int = int(state.current_island)
	var title: String = "DUCK PATROL" if island == 1 else ("BUYER CONTRACTS" if island == 2 else "POTATO FURNACE")
	var description: String = "More ducks. Faster patrols. Fewer pests."
	if island == 2:
		description = "Big harvest or rare finds? Pick your payday."
	elif island == 3:
		description = "25 Icecaps → 20s of heat. Time it with a surge."
	var ducks: Array[Dictionary] = []
	var flock: Array = _current_ducks()
	for index in range(flock.size()):
		var duck: Dictionary = flock[index].duplicate()
		duck["id"] = index
		duck["progress"] = clampf(float(duck.elapsed) / duck_interval(), 0.0, 1.0)
		duck["trained"] = index < duck_count()
		ducks.append(duck)
	var job: Dictionary = contract.duplicate(true)
	if not job.is_empty():
		job["crop_name"] = str(state.CROPS[job.crop].name)
		job["held"] = _contract_held()
		job["can_deliver"] = island == 2 and int(job.held) > 0
		job["premium"] = 1.5 if str(job.kind) == "mutation" else 1.25
		job["ship_amount"] = mini(int(job.held), int(job.target) - int(job.delivered))
	return {"island": island, "title": title, "description": description,
		"duck_level": duck_level, "duck_cost": duck_hire_cost(), "duck_capacity": duck_capacity(),
		"duck_count": duck_count(), "ducks": ducks, "duck_interval": duck_interval(), "duck_can_buy": duck_count() < duck_capacity() and float(state.coins) >= duck_hire_cost(),
		"duck_speed": duck_speed(), "duck_speed_cost": duck_speed_cost(), "duck_can_train": duck_count() > 0 and duck_speed() < 2 and float(state.coins) >= duck_speed_cost(),
		"duck_from": duck_from, "duck_target": duck_target, "duck_progress": clampf(duck_elapsed / duck_interval(), 0.0, 1.0), "duck_clears": duck_clears, "duck_peck": duck_peck,
		"contract": job, "contract_completed": contract_completed, "contract_cooldown": contract_cooldown,
		"contract_crop": _contract_crop(), "contract_crop_name": str(state.CROPS[_contract_crop()].name),
		"bulk_offer": contract_offer("bulk"), "mutation_offer": contract_offer("mutation"),
		"furnace_remaining": furnace_remaining, "furnace_cooldown": furnace_cooldown,
		"furnace_fuel": FURNACE_FUEL, "furnace_crop": "icecap", "furnace_held": int(state.storage.icecap),
		"can_charge": island == 3 and state.island3_unlocked and furnace_cooldown <= 0.0 and int(state.storage.icecap) >= FURNACE_FUEL,
		"furnace_growth": 2.5, "furnace_processing": 3.0}

func save_data() -> Dictionary:
	_ensure_patrols()
	return {"version": 3, "duck_level": duck_level, "duck_patrols": duck_patrols.duplicate(true),
		"duck_counts": duck_counts.duplicate(), "duck_speeds": duck_speeds.duplicate(),
		"duck_clears": duck_clears, "contract": contract.duplicate(true),
		"contract_completed": contract_completed, "contract_cooldown": contract_cooldown,
		"furnace_remaining": furnace_remaining, "furnace_cooldown": furnace_cooldown, "furnace_burned": furnace_burned}

func valid_data(data: Variant) -> bool:
	if not data is Dictionary or not _number(data.get("version"), 1, 3, true):
		return false
	for key in ["duck_level", "duck_clears", "contract_completed", "furnace_burned"]:
		var limit: int = {"duck_level": 3, "duck_clears": 1000000000, "contract_completed": 1000000, "furnace_burned": 1000000000}[key]
		if not _number(data.get(key), 0, limit, true):
			return false
	var interval: float = DUCK_INTERVALS[maxi(0, int(data.duck_level) - 1)]
	if int(data.version) == 3:
		for key: String in ["duck_counts", "duck_speeds"]:
			if not data.get(key) is Dictionary or data[key].size() != state.island_plots.size():
				return false
		for island in state.island_plots:
			if not _number(data.duck_counts.get(island), 0, int(island), true) or not _number(data.duck_speeds.get(island), 0, 2, true):
				return false
			if int(data.duck_counts[island]) == 0 and int(data.duck_speeds[island]) > 0:
				return false
	if int(data.version) == 1:
		if not _number(data.get("duck_from"), 0, 23, true) or not _number(data.get("duck_target"), 0, 23, true) or not _number(data.get("duck_elapsed"), 0, interval):
			return false
	else:
		if not data.get("duck_patrols") is Dictionary or not data.duck_patrols.has("1") or data.duck_patrols.size() > state.island_plots.size():
			return false
		for island in data.duck_patrols:
			if not state.island_plots.has(island) or not data.duck_patrols[island] is Array or data.duck_patrols[island].size() != int(island):
				return false
			var size: int = state.island_plots[island].size()
			if int(data.version) == 3:
				interval = DUCK_INTERVALS[int(data.duck_speeds[island])]
			var targets: Array[int] = []
			for duck in data.duck_patrols[island]:
				if not duck is Dictionary or not _number(duck.get("from"), 0, size - 1, true) or not _number(duck.get("target"), 0, size - 1, true):
					return false
				if not _number(duck.get("elapsed"), 0, interval) or not _number(duck.get("peck"), 0, 0.65) or not _number(duck.get("clears"), 0, 1000000000, true):
					return false
				var owned: int = int(data.duck_counts[island]) if int(data.version) == 3 else int(island)
				if targets.size() < owned and targets.has(int(duck.target)):
					return false
				targets.append(int(duck.target))
	for key in {"contract_cooldown": CONTRACT_COOLDOWN, "furnace_remaining": FURNACE_DURATION, "furnace_cooldown": FURNACE_COOLDOWN}:
		var limit: float = {"contract_cooldown": CONTRACT_COOLDOWN, "furnace_remaining": FURNACE_DURATION, "furnace_cooldown": FURNACE_COOLDOWN}[key]
		if not _number(data.get(key), 0.0, limit):
			return false
	if float(data.furnace_remaining) > float(data.furnace_cooldown):
		return false
	if not data.get("contract") is Dictionary:
		return false
	var job: Dictionary = data.contract
	if not job.is_empty():
		if job.get("kind") not in ["bulk", "mutation"] or job.get("crop") not in ["russet", "golden", "giant", "radioactive", "sunburst"]:
			return false
		if not _number(job.get("target"), 400 if job.kind == "bulk" else 1, 1600 if job.kind == "bulk" else 3, true):
			return false
		if not _number(job.get("delivered"), 0, int(job.target) - 1, true) or not _number(job.get("credit"), 0.0, 1.0e300):
			return false
		if (int(job.delivered) == 0) != (float(job.credit) == 0.0):
			return false
	return true

func load_data(data: Dictionary) -> bool:
	if not valid_data(data):
		return false
	for key in ["duck_clears", "contract_completed", "furnace_burned"]:
		set(key, int(data[key]))
	for key in ["contract_cooldown", "furnace_remaining", "furnace_cooldown"]:
		set(key, float(data[key]))
	duck_patrols = data.duck_patrols.duplicate(true) if int(data.version) >= 2 else {}
	duck_counts = data.duck_counts.duplicate() if int(data.version) == 3 else {}
	duck_speeds = data.duck_speeds.duplicate() if int(data.version) == 3 else {}
	_ensure_patrols()
	if int(data.version) < 3:
		# Existing players keep every duck and the speed they already paid for.
		for island in state.island_plots:
			duck_counts[island] = int(island) if int(data.duck_level) > 0 else 0
			duck_speeds[island] = maxi(0, int(data.duck_level) - 1)
	for flock in duck_patrols.values():
		for duck in flock:
			for key in ["from", "target", "clears"]:
				duck[key] = int(duck[key])
			for key in ["elapsed", "peck"]:
				duck[key] = float(duck[key])
	if int(data.version) == 1:
		duck_patrols["1"][0] = {"from": int(data.duck_from), "target": int(data.duck_target), "elapsed": float(data.duck_elapsed), "peck": 0.0, "clears": int(data.duck_clears)}
	contract = data.contract.duplicate(true)
	return true

func _number(value: Variant, minimum: float, maximum: float, integer_only: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and (not integer_only or float(value) == floorf(float(value)))
