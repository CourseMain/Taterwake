extends SceneTree
const Ops = preload("res://scripts/climate_operations.gd")
var game
var checks := 0
var failures := 0
const SAVE := "user://taterland_weather_station_test_only.json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in range(8): await process_frame
func footprint(body: StaticBody3D) -> Rect2:
	var half: Vector3 = body.get_child(0).shape.size * 0.5
	var a: Vector3 = body.to_global(-half)
	var b: Vector3 = body.to_global(half)
	return Rect2(Vector2(a.x,a.z),Vector2(b.x-a.x,b.z-a.z)).abs()
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.debug_unlock_island(3)
	farm.coins = 1e18
	farm.climate.data.introduced = false
	farm.travel_to(2)
	await frames()
	check(farm.climate.data.intro_pending and game.hud._climate_intro.visible,"first Shores arrival plays cinematic")
	var time: float = farm.elapsed
	farm.update(10)
	check(farm.elapsed == time,"cinematic pauses farm time")
	check(not farm.climate.data.projects["2"].has("irrigation"),"arrival never gives free sprinklers")
	game.hud._climate_intro.elapsed = 5
	game.hud._climate_intro._process(0)
	check(game.hud._climate_intro.chapter.text == "GOLDEN SHORES" and game.hud._climate_intro.find_children("*", "Label", true, false).size() == 1, "arrival keeps the island title without filler subtitles")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.climate.data.intro_pending,"arrival cinema survives reload without advancing the farm")
	game.hud._climate_intro.skip.pressed.emit()
	check(game.conversation.visible and game.conversation.npc_id == "iris", "arrival introduces Iris before station")
	game.conversation.choose(0)
	check(not farm.climate.data.intro_pending and game.hud._panel_kind == "climate","skip opens weather station safely")
	check(game.hud._refs.protection_summary.visible,"protection stats are immediately visible")
	check(not game.world._project_nodes.has("irrigation"),"no unbought sprinkler geometry")
	farm.climate.Lesson.start(farm)
	check(not farm.climate.Lesson.active(farm),"lesson cannot grant irrigation")
	var coins: float = farm.coins
	farm.climate.fund(farm,"irrigation")
	check(farm.coins < coins,"sprinklers cost coins")
	for island in [1,2,3]:
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
		game._on_state_changed()
		await frames()
		check(farm.climate.data.projects[str(island)].irrigation == 1,"owned sprinklers carry to island %d" % island)
		check(game.world._project_nodes.has("irrigation"),"owned sprinkler geometry exists")
		check(is_instance_valid(game.world.weather_station) == (island>=2),"weather station only on later islands")
		if island>=2:
			var before: float = game.world.weather_station.dish.rotation.y
			game.world.weather_station._process(0.5)
			check(game.world.weather_station.dish.rotation.y != before,"dish scans back and forth")
		for a in game.world._interaction_targets:
			var aid: String = str(a.get_meta("station"))
			if aid not in ["equipment:tank","duck_patrol","climate"]: continue
			for b in game.world._interaction_targets:
				var bid: String = str(b.get_meta("station"))
				if a==b or aid==bid or bid in ["island","equipment:barn"]: continue
				check(not footprint(a).grow(0.3).intersects(footprint(b)),"clear interaction space island %d: %s / %s" % [island,aid,bid])
		# Shared irrigation must also work back on the Valley's six-column rows.
		farm.plots[0].merge({"stage":1,"tilled":true,"watered":false,"crop":"russet"},true)
		var water: float = Ops.local(farm).water
		Ops.target(farm,0,"water")
		check(farm.plots[0].watered and Ops.local(farm).water < water,"purchased irrigation operates on each island")
	farm.travel_to(2)
	check(not farm.climate.data.intro_pending,"return visit does not replay cinematic")
	check(not farm.climate.begin_warning(farm,"freeze",1),"freeze unavailable on Shores")
	farm.travel_to(3)
	for i in range(12): farm.plots[i].merge({"stage":2,"crop":"icecap","tilled":true,"watered":true,"elapsed":0.0,"frozen":false},true)
	check(farm.climate.begin_warning(farm,"freeze",1),"Winter freeze warning starts")
	farm.climate._impact(farm)
	check(Ops.frozen(farm,0) and Ops.frozen(farm,11),"freeze affects all planted crops")
	var growth: float = farm.plots[0].elapsed
	farm.update(1)
	check(farm.plots[0].elapsed == growth,"frozen crop growth stops")
	farm.interact_plot(0,"hoe")
	check(Ops.frozen(farm,0),"cold hoe cannot thaw disaster ice")
	farm.storage.icecap = 0
	game.hud.show_panel("activities",farm)
	game.hud._refs["climate_operate:heat_hoe"].pressed.emit()
	check(Ops.local(farm).heat>0 and game.selected_tool=="hoe","furnace heats hoe without a crop-fuel softlock")
	farm.interact_plot(0,"hoe")
	check(not Ops.frozen(farm,0) and farm.plots[0].stage==2,"heated hoe melts ice and preserves crop")
	check(farm.save_game(SAVE) and farm.load_game(SAVE),"freeze, shared equipment and heat save/load")
	check(Ops.frozen(farm,1) and Ops.local(farm).heat>0,"remaining ice and tool heat restored")
	farm.travel_to(1)
	check(not Ops.frozen(farm,1),"Winter ice never freezes same-index Valley bed")
	farm.travel_to(3)
	farm.climate.data.phase="recovery"
	farm.climate.data.timer=0.25
	farm.climate.update(farm,0.25)
	check(farm.climate.data.operations.ice.is_empty(),"remaining ice clears at end of recovery")
	var legacy: Dictionary = farm._save_data()
	legacy.mechanics_revision = 18
	for island in ["2", "3"]:
		for bed in legacy.island_plots[island]: bed.unlocked = bool(legacy["island" + island + "_unlocked"])
	legacy.climate.projects["1"].erase("irrigation")
	legacy.climate.projects["2"].irrigation = 2
	legacy.climate.projects["3"].irrigation = 1
	legacy.climate.operations.erase("ice")
	for supply in legacy.climate.operations.islands.values(): supply.erase("heat")
	var file := FileAccess.open(SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(farm.load_game(SAVE),"revision 18 equipment migrates")
	for projects in farm.climate.data.projects.values(): check(projects.irrigation==2,"migration preserves highest owned sprinkler level everywhere")
	var invalid: Dictionary = farm.climate.data.duplicate(true)
	invalid.operations.ice = {"999":true}
	check(not farm.ClimateSystem.valid(invalid,farm.MAX_MONEY),"invalid frozen-bed save is rejected")
	invalid = farm.climate.data.duplicate(true)
	invalid.operations.islands["3"].heat = -1
	check(not farm.ClimateSystem.valid(invalid,farm.MAX_MONEY),"invalid thaw heat is rejected")
	game.queue_free()
	await frames()
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(SAVE)
	print("WEATHER STATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
