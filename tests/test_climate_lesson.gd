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
			if a[i].get(key) is float or b[i][key] is float:
				if not is_equal_approx(float(a[i].get(key)), float(b[i][key])): return false
			elif a[i].get(key) != b[i][key]: return false
	return true
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.state.climate.reset()
	game.state.season_clock.seconds = 1.0
	game.hud.close_panel()
	var farm = game.state
	var console = game.hud._climate_console
	farm.coins = 1e18
	farm.climate.fund(farm,"irrigation")
	var crops: Array = farm.plots.duplicate(true)
	game._climate_action("lesson_start")
	check(farm.climate.Lesson.active(farm) and game.selected_tool == "water", "practice starts with useful tool equipped")
	check(farm.climate.Operations.capacity(farm) == 36, "practice uses the familiar starter tank without an extra upgrade")
	var clock: float = farm.elapsed
	game._advance_simulation(200)
	check(farm.elapsed == clock, "practice freezes all simulation clocks and bills")
	check(same_crops(farm.plots, crops), "practice crop visuals never replace actual saved crops")
	await shot("water")
	game.perform_plot(0, "water")
	check(farm.climate.data.lesson.stage == "water", "unrelated click does not falsely finish instruction")
	var can_before: float = farm.climate.Operations.local(farm).can
	var tank_before: float = farm.climate.Operations.local(farm).water
	game.perform_plot(18, "water")
	check(farm.climate.data.lesson.stage == "area" and farm.climate_info().operations.stress.size() == 2, "watering exact practice bed clears danger and advances automatically")
	check(farm.climate.Operations.local(farm).can == can_before - 1 and farm.climate.Operations.local(farm).water == tank_before, "first practice action uses one carried water and leaves the tank alone")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.climate.data.lesson.stage == "area", "lesson resumes from saved step")
	game._select_equipment("sprinkler0")
	console.primary.pressed.emit()
	check(farm.climate.data.lesson.stage == "area" and farm.climate.Operations.local(farm).water == tank_before, "wrong fixed sprinkler leaves the lesson and reserve unchanged")
	game._climate_action("show_sprinkler")
	check(console.equipment == "sprinkler2" and console.primary_action == "use_sprinkler" and game.climate_target.is_empty(), "practice selects the actual near sprinkler without an extra targeting mode")
	check(console.primary.text == "Water these beds · 6 water" and game.world._climate_field.loop.selected == "sprinkler2", "selected sprinkler reveals its connection and exact resource cost")
	await shot("select")
	console.primary.pressed.emit()
	check(farm.climate.data.lesson.stage == "success" and console.equipment.is_empty(), "using the connected sprinkler completes practice and dismisses the equipment prompt")
	check(farm.climate.Operations.local(farm).water == tank_before - 6 and farm.climate.Operations.local(farm).can == can_before - 1, "sprinkler practice spends six tank water without consuming carried water")
	check(farm.climate_info().operations.stress.is_empty() and not console.primary.visible and not console.secondary.visible, "success visibly clears rings and finishes without another Next button")
	await shot("success")
	farm.climate.Lesson.tick(farm, 3.1)
	check(farm.climate.data.lesson.stage == "done" and same_crops(farm.plots, crops), "completion restores original view and crops unchanged")
	check(not console.visible and farm.climate.data.timer >= 90, "practice disappears and leaves preparation time")
	game._climate_action("lesson_start")
	game._climate_action("lesson_skip")
	check(same_crops(farm.plots, crops), "mid-lesson skip preserves all real crops")
	# The same fixed sprinkler works in ordinary weather before drought arrives.
	for i in [0, 18, 19, 20]:
		farm.plots[i].merge({"unlocked": true, "tilled": true, "watered": false, "stage": 1, "crop": "russet"}, true)
	var water: float = farm.climate.Operations.local(farm).water
	game._climate_action("show_sprinkler")
	console.primary.pressed.emit()
	check(farm.climate.Operations.local(farm).water == water - 6 and farm.plots[19].watered and not farm.plots[0].watered, "ordinary sprinkler spends tank water and hydrates only its fixed patch")
	water = farm.climate.Operations.local(farm).water
	game._climate_action("show_sprinkler")
	console.primary.pressed.emit()
	check(farm.climate.Operations.local(farm).water == water and console.equipment == "sprinkler2", "reusing already watered beds spends nothing and leaves the action card available")
	game._climate_action("close_equipment")
	farm.climate.begin_warning(farm, "drought", 1)
	game._advance_simulation(55)
	game.hud._climate_alert.dismiss()
	var old: float = farm.climate.data.operations.stress["0"]
	for level in [1, 2]:
		farm.climate.data.projects.irrigation = level
		for index in [18, 19, 20]:
			# Weather and pests may already have damaged these crops.
			# Start fresh planted beds for each connected-sprinkler check.
			farm._clear_crop(farm.plots[index])
			farm.plots[index].merge({"unlocked": true, "tilled": true, "stage": 2, "crop": "russet", "watered": true}, true)
			farm.climate.data.operations.stress[str(index)] = 0.6
			farm.climate.data.operations.wet[str(index)] = 0.0
		water = farm.climate.Operations.local(farm).water
		game._climate_action("show_sprinkler")
		var cost: int = 8 - 2 * level
		check(console.primary.text == "Water these beds · %d water" % cost, "irrigation level %d advertises its exact tank cost" % level)
		console.primary.pressed.emit()
		check(farm.climate.Operations.local(farm).water == water - cost and farm.climate.data.operations.stress["19"] == 0 and farm.climate.data.operations.stress["0"] == old, "irrigation level %d spends shown water and relieves only its connected beds" % level)
	check(farm.climate.Operations.local(farm).mode == 0, "sprinklers never start hidden ongoing consumption")
	farm.climate.Operations.local(farm).water = 0
	farm.climate.Operations.local(farm).can = 8
	game._select_equipment("tank")
	check(console.primary.disabled and console.hint.text.contains("Rain returns") and not console.secondary.visible, "empty drought tank explains replenishment without an invisible water source")
	game._climate_action("show_sprinkler")
	check(console.primary.disabled and console.primary.text == "Water these beds · 4 water", "empty reserve disables the familiar sprinkler action while preserving its cost")
	game._advance_simulation(0.5)
	check(farm.climate.Operations.local(farm).water == 0, "dry-spell reserve does not silently refill")
	farm.climate.Operations.local(farm).water = 36
	game._climate_action("close_equipment")
	check(console.equipment.is_empty() and game.world._climate_field.loop.selected.is_empty(), "closing equipment removes selection and returns ordinary farm controls")
	game._select_tool("pest")
	game.hud.update_state(farm)
	check(console.reserves.text.to_upper().contains("SPRAYER"), "spray supplies only appear when sprayer selected")
	game._select_tool("water")
	game.hud.update_state(farm)
	check(not console.reserves.text.to_upper().contains("SPRAYER"), "drought view excludes unrelated spray readout")
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
	check(console.primary_action == "show_drain", "flood points players to its relevant world equipment")
	console.primary.pressed.emit()
	check(console.equipment == "drain" and console.primary.text == "Open drain" and not console.meter.visible, "drain card offers the concrete action without an unrelated water reserve meter")
	console.primary.pressed.emit()
	check(farm.climate.Operations.local(farm).gates and console.equipment.is_empty() and not console.primary.visible and console.hint.text.contains("Drains are open"), "opening the gate dismisses its prompt and shows the completed flood response")
	await shot("flood")
	var corrupt: Dictionary = farm._save_data()
	corrupt.climate.lesson.stage = "water"
	check(not farm._valid_save(corrupt), "practice cannot be loaded on top of a live disaster")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.queue_free()
	await create_timer(0.25).timeout
	print("CLIMATE LESSON: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
