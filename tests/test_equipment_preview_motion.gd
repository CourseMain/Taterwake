extends SceneTree
const Preview = preload("res://scripts/equipment_preview.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _new_preview():
	var preview = Preview.new()
	preview.size = Vector2(228, 310)
	root.add_child(preview)
	preview.set_process(false)
	return preview

func run() -> void:
	var turns: Array[float] = []
	var inertia_positions: Array[float] = []
	for fps in [30, 60, 120]:
		var preview = _new_preview()
		var delta: float = 1.0 / fps
		var before: float = preview.avatar.rotation.y
		preview._begin_drag()
		check(preview.avatar.rotation.y == before, "drag begins without an angle snap at %d fps" % fps)
		for frame in range(fps):
			preview._drag_by(120.0 / fps, delta)
			preview._process(delta)
		var release_angle: float = preview.avatar.rotation.y
		preview._release_drag()
		check(preview.avatar.rotation.y == release_angle and preview._angular_velocity > 0, "release preserves the displayed angle and carries a gentle turn at %d fps" % fps)
		for frame in range(fps / 2):
			preview._process(delta)
		inertia_positions.append(preview.avatar.rotation.y)
		for frame in range(fps * 2):
			preview._process(delta)
		turns.append(preview.avatar.rotation.y)
		check(absf(preview._angular_velocity) < 0.00001 and preview.avatar.rotation.y > release_angle, "release inertia slows to rest without reversing at %d fps" % fps)
		preview.free()
	check(absf(turns[0] - turns[1]) < 0.001 and absf(turns[1] - turns[2]) < 0.001, "30/60/120 fps settle at the same orientation")
	check(absf(inertia_positions[0] - inertia_positions[2]) < 0.01, "release animation remains visually equivalent across 30 and120 fps")
	var preview = _new_preview()
	preview.set_equipment({"head": "aurora_crown", "body": "scientist_coat", "legs": "farmer_pants", "feet": "industrialist_boots", "hands": "harvest_gloves", "charm": "market_monocle"}, State.ITEM_CATALOG)
	var ids_before: Array[int] = _mesh_ids(preview.avatar)
	preview._begin_drag()
	preview._drag_by(100.0, 0.04)
	check(preview._angular_velocity <= Preview.MAX_TURN_SPEED, "rapid flick velocity is capped for gentle preview motion")
	preview._process(0.05)
	var live_angle: float = preview.avatar.rotation.y
	preview.hide()
	check(not preview._dragging and preview._angular_velocity == 0 and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hiding inventory cancels dragging and stops portrait rendering")
	check(not preview.is_processing(), "hidden portrait stops its animation callback entirely")
	preview._process(4.0)
	check(preview.avatar.rotation.y == live_angle, "hidden time cannot accumulate a stale rotation")
	preview.show()
	preview.set_process(false)
	check(not preview._dragging and preview.avatar.rotation.y == live_angle and preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "reopening retains the viewing angle without restarting an old drag")
	preview._process(1.0 / 60.0)
	check(absf(preview.avatar.rotation.y - live_angle) < 0.002, "idle movement fades back in smoothly after reopening")
	preview._begin_drag()
	preview._drag_by(-50.0, 0.05)
	var outside_release := InputEventMouseButton.new()
	outside_release.button_index = MOUSE_BUTTON_LEFT
	outside_release.pressed = false
	preview._input(outside_release)
	check(not preview._dragging, "mouse release outside the portrait ends dragging")
	preview._begin_drag()
	preview._drag_by(35.0, 0.05)
	preview._process(0.2)
	preview._release_drag()
	check(preview._angular_velocity == 0, "holding the mouse still before release does not create a stale fling")
	preview._begin_drag()
	preview._drag_by(40.0, 0.04)
	preview._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not preview._dragging and preview._angular_velocity == 0, "losing window focus clears drag state")
	for frame in range(360):
		preview._process(1.0 / 120.0)
	check(_mesh_ids(preview.avatar) == ids_before, "continuous portrait rotation and breathing allocate no avatar meshes")
	var attached: bool = true
	for follower in preview.avatar._followers:
		attached = attached and (follower.node as Node3D).transform.is_equal_approx((follower.limb as Node3D).transform)
	check(attached, "all equipped clothing remains attached throughout turn and idle animation")
	check(preview.viewport.msaa_3d == Viewport.MSAA_4X, "portrait alone uses four-sample antialiasing")
	var ordinary: Vector2i = Preview.render_size(Vector2(228, 310), 1.0)
	var retina: Vector2i = Preview.render_size(Vector2(228, 310), 2.0)
	var huge: Vector2i = Preview.render_size(Vector2(2000, 2000), 4.0)
	check(ordinary == Vector2i(342, 465) and retina == Vector2i(456, 620), "portrait resolution scales with the display density and includes modest baseline supersampling")
	check(maxi(huge.x, huge.y) <= Preview.MAX_RENDER_EDGE and huge.x * huge.y <= Preview.MAX_RENDER_PIXELS, "large and HiDPI windows obey the portrait GPU pixel budget")
	preview.size = Vector2(300, 400)
	preview._sync_resolution()
	check(preview.viewport.size.x >= 450 and preview.viewport.size.y >= 600, "resizing portrait updates its actual render resolution")
	var resized: Vector2i = preview.viewport.size
	preview._sync_resolution()
	check(preview.viewport.size == resized, "unchanged display size does not recreate the render target")
	var clock_before: float = preview._clock
	preview._process(NAN)
	check(preview._clock == clock_before, "invalid timing input does not corrupt the preview pose")
	if "--capture" in OS.get_cmdline_user_args():
		preview.position = Vector2(120, 60)
		preview.size = Vector2(456, 620)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/equipment-smooth-portrait.png") == OK, "render the smoothed antialiased equipment portrait")
	preview.free()
	print("EQUIPMENT PREVIEW MOTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _mesh_ids(node: Node) -> Array[int]:
	var result: Array[int] = []
	for child in node.get_children():
		result.append(child.get_instance_id())
		if child is MeshInstance3D:
			result.append(child.mesh.get_instance_id())
		result.append_array(_mesh_ids(child))
	return result
