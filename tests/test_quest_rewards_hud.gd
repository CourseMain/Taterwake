extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle() -> void:
	for i in range(15): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(390,844) if game.touch_controls.enabled else Vector2i(1280,800)
	game.state.coins = 1e18
	game.state.debug_unlock_island(3)
	for island in [1,2,3]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		game.hud.show_panel("quests",game.state)
		await settle()
		var scroll: ScrollContainer = game.hud._body.get_parent()
		check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x+1,"quest rewards fit island %d" % island)
		for quest: Dictionary in game.state.quest_info():
			var card: Control = game.hud._refs["quest:"+quest.id+":card"]
			var cash: Label
			var artifact_visible := str(quest.item).is_empty()
			for label: Node in card.find_children("*","Label",true,false):
				if label.text == game.state.money(quest.coins): cash = label
				if not str(quest.item).is_empty() and label.text == str(game.state.ITEM_CATALOG[quest.item].name): artifact_visible = true
			check(is_instance_valid(cash) and cash.size.x >= 120 and cash.size.y < 80,"cash stays a readable amount: "+quest.id)
			check(artifact_visible,"every advertised artifact appears: "+quest.id)
			var claim: Button = game.hud._refs["quest:"+quest.id]
			scroll.ensure_control_visible(claim)
			await settle()
			check(scroll.get_global_rect().grow(1).encloses(claim.get_global_rect()),"claim reachable: "+quest.id)
	game.queue_free()
	await settle()
	print("QUEST REWARDS HUD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
