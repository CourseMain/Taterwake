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
	game.state.coins = 1200
	game.builds.levels.investor = 2
	game.hud._build_selection = "farmer"
	game.hud.show_panel("builds", game.state)
	check(game.hud._refs.build_equip.text.begins_with("Equipped") and game.hud._refs.build_equip.disabled, "active profession is identified on its detail page")
	game.hud._act("build:inspect:scientist")
	check(game.hud._refs.build_equip.disabled, "locked build cannot be selected")
	game.hud._act("build:inspect:investor")
	check(game.hud._refs.build_equip.text == "Equip · Lv.2" and not game.hud._refs.build_equip.disabled, "owned profession can be equipped from its detail page")
	await inspect("builds")
	game.hud._refs.build_equip.pressed.emit()
	check(game.builds.active == "investor" and game.hud._refs.build_equip.text.begins_with("Equipped"), "selecting a build refreshes the live card states")
	game.state.quest_progress.starter_crash = 10
	game.state.quest_progress.starter_spike = 4
	game.hud.show_panel("quests", game.state)
	check(game.hud._refs["quest:starter_crash:status"].text == "Claim ready", "completed quest visibly awaits collection")
	check(game.hud._refs["quest:starter_spike:bar"].value == 4 and not game.hud._refs["quest:starter_spike"].visible, "partial progress cannot claim a reward")
	await inspect("quests")
	var before: float = game.state.coins
	game.hud._refs["quest:starter_crash"].pressed.emit()
	check(game.state.coins == before + 750 and game.hud._refs["quest:starter_crash:status"].text == "Claimed", "claim pays once and updates its status")
	check(game.hud._refs["quest:starter_crash"].disabled, "claimed quest cannot pay twice")
	game.hud.show_panel("tracked_prices", game.state)
	game.hud._refs["tracked:golden:toggle"].button_pressed = false
	check(not "golden" in game.state.tracked_seeds and game.hud._refs["tracked:golden:toggle"].text == "Track", "switch updates saved tracking and row immediately")
	game.state.market.russet.seed = 321
	game.hud.update_state(game.state)
	check(game.hud._refs["tracked:russet:quote"].text.contains("321"), "seed quote follows current market price")
	await inspect("tracked-seeds")
	game.state.coins = 0
	game.hud.show_panel("duck_patrol", game.state)
	check(game.hud._refs["activity:duck"].disabled and game.hud._refs["activity:duck:status"].text.begins_with("Need"), "unaffordable duck shows the missing coins")
	check(game.hud._refs["activity:duck:speed:status"].text.begins_with("Locked"), "speed training explains the flock prerequisite")
	await inspect("ducks-locked")
	game.state.coins = 1e7
	game.hud.update_state(game.state)
	game.hud._refs["activity:duck"].pressed.emit()
	check(game.activities.duck_count() == 1 and game.hud._refs["activity:duck:status"].text == "Complete", "hiring refreshes the full flock state")
	check(game.hud._refs["activity:duck:speed:status"].text == "Affordable", "hiring unlocks affordable speed training")
	game.hud._refs["activity:duck:speed"].pressed.emit()
	check(game.hud._refs["activity:duck:speed:value"].text.begins_with("3s → 2s"), "training advances the current-to-next value")
	await inspect("ducks-trained")
	game.state.coins = 500000
	game.state.mastery.russet = 250
	game.hud.show_panel("island", game.state)
	check(game.hud._refs["travel:2:harvest:bar"].value == 50 and game.hud._refs["travel:2:coins:bar"].value == 50, "passage shows independent harvest and money progress")
	check(game.hud._refs.island_unlock.disabled and game.hud._refs.island3_unlock.disabled, "incomplete passage requirements keep both destinations locked")
	await inspect("islands")
	game.state.mastery.russet = 500
	game.state.coins = 1e6
	game.hud.update_state(game.state)
	game.hud._refs.island_unlock.pressed.emit()
	check(game.state.island2_unlocked and not game.hud._refs["travel:2:unlock"].visible and not game.hud._refs["travel:2"].disabled, "unlock replaces requirements with an available travel action")
	game.hud.show_panel("inventory", game.state)
	game.hud._act("inventory_tab:gear")
	await inspect("empty-loadout")
	for item: String in ["straw_hat", "farmer_shirt", "farmer_pants", "farmer_boots", "harvest_gloves", "market_monocle", "investor_shirt", "scientist_coat", "aurora_crown"]:
		game.state._grant_item(item)
	game.builds.active = "farmer"
	game.hud.show_panel("inventory", game.state)
	game.hud._act("inventory_tab:gear")
	check(game.hud._refs.equipment_matching.text.contains("3 matching"), "summary counts matching equipped pieces")
	await inspect("loadout")
	check(scroll_rect().encloses(game.hud._refs.equipment_totals.get_global_rect()), "gear totals are visible beside the character without scrolling")
	game.hud._refs["item:investor_shirt:action"].pressed.emit()
	check(game.hud._refs.equipment_matching.text.contains("2 matching") and game.hud._refs["item:investor_shirt:status"].text == "Equipped", "gear card action refreshes both loadout summary and owned cards")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	await settle()
	scroll.scroll_vertical = 510
	await inspect("owned-gear")
	root.size = Vector2i(960, 600)
	for kind: String in ["builds", "quests", "tracked_prices", "duck_patrol", "inventory", "island"]:
		game.hud.show_panel(kind, game.state)
		await inspect("compact-" + kind)
	game.state.island3_unlocked = true
	for island: int in [2, 3]:
		game.state.travel_to(island)
		game.state.climate.acknowledge(game.state)
		game.hud.show_panel("quests", game.state)
		await inspect("island-%d-quests" % island)
		for quest: Dictionary in game.state.quest_info():
			game.state.quest_progress[quest.id] = quest.target
		game.hud.update_state(game.state)
		var first: String = "quest:" + str(game.state.quest_info()[0].id)
		game.hud._refs[first].pressed.emit()
		check(game.hud._refs[first + ":status"].text == "Claimed", "island %d quest remains claimable after acknowledging arrival" % island)
		game.hud.show_panel("tracked_prices", game.state)
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
