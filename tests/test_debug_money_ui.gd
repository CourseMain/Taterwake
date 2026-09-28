extends SceneTree
## Numeric text input, one-shot money changes, and precise balances.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false
var sent_action: String = ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func type_money(source: String) -> void:
	if not game.hud._refs.debug_advanced.visible: game.hud._act("toggle_details:debug_advanced")
	(game.hud._body.get_parent() as ScrollContainer).ensure_control_visible(game.hud._refs.debug_money)
	var field: LineEdit = game.hud._refs.debug_money.get_line_edit()
	field.grab_focus()
	field.clear()
	field.insert_text_at_caret(source)
	field.text_changed.emit(field.text)

func shot(name: String) -> void:
	if not capture:
		return
	game.hud._toast_box.hide()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/debug-money-" + name + ".png") == OK, "render " + name)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not capture and not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._on_action("debug")
	game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
	game.hud._refs.debug_unlock.pressed.emit()
	game.hud.action_requested.connect(func(action: String) -> void: sent_action = action)
	for source: String in ["0.1", "0.01", "0", "2"]:
		game.state.coins = 1000
		type_money(source)
		check(not game.hud._refs.debug_apply.disabled, "valid multiplier enables Apply: " + source)
		game.hud._refs.debug_apply.pressed.emit()
		check(is_equal_approx(game.state.coins, 1000 * float(source)), "Apply uses typed amount: " + source)
		check(game.hud._refs.debug_money.value == 1.0, "Apply returns to neutral multiplier")
		game.hud._refs.debug_apply.pressed.emit()
		check(is_equal_approx(game.state.coins, 1000 * float(source)), "second Apply cannot repeat the change")
	for invalid: String in ["", "bad", "-1", "nan", "inf", "100001"]:
		game.state.coins = 2000
		type_money(invalid)
		check(game.hud._refs.debug_apply.disabled, "invalid input disables Apply: " + invalid)
		game.hud._act("debug_apply")
		check(game.state.coins == 2000, "invalid input preserves cash")
	game.state.coins = 12345
	type_money("0.1")
	check(game.hud._refs.debug_balance.text.contains("12,345"), "debug balance uses grouped integers")
	await shot("decimal-controls")
	game.hud.close_panel()
	if capture:
		root.size = Vector2i(960, 600)
		game._on_action("debug")
		type_money("0.01")
		await shot("compact-controls")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("DEBUG MONEY UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
