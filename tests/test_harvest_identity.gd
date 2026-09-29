extends SceneTree
## Committed harvests, interrupted receipts, ordinary crops and safe reloads.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for i in range(4): await process_frame

func shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/identity-"+label+".png") == OK, "capture " + label)

func ready_plot(index: int, giant: bool = false) -> void:
	game.state._clear_crop(game.state.plots[index])
	game.state.plots[index].merge({"unlocked":true, "tilled":true, "stage":3, "crop":"giant" if giant else "russet", "watered":true, "elapsed":game.state.CropTable.CROPS.giant.grow if giant else game.state.CropTable.CROPS.russet.grow}, true)
	game._on_state_changed()

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.reset_game()
	game.tutorial.start()
	game.state.tutorial_progress.plot = 4
	game.state.tutorial_progress.step = 3
	game.state.plots[4].tilled = true
	game.tutorial._enter_step()
	game.perform_plot(4, "plant")
	game.tutorial._enter_step()
	var path: String = "user://identity-%d.json" % OS.get_process_id()
	check(game.state.save_game(path) and game.state.load_game(path), "planting lesson round-trips through a disposable save")
	game.tutorial.start()
	game.perform_plot(4,"water")
	var tuber: Node3D = game.world._crop_roots[4].get_node("PotatoTuber")
	var start_size: float = tuber.scale.x
	game._process(5)
	check(tuber.scale.x > start_size, "plant visibly expands before it becomes ripe")
	var midway_size: float = tuber.scale.x
	check(game.state.save_game(path) and game.state.load_game(path), "same-stage growing crop reloads")
	game.tutorial.start()
	game._process(1)
	check(tuber.scale.x > midway_size, "reloaded crop follows the new live plot dictionary")
	game._process(float(game.state.CropTable.CROPS.russet.grow) - 6.0 + 0.1)
	check(game.tutorial.current_id() == "harvest", "crop requires ordinary watering and growing time")
	game.world.camera.size = 17
	game.world.camera.position = game.world.plot_positions[4] + Vector3(11,15,17)
	game.world.camera.look_at(game.world.plot_positions[4] + Vector3(0,1,0))
	await shot("giant-ripe")
	var stored: int = game.state.storage_used()
	game.perform_plot(4,"harvest")
	var fx = game.world.harvest_feedback
	check(game.state.storage_used()-stored == 3, "first Russet harvest has its ordinary yield")
	check(fx.active.size() == 1 and not fx.active[0].heavy, "committed Russet starts one visual receipt")
	check(fx.audio.last_kind == "harvest", "ordinary crop uses harvest foley")
	fx.animate(2)
	check(fx.active.is_empty() and fx.clods.is_empty(), "harvest cleans up without leaving props")
	game.tutorial.finish()
	game.tone_remaining = 0
	ready_plot(6)
	game.perform_plot(6, "harvest")
	fx.animate(2)
	game.state.storage.russet = game.state.capacity-1
	ready_plot(5,true)
	game.perform_plot(5,"harvest")
	check(game.state.storage_used() == game.state.capacity and game.state.plots[5].stage == 3 and game.state.plots[5].pending > 0, "partial harvest retains uncollected inventory on its crop")
	fx.animate(2)
	game.tone_remaining = 0
	game.perform_plot(5,"harvest")
	check(fx.active.is_empty(), "full barn produces no fake successful harvest")
	check(game.tone_remaining == 0, "blocked harvest produces no success chime")
	game.state.storage.russet -= 1
	game.perform_plot(5,"harvest")
	check(fx.active.size() == 1, "partial harvest can resume while receipts remain cosmetic")
	var batch: Dictionary = {}
	for i in range(24): batch[i] = {"stage":3,"crop":"giant" if i%2==0 else "russet"}
	fx.harvest(batch)
	check(fx.active.size() <= fx.MAX_HARVESTS, "large tools respect hard receipt budget")
	fx.animate(.4)
	check(fx.clods.size() <= fx.MAX_CLODS, "soil scatter stays bounded across a full field")
	game.world.build_world()
	check(game.world.harvest_feedback.active.is_empty(), "travel cannot replay old harvests")
	var foley = load("res://scripts/farm_audio.gd")
	var normal: AudioStreamWAV = foley.bake("harvest")
	var heavy: AudioStreamWAV = foley.bake("giant")
	check(normal.data.size() > 20000 and heavy.data.size() > normal.data.size(), "distinct foley includes complete normal and heavy envelopes")
	var peak: int = 0
	for i in range(heavy.data.size()/2): peak = maxi(peak, absi(heavy.data.decode_s16(i*2)))
	check(peak > 1000 and peak < 32767, "foley has audible samples without clipping")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await settle()
	await create_timer(.4).timeout
	print("HARVEST IDENTITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
