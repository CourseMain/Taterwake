extends SceneTree
## Revision 22 farms keep their crops when item bonuses retire.
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
	farm.debug_unlock_island(2)
	farm.travel_to(2)
	farm.climate.acknowledge(farm)
	farm.coins = 123456.0
	farm.storage.russet = 195
	farm.quest_progress.ground = 48
	farm.quest_claimed.append("ground")
	var legacy: Dictionary = farm._save_data().duplicate(true)
	legacy.mechanics_revision = 22
	legacy.capacity = 360
	legacy.inventory_items = {"bottomless_sack": 1, "winter_weave": 1, "trader_token": 5, "aurora": 1}
	legacy.equipment = {"head": "aurora_crown", "body": "scientist_coat"}
	legacy.golden_hat = true
	legacy.dex = ["golden", "crystal", "rainbow", "radioactive"]
	legacy.shores_first_mutation = true
	legacy.quest_progress.mutation = 3
	legacy.quest_claimed.append("mutation")
	legacy.mutations = [
		{"id": "golden", "crop": "russet", "count": 2, "multiplier": 25.0},
		{"id": "crystal", "crop": "golden", "count": 3, "multiplier": 75.0},
		{"id": "rainbow", "crop": "sunburst", "count": 4, "multiplier": 250.0},
		{"id": "radioactive", "crop": "radioactive", "count": 5, "multiplier": 1000.0},
		{"id": "golden", "crop": "russet", "count": 1, "multiplier": 25.0},
	]
	legacy.activities.contract = {"kind": "mutation", "crop": "sunburst", "target": 3, "delivered": 1, "credit": 1234.0}
	write_save(legacy)
	check(farm.load_game(path), "revision 22 farm loads after removing item fields")
	check(farm.storage.russet == 198 and farm.storage.golden == 3 and farm.storage.sunburst == 4 and farm.storage.radioactive == 5, "all special batches become plain crops of the same variety and quantity")
	check(farm.capacity == 200 and farm.storage_used() == 210, "retired capacity bonuses disappear without discarding overfull crops")
	check(farm.coins == 123456 and farm.quest_claimed == ["ground"] and farm.quest_progress.ground == 48, "money and surviving quest claims are preserved")
	check(not farm.quest_progress.has("mutation"), "retired quest progress is dropped")
	check(game.activities.contract.kind == "bulk" and game.activities.contract.crop == "sunburst" and game.activities.contract.target == 3 and game.activities.contract.delivered == 1 and game.activities.contract.credit == 1234.0, "old order keeps deliveries and earned credit as an ordinary crop order")
	farm.plots[0].merge({"tilled": true, "stage": 3, "crop": "sunburst", "watered": true, "elapsed": 55.0}, true)
	farm.interact_plot(0, "harvest")
	check(farm.storage_used() == 210 and farm.plots[0].stage == 3, "overfull migrated barn blocks additional harvests")
	check(farm.save_game(path) and farm.load_game(path) and farm.storage_used() == 210, "overfull migrated farm round-trips without converting twice")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.mechanics_revision == 23, "new save records revision 23")
	for field: String in ["inventory_items", "equipment", "mutations", "dex", "golden_hat", "shores_first_mutation"]:
		check(not saved.has(field), "new save omits " + field)
	check(farm.capacity == 200, "reload cannot restore a removed capacity bonus")
	var quote: float = farm.market.sunburst.sell
	game.activities.deliver_contract()
	check(game.activities.contract.is_empty() and farm.storage.sunburst == 2, "converted order consumes only its remaining ordinary crops")
	check(is_equal_approx(farm.coins, 123456 + 1234 + quote * 2 * 1.25), "converted order pays prior credit and ordinary future shipments exactly once")
	var balance: float = farm.coins
	var crop_quote: float = farm.market.golden.sell
	farm.sell_crop("golden")
	check(is_equal_approx(farm.coins - balance, 3 * crop_quote), "converted crop sells at its ordinary quote without rarity multipliers")
	for bad_batch: Variant in [null, {}, {"crop":"unknown", "count":1}, {"crop":"russet", "count":-1}, {"crop":"russet", "count":1.5}, {"crop":"russet", "count":farm.MAX_INVENTORY}]:
		var bad: Dictionary = legacy.duplicate(true)
		bad.mutations = [bad_batch]
		check(not farm._valid_save(bad), "invalid legacy crop batch is rejected: " + str(bad_batch))
	var bad: Dictionary = legacy.duplicate(true)
	bad.mutations = "broken"
	check(not farm._valid_save(bad), "non-array legacy storage cannot be silently lost")
	write_save(bad)
	var live_storage: Dictionary = farm.storage.duplicate()
	check(not farm.load_game(path) and farm.storage == live_storage and FileAccess.file_exists(path + ".rejected"), "invalid migration preserves live state and sets aside its file")
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
