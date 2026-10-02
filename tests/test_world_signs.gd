extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + words)
func frames() -> void:
	for i in range(8): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); await frames(); game.set_process(false)
	game.hud.root.hide(); game.touch_controls.hide()
	var world = game.world
	for label in world.find_children("*", "Label3D", true, false):
		check(label.has_meta("board_bounds"), "every world label has measured bounds")
	var fields: Dictionary = {}
	for label in world._fitted_labels:
		if label.text in ["Home Field", "Low Field", "Hill Field"]: fields[label.text] = label
		world.fit_label(label)
		if label.text.is_empty(): continue
		var actual: Vector2 = world.label_extent(label, label.font_size) * label.pixel_size
		var bounds: Vector2 = label.get_meta("board_bounds")
		check(actual.x <= bounds.x + .001 and actual.y <= bounds.y + .001, label.text + " measured inside its board")
	check(fields.size() == 3, "three field names without exposure copy")
	for label in fields.values(): check(label.get_parent().find_child("Exposure_*", false, false) != null, "exposure is an icon on the post")
	for board in world._lease_boards:
		var labels: Array = board.find_children("*", "Label3D", true, false)
		check(labels.size() == 1 and labels[0].text == "TO LET", "lease board has only TO LET")
	var home: Label3D = fields["Home Field"]
	var original_size: int = home.font_size
	home.text = "Very long field name ".repeat(30); world.fit_label(home)
	var fitted: Vector2 = world.label_extent(home, home.font_size) * home.pixel_size
	check(fitted.x <= 2.94 + .001 and fitted.y <= .6 + .001 and home.font_size < 27, "long text shrinks instead of overflowing")
	home.text = "Home Field"; world.fit_label(home)
	check(home.font_size == original_size, "short text restores its requested size")
	if "--capture" in OS.get_cmdline_user_args():
		root.min_size = Vector2i.ZERO
		world.player.position = home.get_parent().global_position + Vector3(-10, 0, 0)
		for dimensions in [Vector2i(1280,800), Vector2i(390,844)]:
			root.size = dimensions; root.content_scale_size = dimensions; await frames()
			world.camera.near = .1; world.camera.far = 100
			world.camera.size = 3.5 if dimensions.x > 600 else 8.0
			world.camera.position = home.get_parent().global_position + Vector3(0,2.0,7)
			world.camera.look_at(home.get_parent().global_position + Vector3(0,1.0,0))
			await create_timer(.2).timeout; RenderingServer.force_draw()
			check(root.get_texture().get_image().save_png("res://artifacts/segment19-signs-%d.png" % dimensions.x) == OK, "capture signs")
	game.queue_free(); await frames(); await create_timer(.25).timeout
	print("WORLD SIGNS: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
