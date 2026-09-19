extends Control
## Four stock celebrations, composed around the frame so the farm stays playable.
## All symbols are drawn geometry: dollar coins and musical notes need no fonts.
const PALETTES: Array[Color] = [Color("19f889"), Color("ffd537"), Color("35aaff")]
const TIER_POWER: Array[float] = [0.0, 0.40, 0.66, 0.88, 1.0]

var active: bool = false
var island: int = 1
var tier: int = 0
var strength: float = 0.0
var remaining: float = 0.0
var _elapsed: float = 0.0
var _tier_elapsed: float = 0.0
var _continuous: bool = false
var _strong: bool = false
var _color: Color = PALETTES[0]
var _quote_percent: float = 0.0
var _reward_remaining: float = 0.0
var _anticipation: float = 0.0
var _surge_tier: int = 0
var _mist: ColorRect
var _mist_material: ShaderMaterial

static func tier_for_percent(percent: float) -> int:
	if percent >= 15000.0:
		return 4
	if percent >= 3000.0:
		return 3
	if percent >= 500.0:
		return 2
	return 1 if percent > 300.0 else 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist = ColorRect.new()
	_mist.name = "StockEdgeMist"
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://scripts/market_aura.gdshader")
	_mist.material = _mist_material
	# Draw the translucent mist behind the crisp sparks and symbols.
	_mist.show_behind_parent = true
	add_child(_mist)
	_deactivate()

func surge(island_id: int, intensity: float, seconds: float) -> void:
	_prepare_island(island_id)
	_surge_tier = 2 if intensity >= 0.8 else 1
	remaining = maxf(0.0, seconds)
	_tier_elapsed = 0.0
	_refresh_activity()

func reward(island_id: int, seconds: float = 6.0) -> void:
	_prepare_island(island_id)
	_reward_remaining = maxf(_reward_remaining, maxf(0.0, seconds))
	# Reward mist is its own short, modest layer; it never promotes a stock tier.
	_refresh_activity()

func set_countdown(island_id: int, seconds: float) -> void:
	_prepare_island(island_id)
	_anticipation = clampf((11.0 - seconds) / 10.0, 0.0, 1.0) if seconds <= 10.0 else 0.0
	_refresh_activity()

func set_quote(island_id: int, percent: float) -> void:
	_prepare_island(island_id)
	var next_tier: int = tier_for_percent(percent)
	if tier != next_tier:
		_tier_elapsed = 0.0
		# A new stock level owns its effects. No old surge can keep a bigger tier alive.
		remaining = 0.0
		_surge_tier = 0
	tier = next_tier
	_quote_percent = percent
	_continuous = tier > 0
	if not _continuous:
		remaining = 0.0
		_surge_tier = 0
	_refresh_activity()

func _prepare_island(island_id: int) -> void:
	var next_island: int = clampi(island_id, 1, 3)
	if island == next_island:
		return
	island = next_island
	tier = 0
	_quote_percent = 0.0
	_continuous = false
	_strong = false
	remaining = 0.0
	_reward_remaining = 0.0
	_anticipation = 0.0
	_surge_tier = 0
	_elapsed = 0.0
	_tier_elapsed = 0.0
	_color = PALETTES[island - 1]
	_deactivate()

func _visual_tier() -> int:
	return maxi(tier, _surge_tier if remaining > 0.0 else 0)

func _refresh_activity() -> void:
	var level: int = _visual_tier()
	strength = TIER_POWER[level]
	_strong = level >= 2
	if level > 0 or _reward_remaining > 0.0 or _anticipation > 0.0:
		_activate()
	else:
		_deactivate()
	_update_mist()

func _activate() -> void:
	_color = PALETTES[island - 1]
	if not active:
		_elapsed = 0.0
	active = true
	show()
	set_process(true)
	queue_redraw()

func _deactivate() -> void:
	active = false
	strength = 0.0
	_strong = false
	hide()
	set_process(false)
	if is_instance_valid(_mist_material):
		_mist_material.set_shader_parameter("energy", 0.0)
		_mist_material.set_shader_parameter("tier", 0.0)
		_mist_material.set_shader_parameter("arrival", 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_tier_elapsed += delta
	_reward_remaining = maxf(0.0, _reward_remaining - delta)
	remaining = maxf(0.0, remaining - delta)
	_refresh_activity()
	queue_redraw()

func _beat() -> float:
	var bpm: float = 138.0 if _visual_tier() == 4 else 108.0
	return pow(maxf(0.0, cos(_elapsed * TAU * bpm / 60.0)), 4.0)

func _energy() -> float:
	if not active:
		return 0.0
	var stock: float = strength
	if not _continuous:
		stock *= minf(1.0, remaining / 0.8)
	var reward_energy: float = 0.46 * minf(1.0, _reward_remaining / 1.2)
	var power: float = maxf(maxf(stock, reward_energy), _anticipation * 0.26)
	var pulse: float = 0.88 + 0.12 * sin(_elapsed * 3.6)
	if _visual_tier() >= 2:
		pulse = 0.83 + 0.17 * _beat()
	return smoothstep(0.0, 0.32, _elapsed) * power * pulse

func _arrival() -> float:
	return (1.0 - smoothstep(0.0, 0.9, _tier_elapsed)) if _visual_tier() >= 3 else 0.0

func _update_mist() -> void:
	if not is_instance_valid(_mist_material):
		return
	_mist_material.set_shader_parameter("aura_color", _color)
	_mist_material.set_shader_parameter("clock_time", _elapsed)
	_mist_material.set_shader_parameter("energy", _energy())
	_mist_material.set_shader_parameter("tier", float(_visual_tier()))
	_mist_material.set_shader_parameter("beat", _beat())
	_mist_material.set_shader_parameter("arrival", _arrival())

func _draw() -> void:
	if not active or size.x < 1.0 or size.y < 1.0:
		return
	var level: int = _visual_tier()
	var alpha: float = _energy()
	var scale_factor: float = clampf(minf(size.x / 1280.0, size.y / 800.0), 0.65, 1.4)
	_draw_ribbons(level, alpha, scale_factor)
	_draw_sparks(level, alpha, scale_factor)
	if level >= 2:
		_draw_rays(level, alpha, scale_factor)
		_draw_equalizer(level, alpha, scale_factor)
	if level >= 3:
		_draw_floating_symbols(level, alpha, scale_factor)
		_draw_arrival(level, alpha, scale_factor)

func _draw_ribbons(level: int, alpha: float, unit: float) -> void:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	var ribbon_count: int = 1 if level <= 1 else (2 if level == 2 else 3)
	for side: int in range(4):
		var anchor: Vector2 = corners[side]
		var direction := Vector2(1.0 if side % 2 == 0 else -1.0, 1.0 if side < 2 else -1.0)
		for ribbon: int in range(ribbon_count):
			var points := PackedVector2Array()
			var reach: float = (155.0 + level * 37.0 + ribbon * 25.0) * unit
			for step: int in range(28):
				var progress: float = float(step) / 27.0
				var wave: float = sin(progress * 8.0 - _elapsed * (1.6 + level * 0.28) + ribbon * 1.7 + side)
				var inset: float = (11.0 + ribbon * 11.0 + wave * (4.0 + level * 2.0) * sin(progress * PI)) * unit
				points.append(anchor + direction * Vector2(progress * reach, inset))
			draw_polyline(points, Color(_color, alpha * 0.09), (8.0 + level * 2.0) * unit, true)
			draw_polyline(points, Color(_color.lightened(0.50), alpha * 0.63), 1.7 * unit, true)
		if level >= 2:
			for ring: int in range(level - 1):
				var progress: float = fposmod(_elapsed * (0.37 + level * 0.025) + ring * 0.34, 1.0)
				var radius: float = (45.0 + progress * (125.0 + level * 12.0)) * unit
				draw_arc(anchor, radius, 0.0, TAU, 32, Color(_color, alpha * (1.0 - progress) * 0.38), 1.6 * unit, true)

func _draw_sparks(level: int, alpha: float, unit: float) -> void:
	var count: int = 8 + level * 6
	var lane: float = (24.0 + level * 12.0) * unit
	for side: int in range(2):
		for index: int in range(count):
			var phase: float = fposmod(float(index) * 0.618034 + _elapsed * (0.070 + float(index % 4) * 0.013 + level * 0.007), 1.0)
			var inset: float = (9.0 + fposmod(index * 19.7, lane)) * unit + sin(_elapsed * 1.6 + index * 2.0) * 7.0 * unit
			var point := Vector2(inset if side == 0 else size.x - inset, size.y * (1.0 - phase))
			var fade: float = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.84, 1.0, phase))
			var radius: float = (1.1 + index % 3 * 0.65) * unit
			var spark := Color(_color.lightened(0.55), alpha * fade * 0.9)
			draw_circle(point, radius * 3.2, Color(_color, alpha * fade * 0.065))
			draw_circle(point, radius, spark)
			if level >= 2 and index % 3 == 0:
				draw_line(point + Vector2(0, radius * 2), point + Vector2(0, 10.0 + level * 3.0) * unit, Color(_color, alpha * fade * 0.4), 1.4 * unit, true)
			if level >= 3 and index % 4 == 0:
				_draw_star(point, (5.0 + _beat() * 2.0) * unit, spark)

func _draw_rays(level: int, alpha: float, unit: float) -> void:
	var count: int = 7 if level == 2 else (12 if level == 3 else 18)
	for side: int in range(2):
		for index: int in range(count):
			var phase: float = fposmod(_elapsed * 0.32 + index * 0.618, 1.0)
			var y: float = size.y * fposmod(index * 0.3819 + float(side) * 0.16, 1.0)
			var origin := Vector2(0.0 if side == 0 else size.x, y)
			var direction := Vector2(1.0 if side == 0 else -1.0, (size.y * 0.5 - y) / size.y * 0.7)
			var reach: float = (28.0 + phase * (27.0 + level * 13.0) + _beat() * 11.0) * unit
			var tip: Vector2 = origin + direction * reach
			var opacity: float = alpha * sin(phase * PI) * (0.20 if level == 2 else 0.32)
			var points := PackedVector2Array([origin + Vector2(0, -4.0 * unit), tip, origin + Vector2(0, 4.0 * unit)])
			draw_colored_polygon(points, Color(_color, opacity * 0.32))
			draw_line(origin, tip, Color(_color.lightened(0.55), opacity), 1.2 * unit, true)

func _draw_equalizer(level: int, alpha: float, unit: float) -> void:
	# Low profile rhythm bars live in the lower corners, outside the tool strip.
	var count: int = 12 if level == 2 else 20
	for side: int in range(2):
		for index: int in range(count):
			var rhythm: float = pow(0.5 + 0.5 * sin(_elapsed * 9.0 + index * 0.65), 2.0)
			var height: float = (3.0 + rhythm * (7.0 + level * 5.0) + _beat() * 5.0) * unit
			var x: float = (14.0 + index * 7.0) * unit
			if side == 1:
				x = size.x - x
			draw_line(Vector2(x, size.y - 7 * unit), Vector2(x, size.y - 7 * unit - height), Color(_color.lightened(0.3), alpha * 0.48), 2.2 * unit, true)

func _draw_floating_symbols(level: int, alpha: float, unit: float) -> void:
	var count: int = 7 if level == 3 else 11
	var speed: float = 0.108 if level == 3 else 0.142
	for side: int in range(2):
		for index: int in range(count):
			var phase: float = fposmod(float(index) / count + _elapsed * speed + side * 0.17, 1.0)
			var fade: float = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.78, 1.0, phase))
			var inset: float = (39.0 + index % 3 * 34.0 + sin(_elapsed * 1.2 + index * 2.3) * 14.0) * unit
			var point := Vector2(inset if side == 0 else size.x - inset, size.y * (1.06 - phase * 1.18))
			var radius: float = (11.0 + index % 3 * 3.5 + (2.0 if level == 4 else 0.0)) * unit
			var rotation: float = sin(_elapsed * 1.8 + index * 1.9) * 0.22
			var ink := Color(_color.lightened(0.68), alpha * fade * 0.88)
			draw_set_transform(point, rotation, Vector2.ONE)
			if index % 3 == 1:
				_draw_note(radius, ink, index % 2 == 0)
			else:
				_draw_coin(radius, ink, alpha * fade)
			draw_set_transform(Vector2.ZERO)

func _draw_coin(radius: float, ink: Color, alpha: float) -> void:
	draw_circle(Vector2.ZERO, radius * 1.55, Color(_color, alpha * 0.06))
	draw_circle(Vector2.ZERO, radius, Color(_color.darkened(0.5), alpha * 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ink, 1.65, true)
	draw_arc(Vector2.ZERO, radius * 0.78, -1.2, 1.05, 13, Color(ink, ink.a * 0.42), 1.0, true)
	# A hand-drawn dollar S with two cubic curves and its vertical stroke.
	var dollar := PackedVector2Array()
	var first: Array[Vector2] = [Vector2(0.35, -0.37), Vector2(-0.65, -0.84), Vector2(-0.67, 0.02), Vector2(0, 0)]
	var second: Array[Vector2] = [Vector2.ZERO, Vector2(0.68, 0.02), Vector2(0.65, 0.79), Vector2(-0.38, 0.39)]
	for curve: Array[Vector2] in [first, second]:
		for step: int in range(13):
			var t: float = float(step) / 12.0
			var point: Vector2 = pow(1.0 - t, 3.0) * curve[0] + 3.0 * pow(1.0 - t, 2.0) * t * curve[1] + 3.0 * (1.0 - t) * t * t * curve[2] + t * t * t * curve[3]
			dollar.append(point * radius)
	draw_polyline(dollar, ink, 1.8, true)
	draw_line(Vector2(0, -radius * 0.67), Vector2(0, radius * 0.67), ink, 1.4, true)

func _draw_note(radius: float, ink: Color, paired: bool) -> void:
	var note_head := PackedVector2Array()
	for index: int in range(16):
		var angle: float = float(index) * TAU / 16.0
		note_head.append(Vector2(cos(angle) * radius * 0.38, sin(angle) * radius * 0.25).rotated(-0.3) + Vector2(-radius * 0.2, radius * 0.5))
	draw_colored_polygon(note_head, ink)
	draw_line(Vector2(radius * 0.13, radius * 0.46), Vector2(radius * 0.13, -radius * 0.88), ink, 2.0, true)
	if paired:
		var offset := Vector2(radius * 0.79, -radius * 0.13)
		var other_head := PackedVector2Array()
		for point: Vector2 in note_head:
			other_head.append(point + offset)
		draw_colored_polygon(other_head, ink)
		draw_line(Vector2(radius * 0.13, radius * 0.46) + offset, Vector2(radius * 0.13, -radius * 0.88) + offset, ink, 2.0, true)
		draw_line(Vector2(radius * 0.13, -radius * 0.79), Vector2(radius * 0.13, -radius * 0.79) + offset, ink, 4.0, true)
	else:
		var flag := PackedVector2Array([Vector2(0.13, -0.88), Vector2(0.42, -0.66), Vector2(0.64, -0.38), Vector2(0.55, -0.12)])
		for index: int in range(flag.size()):
			flag[index] *= radius
		draw_polyline(flag, ink, 2.4, true)

func _draw_star(point: Vector2, radius: float, ink: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(8):
		points.append(point + Vector2.from_angle(float(index) * TAU / 8.0) * (radius if index % 2 == 0 else radius * 0.23))
	draw_colored_polygon(points, ink)

func _draw_arrival(level: int, alpha: float, unit: float) -> void:
	var arrival: float = _arrival()
	if arrival <= 0.0:
		return
	# An expanding border catches the tier change without covering central crops.
	var inset: float = (1.0 - arrival) * 26.0 * unit
	var frame := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	draw_rect(frame, Color(_color.lightened(0.72), arrival * alpha * (0.52 if level == 4 else 0.32)), false, (2.0 + arrival * 3.0) * unit)
