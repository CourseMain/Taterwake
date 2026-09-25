extends Node
## This scene is exported only into a disposable test-mode project.
var game
var panel: PanelContainer
var controls: VBoxContainer
var report: Label
var elapsed: float = 0.0
var warmup: float = 2.0
var frames: Array[float] = []
func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.state.debug_unlock_island(3)
	game.state.climate.acknowledge(game.state)
	game.state.tutorial_progress.completed = true
	game.state.coins = 1e18
	game.state.capacity = 100000
	game.state.pest_timer = 1000
	game.state.surge_timer = 1000
	for id in game.builds.IDS: game.builds.levels[id] = 20
	for id in game.state.CROP_IDS:
		game.state.storage[id] = 500
		game.state.seed_inventory[id] = 100
	for plot in game.state.plots:
		plot.merge({"tilled":true,"watered":true,"stage":2,"elapsed":0.0},true)
	game._on_state_changed()
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(14,15)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("183b32")
	skin.set_corner_radius_all(10)
	skin.content_margin_left = 10; skin.content_margin_right = 10
	skin.content_margin_top = 8; skin.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",skin)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var toggle := Button.new()
	toggle.text = "Builds & sea lab · scenarios"
	toggle.custom_minimum_size = Vector2(295,36)
	toggle.pressed.connect(func(): controls.visible = not controls.visible; panel.reset_size())
	box.add_child(toggle)
	controls = VBoxContainer.new()
	box.add_child(controls)
	var note := Label.new()
	note.text = "Isolated · saved farm untouched\nFive builds unlocked · crops supplied\nWASD · Shift sprint · scroll to zoom"
	note.add_theme_font_size_override("font_size",12)
	controls.add_child(note)
	button("Explore all five builds",func():
		game.hud._build_selection = ""
		game._on_action("builds")
		fold())
	for id in game.builds.IDS:
		button("Try " + id.capitalize(),func():
			game.builds.select_build(id)
			if id == "farmer":
				for plot in game.state.plots:
					game.state._clear_crop(plot)
					plot.merge({"tilled":true,"stage":1,"watered":false},true)
				game._on_state_changed()
			game.hud._build_selection = id
			game._on_action("builds")
			fold())
	button("Send tax collector · 10 seconds",func():
		game.state.blind_cycle.booms = 3
		game.state.blind_cycle.due_in = 10.0
		game.hud.close_panel()
		game._on_state_changed()
		fold())
	button("Prepare an SSS batch",func():
		game.builds.select_build("industrialist")
		var d: Dictionary = game.builds.professions.data
		d.seedbank = ["hearty","dry"]
		d.fresh_crop = game.state.selected_crop
		d.fresh_count = 500
		d.fresh_left = 45.0
		d.method = "polish" if game.state.selected_crop in ["golden","icecap","radioactive"] else "cure"
		game.hud._build_selection = "industrialist"
		game._on_action("builds")
		fold())
	for island in [1,2,3]:
		button("Island %d · inspect ocean" % island,func():
			game.state.travel_to(island)
			game.state.climate.acknowledge(game.state)
			game.hud.close_panel()
			game._on_state_changed()
			measure()
			fold())
	button("Mature field · stress test",func():
		for plot in game.state.plots: plot.merge({"stage":3,"watered":true,"ripe_age":0.0},true)
		game._on_state_changed()
		measure())
	var row := HBoxContainer.new()
	controls.add_child(row)
	for quality in ["balanced","smooth","crisp"]:
		var b := Button.new()
		b.text = quality.capitalize()
		b.pressed.connect(func(): game._apply_graphics_quality(quality); measure())
		row.add_child(b)
	button("Measure 8 seconds",measure)
	report = Label.new()
	report.add_theme_font_size_override("font_size",12)
	controls.add_child(report)
	fold()
	measure()
func button(title: String, action: Callable) -> void:
	var b := Button.new()
	b.text = title
	b.pressed.connect(action)
	controls.add_child(b)
func fold() -> void:
	controls.hide()
	panel.reset_size()
func measure() -> void:
	frames.clear(); elapsed = 0; warmup = 2
	if is_instance_valid(report): report.text = "Warming up…"
func _process(delta: float) -> void:
	for plot in game.state.plots: plot.ripe_age = 0
	if warmup > 0: warmup -= delta; return
	if elapsed >= 8: return
	frames.append(delta*1000)
	elapsed += delta
	if elapsed >= 8:
		frames.sort()
		report.text = "Island %d · %s · %s\n%.1f FPS · median %.1fms · p95 %.1fms" % [game.state.current_island,game.graphics_quality,game.farm_viewport.size,frames.size()/elapsed,frames[frames.size()/2],frames[int(frames.size()*.95)]]
