extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(why)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var world = game.world
	var colours: PackedColorArray = world.get_node("IslandTerrainShell").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(Array(colours).any(func(c): return c.r < .91) and Array(colours).any(func(c): return c.r > .999),"terrain bakes shaded contacts and open grass")
	check(Array(colours).all(func(c): return c.r >= .799),"baked occlusion is bounded at twenty percent")
	var scans: int = world.ground_occlusion.samples
	world.animate(1.0,false)
	check(world.ground_occlusion.samples == scans and not world._geometry_batcher._compiler.occlusion.is_valid(),"occlusion never scans during animation or dynamic crop batching")
	var lower := preload("res://scripts/farm_world.gd").season_tints(1,1)
	check(lower.grass != lower.grass_low and lower.grass.r > lower.grass_low.r,"Summer terrace tops and olive risers have distinct tones")
	for season in range(4):
		world.set_calendar(3,season,75,"")
		world._process(1.0)
		world._animate_sun(3.0)
		world._animate_sun(.4)
		check(is_equal_approx(world._sun.rotation_degrees.x,-27 if season >= 2 else -35),"Autumn and Winter noon stay lower than Spring and Summer")
		check(world._sun.light_color.r > world._sun.light_color.b and world._day_environment.ambient_light_color.b > world._day_environment.ambient_light_color.r,"warm light contrasts with cool fill")
	check(world.get_node("StaticContactDiscs").multimesh.instance_count >= world._tree_specs.size(),"trees and buildings have shared soft contacts")
	check(game.hud._play_band.get_theme_stylebox("panel") is StyleBoxEmpty,"play HUD background is fully transparent")
	check(game.hud._weather_button.get_theme_stylebox("normal").get_meta("surface_fill") == preload("res://scripts/place_ui.gd").WOOD,"weather picture sits on the rounded tool-tile wood")
	game.touch_controls.enabled = true
	game._set_shadow_size(4096)
	check(game.shadow_size == 2048,"phone shadow maps never exceed 2048 even with an old 4096 preference")
	game.hud.show_panel("graphics",game.state)
	check(game.hud._refs.shadows_4096.disabled,"phone graphics cannot request the desktop map")
	game.queue_free()
	for i in range(6): await process_frame
	print("PLAY LIGHT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
