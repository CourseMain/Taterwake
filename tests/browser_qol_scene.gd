extends "res://qa_base.gd"
## Segment 21j review fixture. No normal save is read or written.

func command(args: Array) -> void:
	if not args.is_empty() and str(args[0]).begins_with("qol_"):
		request += 1
		_present_qol(str(args[0]), request)
	else: super.command(args)

func _present_qol(action: String, ticket: int) -> void:
	var view: String = action.get_slice(":", 0)
	var base: String = {"qol_winter":"play_winter", "qol_grades":"grades", "qol_accounts":"accounts", "qol_seed":"market", "qol_guide":"guide_welcome", "qol_refused":"guide_grow", "qol_undo":"market_sell"}.get(view, "play_spring")
	await super._present(base, ticket)
	if ticket != request: return
	is_ready = false
	current_page = view
	if view in ["qol_home", "qol_low", "qol_quests", "qol_rent", "qol_locked"]:
		var season: int = int(action.get_slice(":", 1)) if action.contains(":") else 0
		game.state.season_clock.season = season
		game.world.set_calendar(3, season, 75)
		game.world._animate_sun(3.4)
		var target: Vector3 = {"qol_home":Vector3(-1.8,0,6.3), "qol_low":Vector3(17.2,0,17.5), "qol_quests":Vector3(-14.7,1.3,9.9), "qol_rent":Vector3(14.5,1,19.7), "qol_locked":Vector3(17.2,0,17.5)}[view]
		var camera: Camera3D = game.world.camera
		camera.size = {"qol_home":20.0, "qol_low":20.0, "qol_quests":12.0, "qol_rent":8.0, "qol_locked":28.0}[view]
		camera.position = target + camera.basis.z * 260.0
		game.world.fit_camera_depth()
		game.hud.root.visible = view == "qol_locked"
		game.touch_controls.root.hide()
		if view == "qol_locked": game.hud.show_farm_hint(preload("res://scripts/farm_advice.gd").locked(game.state, 24))
	if view == "qol_accounts":
		var scroll: ScrollContainer = game.hud._body.get_parent()
		scroll.scroll_vertical = 100000
	for frame in range(8): await get_tree().process_frame
	is_ready = true
	_publish()

func _publish() -> void:
	super._publish()
	if not is_instance_valid(game): return
	last_report.fixture = "qol"
	last_report.quests = []
	var board: Node3D = game.world.find_child("FarmingQuestBoard", true, false)
	if board:
		for x: float in [-1.085, 0.0, 1.085]:
			for y: float in [0.94, 1.53, 2.12]:
				var point: Vector3 = board.to_global(Vector3(x,y,.16))
				var projected: Vector2 = game.world.camera.unproject_position(point)
				last_report.quests.append([projected.x,projected.y])
	_publish_raw()
