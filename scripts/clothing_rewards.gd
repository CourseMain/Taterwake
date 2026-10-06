extends RefCounted
## Cosmetic collection, independent of the ledger and farm random stream.
const ITEMS := {"flower":{"name":"Mara's flower hat", "rarity":"common"}, "scarf":{"name":"Tess's scarf", "rarity":"uncommon"}, "glasses":{"name":"Nell's glasses", "rarity":"rare"}}
const PROFILE := "user://taterland_clothing.json"
static func valid(raw: Variant) -> bool:
	if not raw is Array or raw.size() > ITEMS.size(): return false
	var seen: Array = []
	for item in raw:
		if not item is String or not ITEMS.has(item) or item in seen: return false
		seen.append(item)
	return true
static func read_profile(path: String = PROFILE) -> Array:
	if not FileAccess.file_exists(path): return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if valid(data) else []
static func write_profile(items: Array, path: String = PROFILE) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(items))
static func earned(farm, item: String) -> bool:
	if item in farm.clothing_unlocked: return false
	farm.clothing_unlocked.append(item)
	if farm.clothing_profile_enabled: write_profile(farm.clothing_unlocked)
	farm.clothing_earned.emit(item)
	return true
