extends RefCounted
## Saved, optional help. No action locks and no paused simulation.
const TIP_IDS: Array[String] = ["repeat", "pests", "stocks", "taxes", "debt", "tools", "ducks", "builds"]
var data: Dictionary = fresh()

static func fresh() -> Dictionary:
	return {"enabled": false, "hidden": false, "dismissed": [], "independent": 0,
		"island": 1, "plot": -1, "crop": "russet", "pest_phase": 0, "protected": [],
		"practice_remaining": 0.0, "practice_crop": "russet", "practice_tried": false}

func enable() -> void:
	data.enabled = true

func dismiss(id: String) -> void:
	if id in TIP_IDS and id not in data.dismissed: data.dismissed.append(id)

func unseen(id: String) -> bool:
	return id not in data.dismissed

func observe_plot(farm: Node, index: int, action: String, harvested: int = 0) -> void:
	if not data.enabled or farm.tutorial_active or int(data.independent) >= 4: return
	if action == "plant" and int(data.independent) < 3:
		if int(data.independent) > 0 and (int(data.island) != farm.current_island or int(data.plot) != index):
			var tracked: Dictionary = farm.island_plots[str(int(data.island))][int(data.plot)]
			if int(tracked.stage) > 0: return
		data.independent = 1
		data.island = farm.current_island
		data.plot = index
		data.crop = farm.selected_crop
	elif int(data.island) == farm.current_island and int(data.plot) == index:
		if action == "water" and int(data.independent) == 1: data.independent = 2
		elif action == "harvest" and harvested > 0 and int(data.independent) == 2: data.independent = 3

func observe_sale(farm: Node, crop: String) -> void:
	if not data.enabled or farm.tutorial_active: return
	if int(data.independent) == 3 and crop == str(data.crop):
		data.independent = 4
		dismiss("repeat")
	if float(data.practice_remaining) > 0.0 and crop == str(data.practice_crop):
		dismiss("stocks")
		data.practice_remaining = 0.0
		farm._refresh_market(false)

func can_infest() -> bool:
	return not data.enabled or int(data.pest_phase) != 1

func capture_pests(farm: Node) -> void:
	if not data.enabled or farm.tutorial_active or int(data.pest_phase) != 0: return
	for island: String in farm.island_plots:
		var field: Array = farm.island_plots[island]
		for index: int in range(field.size()):
			if field[index].pests and int(field[index].stage) > 0:
				data.protected.append("%s:%d" % [island, index])
	if not data.protected.is_empty(): data.pest_phase = 1

func protected_pest(farm: Node, plot: Dictionary) -> bool:
	if int(data.pest_phase) != 1: return false
	for key: String in data.protected:
		var field: Array = farm.island_plots[key.get_slice(":", 0)]
		if is_same(field[int(key.get_slice(":", 1))], plot): return true
	return false

func refresh_pests(farm: Node) -> void:
	if int(data.pest_phase) != 1: return
	var remaining: Array = []
	for key: String in data.protected:
		var plot: Dictionary = farm.island_plots[key.get_slice(":", 0)][int(key.get_slice(":", 1))]
		if plot.pests and int(plot.stage) > 0: remaining.append(key)
	data.protected = remaining
	if remaining.is_empty():
		data.pest_phase = 2
		dismiss("pests")

func practice_available(farm: Node) -> bool:
	return data.enabled and unseen("stocks") and int(data.independent) == 4 and farm.current_island == 1 and not farm.tutorial_active and not farm.run_over and not farm.rocket_pending and float(data.practice_remaining) <= 0.0 and farm.surge_remaining <= 0.0 and farm.natural_remaining <= 0.0 and farm.surge_timer > 10.0 and int(farm.storage[farm.selected_crop]) > 0 and float(farm.market[farm.selected_crop].sell) < float(farm.CROPS[farm.selected_crop].base) * 2.0

func start_practice(farm: Node) -> bool:
	if not practice_available(farm): return false
	data.practice_crop = farm.selected_crop
	data.practice_remaining = 10.0
	data.practice_tried = true
	farm._refresh_market(false)
	farm.changed.emit()
	return true

func tick(farm: Node, delta: float) -> bool:
	refresh_pests(farm)
	if float(data.practice_remaining) <= 0.0: return false
	data.practice_remaining = maxf(0.0, float(data.practice_remaining) - delta)
	if farm.current_island != 1 or farm.surge_remaining > 0.0 or farm.natural_remaining > 0.0:
		data.practice_remaining = 0.0
	if float(data.practice_remaining) < 0.000001:
		data.practice_remaining = 0.0
		farm._refresh_market(false)
	return true

func tip(farm: Node) -> Dictionary:
	if not data.enabled or data.hidden or farm.tutorial_active or farm.run_over or farm.rocket_pending or farm.climate.data.intro_pending: return {}
	if int(data.pest_phase) == 1 and unseen("pests"):
		return _tip("pests", "Pests on your potatoes", "Press 5, then click an infested bed. This first group cannot damage crops. Later pests eat a third every 5 seconds.", "Equip sprayer [5]", "tool:pest")
	if float(data.practice_remaining) > 0.0 and unseen("stocks"):
		var crop: String = str(data.practice_crop)
		return _tip("stocks", "Practice boom · %ds" % int(ceil(float(data.practice_remaining))), "%s: +100%% · %s each. Sell from storage before the price returns. Seeds cost more too." % [str(farm.CROPS[crop].name), farm.money(farm.market[crop].sell)], "Sell practice crop", "sell:" + crop + ":-1")
	if farm.coins < 0.0 and unseen("debt"):
		return _tip("debt", "Debt is still playable", "You can keep farming below zero. This run ends only below %s. Sell held crops to recover." % farm.money(farm.bankruptcy_limit()), "View taxes", "taxes")
	if unseen("taxes") and (farm.surge_timer <= 30.0 or int(farm.blind_cycle.booms) > 0):
		return _tip("taxes", "Keep money for taxes", "After 3 major booms, the last 10-second selling window ends and tax is deducted. Forecast: %s. Debt is allowed down to %s." % [farm.money(farm.blind_info().tax), farm.money(farm.bankruptcy_limit())], "View forecast", "taxes")
	if int(data.independent) < 4:
		if unseen("repeat"):
			return _tip("repeat", "The farm is yours", "Try growing and selling another crop on your own. All tools and shops are open. H brings up help whenever you need it.", "Go farming", "dismiss")
		return {}
	if practice_available(farm):
		return _tip("stocks", "Try a small stock boom", "You have crops ready to sell. Try +100% for 10 seconds, then sell before it ends. This practice does not count toward tax.", "Try again · 10 seconds" if data.practice_tried else "Start practice boom", "practice")
	if unseen("ducks") and is_instance_valid(farm.activity_system) and farm.activity_system.duck_count() == 0 and farm.coins >= farm.activity_system.duck_hire_cost():
		return _tip("ducks", "A helper you can afford", "Duck Patrol can clear pests while you farm. Hiring costs %s. Keep enough for seeds and taxes." % farm.money(farm.activity_system.duck_hire_cost()), "Browse Duck Patrol", "duck_patrol")
	if unseen("tools"):
		for tool: String in ["hoe", "water", "harvest"]:
			var rank: int = int(farm.tools[tool])
			if rank < 3 and (rank < 2 or farm.current_island == 3) and farm.coins >= float(farm.TOOL_COSTS[tool][rank]):
				return _tip("tools", "Work more beds per click", "A %s upgrade is within reach at %s. Click the toolsmith or press U to compare its area and cost." % [tool, farm.money(farm.TOOL_COSTS[tool][rank])], "Browse upgrades [U]", "tools")
	if unseen("builds") and is_instance_valid(farm.build_system):
		if farm.build_system.build_crates > 0:
			return _tip("builds", "You found a Build Crate", "Open it from Inventory for a build card. Then compare your unlocked builds with C. Opening a shop does not spend coins.", "Open inventory [I]", "inventory")
		if farm.build_system.active == "farmer" and farm.build_system.cooldown <= 0.0 and int(farm.storage[farm.selected_crop]) >= 10:
			return _tip("builds", "Use your Farmer ability", "In Builds [C], trade 10 held potatoes for 30 seconds of better harvests and growth. Compare that benefit with selling them.", "Inspect Farmer [C]", "builds")
	return {}

func _tip(id: String, title: String, body: String, label: String, action: String) -> Dictionary:
	return {"id": id, "title": title, "body": body, "label": label, "action": action}

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key: String in ["enabled", "hidden", "practice_tried"]:
		if not raw.get(key) is bool: return false
	for entry: Array in [["independent", 0, 4], ["island", 1, 3], ["plot", -1, 79], ["pest_phase", 0, 2], ["practice_remaining", 0, 10]]:
		var value: Variant = raw.get(entry[0])
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < entry[1] or float(value) > entry[2]: return false
		if entry[0] != "practice_remaining" and float(value) != floor(float(value)): return false
	for key: String in ["crop", "practice_crop"]:
		if raw.get(key) not in ["russet", "golden", "giant", "radioactive", "sunburst", "icecap"]: return false
	if not raw.get("dismissed") is Array or raw.dismissed.size() > TIP_IDS.size(): return false
	for id: Variant in raw.dismissed:
		if id not in TIP_IDS: return false
	if not raw.get("protected") is Array or raw.protected.size() > 152: return false
	for key: Variant in raw.protected:
		if not key is String or key.get_slice_count(":") != 2: return false
		var island: String = key.get_slice(":", 0)
		var plot: String = key.get_slice(":", 1)
		if island not in ["1", "2", "3"] or not plot.is_valid_int() or int(plot) < 0 or int(plot) >= int({"1": 24, "2": 48, "3": 80}[island]): return false
	return true
