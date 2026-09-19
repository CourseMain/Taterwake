extends Control
## A soft, click-through ring and arrow follow the actual live button bounds.
var target: Control
var clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 31

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var rect: Rect2 = target.get_global_rect()
	# Do not point at an item scrolled out of a shop.
	var ancestor: Node = target.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(rect):
			return
		ancestor = ancestor.get_parent()
	rect.position -= global_position
	var pulse: float = 0.5 + 0.5 * sin(clock * 3.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("ffdd78")
	style.set_border_width_all(3)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(1.0, 0.75, 0.25, 0.18 + pulse * 0.12)
	style.shadow_size = 6
	draw_style_box(style, rect.grow(4.0 + pulse * 2.0))
	var point: Vector2 = Vector2(rect.get_center().x, rect.position.y - 10.0 - pulse * 5.0)
	draw_colored_polygon(PackedVector2Array([point, point + Vector2(-10, -12), point + Vector2(10, -12)]), Color("ffdd78"))
