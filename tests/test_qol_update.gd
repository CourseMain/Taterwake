extends SceneTree
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func settle() -> void:
	for _i in range(6): await process_frame
func shot(name: String) -> void:
	game.hud._toast_box.hide()
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/qol-" + name + ".png") == OK, "capture " + name)
func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	var state = game.state
	var expected: Array = [75, 135, 105, 195, 225]
	for index: int in range(state.CROP_IDS.size()):
		var crop: String = state.CROP_IDS[index]
		check(state.CropTable.CROPS[crop].grow == expected[index] and state.crop_grow_time(crop) <= 225.0, crop + " uses balanced base growth")
	game._on_action("dex")
	check(game.hud._body.find_children("DexPicture_*", "Control", true, false).size() == 5, "crop tab illustrates all five varieties")
	check(game.hud._refs["dex_status:sunburst"].text.contains("195s") and game.hud._refs["dex_status:icecap"].text.contains("225s"), "Dex shows seasonal growth times")
	await shot("dex-crops")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(640, 360), Vector2i(600, 900)]:
		root.min_size = Vector2i.ZERO
		root.size = size
		await settle()
		check(game.hud.root.get_global_rect().encloses(game.hud._modal_card.get_global_rect()), "Dex modal fits " + str(size))
		check(game.hud._body.get_combined_minimum_size().x <= game.hud._body.size.x + 1.0, "Dex has no horizontal overflow " + str(size))
		for picture: Control in game.hud._body.find_children("DexPicture_*", "Control", true, false):
			check(picture.size.x >= 76 and picture.size.y >= 76, "illustration stays readable " + picture.name)
	root.size = Vector2i(1280, 800)
	game.hud.close_panel()
	state.climate.begin_warning(state, "drought", 1.0)
	state.climate.data.phase = "active"
	state.climate.data.timer = 30.0
	for crop: String in state.CROP_IDS:
		check(state.crop_grow_time(crop) <= state.MAX_GROW_SECONDS + 0.000001, crop + " weather slowdown is bounded")
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("QOL UPDATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
