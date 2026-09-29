extends RefCounted
const Balance = preload("res://scripts/balance.gd")
const Table = preload("res://scripts/crop_table.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const Rules = preload("res://scripts/save_validation.gd")
const GRADES: Array[String] = ["Table", "Standard", "Feed"]
const MULTIPLIER = Balance.GRADE_MULTIPLIER
const CAUSES := {"pests":"Pests", "drought":"Drought", "flood":"Flood", "freeze":"Freeze", "storm":"Lightning", "dry":"Lack of water", "late":"Late harvest"}
static func grade(score: int) -> String:
	return "Table" if score >= 80 else ("Standard" if score >= 40 else "Feed")
static func reset(plot: Dictionary) -> void:
	plot.quality = 100
	plot.quality_ripe_age = 0.0
	plot.quality_losses = {}
	plot.quality_time = {}
	plot.quality_hits = []
static func deduct(farm, index: int, cause: String, points: int, once: bool = false) -> void:
	var plot: Dictionary = farm.plots[index]
	if int(plot.stage) == 0 or farm.tutorial_active: return
	var token: String = "%d/%d/%s" % [farm.season_clock.year, farm.season_clock.season, cause]
	if once:
		if token in plot.quality_hits: return
		plot.quality_hits.append(token)
	var exposed: int = roundi(points * 9.0 / Table.total_tolerance(plot.crop))
	var reduction: float = Protection.REDUCTION[Protection.level(farm, cause, index)]
	var amount: int = mini(int(plot.quality), Protection.loss(exposed, reduction))
	plot.quality -= amount
	plot.quality_losses[cause] = int(plot.quality_losses.get(cause, 0)) + amount
static func timed(farm, index: int, cause: String, seconds: float, points: int) -> void:
	var plot: Dictionary = farm.plots[index]
	plot.quality_time[cause] = float(plot.quality_time.get(cause, 0)) + seconds
	while float(plot.quality_time[cause]) >= 10.0 - 0.000001:
		plot.quality_time[cause] = maxf(0, float(plot.quality_time[cause]) - 10)
		deduct(farm, index, cause, points)
static func ripe(farm, index: int, delta: float) -> void:
	var plot: Dictionary = farm.plots[index]
	var before: float = float(plot.quality_ripe_age)
	plot.quality_ripe_age = minf(1e9, before + delta)
	timed(farm, index, "late", maxf(0, float(plot.quality_ripe_age) - 30) - maxf(0, before - 30), 5)
static func update(farm, index: int, delta: float) -> void:
	var plot: Dictionary = farm.plots[index]
	if int(plot.stage) == 0 or farm.tutorial_active: return
	if int(plot.stage) == 3: ripe(farm, index, delta)
	if int(plot.stage) in [1, 2] and not plot.watered: timed(farm, index, "dry", delta, 2)
	if farm.climate.data.operations.ice.has(str(index)):
		deduct(farm, index, "freeze", 15, true)
		timed(farm, index, "freeze", delta, 4)
	var event: String = farm.climate.data.event
	if farm.climate.data.phase == "active" and event in ["drought", "flood"] and float(farm.climate.data.operations.stress.get(str(index), 0)) > 0:
		if event != "drought" or float(farm.climate.data.operations.wet.get(str(index), 0)) <= 0: timed(farm, index, event, delta, 4)
static func description(plot: Dictionary) -> String:
	var word: String = grade(int(plot.get("quality", 100)))
	if word == "Table": return word
	var biggest: String = ""
	var amount: int = 0
	for cause in plot.get("quality_losses", {}):
		if int(plot.quality_losses[cause]) > amount:
			biggest = cause; amount = int(plot.quality_losses[cause])
	return word + (" · %s took it to %s" % [CAUSES[biggest], word] if not biggest.is_empty() else "")
static func valid(plot: Dictionary) -> bool:
	if not Rules.number(plot.get("quality"), 0, 100, true) or not plot.get("quality_losses") is Dictionary or not plot.get("quality_time") is Dictionary or not plot.get("quality_hits") is Array: return false
	if not Rules.number(plot.get("quality_ripe_age"), 0, 1e9): return false
	var total: int = 0
	for cause in plot.quality_losses:
		if cause not in CAUSES or not Rules.number(plot.quality_losses[cause], 0, 100, true): return false
		total += int(plot.quality_losses[cause])
	if total != 100 - int(plot.quality): return false
	for cause in plot.quality_time:
		if cause not in ["dry", "late", "freeze", "drought", "flood"] or not Rules.number(plot.quality_time[cause], 0, 9.999999): return false
	if plot.quality_hits.size() > 80: return false
	var seen: Array = []
	for hit in plot.quality_hits:
		if not hit is String or hit.length() > 24 or hit in seen: return false
		var parts: PackedStringArray = hit.split("/")
		if parts.size() != 3 or not parts[0].is_valid_int() or int(parts[0]) not in range(1, 11) or parts[1] not in ["0", "1", "2", "3"] or parts[2] not in ["freeze", "storm"]: return false
		seen.append(hit)
	return true
