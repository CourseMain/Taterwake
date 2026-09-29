extends Node
## One saved flock patrols the farm for pests.
signal duck_cleared(index: int)

const Balance = preload("res://scripts/balance.gd")
const DUCK_TRAINING_COSTS: Array[float] = Balance.DUCK_TRAINING_COSTS
const DUCK_INTERVALS: Array[float] = [4.0, 3.0, 2.0]

var state
var owned_ducks: int = 0
var patrol_speed: int = 0
var duck_patrols: Array = []
var duck_level: int:
	get: return 1 + duck_speed() if duck_count() > 0 else 0
	set(value):
		owned_ducks = 2 if value > 0 else 0
		patrol_speed = clampi(value - 1, 0, 2)
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

func setup(farm_state) -> void:
	state = farm_state

func reset() -> void:
	owned_ducks = 0
	patrol_speed = 0
	duck_patrols.clear()
	duck_clears = 0

func duck_capacity() -> int:
	return 2

func duck_count() -> int:
	return owned_ducks

func duck_speed() -> int:
	return patrol_speed

func duck_interval() -> float:
	return DUCK_INTERVALS[duck_speed()]

func duck_hire_cost() -> float:
	return Balance.DUCK_HIRE_COST * (owned_ducks + 1)

func duck_speed_cost() -> float:
	return DUCK_TRAINING_COSTS[mini(1, patrol_speed)]

func _active_ducks() -> Array:
	return _current_ducks().slice(0, duck_count())

func _default_flock() -> Array[Dictionary]:
	var ducks: Array[Dictionary] = []
	var field_size: int = 24
	for index in range(2):
		var origin: int = mini(field_size - 1, index * maxi(1, field_size / 2))
		ducks.append({"from": origin, "target": (origin + 1) % field_size, "elapsed": 0.0, "peck": 0.0, "clears": 0})
	return ducks

func _current_ducks() -> Array:
	if duck_patrols.is_empty(): duck_patrols = _default_flock()
	return duck_patrols

func buy_duck() -> String:
	return hire_duck() if duck_count() == 0 else train_ducks()

func hire_duck() -> String:
	if state.run_over:
		return "Run over. Start a new farm."
	if duck_count() >= duck_capacity():
		return state._reject_purchase("Flock full: %d / %d ducks." % [duck_count(), duck_capacity()])
	var cost: float = duck_hire_cost()
	if not state.can_purchase(cost):
		return state._reject_purchase(state.purchase_refusal(cost))
	state.post_money("labour", "Hire patrol duck", -cost)
	owned_ducks += 1
	_current_ducks()
	_assign_targets(_active_ducks(), state.plots)
	return state._complete_purchase({"kind": "duck", "id": "duck_patrol", "name": "Patrol duck", "quantity": 1, "cost": cost, "total": duck_count(), "level": duck_level}, "Duck hired! %d / %d on patrol." % [duck_count(), duck_capacity()])

func train_ducks() -> String:
	if state.run_over:
		return "Run over. Start a new farm."
	if duck_count() == 0:
		return state._reject_purchase("Hire a duck first.")
	if duck_speed() >= 2:
		return state._reject_purchase("Top speed reached · 2s per bed.")
	var cost: float = duck_speed_cost()
	if not state.can_purchase(cost):
		return state._reject_purchase(state.purchase_refusal(cost))
	var previous_interval: float = duck_interval()
	state.post_money("labour", "Train patrol ducks", -cost)
	patrol_speed += 1
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
	var field: Array = state.plots
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
				plot["pest_delay"] = 0.0
				duck_clears = mini(100000, duck_clears + 1)
				duck.clears = mini(100000, int(duck.clears) + 1)
				duck.peck = 0.65
				changed = true
				duck_cleared.emit(target)
			duck["from"] = target
		if not arrived.is_empty():
			_assign_targets(flock, field, arrived)
	return changed

func next_boundary() -> float:
	var boundary: float = 3600.0
	if duck_count() > 0:
		for duck in _active_ducks():
			boundary = minf(boundary, maxf(0.000001, duck_interval() - float(duck.elapsed)))
	return boundary

func update(delta: float) -> bool:
	if state.run_over:
		return false
	if not is_finite(delta) or delta <= 0.0:
		return false
	var changed: bool = _update_ducks(delta)
	if changed:
		state.changed.emit()
	return changed

func info() -> Dictionary:
	var ducks: Array[Dictionary] = []
	var flock: Array = _current_ducks()
	for index in range(flock.size()):
		var duck: Dictionary = flock[index].duplicate()
		duck["id"] = index
		duck["progress"] = clampf(float(duck.elapsed) / duck_interval(), 0.0, 1.0)
		duck["trained"] = index < duck_count()
		ducks.append(duck)
	return {"title": "DUCK PATROL", "description": "More ducks. Faster patrols. Fewer pests.",
		"duck_level": duck_level, "duck_cost": duck_hire_cost(), "duck_capacity": duck_capacity(),
		"duck_count": duck_count(), "ducks": ducks, "duck_interval": duck_interval(), "duck_can_buy": duck_count() < duck_capacity() and state.can_purchase(duck_hire_cost()),
		"duck_speed": duck_speed(), "duck_speed_cost": duck_speed_cost(), "duck_can_train": duck_count() > 0 and duck_speed() < 2 and state.can_purchase(duck_speed_cost()),
		"duck_from": duck_from, "duck_target": duck_target, "duck_progress": clampf(duck_elapsed / duck_interval(), 0.0, 1.0), "duck_clears": duck_clears, "duck_peck": duck_peck}


func save_data() -> Dictionary:
	return {"owned_ducks": owned_ducks, "patrol_speed": patrol_speed, "duck_patrols": _current_ducks().duplicate(true), "duck_clears": duck_clears}

func valid_data(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not _number(data.get("owned_ducks"), 0, 2, true) or not _number(data.get("patrol_speed"), 0, 2, true) or not _number(data.get("duck_clears"), 0, 100000, true): return false
	if int(data.owned_ducks) == 0 and int(data.patrol_speed) > 0: return false
	if not data.get("duck_patrols") is Array or data.duck_patrols.size() != 2: return false
	var targets: Array = []
	for duck in data.duck_patrols:
		if not duck is Dictionary: return false
		for key in ["from", "target"]:
			if not _number(duck.get(key), 0, 23, true): return false
		if not _number(duck.get("elapsed"), 0, DUCK_INTERVALS[int(data.patrol_speed)]) or not _number(duck.get("peck"), 0, 0.65) or not _number(duck.get("clears"), 0, 100000, true): return false
		if targets.size() < int(data.owned_ducks) and targets.has(int(duck.target)): return false
		targets.append(int(duck.target))
	return true

func load_data(data: Dictionary) -> bool:
	if not valid_data(data): return false
	owned_ducks = int(data.owned_ducks)
	patrol_speed = int(data.patrol_speed)
	duck_clears = int(data.duck_clears)
	duck_patrols = data.duck_patrols.duplicate(true)
	for duck in duck_patrols:
		for key in ["from", "target", "clears"]: duck[key] = int(duck[key])
		for key in ["elapsed", "peck"]: duck[key] = float(duck[key])
	return true

func _number(value: Variant, minimum: float, maximum: float, integer_only: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and (not integer_only or float(value) == floorf(float(value)))
