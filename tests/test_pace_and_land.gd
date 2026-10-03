extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Ops = preload("res://scripts/climate_operations.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func plant(farm, index: int, crop: String = "russet") -> void:
	var p: Dictionary = farm.plots[index]
	farm._clear_crop(p)
	p.crop = crop; p.stage = 2; p.watered = true; p.tilled = true
func run() -> void:
	var arrivals: Array[int] = [0, 0, 0]
	for season in [0, 1, 3]:
		for seed_value in range(1, 81):
			var farm = State.new()
			farm.rng.seed = seed_value
			farm.season_clock.season = season
			farm.climate.data.outlook.started = season
			for p in farm.plots: farm._clear_crop(p)
			var crop: String = farm.CROP_IDS[(seed_value - 1) % 5]
			var grow: float = farm.CropTable.CROPS[crop].grow
			for i in range(12): plant(farm, i, crop)
			var seen: Dictionary = {}
			for tick in range(ceili(grow * 0.6 * 4) + 1):
				farm.update(0.25)
				for i in range(12):
					var p: Dictionary = farm.plots[i]
					if p.pests and not seen.has(i):
						seen[i] = true
						arrivals[[0, 1, 3].find(season)] += 1
						check(p.plant_age >= grow * 0.25 and p.plant_age <= grow * 0.6 + 0.00001 and p.stage != 3, "first pests arrive at 25–60% before ripening")
			for i in range(12):
				var p: Dictionary = farm.plots[i]
				if p.stage > 0:
					p.stage = 3; p.elapsed = grow; p.watered = true
					p.pests = false
			farm.update(20)
			check(farm.plots.all(func(p): return not p.pests), "no first infestation after ripening")
			farm.free()
	check(arrivals[0] > 100 and arrivals[1] > arrivals[0] * 1.25 and arrivals[1] < arrivals[0] * 1.8, "Summer multiplies pest probability by 1.5")
	check(arrivals[2] == 0, "Winter pest pressure is zero")
	var farm = State.new()
	farm.season_clock.season = 3
	farm._season_boundary()
	var before: float = farm.ledger.total(1, "rent")
	farm.rent_field("low"); farm.rent_field("hill")
	check(farm.ledger.total(1, "rent") == before - 64000, "both annual rents post under rent")
	check(farm.field_expansion_info("low").opened == 12 and farm.field_expansion_info("hill").opened == 12, "rent opens only first halves")
	farm.expand_field("low")
	check(farm.field_expansion_info("low").opened == 24 and farm.field_expansion_info("home").opened == 12 and farm.field_expansion_info("hill").opened == 12, "expansion is local to the paid field")
	farm.Land.renew(farm)
	check(farm.ledger.total(1, "rent") == before - 64000 - farm.FIELD_EXPANSION_COST, "renewal cannot double charge")
	farm.rent_field("low", false)
	check(farm.field_expansion_info("low").opened == 0 and farm.ledger.total(1, "rent") == before - 9000 - farm.FIELD_EXPANSION_COST, "Winter cancellation refunds renewal and closes beds")
	farm.rent_field("low")
	check(farm.field_expansion_info("low").opened == 24, "paid expansion survives cancellation")
	check(farm._valid_save(JSON.parse_string(JSON.stringify(farm._save_data()))), "leases and bed ownership round trip")
	farm.rent_field("hill", false)
	farm.season_clock.year = 2
	before = farm.coins
	farm.Land.renew(farm)
	check(farm.coins == before - 55000, "next Winter charges only the retained lease")
	farm.season_clock.season = 0
	farm.rent_field("hill")
	check(not farm.land.hill.rented, "rent decisions restricted to Winter")
	farm.land.hill.rented = true; farm.Land.sync(farm)
	for crop in farm.CROP_IDS:
		var total := 0
		for i in range(24, 36):
			farm.plots[i].crop = crop
			total += farm.Land.yield_for(farm.plots[i])
		check(total == int(farm.CropTable.CROPS[crop].yield) * 15, "Low half-field yields exactly 25% more " + crop)
	for event in ["flood", "drought", "storm", "freeze"]:
		farm.climate.data.operations = Ops.fresh()
		farm.climate.data.event = event; farm.climate.data.phase = "active"; farm.climate.data.severity = 1.0
		for i in [0, 24, 48]:
			plant(farm, i, "golden")
			farm.climate.data.operations.ice[str(i)] = true
		Ops._tick(farm, 0.25)
		var home: float = farm.climate.data.operations.stress["0"] / farm.Land.exposure("home", event)
		for i in [24, 48]:
			check(is_equal_approx(farm.climate.data.operations.stress[str(i)], home * farm.Land.exposure(farm.Land.id(i), event)), "field stress multiplier " + event + " " + farm.Land.id(i))
	for event in ["flood", "drought"]:
		farm.climate.data.operations = Ops.fresh()
		farm.climate.data.last = {"field_lost":0,"field_total":3}
		farm.climate.data.event = event; farm.climate.data.phase = "active"
		for i in [0, 24, 48]: plant(farm, i, "golden")
		for tick in range(120):
			Ops._tick(farm, 0.25)
			if not farm.climate.data.operations.damaged.is_empty(): break
		var first: int = int(farm.climate.data.operations.damaged.keys()[0])
		check(farm.Land.id(first) == ("low" if event == "flood" else "hill"), "exposed field takes the first " + event + " loss")
	farm.climate.data.last = {"field_lost":0,"field_total":3}
	farm.climate.data.operations = Ops.fresh()
	plant(farm, 24, "golden")
	farm.ClimateSystem.Protection.damage(farm, 24, "flood")
	var card: Dictionary = farm.climate.data.protection.losses.back()
	check(card.field == "low" and farm.ClimateSystem.Protection.text(card).contains("Low Field"), "cause card names the affected field")
	farm.free()
	# A calm first Spring permits a complete second sowing without a cooldown.
	farm = State.new(); farm.rng.seed = 6
	for p in farm.plots: farm._clear_crop(p)
	for cycle in range(2):
		for action in ["hoe", "plant", "water"]: farm.interact_plot(5, action)
		farm.plots[5].pest_checked = true
		farm.update(60)
		farm.interact_plot(5, "harvest")
		check(farm.plots[5].stage == 0 and not farm.plots[5].tilled, "harvest leaves an immediately tillable bed")
	check(farm.stock_count("russet") == 6 and farm.season_clock.season == 0, "two Russet harvests fit Spring")
	# A flock can reach shore and hill targets using the ordinary patrol policy.
	farm.season_clock.season = 3; farm._season_boundary()
	farm.rent_field("low"); farm.rent_field("hill")
	var ducks = preload("res://scripts/island_activities.gd").new()
	ducks.setup(farm); farm.activity_system = ducks
	ducks.hire_duck(); ducks.hire_duck()
	for i in [24, 48]:
		plant(farm, i); farm.plots[i].pests = true; farm.plots[i].pest_checked = true
	ducks.update(ducks.duck_interval())
	check(not farm.plots[24].pests and not farm.plots[48].pests, "ducks patrol both rented fields")
	plant(farm, 24, "icecap")
	farm.rent_field("low", false)
	check(farm.plots[24].stage == 0 and farm.climate.data.protection.losses.back().field == "low" and not farm.climate.data.protection.losses.back().insured, "returning standing crops records their field without an insurance windfall")
	ducks.free(); farm.free()
	# Real scene controller, real frame deltas; input decisions get 12 seconds each.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	game.state.buy_seeds("russet", 1)
	for action in ["hoe", "plant", "water"]: game.state.interact_plot(5, action)
	game.state.tutorial_progress.step = 5
	check(game._simulation_delta(1) == 10, "guided waits stay at ten times speed")
	var wall: float = 6 * 12.0
	while game.state.tutorial_loss().is_empty() and wall < 290:
		game._process(0.1); wall += 0.1
	check(is_equal_approx(game.state.season_clock.seconds, 8), "guided storm lands at Summer second 8")
	check(game.state.tutorial_loss().get("sacks") == 1, "scripted storm loses one of three tonnes")
	check(game._simulation_delta(1) == 1, "cause card returns time scale to one")
	var clock: float = game.state.elapsed
	game._process(12); wall += 12
	check(game.state.elapsed == clock, "reading the cause card pauses simulation")
	game.hud.close_panel()
	game.state.tutorial_progress.step = 7
	game.state.interact_plot(5, "harvest")
	game.state.tutorial_progress.step = 9
	game.state.tutorial_progress.choice = "store"
	while game.state.season_clock.season != 3 and wall < 300:
		game._process(0.1); wall += 0.1
	check(wall < 220 and game.state.accounts_open and game.hud._panel_kind == "accounts", "ten-times waits reach accounts with a real-time storm warning and reading allowance")
	check(game.world.plot_positions.size() == 72, "all three fields drawn")
	for i in [0, 24, 48]:
		var pos: Vector3 = game.world.plot_positions[i]
		check(game.world.clamp_walk_position(pos).is_equal_approx(pos), "field beds inside walkable bounds")
	game._on_action("lease:low")
	check(game.state.land.low.rented and game.state.field_expansion_info("low").opened == 12, "accounts action rents the shore field")
	root.min_size = Vector2i.ZERO; root.size = Vector2i(600, 900)
	for frame in range(8): await process_frame
	check(game.hud._body.get_combined_minimum_size().x <= game.hud._body.size.x + 1, "rental controls fit phone-width accounts")
	game._on_action("lease:hill")
	game.hud.close_panel()
	for index in [24, 48]:
		var destination: Vector3 = game.world.plot_positions[index]
		game._start_walk(destination)
		for frame in range(1200):
			game._process(0.04)
			if not game.walking: break
		check(not game.walking and game.world.player.position.is_equal_approx(destination), "farmer walks to " + game.state.Land.NAMES[game.state.Land.id(index)])
	print("Guided first accounts: %.1f real seconds including decision allowance" % wall)
	game.queue_free()
	await create_timer(0.4).timeout
	print("Pace and land: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
