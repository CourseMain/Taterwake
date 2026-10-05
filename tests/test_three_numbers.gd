extends SceneTree
## Segment 21e: human directions and display arithmetic never change transactions.
const Advice = preload("res://scripts/farm_advice.gd")
const Stamp = preload("res://scripts/grade_stamp.gd")
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle() -> void:
	for frame in range(8): await process_frame
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await settle(); game.set_process(false)
	game.year_intro.stop(); game.state.climate_report_open = false
	game.state.tutorial_progress.completed = true; game.state.set_tutorial_active(false); game.hud.set_tutorial({}); game.hud.close_panel()
	var farm = game.state
	var initial: Dictionary = farm.ledger.save_data()
	check(Advice.YEAR_ONE == "The bills are 104,000 a year: mortgage and land 60,000, living 32,000, upkeep 12,000. Twelve beds of Russet make about 45,000 at best. You need more beds, a dearer potato, and no empty beds in Spring or Summer.", "Nell states the owner's arithmetic plainly")
	for season in range(4):
		farm.season_clock.season = season
		check(farm.interact_plot(12, "plant") == "Home bed · open 12 more at the Tools shed, 48,000", "locked Home direction is correct in season " + str(season))
		game.hud.close_panel()
		check(farm.interact_plot(24, "hoe") == "Low Field · lease at the Winter accounts, 55,000 a year", "Low lease direction is field-specific")
		game.hud.close_panel()
		check(farm.interact_plot(48, "hoe") == "Hill Field · lease at the Winter accounts, 9,000 a year", "Hill lease direction is field-specific")
		game.hud.show_panel("tools", farm)
		check(game.hud._refs["upgrade:expansion:detail"].text == "Open more Home beds · 48,000 · any season" and not game.hud._refs["upgrade:expansion"].disabled, "Home purchase remains available in every season")
	check(farm.ledger.save_data() == initial, "reading advice and refused taps leave the journal untouched")
	game.hud.close_panel(); farm.season_clock.season = 0
	game.hud._spring_target.refresh()
	check(game.hud._spring_target.visible, "ordinary Spring opens one estimate")
	var before: Dictionary = Advice.spring(farm)
	farm.select_crop("golden"); game.hud._spring_target.refresh()
	check(Advice.spring(farm).net > before.net and game.hud._spring_target.facts.text.contains(farm.format_number(Advice.spring(farm).net)), "crop selection refreshes the estimate")
	var cash: float = farm.coins
	game._on_action("upgrade:expansion:home")
	game.hud._spring_target.refresh()
	check(farm.field_expansion_info().opened == 24 and farm.coins == cash - 48000, "real Spring Home expansion charges the unchanged 48,000")
	check(Advice.spring(farm).beds == 24, "estimate follows bed openings immediately")
	# Replay the estimate as actual journal entries for every variety, including Low's quarter yields.
	farm.season_clock.season = 3; farm.rent_field("low"); farm.rent_field("hill")
	game.hud.show_panel("tools", farm)
	check(game.hud._refs.expansion_title.text == "Open more Low Field beds", "the workbench names the actual field after Home is fully open")
	game.hud.close_panel()
	for crop in farm.CROP_IDS:
		farm.selected_crop = crop
		var target: Dictionary = Advice.spring(farm)
		var ledger = farm.Ledger.new()
		for plot in farm.plots:
			if not plot.unlocked: continue
			for sowing in range(2):
				var tonnes: int = farm.Land.yield_for({"crop": crop, "field": plot.field, "bed": plot.bed})
				ledger.post(1, sowing, "seeds", crop + " seed", -farm.CropTable.CROPS[crop].seed)
				ledger.post(1, sowing, "sales", "Table " + crop, tonnes * farm.CropTable.CROPS[crop].base * farm.Quality.MULTIPLIER.Table)
		check(is_equal_approx(target.net, ledger.total(1)) and target.bills == 104000 and target.short == maxf(0, 104000 - ledger.total(1)), "two-sowing estimate reconciles with ledger: " + crop)
	farm.season_clock.season = 0; farm.tutorial_progress.completed = false; farm.set_tutorial_active(true)
	game.hud._spring_target.refresh(); check(not game.hud._spring_target.visible, "guided year hides the estimate")
	farm.tutorial_progress.completed = true; farm.set_tutorial_active(false); farm.season_clock.year = 2
	game.hud._spring_target.refresh(); check(game.hud._spring_target.visible and not game.hud._spring_target.collapsed, "next Spring reopens its card")
	game.hud._spring_target.collapsed = true
	farm.season_clock.year = 1; farm.set_tutorial_active(true); game.hud._spring_target.refresh()
	farm.season_clock.year = 2; farm.set_tutorial_active(false); game.hud._spring_target.refresh()
	check(not game.hud._spring_target.collapsed, "a new guided farm cannot inherit the previous farm's folded year-two card")
	farm.season_clock.year = 1; farm.season_clock.season = 3; farm.ledger.post_fixed_costs(1)
	game.hud.show_panel("accounts", farm); await settle()
	var frozen: Dictionary = farm.ledger.save_data(); cash = farm.coins
	check(game.hud._refs.land_bill.text == "Mortgage and land · 60,000" and not game.hud._refs.land_parts.visible, "one land line excludes expansions and leases")
	game.hud._act("land_bill_parts")
	check(game.hud._refs.land_parts.visible and game.hud._refs.land_parts.get_child_count() == 3, "land tap opens the three components")
	check(game.hud._refs["land_part:Mortgage interest"].text == farm.money(24000) and game.hud._refs["land_part:Mortgage principal"].text == farm.money(24000) and game.hud._refs["land_part:Rent and land tax"].text == farm.money(12000), "land parts preserve all three amounts")
	game.hud._act("land_bill_parts")
	check(farm.ledger.save_data() == frozen and farm.coins == cash, "folding bills never posts or changes a balance")
	check(game.hud._body.find_children("*", "Button", true, false).filter(func(button): return button.get_meta("hud_action", "") in ["tools", "market", "barn"]).size() == 1, "accounts have only Go to the barn, with no alternate service routes")
	check(farm.ledger.save_data() == frozen and farm.coins == cash, "advice navigation never buys or sells")
	farm.season_clock.year = 2; game.hud.show_panel("accounts", farm); await settle()
	check(not game.hud._body.find_children("*", "Label", true, false).any(func(label): return label.text.contains(Advice.YEAR_ONE)), "later accounts don't repeat Year-one speech")
	game.hud.close_panel(); farm.season_clock.season = 0
	for crop in farm.CROP_IDS: farm.storage[crop] = farm.Stock.pile()
	for score in [100, 60, 20]: farm.Stock.add(farm.storage, "russet", 3, score)
	root.min_size = Vector2i.ZERO; root.size = Vector2i(390,844)
	game.touch_controls.enabled = true; game.touch_controls._build_touch_sheets(); game.touch_controls.resize()
	await settle()
	for page in ["inventory", "barn"]:
		game.hud.show_panel(page, farm); await settle(); game.touch_controls.fit_modal(); await settle()
		var scale: float = float(root.size.x) / game.hud.root.size.x
		for grade in farm.Quality.GRADES:
			var chip: Control = game.hud._refs["item:crop:russet:grade:" + grade] if page == "inventory" else game.hud._refs.market_page.sale_rows.russet.grades[grade]
			check(chip.is_visible_in_tree() and chip.get_theme_font_size("font_size") * scale >= 14, page + " readable " + grade + " stamp at 390")
			check(chip.get_theme_color("font_color") == Stamp.COLORS[grade], page + " consistent grade ink")
	game.hud.close_panel()
	var fx = game.world.harvest_feedback
	fx.harvest({0:{"stage":3, "crop":"russet", "quality":100}}); fx.animate(.2)
	var pop: Label = fx.active[0].stamp
	check(pop.mouse_filter == Control.MOUSE_FILTER_IGNORE and pop.get_theme_font_size("font_size") * float(root.size.x) / game.hud.root.size.x >= 14, "harvest stamp is readable and passes neighbouring taps through")
	fx.animate(1.18); check(pop.modulate.a > .99, "harvest stamp holds for 1.2 seconds after pop")
	fx.animate(.2); check(pop.modulate.a > 0 and pop.modulate.a < 1, "stamp fades after hold")
	fx.animate(.5); check(fx.active.is_empty(), "faded receipt removes itself")
	for index in [0, 24, 48, 71]:
		fx.harvest({index:{"stage":3, "crop":"russet", "quality":100}}); fx.animate(.2)
		var rect: Rect2 = fx.active[0].stamp.get_global_rect()
		check(not fx._stamp_obstacles().any(func(obstacle): return rect.intersects(obstacle)), "stamp clears every bed and price fact for bed " + str(index))
		fx.animate(2)
	var batch: Dictionary = {}
	for index in range(12): batch[index] = {"stage":3, "crop":"russet", "quality":100}
	fx.harvest(batch); fx.animate(.2)
	var stamp_rects: Array[Rect2] = []
	for entry in fx.active:
		var rect: Rect2 = entry.stamp.get_global_rect()
		check(not stamp_rects.any(func(other): return rect.intersects(other)), "batch stamps remain readable without overlapping each other")
		check(not fx._stamp_obstacles().any(func(obstacle): return rect.intersects(obstacle)), "batch stamp clears beds and price facts")
		stamp_rects.append(rect)
	fx.animate(2)
	game.queue_free(); await settle(); await create_timer(.4).timeout
	print("THREE NUMBERS: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
