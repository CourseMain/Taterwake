extends RefCounted
const Balance = preload("res://scripts/balance.gd")
## Winter stores, annual storage bills and one Spring buyer order.
const Stock = preload("res://scripts/graded_stock.gd")
const Quality = preload("res://scripts/crop_quality.gd")
const Table = preload("res://scripts/crop_table.gd")
const Rules = preload("res://scripts/save_validation.gd")
const STORAGE_FEE: float = Balance.STORAGE_FEE
const SPOILAGE: float = Balance.SPOILAGE
const SHORTFALL_FEE: float = Balance.SHORTFALL_FEE
var held: Dictionary = Stock.empty()
var kept_seed: Dictionary = Table.empty_stock()
var winters: Dictionary = {}
var contract: Dictionary = {}
var settled: Dictionary = {}

func peak_price(id: String, grade: String = "Standard") -> float:
	return float(Table.CROPS[id].base) * float(Table.VOLATILITY[Table.CROPS[id].volatility].storage_peak_factor) * Quality.MULTIPLIER[grade]

func stored_price(farm, id: String, grade: String = "Standard") -> float:
	var progress: float = clampf(farm.season_clock.seconds / farm.SeasonClock.SEASON_SECONDS, 0, 1) if farm.season_clock.season == 3 else 0.0
	return lerpf(float(Table.CROPS[id].base) * Quality.MULTIPLIER[grade], peak_price(id, grade), progress)

func fresh_count(farm, id: String, grade: String = "") -> int:
	return Stock.count(farm.storage, id, grade) - Stock.count(held, id, grade) if farm.season_clock.season == 3 else Stock.count(farm.storage, id, grade)

func clamp_stock(farm) -> void:
	for id in Table.IDS:
		for word in Quality.GRADES:
			for score in held[id][word].keys():
				var amount: int = mini(int(held[id][word][score]), int(farm.storage[id][word].get(score, 0)))
				if amount > 0: held[id][word][score] = amount
				else: held[id][word].erase(score)

func begin_spring(farm) -> void:
	held = Stock.empty()
	for id in Table.IDS:
		farm.seed_inventory[id] += int(kept_seed[id])
	kept_seed = Table.empty_stock()

func keep_seed(farm, id: String, grade: String, quantity: int = 1) -> String:
	if farm.run_over or farm.accounts_open or farm.tutorial_active: return farm._finish("Return to the farm before keeping seed.")
	if id not in Table.IDS or grade not in ["Standard", "Table"] or quantity < 1: return farm._finish("Keep Standard or Table sacks as seed.")
	if Stock.count(farm.storage, id, grade) < quantity or int(kept_seed[id]) + int(farm.seed_inventory[id]) + quantity > farm.MAX_INVENTORY: return farm._finish("Not enough sacks or seed space.")
	# Prefer fresh sacks; any remainder comes from stores with the same cohort.
	var fresh: int = mini(quantity, fresh_count(farm, id, grade))
	Stock.take(farm.storage, id, fresh, grade, held)
	var lots: Array = Stock.take(held, id, quantity - fresh, grade)
	Stock.remove_lots(farm.storage, id, lots)
	kept_seed[id] += quantity
	return farm._finish("Kept %d %s sacks as seed for next Spring. Outside saleable stores and spoilage." % [quantity, id.capitalize()])

func eligible_contract(farm, id: String) -> int:
	return Stock.count(farm.storage, id, "Standard") + Stock.count(farm.storage, id, "Table")

func begin_winter(farm) -> void:
	var year: String = str(farm.season_clock.year)
	if winters.has(year): return
	var report: Dictionary = {"fee": STORAGE_FEE if farm.storage_used() > 0 else 0.0, "spoiled": Table.empty_stock()}
	var remaining_loss: int = roundi(farm.storage_used() * SPOILAGE)
	var piles: Array[String] = Table.IDS.duplicate()
	# Resolve equal piles in catalogue order so the loss is deterministic.
	piles.sort_custom(func(a: String, b: String) -> bool:
		return farm.stock_count(a) > farm.stock_count(b) if farm.stock_count(a) != farm.stock_count(b) else Table.IDS.find(a) < Table.IDS.find(b))
	for id in piles:
		var loss: int = mini(farm.stock_count(id), remaining_loss)
		remaining_loss -= loss
		report.spoiled[id] = loss
		Stock.take(farm.storage, id, loss)
		farm.ClimateSystem.Protection.record(farm, "spoilage", id, loss, 0.0, 1.0, "Sell before Winter storage", "barn")
		if loss > 0: farm.ledger.post(farm.season_clock.year, 3, "storage", "Spoilage: %d %s sacks" % [loss, id], 0.0, true)
	farm.storage = Stock.age(farm.storage)
	held = farm.storage.duplicate(true)
	if report.fee > 0: farm.post_money("storage", "Winter storage fee", -float(report.fee))
	winters[year] = report

func sell_stored(farm, id: String, quantity: int = -1, grade: String = "") -> String:
	return sell(farm, id, quantity, grade, true)

func sell(farm, id: String, quantity: int, grade: String, stored: bool) -> String:
	if farm.run_over or farm.accounts_open: return farm._finish("Return to the farm before selling.")
	if stored and farm.season_clock.season != 3: return farm._finish("Sell Winter stores at the barn during Winter only.")
	if id not in Table.IDS or quantity == 0 or quantity < -1 or (not grade.is_empty() and grade not in Quality.GRADES): return farm._finish("Choose a crop, grade and amount.")
	var owned: int = Stock.count(held, id, grade) if stored else fresh_count(farm, id, grade)
	var amount: int = owned if quantity == -1 else quantity
	if amount <= 0 or amount > owned: return farm._finish("Not enough sacks of that grade. Sell stored sacks at Barn stores during Winter.")
	var lots: Array = Stock.take(held if stored else farm.storage, id, amount, grade, {} if stored else held)
	if stored: Stock.remove_lots(farm.storage, id, lots)
	var earnings: float = 0
	for word in Quality.GRADES:
		var sacks: int = 0
		for lot in lots:
			if lot.grade == word: sacks += int(lot.quantity)
		if sacks == 0: continue
		var price: float = stored_price(farm, id, word) if stored else float(farm.market[id].sell) * Quality.MULTIPLIER[word]
		farm.post_money("sales", "Sold %d %s %s sacks" % [sacks, word, id], price * sacks)
		earnings += price * sacks
	farm._record_sales(earnings)
	farm._progress_quest("starter_spike", float(amount))
	farm.farm_help.observe_sale(farm, id)
	farm.sale_completed.emit({"id":id, "grade":grade, "quantity":amount, "price":earnings/amount, "total":earnings, "owned":farm.stock_count(id)})
	return farm._finish("Sold %d %s %s sacks for %s." % [amount, grade, id.capitalize(), farm.money(earnings)])

func offer(year: int) -> Dictionary:
	var id: String = Table.IDS[(year - 1) % Table.IDS.size()]
	return {"year": year, "crop": id, "quantity": 20, "price": float(Table.CROPS[id].base) * 1.1}

func accept(farm) -> String:
	var year: int = farm.season_clock.year
	if farm.run_over or farm.accounts_open or farm.tutorial_active or farm.season_clock.season != 0: return farm._finish("The buyer offers one order each Spring.")
	if not contract.is_empty() or settled.has(str(year)): return farm._finish("Only one buyer order per year.")
	contract = offer(year)
	return farm._finish("Order accepted: %d %s sacks, Standard or better, collected at the end of Autumn. Shortfalls cost %s per sack." % [contract.quantity, contract.crop.capitalize(), farm.money(SHORTFALL_FEE)])

func settle(farm) -> void:
	if contract.is_empty(): return
	var id: String = contract.crop
	var delivered: int = mini(eligible_contract(farm, id), int(contract.quantity))
	var missing: int = int(contract.quantity) - delivered
	var standard: int = mini(delivered, Stock.count(farm.storage, id, "Standard"))
	Stock.take(farm.storage, id, standard, "Standard")
	Stock.take(farm.storage, id, delivered - standard, "Table")
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
	return "Storage fee %s · Spoilage %d sacks (5%% of the barn, rounded to nearest; largest pile first). Stored sacks lose 10 quality." % [farm.money(report.fee), loss]

func save_data() -> Dictionary:
	return {"held": held.duplicate(true), "kept_seed": kept_seed.duplicate(), "winters": winters.duplicate(true), "contract": contract.duplicate(), "settled": settled.duplicate(true)}

func load_data(raw: Dictionary) -> void:
	held = raw.held.duplicate(true)
	kept_seed = raw.kept_seed.duplicate()
	winters = raw.winters.duplicate(true)
	contract = raw.contract.duplicate()
	settled = raw.settled.duplicate(true)

func valid(raw: Variant, saved: Dictionary) -> bool:
	if not raw is Dictionary or raw.size() != 5 or not Stock.valid(raw.get("held")): return false
	if not raw.get("kept_seed") is Dictionary or raw.kept_seed.size() != Table.IDS.size(): return false
	for id in Table.IDS:
		if not Rules.number(raw.kept_seed.get(id), 0, 100000, true) or int(raw.kept_seed[id]) + int(saved.seed_inventory[id]) > 100000: return false
		if int(saved.season_clock.season) != 3 and Stock.count(raw.held, id) != 0: return false
		for word in Quality.GRADES:
			for score in raw.held[id][word]:
				if int(raw.held[id][word][score]) > int(saved.storage[id][word].get(score, 0)): return false
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
