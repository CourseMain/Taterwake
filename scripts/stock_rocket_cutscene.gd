extends Control
## A self-contained, deterministic launch film. Its finished signal is the handoff
## to the market event; no game state or save file is accessed here.
signal finished

const DURATION: float = 7.4
const IGNITION_AT: float = 2.05
const LIFTOFF_AT: float = 2.65
const LAUNCH_SOUND = preload("res://assets/audio/stock-rocket-launch.wav")
const SKY_SHADER = preload("res://scripts/stock_rocket_sky.gdshader")
var active: bool = false
var elapsed: float = 0.0
var island: int = 3
var _sky: ColorRect
var _sky_material: ShaderMaterial
var _art: Control
var _player: AudioStreamPlayer
var _sound: AudioStreamWAV
var _font: Font
var _bold_font: Font
var _accent := Color("81f7dc")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Avenir Next", "DejaVu Sans", "Arial"])
	bold.font_weight = 800
	_bold_font = bold
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	_sky.material = _sky_material
	add_child(_sky)
	# A child canvas draws on top of the shader, while the parent owns input.
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.draw.connect(_draw_film)
	add_child(_art)
	_player = AudioStreamPlayer.new()
	_player.name = "RocketLaunchAudio"
	_player.volume_db = -5.0
	add_child(_player)
	# Baked from the original deterministic score; no sample loop on the web main thread.
	_sound = LAUNCH_SOUND
	_player.stream = _sound
	resized.connect(_refresh)
	hide()
	set_process(false)
	set_process_input(false)

func start(island_id: int = 3) -> void:
	island = clampi(island_id, 1, 3)
	_accent = [Color("81f7b4"), Color("ffd977"), Color("81e7ff")][island - 1]
	elapsed = 0.0
	active = true
	show()
	set_process(true)
	set_process_input(true)
	# Mouse filtering alone does not protect focused HUD buttons from keyboard
	# or controller activation. Clear focus and trap input before GUI dispatch.
	get_viewport().gui_release_focus()
	if is_instance_valid(_player):
		_player.play()
	_refresh()

func stop() -> void:
	active = false
	hide()
	set_process(false)
	set_process_input(false)
	if is_instance_valid(_player):
		_player.stop()

func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null

func _process(delta: float) -> void:
	if not active or not is_finite(delta) or delta < 0.0:
		return
	elapsed = minf(DURATION, elapsed + delta)
	if elapsed >= DURATION:
		stop()
		finished.emit()
		return
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_sky_material) or not is_instance_valid(_art):
		return
	_sky_material.set_shader_parameter("clock_time", elapsed)
	_sky_material.set_shader_parameter("altitude", _altitude())
	_sky_material.set_shader_parameter("ignition", _ignition() * (1.0 - smoothstep(4.0, 6.1, elapsed)))
	_sky_material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))
	_sky_material.set_shader_parameter("accent", _accent)
	_art.queue_redraw()

func _altitude() -> float:
	var flight: float = maxf(0.0, elapsed - LIFTOFF_AT)
	return 56.0 * flight + 90.0 * flight * flight

func _ignition() -> float:
	return smoothstep(IGNITION_AT, LIFTOFF_AT, elapsed)

func _camera_offset() -> float:
	return maxf(0.0, _altitude() - 240.0) * 0.76

func _rocket_position() -> Vector2:
	var bend: float = smoothstep(4.25, 6.2, elapsed)
	return Vector2(640.0 + bend * bend * 220.0, 626.0 - _altitude() + _camera_offset())

func _rocket_scale() -> float:
	return lerpf(1.0, 0.10, smoothstep(3.95, 6.3, elapsed))

func _shake() -> Vector2:
	var attack: float = smoothstep(IGNITION_AT, LIFTOFF_AT + 0.08, elapsed)
	var decay: float = 1.0 - smoothstep(LIFTOFF_AT + 0.14, 4.1, elapsed)
	return Vector2(sin(elapsed * 127.0) + sin(elapsed * 83.0) * 0.33, cos(elapsed * 111.0)) * attack * decay * 8.0

func _draw_film() -> void:
	if not active or size.x <= 0.0 or size.y <= 0.0:
		return
	var fit: float = minf(size.x / 1280.0, size.y / 800.0)
	var margin: Vector2 = (size - Vector2(1280, 800) * fit) * 0.5
	var camera: float = _camera_offset()
	_art.draw_set_transform(margin + _shake() * fit, 0.0, Vector2.ONE * fit)
	_draw_moon(Vector2(1090, 160 + camera * 0.026))
	_draw_constellations(camera)
	_draw_landscape(camera)
	_draw_smoke(camera, false)
	if elapsed < 6.3:
		var rocket: Vector2 = _rocket_position()
		var scale_factor: float = _rocket_scale()
		_draw_exhaust(rocket, scale_factor)
		_art.draw_set_transform(margin + (rocket + _shake()) * fit, smoothstep(4.4, 6.2, elapsed) * 0.24, Vector2.ONE * fit * scale_factor)
		_draw_rocket()
		_art.draw_set_transform(margin + _shake() * fit, 0.0, Vector2.ONE * fit)
	_draw_smoke(camera, true)
	_draw_motion_lines()
	_art.draw_set_transform(margin, 0.0, Vector2.ONE * fit)
	_draw_titles()
	_draw_finale()
	# Letterbox, opening fade and exit fade use actual viewport coordinates.
	_art.draw_set_transform(Vector2.ZERO)
	var letterbox: float = size.y * 0.046
	_art.draw_rect(Rect2(0, 0, size.x, letterbox), Color("050b17"))
	_art.draw_rect(Rect2(0, size.y - letterbox, size.x, letterbox), Color("050b17"))
	var fade: float = maxf(1.0 - smoothstep(0.0, 0.30, elapsed), smoothstep(DURATION - 0.42, DURATION, elapsed))
	if fade > 0.0:
		_art.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.026, 0.055, fade))

func _draw_moon(center: Vector2) -> void:
	for glow in range(6, 0, -1):
		_art.draw_circle(center, 49.0 + glow * 11.0, Color(0.55, 0.75, 0.98, 0.012 + (6 - glow) * 0.002))
	_art.draw_circle(center, 49, Color("bdd6e3"))
	_art.draw_circle(center + Vector2(-9, -5), 40, Color("e9ead7"))
	for crater: Vector3 in [Vector3(-19, -16, 10), Vector3(13, 11, 15), Vector3(-10, 22, 6), Vector3(17, -20, 5)]:
		_art.draw_circle(center + Vector2(crater.x, crater.y), crater.z, Color("b5c7c9"))
		_art.draw_circle(center + Vector2(crater.x - 2, crater.y - 2), crater.z * 0.78, Color("cbd6d0"))

func _draw_constellations(camera: float) -> void:
	var points := PackedVector2Array([Vector2(116, 206), Vector2(189, 167), Vector2(249, 200), Vector2(264, 274), Vector2(315, 302)])
	for i in range(points.size()):
		points[i].y += camera * 0.014
	_art.draw_polyline(points, Color(0.48, 0.68, 0.84, 0.12), 1.0, true)
	for point in points:
		_art.draw_circle(point, 2.3, Color("9daece"))
	var center := Vector2(939, 306 + camera * 0.025)
	_art.draw_line(center - Vector2(6, 0), center + Vector2(6, 0), Color(0.73, 0.90, 1.0, 0.6), 1.0, true)
	_art.draw_line(center - Vector2(0, 6), center + Vector2(0, 6), Color(0.73, 0.90, 1.0, 0.6), 1.0, true)

func _draw_landscape(camera: float) -> void:
	if camera > 380.0:
		return
	var offset: float = camera
	_poly(PackedVector2Array([Vector2(-200, 640 + offset * 0.4), Vector2(-200, 529 + offset * 0.4), Vector2(115, 488 + offset * 0.4), Vector2(237, 541 + offset * 0.4), Vector2(419, 481 + offset * 0.4), Vector2(579, 547 + offset * 0.4), Vector2(780, 494 + offset * 0.4), Vector2(961, 529 + offset * 0.4), Vector2(1167, 471 + offset * 0.4), Vector2(1480, 550 + offset * 0.4), Vector2(1480, 940)]), Color("16283a"))
	_poly(PackedVector2Array([Vector2(-200, 606 + offset * 0.7), Vector2(107, 566 + offset * 0.7), Vector2(282, 608 + offset * 0.7), Vector2(433, 563 + offset * 0.7), Vector2(666, 609 + offset * 0.7), Vector2(843, 565 + offset * 0.7), Vector2(1116, 607 + offset * 0.7), Vector2(1480, 560 + offset * 0.7), Vector2(1480, 1050), Vector2(-200, 1050)]), Color("101f31"))
	_art.draw_rect(Rect2(-300, 662 + offset, 1880, 600), Color("0a1523"))
	_art.draw_line(Vector2(-100, 662 + offset), Vector2(1380, 662 + offset), Color("283c4c"), 2.0, true)
	# A gantry, service cabin, and runway lights give the launch a physical place.
	var gy: float = 640 + offset
	_art.draw_rect(Rect2(488, gy - 226, 12, 226), Color("314655"))
	_art.draw_rect(Rect2(533, gy - 226, 9, 226), Color("233a4b"))
	for index in range(6):
		_art.draw_line(Vector2(499, gy - index * 36), Vector2(533, gy - (index + 1) * 36), Color("284252"), 5.0, true)
	_art.draw_line(Vector2(488, gy - 227), Vector2(571 - _ignition() * 34, gy - 227), Color("4a6170"), 8.0, true)
	_art.draw_rect(Rect2(174, gy - 32, 117, 34), Color("223847"))
	_art.draw_rect(Rect2(189, gy - 24, 31, 11), Color("acd6bb"))
	_art.draw_rect(Rect2(232, gy - 24, 31, 11), Color("496f74"))
	_art.draw_line(Vector2(254, gy - 34), Vector2(254, gy - 72), Color("5d727a"), 2.0, true)
	_art.draw_circle(Vector2(254, gy - 74), 3, Color("ed907d"))
	_ellipse(Vector2(640, 655 + offset), Vector2(180, 25), Color("233747"))
	_ellipse(Vector2(640, 649 + offset), Vector2(146, 15), Color("41515b"))
	_ellipse(Vector2(640, 650 + offset), Vector2(101, 8), Color("1d2c38"))
	for index in range(17):
		var light_position := Vector2(74 + index * 73, 680 + offset + absf(index - 8) * 5)
		_art.draw_circle(light_position, 7, Color(1.0, 0.67, 0.23, 0.05))
		_art.draw_circle(light_position, 2.0, Color("f6cc87"))

func _draw_rocket() -> void:
	var edge := Color("182a39")
	# Curved nacelle, blue shaded side, warm ivory main hull, copper nose.
	_poly(PackedVector2Array([Vector2(-38, -91), Vector2(-76, -35), Vector2(-80, 12), Vector2(-37, -9), Vector2(-20, -75)]), Color("70bac6"), edge, 4)
	_poly(PackedVector2Array([Vector2(38, -91), Vector2(76, -35), Vector2(80, 12), Vector2(37, -9), Vector2(20, -75)]), Color("488697"), edge, 4)
	_poly(PackedVector2Array([Vector2(-35, -28), Vector2(-31, 7), Vector2(31, 7), Vector2(35, -28)]), Color("4a5765"), edge, 4)
	_art.draw_rect(Rect2(-24, -17, 48, 10), Color("202b3e"))
	var hull := PackedVector2Array()
	for i in range(21):
		var t: float = float(i) / 20.0
		var point: Vector2 = Vector2(0, -268).bezier_interpolate(Vector2(-49, -231), Vector2(-48, -189), Vector2(-43, -43), t)
		hull.append(point)
	hull.append(Vector2(-31, -26))
	hull.append(Vector2(31, -26))
	for i in range(21):
		var t: float = 1.0 - float(i) / 20.0
		var point: Vector2 = Vector2(0, -268).bezier_interpolate(Vector2(49, -231), Vector2(48, -189), Vector2(43, -43), t)
		hull.append(point)
	_poly(hull, Color("f1e5c9"), edge, 4)
	_poly(PackedVector2Array([Vector2(15, -246), Vector2(34, -212), Vector2(42, -162), Vector2(43, -43), Vector2(31, -27), Vector2(15, -27), Vector2(24, -111), Vector2(22, -213)]), Color("b9cdd0"))
	var nose := PackedVector2Array([Vector2(-32, -217)])
	for i in range(21):
		var angle: float = PI + float(i) / 20.0 * PI
		var x: float = cos(angle) * 32.0
		var y: float = -217.0 - pow(maxf(0.0, -sin(angle)), 1.2) * 51.0
		nose.append(Vector2(x, y))
	_poly(nose, Color("e99c77"), edge, 3)
	_art.draw_line(Vector2(-18, -223), Vector2(-5, -246), Color("ffcf9b"), 5.0, true)
	_art.draw_line(Vector2(-42, -66), Vector2(42, -66), Color("739da5"), 11.0, true)
	_art.draw_line(Vector2(-41, -73), Vector2(40, -73), Color("e2c286"), 3.0, true)
	# The brave little potato in the porthole anchors this in Taterland.
	_art.draw_circle(Vector2(0, -158), 35, edge)
	_art.draw_circle(Vector2(0, -160), 31, Color("7bb6c5"))
	_art.draw_circle(Vector2(0, -160), 25, Color("203e54"))
	_ellipse(Vector2(0, -154), Vector2(17, 21), Color("d7a779"))
	_ellipse(Vector2(-3, -158), Vector2(12, 16), Color("e8c28a"))
	_art.draw_circle(Vector2(-6, -157), 2.2, edge)
	_art.draw_circle(Vector2(6, -157), 2.2, edge)
	_art.draw_arc(Vector2(0, -155), 7, 0.24, PI - 0.24, 14, edge, 1.6, true)
	_art.draw_circle(Vector2(-11, -151), 3, Color("d79372"))
	_art.draw_circle(Vector2(11, -151), 3, Color("d79372"))
	_art.draw_arc(Vector2(0, -160), 26, PI * 1.07, PI * 1.53, 18, Color(0.85, 0.98, 1.0, 0.60), 3, true)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		_art.draw_circle(Vector2(0, -160) + Vector2.from_angle(angle) * 29.0, 2, Color("e4e8cb"))
	_text("SPUD", Vector2(0, -103), 16, edge, true, true)
	_text("01", Vector2(0, -82), 12, Color("557081"), true)
	_poly(PackedVector2Array([Vector2(-7, -79), Vector2(7, -79), Vector2(10, 8), Vector2(0, 17), Vector2(-10, 8)]), Color("8dc3c7"), edge, 3)
	_art.draw_line(Vector2(-25, -196), Vector2(-29, -184), Color("fff6df"), 4.0, true)

func _draw_exhaust(origin: Vector2, rocket_size: float) -> void:
	if elapsed < IGNITION_AT:
		return
	var power: float = _ignition()
	var flight: float = maxf(0.0, elapsed - LIFTOFF_AT)
	var length: float = (48.0 + power * 200.0 + flight * 152.0) * maxf(0.55, rocket_size)
	var nozzle: Vector2 = origin + Vector2(0, 7) * rocket_size
	var width: float = 24.0 * rocket_size * power
	var flicker: float = 0.93 + 0.07 * sin(elapsed * 78.0)
	for glow in range(6, 0, -1):
		_ellipse(nozzle + Vector2(0, length * 0.27), Vector2(width * (1 + glow * 0.9), length * (0.42 + glow * 0.04)), Color(1.0, 0.32 + glow * 0.045, 0.09, 0.016 * power))
	var plume := PackedVector2Array([nozzle + Vector2(-width, 0), nozzle + Vector2(-width * 1.7, length * 0.26), nozzle + Vector2(-width * 1.25, length * 0.49), nozzle + Vector2(-width * 0.9, length * 0.71), nozzle + Vector2(0, length * flicker), nozzle + Vector2(width * 0.85, length * 0.75), nozzle + Vector2(width * 1.40, length * 0.43), nozzle + Vector2(width * 1.55, length * 0.19), nozzle + Vector2(width, 0)])
	_poly(plume, Color(1.0, 0.43, 0.11, 0.91))
	_poly(PackedVector2Array([nozzle + Vector2(-width * 0.7, 0), nozzle + Vector2(-width * 0.8, length * 0.31), nozzle + Vector2(0, length * 0.78 * flicker), nozzle + Vector2(width * 0.8, length * 0.29), nozzle + Vector2(width * 0.7, 0)]), Color("ffce63"))
	_poly(PackedVector2Array([nozzle + Vector2(-width * 0.4, 0), nozzle + Vector2(0, length * 0.52 * flicker), nozzle + Vector2(width * 0.4, 0)]), Color("fff6ce"))
	for i in range(38):
		var fraction: float = fposmod(float(i) * 0.139 + elapsed * (0.43 + float(i % 3) * 0.05), 1.0)
		var side: float = sin(float(i) * 7.17) * (width + fraction * 85.0)
		var point: Vector2 = nozzle + Vector2(side, fraction * length * 1.4)
		_art.draw_line(point, point + Vector2(side * 0.04, 5.0 + fraction * 17.0), Color(1.0, 0.73, 0.31, (1.0 - fraction) * power * 0.75), 1.5, true)

func _draw_smoke(camera: float, foreground: bool) -> void:
	if elapsed < IGNITION_AT or camera > 950.0:
		return
	var since: float = elapsed - IGNITION_AT
	for index in range(42):
		if (index % 2 == 0) != foreground:
			continue
		var birth: float = float(index / 2) * 0.085
		var age: float = since - birth
		if age <= 0.0:
			continue
		var direction: float = -1.0 if index % 4 < 2 else 1.0
		var speed: float = 70.0 + float(index % 7) * 16.0
		var point := Vector2(640 + direction * (30.0 + age * speed), 653 + camera - age * (15.0 + index % 5 * 8.0))
		var radius: float = 16.0 + age * (28.0 + index % 3 * 10.0)
		var opacity: float = minf(1.0, age * 6.0) * (1.0 - smoothstep(1.3, 4.1, age))
		var smoke_color: Color = Color("687681") if foreground else Color("384957")
		smoke_color = smoke_color.lerp(Color("efb980"), clampf(1.0 - absf(point.x - 640.0) / 270.0, 0.0, 1.0) * _ignition() * 0.62)
		_art.draw_circle(point, radius, Color(smoke_color, opacity * 0.85))
		_art.draw_circle(point + Vector2(direction * radius * 0.34, -radius * 0.34), radius * 0.73, Color(smoke_color.lightened(0.10), opacity * 0.73))
		_art.draw_arc(point, radius * 0.83, PI * 1.08, PI * 1.71, 16, Color(smoke_color.lightened(0.20), opacity * 0.22), 2, true)

func _draw_motion_lines() -> void:
	var energy: float = smoothstep(3.2, 4.6, elapsed) * (1.0 - smoothstep(5.55, 6.25, elapsed))
	if energy <= 0.0:
		return
	for index in range(32):
		var x: float = 40 + fposmod(index * 191.7, 1200.0)
		if absf(x - _rocket_position().x) < 100:
			continue
		var y: float = fposmod(index * 173.4 + elapsed * (170.0 + index * 6), 820.0)
		_art.draw_line(Vector2(x, y), Vector2(x - 3, y + energy * (16 + index % 5 * 12)), Color(0.67, 0.85, 1.0, energy * 0.22), 1.5, true)

func _draw_titles() -> void:
	var fade: float = 1.0 - smoothstep(4.8, 5.6, elapsed)
	_art.draw_circle(Vector2(88, 88), 4, Color(_accent, fade))
	_text("TATERLAND  /  SPACE PROGRAM", Vector2(105, 93), 15, Color("b2cbd9") * Color(1, 1, 1, fade), false, true)
	_text("MISSION  0%d" % island, Vector2(1105, 94), 13, Color(0.65, 0.78, 0.84, fade), true)
	if elapsed < LIFTOFF_AT:
		_text("A LITTLE SPUD.", Vector2(88, 350), 31, Color("f5ecce"), false, true)
		_text("A GIANT LEAP.", Vector2(88, 391), 31, _accent, false, true)
		_text("The market is going somewhere new.", Vector2(89, 424), 16, Color("9ab4c6"))
		var remaining: int = maxi(1, 3 - int(elapsed / (IGNITION_AT / 3.0)))
		var countdown: float = fposmod(elapsed, IGNITION_AT / 3.0) / (IGNITION_AT / 3.0)
		var ring := Vector2(905, 437)
		_art.draw_arc(ring, 61, -PI * 0.5, PI * 1.5, 90, Color(0.65, 0.83, 0.85, 0.12), 2, true)
		_art.draw_arc(ring, 61, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - countdown), 90, _accent, 3, true)
		_text(str(remaining) if elapsed < IGNITION_AT else "GO", ring + Vector2(0, 20), 55 if elapsed < IGNITION_AT else 39, Color("f4efda"), true, true)
		_text("ENGINE CHECK" if elapsed < IGNITION_AT else "IGNITION", ring + Vector2(0, 94), 13, _accent, true, true)
	else:
		var subtitle: float = smoothstep(LIFTOFF_AT, 2.9, elapsed) * fade
		_text("LIFTOFF", Vector2(88, 361), 45, Color(_accent, subtitle), false, true)
		_text("Big dreams. Tiny astronaut.", Vector2(90, 393), 16, Color(0.68, 0.80, 0.86, subtitle))
	var bottom_alpha: float = 1.0 - smoothstep(5.2, 5.8, elapsed)
	_text("FLIGHT  SPUD–01", Vector2(89, 722), 13, Color(0.62, 0.77, 0.83, bottom_alpha), false, true)
	_text("T + %04.1f s" % maxf(0.0, elapsed - LIFTOFF_AT) if elapsed >= LIFTOFF_AT else "LAUNCH SEQUENCE", Vector2(1110, 722), 13, Color(_accent, bottom_alpha), true)
	_art.draw_line(Vector2(264, 717), Vector2(999, 717), Color(0.48, 0.71, 0.80, bottom_alpha * 0.18), 2, true)
	_art.draw_line(Vector2(264, 717), Vector2(264 + 735 * minf(1.0, elapsed / 5.8), 717), Color(_accent, bottom_alpha * 0.72), 2, true)

func _draw_finale() -> void:
	var progress: float = smoothstep(5.75, 6.3, elapsed)
	if progress <= 0.0:
		return
	var star := Vector2(860, 136)
	var burst: float = maxf(0.0, 1.0 - absf(elapsed - 6.06) / 0.38)
	for ray in range(8):
		var direction: Vector2 = Vector2.from_angle(float(ray) * TAU / 8.0)
		_art.draw_line(star + direction * 6, star + direction * (12 + burst * 66), Color(_accent, burst * 0.7), 2, true)
	_art.draw_circle(star, 3 + burst * 7, Color(1.0, 0.96, 0.75, 1.0 - smoothstep(6.3, 6.8, elapsed)))
	var y: float = 342 + (1.0 - progress) * 18
	_text("NEXT STOP", Vector2(640, y - 48), 18, Color(_accent, progress), true, true)
	_text("THE MOON", Vector2(640, y + 20), 72, Color(0.97, 0.94, 0.84, progress), true, true)
	_art.draw_line(Vector2(532, y + 46), Vector2(748, y + 46), Color(_accent, progress * 0.65), 2, true)
	_text("STOCK BOOM INCOMING", Vector2(640, y + 87), 19, Color(_accent, progress), true, true)
	_text("One small spud. One very big opportunity.", Vector2(640, y + 120), 16, Color(0.63, 0.76, 0.83, progress), true)
	for index in range(20):
		var angle: float = index * 2.399
		var radial: float = 145 + index % 4 * 31 + (elapsed - 5.75) * 12
		var point := Vector2(640, y + 5) + Vector2(cos(angle) * radial * 1.85, sin(angle) * radial)
		_art.draw_circle(point, 1.0 + index % 2, Color(_accent, progress * 0.55))

func _text(value: String, baseline: Vector2, font_size: int, color: Color, centered: bool = false, bold: bool = false) -> void:
	var font: Font = _bold_font if bold else _font
	var pos: Vector2 = baseline
	if centered:
		pos.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	_art.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _poly(points: PackedVector2Array, color: Color, outline: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
	_art.draw_colored_polygon(points, color)
	if outline.a > 0.0:
		var border: PackedVector2Array = points.duplicate()
		border.append(points[0])
		_art.draw_polyline(border, outline, width, true)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		var angle: float = float(index) / 48.0 * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	_art.draw_colored_polygon(points, color)
