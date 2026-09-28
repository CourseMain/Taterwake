extends SceneTree
## Real input and layout checks for farm guidance and overlapping help.
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(why)
func settle() -> void:
	for i in range(5): await process_frame
func shot(name: String) -> void:
	await settle()
	if "--capture" not in OS.get_cmdline_user_args(): return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/audit-" + name + ".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game._on_action("tools")
	game.hud.show_toast("Upgrade a tool to work more beds.")
	await settle()
	check(not game.hud._toast_box.get_global_rect().intersects(game.hud._modal_card.get_global_rect()), "notifications stay clear of modal content and its close button")
	check(game.hud.root.get_global_rect().encloses(game.hud._toast_box.get_global_rect()), "docked notification remains within the game view")
	# Reproduce the supplied screenshot: Island2, debt, pest tip, selected tank.
	game.state.debug_unlock_island(2)
	game.state.travel_to(2)
	game.state.climate.acknowledge(game.state)
	game.state.farm_help.enable()
	game.state.farm_help.data.pest_phase = 1
	game.state.farm_help.data.dismissed.clear()
	game._select_equipment("tank")
	game.hud.update_state(game.state)
	await settle()
	game._update_equipment_card()
	check(not game.hud._farm_help_card.visible, "pest tip cannot cover an equipment card")
	check(not game.hud._climate_console.get_global_rect().intersects(game.hud.root.get_node("ToolHotbar").get_global_rect()), "tank card clears the farming hotbar")
	game.hud.show_toast("Tank selected. Your watering can is full.")
	await settle()
	check(game.hud._toast_label.get_visible_line_count() > 0 and game.hud._toast_label.size.y >= 16, "world notifications retain visible text after leaving a compact modal")
	await shot("tank-debt")
	game._close_equipment()
	game._on_action("tools")
	game.hud.update_state(game.state)
	await shot("tools-debt")
	game.queue_free()
	await settle()
	print("PLAYABILITY AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
