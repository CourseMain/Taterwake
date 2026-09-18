extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Builds = preload("res://scripts/player_builds.gd")
const SAVE := "user://spud_equipment_test_only.json"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _run() -> void:
	var state = State.new()
	var builds = Builds.new()
	builds.state = state
	state.build_system = builds
	root.add_child(state)
	root.add_child(builds)
	state.rng.seed = 32148
	check(state.equipment_info().size() == 6, "six equipment slots are exposed to the inventory")
	for slot in state.equipment_info():
		check(slot.empty and slot.id == "" and not slot.active, "new farm begins with empty " + str(slot.slot))
	var initial_rng: int = state.rng.state
	var original_loadout: Dictionary = state.equipment_loadout()
	state.equip_gear("farmer_shirt")
	state.equip_gear("sunstone")
	state.equip_gear("missing_item")
	state.unequip_gear("helmet")
	check(state.equipment_loadout() == original_loadout and state.rng.state == initial_rng, "unowned, nonwearable and invalid slot requests cannot change gear or advance RNG")
	var role_counts: Dictionary = {}
	for id in State.ITEM_CATALOG:
		var item: Dictionary = State.ITEM_CATALOG[id]
		if item.get("kind", "") != "gear":
			continue
		check(State.EQUIPMENT_SLOTS.has(str(item.slot)) and item.has("color") and item.has("bonuses"), "wearable has a real slot, appearance and stats: " + id)
		if item.has("role"):
			role_counts[item.role] = int(role_counts.get(item.role, 0)) + 1
	for role in ["farmer", "gambler", "investor", "scientist", "industrialist"]:
		check(int(role_counts.get(role, 0)) == 3, "each build has a shirt, pants and footwear: " + role)
	# Audit every piece independently, including all lesser-seen garments.
	for id in State.ITEM_CATALOG:
		var item: Dictionary = State.ITEM_CATALOG[id]
		if item.get("kind", "") != "gear":
			continue
		state.reset_game()
		if item.has("role"):
			builds.levels[item.role] = 1
			builds.select_build(item.role)
		state._grant_item(id)
		for stat in item.bonuses:
			check(is_equal_approx(state.equipment_bonus(stat), float(item.bonuses[stat]) * (1.25 if item.has("role") else 1.0)), "equipped matching-build stat applies: " + id + " / " + str(stat))
		state.unequip_gear(str(item.slot))
		for stat in item.bonuses:
			check(state.equipment_bonus(stat) == 0.0, "stored item cannot leave a hidden bonus: " + id + " / " + str(stat))
	state.reset_game()
	state._grant_item("farmer_shirt")
	check(state.equipment_loadout().body == "farmer_shirt" and is_equal_approx(state.item_yield_bonus(), 0.10), "first garment auto-equips and Farmer synergy changes real yield bonus")
	state._grant_item("farmer_shirt")
	check(state.inventory_items.farmer_shirt == 2 and is_equal_approx(state.item_yield_bonus(), 0.10), "extra owned copies cannot stack equipment power")
	state._grant_item("scientist_coat")
	check(state.equipment_loadout().body == "farmer_shirt", "new clothing does not replace a chosen occupied slot")
	state.equip_gear("scientist_coat")
	check(state.equipment_loadout().body == "scientist_coat" and is_equal_approx(state.item_yield_bonus(), 0.0) and is_equal_approx(state.equipment_mutation_factor(), 1.25), "equipping a coat replaces shirt bonuses immediately")
	check(state.inventory_items.farmer_shirt == 2 and state.inventory_items.scientist_coat == 1, "equipping never consumes or duplicates owned clothes")
	var mutation_with_coat: float = state.mutation_chance("russet")
	state.unequip_gear("body")
	check(is_equal_approx(mutation_with_coat / state.mutation_chance("russet"), 1.25), "unequipping removes the actual mutation modifier")
	state._grant_item("sunstone")
	state._grant_item("lens")
	check(is_equal_approx(state.item_yield_bonus(), 0.02) and is_equal_approx(state.item_mutation_factor(), 1.10), "original keepsakes stay passive without using equipment slots")
	state.equip_gear("scientist_coat")
	builds.levels.scientist = 1
	builds.select_build("scientist")
	check(is_equal_approx(state.equipment_mutation_factor(), 1.3125), "matching Scientist build strengthens its clothing bonus by25 percent")
	builds.select_build("farmer")
	check(is_equal_approx(state.equipment_mutation_factor(), 1.25), "nonmatching builds can wear the same clothing at its base strength")
	state.reset_game()
	state._grant_item("farmer_pants")
	state._grant_item("farmer_boots")
	check(is_equal_approx(state.crop_growth_speed(), 1.175) and is_equal_approx(state.crop_grow_time("russet"), 10.0 / 1.175), "growth clothing changes actual and displayed growth speed")
	var plot: Dictionary = state.plots[4]
	plot.stage = 2
	plot.watered = true
	plot.tilled = true
	plot.elapsed = 0.0
	state.update(1.0)
	check(is_equal_approx(plot.elapsed, 1.175), "field simulation uses equipped growth clothing")
	state.unequip_gear("legs")
	state.unequip_gear("feet")
	state.update(1.0)
	check(is_equal_approx(plot.elapsed, 2.175), "removing growth equipment restores ordinary per-second growth without losing progress")
	state.reset_game()
	var base_quote: float = state.market.russet.sell
	var base_seed: float = state.market.russet.seed
	state._grant_item("investor_shirt")
	check(is_equal_approx(state.market.russet.sell, base_quote * 1.10) and is_equal_approx(state.market.russet.seed, base_seed * 1.10), "stock shirt increases actual crop and linked seed prices together")
	state._grant_item("investor_shirt")
	state.equip_gear("investor_shirt")
	check(is_equal_approx(state.market.russet.sell, base_quote * 1.10), "re-equipping and collecting stock duplicates cannot compound prices")
	builds.levels.investor = 1
	builds.select_build("investor")
	check(is_equal_approx(state.item_stock_factor(), 1.125) and is_equal_approx(state.market.russet.sell, base_quote * 1.125), "changing to Investor immediately refreshes matched clothing stock quotes")
	state.unequip_gear("body")
	check(is_equal_approx(state.market.russet.sell, base_quote), "stock clothing stops affecting prices when removed")
	state.reset_game()
	var ordinary_odds: float = state.roll_odds()[0].chance
	var ordinary_mutation: float = state.mutation_chance("russet")
	state._grant_item("gambler_shirt")
	check(is_equal_approx(state.effective_luck(), 1.35) and state.roll_odds()[0].chance < ordinary_odds and state.mutation_chance("russet") > ordinary_mutation, "equipped luck clothing improves real odds and mutations")
	state.unequip_gear("body")
	check(is_equal_approx(state.effective_luck(), 1.0) and is_equal_approx(state.roll_odds()[0].chance, ordinary_odds), "stored luck clothing grants no power")
	state.equip_gear("gambler_shirt")
	state._grant_item("aurora_crown")
	state._grant_item("loaded_dice")
	state.luck = 9.9
	check(state.effective_luck() == 10.0, "all equipped luck still obeys the10x effective cap")
	state.reset_game()
	builds.levels.industrialist = 1
	builds.select_build("industrialist")
	state._grant_item("industrialist_overalls")
	state._grant_item("industrialist_pants")
	state._grant_item("industrialist_boots")
	check(is_equal_approx(state.equipment_processing_factor(), 1.625), "Industrialist outfit applies meaningful processing bonuses with synergy")
	state.storage.russet = 100
	builds.use_ability()
	builds.update(1.0)
	check(is_equal_approx(builds.processing.elapsed, 1.625), "loaded processor advances using equipped outfit speed")
	state.unequip_gear("body")
	state.unequip_gear("legs")
	state.unequip_gear("feet")
	builds.update(1.0)
	check(is_equal_approx(builds.processing.elapsed, 2.625), "removing outfit slows existing processing job without duplicating potatoes")
	state.reset_game()
	for id in ["prospectors_hat", "investor_shirt", "investor_pants", "investor_shoes", "market_monocle", "harvest_gloves"]:
		state._grant_item(id)
	builds.levels.investor = 1
	builds.select_build("investor")
	check(is_equal_approx(state.item_stock_factor(), 1.525), "one strongest stock item per slot has a bounded combined bonus")
	state.surge_crop = "russet"
	state.surge_remaining = 5.0
	state.surge_factor = State.MAX_PRICE_MULTIPLIER
	state._refresh_market(false)
	check(is_equal_approx(state.market.russet.change, 3000.0), "full stock outfit never breaks the+3000 percent market cap")
	var held_loadout: Dictionary = state.equipment_loadout()
	held_loadout.head = "aurora_crown"
	check(state.equipment_loadout().head == "prospectors_hat", "loadout UI snapshot cannot mutate authoritative equipment")
	var equipped_count: int = 0
	for entry in state.inventory_info():
		if entry.kind == "gear" and entry.active:
			equipped_count += 1
			check(entry.equipped and str(entry.action).begins_with("gear:unequip:"), "equipped inventory row exposes unequip action")
	check(equipped_count == 6, "one active item occupies each of six body slots")
	check(state.save_game(SAVE) and state.load_game(SAVE) and state.equipment_loadout().body == "investor_shirt" and is_equal_approx(state.item_stock_factor(), 1.525), "chosen loadout and active build synergy survive save/load")
	var saved: Dictionary = state._save_data().duplicate(true)
	for error_kind in ["missing_slot", "extra_slot", "wrong_slot", "unowned", "duplicate", "unknown", "missing_equipment"]:
		var malformed: Dictionary = saved.duplicate(true)
		match error_kind:
			"missing_slot": malformed.equipment.erase("head")
			"extra_slot": malformed.equipment["back"] = ""
			"wrong_slot": malformed.equipment.head = "investor_shirt"
			"unowned": malformed.equipment.body = "scientist_coat"
			"duplicate": malformed.equipment.charm = "prospectors_hat"
			"unknown": malformed.equipment.feet = "future_boots"
			"missing_equipment": malformed.erase("equipment")
		check(not state._valid_save(malformed), "strict saved equipment rejects " + error_kind)
	state.reset_game()
	for id in ["straw_hat", "lucky_cap", "traders_visor", "prospectors_hat", "aurora_crown", "harvest_gloves", "market_monocle", "loaded_dice"]:
		state._grant_item(id)
	state.coins = 987654.0
	state.mastery.russet = 132
	var old_data: Dictionary = state._save_data().duplicate(true)
	old_data.mechanics_revision = 5
	old_data.erase("equipment")
	for id in State.ITEM_CATALOG:
		if State.ITEM_CATALOG[id].has("role"):
			old_data.inventory_items.erase(id)
	write_save(old_data)
	check(state.load_game(SAVE), "previous16-item farms migrate to equipment slots")
	check(state.equipment_loadout().head == "aurora_crown" and state.equipment_loadout().hands == "harvest_gloves" and state.equipment_loadout().charm == "loaded_dice", "migration equips best old owned item in each compatible slot")
	check(state.equipment_loadout().body == "" and state.inventory_items.farmer_shirt == 0 and state.inventory_items.straw_hat == 1 and state.coins == 987654.0 and state.mastery.russet == 132, "migration preserves ownership and progress without granting new clothes")
	check(state.save_game(SAVE) and state.load_game(SAVE), "migrated equipment farm remains valid when resaved")
	state.reset_game()
	var seeds: Dictionary = state.seed_inventory.duplicate(true)
	for _index in range(500):
		state._grant_roll_reward("rare", 200.0)
		state._grant_roll_reward("epic", 200.0)
	for id in State.ITEM_CATALOG:
		if State.ITEM_CATALOG[id].has("role"):
			check(int(state.inventory_items[id]) > 0, "real gacha pool can award clothing: " + id)
	check(state.seed_inventory == seeds, "expanded clothing pool still awards no seeds")
	for slot in State.EQUIPMENT_SLOTS:
		state.unequip_gear(slot)
	check(state.equipment_bonus("yield") == 0.0 and state.equipment_bonus("luck") == 0.0 and state.equipment_processing_factor() == 1.0 and state.item_stock_factor() == 1.0, "a full inventory of unequipped clothes grants no hidden bonuses")
	state.reset_game()
	for slot in state.equipment_info():
		check(slot.empty, "new-game reset clears " + str(slot.slot))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	builds.free()
	state.free()
	print("SPUD EQUIPMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
