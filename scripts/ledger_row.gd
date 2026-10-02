extends PanelContainer
## A ruled accounting row keeps its figures aligned, including on phones.
const Type = preload("res://scripts/ui_type.gd")
var hud
var caption: Label
var amount: Label
var font: Font = Type.face(Type.BODY, 400)

func setup(owner_hud, words: String, value: String) -> void:
	hud = owner_hud
	font.fallbacks = [Type.SPUDION]
	set_meta("market_responsive", true)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	caption = hud._label(words, 15)
	row.add_child(caption)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	amount = hud._label(value, 15)
	row.add_child(amount)
	var rule := preload("res://scripts/paper_detail.gd").new()
	rule.caption = caption; rule.amount = amount
	add_child(rule)
	amount.resized.connect(rule.queue_redraw)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var touch = hud.get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	for label in [caption, amount]:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 22 if phone else 15)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
