extends "res://scripts/kit_card.gd"
var flash_left: float = 0.0
var flame_left: float = 0.0
func _draw() -> void:
	super._draw()
	if flash_left > 0:
		draw_rect(Rect2(Vector2(2,2)*unit,size-Vector2(4,4)*unit),Color(edge,flash_left/.3),false,5*unit,true)
	if flame_left <= 0: return
	for i in range(6):
		var x: float = 10*unit + (size.x-20*unit)*float(i)/5
		var height: float = (8+sin(flame_left*25+i)*5)*unit
		draw_colored_polygon(PackedVector2Array([Vector2(x-4*unit,4*unit),Vector2(x,-height),Vector2(x+4*unit,4*unit)]),edge)
func _process(delta: float) -> void:
	if flash_left > 0: flash_left = maxf(0,flash_left-delta); queue_redraw()
	if flame_left > 0: flame_left = maxf(0,flame_left-delta); queue_redraw()
