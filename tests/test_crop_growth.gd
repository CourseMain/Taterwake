extends SceneTree
## Save-free checks for continuous, state-owned growth and matching harvests.
const World = preload("res://scripts/farm_world.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func plot_for(crop: String) -> Dictionary:
	var plot: Dictionary = {"unlocked":true, "tilled":true, "stage":1,
		"watered":false, "crop":crop, "elapsed":0.0, "frozen":false,
		"pending":0, "yield_total":0, "yield_taken":0}
	return plot

func size_at(world, index: int) -> float:
	return float(world._crop_tubers[index].node.scale.x)

func shape_bounds(tuber: Node3D) -> Array[AABB]:
	var result: Array[AABB] = []
	for mesh: MeshInstance3D in tuber.find_children("*", "MeshInstance3D", true, false):
		result.append(mesh.transform * mesh.get_aabb())
	return result

func shot(world, plots: Array) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	# Each row compares the same six varieties: planted, halfway and ripe.
	for row in range(3):
		for column in range(6):
			var plot: Dictionary = plot_for(State.CROP_IDS[column])
			plot.stage = 1 if row == 0 else (2 if row == 1 else 3)
			plot.watered = row > 0
			plot.elapsed = float(State.CROPS[plot.crop].grow) * (0.0 if row == 0 else (.5 if row == 1 else 1.0))
			plots[row * 6 + column] = plot
	world.update_plots(plots)
	world.set_tutorial_focus("")
	world.camera.size = 20
	var center := Vector3(-1.75, 0, 1.45)
	world.camera.position = center + Vector3(7, 14, 16)
	world.camera.look_at(center)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/crop-growth-all-varieties.png") == OK, "capture the three growth rows")

func run() -> void:
	var world = World.new()
	root.add_child(world)
	world.build_world()
	var plots: Array = []
	for crop: String in State.CROP_IDS: plots.append(plot_for(crop))
	world.update_plots(plots)
	var planted: Array[float] = []
	for i in range(plots.size()):
		var description: String = str(plots[i].crop)
		check(world._crop_tubers.has(i), description + " starts with a visible growing tuber")
		if not world._crop_tubers.has(i):
			world.queue_free()
			quit(1)
			return
		planted.append(size_at(world, i))
		check(planted[i] > 0 and planted[i] < world._crop_tuber_size(plots[i]), description + " starts smaller than its mature crop")
		plots[i].stage = 2
		plots[i].watered = true
	world.update_plots(plots)
	var growing_ids: Array[int] = []
	for i in range(plots.size()):
		growing_ids.append(world._crop_tubers[i].node.get_instance_id())
		check(is_equal_approx(size_at(world, i), planted[i]), "watering plot %d does not jump to a different crop size" % i)
		plots[i].elapsed = float(State.CROPS[plots[i].crop].grow) * .5
	world.update_plots(plots)
	var midpoint: Array[float] = []
	for i in range(plots.size()):
		midpoint.append(size_at(world, i))
		check(midpoint[i] > planted[i] and midpoint[i] < world._crop_tuber_size(plots[i]), "plot %d grows visibly before ripening" % i)
		check(world._crop_tubers[i].node.get_instance_id() == growing_ids[i], "plot %d grows without rebuilding its geometry" % i)
		check(world._crop_roots[i].scale.is_equal_approx(Vector3.ONE) and world._plot_nodes[i].scale.is_equal_approx(Vector3.ONE), "plot %d keeps soil and decorations at their original size" % i)
	# No visual clock may advance a paused, frozen or unwatered crop on its own.
	for plot: Dictionary in plots: plot.frozen = true
	var unchanged: Array = plots.duplicate(true)
	world.animate(30.0, false)
	for i in range(plots.size()):
		check(is_equal_approx(size_at(world, i), midpoint[i]), "plot %d stays still when simulation elapsed time stays still" % i)
	check(plots == unchanged, "visual updates preserve elapsed time and harvest accounting")
	# A loaded save supplies new dictionaries without necessarily changing stage.
	var previous: Array = plots
	plots = plots.duplicate(true)
	for plot: Dictionary in plots: plot.elapsed = float(State.CROPS[plot.crop].grow) * .65
	world.update_plots(plots)
	var loaded_sizes: Array[float] = []
	for i in range(plots.size()):
		loaded_sizes.append(size_at(world, i))
		check(loaded_sizes[i] > midpoint[i] and world._crop_tubers[i].node.get_instance_id() == growing_ids[i], "same-stage load refreshes plot %d without replacing its tuber" % i)
		previous[i].elapsed = float(State.CROPS[previous[i].crop].grow)
	world.animate(1.0, false)
	for i in range(plots.size()):
		check(is_equal_approx(size_at(world, i), loaded_sizes[i]), "plot %d no longer follows the replaced save dictionary" % i)
		plots[i].elapsed = float(State.CROPS[plots[i].crop].grow) * .999
	world.animate(.1, false)
	var nearly_ripe: Array[float] = []
	for i in range(plots.size()):
		nearly_ripe.append(size_at(world, i))
		check(nearly_ripe[i] > loaded_sizes[i], "plot %d follows new live elapsed time between state refreshes" % i)
		plots[i].stage = 3
		plots[i].elapsed = float(State.CROPS[plots[i].crop].grow)
	world.update_plots(plots)
	var snapshots: Dictionary = {}
	for i in range(plots.size()):
		check(is_equal_approx(size_at(world, i), world._crop_tuber_size(plots[i])) and absf(size_at(world, i) - nearly_ripe[i]) < .01, "plot %d reaches ripeness without a size jump" % i)
		snapshots[i] = plots[i].duplicate(true)
	var fx = world.harvest_feedback
	var before_harvest: Dictionary = snapshots.duplicate(true)
	fx.harvest(snapshots)
	for receipt: Dictionary in fx.active:
		var index: int = int(receipt.index)
		var tuber: Node3D = receipt.node.get_node_or_null("PotatoTuber")
		check(is_instance_valid(tuber), "harvest %d preserves its planted tuber identity" % index)
		if is_instance_valid(tuber):
			check(tuber.scale.is_equal_approx(world._crop_tubers[index].node.scale), "harvest %d preserves mature size" % index)
			check(shape_bounds(tuber) == shape_bounds(world._crop_tubers[index].node), "harvest %d preserves the planted silhouette" % index)
	check(snapshots == before_harvest and plots == before_harvest.values(), "harvest visuals leave crop state unchanged")
	fx.harvest(snapshots)
	check(fx.active.size() == State.CROP_IDS.size(), "repeated harvest receipts replace each plot instead of duplicating it")
	fx.animate(.4)
	check(fx.clods.size() <= fx.MAX_CLODS, "a full row of pop animations respects the soil-particle budget")
	fx.animate(2.0)
	check(fx.active.is_empty() and fx.clods.is_empty(), "completed harvests clear their tubers and soil particles")
	while plots.size() < world.plot_positions.size(): plots.append(plot_for("russet"))
	await shot(world, plots)
	world.queue_free()
	await process_frame
	print("CROP GROWTH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
