extends SceneTree
## Isolated, real-scene readiness and small-screen regression checks.
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func frames() -> void:
	for _i in range(5): await process_frame
func show_build(id: String) -> void:
	game.hud._act("build:inspect:" + id)
	await frames()
func refresh() -> void:
	game.hud.update_state(game.state)
	await frames()
func capture(id: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game.hud._toast_box.hide()
	game.hud._purchase_box.hide()
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/build-clarity-" + id + ".png")
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	var farm = game.state
	var builds = game.builds
	var p = builds.professions
	for id in builds.IDS: builds.levels[id] = 1
	for crop in farm.CROP_IDS: farm.storage[crop] = 0
	farm.selected_crop = "russet"
	for plot in farm.plots: farm._clear_crop(plot)
	await show_build("farmer")
	check(game.hud._refs.prof_giant.disabled and game.hud._refs.prof_status.text.contains("Plant a seed"), "empty farm explains planting before compost")
	check(game.hud._refs.prof_giant.text == "Grow a giant potato · 1 compost", "Farmer states its result and cost without prize-bed jargon")
	check(game.hud._refs.prof_prepare.visible and game.hud._refs.prof_prepare.get_meta("tool") == "plant", "empty farm offers a direct planting shortcut")
	game.hud._refs.prof_prepare.pressed.emit()
	check(not game.hud.is_panel_open() and game.selected_tool == "plant", "planting shortcut closes the detail and equips the seed tool")
	farm.plots[0].merge({"unlocked": true, "stage": 3, "crop": "russet", "watered": true}, true)
	await show_build("farmer")
	check(game.hud._refs.prof_prepare.get_meta("tool") == "harvest" and game.hud._refs.prof_status.text.contains("Harvest a ripe"), "ripe-only field explains harvesting before replanting")
	farm.plots[0].merge({"stage": 2, "frozen": true}, true)
	await refresh()
	check(game.hud._refs.prof_prepare.get_meta("tool") == "hoe" and game.hud._refs.prof_status.text.contains("Clear the ice"), "frozen growing crop offers the hoe instead of misleading planting advice")
	farm.plots[0].frozen = false
	farm.plots[0].merge({"unlocked": true, "tilled": true, "stage": 1, "crop": "russet", "watered": false}, true)
	await refresh()
	check(not game.hud._refs.prof_giant.disabled and game.hud._refs.prof_resource.text.contains("1 growing crop"), "a real growing crop enables the world selection action")
	p.data.compost = 0
	await refresh()
	check(game.hud._refs.prof_giant.disabled and game.hud._refs.prof_status.text.contains("earn 1 compost"), "missing compost explains where to get it")
	p.data.compost = 3
	await refresh()
	await show_build("farmer")
	check(game.hud._modal_card.size.y < 550, "Farmer detail fits its short content without a tall empty panel")
	await capture("farmer")
	builds.select_build("industrialist")
	p.data.method = "cure"
	farm.storage.russet = 19
	await show_build("industrialist")
	check(game.hud._refs.prof_load.disabled and game.hud._refs.prof_status.text.contains("1 more Russet"), "processor explains the exact missing crop count")
	farm.storage.russet = 20
	await refresh()
	check(not game.hud._refs.prof_load.disabled and game.hud._refs.prof_resource.text.contains("grade"), "load preview includes real grade and cost")
	var load_position: Vector2 = game.hud._refs.prof_load.global_position
	game.hud._refs.prof_load.pressed.emit()
	await refresh()
	check(builds.processing.quantity == 20 and game.hud._refs.prof_load.disabled and game.hud._refs.prof_status.text.contains("Queue full"), "loaded batch exposes queue readiness instead of silent disabled control")
	check(game.hud._refs.prof_progress.visible and game.hud._refs.prof_job.text.contains("20 Russet"), "current job is distinct from the next grade preview")
	var processor_scroll: ScrollContainer = game.hud._body.get_parent()
	check(processor_scroll.get_global_rect().grow(1).encloses(game.hud._refs["build_details:toggle"].get_global_rect()), "Industrialist bonuses toggle stays fully visible immediately after its first load")
	check(game.hud._refs.prof_load.global_position.is_equal_approx(load_position), "loading the first batch preserves the button position")
	await capture("industrialist-processing")
	builds.processing.erase("grade")
	await refresh()
	check(game.hud._refs.prof_job.text.contains("Legacy"), "migrated processing jobs without grade keep readable progress")
	builds.update(10)
	builds.select_build("farmer")
	await refresh()
	check(game.hud._refs.prof_sell.visible and not game.hud._refs.prof_sell.disabled, "finished graded goods remain sellable after changing build")
	await capture("industrialist")
	builds.select_build("scientist")
	farm.storage.russet = 8
	farm.storage.golden = 7
	await show_build("scientist")
	check(game.hud._refs.prof_breed.disabled and game.hud._refs.prof_status.text.contains("2 Russet") and game.hud._refs.prof_status.text.contains("3 Golden"), "crossbreeding names both resource deficits")
	farm.storage.russet = 10
	farm.storage.golden = 10
	await refresh()
	game.hud._refs.prof_breed.pressed.emit()
	await refresh()
	check(p.data.seedbank == ["hearty"] and farm.storage.russet == 0 and farm.storage.golden == 0, "crossbreed button spends its exact displayed harvest ingredients")
	check(game.hud._refs.prof_breed.disabled and game.hud._refs.prof_breed.text == "Already discovered" and game.hud._refs.prof_resource.text.contains("permanent planting trait"), "discovery is an enduring trait rather than an implied stack of seeds")
	var scroll: ScrollContainer = game.hud._body.get_parent()
	check(scroll.get_global_rect().grow(1).encloses(game.hud._refs["build_details:toggle"].get_global_rect()), "Scientist base card and bonuses toggle fit without scrolling at 1280×800")
	await capture("scientist")
	builds.select_build("investor")
	await show_build("investor")
	var quote: Dictionary = p.contract_preview()
	check(game.hud._refs.prof_resource.text.contains(farm.money(quote.total)) and game.hud._refs.prof_status.text.contains("No upfront cost"), "buyer preview discloses actual payout and no upfront crop requirement")
	game.hud._refs.prof_reserve.pressed.emit()
	await refresh()
	check(not game.hud._refs.prof_inputs.visible and game.hud._refs.prof_deliver.disabled and game.hud._refs.prof_status.text.contains("20 more Russet"), "locked buyer hides irrelevant crop selection and explains delivery shortfall")
	farm.storage.russet = 20
	await refresh()
	var before: float = farm.coins
	game.hud._refs.prof_deliver.pressed.emit()
	await refresh()
	check(is_equal_approx(farm.coins - before, float(quote.total)) and p.data.contract.is_empty(), "delivery action pays its disclosed locked price")
	await capture("investor")
	builds.select_build("gambler")
	await show_build("gambler")
	check(game.hud._refs.prof_stake.disabled and game.hud._refs.prof_status.text.contains("20 more Russet"), "stake explains exact missing harvest")
	farm.storage.russet = 20
	await refresh()
	check(game.hud._refs.prof_note.text.contains("half") and game.hud._refs.prof_note.text.contains("coins"), "stake names its possible loss and payout currency before committing")
	game.hud._refs.prof_stake.pressed.emit()
	await refresh()
	check(farm.storage.russet == 0 and not game.hud._refs.prof_inputs.visible and game.hud._refs.prof_claim.visible, "pending stake shows claim controls instead of irrelevant new-stake choices")
	game.hud._refs.prof_reroll.pressed.emit()
	await refresh()
	check(game.hud._refs.prof_reroll.disabled and game.hud._refs.prof_note.text.contains("one reroll"), "used charm explains the per-stake limit")
	builds.select_build("farmer")
	await refresh()
	check(not game.hud._refs.prof_claim.disabled, "claim remains available after switching professions")
	await capture("gambler")
	# Every visible choice fits within the modal and the story keeps its proportions.
	for dimensions in [Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		await frames()
		for id in builds.IDS:
			await show_build(id)
			var panel: Rect2 = game.hud._modal_card.get_global_rect().grow(1)
			var art = game.hud._refs.build_art
			check(panel.encloses(art.get_global_rect()) and art.canvas_origin().x >= 0 and art.canvas_origin().y >= 0, "%s story is contained at %s" % [id, dimensions])
			for key in ["crop", "batch", "method", "recipe", "variety", "stake_size"]:
				if not game.hud._refs.has("prof_" + key): continue
				var option: OptionButton = game.hud._refs["prof_" + key]
				if not option.is_visible_in_tree(): continue
				var rect: Rect2 = option.get_global_rect()
				check(rect.position.x >= panel.position.x and rect.end.x <= panel.end.x, "%s choice fits horizontally at %s" % [key, dimensions])
			check(not game.hud._refs.build_details.visible, "technical details stay optional for " + id)
		if dimensions == Vector2i(960, 600): await capture("small-screen")
	game.queue_free()
	await frames()
	print("PROFESSION CLARITY UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
