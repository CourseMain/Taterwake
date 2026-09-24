extends SceneTree
const SAVE: String = "user://climate_lesson_test_only.json"
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func frames() -> void:
	for _i in range(6): await process_frame
func shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/climate-simple-" + label + ".png")
func same_crops(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in range(a.size()):
		for key in b[i]:
			if a[i].get(key) != b[i][key]: return false
	return true
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.state.debug_unlock_island(3)
	game.state.travel_to(2)
	game.hud.close_panel()
	var farm = game.state
	var console = game.hud._climate_console
	check(farm.climate.data.lesson.stage == "offer" and not farm.climate.data.intro_pending, "arrival offers optional practice without modal lock")
	check(not game.hud._climate_alert.visible and console.visible and console.primary.text.begins_with("Try it"), "one contextual invitation instead of blocking introduction")
	await shot("arrival")
	var clock: float = farm.elapsed
	game._advance_simulation(1.0)
	check(farm.elapsed > clock and farm.climate.data.timer == 90, "invitation permits normal farming while reserving first weather lesson")
	game._climate_action("lesson_skip")
	farm.travel_to(1)
	farm.travel_to(2)
	check(farm.climate.data.lesson.stage == "done" and not console.visible, "dismissal persists on return")
	farm.coins = 1e18
	var crops: Array = farm.plots.duplicate(true)
	game._climate_action("lesson_start")
	check(farm.climate.Lesson.active(farm) and game.selected_tool == "water", "practice starts with useful tool equipped")
	check(farm.climate.data.projects["2"].rainwater == 1, "practice supplies starter tank")
	clock = farm.elapsed
	var bill: Dictionary = farm.blind_cycle.duplicate(true)
	var build_clock: float = game.builds.cooldown
	game._advance_simulation(200)
	check(farm.elapsed == clock and farm.blind_cycle == bill and game.builds.cooldown == build_clock, "practice freezes all simulation clocks and bills")
	check(same_crops(farm.plots, crops), "practice crop visuals never replace actual saved crops")
	check(not game.hud._blind_card.visible, "unrelated tax panel stays out of practice")
	await shot("water")
	game.perform_plot(0, "water")
	check(farm.climate.data.lesson.stage == "water", "unrelated click does not falsely finish instruction")
	game.perform_plot(34, "water")
	check(farm.climate.data.lesson.stage == "area" and farm.climate_info().operations.stress.size() == 2, "watering exact practice bed clears danger and advances automatically")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.climate.data.lesson.stage == "area", "lesson resumes from saved step")
	game._climate_action("target_water")
	check(game.climate_target == "water" and console.primary.text.contains("Cancel"), "area action arms a visible cancellable field choice")
	game.queue_plot(0)
	check(farm.climate.data.lesson.stage == "area", "wrong area keeps lesson and water safe")
	await shot("select")
	game.queue_plot(35)
	check(farm.climate.data.lesson.stage == "success" and game.climate_target.is_empty(), "correct area completes demonstration")
	check(farm.climate_info().operations.stress.is_empty() and console.title.text.contains("RESCUED"), "success visibly clears rings without another Next button")
	await shot("success")
	farm.climate.Lesson.tick(farm, 3.1)
	check(farm.climate.data.lesson.stage == "done" and same_crops(farm.plots, crops), "completion restores original view and crops unchanged")
	check(not console.visible and farm.climate.data.timer >= 90, "practice disappears and leaves preparation time")
	game._climate_action("lesson_start")
	game._climate_action("lesson_skip")
	check(same_crops(farm.plots, crops), "mid-lesson skip preserves all real crops")
	# Real target mechanics: selected area only, no cycling labels or hidden draining.
	for i in [0, 34, 35, 36]:
		farm.plots[i].merge({"unlocked": true, "tilled": true, "watered": false, "stage": 1, "crop": "russet"}, true)
	farm.climate.begin_warning(farm, "drought", 1)
	game._advance_simulation(55)
	game.hud._climate_alert.dismiss()
	var old: float = farm.climate.data.operations.stress["0"]
	var water: float = farm.climate.Operations.local(farm).water
	game._climate_action("target_water")
	game.queue_plot(35)
	check(farm.climate.Operations.local(farm).water == water - 8 and farm.climate.data.operations.stress["35"] == 0 and farm.climate.data.operations.stress["0"] == old, "one direct field choice spends shown water and rescues only its area")
	check(farm.climate.Operations.local(farm).mode == 0, "area action never starts hidden ongoing consumption")
	for level in [1, 2]:
		farm.climate.data.projects["2"].irrigation = level
		water = farm.climate.Operations.local(farm).water
		game._climate_action("target_water")
		game.queue_plot(35)
		check(farm.climate.Operations.local(farm).water == water - (8 - 2 * level), "irrigation level %d applies its advertised area discount" % level)
	farm.climate.data.projects["2"].irrigation = 0
	farm.climate.data.projects["2"].rainwater = 0
	farm.climate.Operations.local(farm).water = 0
	game.hud.update_state(farm)
	check(console.primary_action == "hand" and console.primary.visible, "emergency well remains available without a tank")
	farm.climate.data.projects["2"].rainwater = 1
	farm.climate.Operations.local(farm).water = 36
	game._climate_action("target_water")
	game._climate_action("cancel")
	check(game.climate_target.is_empty(), "cancel reliably returns regular farm controls")
	game._select_tool("pest")
	game.hud.update_state(farm)
	check(console.reserves.text.contains("SPRAYER"), "spray supplies only appear when sprayer selected")
	game._select_tool("water")
	game.hud.update_state(farm)
	check(not console.reserves.text.contains("SPRAYER"), "drought view excludes unrelated spray readout")
	await shot("drought")
	game._advance_simulation(20)
	game.hud._climate_alert.dismiss()
	game.hud.update_state(farm)
	check(console.title.text == "WEATHER CLEARING" and not console.primary.visible and not console.secondary.visible and not console.meter.visible, "recovery shows no emergency controls or misleading drought timer")
	await shot("recovery")
	game.hud.show_panel("climate", farm)
	check(not game.hud._refs.has("climate_control:mode"), "shop removes second control grid too")
	await shot("shop")
	game.hud.close_panel()
	farm.climate.data.phase = "calm"
	farm.climate.data.event = ""
	farm.climate.data.severity = 0
	farm.climate.fund(farm, "drainage")
	farm.climate.begin_warning(farm, "flood", 1)
	game._advance_simulation(45)
	game.hud._climate_alert.dismiss()
	game.hud.update_state(farm)
	check(console.primary.text == "Open drains", "flood has one relevant action")
	console.primary.pressed.emit()
	check(not console.primary.visible and console.hint.text.contains("Drains are open"), "successful drainage removes completed action")
	await shot("flood")
	# Old saves should not force a lesson or retain invisible ration mode.
	var legacy: Dictionary = farm._save_data()
	legacy.mechanics_revision = 16
	legacy.climate.erase("lesson")
	legacy.climate.operations.islands["2"].mode = 2
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(farm.load_game(SAVE) and farm.climate.data.lesson.stage == "done" and farm.climate.Operations.local(farm).mode == 0, "existing farms migrate quietly with old background irrigation stopped")
	var corrupt: Dictionary = farm._save_data()
	corrupt.climate.lesson.stage = "water"
	check(not farm._valid_save(corrupt), "practice cannot be loaded on top of a live disaster")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await create_timer(0.25).timeout
	print("CLIMATE LESSON: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
