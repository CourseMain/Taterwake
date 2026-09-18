extends SceneTree
## Purchase feedback survives an open exchange; each island's duck station stays separate.
const State = preload("res://scripts/game_state.gd")
const Activities = preload("res://scripts/island_activities.gd")
const HUD = preload("res://scripts/game_hud.gd")
var checks: int = 0
var failures: int = 0
var state
var activities
var hud

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func ignores_mouse(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not ignores_mouse(child):
			return false
	return true

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "render " + name)

func run() -> void:
	state = State.new()
	activities = Activities.new()
	activities.setup(state)
	state.activity_system = activities
	root.add_child(state)
	root.add_child(activities)
	hud = HUD.new()
	root.add_child(hud)
	hud.update_state(state)
	hud.set_process(false)
	state.coins = 1e16
	state.island2_unlocked = true
	state.island3_unlocked = true
	hud.show_panel("market", state)
	hud.show_purchase({"kind": "seeds", "id": "russet", "name": "Russet", "quantity": 5, "cost": 100.0, "total": 17})
	await process_frame
	await process_frame
	check(hud._purchase_box.is_visible_in_tree() and hud.is_panel_open(), "purchase appears while exchange remains open")
	check(hud._purchase_title.text == "+5 Russet seeds" and hud._purchase_detail.text == "Owned 17 · −$100", "receipt shows exact bought seeds, new total and actual spend")
	check(hud._purchase_box.z_index > hud._modal.z_index, "receipt renders above modal shade")
	check(not hud._purchase_box.get_global_rect().intersects(hud._modal_card.get_global_rect()), "receipt leaves modal and its purchase buttons unobscured")
	check(ignores_mouse(hud._purchase_box), "receipt and every child pass mouse input through")
	hud._process(1.0)
	check(is_equal_approx(hud._purchase_bar.value, 2.2), "receipt countdown drains in real gameplay time")
	hud.show_purchase({"kind": "seeds", "id": "russet", "name": "Russet", "quantity": 10, "cost": 240.0, "total": 27})
	check(hud._purchase_title.text == "+15 Russet seeds" and hud._purchase_detail.text == "Owned 27 · −$340", "rapid same-crop purchases aggregate quantities and actual changing prices, retaining latest owned total")
	check(hud._purchase_remaining == HUD.PURCHASE_SECONDS, "new purchase renews receipt lifetime")
	hud.show_panel("inventory", state)
	check(hud._purchase_box.is_visible_in_tree() and hud._purchase_box.z_index > hud._modal.z_index, "switching modal cannot bury a live receipt")
	hud.show_panel("market", state)
	await capture("purchase-seeds")
	hud.show_purchase({"kind": "seeds", "id": "radioactive", "name": "Radioactive", "quantity": 12500, "cost": 125000000.0, "total": 12506})
	await process_frame
	check(hud._purchase_title.text == "+12500 Radioactive seeds" and hud._purchase_detail.text.begins_with("Owned 12506"), "different seed replaces receipt and large quantities stay exact")
	check(hud._purchase_box.size.x == 230 and hud._purchase_box.get_global_rect().end.x <= 1280, "long seed receipt retains its clear right-margin width")
	await capture("purchase-receipt-long")
	hud.show_purchase({"kind": "seeds", "id": "radioactive", "name": "Radioactive", "quantity": 0, "cost": 0.0, "total": 12506})
	check(hud._purchase_title.text == "+12500 Radioactive seeds", "zero-quantity failure cannot fabricate a success receipt")
	hud._process(HUD.PURCHASE_SECONDS + 0.1)
	check(not hud._purchase_box.visible and hud._purchase_receipt.is_empty(), "receipt disappears and clears aggregation after its short lifetime")
	hud.show_purchase({"kind": "seeds", "id": "radioactive", "name": "Radioactive", "quantity": 5, "cost": 1000.0, "total": 12511})
	check(hud._purchase_title.text == "+5 Radioactive seeds", "later purchase starts a fresh quantity after expiry")
	hud.show_purchase({"kind": "tool", "id": "water", "name": "Watering can", "quantity": 1, "cost": 450.0, "level": 2})
	check(hud._purchase_title.text == "Watering can" and hud._purchase_detail.text == "Level 2 · −$450", "tool purchase replaces seeds with actual upgrade level and cost")
	hud.show_purchase({"kind": "barn", "id": "barn", "name": "Barn space", "quantity": 200, "cost": 800.0, "total": 300, "level": 2})
	check(hud._purchase_title.text == "+200 barn spaces" and hud._purchase_detail.text == "Capacity 300 · −$800", "barn receipt identifies exact added spaces and resulting capacity")
	hud.show_purchase({"kind": "service", "id": "scouting", "name": "Roll scouting", "quantity": 1, "cost": 1500.0})
	check(hud._purchase_title.text == "Roll scouting" and hud._purchase_detail.text == "Purchased · −$1.5K", "paid build service uses the same purchase feedback")
	hud._process(HUD.PURCHASE_SECONDS + 0.1)
	state.combo_time = 2.0
	hud.update_state(state)
	check(hud._combo_box.visible, "harvest chain becomes visible again after purchase feedback ends")
	for island: int in [1, 2, 3]:
		state.current_island = island
		hud.update_state(state)
		hud.show_panel("duck_patrol", state)
		check(hud._modal_title.text == "Duck patrol" and hud._refs.has("activity:duck"), "island %d duck station opens dedicated patrol controls" % island)
		check(not hud._refs.has("activity:contract:bulk") and not hud._refs.has("activity:furnace:icecap"), "island %d duck controls contain no unrelated buyer or furnace" % island)
		check(hud._refs["activity:duck:detail"].text.begins_with("%d duck" % island), "island %d patrol describes the correct flock size" % island)
		if island == 2:
			await capture("purchase-ducks-island2")
		activities.duck_level = 3
		hud.update_state(state)
		check(hud._refs["activity:duck"].disabled and hud._refs["activity:duck"].text == "Fully trained", "island %d patrol refresh safely shows fully trained flock" % island)
		activities.duck_level = 0
		hud.show_panel("activities", state)
		if island == 1:
			check(hud._refs.has("activity:duck"), "first island activity alias preserves the duck patrol entry")
		else:
			check(not hud._refs.has("activity:duck"), "island %d buyer/furnace does not embed duck controls" % island)
			check(hud._refs.has("activity:contract:bulk" if island == 2 else "activity:furnace:icecap"), "island %d unique activity still opens its own controls" % island)
		hud.show_panel("pause", state)
		var duck_entries: int = 0
		for button: Node in hud._body.find_children("*", "Button", true, false):
			if str(button.get_meta("action", "")) == ("activities" if island == 1 else "duck_patrol"):
				duck_entries += 1
		check(duck_entries == 1, "island %d menu offers exactly one duck patrol entry" % island)
	state.current_island = 2
	hud.show_panel("activities", state)
	state.current_island = 3
	hud.update_state(state)
	check(hud._refs.has("activity:furnace:icecap") and not hud._refs.has("activity:contract:bulk"), "travel refresh rebuilds activity controls instead of retaining buyer references")
	hud.queue_free()
	activities.queue_free()
	state.queue_free()
	await process_frame
	print("PURCHASE + PATROL HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
