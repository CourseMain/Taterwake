extends SceneTree
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://tax_credit_land_test_only.json"
var farm
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func tax_debt(amount: float) -> void:
	farm.coins = float(farm.blind_info().tax) - amount
	farm._resolve_blind()
func open_island(island: int) -> void:
	farm.coins = 1e18
	farm.mastery.russet = State.ISLAND3_UNLOCK_HARVEST
	if not farm.island2_unlocked: farm.unlock_island2()
	if island == 3 and not farm.island3_unlocked: farm.unlock_island3()
	farm.travel_to(island)
	farm.climate.acknowledge(farm)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	farm = State.new()
	root.add_child(farm)
	check(farm.field_expansion_info().opened == 12, "new Valley starts with half the field")
	check(not farm.has_tax_credit() and farm.purchase_credit() == 0, "new farm has no borrowing account")
	check(farm.can_purchase(240) and not farm.can_purchase(241), "cash farm can spend only its cash")
	check(not farm.purchase_caption("Buy",241).contains("account"), "unaffordable cash purchase never advertises an account")
	var snapshot: Dictionary = farm._save_data().duplicate(true)
	farm.upgrade_tool("hoe")
	check(farm._save_data() == snapshot, "cash shortage leaves state unchanged")
	farm.coins = -1000
	check(not farm.has_tax_credit() and not farm.can_purchase(1), "non-tax negative balance cannot grant borrowing")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and not farm.has_tax_credit(), "non-tax debt stays ineligible after load")
	tax_debt(1000)
	check(farm.coins == -1000 and farm.has_tax_credit(), "actual tax shortfall opens an account")
	check(farm.purchase_credit() == 49000, "account allowance matches bankruptcy boundary")
	var quote: Dictionary = farm.purchase_quote(300)
	check(quote.affordable and quote.uses_credit and quote.after_balance == -1300 and quote.credit_left_after == 48700 and not quote.near_limit, "quote reports exact debt and remaining allowance")
	check(farm.purchase_caption("Upgrade",300) == "Upgrade · On account", "account label appears only when borrowing")
	farm.upgrade_tool("hoe")
	check(farm.tools.hoe == 1 and farm.coins == -1300, "eligible purchase grants item and increases debt")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.has_tax_credit(), "tax origin survives save and load")
	quote = farm.purchase_quote(46000)
	check(quote.affordable and quote.near_limit and quote.credit_left_after == 2700, "near-bankruptcy purchase produces a warning quote")
	quote = farm.purchase_quote(49000)
	check(not quote.affordable and quote.near_limit and quote.reason.contains("bankruptcy"), "over-limit purchase is blocked with explicit reason")
	farm.coins = farm.bankruptcy_limit() + float(farm.market.russet.seed)
	farm.buy_seeds("russet",1)
	check(is_equal_approx(farm.coins, farm.bankruptcy_limit()) and not farm.run_over, "exact boundary is safe to spend to")
	snapshot = farm._save_data().duplicate(true)
	farm.buy_seeds("russet",1)
	check(farm._save_data() == snapshot and not farm.run_over, "over-limit purchase cannot trigger bankruptcy")
	check(not farm.can_purchase(INF) and not farm.can_purchase(NAN) and not farm.can_purchase(-1), "invalid purchase amounts rejected")
	farm.storage.russet = 100
	farm.deliver_recovery()
	check(farm.coins == 0 and not farm.has_tax_credit() and not farm.tax_credit_eligible, "recovery at zero closes the account")
	farm.coins = -100
	check(not farm.has_tax_credit(), "later non-tax loss cannot reopen a closed account")
	tax_debt(1000)
	farm.debug_set_balance(1)
	check(not farm.tax_credit_eligible, "debug cash recovery clears permission")
	tax_debt(1000)
	farm.coins = farm.bankruptcy_limit()-1
	farm.debug_recover(240)
	check(not farm.run_over and not farm.has_tax_credit(), "debug recovery clears ended-run permission")
	tax_debt(1000)
	farm.reset_game()
	check(not farm.tax_credit_eligible, "new game clears permission")
	farm.coins = 1800
	farm.expand_field()
	check(farm.field_expansion_info().complete and farm.expansion == 1 and farm.coins == 0, "Valley expansion opens twelve beds once")
	for island in [2,3]:
		open_island(island)
		var info: Dictionary = farm.field_expansion_info()
		check(info.opened == info.total/2 and info.remaining == info.total/2, "new island %d starts half open" % island)
		check(not farm.plots.back().unlocked, "back half of island %d remains locked" % island)
		check(info.cost == (25000000.0 if island == 2 else 1e12), "expansion price follows island %d economy" % island)
		var before: float = farm.coins
		farm.expand_field()
		check(farm.field_expansion_info().complete and farm.coins == before-info.cost, "purchase opens remainder of island %d exactly once" % island)
		snapshot = farm._save_data().duplicate(true)
		farm.expand_field()
		check(snapshot == farm._save_data(), "repeated island %d expansion cannot charge twice" % island)
		check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.field_expansion_info().complete, "island %d expansion persists" % island)
	farm.travel_to(1)
	check(farm.field_expansion_info().complete, "later expansions preserve Valley purchase")
	# A real pre-update save had all later-island beds open. Keep growing crops
	# and active frost targets while reclaiming only empty land.
	farm.travel_to(3)
	var legacy: Dictionary = farm._save_data().duplicate(true)
	legacy.mechanics_revision = 20
	for key in ["tax_credit_eligible","field_expansions","retained_beds"]: legacy.erase(key)
	legacy.island_plots["2"][30].merge({"stage":1,"tilled":true,"watered":false,"crop":"sunburst"},true)
	legacy.island_plots["2"][31].tilled = true
	legacy.island_plots["3"][60].merge({"stage":2,"tilled":true,"watered":true,"elapsed":10.0,"crop":"icecap"},true)
	legacy.plots = legacy.island_plots["3"]
	check(farm._valid_save(legacy), "genuine legacy full-field state passes old validation")
	write_save(legacy)
	check(farm.load_game(SAVE), "legacy field migration loads")
	check(farm.island_plots["2"][30].unlocked and farm.island_plots["2"][30].stage == 1, "legacy planted Shores bed survives")
	check(not farm.island_plots["2"][31].unlocked and not farm.island_plots["2"][31].tilled, "legacy empty tilled extra land is locked")
	check(farm.plots[60].unlocked and farm.plots[60].elapsed == 10 and farm.plots[60].stage == 2, "legacy growing winter crop retains its progress")
	check(farm.field_expansion_info().opened == 41 and farm.field_expansion_info().remaining == 39, "winter migration retains only occupied extra bed")
	check(farm.expansion == 1, "legacy paid Valley expansion stays open")
	farm._clear_crop(farm.plots[60])
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.plots[60].unlocked, "retained extra bed remains accessible after harvest and reload")
	farm._start_frost()
	var frozen: int = 0
	var frozen_locked: int = 0
	for plot in farm.plots:
		if plot.frozen:
			frozen += 1
			if not plot.unlocked: frozen_locked += 1
	check(frozen == 12 and frozen_locked == 0, "Frostbreak targets only accessible beds")
	farm._end_frost()
	farm.expand_field()
	check(farm.field_expansion_info().complete and farm.retained_beds["3"].is_empty(), "expansion opens migrated locked land and clears exceptions")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.field_expansion_info().complete, "migration never reclaims a newly purchased expansion")
	# Pre-update tax debt uses the last actual tax collection as evidence.
	tax_debt(1000)
	legacy = farm._save_data().duplicate(true)
	legacy.mechanics_revision = 20
	for key in ["tax_credit_eligible","field_expansions","retained_beds"]: legacy.erase(key)
	for id in ["2","3"]:
		for plot in legacy.island_plots[id]: plot.unlocked = true
	legacy.plots = legacy.island_plots[str(farm.current_island)]
	write_save(legacy)
	check(farm.load_game(SAVE) and farm.has_tax_credit(), "old tax-debt save receives account eligibility")
	legacy.blind_cycle.last_result = {}
	write_save(legacy)
	check(farm.load_game(SAVE) and not farm.has_tax_credit(), "old negative balance without tax evidence cannot open an account")
	farm.reset_game()
	farm.debug_unlock_island(3)
	farm.travel_to(3)
	check(farm.field_expansion_info().opened == 40, "debug island unlock follows new land progression")
	check(farm._valid_save(farm._save_data()), "new half-open debug farm serializes validly")
	for path in [SAVE,SAVE+".bak",SAVE+".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	farm.queue_free()
	await process_frame
	print("TAX CREDIT / LAND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
