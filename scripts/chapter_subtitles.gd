extends Control
## Reusable timed chapter subtitle and skip control, reserved for year-start pages.
signal finished
const Type = preload("res://scripts/ui_type.gd")
const DURATION: float = 12.0
var elapsed: float = 0.0
var chapter: Label
var skip: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 130
	chapter = Label.new()
	add_child(chapter)
	chapter.text = ""
	chapter.add_theme_font_override("font", Type.face(Type.BODY, 650))
	chapter.add_theme_font_size_override("font_size", 18)
	chapter.add_theme_color_override("font_color", Color("f2dfb5"))
	chapter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skip = Button.new()
	skip.text = "Skip →"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 22)
	add_child(skip)
	skip.pressed.connect(func(): stop(); finished.emit())
	stop()
func start(text: String) -> void:
	chapter.text = text
	if visible: return
	elapsed = 0.0
	show()
	set_process(true)
	_process(0)
func stop() -> void:
	hide()
	set_process(false)
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		stop()
		finished.emit()

func _process(delta: float) -> void:
	elapsed = minf(DURATION, elapsed+delta)
	chapter.position = Vector2(30,100)
	chapter.size = Vector2(maxf(180,size.x-60),60)
	skip.position = Vector2(size.x-154,18)
	skip.size = Vector2(130,68)
	if elapsed>=DURATION:
		stop()
		finished.emit()
