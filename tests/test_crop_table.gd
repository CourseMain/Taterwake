extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
const Table = preload("res://scripts/crop_table.gd")
const State = preload("res://scripts/game_state.gd")
const SAVE := "user://crop_table_test_only.json"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh():
	var farm = State.new()
	root.add_child(farm)
	farm.rng.seed = 6
	for plot in farm.plots: farm._clear_crop(plot); plot.tilled = true
	return farm
func stress(crop: String, event: String = "") -> float:
	var farm = fresh()
	farm.selected_crop = crop; farm.seed_inventory[crop] = 1
	farm.interact_plot(5, "plant")
	if not event.is_empty():
		farm.interact_plot(5, "water")
		farm.climate.begin_warning(farm, event, 1)
		farm.climate._impact(farm)
	farm.climate.Operations.update(farm, 1)
	var result: float = farm.climate.data.operations.stress.get("5", 0)
	farm.free()
	return result
func run() -> void:
	check(Table.IDS == ["russet", "giant", "golden", "sunburst", "icecap"] and Table.CROPS.size() == 5, "exactly five varieties in one table")
	var last_price: float = 0
	var last_tolerance: int = 10
	for id in Table.IDS:
		var crop: Dictionary = Table.CROPS[id]
		check(crop.seed > 0 and crop.seed <= crop.base and crop["yield"] >= 2 and crop["yield"] <= 5, id + " has legible seed cost and yield")
		check(crop.base > last_price and Table.total_tolerance(id) < last_tolerance, id + " pays more for lower combined water/heat/cold resilience")
		last_price = crop.base; last_tolerance = Table.total_tolerance(id)
		for dial in ["water_need", "heat_tolerance", "cold_tolerance"]: check(crop[dial] in [1, 2, 3], id + " bounded " + dial)
		check(crop.grow_seasons in [1, 2] and crop.grow <= crop.grow_seasons * 150 and crop.grow > (crop.grow_seasons - 1) * 150, id + " ripens within its advertised season budget")
		check(Table.VOLATILITY.has(crop.volatility), id + " has known volatility")
	var farm = fresh()
	for id in Table.IDS:
		for second in [150, 450]:
			farm.elapsed = second; farm._refresh_market()
			var expected: float = Table.CROPS[id].base * (1 + Table.drift(id) * (1 if second == 150 else -1))
			check(is_equal_approx(farm.market[id].sell, expected), id + " volatility controls drift endpoints")
	check(farm.last_year_price("russet") == 0, "first year does not invent a previous price")
	farm.season_clock.year = 2
	check(farm.last_year_price("icecap") == Table.CROPS.icecap.base, "full previous annual price cycle averages to base")
	farm.free()
	check(stress("icecap") > stress("sunburst") and stress("sunburst") > stress("russet"), "unwatered stress scales with water need")
	check(stress("golden", "drought") > stress("russet", "drought"), "heat tolerance scales drought stress at equal water need")
	check(stress("icecap", "drought") > stress("russet", "drought"), "thirsty heat-fragile crop takes more drought stress")
	check(stress("sunburst", "freeze") > stress("icecap", "freeze"), "cold tolerance scales freeze stress")
	farm = fresh()
	farm.interact_plot(5, "plant"); farm.climate.Operations.update(farm, 10)
	farm.interact_plot(5, "water")
	check(farm.climate.data.operations.stress["5"] == 0, "watering relieves ordinary dry-bed stress")
	farm.free()
	farm = fresh()
	farm.climate.data.projects.irrigation = 1
	farm.interact_plot(5, "plant"); farm.climate.Operations.update(farm, 10)
	farm.climate.Operations.target(farm, 5, "water")
	check(farm.plots[5].watered and farm.climate.data.operations.stress["5"] == 0, "sprinklers relieve ordinary dry-bed stress")
	farm.free()
	for autumn_second in [0, 100]:
		farm = fresh()
		farm.season_clock.season = 2; farm.season_clock.seconds = autumn_second
		farm.seed_inventory.icecap = 1; farm.selected_crop = "icecap"
		farm.interact_plot(5, "plant"); farm.interact_plot(5, "water")
		check(farm.plots[5].stage == 2, "Icecap plants into prepared Autumn soil")
		farm.update(150 - autumn_second)
		check(farm.plots[5].stage == 2 and farm.plots[5].winter_ice and farm.season_clock.autumn_loss == 0, "Icecap survives Autumn clearing on an iced bed")
		check(farm.winter_notice().contains("Icecap survives in 1 bed"), "Winter notice explains surviving Icecap")
		check(farm.save_game(SAVE) and farm.load_game(SAVE), "living Winter Icecap is valid saved state")
		farm.update(75 + autumn_second)
		check(farm.plots[5].stage == 3 and farm.plots[5].winter_ice and farm.season_clock.season == (3 if autumn_second == 0 else 0), "Icecap ripens through Winter ice or early Spring")
		farm.interact_plot(5, "harvest")
		check(Stock.count(farm.storage, "icecap") == Table.CROPS.icecap.yield and farm.plots[5].winter_ice, "Icecap harvest works through uncleared bed ice")
		check(farm.save_game(SAVE) and farm.load_game(SAVE), "harvested Icecap bed remains valid saved state")
		var before: float = farm.coins
		farm.sell_crop("icecap")
		check(farm.coins > before and farm.ledger.total(farm.season_clock.year, "sales") > 0, "Icecap turns winter labour into recorded sales")
		farm.free()
	farm = fresh()
	farm.plots[5].crop = "icecap"; farm.plots[5].winter_ice = true
	farm.selected_crop = "icecap"; farm.seed_inventory.icecap = 1
	farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 0, "an empty iced bed needs clearing before new planting")
	farm.interact_plot(5, "hoe"); farm.interact_plot(5, "plant")
	check(farm.plots[5].stage == 1, "clearing the old Icecap bed permits Spring planting")
	farm.free()
	await ui_checks()
	for suffix in ["", ".bak", ".rejected", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("CROP TABLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.hud.show_panel("market", game.state)
	for i in range(5): await process_frame
	var page = game.hud._refs.market_page
	check(page.grid.get_child_count() == 5, "Buy Seeds has one card for each variety")
	var balance: float = game.state.coins
	game.hud._refs["icecap:select"].pressed.emit()
	check(game.state.selected_crop == "icecap" and game.selected_tool == "plant" and game.state.coins == balance, "selecting a card selects the seed tool without buying")
	for size in [Vector2i(1280, 800), Vector2i(390, 844)]:
		root.size = size
		if game.touch_controls.enabled:
			game.touch_controls.resize()
		else:
			root.content_scale_size = size
			game.hud._modal_card.offset_left = -minf(500, size.x * 0.5 - 12)
			game.hud._modal_card.offset_right = minf(500, size.x * 0.5 - 12)
		for i in range(8): await process_frame
		page._layout()
		for i in range(8): await process_frame
		check(page.grid.columns == ((3 if game.touch_controls.enabled else 5) if size.x == 1280 else 1), "five-card row becomes a phone column")
		for id in Table.IDS:
			for dial in ["water_need", "heat_tolerance", "cold_tolerance"]:
				var bars = page.find_child(id + "_" + dial, true, false)
				check(bars.get_child_count() == 3 and bars.get_meta("value") == Table.CROPS[id][dial], "three readable bar segments reflect " + id + " " + dial)
				check(bars.get_global_rect().position.x >= 0 and bars.get_global_rect().end.x <= game.hud.root.size.x, "dial fits phone/desktop width")
		if "--capture" in OS.get_cmdline_user_args():
			await create_timer(.2).timeout
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/crop-cards-%d.png" % size.x)
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
