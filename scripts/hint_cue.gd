extends Control
## A small friendly cue draws the eye without moving text or taking input.
var elapsed: float = 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)
func restart() -> void:
	elapsed = 0
	queue_redraw()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	var pulse: float = sin(minf(elapsed, 1.5) * TAU * 1.3) * maxf(0, 1 - elapsed / 1.5)
	var centre := size * .5 + Vector2(0, -pulse * 2)
	var radius: float = minf(size.x, size.y) * .36
	draw_circle(centre, radius + 3, Color(0.96, .77, .35, .20 + absf(pulse) * .15))
	draw_circle(centre, radius, Color("e9bf72"))
	for side in [-1, 1]: draw_circle(centre + Vector2(side * radius * .32, -radius * .10), radius * .09, Color("17382d"))
	draw_arc(centre + Vector2(0, radius * .18), radius * .25, .2, PI - .2, 10, Color("79553d"), 1.5, true)
