extends OptionButton
## The location picker uses the same drawing layout and native popup behavior.
const Layout = preload("res://scripts/illustrated_button.gd")
var picture: Dictionary = {"kind":"symbol", "id":"compass"}
var picture_pixels: float = 32.0
var picture_scale: float = 1.0
var _signature: String = ""
var _fitting: bool = false
func _ready() -> void:
	resized.connect(queue_redraw)
	refresh_picture()
func _process(_delta: float) -> void:
	if is_visible_in_tree(): refresh_picture()
func has_picture() -> bool: return not text.is_empty()
func refresh_picture() -> void: Layout.fit_picture(self)
func _draw() -> void: Layout.paint_picture(self)
