extends Control
## Bright animated edge mist, with a clear farm in the middle. Never catches input.
var active: bool = false
var island: int = 1
var strength: float = 0.0
var remaining: float = 0.0
var _elapsed: float = 0.0
var _continuous: bool = false
var _strong: bool = false
var _color: Color = Color("35ff85")
var _quote_percent: float = 0.0
var _reward_remaining: float = 0.0
var _anticipation: float = 0.0
var _mist: ColorRect
var _mist_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist = ColorRect.new()
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://scripts/market_aura.gdshader")
	_mist.material = _mist_material
	add_child(_mist)
	hide()
	set_process(false)

func surge(island_id: int, intensity: float, seconds: float) -> void:
	island = island_id
	_quote_percent = 0.0
	_continuous = false
	_strong = intensity >= 0.8
	strength = clampf(intensity, 0.55, 1.0)
	remaining = maxf(4.0, seconds)
	_activate()

func reward(island_id: int, seconds: float = 6.0) -> void:
	island = island_id
	_reward_remaining = maxf(_reward_remaining, seconds)
	strength = maxf(strength, 0.76)
	_activate()

func set_countdown(island_id: int, seconds: float) -> void:
	_anticipation = clampf((11.0 - seconds) / 10.0, 0.0, 1.0) if seconds <= 10.0 else 0.0
	if _anticipation > 0.0:
		island = island_id
		_activate()
	elif not _continuous and remaining <= 0.0 and _reward_remaining <= 0.0 and _anticipation <= 0.0:
		_deactivate()

func set_quote(island_id: int, percent: float) -> void:
	var was_high: bool = _quote_percent > 300.0
	island = island_id
	_quote_percent = percent
	_continuous = percent > 300.0
	if _continuous:
		_strong = percent > 1000.0
		strength = clampf(0.67 + (percent - 300.0) / 1700.0 * 0.33, 0.67, 1.0)
		remaining = 1.6
		_activate()
	elif was_high:
		remaining = maxf(remaining, 1.6)
	elif remaining <= 0.0 and _reward_remaining <= 0.0 and _anticipation <= 0.0:
		_deactivate()

func _activate() -> void:
	_color = Color("08ff72") if island == 1 else (Color("ffcd08") if island == 2 else Color("159eff"))
	if not active:
		_elapsed = 0.0
	active = true
	show()
	set_process(true)
	queue_redraw()

func _deactivate() -> void:
	active = false
	strength = 0.0
	hide()
	set_process(false)

func _process(delta: float) -> void:
	_elapsed += delta
	_reward_remaining = maxf(0.0, _reward_remaining - delta)
	if not _continuous:
		remaining = maxf(0.0, remaining - delta)
	if not _continuous and remaining <= 0.0 and _reward_remaining <= 0.0 and _anticipation <= 0.0:
		_deactivate()
	var intensity: float = _energy()
	_mist_material.set_shader_parameter("aura_color", _color)
	_mist_material.set_shader_parameter("clock_time", _elapsed)
	_mist_material.set_shader_parameter("energy", intensity * 1.65)
	_mist_material.set_shader_parameter("jackpot", 1.0 if _strong and _continuous else 0.0)
	queue_redraw()

func _energy() -> float:
	var fade: float = 1.0 if _continuous else minf(1.0, maxf(remaining, _reward_remaining) / 1.3)
	var power: float = maxf(strength * fade, _anticipation * 0.40)
	var pulse: float = 0.87 + 0.13 * sin(_elapsed * TAU * 0.9)
	if _strong and (_continuous or remaining > 0.0):
		pulse = 0.68 + 0.32 * pow(maxf(0.0, cos(_elapsed * TAU * 1.8)), 3.0)
	return minf(1.0, _elapsed / 0.14) * power * pulse

func _draw() -> void:
	if not active:
		return
	var alpha: float = _energy()
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	# Saturated rings and ribbons stay at the perimeter of the playable world.
	for side: int in range(4):
		var anchor: Vector2 = corners[side]
		var direction: Vector2 = Vector2(1 if side % 2 == 0 else -1, 1 if side < 2 else -1)
		for ribbon: int in range(3):
			var points := PackedVector2Array()
			for step: int in range(30):
				var t: float = float(step) / 29.0
				var swirl: float = 18 + sin(t * 12.0 - _elapsed * 3.0 + ribbon * 1.8) * (8 + t * 13)
				points.append(anchor + direction * Vector2(t * (260 + ribbon * 35), swirl + ribbon * 9))
			draw_polyline(points, Color(_color, alpha * 0.16), 14.0, true)
			draw_polyline(points, Color(_color.lightened(0.22), alpha * 0.6), 2.0, true)
		for ring: int in range(3):
			var radius: float = 48 + fmod(_elapsed * (50 if _strong else 27) + ring * 80, 245)
			draw_arc(anchor, radius, 0, TAU, 48, Color(_color, alpha * (1.0 - radius / 310.0) * 0.35), 2.5, true)
		for index: int in range(24):
			var travel: float = fmod(index * 41.0 + _elapsed * (45.0 + index * 2.0), size.y * 0.49)
			var point: Vector2 = anchor + direction * Vector2(12 + (index % 6) * 15 + sin(_elapsed * 1.9 + index) * 10, travel)
			var radius: float = 1.5 + index % 3
			var color: Color = Color(_color.lightened(0.3), alpha * 0.85)
			draw_circle(point, radius * 3, Color(_color, alpha * 0.06))
			draw_circle(point, radius, color)
			if island == 3:
				for angle: float in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
					var ray: Vector2 = Vector2.from_angle(angle) * radius * 2.0
					draw_line(point - ray, point + ray, color, 1.0, true)
			elif _strong:
				draw_line(point, point - direction * Vector2(5, 22), Color(color, alpha * 0.6), 2, true)
		if _strong and _continuous:
			# Sharp, animated energy bolts frame the jackpot without a central flash.
			var bolt := PackedVector2Array()
			for index: int in range(12):
				var wobble: float = sin(index * 8.1 + floor(_elapsed * 12) * 2.3)
				bolt.append(anchor + direction * Vector2(8 + absf(wobble) * 43, index * 25))
			draw_polyline(bolt, Color(_color, alpha * 0.20), 12.0, true)
			draw_polyline(bolt, Color(_color.lightened(0.55), alpha * 0.9), 2.0, true)
