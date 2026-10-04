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
	game.set_process(false)
	game.state.rng.seed = 6
	await frames()
	var farm = game.state
	farm.tutorial_progress.completed = true
	farm.coins = 4000000
	var talk = game.conversation
	for clip in talk.voice.CLIPS:
		check(clip.get_length() >= .15 and clip.get_length() <= 1.0, "potato takes are short, nonempty audio clips")
	var looks: Array = []
	for id: String in Roster.PEOPLE:
		farm.climate.data.phase = "calm"
		if id == "edwin": farm.coins = farm.bankruptcy_limit() * 0.5 - 1
		var expected_greeting: String = Roster.greeting(id, farm)
		var service: String = Roster.PEOPLE[id].service
		game._on_user_action("talk:edwin" if id == "edwin" else service)
		check(talk.visible and talk.npc_id == id,"conversation before service at " + service)
		await frames()
		check(talk.visible and game.hud.is_panel_open(),"conversation is modal " + id)
		check(not game.hud._modal.visible,"no stacked shop " + id)
		check(game.farm_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,"farm keeps rendering behind the keeper")
		check(talk.title.text == Roster.PEOPLE[id].name,"named portrait " + id)
		check(talk.speech.text == expected_greeting,"first introduction " + id)
		check(farm.npc_history[id].visits == 1,"remembers meeting " + id)
		check(talk.portrait.avatar.npc_id == id,"matching character model " + id)
		check(talk.portrait.get_index() > talk.card.get_index(), "portrait draws above the dialogue background " + id)
		check(talk.voice.PROFILES.has(id) and talk.voice.speaker == id and talk.voice.utterances > 0, "character voice starts with the dialogue " + id)
		check(talk.voice.player.stream in talk.voice.CLIPS, "dialogue uses a potato voice clip " + id)
		var signature: String = str(talk.portrait.avatar.scale)+str(talk.portrait.avatar.skin_color)+Roster.PEOPLE[id].detail
		check(not looks.has(signature),"distinct appearance " + id)
		looks.append(signature)
		var before: String = JSON.stringify(farm._save_data())
		var position: Vector3 = game.world.player.position
		var world_time: float = game.world._time
		game._process(20)
		check(game.world._time > world_time, "farm animation continues behind the keeper " + id)
		check(JSON.stringify(farm._save_data()) == before,"all farm clocks paused " + id)
		check(game.world.player.position == position,"player stays still " + id)
		game._on_action("quick_sell")
		check(JSON.stringify(farm._save_data()) == before,"no background transactions " + id)
		talk.choose(1)
		check(talk.speech.text == Roster.PEOPLE[id].story,"personal topic " + id)
		talk.choose(0)
		check(talk.speech.text == Roster.PEOPLE[id].answer and farm.npc_history[id].kind,"choice gets personal response " + id)
		talk.choose(0)
		check(talk.speech.text == Roster.advice(id, farm),"practical branch " + id)
		var first_take: int = talk.voice.last_clip
		var spoken: int = talk.voice.utterances
		for i in range(100): talk.voice._process(.1)
		check(talk.voice.utterances - spoken <= 2 and not talk.voice.is_processing(), "voice repeats stay bounded while reading " + id)
		if talk.voice.utterances == spoken + 1:
			check(talk.voice.last_clip != first_take, "successive potato takes vary " + id)
		talk.portrait.avatar.speaking = true
		talk.portrait.avatar.animate(.1)
		var mouth_scale: Vector3 = talk.portrait.avatar.talk_mouth.scale
		talk.portrait.avatar.animate(.04)
		check(talk.portrait.avatar.talk_mouth.visible and talk.portrait.avatar.talk_mouth.scale != mouth_scale,"animated speech " + id)
		check(talk.portrait.avatar.talk_mouth.scale.x < .1 and talk.portrait.avatar.talk_mouth.scale.y < .06,"talking mouth stays within the face")
		talk.reveal()
		check(not talk.voice.player.playing and not talk.voice.is_processing(), "revealing text immediately stops speech " + id)
		for i in range(20): talk.portrait.avatar.animate(.1)
		check(not talk.portrait.avatar.talk_mouth.visible and talk.portrait.avatar._mouth.visible,"returns to listening " + id)
		talk.choose(0)
		await frames()
		check(not talk.visible and game.hud._panel_kind == service,"returns to service without spending " + id)
		check(not talk.voice.player.playing and not talk.voice.is_processing(), "service transition leaves no voice playing " + id)
		check(talk.portrait.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden portrait stops rendering " + id)
		game._on_action("talk:" + id)
		check(farm.npc_history[id].kind and talk.speech.text == (Roster.advice(id, farm) if id == "edwin" else Roster.PEOPLE[id].thanks),"friendly memory preserves current reports " + id)
		var previous: String = talk.speech.text
		talk.finish()
		game._start_conversation(id)
		check(talk.speech.text == previous if id == "edwin" else talk.speech.text != previous,"reports stay accurate; flavour greetings vary " + id)
		talk.finish()
	farm.coins = farm.bankruptcy_limit() * 0.5
	game._on_state_changed()
	game._start_conversation("edwin")
	check(not talk.visible and not game.world._npc_actors.edwin.visible, "exactly half overdraft has no bank visit")
	farm.post_money("other", "Test overdraft crossing", -1)
	game._on_state_changed()
	game._on_user_action("bank")
	check(talk.visible and talk.npc_id == "edwin" and game.world._npc_actors.edwin.visible, "crossing half brings manager to first farm")
	check(talk.speech.text.contains("100,001") and talk.speech.text.contains("200,000"), "bank manager quotes actual debt and limit")
	talk.finish()
	for island in [1]:
		var cast: Array = []
		for actor in game.world._villagers: cast.append(actor.npc_id)
		check("mara" in cast and "nell" in cast,"world residents keep distinct identities on island " + str(island))
		for pair in [["mara","MarketStall"],["nell","RedBarn"],["pip","DuckPatrolHouse"],["tess","FarmingQuestBoard"]]:
			check(str(game.world._npc_actors[pair[0]].get_parent().name) == ("BuyerContracts" if pair[0] == "tess" and island == 2 else pair[1]),"stallholder at their service: " + pair[0])
		check(game.world._npc_actors.mara.position.z > .15,"seed vendor stands in front of awning")
	game.hud.close_panel()
	check(farm.save_game(SAVE),"save NPC memories")
	var remembered: Dictionary = farm.npc_history.duplicate(true)
	farm.npc_history.clear()
	check(farm.load_game(SAVE),"load farm with NPC memories")
	check(farm.npc_history == remembered,"memories survive reload")
	for bad in [[],{"mara":true},{"unknown":{"visits":1,"last":"hi","kind":true}},{"mara":{"visits":-1,"last":"hi","kind":true}},{"mara":{"visits":1,"last":false,"kind":true}}]:
		check(not Roster.valid_history(bad),"invalid memory rejected")
	farm.climate.data.phase = "calm"
	farm.climate.begin_warning(farm,"freeze",1)
	game._on_action("activities")
	game._on_action("talk:bram")
	talk.choose(2)
	check(talk.speech.text.contains("hoe") and talk.speech.text.contains("clear ice"),"weather choice gives local freeze guidance")
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
	game._start_conversation("iris")
	check(talk.visible and talk.npc_id == "iris", "weather observer is available on the valley")
	talk.finish()
	# Winter commentary consists of two lines derived from the actual accounts.
	farm.climate.end_working_year()
	farm.season_clock.season = 3
	farm.ledger.post_fixed_costs(1)
	game._start_conversation("nell")
	check(talk.speech.text.split("\n").size() == 2 and talk.speech.text.contains(farm.money(farm.ledger.total(1))), "accountant reads two honest Winter lines")
	talk.choose(0)
	check(game.hud._panel_kind == "accounts", "accountant opens annual ledger in Winter")
	game._on_action("close")
	farm.reset_game()
	check(farm.npc_history.is_empty(),"new farm resets introductions")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("NPC CONVERSATIONS: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames()
	# Give the audio mixer one buffer cycle to release stopped voice playback.
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
