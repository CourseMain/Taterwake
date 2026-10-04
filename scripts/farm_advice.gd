extends RefCounted
## Estimates and field directions only. Never posts money or changes a policy.
const YEAR_ONE: String = "The bills are 104,000 a year: mortgage and land 60,000, living 32,000, upkeep 12,000. Twelve beds of Russet make about 45,000 at best. You need more beds, a dearer potato, and no empty beds in Spring or Summer."

static func spring(farm) -> Dictionary:
	var beds: int = 0
	var tonnes: int = 0
	for plot: Dictionary in farm.plots:
		if not plot.unlocked: continue
		beds += 1
		var example: Dictionary = {"crop": farm.selected_crop, "field": plot.field, "bed": plot.bed}
		tonnes += farm.Land.yield_for(example) * 2
	var crop: Dictionary = farm.CropTable.CROPS[farm.selected_crop]
	var net: float = tonnes * float(crop.base) * farm.Quality.MULTIPLIER.Table - beds * 2 * float(crop.seed)
	var bills: float = farm.ledger.fixed_cost_total()
	return {"beds": beds, "tonnes": tonnes, "net": net, "bills": bills, "short": maxf(0, bills - net)}

static func locked(farm, index: int) -> String:
	var field: String = farm.Land.id(index)
	if field == "home": return "Home bed · open 12 more at the Tools shed, " + farm.format_number(farm.FIELD_EXPANSION_COST)
	if not farm.Land.active(farm, field):
		return "%s · lease at the Winter accounts, %s a year" % [farm.Land.NAMES[field], farm.format_number(farm.Land.RENTS[field])]
	return "%s bed · open 12 more at the Tools shed, %s" % [farm.Land.NAMES[field], farm.format_number(farm.FIELD_EXPANSION_COST)]

static func seed_capacity(farm, crop: String) -> int:
	var room: int = maxi(0, farm.MAX_INVENTORY - int(farm.seed_inventory[crop]) - int(farm.trading.kept_seed[crop]))
	return mini(room, farm.stock_count(crop, "Table") + farm.stock_count(crop, "Standard"))
