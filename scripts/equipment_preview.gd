extends Control
## A live portrait of the same avatar used on the farm; drag to turn it.
const Avatar = preload("res://scripts/farmer_avatar.gd")
const DRAG_SENSITIVITY: float = 0.012
const FOLLOW_RESPONSE: float = 24.0
const INERTIA_DECAY: float = 6.0
const MAX_TURN_SPEED: float = 5.0
const MAX_RENDER_EDGE: int = 896
const MAX_RENDER_PIXELS: int = 600000
var viewport: SubViewport
var avatar: Node3D
var loadout: Dictionary = {}
var _catalog: Dictionary = {}
var _dragging: bool = false
var _angle: float = -0.18
var _display_angle: float = -0.18
var _display_velocity: float = 0.0
var _angular_velocity: float = 0.0
var _idle_blend: float = 1.0
var _since_motion: float = 1.0
var _last_input_usec: int = 0
var _resolution_clock: float = 0.0
var _clock: float = 0.0
var _signature: String = ""
var _background: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(220, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag to turn your farmer. Equipped clothes appear here and on the farm."
	_background = StyleBoxFlat.new()
	_background.bg_color = Color("253b42")
	_background.set_corner_radius_all(13)
	viewport = SubViewport.new()
	viewport.name = "EquipmentPortraitViewport"
	viewport.size = Vector2i(300, 390)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	# A TextureRect lets the portrait render above its logical UI resolution.
	# SubViewportContainer.stretch would overwrite the HiDPI viewport size.
	var image: TextureRect = TextureRect.new()
	image.name = "EquipmentPortraitImage"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.texture = viewport.get_texture()
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("253b42")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e2f0e8")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-32, -40, 0)
	sunlight.light_color = Color("fff0d2")
	sunlight.light_energy = 0.95
	viewport.add_child(sunlight)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 145, 0)
	fill.light_color = Color("a5d6e6")
	fill.light_energy = 0.38
	viewport.add_child(fill)
	var pedestal: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.88
	cylinder.bottom_radius = 0.91
	cylinder.height = 0.09
	cylinder.radial_segments = 32
	pedestal.mesh = cylinder
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("52706a")
	material.roughness = 0.95
	pedestal.material_override = material
	pedestal.position.y = -0.06
	viewport.add_child(pedestal)
	avatar = Avatar.new()
	viewport.add_child(avatar)
	avatar.setup()
	avatar.set_equipment(loadout, _catalog)
	avatar.rotation.y = _display_angle
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	viewport.add_child(camera)
	camera.position = Vector3(2.4, 1.55, 4.4)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	resized.connect(queue_redraw)
	resized.connect(_sync_resolution)
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _draw() -> void:
	if _background != null:
		draw_style_box(_background, Rect2(Vector2.ZERO, size))

func _sync_visibility() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if showing:
		_sync_resolution()
	else:
		_cancel_drag()

static func render_size(logical_size: Vector2, pixel_density: float) -> Vector2i:
	var scale_factor: float = clampf(pixel_density * 1.15, 1.5, 2.0)
	var desired: Vector2 = logical_size.max(Vector2(32, 32)) * scale_factor
	var edge_scale: float = minf(1.0, float(MAX_RENDER_EDGE) / maxf(desired.x, desired.y))
	desired *= edge_scale
	var pixel_scale: float = minf(1.0, sqrt(float(MAX_RENDER_PIXELS) / (desired.x * desired.y)))
	desired *= pixel_scale
	return Vector2i(maxi(1, int(floorf(desired.x))), maxi(1, int(floorf(desired.y))))

func _sync_resolution() -> void:
	if not is_instance_valid(viewport) or not is_visible_in_tree():
		return
	var screen_scale: Vector2 = get_screen_transform().get_scale().abs()
	var density: float = maxf(screen_scale.x, screen_scale.y)
	if DisplayServer.get_name() != "headless":
		density = maxf(density, DisplayServer.screen_get_scale())
	var desired: Vector2i = render_size(size.max(custom_minimum_size), density)
	if viewport.size != desired:
		viewport.size = desired

func set_equipment(next_loadout: Dictionary, catalog: Dictionary) -> void:
	var signature: String = JSON.stringify(next_loadout)
	if signature == _signature and not _catalog.is_empty():
		return
	_signature = signature
	loadout = next_loadout.duplicate(true)
	_catalog = catalog
	if is_instance_valid(avatar):
		avatar.set_equipment(loadout, _catalog)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar) or not is_finite(delta) or delta <= 0.0:
		return
	# Bound a resumed browser's first frame: a background pause cannot fling
	# the farmer forward by several seconds in one rendered frame.
	var frame_time: float = minf(delta, 0.25)
	_advance_turn(frame_time)
	avatar.rotation.y = _display_angle
	avatar.animate(frame_time, false)
	_resolution_clock += frame_time
	if _resolution_clock >= 0.5:
		_resolution_clock = 0.0
		_sync_resolution()

func _advance_turn(delta: float) -> void:
	# Small equal-time integration steps make30/60/120Hz displays follow the
	# same damped motion. The critically damped spring never snaps to input.
	var remaining: float = delta
	while remaining > 0.000001:
		var step: float = minf(remaining, 1.0 / 120.0)
		remaining -= step
		_clock += step
		_since_motion += step
		if not _dragging:
			var decay: float = exp(-INERTIA_DECAY * step)
			_angle += _angular_velocity * (1.0 - decay) / INERTIA_DECAY
			_angular_velocity *= decay
		_idle_blend = lerpf(_idle_blend, 0.0 if _dragging else 1.0, 1.0 - exp(-step * 3.5))
		var target: float = _angle + sin(_clock * 0.6) * 0.065 * _idle_blend
		var offset: float = _display_angle - target
		var spring: float = (_display_velocity + FOLLOW_RESPONSE * offset) * step
		var damping: float = exp(-FOLLOW_RESPONSE * step)
		_display_angle = target + (offset + spring) * damping
		_display_velocity = (_display_velocity - FOLLOW_RESPONSE * spring) * damping

func _begin_drag() -> void:
	_dragging = true
	_angle = _display_angle
	_angular_velocity = 0.0
	_idle_blend = 0.0
	_since_motion = 0.0
	_last_input_usec = Time.get_ticks_usec()

func _drag_by(pixels: float, elapsed: float) -> void:
	if not _dragging or not is_finite(pixels) or not is_finite(elapsed):
		return
	var turn: float = pixels * DRAG_SENSITIVITY
	_angle += turn
	var sample_time: float = clampf(elapsed, 1.0 / 240.0, 0.10)
	var speed: float = clampf(turn / sample_time, -MAX_TURN_SPEED, MAX_TURN_SPEED)
	_angular_velocity = lerpf(_angular_velocity, speed, 1.0 - exp(-sample_time * 14.0))
	_since_motion = 0.0

func _release_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if _since_motion > 0.12:
		_angular_velocity = 0.0
	_last_input_usec = 0

func _cancel_drag() -> void:
	_dragging = false
	_angular_velocity = 0.0
	_display_velocity = 0.0
	_angle = _display_angle
	_idle_blend = 0.0
	_since_motion = 1.0
	_last_input_usec = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_drag()

func _input(event: InputEvent) -> void:
	# The mouse can be released outside the portrait after a drag.
	if _dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_drag()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag()
		else:
			_release_drag()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var now: int = Time.get_ticks_usec()
		_drag_by(event.relative.x, float(now - _last_input_usec) / 1000000.0)
		_last_input_usec = now
		accept_event()
