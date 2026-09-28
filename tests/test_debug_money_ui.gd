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
	game.state.coins = 1e20
	game._on_action("debug")
	game.hud._refs.debug_code.text = "ORIGINALLYSPUDREPUBLIC"
	game.hud._refs.debug_unlock.pressed.emit()
	game.hud.action_requested.connect(func(action: String) -> void: sent_action = action)
	for source: String in ["0.1", "0.01"]:
		game.state.coins = 1000.0
		type_money(source)
		check(not game.hud._refs.debug_apply.disabled and game.hud._refs.debug_preview.text.contains("× " + source), "fractional input updates the live preview: " + source)
		game.hud._refs.debug_apply.pressed.emit()
		var expected: float = 100.0 if source == "0.1" else 10.0
		check(game.state.coins == expected and float(sent_action.get_slice(":", 2)) == float(source), "Apply transmits the fractional amount without integer truncation: " + source)
		check(game.hud._refs.debug_money.value == 1.0, "money resets to neutral after each fractional Apply")
		game.hud._refs.debug_apply.pressed.emit()
		check(game.state.coins == expected, "repeated Apply does not reduce money again")
	for source: String in ["1e-20", "0.00000000000000000001"]:
		game.state.coins = 1e20
		type_money(source)
		check(not game.hud._refs.debug_apply.disabled and game.hud._refs.debug_money.value > 0.0, "tiny positive input is accepted without becoming zero: " + source)
		check(game.hud._refs.debug_preview.text.contains("× 1e-20 → \uE000 1"), "tiny multiplier previews the true one-dollar result")
		await shot("tiny-input")
		game.hud._refs.debug_apply.pressed.emit()
		check(game.state.coins == 1.0 and sent_action.ends_with(":1e-20"), "scientific and long decimal input both scale 1e20 to exactly1")
	game.state.coins = 240.0
	type_money("1e-3")
	check(game.hud._refs.debug_preview.text.contains("\uE000 0.24"), "fractional-dollar preview does not round to zero")
	game.hud._refs.debug_apply.pressed.emit()
	check(is_equal_approx(game.state.coins, 0.24) and game.hud._refs.debug_balance.text.contains("\uE000 0.24"), "fractional balance is preserved and displayed")
	game.state.coins = 1e20
	type_money("0.12345678901234567")
	var exact: float = game.hud._refs.debug_money.value
	game.hud._refs.debug_apply.pressed.emit()
	check(float(sent_action.get_slice(":", 2)) == exact and game.state.coins == 1e20 * exact, "Apply preserves all parsed significant digits instead of shortening to a display label")
	for invalid: String in ["", "bad", "-0.1", "nan", "inf", "1e-999", "1e999", "1000001"]:
		game.state.coins = 240.0
		type_money(invalid)
		check(game.hud._refs.debug_apply.disabled, "invalid or underflow input disables Apply: " + invalid)
		game.hud._act("debug_apply")
		check(game.state.coins == 240.0, "invalid money text never wipes a purse: " + invalid)
	game.state.coins = 1e-200
	type_money("1e-200")
	check(game.hud._refs.debug_money.value > 0.0 and game.hud._refs.debug_apply.disabled, "a valid positive multiplier whose product underflows is visibly disabled")
	check(game.hud._refs.debug_preview.text.contains("nonzero balance") and not game.hud._refs.debug_preview.text.contains("→ \uE000 0"), "product underflow shows the reason instead of promising a zero balance")
	game.hud._act("debug_apply")
	check(game.state.coins == 1e-200 and game.hud._refs.debug_money.text == "1e-200", "rejected product underflow keeps the purse and editable input unchanged")
	type_money("1")
	check(not game.hud._refs.debug_apply.disabled, "a representable replacement immediately enables Apply again")
	game.state.coins = 240.0
	type_money("0")
	check(not game.hud._refs.debug_apply.disabled and game.hud._refs.debug_preview.text.contains("× 0 → \uE000 0"), "explicit zero clearly previews wiping the purse")
	game.hud._refs.debug_apply.pressed.emit()
	check(game.state.coins == 0.0 and game.hud._refs.debug_money.value == 1.0, "explicit zero applies and returns the field to neutral")
	game.hud._refs.debug_apply.pressed.emit()
	check(game.state.coins == 0.0, "neutral repeated Apply leaves an empty purse unchanged")
	for raw: String in ["bad", "", "1e-999"]:
		game.state.coins = 240.0
		game._on_action("debug:apply:" + raw)
		check(game.state.coins == 240.0, "main action path rejects malformed or underflow text: " + raw)
	game.state.coins = 1e20
	game._on_action("debug:apply:0.00000000000000000001")
	check(game.state.coins == 1.0, "main action parser also handles raw tiny decimal without wiping")
	game.state.coins = 1e20
	type_money("0.1")
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
