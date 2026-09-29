extends RefCounted
## Winter stores, annual storage bills and one Spring buyer order.
const Table = preload("res://scripts/crop_table.gd")
const Rules = preload("res://scripts/save_validation.gd")
const STORAGE_FEE: float = 200.0
const SPOILAGE: float = 0.10
const SHORTFALL_FEE: float = 5.0
var held: Dictionary = Table.empty_stock()
var winters: Dictionary = {}
var contract: Dictionary = {}
var settled: Dictionary = {}

func peak_price(id: String) -> float:
	return float(Table.CROPS[id].base) * float(Table.VOLATILITY[Table.CROPS[id].volatility].storage_peak_factor)

func stored_price(farm, id: String) -> float:
	var progress: float = clampf(farm.season_clock.seconds / farm.SeasonClock.SEASON_SECONDS, 0, 1) if farm.season_clock.season == 3 else 0.0
	return lerpf(float(Table.CROPS[id].base), peak_price(id), progress)

func fresh_count(farm, id: String) -> int:
	return int(farm.storage[id]) - int(held[id]) if farm.season_clock.season == 3 else int(farm.storage[id])

func clamp_stock(farm) -> void:
	for id in Table.IDS: held[id] = mini(int(held[id]), int(farm.storage[id]))

func begin_winter(farm) -> void:
	var year: String = str(farm.season_clock.year)
	if winters.has(year): return
	var report: Dictionary = {"fee": STORAGE_FEE if farm.storage_used() > 0 else 0.0, "spoiled": Table.empty_stock()}
	var remaining_loss: int = roundi(farm.storage_used() * SPOILAGE)
	var piles: Array[String] = Table.IDS.duplicate()
	# Resolve equal piles in catalogue order so the loss is deterministic.
	piles.sort_custom(func(a: String, b: String) -> bool:
		return int(farm.storage[a]) > int(farm.storage[b]) if farm.storage[a] != farm.storage[b] else Table.IDS.find(a) < Table.IDS.find(b))
	for id in piles:
		var loss: int = mini(int(farm.storage[id]), remaining_loss)
		remaining_loss -= loss
		report.spoiled[id] = loss
		farm.storage[id] = int(farm.storage[id]) - loss
		held[id] = int(farm.storage[id])
		farm.ClimateSystem.Protection.record(farm, "spoilage", id, loss, 0.0, 1.0, "Sell before Winter storage", "barn")
		if loss > 0: farm.ledger.post(farm.season_clock.year, 3, "storage", "Spoilage: %d %s sacks" % [loss, id], 0.0, true)
	if report.fee > 0: farm.post_money("storage", "Winter storage fee", -float(report.fee))
	winters[year] = report

func sell_stored(farm, id: String, quantity: int = -1) -> String:
	if farm.run_over or farm.accounts_open: return farm._finish("Return to the farm before selling stores.")
	if farm.season_clock.season != 3: return farm._finish("Winter storage prices are available at the barn during Winter only.")
	if id not in Table.IDS or quantity == 0 or quantity < -1: return farm._finish("Choose stored sacks to sell.")
	var amount: int = int(held[id]) if quantity == -1 else quantity
	if amount < 1 or amount > int(held[id]): return farm._finish("Not enough Winter stores.")
	var price: float = stored_price(farm, id)
	held[id] = int(held[id]) - amount
	farm.storage[id] = int(farm.storage[id]) - amount
	farm.post_money("sales", "Sold %d stored %s sacks" % [amount, id], price * amount)
	farm._record_sales(price * amount)
	farm._progress_quest("starter_spike", float(amount))
	farm.farm_help.observe_sale(farm, id)
	farm.sale_completed.emit({"id": id, "quantity": amount, "price": price, "total": price * amount, "owned": int(farm.storage[id])})
	return farm._finish("Sold %d stored %s sacks for %s." % [amount, id.capitalize(), farm.money(price * amount)])

func offer(year: int) -> Dictionary:
	var id: String = Table.IDS[(year - 1) % Table.IDS.size()]
	return {"year": year, "crop": id, "quantity": 20, "price": float(Table.CROPS[id].base) * 1.1}

func accept(farm) -> String:
	var year: int = farm.season_clock.year
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 0: return farm._finish("The buyer offers one order each Spring.")
	if not contract.is_empty() or settled.has(str(year)): return farm._finish("Only one buyer order per year.")
	contract = offer(year)
	return farm._finish("Order accepted: %d %s sacks, collected at the end of Autumn. Shortfalls cost %s per sack." % [contract.quantity, contract.crop.capitalize(), farm.money(SHORTFALL_FEE)])

func settle(farm) -> void:
	if contract.is_empty(): return
	var id: String = contract.crop
	var delivered: int = mini(int(farm.storage[id]), int(contract.quantity))
	var missing: int = int(contract.quantity) - delivered
	farm.storage[id] = int(farm.storage[id]) - delivered
	clamp_stock(farm)
	if delivered > 0: farm.post_money("contracts", "Buyer collected %d %s sacks" % [delivered, id], delivered * float(contract.price))
	if missing > 0: farm.post_money("contracts", "Contract shortfall: %d %s sacks" % [missing, id], -missing * SHORTFALL_FEE)
	var receipt: Dictionary = contract.duplicate()
	receipt.delivered = delivered
	receipt.shortfall = missing
	settled[str(int(contract.year))] = receipt
	contract.clear()
	farm.notified.emit("Autumn buyer: %d sacks delivered; %d short. Penalty %s." % [delivered, missing, farm.money(missing * SHORTFALL_FEE)])

func winter_text(farm) -> String:
	var report: Dictionary = winters.get(str(farm.season_clock.year), {})
	if report.is_empty(): return ""
	var loss: int = 0
	for count in report.spoiled.values(): loss += int(count)
	return "Storage fee %s · Spoilage %d sacks (10%% of the barn, rounded to nearest; largest pile first)." % [farm.money(report.fee), loss]

func save_data() -> Dictionary:
	return {"held": held.duplicate(), "winters": winters.duplicate(true), "contract": contract.duplicate(), "settled": settled.duplicate(true)}

func load_data(raw: Dictionary) -> void:
	held = raw.held.duplicate()
	winters = raw.winters.duplicate(true)
	contract = raw.contract.duplicate()
	settled = raw.settled.duplicate(true)

func valid(raw: Variant, saved: Dictionary) -> bool:
	if not raw is Dictionary or raw.size() != 4: return false
	if not raw.get("held") is Dictionary or raw.held.size() != Table.IDS.size(): return false
	for id in Table.IDS:
		if not Rules.number(raw.held.get(id), 0, saved.storage[id], true): return false
		if int(saved.season_clock.season) != 3 and int(raw.held[id]) != 0: return false
	for kind in ["winters", "settled"]:
		if not raw.get(kind) is Dictionary or raw[kind].size() > 10: return false
		for key in raw[kind]:
			if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > int(saved.season_clock.year): return false
			if int(key) == int(saved.season_clock.year) and int(saved.season_clock.season) < 3: return false
			var row: Variant = raw[kind][key]
			if not row is Dictionary: return false
			if kind == "winters":
				if row.size() != 2 or row.get("fee") not in [0.0, STORAGE_FEE] or not row.get("spoiled") is Dictionary or row.spoiled.size() != Table.IDS.size(): return false
				for id in Table.IDS:
					if not Rules.number(row.spoiled.get(id), 0, 100000, true): return false
					if int(row.spoiled[id]) > 0:
						if row.fee != STORAGE_FEE or not _posting(saved, int(key), 3, "storage", "Spoilage: %d %s sacks" % [int(row.spoiled[id]), id], 0.0): return false
				if row.fee > 0 and not _posting(saved, int(key), 3, "storage", "Winter storage fee", -STORAGE_FEE): return false
			else:
				if not valid_order(row, int(key), true): return false
				if int(row.delivered) > 0 and not _posting(saved, int(key), 3, "contracts", "Buyer collected %d %s sacks" % [int(row.delivered), row.crop], row.delivered * row.price): return false
				if int(row.shortfall) > 0 and not _posting(saved, int(key), 3, "contracts", "Contract shortfall: %d %s sacks" % [int(row.shortfall), row.crop], -row.shortfall * SHORTFALL_FEE): return false
	for entry in saved.ledger.entries:
		if entry.category != "storage": continue
		var report: Dictionary = raw.winters.get(str(int(entry.year)), {})
		if entry.label == "Winter storage fee":
			if report.is_empty() or report.fee != STORAGE_FEE: return false
		elif str(entry.label).begins_with("Spoilage: "):
			if report.is_empty(): return false
			var matches: bool = false
			for id in Table.IDS:
				if int(report.spoiled[id]) > 0 and entry.label == "Spoilage: %d %s sacks" % [int(report.spoiled[id]), id]: matches = true
			if not matches: return false
	if not raw.get("contract") is Dictionary: return false
	if not raw.contract.is_empty():
		if int(saved.season_clock.season) >= 3 or raw.settled.has(str(saved.season_clock.year)): return false
		if not valid_order(raw.contract, int(saved.season_clock.year), false): return false
	return true

func valid_order(row: Dictionary, year: int, complete: bool) -> bool:
	if row.size() != (6 if complete else 4): return false
	var expected: Dictionary = offer(year)
	for key in expected:
		if row.get(key) != expected[key]: return false
	if complete:
		if not Rules.number(row.get("delivered"), 0, expected.quantity, true) or not Rules.number(row.get("shortfall"), 0, expected.quantity, true): return false
		if int(row.delivered) + int(row.shortfall) != int(expected.quantity): return false
	return true

func _posting(saved: Dictionary, year: int, season: int, category: String, label: String, amount: float) -> bool:
	var count: int = 0
	for entry in saved.ledger.entries:
		if int(entry.year) == year and entry.category == category and entry.label == label:
			if int(entry.season) != season or not is_equal_approx(float(entry.amount), amount): return false
			count += 1
	return count == 1
