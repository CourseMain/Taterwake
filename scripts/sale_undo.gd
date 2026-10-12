extends RefCounted
## A short-lived reversal of one committed sale, never a whole-farm rollback.
const SECONDS: float = 3.0
var _before: Dictionary
var _after: Dictionary
var _entries: Array
var _start: int
var _deadline: int = 0

func _init(farm: Node) -> void:
	_before = _capture(farm)
	_start = farm.ledger.entry_count()

func _capture(farm: Node) -> Dictionary:
	return {"stock":farm.storage.duplicate(true), "held":farm.trading.held.duplicate(true),
		"year":farm.season_clock.year, "season":farm.season_clock.season,
		"sales":farm.lifetime_sales, "quests":farm.quest_progress.duplicate(true),
		"help":farm.farm_help.data.duplicate(true), "tutorial":farm.tutorial_progress.duplicate(true), "oddities":farm.pedlar.data.oddities.duplicate(true)}

func commit(farm: Node) -> bool:
	_entries = farm.ledger.entries.slice(_start)
	if _entries.is_empty() or not _entries.all(func(entry): return entry.category == "sales"):
		return false
	_after = _capture(farm)
	_deadline = Time.get_ticks_msec() + int(SECONDS * 1000)
	return true

func available(farm: Node) -> bool:
	return _deadline > Time.get_ticks_msec() and not farm.run_over and farm.season_clock.year == _before.year and farm.season_clock.season == _before.season

func remaining(farm: Node) -> float:
	return maxf(0, (_deadline - Time.get_ticks_msec()) / 1000.0) if available(farm) else 0.0

func undo(farm: Node) -> bool:
	if not available(farm): return false
	var journal: Dictionary = farm.ledger.save_data()
	if journal.entries.slice(_start, _start + _entries.size()) != _entries: return false
	journal.entries = journal.entries.slice(0, _start) + journal.entries.slice(_start + _entries.size())
	farm.ledger.load_data(journal)
	_restore_lots(farm.storage, _before.stock, _after.stock)
	_restore_lots(farm.trading.held, _before.held, _after.held)
	farm.lifetime_sales = _before.sales if farm.lifetime_sales == _after.sales else farm.lifetime_sales - (float(_after.sales) - float(_before.sales))
	for key in _before.quests:
		farm.quest_progress[key] = _before.quests[key] if farm.quest_progress[key] == _after.quests[key] else farm.quest_progress[key] - (float(_after.quests[key]) - float(_before.quests[key]))
	for index in range(mini(_before.oddities.size(), farm.pedlar.data.oddities.size())):
		_restore_fields(farm.pedlar.data.oddities[index], _before.oddities[index], _after.oddities[index])
	_restore_fields(farm.farm_help.data, _before.help, _after.help)
	_restore_fields(farm.tutorial_progress, _before.tutorial, _after.tutorial)
	_deadline = 0
	farm.changed.emit()
	return true

func _restore_lots(stock: Dictionary, before: Dictionary, after: Dictionary) -> void:
	for crop in before:
		for grade in before[crop]:
			for score in before[crop][grade]:
				var quantity: int = int(before[crop][grade][score]) - int(after[crop][grade].get(score, 0))
				if quantity > 0:
					stock[crop][grade][score] = int(stock[crop][grade].get(score, 0)) + quantity

func _restore_fields(current: Dictionary, before: Dictionary, after: Dictionary) -> void:
	for key in before:
		if before[key] != after[key] and current.get(key) == after[key]: current[key] = before[key]
