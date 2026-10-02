extends Control
## Functional ink marks shared by the ledger, forecast and seasonal masthead.
const Type = preload("res://scripts/ui_type.gd")
const INK := Color("17382d")
const RULE := Color("c9c5af")
var kind: String = "leaders"
var low: float = 0.0
var high: float = 1.0
var season: int = 0
var year: int = 1
var caption: Label
var amount: Label
var font: Font = Type.face(Type.BODY, 600)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	match kind:
		"leaders":
			if not is_instance_valid(caption) or not is_instance_valid(amount): return
			var a: float = caption.position.x + caption.size.x + 8
			var b: float = amount.position.x - 8
			for x in range(int(a), int(b), 5): draw_circle(Vector2(x, size.y * 0.62), 0.65, RULE.darkened(0.2))
			draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), RULE, 1)
		"pin":
			draw_circle(Vector2(size.x / 2 + 1, 8), 6, Color("17382d", 0.18))
			draw_circle(Vector2(size.x / 2, 6), 5, Color("bb654d"))
		"range":
			var scale: float = minf(float(get_tree().root.size.x) / get_viewport_rect().size.x, float(get_tree().root.size.y) / get_viewport_rect().size.y)
			var factor: float = maxf(1, 1 / maxf(0.1, scale))
			var left: float = 18
			var width: float = size.x - 36
			draw_line(Vector2(left, 36 * factor), Vector2(left + width, 36 * factor), RULE.darkened(0.2), 2)
			for tick in range(5):
				var x: float = left + width * tick / 4.0
				draw_line(Vector2(x, 32 * factor), Vector2(x, 40 * factor), RULE.darkened(0.2), 1)
				draw_string(font, Vector2(x - 12 * factor, 62 * factor), str(tick * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(13 * factor), INK)
			var a := Vector2(left + width * low, 20 * factor)
			var b := Vector2(left + width * high, 20 * factor)
			draw_line(a, b, INK, 3)
			draw_line(a, a + Vector2(0, 10 * factor), INK, 3)
			draw_line(b, b + Vector2(0, 10 * factor), INK, 3)
			draw_string(font, Vector2(maxf(left, a.x - 10), 14 * factor), "%d–%d%%" % [roundi(low * 100), roundi(high * 100)], HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(14 * factor), INK)
		"season":
			var scale: float = minf(float(get_tree().root.size.x) / get_viewport_rect().size.x, float(get_tree().root.size.y) / get_viewport_rect().size.y)
			var pixels: int = 11 if size.x < 400 else ceili(14 / maxf(scale, 0.1))
			var names: Array = ["Spring", "Summer", "Autumn", "Winter"]
			var year_words: String = "YEAR %02d" % year
			var year_width: float = maxf(78, font.get_string_size(year_words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 12)
			var width: float = (size.x - year_width) / 4
			while pixels > 10 and names.any(func(words): return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width - 10):
				pixels -= 1
				year_width = maxf(78, font.get_string_size(year_words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 12)
				width = (size.x - year_width) / 4
			for index in range(4):
				var rect := Rect2(index * width, 0, width - 3, size.y - 1)
				draw_rect(rect, INK if index == season else Color("fffbed"))
				draw_rect(rect, RULE, false)
				draw_string(font, Vector2(rect.position.x + 5, size.y * 0.72), names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color("fffbed") if index == season else INK)
			draw_rect(Rect2(size.x - year_width, 0, year_width, size.y - 1), Color("fffbed"))
			draw_string(font, Vector2(size.x - year_width + 6, size.y * 0.72), year_words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, INK)
