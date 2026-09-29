extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
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
	# Keep the equipment fixture calm until its explicit freeze scenario.
	game.state.rng.seed = 6
	await frames()
	game.set_process(false)
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.coins = 4e+19
	await frames()
	game._on_action("climate")
	check(game.hud._refs.protection_summary.visible,"protection stats are immediately visible")
	check(not game.world._project_nodes.has("irrigation"),"no unbought sprinkler geometry")
	farm.climate.Lesson.start(farm)
	check(not farm.climate.Lesson.active(farm),"lesson cannot grant irrigation")
	var coins: float = farm.coins
	farm.climate.fund(farm,"irrigation")
	check(farm.coins < coins,"sprinklers cost coins")
	for island in [1]:
		game._on_state_changed()
		await frames()
		check(farm.climate.data.projects.irrigation == 1,"owned sprinklers carry to island %d" % island)
		check(game.world._project_nodes.has("irrigation"),"owned sprinkler geometry exists")
		check(is_instance_valid(game.world.weather_station) ,"weather station on the farm")
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
	for i in range(12):
		farm._clear_crop(farm.plots[i])
		farm.plots[i].merge({"stage":2,"crop":"icecap","tilled":true,"watered":true,"elapsed":0.0,"frozen":false},true)
	check(farm.climate.begin_warning(farm,"freeze",1),"Winter freeze warning starts")
	farm.climate._impact(farm)
	check(Ops.frozen(farm,0) and Ops.frozen(farm,11),"freeze affects all planted crops")
	var growth: float = farm.plots[0].elapsed
	farm.update(1)
	check(farm.plots[0].elapsed == growth,"frozen crop growth stops")
	farm.interact_plot(0,"hoe")
	farm.storage["icecap"] = Stock.pile(0)
	game.hud.show_panel("activities",farm)
	farm.interact_plot(0,"hoe")
	check(not Ops.frozen(farm,0) and farm.plots[0].stage==2,"hoe clears ice and preserves crop")
	check(farm.save_game(SAVE) and farm.load_game(SAVE),"freeze and equipment save/load")
	farm.climate.data.phase="recovery"
	farm.climate.data.timer=0.25
	farm.climate.update(farm,0.25)
	check(farm.climate.data.operations.ice.is_empty(),"remaining ice clears at end of recovery")
	var invalid: Dictionary = farm.climate.data.duplicate(true)
	invalid.operations.ice = {"999":true}
	check(not farm.ClimateSystem.valid(invalid,farm.MAX_MONEY),"invalid frozen-bed save is rejected")
	game.queue_free()
	await frames()
	# Allow the audio mixer to release weather playback before engine shutdown.
	await create_timer(0.1).timeout
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(SAVE)
	print("WEATHER STATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
