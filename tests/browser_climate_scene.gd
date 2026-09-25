extends Node
## Copied to a disposable project with main.test_mode forced true by the exporter.
## No real farm is loaded or saved; scenario changes replace only this lab's state.
var game
var report: Label
var controls: VBoxContainer
var panel: PanelContainer
var frames: Array[float] = []
var calls: float = 0.0
var warmup: float = 2.0
var elapsed: float = 0.0
var scenario: String = "valley"
var coast_toggle: CheckButton

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(14, 15)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("183b32")
	skin.set_corner_radius_all(10)
	skin.content_margin_left = 10
	skin.content_margin_right = 10
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", skin)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var toggle := Button.new()
	toggle.text = "Climate Lab · scenarios"
	toggle.custom_minimum_size = Vector2(288, 34)
	toggle.pressed.connect(func():
		controls.visible = not controls.visible
		panel.reset_size())
	box.add_child(toggle)
	controls = VBoxContainer.new()
	box.add_child(controls)
	var note := Label.new()
	note.text = "Isolated preview · your saved farm is untouched\nWASD / arrows · Hold Shift to sprint\nScroll / pinch to zoom · 50% more land"
	note.add_theme_font_size_override("font_size", 12)
	controls.add_child(note)
	for entry in [["valley", "Island 1 · tank, can, crops"], ["shores", "Island 2 · ordinary sprinklers"], ["practice", "Island 2 · optional practice"], ["winter", "Island 3 · expanded snowy farm"], ["drought", "Dry spell · shared water reserve"], ["flood", "Flood · open the drain"], ["storm", "Storm · trees and automatic shutters"]]:
		var button := Button.new()
		button.text = entry[1]
		button.pressed.connect(func(): _scenario(entry[0]))
		controls.add_child(button)
	var empty := Button.new()
	empty.text = "Empty can · test first refill"
	empty.pressed.connect(func():
		game.state.ClimateSystem.Operations.local(game.state).can = 0.0
		game.state.ClimateSystem.Operations.local(game.state).refilled = false
		game.empty_can_prompted = false
		_fold())
	controls.add_child(empty)
	var upgrades := Button.new()
	upgrades.text = "Open upgrades · plenty of lab coins"
	upgrades.pressed.connect(func():
		game._on_action("tools" if game.state.current_island == 1 else "climate")
		_fold())
	controls.add_child(upgrades)
	var ferry := Button.new()
	ferry.text = "Walk the path to the ferry"
	ferry.pressed.connect(func():
		game.queue_ferry()
		_fold())
	controls.add_child(ferry)
	coast_toggle = CheckButton.new()
	coast_toggle.text = "Coastal water & ice"
	coast_toggle.tooltip_text = "Compare frame times with the coastal water and ice visible or hidden."
	coast_toggle.button_pressed = true
	coast_toggle.toggled.connect(func(enabled: bool):
		game.world.coast.set_effects_enabled(enabled)
		_measure())
	controls.add_child(coast_toggle)
	var mature := Button.new()
	mature.text = "Mature farm · performance test"
	mature.pressed.connect(func():
		for plot in game.state.plots:
			plot.merge({"stage": 3, "watered": true, "frozen": false, "ripe_age": 0.0}, true)
		game._on_state_changed()
		_measure())
	controls.add_child(mature)
	var row := HBoxContainer.new()
	controls.add_child(row)
	for mode in ["balanced", "smooth", "crisp"]:
		var button := Button.new()
		button.text = mode.capitalize()
		button.pressed.connect(func():
			game._apply_graphics_quality(mode)
			_measure())
		row.add_child(button)
	var measure := Button.new()
	measure.text = "Measure another 8 seconds"
	measure.pressed.connect(_measure)
	controls.add_child(measure)
	report = Label.new()
	report.add_theme_font_size_override("font_size", 13)
	controls.add_child(report)
	_scenario("valley")

func _fold() -> void:
	controls.hide()
	panel.reset_size()

func _measure() -> void:
	frames.clear()
	calls = 0
	elapsed = 0
	warmup = 2
	report.text = "Warming up…"

func _scenario(kind: String) -> void:
	scenario = kind
	coast_toggle.set_pressed_no_signal(true)
	game._cancel_walk()
	game._close_equipment()
	game.state.reset_game()
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	game.state.debug_unlock_island(3)
	game.state.travel_to(1 if kind == "valley" else (3 if kind == "winter" else 2))
	game.state.climate.acknowledge(game.state)
	game.state.coins = 1e18
	game.state.pest_timer = 1000.0
	game.state.surge_timer = 1000.0
	game.state.climate.data.timer = 330.0
	game.empty_can_prompted = false
	game.state.expansion = 1
	for plot in game.state.plots:
		plot.merge({"unlocked": true, "tilled": true, "watered": false, "stage": 1, "crop": "russet" if kind == "valley" else ("icecap" if kind == "winter" else "sunburst"), "ripe_age": 0.0}, true)
	if kind == "practice": game.state.climate.data.lesson = game.state.ClimateSystem.Lesson.fresh("offer")
	if kind in ["drought", "flood", "storm"]:
		for plot in game.state.plots:
			plot.watered = true
			plot.stage = 2
		if kind == "flood": game.state.climate.data.projects["2"].drainage = 1
		if kind == "storm":
			game.state.climate.data.projects["2"].windbreaks = 1
			game.state.climate.data.projects["2"].barn = 1
		game.state.climate.begin_warning(game.state, kind, 1)
		game._advance_simulation(45)
	game.hud.close_panel()
	game.hud._climate_alert.dismiss()
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	game._select_tool("water")
	game._on_state_changed()
	_fold()
	_measure()

func _process(delta: float) -> void:
	for plot in game.state.plots: plot.ripe_age = 0.0
	if warmup > 0:
		warmup -= delta
		return
	if elapsed >= 8: return
	frames.append(delta * 1000)
	calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	elapsed += delta
	if elapsed >= 8:
		frames.sort()
		report.text = "%s · %s · coast %s\nUI %s · Farm %s\n%.1f FPS · median %.1f ms · p95 %.1f ms\n%.0f draw calls · %d frames / 8s" % [scenario.capitalize(), game.graphics_quality, "on" if game.world.coast.water_enabled else "off", get_tree().root.size, game.farm_viewport.size, frames.size() / elapsed, frames[frames.size() / 2], frames[int(frames.size() * 0.95)], calls / frames.size(), frames.size()]
		print("BROWSER_PERFORMANCE " + report.text.replace("\n", " | "))
