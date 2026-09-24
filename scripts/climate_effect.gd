extends Control
## Batched canvas weather: strong atmosphere without hundreds of particle nodes.
const Climate = preload("res://scripts/climate_system.gd")
var event: String = ""
var strength: float = 0.0
var target_strength: float = 0.0
var clock: float = 0.0
var phase: String = "calm"
var flash: float = 0.0
var strike_flash: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	set_process(false)

func set_weather(info: Dictionary, island: int, paused: bool) -> void:
	strike_flash = float(info.get("operations", {}).get("flash", 0.0))
	event = str(info.event)
	phase = str(info.phase)
	target_strength = 0.0
	if phase == "warning": target_strength = float(info.severity) * lerpf(0.18, 0.65, 1.0 - float(info.timer) / Climate.WARNING_SECONDS)
	if phase == "active": target_strength = float(info.severity)
	if phase == "recovery": target_strength = float(info.severity) * float(info.timer) / Climate.RECOVERY_SECONDS
	if int(info.island) != island or island < Climate.FIRST_ISLAND or paused:
		target_strength = 0.0
		strength = 0.0
	visible = target_strength > 0.0 or strength > 0.005
	set_process(visible)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	strength = move_toward(strength, target_strength, delta * 1.1)
	flash = clampf(strike_flash / 0.75, 0.0, 1.0) if event == "storm" and phase == "active" else 0.0
	if strength <= 0.005 and target_strength == 0.0:
		hide()
		set_process(false)
	queue_redraw()

func _cloud(center: Vector2, width: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for j in range(32):
		var angle: float = float(j) / 32.0 * TAU
		var r: float = 1.0 + 0.12 * sin(angle * 7.0)
		points.append(center + Vector2(cos(angle) * width, sin(angle) * width * 0.38) * r)
	draw_colored_polygon(points, Color(0.12, 0.19, 0.24, alpha))

func _draw() -> void:
	if strength <= 0.0 or size.x <= 0.0: return
	var drought: bool = event == "drought"
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.45, 0.10, 0.13 * strength) if drought else Color(0.10, 0.20, 0.30, 0.18 * strength))
	if drought:
		var sun := Vector2(size.x * 0.64, 125)
		for layer in range(5, 0, -1):
			draw_circle(sun, 38.0 + layer * 24.0, Color(1.0, 0.68, 0.25, 0.025 * strength))
		for ray in range(12):
			var angle: float = ray * TAU / 12.0 + clock * 0.035
			var direction := Vector2.from_angle(angle)
			draw_line(sun + direction * 46, sun + direction * (64 + sin(clock * 2 + ray) * 5), Color(1, 0.79, 0.34, strength * 0.7), 3, true)
		draw_circle(sun, 34, Color(1, 0.88, 0.48, strength * 0.88))
		draw_circle(sun + Vector2(-4, -4), 26, Color(1, 0.96, 0.72, strength * 0.85))
		for band in range(5):
			var heat := PackedVector2Array()
			for j in range(40): heat.append(Vector2(size.x * j / 39.0, size.y * (0.4 + band * 0.08) + sin(j * 0.6 + clock * 2.0 + band) * 3.0))
			draw_polyline(heat, Color(1, 0.85, 0.5, 0.055 * strength), 3, true)
		var dust := PackedVector2Array()
		for i in range(28):
			var pos := Vector2(fposmod(i * 117.0 + clock * 80, size.x + 100.0) - 50, fposmod(i * 173.0, size.y))
			dust.append(pos)
			dust.append(pos + Vector2(14, -2))
		draw_multiline(dust, Color(0.97, 0.76, 0.37, 0.48 * strength), 2.0, true)
	else:
		for i in range(7):
			var x: float = fposmod(i * 243.0 + clock * 19.0, size.x + 560.0) - 280.0
			_cloud(Vector2(x, -35.0 + 20.0 * sin(clock * 0.3 + i)), 235.0 + i * 7.0, 0.64 * strength)
		var rain := PackedVector2Array()
		for i in range(100 if event == "storm" else 72):
			var pos := Vector2(fposmod(i * 139.0 - clock * 290, size.x + 150.0) - 75, fposmod(i * 83.0 + clock * 700, size.y + 80.0) - 40)
			rain.append(pos)
			rain.append(pos + Vector2(-15.0, 34.0))
		draw_multiline(rain, Color(0.72, 0.88, 0.95, strength * (0.42 if phase != "warning" else 0.2)), 1.5, true)
		if event == "flood":
			for i in range(8):
				var points := PackedVector2Array()
				for j in range(33): points.append(Vector2(size.x * j / 32.0, size.y - i * 13.0 + sin(j * 0.5 + clock * 2.0 + i) * 7.0))
				draw_polyline(points, Color(0.3, 0.68, 0.82, 0.17 * strength), 9.0, true)
	# Long wind ribbons sweep across the whole farm, leaving UI and crops readable.
	for i in range(5 if event == "storm" else 3):
		var gust := PackedVector2Array()
		var x: float = fposmod(clock * 390.0 + i * 397, size.x + 600.0) - 600.0
		for j in range(19):
			gust.append(Vector2(x + j * 22.0, size.y * (0.25 + i * 0.13) + sin(j * 0.23 + clock + i) * 19.0))
		draw_polyline(gust, Color(0.86, 0.91, 0.84, 0.32 * strength), 2.5, true)
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.87, 1.0, flash * strength * 0.16))
