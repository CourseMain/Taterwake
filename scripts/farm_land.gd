extends RefCounted
## A lease is paid ahead each Winter; cancellation refunds that Winter's renewal.
const IDS: Array[String] = ["home", "low", "hill"]
const NAMES := {"home": "Home Field", "low": "Low Field", "hill": "Hill Field"}
const WORDS := {"home": "Sheltered", "low": "Floods first", "hill": "Dries first"}
const RENTS = preload("res://scripts/balance.gd").FIELD_RENTS
const EXPOSURE := {"home": {"storm": 0.8, "flood": 0.8}, "low": {"flood": 1.5, "drought": 0.8}, "hill": {"drought": 1.5, "flood": 0.5, "storm": 1.3, "freeze": 1.2}}

static func fresh() -> Dictionary:
	return {"low": {"rented": false, "expansion": 0, "paid_year": 0}, "hill": {"rented": false, "expansion": 0, "paid_year": 0}}

static func id(index: int) -> String:
	return IDS[clampi(index / 24, 0, 2)]

static func exposure(field: String, event: String) -> float:
	return float(EXPOSURE[field].get(event, 1.0))

static func yield_for(plot: Dictionary) -> int:
	var base: int = int(preload("res://scripts/crop_table.gd").CROPS[plot.crop].yield)
	# Tonnes are whole units. Distribute fractional quarters over four beds,
	# so every complete half-field yields exactly 25% more, for every crop.
	if plot.get("field", "home") == "low":
		var local: int = int(plot.get("bed", 0)) % 4
		return floori((local + 1) * base * 1.25) - floori(local * base * 1.25)
	return base

static func active(farm, field: String) -> bool:
	return field == "home" or bool(farm.land[field].rented)

static func sync(farm) -> void:
	for index in range(farm.plots.size()):
		var field: String = id(index)
		var expanded: bool = farm.expansion == 1 if field == "home" else int(farm.land[field].expansion) == 1
		farm.plots[index].unlocked = active(farm, field) and (index % 24 < 12 or expanded)

static func renew(farm) -> void:
	for field in RENTS:
		var lease: Dictionary = farm.land[field]
		if lease.rented and int(lease.paid_year) != farm.season_clock.year:
			farm.post_money("rent", NAMES[field] + " annual lease", -RENTS[field])
			lease.paid_year = farm.season_clock.year

static func rent(farm, field: String, enabled: bool) -> String:
	if field not in RENTS or farm.run_over or farm.season_clock.season != 3 or farm.tutorial_active:
		return farm._finish("Field leases are decided at the Winter accounts.")
	var lease: Dictionary = farm.land[field]
	if bool(lease.rented) == enabled: return farm._finish("Lease already set.")
	if enabled:
		if not farm.can_purchase(RENTS[field]): return farm._reject_purchase(farm.purchase_refusal(RENTS[field]))
		lease.rented = true
		renew(farm)
	else:
		lease.rented = false
		if int(lease.paid_year) == farm.season_clock.year:
			farm.post_money("rent", NAMES[field] + " lease cancellation", RENTS[field])
		lease.paid_year = 0
		for plot in farm.plots:
			if plot.field == field:
				var left: int = farm.ClimateSystem.Protection.remaining(plot)
				if left > 0: farm.ClimateSystem.Protection.record(farm, "lease_ended", str(plot.crop), left, 0.0, 1.0, "Harvest before returning the field", "field", -1, -1, field)
				farm._clear_crop(plot)
				plot.tilled = false
		for key in farm.climate.data.protection.covers.keys():
			if id(int(key)) == field: farm.climate.data.protection.covers.erase(key)
	sync(farm)
	return farm._finish(("%s rented. %d beds open; renews each Winter." % [NAMES[field], farm.field_expansion_info(field).opened]) if enabled else NAMES[field] + " returned. Standing crops cleared; this Winter's rent refunded.")

static func valid(raw: Variant, saved: Dictionary = {}) -> bool:
	if not raw is Dictionary or raw.size() != 2: return false
	for field in RENTS:
		var lease: Variant = raw.get(field)
		if not lease is Dictionary or lease.size() != 3 or not lease.get("rented") is bool: return false
		if not preload("res://scripts/save_validation.gd").number(lease.get("expansion"), 0, 1, true): return false
		if not preload("res://scripts/save_validation.gd").number(lease.get("paid_year"), 0, 50, true): return false
		if lease.rented != (int(lease.paid_year) > 0): return false
		if lease.rented and not saved.is_empty():
			var year: int = int(saved.season_clock.year)
			if int(lease.paid_year) != year - (0 if int(saved.season_clock.season) == 3 else 1): return false
			var paid: float = 0.0
			for entry in saved.ledger.entries:
				if int(entry.year) == int(lease.paid_year) and entry.category == "rent" and entry.label in [NAMES[field] + " annual lease", NAMES[field] + " lease cancellation"]:
					paid += float(entry.amount)
			if paid != -RENTS[field]: return false
	return true
