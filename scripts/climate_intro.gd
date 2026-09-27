extends Control
## First-arrival cinematic. Only presentation time advances; the farm stays paused.
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
	chapter.text = "GOLDEN SHORES"
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
func start() -> void:
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
	queue_redraw()
	if elapsed>=DURATION:
		stop()
		finished.emit()
func _draw() -> void:
	var storm: float = smoothstep(2.0,8.0,elapsed)
	var top := Color("71b8c8").lerp(Color("1c2d4e"),storm)
	var bottom := Color("eed7a0").lerp(Color("687d91"),storm)
	for i in range(24):
		draw_rect(Rect2(0,size.y*i/24.0,size.x,size.y/24.0+1),top.lerp(bottom,i/24.0))
	var sun := Vector2(size.x*0.72,size.y*0.27)
	for i in range(4,0,-1): draw_circle(sun,42+i*16,Color(1,0.83,0.48,(1-storm)*0.035))
	draw_circle(sun,42,Color(1,0.9,0.62,1-storm))
	# Soft clouds sweep in and darken while the sea and palms catch the wind.
	for i in range(9):
		var center := Vector2(fposmod(i*size.x/6.0+elapsed*(8+storm*25),size.x+320)-160,size.y*(0.18+float(i%3)*0.105))
		for j in range(5):
			draw_circle(center+Vector2(j*30,sin(j*1.5)*18),48+j%2*15,Color("f3ead0").lerp(Color("344256"),storm))
	var sea_y: float = size.y*0.54
	draw_rect(Rect2(0,sea_y,size.x,size.y-sea_y),Color("4d9ca8").lerp(Color("233e59"),storm))
	for i in range(14):
		var points := PackedVector2Array()
		for j in range(32): points.append(Vector2(size.x*j/31.0,sea_y+i*10+sin(j*0.5+elapsed*(1+storm*2)+i)*3))
		draw_polyline(points,Color(0.7,0.86,0.85,0.15),2,true)
	var island := PackedVector2Array([Vector2(0,size.y*.68),Vector2(size.x*.18,size.y*.59),Vector2(size.x*.42,size.y*.61),Vector2(size.x*.62,size.y*.7),Vector2(size.x,size.y*.66),Vector2(size.x,size.y),Vector2(0,size.y)])
	draw_colored_polygon(island,Color("ae9b63").lerp(Color("2a4546"),storm))
	for i in range(3):
		var base := Vector2(size.x*(0.1+i*.34),size.y*(.69+(i%2)*.03))
		var crown := base+Vector2(12+sin(elapsed*1.8+i)*storm*14,-size.y*.17)
		draw_line(base,crown,Color("554f3c"),9,true)
		for leaf in range(5):
			var direction := Vector2.from_angle(-PI+leaf*PI/4)
			draw_line(crown,crown+direction*58+Vector2(storm*14,14),Color("315c4b"),13,true)
	if storm>0:
		var rain := PackedVector2Array()
		for i in range(100):
			var p := Vector2(fposmod(i*133.0-elapsed*180,size.x+50),fposmod(i*79.0+elapsed*490,size.y))
			rain.append(p); rain.append(p+Vector2(-8,20))
		draw_multiline(rain,Color(.75,.88,1,storm*.28),1.2,true)
	if elapsed>6.4 and elapsed<6.65:
		var bolt := PackedVector2Array([Vector2(size.x*.63,0),Vector2(size.x*.59,size.y*.22),Vector2(size.x*.63,size.y*.21),Vector2(size.x*.57,size.y*.42)])
		draw_polyline(bolt,Color(.85,.94,1,.8),3,true)
	draw_rect(Rect2(0,0,size.x,84),Color(0.04,0.1,0.15,.88))
