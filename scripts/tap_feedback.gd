extends Node
## A press answers before a card's release action builds the next page.
signal tapped(control: Button)
var game: Node
var _last_control: int = 0
var _last_tick: int = -100
func _ready() -> void:
	get_tree().node_added.connect(_register)
	_walk(game)
func _walk(node: Node) -> void:
	_register(node)
	for child in node.get_children(): _walk(child)
func _register(node: Node) -> void:
	if not node is Button or not game.is_ancestor_of(node): return
	if node.has_meta("tap_feedback"): return
	# Native OptionButton opens on press by default. Let the press draw and
	# sound first, then open the dropdown on release like the other controls.
	if node is OptionButton: node.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	node.set_meta("tap_feedback", true)
	node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed:
			_press(node)
	)
func _press(button: Button) -> void:
	var now := Time.get_ticks_msec()
	# Touch-emulated mouse input is the same press, not a second sound.
	if _last_control == button.get_instance_id() and now - _last_tick < 30: return
	_last_control = button.get_instance_id(); _last_tick = now
	game.hud.last_tap = button
	var previous = button.get_meta("tap_tween") if button.has_meta("tap_tween") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	button.pivot_offset = button.size * .5
	button.scale = Vector2(.96,.96)
	var tween := button.create_tween()
	button.set_meta("tap_tween", tween)
	tween.tween_property(button,"scale",Vector2.ONE,.15)
	game.feedback_audio.play_tone(440,.10)
	if button.disabled:
		var reason := "Unavailable now."
		var action: String = str(button.get_meta("action", ""))
		if game.tutorial.active: reason = "Follow the guided year."
		elif game.state.run_over: reason = "Run over."
		elif action == "market_sell" or action.begins_with("sell_amount:"): reason = "Not enough tonnes."
		elif button.name.begins_with("FarmerChoice_"): reason = "Hat locked. Complete its quest first."
		elif button.text.contains("Fully upgraded") or button.text.contains("Top speed"): reason = "Fully upgraded. Choose another tool."
		elif button.text.contains("Hire a duck first"): reason = "No ducks. Hire a duck first."
		elif action.begins_with("buy") or action.begins_with("upgrade") or action.begins_with("lease") or action.begins_with("build"): reason = game.state.purchase_refusal()
		game.hud.show_refusal(reason,button)
	tapped.emit(button)
