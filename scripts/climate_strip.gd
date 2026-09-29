extends Control
## Ten years of actual warnings, with procedural icons rather than font glyphs.
const Type = preload("res://scripts/ui_type.gd")
const Climate = preload("res://scripts/climate_system.gd")
var records: Array = []
var year: int = 1
var font: Font = Type.face(Type.BODY)
func _init() -> void:
	custom_minimum_size = Vector2(280, 126)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
func setup(entries: Array, current_year: int) -> void:
	records = entries.duplicate(true); year = current_year
	var lines := PackedStringArray()
	for e in records: lines.append("Year %d · %s · %s" % [e.year, ["Spring", "Summer", "Autumn", "Winter"][int(e.season)], Climate.EVENTS[e.event].name])
	tooltip_text = "\n".join(lines)
	queue_redraw()
func _draw() -> void:
	var width: float = size.x / 10.0
	for y in range(1, 11):
		var rect := Rect2((y - 1) * width + 1, 0, width - 2, 122)
		draw_rect(rect, Color("e4d7b7") if y == year else Color("f0e6ce"))
		draw_string(font, Vector2(rect.position.x + 6, 20), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("493d2b"))
		var row: int = 0
		for e in records:
			if int(e.year) != y: continue
			_icon(Vector2(rect.position.x + rect.size.x / 2, 39 + row * 24), str(e.event))
			row += 1
		if row == 0: draw_line(Vector2(rect.position.x + 8, 45), Vector2(rect.end.x - 8, 45), Color("9d9279"), 1)
func _icon(p: Vector2, event: String) -> void:
	var ink := Color("496b76")
	if event == "drought":
		draw_circle(p, 4, Color("b88836"))
		for i in range(8): draw_line(p + Vector2.from_angle(i * TAU / 8) * 6, p + Vector2.from_angle(i * TAU / 8) * 9, Color("b88836"), 1.5, true)
	elif event == "storm":
		draw_polyline(PackedVector2Array([p + Vector2(3,-9), p + Vector2(-5,1), p + Vector2(3,0), p + Vector2(-3,9)]), Color("88604a"), 2, true)
	elif event == "flood":
		for i in range(3): draw_polyline(PackedVector2Array([p + Vector2(-8, i*4-4), p + Vector2(-3,i*4-6), p + Vector2(3,i*4-3),p + Vector2(8,i*4-5)]), ink, 1.5, true)
	else:
		for i in range(6): draw_line(p, p + Vector2.from_angle(i * TAU / 6) * 8, ink, 1.5, true)
		if event == "blizzard": draw_line(p + Vector2(-10,7), p + Vector2(10,4), ink, 2, true)
		if event == "deep_freeze": draw_arc(p, 10, 0, TAU, 20, ink, 1, true)
