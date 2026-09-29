extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(note)
func frames(count: int=8) -> void:
	for i in range(count): await process_frame
func capture(label: String, target: Vector3=Vector3.ZERO, zoom: float=0) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	if zoom>0:
		game.world.camera.position=target+Vector3(14,19,25)
		game.world.camera.look_at(target)
		game.world.camera.size=zoom
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/cute-snow-"+label+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames()
	game.set_process(false)
	var farm=game.state
	var w=game.world
	farm.tutorial_progress.completed=true; farm.set_tutorial_active(false)
	farm.season_clock.season=3; farm.season_clock.seconds=75
	for plot in farm.plots: farm._clear_crop(plot)
	for i in range(12): farm.plots[i].winter_ice=true; farm.plots[i].tilled=true
	game._on_state_changed(); game.hud.close_panel()
	game.hud._climate_alert.dismiss(); game.hud._toast_box.hide(); game.hud._purchase_box.hide()
	w._process(1)
	game._recenter_camera()
	for i in range(30): game._update_camera_zoom(.1)
	var art=w.visuals
	check(art.snow_ground.material_override.shader==art.snow_material.shader,"ground and caps share the two-band snow shader")
	check(art.snow_ground.mesh.get_aabb().size.y>2,"pillows follow the terraced ground")
	check(art.snow_exposed_fraction>=.12 and art.snow_exposed_fraction<=.18,"snow leaves fifteen percent exposed grass")
	check(art.bed_snow.multimesh.visible_instance_count==36,"only twelve opened icy beds have three soft snow ridges")
	farm.plots[0].winter_ice=false; game._on_state_changed()
	check(art.bed_snow.multimesh.visible_instance_count==33,"clearing ice removes that bed's snow ridges")
	farm.plots[0].winter_ice=true; game._on_state_changed()
	w.player.position=Vector3(-14.7,0,15)
	w.set_player_position(Vector3(-14.7,0,15.6))
	check(art.print_count==2,"one walked step stamps a pair of footprints")
	art.animate(30)
	check(is_equal_approx(art.footprint_alpha(0),.5) and art.footprints.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"tracks fade halfway after thirty seconds")
	art.animate(31)
	check(art.print_count==0,"tracks fade away after a minute")
	for i in range(14): w.set_player_position(Vector3(-14.7,0,15+i*.6))
	var step := "1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--step="): step=arg.trim_prefix("--step=")
	await capture("step"+step+"-overview")
	var point: Vector3=Vector3(-14.7,0,18) if step=="2" else (w.plot_positions[7] if step=="5" else w.ClimateProjects.barn_position(w)+Vector3(0,1,3))
	await capture("step"+step+"-detail",point,14 if step in ["2","5"] else 23)
	game.queue_free(); await frames(); await create_timer(.4).timeout
	print("CUTE SNOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
