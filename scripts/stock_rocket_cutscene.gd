extends Control
## A self-contained, deterministic launch film. Its finished signal is the handoff
## to the market event; no game state or save file is accessed here.
signal finished

const DURATION: float = 7.4
const IGNITION_AT: float = 2.05
const LIFTOFF_AT: float = 2.65
const MONEY_PARTICLES: int = 42
const POTATO_COLORS: Array[Color] = [Color("e9af62"), Color("f3c981"), Color("dc9755"), Color("f6d99b")]
const CELEBRATION_COLORS: Array[Color] = [Color("ffe34a"), Color("36beff"), Color("ff5262"), Color("ff963d"), Color("ff76da")]
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
var _ellipse_unit := PackedVector2Array()

func _ready() -> void:
	for point: int in range(24):
		_ellipse_unit.append(Vector2.from_angle(float(point) / 24.0 * TAU))
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
	_player.volume_db = -4.0
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
	return lerpf(1.0, 0.10, smoothstep(3.65, 6.3, elapsed))

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
	_draw_colour_ribbons()
	_draw_money_streams()
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

func _draw_potato(center: Vector2, radius: float, character: int, alpha: float = 1.0) -> void:
	var ink: Color = Color("382840")
	var skin: Color = POTATO_COLORS[character % POTATO_COLORS.size()]
	var bounce: float = sin(elapsed * 4.0 + character * 1.7) * _ignition() * radius * 0.08
	center.y += bounce
	_ellipse(center, Vector2(radius * 0.84, radius), Color(ink, alpha))
	_ellipse(center + Vector2(-radius * 0.05, -radius * 0.05), Vector2(radius * 0.74, radius * 0.91), Color(skin, alpha))
	_ellipse(center + Vector2(-radius * 0.28, -radius * 0.34), Vector2(radius * 0.20, radius * 0.29), Color("ffe9b4") * Color(1, 1, 1, alpha * 0.72))
	for side: float in [-1.0, 1.0]:
		_art.draw_circle(center + Vector2(side * radius * 0.29, -radius * 0.12), radius * 0.095, Color(ink, alpha))
		_ellipse(center + Vector2(side * radius * 0.48, radius * 0.16), Vector2(radius * 0.19, radius * 0.10), Color("ff8b8c") * Color(1, 1, 1, alpha * 0.9))
	_art.draw_arc(center + Vector2(0, radius * 0.10), radius * 0.25, 0.16, PI - 0.16, 8, Color(ink, alpha), maxf(1.3, radius * 0.07), true)
	# Tiny freckles and a jaunty sprout give every passenger a distinct face.
	_art.draw_circle(center + Vector2(radius * 0.30, -radius * 0.60), radius * 0.055, Color(ink, alpha * 0.4))
	if character % 3 == 0:
		_art.draw_line(center + Vector2(0, -radius * 0.83), center + Vector2(-radius * 0.13, -radius * 1.12), Color("73db98") * Color(1, 1, 1, alpha), maxf(2.0, radius * 0.11), true)
		_ellipse(center + Vector2(radius * 0.07, -radius * 1.07), Vector2(radius * 0.20, radius * 0.09), Color("a9f1a8") * Color(1, 1, 1, alpha))

func _draw_rocket() -> void:
	var edge := Color("172c48")
	# Candy-coloured boosters frame a big, visibly full glass passenger hold.
	for side: float in [-1.0, 1.0]:
		var fin: Color = Color("ff983d") if side < 0 else Color("ff76da")
		_poly(PackedVector2Array([Vector2(side * 48, -112), Vector2(side * 108, -64), Vector2(side * 120, 19), Vector2(side * 58, -13), Vector2(side * 34, -84)]), fin, edge, 4)
		_poly(PackedVector2Array([Vector2(side * 78, -168), Vector2(side * 93, -144), Vector2(side * 93, -25), Vector2(side * 66, -25), Vector2(side * 66, -144)]), Color("37bcff"), edge, 4)
		_art.draw_line(Vector2(side * 72, -130), Vector2(side * 72, -45), Color("b9f2ff"), 5, true)
		_art.draw_rect(Rect2(side * 79 - 14, -32, 28, 20), Color("ffe34a"))
	_poly(PackedVector2Array([Vector2(-42, -30), Vector2(-34, 11), Vector2(34, 11), Vector2(42, -30)]), Color("324d72"), edge, 4)
	_art.draw_rect(Rect2(-27, -9, 54, 13), Color("17243d"))
	var hull := PackedVector2Array([Vector2(0, -364), Vector2(-31, -338), Vector2(-51, -303), Vector2(-60, -268), Vector2(-63, -83), Vector2(-55, -46), Vector2(-36, -26), Vector2(36, -26), Vector2(55, -46), Vector2(63, -83), Vector2(60, -268), Vector2(51, -303), Vector2(31, -338)])
	_poly(hull, Color("fff1c9"), edge, 5)
	_poly(PackedVector2Array([Vector2(26, -327), Vector2(49, -297), Vector2(58, -261), Vector2(61, -84), Vector2(53, -48), Vector2(32, -29), Vector2(21, -29), Vector2(40, -90), Vector2(41, -264)]), Color("a7d9ed"))
	_poly(PackedVector2Array([Vector2(0, -364), Vector2(-31, -338), Vector2(-49, -307), Vector2(49, -307), Vector2(31, -338)]), Color("ff536b"), edge, 4)
	_art.draw_line(Vector2(-22, -324), Vector2(-4, -347), Color("ffc49d"), 6, true)
	_art.draw_circle(Vector2(0, -279), 30, edge)
	_art.draw_circle(Vector2(0, -280), 26, Color("329dc7"))
	_draw_potato(Vector2(0, -277), 20, 0)
	_art.draw_arc(Vector2(0, -280), 24, PI * 1.09, PI * 1.52, 12, Color(0.88, 1.0, 1.0, 0.8), 3, true)
	# Four close-packed rows plus the captain: thirteen potatoes, no empty hold.
	_poly(PackedVector2Array([Vector2(-49, -241), Vector2(49, -241), Vector2(50, -84), Vector2(43, -74), Vector2(-43, -74), Vector2(-50, -84)]), Color("1f4762"), edge, 3)
	for row: int in range(4):
		for column: int in range(3):
			var crew: int = 1 + row * 3 + column
			_draw_potato(Vector2((column - 1) * 30.0 + (2.0 if row % 2 else -2.0), -220.0 + row * 39.0), 21.0, crew)
	_art.draw_line(Vector2(-47, -238), Vector2(-47, -86), Color(0.66, 0.93, 1.0, 0.62), 3, true)
	_art.draw_line(Vector2(46, -236), Vector2(46, -84), Color(0.56, 0.84, 1.0, 0.34), 3, true)
	_art.draw_line(Vector2(-59, -66), Vector2(58, -66), Color("ffd949"), 13, true)
	_text("SPUD EXPRESS", Vector2(0, -43), 12, edge, true, true)
	_poly(PackedVector2Array([Vector2(-8, -36), Vector2(8, -36), Vector2(12, 13), Vector2(0, 24), Vector2(-12, 13)]), Color("ff536b"), edge, 3)

func _draw_money_symbol(center: Vector2, radius: float, index: int, alpha: float) -> void:
	var color: Color = CELEBRATION_COLORS[index % CELEBRATION_COLORS.size()]
	if index % 3 == 0:
		_text("$", center + Vector2(0, radius * 0.56), int(radius * 2.0), Color(color, alpha), true, true)
		return
	var width: float = radius * (0.54 + absf(cos(elapsed * 2.7 + index)) * 0.46)
	_ellipse(center + Vector2(2, 3), Vector2(width + 2, radius + 2), Color("182a49") * Color(1, 1, 1, alpha * 0.6))
	_ellipse(center, Vector2(width, radius), Color(color.darkened(0.12), alpha))
	_ellipse(center + Vector2(-1, -1), Vector2(width * 0.81, radius * 0.81), Color(color.lightened(0.20), alpha))
	if width > radius * 0.70:
		_text("$", center + Vector2(0, radius * 0.42), int(radius * 1.35), Color("27364f") * Color(1, 1, 1, alpha), true, true)

func _draw_money_streams() -> void:
	var energy: float = smoothstep(IGNITION_AT - 0.18, LIFTOFF_AT + 0.3, elapsed) * (1.0 - smoothstep(5.8, 6.35, elapsed))
	if energy <= 0.0:
		return
	var origin: Vector2 = _rocket_position()
	for index: int in range(MONEY_PARTICLES):
		var life: float = fposmod(index * 0.137 + elapsed * 0.53, 1.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var spread: float = 91.0 + life * (170.0 + index % 4 * 23.0)
		var point: Vector2 = origin + Vector2(side * spread, 15.0 + life * 190.0 - sin(life * PI) * 190.0)
		point.y -= smoothstep(3.0, 4.4, elapsed) * (index % 5) * 58.0
		if point.x < 450.0 and point.y > 300.0 and point.y < 445.0 and elapsed < 5.6:
			continue
		if point.x > 825.0 and point.y > 340.0 and point.y < 550.0 and elapsed < LIFTOFF_AT:
			continue
		var opacity: float = energy * smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.84, 1.0, life))
		var color: Color = CELEBRATION_COLORS[index % 5]
		_art.draw_line(point + Vector2(-side * 7, 10), point + Vector2(-side * 16, 26), Color(color, opacity * 0.34), 3, true)
		_draw_money_symbol(point, 11.0 + index % 4 * 3.0, index, opacity)

func _draw_colour_ribbons() -> void:
	var energy: float = smoothstep(2.3, 3.7, elapsed) * (1.0 - smoothstep(5.7, 6.3, elapsed))
	if energy <= 0.0:
		return
	for ribbon: int in range(5):
		var points := PackedVector2Array()
		var side: float = -1.0 if ribbon % 2 == 0 else 1.0
		for point: int in range(20):
			var progress: float = float(point) / 19.0
			var spread: float = 55.0 + pow(progress, 0.70) * (235.0 + ribbon * 35.0)
			points.append(Vector2(640 + side * spread + sin(progress * PI * 2.0 - elapsed * 1.8 + ribbon) * 25.0 * progress, 665 - progress * 575 + _camera_offset() * 0.12))
		var color: Color = CELEBRATION_COLORS[ribbon]
		_art.draw_polyline(points, Color(color, energy * 0.06), 19.0, true)
		_art.draw_polyline(points, Color(color, energy * 0.55), 3.0 + ribbon % 2, true)

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
		var smoke_color: Color = Color("716999") if foreground else Color("414d7b")
		smoke_color = smoke_color.lerp(Color("efb980"), clampf(1.0 - absf(point.x - 640.0) / 270.0, 0.0, 1.0) * _ignition() * 0.62)
		_art.draw_circle(point, radius, Color(smoke_color, opacity * 0.85))
		_art.draw_circle(point + Vector2(direction * radius * 0.34, -radius * 0.34), radius * 0.73, Color(smoke_color.lightened(0.10), opacity * 0.73))
		_art.draw_arc(point, radius * 0.83, PI * 1.08, PI * 1.71, 16, Color(smoke_color.lightened(0.20), opacity * 0.22), 2, true)

func _draw_motion_lines() -> void:
	var energy: float = smoothstep(3.2, 4.6, elapsed) * (1.0 - smoothstep(5.55, 6.25, elapsed))
	if energy <= 0.0:
		return
	for index in range(24):
		var x: float = 40 + fposmod(index * 191.7, 1200.0)
		if absf(x - _rocket_position().x) < 100:
			continue
		var y: float = fposmod(index * 173.4 + elapsed * (170.0 + index * 6), 820.0)
		_art.draw_line(Vector2(x, y), Vector2(x - 3, y + energy * (16 + index % 5 * 12)), Color(CELEBRATION_COLORS[index % 5], energy * 0.48), 1.5, true)

func _draw_titles() -> void:
	var fade: float = 1.0 - smoothstep(4.8, 5.6, elapsed)
	_art.draw_circle(Vector2(88, 88), 4, Color(_accent, fade))
	_text("TATERLAND  /  SPACE PROGRAM", Vector2(105, 93), 15, Color("b2cbd9") * Color(1, 1, 1, fade), false, true)
	_text("MISSION  0%d" % island, Vector2(1105, 94), 13, Color(0.65, 0.78, 0.84, fade), true)
	if elapsed < LIFTOFF_AT:
		_text("FULL OF SPUDS.", Vector2(88, 350), 31, Color("f5ecce"), false, true)
		_text("BOUND FOR THE MOON.", Vector2(88, 391), 31, _accent, false, true)
		_text("One crowded rocket. One wild market.", Vector2(89, 424), 16, Color("9ab4c6"))
		var remaining: int = maxi(1, 3 - int(elapsed / (IGNITION_AT / 3.0)))
		var countdown: float = fposmod(elapsed, IGNITION_AT / 3.0) / (IGNITION_AT / 3.0)
		var ring := Vector2(905, 437)
		_art.draw_arc(ring, 61, -PI * 0.5, PI * 1.5, 90, Color(0.65, 0.83, 0.85, 0.12), 2, true)
		_art.draw_arc(ring, 61, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - countdown), 90, _accent, 3, true)
		_text(str(remaining) if elapsed < IGNITION_AT else "GO", ring + Vector2(0, 20), 55 if elapsed < IGNITION_AT else 39, Color("f4efda"), true, true)
		_text("CREW: ALL ABOARD" if elapsed < IGNITION_AT else "IGNITION", ring + Vector2(0, 94), 13, _accent, true, true)
	else:
		var subtitle: float = smoothstep(LIFTOFF_AT, 2.9, elapsed) * fade
		_text("LIFTOFF", Vector2(88, 361), 45, Color(_accent, subtitle), false, true)
		_text("Tiny potatoes. Enormous ambitions.", Vector2(90, 393), 16, Color(0.68, 0.80, 0.86, subtitle))
	var bottom_alpha: float = 1.0 - smoothstep(5.2, 5.8, elapsed)
	_text("SPUD EXPRESS  /  FULL HOUSE", Vector2(89, 722), 13, Color(0.62, 0.77, 0.83, bottom_alpha), false, true)
	_text("T + %04.1f s" % maxf(0.0, elapsed - LIFTOFF_AT) if elapsed >= LIFTOFF_AT else "LAUNCH SEQUENCE", Vector2(1110, 722), 13, Color(_accent, bottom_alpha), true)
	_art.draw_line(Vector2(370, 717), Vector2(999, 717), Color(0.48, 0.71, 0.80, bottom_alpha * 0.18), 2, true)
	_art.draw_line(Vector2(370, 717), Vector2(370 + 629 * minf(1.0, elapsed / 5.8), 717), Color(_accent, bottom_alpha * 0.72), 2, true)

func _draw_finale() -> void:
	var progress: float = smoothstep(5.75, 6.3, elapsed)
	if progress <= 0.0:
		return
	var star := Vector2(860, 136)
	var burst: float = maxf(0.0, 1.0 - absf(elapsed - 6.06) / 0.38)
	for ray: int in range(10):
		var direction: Vector2 = Vector2.from_angle(float(ray) * TAU / 10.0)
		_art.draw_line(star + direction * 6, star + direction * (12 + burst * 66), Color(CELEBRATION_COLORS[ray % 5], burst * 0.85), 3, true)
	_art.draw_circle(star, 3 + burst * 7, Color(1.0, 0.96, 0.75, 1.0 - smoothstep(6.3, 6.8, elapsed)))
	var y: float = 334 + (1.0 - progress) * 18
	# A quiet central field keeps the payoff readable inside the money orbit.
	for ring: int in range(3):
		_ellipse(Vector2(640, y + 56), Vector2(360 + ring * 18, 166 + ring * 14), Color(0.027, 0.043, 0.12, progress * (0.22 - ring * 0.05)))
	_text("FULL CREW. FULL SEND.", Vector2(640, y - 66), 18, Color("ff94dc") * Color(1, 1, 1, progress), true, true)
	_text("TO THE MOON", Vector2(640, y + 11), 69, Color("ffe34a") * Color(1, 1, 1, progress), true, true)
	_text("10-SECOND STOCK BOOM INCOMING", Vector2(640, y + 67), 20, Color("86dfff") * Color(1, 1, 1, progress), true, true)
	_text("Get ready to sell.", Vector2(640, y + 101), 17, Color(0.94, 0.95, 1.0, progress), true)
	for crew: int in range(3):
		_draw_potato(Vector2(582 + crew * 58, y + 163), 25 if crew == 1 else 21, crew + 2, progress)
	for index: int in range(26):
		var angle: float = index * TAU / 26.0 + (elapsed - 5.75) * 0.13
		var point := Vector2(640, y + 32) + Vector2(cos(angle) * (440 + index % 2 * 27), sin(angle) * (222 + index % 3 * 17))
		_draw_money_symbol(point, 12 + index % 4 * 3, index, progress * 0.94)
		var star_point: Vector2 = point + Vector2(17, -25)
		var color: Color = Color(CELEBRATION_COLORS[(index + 2) % 5], progress * 0.65)
		_art.draw_line(star_point - Vector2(4, 0), star_point + Vector2(4, 0), color, 2, true)
		_art.draw_line(star_point - Vector2(0, 4), star_point + Vector2(0, 4), color, 2, true)

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
	points.resize(_ellipse_unit.size())
	for index: int in range(_ellipse_unit.size()):
		points[index] = center + _ellipse_unit[index] * radii
	_art.draw_colored_polygon(points, color)
