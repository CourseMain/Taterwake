extends SceneTree
## Real HUD browsing and saved-selection checks. Uses integration test state only.
const Pages = preload("res://scripts/build_pages.gd")
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
	for _i in range(6): await process_frame
func overview() -> void:
	game.hud._act("build:inspect:")
	await frames()
func labels(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label else ""
	for child in node.get_children(): result += labels(child)
	return result
func capture_pages() -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	var touch: bool = game.touch_controls.enabled
	root.size = Vector2i(390, 844) if touch else Vector2i(1280, 800)
	await frames()
	var folder: String = "res://artifacts/build-polish"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var suffix: String = "390x844-touch" if touch else "1280x800-desktop"
	# This fixture has an unlocked Scientist selected from the saved-state check.
	# It intentionally demonstrates preservation of an existing player's build.
	for page in ["overview", "guide", "help", "farmer", "scientist"]:
		print("BUILD CAPTURE PREPARE: " + page)
		match page:
			"overview": await overview()
			"guide": game.hud._act("build_guide")
			"help": game.hud.show_panel("help", game.state)
			_: game.hud._act("build:inspect:" + page)
		await frames()
		game.hud._toast_box.hide()
		game.hud._purchase_box.hide()
		game.hud._reward_box.hide()
		await create_timer(0.24, true, false, true).timeout
		# A background macOS window can stop its automatic redraws. Force the
		# settled frame instead of awaiting a signal that may never be emitted.
		RenderingServer.force_draw()
		var path: String = folder + "/" + page + "-" + suffix + ".png"
		root.get_texture().get_image().save_png(path)
		print("BUILD CAPTURE: " + path)

func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	create_timer(90, true, false, true).timeout.connect(func(): push_error("Build overview check timed out"); quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_process_unhandled_input(false)
	var b = game.builds
	var farm = game.state
	var h = game.hud
	check(b.active == "farmer" and b.levels.farmer == 1, "a new farm selects the Farmer starter")
	game._interact_station("profession:farmer")
	await frames()
	check(h._panel_kind == "builds" and h._build_selection == "farmer" and h._refs.has("prof_giant") and not h._refs.has("build_overview"), "Compost opens its controls directly instead of the build list")
	check(h._refs.prof_title.text == "Compost · Farmer perk", "compost is briefly identified as a Farmer perk")
	await overview()
	check(h._refs.build_selected_summary.text.contains("Farmer"), "overview marks actual starter selection")
	check(h._refs.build_overview.get_child_count() == 5, "overview contains only the five build cards")
	check(not h._modal_subtitle.visible and not labels(h._body).contains("LEAF "), "overview omits decorative subtitles and page numbers")
	var saved: Dictionary = b.save_data().duplicate(true)
	var coins: float = farm.coins
	for id in Pages.ORDER:
		check(h._refs.has("build_preview:" + id), id + " has an illustrated preview")
		check(h._refs["build_status:" + id].text.contains("Selected" if id == "farmer" else "Lv.1"), id + " has its true selection/unlock state")
		h._refs["build_explore:" + id].pressed.emit()
		await frames()
		check(h._build_selection == id and b.save_data() == saved and farm.coins == coins, id + " browsing changes no gameplay or save state")
		check(h._refs.build_equip.disabled == (id == "farmer"), id + " selection is disabled only while active")
		check(h._refs.has("build_art") and h._refs.build_art.kind == id, id + " detail shows its own appearance")
		if game.touch_controls.enabled:
			check(h._modal_card.size.y <= Pages.content_height(h) + 1, id + " touch panel fits remaining content")
		h._refs["build_details:toggle"].pressed.emit()
		await frames()
		var copy: String = labels(h._refs.build_details)
		check(not copy.contains("How it works") and copy.contains(Pages.BENEFITS[id]) and copy.contains(Pages.TRADEOFFS[id]), id + " retains bonuses and limits without repeated instructions")
		await overview()
	b.levels.scientist = 1
	h._act("build:inspect:scientist")
	await frames()
	check(not h._refs.build_equip.disabled and b.active == "farmer", "unlocked preview leaves Farmer selected")
	check(h._refs.build_equip.text.contains("Free") and h._refs.build_selection_note.text == b.XP_SOURCES.scientist and h._refs.build_equip.tooltip_text.contains("Farmer"), "selection shows its free cost and a brief way to earn XP")
	check(h._refs["build_xp:scientist"].text.contains("0 / 40 XP"), "unlocked build exposes its level and next XP target")
	b.award_xp("scientist", 24)
	h.update_state(farm)
	await frames()
	check(h._refs["build_xp_meter:scientist"].value == 24 and h._refs["build_xp:scientist"].text.contains("24 / 40 XP"), "build XP updates while the detail page remains open")
	h._refs.build_equip.pressed.emit()
	await frames()
	check(b.active == "scientist" and farm.coins == coins, "explicit selection equips Scientist for no fee")
	var chosen: Dictionary = b.save_data().duplicate(true)
	b.reset_builds()
	check(b.load_data(chosen) and b.active == "scientist", "saved active selection reloads unchanged")
	await overview()
	check(h._refs["build_status:scientist"].text.contains("Selected") and not h._refs["build_status:farmer"].text.contains("Selected"), "overview uses saved selection rather than resetting to Farmer")
	var before_compost_visit: Dictionary = b.save_data().duplicate(true)
	game._interact_station("profession:farmer")
	await frames()
	check(h._build_selection == "farmer" and b.save_data() == before_compost_visit, "visiting Compost keeps an existing Scientist selection and its saved progress")
	check(h._refs.prof_giant.disabled and not h._refs.build_equip.disabled and h._refs.prof_status.text.contains("Farmer"), "non-Farmer sees an explicit build selection and reason before using compost")
	h._act("build:inspect:farmer")
	await frames()
	game._on_action("builds")
	await frames()
	check(h._build_selection.is_empty() and h._refs.has("build_overview") and b.active == "scientist", "ordinary Builds entry returns to overview without changing saved selection")
	h._act("build_guide")
	await frames()
	check(h._panel_kind == "builds" and h._build_selection.is_empty(), "legacy guide action returns to builds without reopening help")
	check(b.active == "scientist", "browsing preserves saved selection")
	for dimensions in [Vector2i(1280, 800), Vector2i(960, 600), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await frames()
		await overview()
		var panel: Rect2 = h._modal_card.get_global_rect()
		var width: float = h._refs.build_overview.size.x
		for id in Pages.ORDER:
			var card: Rect2 = h._refs["build_card:" + id].get_global_rect()
			check(card.position.x >= panel.position.x and card.end.x <= panel.end.x, "%s overview stays inside modal at %s" % [id, dimensions])
			check(h._refs["build_explore:" + id].size.x <= width, "%s preview control fits at %s" % [id, dimensions])
		check(b.active == "scientist", "responsive overview never changes selected build")
	await capture_pages()
	game.queue_free()
	await frames()
	print("BUILD OVERVIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
