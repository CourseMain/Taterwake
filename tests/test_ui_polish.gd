extends SceneTree
## Exercise live card states and layout without loading or writing player saves.
var game
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for _frame: int in range(5): await process_frame

func inspect(label: String) -> void:
	game.hud.update_state(game.state)
	game.hud._toast_box.hide()
	game.hud._reward_box.hide()
	game.hud._purchase_box.hide()
	await settle()
	var scroll: ScrollContainer = game.hud._body.get_parent()
	check(game.hud._body.get_combined_minimum_size().x <= scroll.size.x + 0.5, label + " fits without horizontal scrolling")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	check(game.hud._body.size.x <= scroll.size.x - (bar.size.x if bar.visible else 0.0) + 0.5, label + " cards clear the scrollbar")
	check(game.hud.root.get_global_rect().encloses(game.hud._modal_card.get_global_rect()), label + " keeps the modal inside the game")
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/ui-" + label + ".png") == OK, "capture " + label)

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.hud.set_process(false)
	game.state.coins = 48000
	game.state.quest_progress.starter_crash = 10
	game.state.quest_progress.starter_spike = 4
	game.hud.show_panel("quests", game.state)
	check(game.hud._refs["quest:starter_crash:status"].text == "Claim ready", "completed quest visibly awaits collection")
	check(game.hud._refs["quest:starter_spike:bar"].value == 4 and not game.hud._refs["quest:starter_spike"].visible, "partial progress cannot claim a reward")
	await inspect("quests")
	var before: float = game.state.coins
	game.hud._refs["quest:starter_crash"].pressed.emit()
	check(game.state.coins == before + game.state.QUEST_REWARD and game.hud._refs["quest:starter_crash:status"].text == "Claimed", "claim pays once and updates its status")
	check(game.hud._refs["quest:starter_crash"].disabled, "claimed quest cannot pay twice")
	game.state.coins = game.state.bankruptcy_limit()
	game.hud.show_panel("duck_patrol", game.state)
	check(game.hud._refs["activity:duck"].disabled and game.hud._refs["activity:duck:status"].text.begins_with("Need"), "unaffordable duck shows the missing coins")
	check(game.hud._refs["activity:duck:speed:status"].text.begins_with("Locked"), "speed training explains the flock prerequisite")
	await inspect("ducks-locked")
	game.state.coins = 400000000
	game.hud.update_state(game.state)
	game.hud._refs["activity:duck"].pressed.emit()
	check(game.activities.duck_count() == 1 and game.hud._refs["activity:duck:status"].text == "Affordable", "hiring refreshes the remaining flock slot")
	check(game.hud._refs["activity:duck:speed:status"].text == "Affordable", "hiring unlocks affordable speed training")
	game.hud._refs["activity:duck:speed"].pressed.emit()
	check(game.hud._refs["activity:duck:speed:value"].text.begins_with("3s → 2s"), "training advances the current-to-next value")
	await inspect("ducks-trained")
	game.hud.show_panel("inventory", game.state)
	game.hud._act("inventory_tab:tools")
	await inspect("tools")
	root.size = Vector2i(960, 600)
	for kind: String in ["quests", "duck_patrol", "inventory"]:
		game.hud.show_panel(kind, game.state)
		await inspect("compact-" + kind)
	for island in [1]:
		game.hud.show_panel("quests", game.state)
		await inspect("island-%d-quests" % island)
		for quest: Dictionary in game.state.quest_info():
			game.state.quest_progress[quest.id] = quest.target
		game.hud.update_state(game.state)
		var first: String = "quest:" + str(game.state.quest_info()[0].id)
		game.hud._refs[first].pressed.emit()
		check(game.hud._refs[first + ":status"].text == "Claimed", "island %d quest remains claimable after acknowledging arrival" % island)
		game.hud.show_panel("market", game.state)
		await inspect("island-%d-seeds" % island)
		game.hud.show_panel("island", game.state)
		var travel_scroll: ScrollContainer = game.hud._body.get_parent()
		await settle()
		travel_scroll.scroll_vertical = int(travel_scroll.get_v_scroll_bar().max_value)
		await inspect("island-%d-destinations" % island)
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("UI POLISH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func scroll_rect() -> Rect2:
	return game.hud._body.get_parent().get_global_rect()
