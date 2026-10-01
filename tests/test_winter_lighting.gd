extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(note)
func frames(count: int=8) -> void:
	for i in range(count): await process_frame
func frame_image() -> Image:
	await frames(4)
	RenderingServer.force_draw()
	return root.get_texture().get_image()
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames()
	game.set_process(false)
	var w=game.world
	game.state.tutorial_progress.completed=true; game.state.set_tutorial_active(false)
	game.state.season_clock.season=3; game.state.season_clock.seconds=75
	for plot in game.state.plots: game.state._clear_crop(plot)
	for i in range(12): game.state.plots[i].winter_ice=true; game.state.plots[i].tilled=true
	game._on_state_changed(); game.hud.close_panel()
	game.hud._climate_alert.dismiss(); game.hud._toast_box.hide(); game.hud._purchase_box.hide()
	w._process(1); w._animate_sun(3.0); w._animate_sun(0.4); game._recenter_camera()
	for i in range(30): game._update_camera_zoom(.1)
	w.set_process(false); w.visuals.set_process(false)
	var material: ShaderMaterial=w.visuals.snow_ground.material_override
	check("unshaded" not in material.shader.code and "shadows_disabled" not in material.shader.code and "ambient_light_disabled" not in material.shader.code,"snow uses the ordinary lit surface and ambient path")
	check("step(0.35, dot(NORMAL, LIGHT))" in material.shader.code,"snow normal band uses the requested 0.35 threshold")
	for elevation in [25.1,30.0,40.0,55.0,60.0]:
		check(Vector3.UP.dot(Vector3(0,sin(deg_to_rad(elevation)),cos(deg_to_rad(elevation))))>0.35,"upward ground is lit above 25 degrees")
	for mode in ["balanced","crisp","smooth"]:
		w.set_graphics_quality(mode)
		check(w._sun.shadow_enabled==(mode!="smooth"),mode+" uses the same sun-shadow policy on snow as grass")
	if DisplayServer.get_name()!="headless":
		var probe: MeshInstance3D=w._box(w,Vector3(20,2,-8),Vector3(1.4,4,1.4),Color("6e645a"))
		var point: Vector2=w.camera.unproject_position(Vector3(20,.18,-5.8))
		w.set_graphics_quality("balanced")
		probe.hide()
		var clear: Image=await frame_image()
		probe.show()
		var shaded: Image=await frame_image()
		var clear_color: Color=clear.get_pixelv(Vector2i(point))
		var shaded_color: Color=shaded.get_pixelv(Vector2i(point))
		print("SNOW SHADOW pixels ",clear_color," -> ",shaded_color)
		check(clear_color.get_luminance()-shaded_color.get_luminance()>.025,"a real occluder casts a visible sun shadow onto snow")
		check(shaded_color.b>shaded_color.r,"the snow shadow is pale blue")
		w.set_graphics_quality("smooth")
		var smooth_shaded: Image=await frame_image()
		probe.hide()
		var smooth_clear: Image=await frame_image()
		check(smooth_shaded.get_pixelv(Vector2i(point)).is_equal_approx(smooth_clear.get_pixelv(Vector2i(point))),"Smooth omits the cast shadow while retaining lit snow")
		probe.free()
	w.set_graphics_quality("balanced")
	for i in range(12): w.set_player_position(Vector3(-14.7,0,15+i*.6))
	if "--capture" in OS.get_cmdline_user_args():
		var step:="1"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--step="): step=arg.trim_prefix("--step=")
		(await frame_image()).save_png("res://artifacts/winter-light-step"+step+".png")
	game.queue_free(); await frames(); await create_timer(.25).timeout
	print("WINTER LIGHTING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
