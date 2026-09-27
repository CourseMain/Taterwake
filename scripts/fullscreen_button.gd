extends Button
## Small, background-free chrome with a full-size invisible hit target.
var _active: bool = false

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)
	_sync_mode()

func _process(_delta: float) -> void:
	_sync_mode()

func _sync_mode() -> void:
	var mode: int = get_window().mode
	var active: bool = mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	var label: String = "Exit fullscreen (F11)" if active else "Enter fullscreen (F11)"
	if active != _active or tooltip_text != label:
		_active = active
		tooltip_text = label
		queue_redraw()

func _draw() -> void:
	var scale: float = minf(size.x, size.y) / 44.0
	var center: Vector2 = size * .5
	var color := Color("ffe09b") if is_pressed() else Color("ffffff" if is_hovered() else "fff3cf")
	var paths: Array[PackedVector2Array] = []
	if _active:
		paths.append(PackedVector2Array([Vector2(-7, -7), Vector2(7, 7)]))
		paths.append(PackedVector2Array([Vector2(-7, 7), Vector2(7, -7)]))
	else:
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			paths.append(PackedVector2Array([corner * 4, corner * 10]))
			paths.append(PackedVector2Array([Vector2(corner.x * 4, corner.y * 10), corner * 10, Vector2(corner.x * 10, corner.y * 4)]))
	for path in paths:
		var points := PackedVector2Array()
		var shadow := PackedVector2Array()
		for point in path:
			points.append(center + point * scale)
			shadow.append(center + point * scale + Vector2(0, scale))
		draw_polyline(shadow, Color(0.04, .1, .1, .65), 3.5 * scale, true)
		draw_polyline(points, color, 2.0 * scale, true)
