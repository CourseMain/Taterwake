extends SceneTree
## Inventory and ordinary crop sales have no retired item bonuses.
var checks: int = 0
var failures: int = 0
var game
var path: String = "user://item-removal-%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var farm = game.state
	farm.coins = 12345.0
	farm.storage.russet = 195
	var saved: Dictionary = farm._save_data()
	for field: String in ["inventory_items", "equipment", "mutations", "dex", "golden_hat", "shores_first_mutation"]:
		check(not saved.has(field), "new save omits " + field)
	farm.storage.golden = 3
	var quote: float = farm.market.golden.sell
	var balance: float = farm.coins
	farm.sell_crop("golden")
	check(is_equal_approx(farm.coins - balance, 3 * quote), "ordinary crop sales have no item bonus")
	for entry: Dictionary in farm.inventory_info():
		check(entry.kind in ["crop", "seed", "tool"], "inventory entry is a farming supply: " + entry.id)
	game.hud.show_panel("inventory", farm)
	check(game.hud._inventory_sections.keys() == ["crops", "tools"], "Inventory has only crops and tools tabs")
	check(game.hud._body.find_children("*", "SubViewport", true, false).is_empty(), "Inventory has no avatar preview viewport")
	game.hud._act("inventory_tab:tools")
	check(game.hud._inventory_sections.tools.is_visible_in_tree() and not game.hud._inventory_sections.crops.visible, "tool tab switches shelf visibility")
	check(game.hud._refs.has("item:tool:hoe:action"), "tool shelf offers the hoe")
	game.hud._refs["item:tool:hoe:action"].pressed.emit()
	check(game.selected_tool == "hoe", "tool shelf selects a real farming tool")
	game.hud.show_panel("dex", farm)
	check(game.hud._body.find_children("DexPicture_*", "Control", true, false).size() == 6, "crop reference retains all six ordinary varieties")
	for quest: Dictionary in farm.quest_info():
		check(quest.id != "mutation" and not quest.has("item"), "quests retain only cash and seed rewards")
	for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	game.queue_free()
	await process_frame
	print("ITEM REMOVAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
