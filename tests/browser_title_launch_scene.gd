extends Node
## Production Main._ready, real browser persistence, no integration-mode override.
var game
var callback
var first_frame: Dictionary
var first_farm_frame: Dictionary
var launch_report: Dictionary
func _ready() -> void:
	if OS.has_feature("web"):
		callback = JavaScriptBridge.create_callback(command)
		JavaScriptBridge.get_interface("window").titleQA = callback
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	assert(not game.test_mode)
	RenderingServer.frame_post_draw.connect(_draw)
func _draw() -> void:
	if first_frame.is_empty():
		first_frame = status()
		_publish()
	elif first_farm_frame.is_empty() and not game.title_active():
		first_farm_frame = status()
		_publish()
func command(args: Array) -> void:
	if args.is_empty(): return
	if str(args[0]) == "checkpoint": game._save_checkpoint()
	_publish()
func status() -> Dictionary:
	var title = game.title_scene
	return {"title":game.title_active(),"hud":game.hud.root.is_visible_in_tree(),
		"panel":game.hud.is_panel_open(),"panel_kind":game.hud._panel_kind,"farmer_exit_rect":_farmer_exit(),"front_page":game.year_intro.visible,
		"panel_ready":not game.hud._modal_entrance_shield.visible and game.hud._modal.modulate.a > .99,
		"guide":game.tutorial.current_id() if game.tutorial.active else "",
		"saved":title.has_saved_farm,"primary":title.walk.text,
		"secondary_visible":title.resume.is_visible_in_tree(),"secondary":title.resume.text,
		"confirmation":title.confirmation.is_visible_in_tree(),"pause_reset":game.hud._reset_pending,
		"safe_default":title.keep_farm.has_focus(),"walking_in":title.walking_in,
		"logical_size":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],
		"primary_rect":_rect(title.walk),"secondary_rect":_rect(title.resume),
		"keep_rect":_rect(title.keep_farm),"replace_rect":_rect(title.replace_farm),
		"version":ProjectSettings.get_setting("application/config/version"),"test_mode":game.test_mode,
		"camera_size":game.world.camera.size,"overview_size":game.world.overview_size(),
		"home_size":game._camera_home_size,"camera_home_distance":game.world.camera.global_position.distance_to(game._camera_home_position),
		"island":_island_bounds(),"idle":_idle()}

func _island_bounds() -> Dictionary:
	var surface = game.world.Surface
	var viewport: Vector2 = game.farm_viewport.get_visible_rect().size
	var bounds := Rect2()
	var first := true
	var clipped := false
	var camera: Camera3D = game.world.camera
	for z: float in [-surface.EXTENT.y * .5, 0.0, surface.EXTENT.y * .5]:
		for side: float in [-1,1]:
			var x: float = side * surface.half_width(z)
			var point := Vector3(x,surface.height_at(x,z),z)
			var projected: Vector2 = camera.unproject_position(point) / viewport
			if first: bounds = Rect2(projected, Vector2.ZERO); first = false
			else: bounds = bounds.expand(projected)
			var depth: float = camera.global_basis.z.dot(camera.global_position - point)
			clipped = clipped or camera.is_position_behind(point) or depth < camera.near or depth > camera.far
	return {"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"clipped":clipped}

func _idle() -> Dictionary:
	var poses: Array = []
	for record: Dictionary in game.title_scene.idle.actors:
		var person = record.person
		poses.append({"name":person.name,"bob":person._rig.position.y,"eyes":person._eyes[0].scale.y})
	return {"poses":poses,"petals":game.title_scene.idle.petals.size()}
func _rect(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func _publish() -> void:
	launch_report = {"first_frame":first_frame,"first_farm_frame":first_farm_frame,"state":status(),"ready":not first_frame.is_empty()}
	if OS.has_feature("web"): JavaScriptBridge.eval("window.titleReport="+JSON.stringify(launch_report),true)

func _farmer_exit() -> Array:
	for button in game.hud._body.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.get_meta("hud_action", "") == "close": return _rect(button)
	return [0,0,0,0]
