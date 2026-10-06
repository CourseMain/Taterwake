extends VBoxContainer
## The grade is a paper stamp; its first-three-harvest gloss sits underneath.
const Stamp = preload("res://scripts/grade_stamp.gd")
var word: String = ""
var tag: Label
var gloss: Label
var text: String:
	get: return word + ("\n" + gloss.text if is_instance_valid(gloss) else "")
func setup(grade: String, explain: bool) -> void:
	word = grade; mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	tag = Label.new(); tag.text = grade; tag.name = "HarvestGrade"
	Stamp.apply(tag, grade, 16); tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; add_child(tag)
	if explain:
		gloss = Label.new(); gloss.name = "HarvestGloss"; gloss.text = Stamp.GLOSSES[grade]
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE; gloss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gloss.add_theme_font_override("font", Stamp.Type.face(Stamp.Type.BODY))
		gloss.add_theme_color_override("font_color", Color("17382d")); gloss.add_theme_color_override("font_outline_color", Color("fffbed")); gloss.add_theme_constant_override("outline_size", 2)
		add_child(gloss)
func fit(scale: float) -> void:
	var pixels: int = ceili(16 / scale)
	add_theme_font_size_override("font_size", pixels); tag.add_theme_font_size_override("font_size", pixels)
	if is_instance_valid(gloss): gloss.add_theme_font_size_override("font_size", ceili(14 / scale))
	add_theme_constant_override("separation", ceili(6 / scale))
