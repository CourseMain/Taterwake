extends Node3D
## Visual receipts for committed harvests; animation never owns crop inventory.
const MAX_HARVESTS: int = 12
const MAX_CLODS: int = 64
var world
var active: Array[Dictionary] = []
var clods: Array[Dictionary] = []
var audio: Node
const STAMP_HOLD: float = 1.2
const STAMP_FADE: float = .4
var _canvas_width: float = 0
var stamp_layer: CanvasLayer
var pull_pose: float = 0

func setup(owner_world) -> void:
	world = owner_world
	name = "HarvestFeedback"
	stamp_layer = CanvasLayer.new(); stamp_layer.name = "HarvestStamps"; stamp_layer.layer = 2
	var host: Node = world.get_viewport().get_parent() if world.get_viewport() is SubViewport else get_tree().root
	host.add_child(stamp_layer)
	get_tree().root.size_changed.connect(func(): _canvas_width = 0)
	tree_exiting.connect(func(): if is_instance_valid(stamp_layer): stamp_layer.queue_free())
	audio = preload("res://scripts/farm_audio.gd").new()
	add_child(audio)

func harvest(snapshots: Dictionary) -> void:
	var heavy_sound: bool = false
	for raw_index in snapshots:
		var index: int = int(raw_index)
		var plot: Dictionary = snapshots[raw_index]
		if index < 0 or index >= world.plot_positions.size() or int(plot.get("stage", 0)) != 3: continue
		var heavy: bool = plot.get("crop") == "giant"
		heavy_sound = heavy_sound or heavy
		# Repeated partial harvests replace their own receipt. Big tools have a
		# hard visual budget, independent of field size and stored crop count.
		for i in range(active.size() - 1, -1, -1):
			if int(active[i].index) == index: _remove(i)
		if active.size() >= MAX_HARVESTS: _remove(0)
		var body := Node3D.new()
		body.name = "GiantHarvest" if heavy else "PotatoHarvest"
		add_child(body)
		# Match the planted tuber's silhouette, color and size at the instant of
		# harvest. The wrapper supplies the pull/flight pivot at its body center.
		var size: float = world._crop_tuber_size(plot)
		var tuber: Node3D = world._create_crop_tuber(body, plot)
		tuber.scale = Vector3.ONE * size
		tuber.position.y = -.58 * size
		var origin: Vector3 = world.plot_positions[index] + Vector3(0,.25 + .58 * size,0)
		var tag := Label.new()
		tag.text = preload("res://scripts/crop_quality.gd").grade(int(plot.get("quality", 100)))
		tag.name = "HarvestGrade"
		preload("res://scripts/grade_stamp.gd").apply(tag, tag.text)
		stamp_layer.add_child(tag)
		tag.hide()
		body.position = origin
		active.append({"node":body, "index":index, "origin":origin, "age":0.0, "heavy":heavy, "size":size, "grade":tag.text, "stamp":tag, "popped":false, "landed":false})
	if not snapshots.is_empty(): audio.play_action("giant" if heavy_sound else "harvest")

func _remove(index: int) -> void:
	var node: Node3D = active[index].node
	active[index].stamp.queue_free()
	node.hide()
	node.queue_free()
	active.remove_at(index)

func _scatter(at: Vector3, count: int, heavy: bool) -> void:
	for i in range(count):
		if clods.size() >= MAX_CLODS: break
		var angle: float = i * 2.39996
		var spread: float = (1.6 if heavy else 1.0) + float(i % 3) * .35
		var size: Vector3 = Vector3(.095,.065,.08) * (1.4 if heavy else 1.0)
		var piece: Node3D = world._sphere(self, at, size, Color("715239") if i % 2 else Color("a07b51"))
		clods.append({"node":piece, "age":0.0, "size":size, "velocity":Vector3(cos(angle)*spread,1.6+float(i%3)*.4,sin(angle)*spread)})

func animate(delta: float) -> void:
	pull_pose = 0
	var popped_grades: Dictionary = {}
	var blocked: Array[Rect2] = []
	if not active.is_empty(): blocked = _stamp_obstacles()
	for i in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[i]
		entry.age += delta
		var t: float = entry.age
		var pull: float = .32 if entry.heavy else .18
		var flight: float = .48 if entry.heavy else .36
		var body: Node3D = entry.node
		var origin: Vector3 = entry.origin
		var stamp: Label = entry.stamp
		var logical: Vector2 = get_tree().root.get_visible_rect().size
		var scale: float = _display_scale()
		stamp.visible = t >= pull
		var pixels: int = ceili(16 / scale)
		if stamp.get_theme_font_size("font_size") != pixels: stamp.add_theme_font_size_override("font_size", pixels)
		stamp.size = stamp.get_combined_minimum_size()
		var point: Vector2 = world.camera.unproject_position(origin) * logical / Vector2(world.get_viewport().size)
		# A receipt rail sits above the whole field, so no chip covers a bed.
		var top: float = logical.y
		var field: int = entry.index / 24
		for bed in range(field * 24, mini((field + 1) * 24, world.plot_positions.size())):
			var bed_point: Vector2 = world.camera.unproject_position(world.plot_positions[bed] + Vector3(0, .3, 0)) * logical / Vector2(world.get_viewport().size)
			top = minf(top, bed_point.y)
		var preferred := Vector2(clampf(point.x - stamp.size.x / 2, 8, logical.x - stamp.size.x - 8), maxf(8, top - stamp.size.y - 18 / scale))
		stamp.position = _clear_stamp_position(preferred, stamp.size, blocked)
		stamp.modulate.a = clampf(1 - (t - pull - STAMP_HOLD) / STAMP_FADE, 0, 1)
		if stamp.visible and stamp.modulate.a > 0: blocked.append(Rect2(stamp.position, stamp.size).grow(4))
		if t >= pull + STAMP_HOLD + STAMP_FADE:
			_remove(i); continue
		if t < pull:
			var tension: float = t / pull
			body.position = origin + Vector3(sin(tension*PI*5)*.035, tension*.11,0)
			body.scale = Vector3(1-tension*.08,1+tension*.16,1-tension*.08)
			body.rotation.z = sin(tension*PI*4)*.09
			pull_pose = maxf(pull_pose, sin(tension*PI)*.9)
		elif t < pull + flight:
			var arc: float = (t-pull)/flight
			body.position = origin + Vector3(.22*arc, sin(arc*PI)*(2.0 if entry.heavy else 1.15), .16*arc)
			body.scale = Vector3.ONE
			body.rotation.z = sin(arc*TAU)*(.18 if entry.heavy else .35)
		else:
			var settle: float = t-pull-flight
			var squash: float = sin(minf(1,settle/.20)*PI) * (.26 if entry.heavy else .13)
			body.position = origin + Vector3(.22, -.05,.16)
			body.scale = Vector3(1+squash,1-squash,1+squash)
			body.rotation.z = -.07
			if settle > .22: body.scale *= maxf(.001, 1-(settle-.22)/.18)
			if settle >= .4: body.hide()
		if t >= pull and not entry.popped:
			entry.popped = true
			if not popped_grades.has(entry.grade):
				popped_grades[entry.grade] = true
				audio.play_grade(entry.grade)
			_scatter(origin, 7 if entry.heavy else 4, entry.heavy)
		if t >= pull+flight and not entry.landed:
			entry.landed = true
			_scatter(origin + Vector3(.22,-.1,.16), 9 if entry.heavy else 3, entry.heavy)
	for i in range(clods.size() - 1, -1, -1):
		var entry: Dictionary = clods[i]
		entry.age += delta
		var node: Node3D = entry.node
		if entry.age >= .7:
			node.queue_free()
			clods.remove_at(i)
			continue
		node.position += Vector3(entry.velocity)*delta
		entry.velocity.y -= delta*9
		if node.position.y < .24:
			node.position.y = .24
			entry.velocity = Vector3.ZERO
		node.rotation.z += delta*3
		node.scale = Vector3(entry.size)*minf(1,(.7-float(entry.age))/.2)

func _stamp_obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var factor: Vector2 = get_tree().root.get_visible_rect().size / Vector2(world.get_viewport().size)
	for centre: Vector3 in world.plot_positions:
		var rect: Rect2
		var first: bool = true
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var point: Vector2 = world.camera.unproject_position(centre + Vector3(x, .3, z) * world.LAND_SPACING) * factor
				if first: rect = Rect2(point, Vector2.ZERO); first = false
				else: rect = rect.expand(point)
		result.append(rect)
	if world.get_viewport() is SubViewport:
		var hud = world.get_viewport().get_parent().get("hud")
		if is_instance_valid(hud):
			for control in [hud._stats_card, hud._spring_target, hud._season_jobs]:
				if is_instance_valid(control) and control.is_visible_in_tree(): result.append(control.get_global_rect())
	return result

func _clear_stamp_position(preferred: Vector2, stamp_size: Vector2, obstacles: Array[Rect2]) -> Vector2:
	var view: Vector2 = get_tree().root.get_visible_rect().size
	var lanes: Array[float] = [preferred.x, 8.0, view.x - stamp_size.x - 8]
	# Search above the receipt first, then below. Field borders and prices
	# remain clear even when a Low receipt would otherwise sit over Home.
	for down in [false, true]:
		for x in lanes:
			var point := Vector2(x, 8 if down else preferred.y)
			for attempt in range(obstacles.size() + 1):
				if point.y < 8 or point.y + stamp_size.y > view.y - 8: break
				var hit: bool = false
				for rect in obstacles:
					if Rect2(point, stamp_size).intersects(rect):
						point.y = rect.end.y + 8 if down else rect.position.y - stamp_size.y - 8
						hit = true; break
				if not hit: return point
	return preferred

func _display_scale() -> float:
	if _canvas_width <= 0:
		_canvas_width = float(get_tree().root.size.x)
		if OS.has_feature("web"):
			_canvas_width = float(JavaScriptBridge.eval("document.getElementById('canvas').clientWidth", true))
	return maxf(.1, _canvas_width / get_tree().root.get_visible_rect().size.x)
