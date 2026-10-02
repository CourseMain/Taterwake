extends PanelContainer
## Quiet board_kind marks distinguish the chalkboard, cork and pegboard.
var board_kind: String = "chalk"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(queue_redraw)
func _draw() -> void:
	var ink := Color("f9efd6", .08)
	if board_kind == "peg": ink = Color("4e392c", .28)
	if board_kind == "cork": ink = Color("5b3f20", .10)
	if board_kind in ["chalk", "peg", "cork"]:
		var step: int = 18 if board_kind == "peg" else 12
		for x in range(8, int(size.x), step):
			for y in range(8, int(size.y), step): draw_circle(Vector2(x, y), 2 if board_kind == "peg" else .7, ink)
	elif board_kind == "timber":
		for y in range(16, int(size.y), 52):
			draw_line(Vector2(8, y), Vector2(size.x - 8, y + 2), Color("765333", .16), 1)
