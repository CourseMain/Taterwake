extends SubViewport
## The farm has its own pixel budget. Menus, text and celebrations stay at the
## window's full resolution, even when the player chooses lighter 3D rendering.
const BUDGETS: Dictionary = {
	"smooth": Vector2i(1600, 1000),
	"balanced": Vector2i(1920, 1200),
	"crisp": Vector2i(2560, 1600),
}
var quality: String = "balanced"
var picture: TextureRect

func _ready() -> void:
	own_world_3d = true
	gui_disable_input = true
	handle_input_locally = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "FarmPictureLayer"
	layer.layer = -10
	get_parent().add_child.call_deferred(layer)
	picture = TextureRect.new()
	picture.name = "FarmPicture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.texture = get_texture()
	layer.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.size_changed.connect(sync_resolution)
	sync_resolution.call_deferred()

static func render_size(display_size: Vector2i, mode: String) -> Vector2i:
	var budget: Vector2i = BUDGETS.get(mode, BUDGETS.balanced)
	var source := Vector2(display_size).max(Vector2.ONE)
	var scale: float = minf(1.0, minf(budget.x / source.x, budget.y / source.y))
	return Vector2i(maxi(1, int(source.x * scale)), maxi(1, int(source.y * scale)))

func set_quality(mode: String) -> void:
	quality = mode if BUDGETS.has(mode) else "balanced"
	msaa_3d = Viewport.MSAA_4X if quality == "crisp" else Viewport.MSAA_2X
	sync_resolution()

func sync_resolution() -> void:
	if not is_inside_tree(): return
	# Exclude letterbox borders: the root backing canvas can be wider/taller
	# than its logical game rectangle. Rendering that aspect would squash 3D.
	var window: Window = get_tree().root
	var logical: Vector2 = window.get_visible_rect().size.max(Vector2.ONE)
	var fit: float = minf(window.size.x / logical.x, window.size.y / logical.y)
	size = render_size(Vector2i(logical * fit), quality)

func to_farm_position(logical_position: Vector2) -> Vector2:
	var logical: Vector2 = get_tree().root.get_visible_rect().size.max(Vector2.ONE)
	return logical_position * Vector2(size) / logical
