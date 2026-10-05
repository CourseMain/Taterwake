extends "res://scripts/npc_portrait.gd"
## An isolated view of the same farmer model used on the farm.
var turn: float = 0.0
var hat_tip: float = 0.0
func show_farmer(look: Dictionary) -> void:
	if not is_instance_valid(avatar):
		avatar = preload("res://scripts/farmer_avatar.gd").new()
		viewport.add_child(avatar); avatar.setup()
	avatar.set_season(0); avatar.apply_appearance(look)
	hat_tip = .65
	queue_redraw(); _sync_resolution()
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar): return
	turn += delta * .22
	avatar.rotation.y = turn
	avatar.animate(delta)
	hat_tip = maxf(0, hat_tip - delta)
	if hat_tip > 0: avatar._rig.rotation.x -= sin(hat_tip / .65 * PI) * .12
	camera.size = 2.9; camera.look_at(Vector3(0, 1.12, 0))
	_sync_resolution()
