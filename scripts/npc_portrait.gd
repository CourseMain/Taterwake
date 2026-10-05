extends Control
const MAX_RENDER_EDGE: int = 896
const MAX_RENDER_PIXELS: int = 600000
var viewport: SubViewport
var avatar: Node3D
var _background: StyleBoxTexture
var _resolution_clock: float = 0.0
const NpcAvatar = preload("res://scripts/npc_avatar.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
var camera: Camera3D
var _entrance: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = Cozy.paper(Cozy.INK, 0, 8, Cozy.WOOD)
	viewport = SubViewport.new()
	viewport.name = "VillagePortraitViewport"
	viewport.size = Vector2i(300, 390)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	# A TextureRect lets the portrait render above its logical UI resolution.
	# SubViewportContainer.stretch would overwrite the HiDPI viewport size.
	var image: TextureRect = TextureRect.new()
	image.name = "VillagePortraitImage"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.texture = viewport.get_texture()
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 6; image.offset_top = 6; image.offset_right = -6; image.offset_bottom = -6
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	camera.size = 2.35
	camera.position = Vector3(.15,1.45,4.4)
	camera.look_at(Vector3(0,1.18,0))
	resized.connect(queue_redraw)
	resized.connect(_sync_resolution)
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _draw() -> void:
	if _background != null:
		draw_style_box(_background, Rect2(Vector2.ZERO, size))
		var line := Cozy.box(Color.TRANSPARENT, 0, 12, Cozy.CREAM)
		line.set_border_width_all(2)
		draw_style_box(line, Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4))

func _sync_visibility() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if showing:
		_sync_resolution()

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

func show_person(id: String) -> void:
	if is_instance_valid(avatar):
		viewport.remove_child(avatar)
		avatar.queue_free()
	avatar = NpcAvatar.new()
	viewport.add_child(avatar)
	avatar.configure(id)
	_background = Cozy.paper(Color(NpcAvatar.Roster.PEOPLE[id].color).darkened(.55), 0, 8, Cozy.WOOD)
	_entrance = 0.0
	queue_redraw()
	_sync_resolution()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar): return
	var dt: float = clampf(delta,0,.1)
	_entrance = minf(1.0,_entrance+dt*1.8)
	avatar.rotation.y = -.12 + (1.0-_entrance)*.18
	avatar.animate(dt)
	var aspect: float = size.x / maxf(1,size.y)
	var span: float = clampf(1.55 / maxf(.5,aspect),1.5,2.22)
	camera.size = lerpf(span+.25,span,smoothstep(0,1,_entrance))
	camera.look_at(Vector3(0,lerpf(1.48,1.18,(span-1.5)/.72),0))
	_resolution_clock += dt
	if _resolution_clock >= .5:
		_resolution_clock = 0
		_sync_resolution()

func _gui_input(_event: InputEvent) -> void: pass
