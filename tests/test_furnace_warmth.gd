extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle() -> void:
	for i in range(12): await process_frame
func shot(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/furnace-"+name+".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.tutorial_progress.completed = true
	game.state.debug_unlock_island(3)
	game.state.coins = 1e18
	game.state.travel_to(3)
	game.state.climate.acknowledge(game.state)
	game.hud._climate_alert.dismiss()
	game.state.storage.icecap = 50
	game.hud.show_panel("activities",game.state)
	await settle()
	var scroll: ScrollContainer = game.hud._body.get_parent()
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(390,844),Vector2i(844,390)]:
		root.min_size = Vector2i.ZERO
		root.size = resolution
		await settle()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x+1,"furnace fits without sideways scrolling "+str(resolution))
		for action: String in ["climate_operate:heat_hoe","activity:furnace:icecap"]:
			var button: Button = game.hud._refs[action]
			scroll.ensure_control_visible(button)
			await settle()
			check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),"furnace action reachable "+action)
		await shot(str(resolution.x))
	game._on_action("activity:furnace:icecap")
	await settle()
	check(game.state.storage.icecap == 25,"warm panel still charges exactly 25 Icecaps")
	check(game.hud._refs.furnace_hearth.burning and game.hud._refs["activity:furnace:icecap"].disabled,"fire reflects the real active boost and blocks repeat payment")
	game._on_action("climate_operate:heat_hoe")
	check(game.selected_tool == "hoe" and not game.hud.is_panel_open(),"bellows equips the thawing hoe and returns to the farm")
	check(game.state.storage.icecap == 25,"emergency bellows does not consume potatoes")
	root.size = Vector2i(1280,800)
	game.hud._toast_box.hide()
	var furnace: Node3D = game.world.find_child("FrostFurnace",true,false)
	game.world.camera.size = 7
	game.world.camera.position = furnace.global_position + Vector3(8,7,13)
	game.world.camera.look_at(furnace.global_position + Vector3(0,1.8,0))
	await settle()
	await shot("exterior")
	game.queue_free()
	await settle()
	print("FURNACE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
