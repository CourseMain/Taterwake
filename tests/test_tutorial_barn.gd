extends SceneTree
## First-harvest sale remains reachable from a remembered inventory tab.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func button(action: String) -> Button:
	for candidate: Node in game.hud.root.find_children("*", "Button", true, false):
		if candidate.get_meta("hud_action", "") == action and candidate.is_visible_in_tree(): return candidate
	return null

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null and not target.disabled, "visible enabled action " + action)
	if target != null and not target.disabled: target.pressed.emit()

func settle() -> void:
	for frame: int in range(8): await process_frame

func walk_plot(tool: String) -> void:
	game._on_action("tool:" + tool)
	game.queue_plot(4)
	for frame: int in range(400):
		game._process(0.04)
		if not game.walking: break

func check_crops() -> void:
	check(game.hud._inventory_tab == "crops", "lesson opens crops instead of remembered Tools")
	check(game.hud._inventory_sections.crops.is_visible_in_tree(), "crop crates visible")
	check(not game.hud._inventory_sections.tools.is_visible_in_tree(), "tools loadout hidden")
	check(button("inventory_tab:crops") != null and not button("inventory_tab:crops").disabled, "crop tab stays usable")
	check(button("inventory_tab:tools").disabled, "unrelated tools stays locked during lesson")
	check(game.tutorial.allows_action("inventory_tab:crops"), "controller permits crop tab")
	check(button("sell:russet:-1") != null and not button("sell:russet:-1").disabled, "harvest sale available")

func sell_harvest() -> void:
	var coins_before: float = game.state.coins
	var sales_before: float = game.state.lifetime_sales
	check(game.state.storage.russet > 0, "real harvest stored before selling")
	press("sell:russet:-1")
	check(game.state.storage.russet == 0, "sale clears harvested Russets")
	check(game.state.coins > coins_before and game.state.lifetime_sales > sales_before, "sale credits coins")
	check(not game.tutorial.active and game.state.tutorial_progress.completed, "barn sale completes lesson")

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hud.show_panel("barn", game.state)
	press("inventory_tab:tools")
	game.hud.close_panel()
	game.hud.show_panel("barn", game.state)
	check(game.hud._inventory_tab == "tools", "ordinary barn preserves selected Tools")
	game.tutorial.start()
	press("tutorial:next")
	game._on_action("market")
	press("buy:russet:1")
	walk_plot("hoe")
	walk_plot("plant")
	walk_plot("water")
	game._process(float(game.state.CropTable.CROPS.russet.grow) + 0.1)
	walk_plot("harvest")
	check(game.tutorial.current_id() == "sell", "real growing and harvesting reaches first sale")
	var path: String = "user://tutorial-barn-%d.json" % OS.get_process_id()
	check(game.state.save_game(path), "save unfinished first sale")
	game._on_action("barn")
	await settle()
	check_crops()
	# A previously open/stale tab must also recover when guide state refreshes.
	game.hud._inventory_tab = "tools"
	game.hud._set_inventory_tab()
	game.tutorial.refresh()
	check_crops()
	# The enabled crop tab gives a direct escape without closing the barn.
	game.hud._inventory_tab = "tools"
	game.hud._set_inventory_tab()
	press("inventory_tab:crops")
	check_crops()
	sell_harvest()
	# Existing saves resume at the sale; no tutorial restart or lost crop.
	check(game.state.load_game(path), "reload unfinished first sale")
	game.hud._inventory_tab = "tools"
	game.tutorial.start()
	check(game.tutorial.current_id() == "sell", "saved guide resumes first sale")
	game._on_action("barn")
	await settle()
	check_crops()
	sell_harvest()
	game.hud.show_panel("barn", game.state)
	press("inventory_tab:tools")
	game.tutorial.start(true)
	game._on_action("barn")
	check(game.hud._inventory_tab == "tools" and not button("inventory_tab:crops").disabled, "optional tour preserves free tab browsing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("TUTORIAL BARN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
