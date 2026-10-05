extends RefCounted
## Saved, optional help. No action locks and no paused simulation.
const TIP_IDS: Array[String] = ["repeat", "pests", "tools", "ducks"]
var data: Dictionary = fresh()

static func fresh() -> Dictionary:
	return {"enabled": false, "hidden": false, "dismissed": [], "independent": 0,
		"plot": -1, "crop": "russet", "pest_phase": 0, "protected": []}

func enable() -> void:
	data.enabled = true

func dismiss(id: String) -> void:
	if id in TIP_IDS and id not in data.dismissed: data.dismissed.append(id)

func unseen(id: String) -> bool:
	return id not in data.dismissed

func observe_plot(farm: Node, index: int, action: String, harvested: int = 0) -> void:
	if not data.enabled or farm.tutorial_active or int(data.independent) >= 4: return
	if action == "plant" and int(data.independent) < 3:
		if int(data.independent) > 0 and int(data.plot) != index:
			var tracked: Dictionary = farm.plots[int(data.plot)]
			if int(tracked.stage) > 0: return
		data.independent = 1
		data.plot = index
		data.crop = farm.selected_crop
	elif int(data.plot) == index:
		if action == "water" and int(data.independent) == 1: data.independent = 2
		elif action == "harvest" and harvested > 0 and int(data.independent) == 2: data.independent = 3

func observe_sale(farm: Node, crop: String) -> void:
	if not data.enabled or farm.tutorial_active: return
	if int(data.independent) == 3 and crop == str(data.crop):
		data.independent = 4
		dismiss("repeat")

func can_infest() -> bool:
	return not data.enabled or int(data.pest_phase) != 1

func capture_pests(farm: Node) -> void:
	if not data.enabled or farm.tutorial_active or int(data.pest_phase) != 0: return
	var field: Array = farm.plots
	for index: int in range(field.size()):
		if field[index].pests and int(field[index].stage) > 0:
			data.protected.append(str(index))
	if not data.protected.is_empty(): data.pest_phase = 1

func protected_pest(farm: Node, plot: Dictionary) -> bool:
	if int(data.pest_phase) != 1: return false
	for key: String in data.protected:
		var field: Array = farm.plots
		if is_same(field[int(key)], plot): return true
	return false

func refresh_pests(farm: Node) -> void:
	if int(data.pest_phase) != 1: return
	var remaining: Array = []
	for key: String in data.protected:
		var plot: Dictionary = farm.plots[int(key)]
		if plot.pests and int(plot.stage) > 0: remaining.append(key)
	data.protected = remaining
	if remaining.is_empty():
		data.pest_phase = 2
		dismiss("pests")

func tip(farm: Node) -> Dictionary:
	if not data.enabled or data.hidden or farm.tutorial_active or farm.run_over: return {}
	if int(data.pest_phase) == 1 and unseen("pests"):
		return _tip("pests", "Pests on your potatoes", "Tap the sprayer, then the bed with bugs.", "Tap the sprayer", "tool:pest")

	if int(data.independent) < 4:
		if unseen("repeat"):
			return _tip("repeat", "Next harvest", "Hoe → plant → water → harvest → sell.", "Go farming", "dismiss")
		return {}
	if unseen("ducks") and is_instance_valid(farm.activity_system) and farm.activity_system.duck_count() == 0 and farm.coins >= farm.activity_system.duck_hire_cost():
		return _tip("ducks", "A helper you can afford", "Duck Patrol can clear pests while you farm. Hiring costs %s. Keep enough for seeds." % farm.money(farm.activity_system.duck_hire_cost()), "Got it", "dismiss")
	if unseen("tools"):
		for tool: String in ["hoe", "water", "harvest"]:
			var rank: int = int(farm.tools[tool])
			if rank < 3 and farm.coins >= float(farm.TOOL_COSTS[tool][rank]):
				return _tip("tools", "Work more beds per click", "A %s upgrade costs %s at the Tools shed." % [tool, farm.money(farm.TOOL_COSTS[tool][rank])], "Got it", "dismiss")
	return {}

func _tip(id: String, title: String, body: String, label: String, action: String) -> Dictionary:
	return {"id": id, "title": title, "body": body, "label": label, "action": action}

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key: String in ["enabled", "hidden"]:
		if not raw.get(key) is bool: return false
	for entry: Array in [["independent", 0, 4], ["plot", -1, 71], ["pest_phase", 0, 2]]:
		var value: Variant = raw.get(entry[0])
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < entry[1] or float(value) > entry[2]: return false
		if float(value) != floor(float(value)): return false
	for key: String in ["crop"]:
		if raw.get(key) not in ["russet", "golden", "giant", "sunburst", "icecap"]: return false
	if not raw.get("dismissed") is Array or raw.dismissed.size() > TIP_IDS.size(): return false
	for id: Variant in raw.dismissed:
		if id not in TIP_IDS: return false
	if not raw.get("protected") is Array or raw.protected.size() > 72: return false
	for key: Variant in raw.protected:
		if not key is String or not key.is_valid_int() or int(key) < 0 or int(key) >= 72: return false
	return true
