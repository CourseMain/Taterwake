extends Node
## Exported only by tools/export_browser_benchmark.py into an isolated project.
## The copied main script is forced into integration mode: no farm reads/writes.
var game
var report: Label
var frames: Array[float] = []
var calls: float = 0.0
var warmup: float = 2.0
var elapsed: float = 0.0

func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.state.island2_unlocked = true
	game.state.travel_to(2)
	game.state.pest_timer = 1000.0
	game.state.surge_timer = 1000.0
	for plot: Dictionary in game.state.plots:
		plot.merge({"unlocked": true, "tilled": true, "watered": true, "stage": 3, "crop": "sunburst", "ripe_age": 0.0}, true)
	game._on_state_changed()
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(15, 260)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	report = Label.new()
	report.add_theme_font_size_override("font_size", 18)
	box.add_child(report)
	var row := HBoxContainer.new()
	box.add_child(row)
	for mode: String in ["balanced", "smooth", "crisp"]:
		var button := Button.new()
		button.text = mode.capitalize()
		button.pressed.connect(func():
			game._apply_graphics_quality(mode)
			frames.clear()
			calls = 0
			elapsed = 0
			warmup = 2)
		row.add_child(button)
	var menu := Button.new()
	menu.text = "Menu / text sharpness"
	menu.pressed.connect(func(): game._on_action("menu"))
	box.add_child(menu)

func _process(delta: float) -> void:
	# Pin crop age while exercising real gameplay, HUD, audio and animations.
	for plot: Dictionary in game.state.plots: plot.ripe_age = 0.0
	if warmup > 0:
		warmup -= delta
		report.text = "Warming up…"
		return
	if elapsed >= 8.0: return
	frames.append(delta * 1000.0)
	calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	elapsed += delta
	if elapsed >= 8.0:
		frames.sort()
		var farm_size: Vector2i = game.farm_viewport.size if "farm_viewport" in game else get_tree().root.size
		report.text = "%s · %s\nUI %s · 3D %s\n%.1f FPS · median %.1f ms · p95 %.1f ms\n%.0f draw calls · %d frames · 8s sample" % [ProjectSettings.get_setting("application/config/version"), game.graphics_quality, get_tree().root.size, farm_size, frames.size() / elapsed, frames[frames.size() / 2], frames[int(frames.size() * 0.95)], calls / frames.size(), frames.size()]
		print("BROWSER_PERFORMANCE " + report.text.replace("\n", " | "))
