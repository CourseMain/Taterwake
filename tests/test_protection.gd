extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Protection = preload("res://scripts/farm_protection.gd")
const SAVE := "user://protection_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh():
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 6
	for plot in farm.plots: farm._clear_crop(plot)
	farm.coins = 30000
	return farm
func winter(farm) -> void:
	farm.season_clock.season = 2; farm.season_clock.seconds = 149.75
	farm.update(0.25)
func plant(farm, index: int, crop: String = "russet") -> void:
	farm._clear_crop(farm.plots[index])
	farm.plots[index].merge({"crop":crop, "tilled":true, "stage":3, "watered":true, "elapsed":State.CropTable.CROPS[crop].grow}, true)
func run() -> void:
	for season in range(3):
		for event in Protection.PROJECT_FOR:
			var stocked = fresh()
			Protection.insure(stocked)
			stocked.season_clock.season = season
			for crop in State.CropTable.IDS: stocked.storage[crop] = 100
			var stock: Dictionary = stocked.storage.duplicate()
			stocked.climate.begin_warning(stocked, event, 1)
			stocked.update(149.75)
			check(stocked.storage == stock, "%s in season %d preserves every barn variety throughout its weather cycle" % [event, season])
			check(stocked.climate.data.protection.losses.is_empty(), "weather on an empty field creates no barn cause cards")
			check(stocked.save_game(SAVE) and stocked.load_game(SAVE), "safe barn stock and field-only weather history survive reload")
			winter(stocked)
			check(stocked.climate.data.protection.winters["1"].payout == 0 and stocked.storage_used() == 450, "Winter storage spoilage remains, without a weather insurance claim")
			stocked.free()
	for event in Protection.PROJECT_FOR:
		for rank in range(3):
			check(Protection.loss(20, Protection.REDUCTION[rank]) == [20, 10, 5][rank], "%s level %d cuts sack losses by 0/50/75 percent" % [event, rank])
			var farm = fresh()
			farm.climate.data.projects[Protection.PROJECT_FOR[event]] = rank
			if event == "freeze" and rank > 0: farm.climate.data.protection.covers["0"] = {"year":1, "level":rank}
			plant(farm, 0, "icecap")
			farm.climate.begin_warning(farm, event, 1)
			farm.climate._impact(farm)
			var quantity: int = Protection.remaining(farm.plots[0])
			Protection.damage(farm, 0, event)
			var lost: int = quantity - Protection.remaining(farm.plots[0])
			check(lost == Protection.loss(quantity, Protection.REDUCTION[rank]), "%s damage uses the shared formula at level %d" % [event, rank])
			var card: Dictionary = farm.climate.data.protection.losses[-1]
			check(card.event == event and card.crop == "icecap" and card.season == 0 and card.sacks == lost and not card.missing.is_empty(), "cause card identifies event, season, crop, sacks and protection")
			check(card.saved == card.sacks - Protection.loss(card.exposed, Protection.REDUCTION[mini(2, rank + 1)]), "counterfactual is the same loss formula with the next protection level")
			check(farm.save_game(SAVE) and farm.load_game(SAVE), "damaged crop and cause card round-trip")
			if rank > 0:
				farm.climate.data.operations.ice.clear()
				farm.storage.icecap = 0
				farm.interact_plot(0, "harvest")
				check(farm.storage.icecap == quantity - lost, "surviving protected sacks can be harvested exactly once")
			farm.free()
	for rank in range(3):
		var field = fresh()
		field.climate.data.projects.rainwater = rank
		field.climate.begin_warning(field, "drought", 1); field.climate._impact(field)
		for bed in range(12):
			plant(field, bed)
			Protection.damage(field, bed, "drought")
			if bed == 4: check(field.save_game(SAVE) and field.load_game(SAVE), "rounding group survives a mid-disaster reload")
		var sacks_left: int = 0
		for plot in field.plots: sacks_left += Protection.remaining(plot)
		check(sacks_left == [0, 18, 27][rank], "twelve three-sack beds deliver exact field-wide protection after rounding")
		check(field.climate.data.protection.losses.size() == 1 and field.climate.data.protection.losses[0].sacks == 36 - sacks_left, "one cause card totals the disaster's matching crop losses")
		var card: Dictionary = field.climate.data.protection.losses[0]
		check(card.saved == card.sacks - Protection.loss(36, Protection.REDUCTION[mini(2, rank + 1)]), "aggregate card counterfactual matches aggregate protection")
		field.free()
	for event in Protection.PROJECT_FOR:
		var damaged = fresh()
		damaged.climate.data.projects[Protection.PROJECT_FOR[event]] = 2
		if event == "freeze": damaged.climate.data.protection.covers["0"] = {"year":1, "level":2}
		plant(damaged, 0)
		damaged.climate.begin_warning(damaged, event, 1); damaged.climate._impact(damaged)
		damaged.climate.data.operations.stress["0"] = 0.99
		damaged.climate.Operations.update(damaged, 30)
		check(Protection.remaining(damaged.plots[0]) == 2, "severe %s cannot repeatedly charge the same bed's protected loss" % event)
		damaged.free()
	var farm = fresh()
	var opening: float = farm.coins
	farm.climate.fund(farm, "rainwater")
	check(farm.coins == opening and farm.climate.data.protection.pending.is_empty(), "Spring cannot pay for Winter construction")
	winter(farm)
	for id in Protection.PROJECT_FOR.values():
		var cost: float = farm.ClimateSystem.PROJECTS[id].cost
		check(cost >= 1500 and cost <= 2500, "first level cost is within the specified range")
		opening = farm.coins
		farm.climate.fund(farm, id)
		check(farm.coins == opening - cost and farm.climate.data.protection.pending[id] == 0 and farm.climate.data.projects.get(id, 0) == 0, "paying reserves materials without granting protection")
		farm.climate.fund(farm, id)
		check(farm.coins == opening - cost, "reservation cannot charge twice")
		Protection.work(farm, id)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "partly built sites survive reload")
	farm.season_clock.seconds = 149.75; farm.update(0.25)
	Protection.work(farm, "rainwater")
	check(farm.climate.data.protection.pending.rainwater == 1 and farm.climate.data.projects.get("rainwater", 0) == 0, "unfinished work carries into Spring without protection or Spring labour")
	winter(farm)
	check(farm.climate.data.protection.winters["2"].upkeep == 0, "unfinished projects do not incur upkeep")
	for id in Protection.PROJECT_FOR.values():
		Protection.work(farm, id); Protection.work(farm, id)
		check(farm.climate.data.projects[id] == 1 and not farm.climate.data.protection.pending.has(id), "third work action completes the reserved level")
	opening = farm.coins
	farm.climate.fund(farm, "rainwater")
	check(farm.coins == opening - 3000 and farm.climate.data.projects.rainwater == 1, "second level costs twice as much and old protection remains while building")
	for i in range(3): Protection.work(farm, "rainwater")
	opening = farm.coins; farm.climate.fund(farm, "rainwater")
	check(farm.climate.data.projects.rainwater == 2 and farm.coins == opening, "completed projects have two levels only")
	Protection.cover(farm, 0)
	check(not farm.climate.data.protection.covers.has("0"), "model refuses covers until bed ice is cleared")
	farm.interact_plot(0, "hoe")
	farm.interact_plot(0, "hoe")
	check(farm.climate.data.protection.covers.is_empty() and not farm.plots[0].winter_ice and not farm.plots[0].tilled, "repeated Winter Hoe only clears ice, without tilling or placing covers")
	Protection.cover(farm, 0)
	check(farm.climate.data.protection.covers.has("0") and not farm.climate.data.protection.covers.has("1"), "explicit cover action protects just the chosen bed")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "placed covers survive Winter reload")
	farm.season_clock.seconds = 149.75; farm.update(0.25)
	check(Protection.level(farm, "freeze", 0) == 1 and Protection.level(farm, "freeze", 1) == 0, "cover protects only its bed in the following Spring")
	farm.season_clock.seconds = 149.75; farm.update(0.25)
	check(farm.climate.data.protection.covers.is_empty(), "Spring covers expire in Summer")
	winter(farm)
	check(farm.climate.data.protection.winters["3"].upkeep == 400, "Winter posts 100 per completed project, independent of level")
	opening = farm.coins
	Protection.winter(farm)
	check(farm.coins == opening and farm.save_game(SAVE) and farm.load_game(SAVE), "upkeep is idempotent across calls and saves")
	farm.free()
	farm = fresh()
	farm.climate.data.projects.frost = 1
	Protection.cover_all(farm)
	check(farm.climate.data.protection.covers.is_empty(), "Spring cannot place covers")
	farm.climate.data.projects.erase("frost")
	winter(farm)
	farm.interact_plot(0, "hoe"); farm.interact_plot(1, "hoe")
	farm.plots[12].winter_ice = false
	Protection.cover_all(farm)
	check(farm.climate.data.protection.covers.is_empty(), "cover all requires a completed frost project")
	farm.climate.data.projects.frost = 1
	farm.accounts_open = true
	Protection.cover_all(farm)
	check(farm.climate.data.protection.covers.is_empty(), "accounts pause prevents cover placement")
	farm.accounts_open = false
	Protection.cover_all(farm)
	check(farm.climate.data.protection.covers.size() == 2 and farm.climate.data.protection.covers.has("0") and farm.climate.data.protection.covers.has("1"), "cover all includes cleared open beds and excludes ice and locked beds")
	var covers: Dictionary = farm.climate.data.protection.covers.duplicate(true)
	opening = farm.coins
	Protection.cover_all(farm)
	check(farm.climate.data.protection.covers == covers and farm.coins == opening, "repeating cover all is idempotent and does not charge")
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "batch-placed covers survive reload")
	farm.free()
	farm = fresh()
	plant(farm, 0)
	Protection.damage(farm, 0, "")
	Protection.insure(farm)
	check(farm.save_game(SAVE) and farm.load_game(SAVE), "Spring insurance and pre-policy losses survive reload")
	opening = farm.coins
	Protection.insure(farm)
	check(farm.coins == opening and farm.ledger.total(1, "insurance") == -400, "annual premium posts once")
	plant(farm, 1, "giant")
	farm.climate.begin_warning(farm, "drought", 1); farm.climate._impact(farm)
	Protection.damage(farm, 1, "drought")
	var claim: float = State.CropTable.CROPS.giant.yield * State.CropTable.CROPS.giant.base * 0.4
	farm.boundary_save_path = SAVE
	winter(farm)
	check(is_equal_approx(farm.ledger.total(1, "insurance"), claim - 400), "insurance pays forty percent at base price, excluding losses before purchase")
	check(farm.load_game(SAVE) and is_equal_approx(farm.climate.data.protection.winters["1"].payout, claim), "boundary save contains insurance settlement before accounts")
	opening = farm.coins; Protection.winter(farm)
	check(farm.coins == opening, "claims cannot be paid twice")
	var broken: Dictionary = farm._save_data(); broken.climate.protection.losses[0].saved += 1
	check(not farm._valid_save(broken), "cause-card counterfactual tampering is rejected")
	broken = farm._save_data(); broken.climate.protection.winters["1"].payout += 1
	check(not farm._valid_save(broken), "insurance report must match both crop losses and the journal")
	broken = farm._save_data(); broken.climate.protection.pending.rainwater = 0
	check(not farm._valid_save(broken), "unpaid construction reservations are rejected")
	broken = farm._save_data(); broken.climate.protection.pending.rainwater = 3
	check(not farm._valid_save(broken), "completed work cannot remain pending in a save")
	for season in range(4):
		farm.season_clock.season = season
		for station in range(3):
			farm.climate.data.protection.station = station
			var f: Dictionary = Protection.forecast(farm)
			check(f.low <= f.chance and f.high >= f.chance and f.low >= 0 and f.high <= 1, "forecast brackets actual chance and clips to probability bounds")
			for event in f.events:
				var risk: Dictionary = f.events[event]
				check(risk.low <= risk.chance and risk.high >= risk.chance and is_equal_approx(risk.chance, f.chance / 4), "event forecast brackets its actual uniform-choice probability")
			if int(f.season) != 3: check(is_equal_approx(f.high - f.chance, [0.20, 0.10, 0.05][station]), "station accuracy uses percentage points")
	farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("PROTECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.state.coins = 30000
	plant(game.state, 0, "giant")
	Protection.damage(game.state, 0, "")
	game.hud.show_panel("loss_notices", game.state)
	var notices: String = ""
	for label in game.hud._body.find_children("*", "Label", true, false): notices += label.text
	check(notices.contains("Spring") and notices.contains("5 sacks lost") and notices.contains("Giant"), "season notice cards expose the actual crop loss")
	game.hud.close_panel()
	winter(game.state); game.hud.close_panel()
	game._on_action("climate_fund:rainwater")
	check(game.world._work_nodes.has("rainwater"), "paid project has a visible clickable construction site")
	await world_shot("site", game)
	for i in range(3):
		game._on_action("project_site:rainwater")
		check(game.walking and game.state.climate.data.projects.get("rainwater", 0) == 0, "construction must walk to the site before working")
		for step in range(600):
			game._process(0.05)
			if game.pending_project.is_empty(): break
	check(game.state.climate.data.projects.get("rainwater", 0) == 1 and not game.world._work_nodes.has("rainwater"), "three walked, timed hoe actions finish the site")
	game.state.climate.data.projects.frost = 1
	game.perform_plot(0, "hoe"); game.perform_plot(0, "hoe")
	check(not game.world._cover_nodes.has("0"), "world Hoe action never places frost covers")
	game.world.set_player_position(game.world.plot_positions[0] + Vector3(0, 0, 0.65))
	game.touch_controls.update_interaction_prompt()
	check(game.bed_context().get("plot_index", -1) == 0 and game.touch_controls.interaction_prompt.tooltip_text.contains("Cover bed"), "cleared bed offers its own cover context action")
	game.touch_controls.interaction_prompt.pressed.emit()
	check(game.world._cover_nodes.has("0") and game.state.climate.data.protection.covers.size() == 1, "bed context action renders exactly one frost cover")
	game._interact_nearby()
	check(game.state.climate.data.protection.covers.size() == 1, "repeated nearby action cannot cover a different bed")
	game.perform_plot(1, "hoe")
	await world_shot("cover", game)
	game._on_action("climate")
	check(game.hud._refs.cover_all.text == "Cover all cleared beds" and not game.hud._refs.cover_all.disabled, "weather page offers the explicit batch cover control")
	game.hud._refs.cover_all.pressed.emit()
	check(game.world._cover_nodes.has("1") and game.state.climate.data.protection.covers.size() == 2 and game.hud._refs.cover_all.disabled, "weather control covers remaining cleared beds and disables when done")
	check(game.hud._refs.forecast_range.text.contains("Next Spring") and game.hud._refs.insurance.disabled, "weather page shows next season and annual insurance gate")
	for size in [Vector2i(1280, 800), Vector2i(390, 844)]:
		root.size = size
		if game.touch_controls.enabled: game.touch_controls.resize()
		for page in ["climate", "loss_notices", "accounts"]:
			game.hud.show_panel(page, game.state)
			if page == "accounts":
				var account_words: String = ""
				for label in game.hud._body.find_children("*", "Label", true, false): account_words += label.text
				check(account_words.contains("5 sacks lost") and account_words.contains("Water this bed"), "Winter accounts retain the Spring cause card")
			for i in range(10): await process_frame
			check(game.hud._body.get_combined_minimum_size().x <= game.hud._body.get_parent().size.x + 1, page + " fits available width")
			if "--capture" in OS.get_cmdline_user_args():
				await create_timer(0.25).timeout
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://artifacts/protection-%s-%d.png" % [page, size.x])
				if page in ["accounts", "climate"]:
					game.hud._body.get_parent().scroll_vertical = 100000
					await create_timer(0.15).timeout
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://artifacts/protection-%s-bottom-%d.png" % [page, size.x])
	game.queue_free(); await process_frame; await create_timer(0.25).timeout

func world_shot(label: String, game) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	for i in range(6): await process_frame
	game.world.set_day_time(75, true)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/protection-" + label + ".png")
