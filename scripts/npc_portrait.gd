extends "res://scripts/equipment_preview.gd"
const NpcAvatar = preload("res://scripts/npc_avatar.gd")
var camera: Camera3D
var _entrance: float = 0.0

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = ""
	for child in viewport.get_children():
		if child is Camera3D: camera = child
		if child is MeshInstance3D: child.hide()
	camera.size = 2.35
	camera.position = Vector3(.15,1.45,4.4)
	camera.look_at(Vector3(0,1.18,0))

func show_person(id: String) -> void:
	if is_instance_valid(avatar):
		viewport.remove_child(avatar)
		avatar.queue_free()
	avatar = NpcAvatar.new()
	viewport.add_child(avatar)
	avatar.configure(id)
	_background.bg_color = Color(NpcAvatar.Roster.PEOPLE[id].color).darkened(.55)
	_entrance = 0.0
	queue_redraw()
	_sync_resolution()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar): return
	var dt: float = clampf(delta,0,.1)
	_entrance = minf(1.0,_entrance+dt*1.8)
	avatar.rotation.y = -.12 + (1.0-_entrance)*.18
	avatar.animate(dt)
	var aspect: float = size.x / maxf(1,size.y)
	var span: float = clampf(1.55 / maxf(.5,aspect),1.5,2.22)
	camera.size = lerpf(span+.25,span,smoothstep(0,1,_entrance))
	camera.look_at(Vector3(0,lerpf(1.48,1.18,(span-1.5)/.72),0))
	_resolution_clock += dt
	if _resolution_clock >= .5:
		_resolution_clock = 0
		_sync_resolution()

func _gui_input(_event: InputEvent) -> void: pass
