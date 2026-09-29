extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## Real capacity changes, alert actions and warning visibility; isolated saves.
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func settle() -> void:
	for i in range(6): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.state.tutorial_progress.completed = true
	game.hud.set_tutorial({})
	game.state.storage["russet"] = Stock.pile(game.state.capacity - 1)
	game.hud.update_state(game.state)
	check(not game.hud._barn_full_alert.visible, "almost full storage does not show a full-barn alert")
	Stock.add(game.state.storage, "russet", 1, 60)
	game.hud.update_state(game.state)
	await settle()
	check(game.hud._barn_full_alert.visible, "filling the barn shows a persistent banner")
	check(game.hud._barn_full_alert.get_theme_stylebox("panel").bg_color.r > .5, "full barn uses the red alert palette")
	check(game.hud.root.get_global_rect().encloses(game.hud._barn_full_alert.get_global_rect()), "full-barn banner fits inside the viewport")
	if game.touch_controls.enabled:
		root.min_size = Vector2i.ZERO
		for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			await settle()
			var alert: Rect2 = game.hud._barn_full_alert.get_global_rect()
			check(game.hud.root.get_global_rect().encloses(alert), "phone full-barn banner fits " + str(dimensions))
			check(not alert.intersects(game.touch_controls.sell_button.get_global_rect()) and not alert.intersects(game.touch_controls.status.get_global_rect()), "phone full-barn alert clears existing controls " + str(dimensions))
			check(game.hud._barn_full_sell.size.y >= 68, "phone alert retains a large sell touch target")
	game.hud._process(8)
	check(game.hud._barn_full_alert.visible, "full-barn warning remains after temporary hints expire")
	game.hud._barn_full_sell.pressed.emit()
	await settle()
	check(game.hud._panel_kind == "sell_potatoes" and not game.hud._barn_full_alert.visible, "banner opens the selling board without covering its controls")
	game._on_action("sell:russet:-1")
	game.hud.close_panel()
	await settle()
	check(game.state.storage_used() == 0 and not game.hud._barn_full_alert.visible, "selling clears the warning immediately")
	game.hud.set_context("12 more beds · Unlock at Tools for \uE000 1.8K")
	await settle()
	check(game.hud._context_box.visible and game.hud._context_box.get_meta("warning", false), "locked-bed reminder stays visible on desktop and touch")
	var skin: StyleBoxFlat = game.hud._context_box.get_theme_stylebox("panel")
	check(skin.bg_color.r > skin.bg_color.g * 2, "locked-bed reminder uses red rather than farm green")
	check(game.hud.root.get_global_rect().encloses(game.hud._context_box.get_global_rect()), "warning reminder stays inside the viewport")
	game.hud.show_panel("duck_patrol",game.state)
	await settle()
	check(not game.hud._refs.has("duck_summary") and not game.hud._refs.has("activity_hint"), "duck screen omits all-island limits and filler footer")
	check(game.hud._refs.duck_pond.capacity == 2 and game.hud._refs.duck_pond.count == 0, "pond reflects the local flock")
	game.state.coins = 10000
	game.hud.update_state(game.state)
	game.hud._refs["activity:duck"].pressed.emit()
	await settle()
	check(game.activities.duck_count() == 1 and game.hud._refs.duck_pond.count == 1, "hiring adds a real duck to the pond")
	game.queue_free()
	await settle()
	print("FARM ALERTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
