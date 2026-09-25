extends SceneTree
const Roster = preload("res://scripts/npc_roster.gd")
const SAVE := "user://taterland_npc_dialogue_test_only.json"
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames() -> void:
	for i in range(8): await process_frame
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.debug_unlock_island(3)
	farm.climate.acknowledge(farm)
	farm.coins = 1e18
	var talk = game.conversation
	var looks: Array = []
	for id: String in Roster.PEOPLE:
		farm.travel_to(3 if id == "oren" else 2)
		farm.climate.acknowledge(farm)
		farm.climate.data.phase = "calm"
		var service: String = Roster.PEOPLE[id].service
		game._on_user_action(service)
		check(talk.visible and talk.npc_id == id,"conversation before service at " + service)
		await frames()
		check(talk.visible and game.hud.is_panel_open(),"conversation is modal " + id)
		check(not game.hud._modal.visible,"no stacked shop " + id)
		check(game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"only portrait renders while talking")
		check(talk.title.text == Roster.PEOPLE[id].name,"named portrait " + id)
		check(talk.speech.text == Roster.PEOPLE[id].first,"first introduction " + id)
		check(farm.npc_history[id].visits == 1,"remembers meeting " + id)
		check(talk.portrait.avatar.npc_id == id,"matching character model " + id)
		var signature: String = str(talk.portrait.avatar.scale)+str(talk.portrait.avatar.skin_color)+Roster.PEOPLE[id].detail
		check(not looks.has(signature),"distinct appearance " + id)
		looks.append(signature)
		var before: String = JSON.stringify(farm._save_data())
		var position: Vector3 = game.world.player.position
		game._process(20)
		check(JSON.stringify(farm._save_data()) == before,"all farm clocks paused " + id)
		check(game.world.player.position == position,"player stays still " + id)
		game._on_action("quick_sell")
		check(JSON.stringify(farm._save_data()) == before,"no background transactions " + id)
		talk.choose(1)
		check(talk.speech.text == Roster.PEOPLE[id].story,"personal topic " + id)
		talk.choose(0)
		check(talk.speech.text == Roster.PEOPLE[id].answer and farm.npc_history[id].kind,"choice gets personal response " + id)
		talk.choose(0)
		check(talk.speech.text == Roster.PEOPLE[id].advice,"practical branch " + id)
		talk.portrait.avatar.speaking = true
		talk.portrait.avatar.animate(.1)
		var mouth_scale: Vector3 = talk.portrait.avatar.talk_mouth.scale
		talk.portrait.avatar.animate(.04)
		check(talk.portrait.avatar.talk_mouth.visible and talk.portrait.avatar.talk_mouth.scale != mouth_scale,"animated speech " + id)
		check(talk.portrait.avatar.talk_mouth.scale.x < .1 and talk.portrait.avatar.talk_mouth.scale.y < .06,"talking mouth stays within the face")
		talk.reveal()
		for i in range(20): talk.portrait.avatar.animate(.1)
		check(not talk.portrait.avatar.talk_mouth.visible and talk.portrait.avatar._mouth.visible,"returns to listening " + id)
		talk.choose(0)
		await frames()
		check(not talk.visible and game.hud._panel_kind == service,"returns to service without spending " + id)
		check(talk.portrait.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden portrait stops rendering " + id)
		game._on_action("talk:" + id)
		check(talk.speech.text == Roster.PEOPLE[id].thanks,"remembers friendly response " + id)
		var previous: String = talk.speech.text
		talk.finish()
		game._start_conversation(id)
		check(talk.speech.text != previous,"no consecutive repeated greeting " + id)
		talk.finish()
	for island in [1,2,3]:
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
		var cast: Array = []
		for actor in game.world._villagers: cast.append(actor.npc_id)
		check("mara" in cast and "nell" in cast and "rook" in cast,"world residents keep distinct identities on island " + str(island))
		for pair in [["mara","MarketStall"],["nell","RedBarn"],["rook","RollHouse"],["ada","WashAndSortWorkshop"],["pip","DuckPatrolHouse"],["tess","FarmingQuestBoard"]]:
			check(str(game.world._npc_actors[pair[0]].get_parent().name) == ("BuyerContracts" if pair[0] == "tess" and island == 2 else pair[1]),"stallholder at their service: " + pair[0])
		check(game.world._npc_actors.mara.position.z > .15,"seed vendor stands in front of awning")
	game.hud.close_panel()
	game.world.player.position = game.world.ferry_position()
	game._interact_nearby()
	check(talk.visible and talk.npc_id == "hollis", "nearby ferry action greets captain first")
	talk.choose(0)
	check(game.hud._panel_kind == "island", "captain opens crossings")
	game.hud.close_panel()
	game._climate_action("open_furnace")
	check(talk.visible and talk.npc_id == "oren", "freeze shortcut greets furnace keeper")
	talk.finish()
	farm.travel_to(2)
	farm.climate.data.intro_pending = true
	game._on_action("climate_continue")
	check(talk.visible and talk.npc_id == "iris", "sky introduction leads to Iris before weather service")
	talk.choose(0)
	check(game.hud._panel_kind == "climate", "Iris opens weather and protection")
	game.hud.close_panel()
	check(farm.save_game(SAVE),"save NPC memories")
	var remembered: Dictionary = farm.npc_history.duplicate(true)
	farm.npc_history.clear()
	check(farm.load_game(SAVE),"load farm with NPC memories")
	check(farm.npc_history == remembered,"memories survive reload")
	var old_save: Dictionary = farm._save_data()
	old_save.erase("npc_history")
	check(farm._valid_save(old_save),"old saves remain compatible")
	for bad in [[],{"mara":true},{"unknown":{"visits":1,"last":"hi","kind":true}},{"mara":{"visits":-1,"last":"hi","kind":true}},{"mara":{"visits":1,"last":false,"kind":true}}]:
		check(not Roster.valid_history(bad),"invalid memory rejected")
	farm.travel_to(3)
	farm.climate.acknowledge(farm)
	farm.climate.data.phase = "calm"
	farm.climate.begin_warning(farm,"freeze",1)
	game._on_action("activities")
	game._on_action("talk:oren")
	talk.choose(2)
	check(talk.speech.text.contains("Heat your hoe") and talk.speech.text.contains("free"),"weather choice gives local freeze guidance")
	var remaining: float = farm.climate.data.timer
	game._process(12)
	check(farm.climate.data.timer == remaining,"weather warning waits while talking")
	# All choices and portrait fit desktop, phone and tablet logical sizes.
	for viewport_size in [Vector2i(1280,800),Vector2i(600,1298),Vector2i(1298,600),Vector2i(768,1024),Vector2i(1024,768)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		talk._touch = viewport_size != Vector2i(1280,800)
		await frames()
		talk.layout()
		talk.reveal()
		await frames()
		var screen := Rect2(Vector2.ZERO,Vector2(viewport_size))
		check(screen.encloses(talk.card.get_global_rect()),"dialogue frame in viewport " + str(viewport_size))
		check(screen.encloses(talk.close_button.get_global_rect()),"exit remains reachable " + str(viewport_size))
		check(not talk.close_button.get_global_rect().intersects(talk.text_card.get_global_rect()),"leave button does not overlap text card")
		check(not talk.portrait.get_global_rect().intersects(talk.text_card.get_global_rect()),"portrait and text separate " + str(viewport_size))
		for b in talk.choice_buttons:
			check(b.size.y >= (68 if talk._touch else 48),"accessible choice height")
			check(b.size.x <= talk.scroll.size.x,"choices wrap within panel")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	talk._input(escape)
	check(not talk.visible and not game.hud.is_panel_open(),"Escape leaves dialogue")
	game._process(.1)
	check(farm.climate.data.timer < remaining,"simulation resumes afterwards")
	game.hud.close_panel()
	farm.travel_to(1)
	game._start_conversation("oren")
	check(not talk.visible,"winter keeper unavailable outside winter")
	game._start_conversation("iris")
	check(not talk.visible,"radio observer unavailable before station")
	farm.reset_game()
	check(farm.npc_history.is_empty(),"new farm resets introductions")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("NPC CONVERSATIONS: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames()
	quit(1 if failures else 0)
