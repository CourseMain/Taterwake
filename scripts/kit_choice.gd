extends Button
## A drawn clothing tile or colour swatch, one target, no word-only pills.
const Kit = preload("res://scripts/ui_kit.gd")
var choice: String = ""
var field: String = "hat"
var unit: float = 1
func _ready() -> void:
	set_meta("kit_type", true)
	set_meta("plain_control", true)
	resized.connect(queue_redraw)
	toggled.connect(func(_on): queue_redraw())
func _draw() -> void:
	var rarity: Color = Kit.RARITIES[{"flower":"common", "scarf":"uncommon", "glasses":"rare"}.get(choice, "common")] if choice in ["flower", "scarf", "glasses"] else Kit.RULE
	var box := Kit.skin(Kit.CREAM if field == "hat" else Color(choice), rarity if choice in ["flower", "scarf", "glasses"] else Kit.MONEY if button_pressed else rarity, 0, 12 if field == "hat" else 999, unit, false)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if field != "hat": return
	if button_pressed:
		var inner := Kit.skin(Color.TRANSPARENT, Kit.MONEY, 0, 8, unit, false)
		inner.set_border_width_all(ceili(2 * unit))
		draw_style_box(inner, Rect2(Vector2.ONE * 5 * unit, size - Vector2.ONE * 10 * unit))
	var center := Vector2(size.x * .5, 22 * unit)
	var straw := Color("e4c060")
	if choice in ["straw", "flower", "seasonal"]:
		draw_set_transform(center, 0, Vector2(unit, unit))
		paint_ellipse(Vector2.ZERO, Vector2(18, 5), straw)
		paint_ellipse(Vector2(0, -5), Vector2(10, 7), straw)
		if choice == "flower":
			for i in range(5): draw_circle(Vector2(9, -7) + Vector2.from_angle(i * TAU / 5) * 3, 2.5, Color("f4a3b0"))
			draw_circle(Vector2(9, -7), 2, Kit.MONEY)
	elif choice == "scarf":
		draw_set_transform(center, 0, Vector2(unit, unit))
		draw_polyline(PackedVector2Array([Vector2(-12,4), Vector2(-8,0), Vector2(8,0), Vector2(12,4)]), Kit.KEEPERS.tess, 6, true)
	elif choice == "glasses":
		draw_set_transform(center, 0, Vector2(unit, unit))
		draw_arc(Vector2(-7,0),6,0,TAU,24,Kit.INK,2,true); draw_arc(Vector2(7,0),6,0,TAU,24,Kit.INK,2,true)
		draw_line(Vector2(-1,0),Vector2(1,0),Kit.INK,2,true)
	else:
		draw_set_transform(center, 0, Vector2(unit, unit))
		for i in range(8): draw_arc(Vector2.ZERO,10,i*TAU/8,i*TAU/8+.4,6,Kit.RULE,3,true)
	draw_set_transform(Vector2.ZERO)
	var font: Font = Kit.Type.face(Kit.Type.BODY)
	var pixels: int = get_theme_font_size("font_size")
	var span: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(font, Vector2((size.x - span) / 2, size.y - 10 * unit), text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Kit.INK)
func paint_ellipse(origin: Vector2, radii: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40): points.append(origin + Vector2.from_angle(i * TAU / 40) * radii)
	draw_colored_polygon(points, colour)
