extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for frame in range(12): await process_frame
	game.set_process(false); game.year_intro.stop(); game.hud.close_panel()
	game.tutorial.active = false; game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false); game.hud.set_tutorial({})
	game._reset_camera_view(true)
	var player: Vector3 = game.world.player.position
	var camera: Transform3D = game.world.camera.global_transform
	Input.action_press("move_right")
	for frame in range(30): game._process(1.0/60.0)
	Input.action_release("move_right")
	var travelled: Vector3 = game.world.player.position-player; travelled.y = 0
	check(travelled.length() > 1,"real movement moves the player")
	check(game.world.camera.global_position.distance_to(camera.origin+travelled) < .01,"camera follows the exact ground displacement in the same frame")
	check(game.world.camera.global_position.distance_to(camera.origin) > .5,"camera visibly follows during movement")
	check(game.world.camera.global_basis.is_equal_approx(camera.basis),"follow retains the play-camera angle")
	game.hud.show_panel("inventory",game.state)
	var held: Vector3 = game._camera_pan_offset
	game.world.set_player_position(game.world.player.position+Vector3(1,0,0)); game._update_player_camera(true)
	check(game._camera_pan_offset == held,"an open card holds its farm view")
	game.hud.close_panel(); game._recenter_camera()
	check(game._camera_pan_offset == Vector3.ZERO,"recenter cannot retain a free pan offset")
	var centre: Vector2 = Vector2(game.farm_viewport.size)*.5
	check(game.world.camera.unproject_position(game._player_camera_focus()).distance_to(centre) < .01,"recenter places the farmer body exactly in the middle")
	game.world.set_player_position(game.world.player.position+Vector3(2,0,1)); game._update_player_camera(false)
	check(game.world.camera.unproject_position(game._player_camera_focus()).distance_to(centre) < .01,"an idle position change still locks the view onto the farmer")
	game._zoom_by_log_amount(-.5)
	for frame in range(30): game._update_camera_zoom(1.0/60.0)
	check(game.world.camera.unproject_position(game._player_camera_focus()).distance_to(centre) < .01,"scrolling changes the view size around the farmer")
	check(game.world.camera.size < game._camera_home_size,"the locked camera retains useful zoom")
	game.hud.set_tool("hoe"); game.hud._layout_hotbar()
	for frame in range(12): await process_frame
	var previous: Rect2
	var first: Rect2 = game.hud._tool_buttons.hoe.get_global_rect()
	var caption_y: float = game.hud._tool_buttons.hoe.get_meta("caption").global_position.y
	for tool in ["hoe","plant","water","harvest","pest"]:
		var button: Button = game.hud._tool_buttons[tool]
		var rect: Rect2 = button.get_global_rect()
		check(rect.size.is_equal_approx(first.size) and is_equal_approx(rect.position.y,first.position.y),"tool tiles have equal size and share one row: "+tool)
		check(is_equal_approx(button.get_meta("caption").global_position.y,caption_y),"tool captions share one baseline: "+tool)
		if tool != "hoe": check(rect.position.x >= previous.end.x,"tool tiles do not overlap: "+tool)
		previous = rect
	check(game.hud.root.get_global_rect().encloses(game.hud._hotbar.get_global_rect()),"hotbar fits the play viewport")
	check(game.hud._tool_buttons.harvest.tooltip_text.is_empty(),"the redundant Harvest tooltip cannot cover the hotbar")
	check(game.hud._tool_caption.get_global_rect().end.y <= game.hud._hotbar.get_global_rect().position.y,"equipment caption clears the measured hotbar")
	check(await preload("res://tests/audio_fixture.gd").release(game,self),"audio releases before teardown")
	game.queue_free(); for frame in range(8): await process_frame
	print("CAMERA HOTBAR: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
