extends RefCounted
## Variety -> grade -> quality score -> sacks. Cohorts preserve exact Winter ageing.
const Quality = preload("res://scripts/crop_quality.gd")
const Table = preload("res://scripts/crop_table.gd")
const Rules = preload("res://scripts/save_validation.gd")
static func pile(quantity: int = 0, score: int = 60) -> Dictionary:
	var result := {"Table": {}, "Standard": {}, "Feed": {}}
	if quantity > 0: result[Quality.grade(score)][str(score)] = quantity
	return result
static func empty() -> Dictionary:
	var result: Dictionary = {}
	for id in Table.IDS: result[id] = pile()
	return result
static func count_pile(value: Dictionary, grade: String = "") -> int:
	var total: int = 0
	for word in Quality.GRADES if grade.is_empty() else [grade]:
		for number in value[word].values(): total += int(number)
	return total
static func count(stock: Dictionary, id: String, grade: String = "") -> int:
	return count_pile(stock[id], grade)
static func add(stock: Dictionary, id: String, quantity: int, score: int) -> void:
	if quantity <= 0: return
	var cohort: Dictionary = stock[id][Quality.grade(score)]
	cohort[str(score)] = int(cohort.get(str(score), 0)) + quantity
static func take(stock: Dictionary, id: String, quantity: int, grade: String = "", excluded: Dictionary = {}) -> Array:
	var result: Array = []
	# Sell/use older, lower-quality sacks first within the selected grade.
	for word in ["Feed", "Standard", "Table"] if grade.is_empty() else [grade]:
		var scores: Array = stock[id][word].keys()
		scores.sort_custom(func(a, b): return int(a) < int(b))
		for score in scores:
			var reserved: int = int(excluded.get(id, {}).get(word, {}).get(score, 0))
			var amount: int = mini(quantity, int(stock[id][word][score]) - reserved)
			if amount <= 0: continue
			stock[id][word][score] -= amount
			if int(stock[id][word][score]) == 0: stock[id][word].erase(score)
			result.append({"grade":word, "score":int(score), "quantity":amount})
			quantity -= amount
	return result
static func remove_lots(stock: Dictionary, id: String, lots: Array) -> void:
	for lot in lots:
		var cohort: Dictionary = stock[id][lot.grade]
		var score: String = str(int(lot.score))
		cohort[score] -= int(lot.quantity)
		if int(cohort[score]) == 0: cohort.erase(score)
static func age(stock: Dictionary) -> Dictionary:
	var result: Dictionary = empty()
	for id in Table.IDS:
		for word in Quality.GRADES:
			for score in stock[id][word]: add(result, id, int(stock[id][word][score]), maxi(0, int(score) - 10))
	return result
static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != Table.IDS.size(): return false
	var total: int = 0
	for id in Table.IDS:
		if not raw.get(id) is Dictionary or raw[id].size() != 3: return false
		for word in Quality.GRADES:
			if not raw[id].get(word) is Dictionary or raw[id][word].size() > 101: return false
			for score in raw[id][word]:
				if not score is String or not score.is_valid_int() or str(int(score)) != score or int(score) < 0 or int(score) > 100 or Quality.grade(int(score)) != word: return false
				if not Rules.number(raw[id][word][score], 1, 100000, true): return false
				total += int(raw[id][word][score])
	return total <= 100000
static func sales(ledger, year: int) -> Dictionary:
	var result: Dictionary = {}
	for word in Quality.GRADES: result[word] = {"sacks":0, "total":0.0}
	for entry in ledger.entries:
		if int(entry.year) != year or entry.category != "sales": continue
		var parts: PackedStringArray = str(entry.label).split(" ")
		if parts.size() != 5 or parts[0] != "Sold" or parts[2] not in Quality.GRADES: continue
		result[parts[2]].sacks += int(parts[1])
		result[parts[2]].total += float(entry.amount)
	return result
