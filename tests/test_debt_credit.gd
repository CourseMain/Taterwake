extends SceneTree
const SAVE := "user://tater_debt_credit_test_only.json"
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.coins = -1000
	game.hud.show_panel("market",farm)
	await settle()
	var seed_cost: float = farm.market.russet.seed
	var seeds: int = farm.seed_inventory.russet
	check(not game.hud._refs["buy:russet:5"].disabled and game.hud._refs["buy:russet:5"].text.contains("Credit"),"seed checkout exposes credit while negative")
	game.hud._refs["buy:russet:5"].pressed.emit()
	check(farm.seed_inventory.russet == seeds+5 and is_equal_approx(farm.coins,-1000-seed_cost*5),"credit seed purchase charges exact live quote below zero")
	check(game.hud._recovery_link.visible,"debt recovery remains reachable from shop")
	for panel: String in ["tools","barn","duck_patrol"]:
		game.hud.show_panel(panel,farm)
		await settle()
		var action: String = {"tools":"upgrade:hoe","barn":"upgrade:barn","duck_patrol":"activity:duck"}[panel]
		check(not game.hud._refs[action].disabled and game.hud._refs[action].text.contains("Credit"),"credit available for "+panel)
		var balance: float = farm.coins
		game.hud._refs[action].pressed.emit()
		check(farm.coins < balance and not farm.run_over,"credit purchase completes safely for "+panel)
	check(farm.tools.hoe == 1 and farm.barn_level == 1 and game.activities.duck_count() == 1,"purchased tool, barn and duck actually granted")
	var before: float = farm.coins
	farm.expand_field()
	check(farm.expansion == 1 and farm.coins == before-1800,"field expansion accepts debt")
	var rng_before: int = farm.rng.state
	check(not farm.can_roll("normal") and farm.roll_batch("normal",3).is_empty() and farm.rng.state == rng_before,"casino still requires a cash stake")
	farm.coins = farm.bankruptcy_limit() + seed_cost
	farm.buy_seeds("russet",1)
	check(is_equal_approx(farm.coins,farm.bankruptcy_limit()) and not farm.run_over,"exact credit limit is payable without bankruptcy")
	for action: Callable in [func(): farm.buy_seeds("russet",1), func(): farm.upgrade_tool("water"), func(): farm.upgrade_barn(), func(): game.activities.train_ducks()]:
		var snapshot: Dictionary = farm._save_data().duplicate(true)
		action.call()
		check(farm._save_data() == snapshot,"over-limit purchase leaves all saved state unchanged")
	check(not farm.can_purchase(INF) and not farm.can_purchase(NAN) and not farm.can_purchase(-1),"invalid purchase values rejected")
	farm.coins = -760
	farm.storage.russet = 1
	farm.storage.golden = 5
	var order: Dictionary = farm.recovery_order()
	check(order.needed == 2 and order.quantity == 2 and order.payment == 760,"order pays only outstanding debt")
	game.hud._recovery_link.pressed.emit()
	check(game.hud._panel_kind == "debt" and not game.hud._refs.recovery_deliver.disabled,"shop recovery link opens real delivery")
	game.hud._refs.recovery_deliver.pressed.emit()
	check(farm.coins == 0 and farm.storage.russet == 0 and farm.storage.golden == 4,"delivery consumes cheapest potatoes first and retains surplus")
	var clear_snapshot: Dictionary = farm._save_data().duplicate(true)
	game._on_action("recovery:deliver")
	check(farm._save_data() == clear_snapshot,"repeated delivery cannot create cash")
	farm.coins = -500
	farm.storage.golden = 0
	farm.storage.russet = 1
	var sell: float = farm.market.russet.sell
	farm.sell_crop("russet",1)
	check(is_equal_approx(farm.coins,-500+sell),"normal market sales also reduce debt")
	farm.coins = farm.bankruptcy_limit()
	for crop in farm.CROP_IDS:
		farm.seed_inventory[crop] = 0
		farm.storage[crop] = 0
	for field in farm.island_plots.values():
		for plot in field: farm._clear_crop(plot)
	check(farm.can_claim_recovery_seeds(),"empty farm at debt limit has free restart supply")
	game._on_action("recovery:seeds")
	check(farm.seed_inventory.russet == 3 and farm.coins == farm.bankruptcy_limit(),"free recovery seeds do not add debt")
	game._on_action("recovery:seeds")
	check(farm.seed_inventory.russet == 3,"free supply cannot be repeatedly stockpiled")
	farm.selected_crop = "russet"
	farm.interact_plot(0,"hoe")
	farm.interact_plot(0,"plant")
	farm.interact_plot(0,"water")
	check(farm.plots[0].stage > 0 and farm.plots[0].watered,"relief seeds can be planted and watered at the debt limit")
	farm.update(12)
	farm.interact_plot(0,"harvest")
	check(farm.storage.russet > 0,"recovery crop can be grown and harvested without money")
	var harvest_debt: float = farm.coins
	farm.deliver_recovery()
	check(farm.coins > harvest_debt and farm.coins <= 0,"actual harvested relief crop repays debt")
	farm.seed_inventory.russet = 0
	farm.plots[0].stage = 1
	check(not farm.can_claim_recovery_seeds(),"planted crop prevents duplicate relief")
	farm._clear_crop(farm.plots[0])
	for island in [1,2,3]:
		farm.coins = 1e18
		farm.debug_unlock_island(island)
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
		farm.coins = farm.bankruptcy_limit()
		farm.storage.russet = 100
		check(farm.recovery_order().needed == 100,"100-crop recovery bound on tax tier %d" % island)
		farm.deliver_recovery()
		check(farm.coins == 0 and farm.storage.russet == 0,"full debt cleared by actual delivery on tier %d" % island)
		if island >= 2:
			farm.coins = -100
			game.hud.show_panel("climate",farm)
			await settle()
			check(not game.hud._refs["climate_fund:rainwater"].disabled,"weather equipment available on credit")
			var level: int = farm.climate.data.projects[str(island)].get("rainwater",0)
			game.hud._refs["climate_fund:rainwater"].pressed.emit()
			check(farm.coins < -100 and farm.climate.data.projects[str(island)].rainwater == level+1,"weather purchase installs equipment and adds debt")
			farm.coins = farm.bankruptcy_limit()
			var snapshot: Dictionary = farm._save_data().duplicate(true)
			farm.climate.fund(farm,"barn")
			check(farm._save_data() == snapshot,"weather purchase cannot cross debt limit")
	farm.coins = -1234
	farm.storage.russet = 4
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.coins == -1234 and farm.recovery_order().quantity == 1,"credit and repayment survive dedicated save roundtrip")
	farm.coins = farm.bankruptcy_limit()-1
	var ended: Dictionary = farm._save_data().duplicate(true)
	farm.deliver_recovery()
	farm.claim_recovery_seeds()
	farm.buy_seeds("russet",1)
	check(farm.run_over and farm._save_data() == ended,"recovery does not bypass ended-run state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await settle()
	print("DEBT CREDIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
