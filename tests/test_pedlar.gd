extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Model = preload("res://scripts/pedlar_state.gd")
const Balance = preload("res://scripts/balance.gd")
const Undo = preload("res://scripts/sale_undo.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const SAVE = "user://pedlar_test_only.json"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + why)
func setup_farm(farm, seed_value: int = 6) -> void:
	farm.reset_game(); farm.rng.seed = seed_value
	# Unendowed fixtures isolate individual pack outcomes from the starter gift.
	farm.storage = farm.Stock.empty(); farm.pedlar.data = Model.fresh()
	farm.boundary_save_path = ""; farm.season_clock.year = 2; farm.season_clock.season = 0
	farm.tutorial_progress.completed = true; farm.set_tutorial_active(false)
func settle() -> void:
	for frame in range(14): await process_frame
func audit(node: Node, scale_value: float) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label and not node.text.is_empty():
		check(node.get_theme_font_size("font_size")*scale_value >= 13.99,"Pedlar caption floor: "+node.text)
	if node is ScrollContainer: check(not node.get_v_scroll_bar().visible,"Pedlar has no scrollbar")
	for child in node.get_children(): audit(child,scale_value)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var farm = State.new(); root.add_child(farm)
	check(farm.pedlar.data.hooks==["Second Sowing"] and farm.pedlar.data.superstitions==["Second Sowing"],"fresh farm starts with hook one filled")
	check(farm.pedlar.data.oddities.size()==1 and farm.stock_count("russet","Standard")==1 and farm.seed_inventory.russet==12,"fresh collection has the Standard Twin and no extra seeds")
	check(farm.ledger.entry_count()==0 and farm._valid_save(farm._save_data()) and farm.save_game(SAVE) and farm.load_game(SAVE),"endowed items validate without ledger purchases")
	setup_farm(farm)
	farm.season_clock.year = 1
	check(farm.pedlar.presence(farm)=="passing" and farm.pedlar.buy(farm,"seed").is_empty(),"first-year cart passes and cannot trade")
	check(not farm.pedlar.tick_pass(farm,9.99) and farm.pedlar.tick_pass(farm,.01),"one bell halfway through the twenty-second pass")
	check(not farm.pedlar.tick_pass(farm,10) and farm.pedlar.presence(farm)=="absent","cart exits at twenty seconds without another bell")
	farm.season_clock.year = 2
	check(farm.pedlar.presence(farm)=="parked","cart parks for the second Spring")
	for season in [1,2,3]:
		farm.season_clock.season = season
		check(farm.pedlar.presence(farm)=="absent","cart leaves outside Spring")
	setup_farm(farm)
	for pack: String in Model.PACK_IDS:
		var sum: int = 0; var reached: Dictionary = {}
		for row: Array in Balance.PEDLAR_PACKS[pack].outcomes: sum += int(row[1])
		check(sum==Balance.PEDLAR_PACKS[pack].tickets,"exact odds sum to one: "+pack)
		for seed_value in range(1000):
			var rng := RandomNumberGenerator.new(); rng.seed = seed_value
			reached[Model.choose(pack,rng)[0]] = true
		for row: Array in Balance.PEDLAR_PACKS[pack].outcomes:
			check(reached.has(row[0]),"seeded outcome reachable: "+pack+str(row[0]))
	for pack: String in Model.PACK_IDS:
		var counts: Dictionary = {}; var rng := RandomNumberGenerator.new(); rng.seed = 2201
		for roll in range(10000):
			var id: String = str(Model.choose(pack,rng)[0]); counts[id] = int(counts.get(id,0))+1
		for row: Array in Balance.PEDLAR_PACKS[pack].outcomes:
			var expected: float = 10000.0*int(row[1])/int(Balance.PEDLAR_PACKS[pack].tickets)
			check(absf(int(counts.get(str(row[0]),0))-expected) <= expected*.1,"10,000 rolls match the printed odds within a tenth: "+pack+str(row[0]))
	var superstition_reached: Dictionary = {}; var mystery_reached: Dictionary = {}
	for seed_value in range(240):
		setup_farm(farm,seed_value)
		var result: Dictionary = farm.pedlar.buy(farm,"superstition")
		superstition_reached[result.id] = true
		check(farm.pedlar.data.hooks == [result.id] and farm.pedlar.data.superstitions == [result.id],"won superstition fills its first hook")
		check(result.effect=="Takes effect next Winter","superstition stays inert in V1")
		setup_farm(farm,seed_value)
		result = farm.pedlar.buy(farm,"mystery"); mystery_reached[result.kind+":"+result.id] = true
		check(farm.ledger.entries[0].label=="Pedlar's pack","purchase uses the frozen new label")
		if result.kind == "refund": check(farm.ledger.entries.back().label=="Pedlar's refund" and farm.ledger.entries.back().amount==500,"Mystery refund records 500")
	for rarity: String in Model.SUPERSTITIONS:
		for id: String in Model.SUPERSTITIONS[rarity]: check(superstition_reached.has(id),"all superstition cards reachable: "+id)
	for id in ["seeds:russet","seeds:blue_pearl","stone:stone","refund:refund"]: check(mystery_reached.has(id),"Mystery outcome reachable: "+id)
	check(mystery_reached.keys().any(func(id): return str(id).begins_with("oddity:")),"oddity reachable")
	setup_farm(farm)
	farm.coins = 2999; var before: Dictionary = farm._save_data()
	check(farm.pedlar.buy(farm,"seed").get("error")=="Not enough in the purse." and farm._save_data()==before,"no borrowing for a pack")
	farm.coins = -1; before = farm._save_data()
	check(farm.pedlar.buy(farm,"mystery").has("error") and farm._save_data()==before,"overdraft cannot buy even cheapest pack")
	farm.coins = 3000
	check(not farm.pedlar.buy(farm,"seed").is_empty() and farm.coins==0,"cash exactly covers price")
	check(farm.pedlar.buy(farm,"seed").is_empty() and farm.pedlar.unbought(farm,"mystery"),"one pack of each kind per Spring")
	check(farm.save_game(SAVE) and farm.load_game(SAVE) and farm.pedlar.unbought(farm,"mystery") and not farm.pedlar.unbought(farm,"seed"),"unbought and bought backs survive a save")
	farm.season_clock.year = 3; farm.pedlar.begin_spring(3)
	check(farm.pedlar.unbought(farm,"seed"),"new Spring restores pack slots")
	setup_farm(farm)
	farm.pedlar.data.superstitions = (Model.SUPERSTITIONS.common+Model.SUPERSTITIONS.uncommon+Model.SUPERSTITIONS.rare).duplicate()
	farm.pedlar.data.hooks = Model.SUPERSTITIONS.common.duplicate()
	var refund: Dictionary = farm.pedlar.buy(farm,"superstition")
	check(refund.kind=="refund" and refund.effect=="All of these are yours. Here's 2,000.","all owned within rarity gives exact refund copy")
	check(farm.ledger.entries.back().label=="Pedlar's refund" and farm.ledger.entries.back().amount==2000 and farm.coins==74000,"duplicate refund has exact amount and label")
	setup_farm(farm,11)
	farm.pedlar.data.superstitions = Model.SUPERSTITIONS.common.duplicate()
	farm.pedlar.data.hooks = Model.SUPERSTITIONS.common.duplicate()
	# Choose a rarity still containing an unowned card; a full gate must accept it.
	for seed_value in range(100):
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value ^ 0x5f3a71
		if Model.choose("superstition",rng)[0] != "common": farm.rng.seed = seed_value; break
	var won: Dictionary = farm.pedlar.buy(farm,"superstition")
	check(won.kind=="superstition" and farm.pedlar.data.superstitions.size()==6 and farm.pedlar.data.hooks.size()==5 and won.id not in farm.pedlar.data.hooks,"full hooks collect the sixth card without refusing")
	check(Model.valid(farm.pedlar.data,2),"full hooks and collection validate")
	setup_farm(farm)
	check("blue_pearl" not in farm.available_crops() and "blue_pearl" not in farm.known_crops(),"Mara never sells Blue Pearl and its price board starts hidden")
	farm.seed_inventory.blue_pearl = 1; farm.farmer_appearance.farm_name = "Copper Acres"
	check("blue_pearl" in farm.known_crops() and farm.save_game(SAVE) and farm.load_game(SAVE),"held Blue Pearl and farm name validate and save")
	check(farm.farm_name()=="Copper Acres","farm name round-trips with appearance")
	farm.select_crop("blue_pearl"); farm._clear_crop(farm.plots[5]); farm.plots[5].tilled = true
	farm.interact_plot(5,"plant"); farm.interact_plot(5,"water")
	check(farm.plots[5].crop=="blue_pearl" and farm.plots[5].stage==2,"a held Blue Pearl seed actually plants and waters")
	for season in range(4):
		farm.season_clock.season = season
		check(farm.can_plant_crop("blue_pearl") == (season != 3),"Blue Pearl plant seasons are Spring through Autumn")
	setup_farm(farm)
	var legacy: Dictionary = farm._save_data(); legacy.erase("pedlar"); legacy.farmer_appearance.erase("farm_name")
	legacy.seed_inventory.erase("blue_pearl"); legacy.storage.erase("blue_pearl"); legacy.trading.held.erase("blue_pearl"); legacy.trading.kept_seed.erase("blue_pearl")
	check(farm._valid_save(farm._prepare_v1_save(legacy)),"complete old five-crop save migrates to six")
	farm.restore_snapshot(legacy); check(farm.farm_name()=="Taterland" and farm.seed_inventory.blue_pearl==0,"old save keeps appearance and default farm name")
	check(farm.pedlar.data.hooks==["Second Sowing"] and farm.pedlar.data.oddities.size()==1 and farm.stock_count("russet")==1,"old save receives both gifts once")
	var once: Dictionary = farm._save_data(); farm.restore_snapshot(once)
	check(farm._save_data()==once,"reloading an endowed save never duplicates gifts")
	var corrupt: Dictionary = farm._save_data(); corrupt.pedlar.hooks = ["unknown"]
	check(not farm._valid_save(corrupt),"invented hooks reject")
	setup_farm(farm)
	farm.Stock.add(farm.storage,"russet",1,60)
	farm.pedlar.data.oddities.append({"name":"the Twin","crop":"russet","score":60,"held":true,"starter":false})
	before = farm._save_data(); var cash: float = farm.coins
	var command = Undo.new(farm); var grade_price: float = float(farm.market.russet.sell)*farm.Quality.MULTIPLIER.Standard
	farm.sell_crop("russet",1,"Standard"); command.commit(farm)
	check(is_equal_approx(farm.coins-cash,grade_price+500) and not farm.pedlar.data.oddities[0].held,"oddity sale adds exactly 500 to the grade price")
	check(command.undo(farm) and farm._save_data()==before,"oddity Undo restores exact ledger, stock and collection")
	check(farm.ClimateSystem.chance(2)==0 and farm.ClimateSystem.chance(3)==.15,"climate curve begins in year three")
	for season in range(4):
		farm.climate.reset(); farm.season_clock.season = season
		farm.climate.start_season(farm)
		check(farm.climate.data.phase=="calm","year two has no climate events")
	farm.free()
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.year_intro.stop(); game.hud.close_panel(); setup_farm(game.state)
	game.hud.set_tutorial({}); root.min_size = Vector2i.ZERO; root.size = Vector2i(390,844)
	game.touch_controls.enabled = true; game.touch_controls._build_touch_sheets(); game.touch_controls.resize()
	game.hud.show_panel("pedlar",game.state); await settle()
	game.hud.advance_panel_entrance(.8)
	var page = game.hud._refs.pedlar_page; page.set_process(false)
	check(page.cards.size()==3,"three facedown cards share the page")
	audit(game.hud._modal_card,game.touch_controls.display_scale())
	check(Rect2(Vector2.ZERO,game.hud.root.size).encloses(game.hud._modal_card.get_global_rect()),"three packs fit the phone")
	page.buy("seed"); page.advance_reveal(.69)
	check(page.revealing and not page.cue_started and not page.result_card.visible,"wind-up never reveals immediately")
	page.advance_reveal(.01)
	check(page.revealing and page.cue_started and not page.result_card.visible,"two notes follow the drumroll before landing")
	page.advance_reveal(.42)
	check(not page.revealing and page.result_card.visible and game.state.pedlar.data.revealed,"contents land after the two-note cue")
	check(page.cards.seed.title.text=="Sold" and page.cards.mystery.title.text=="Mystery pack","only bought pack reads Sold")
	await settle(); audit(game.hud._modal_card,game.touch_controls.display_scale())
	game.state.pedlar.data.superstitions = Model.SUPERSTITIONS.common.duplicate()+["Lucky Boot"]
	game.state.pedlar.data.hooks = Model.SUPERSTITIONS.common.duplicate()
	game.state.pedlar.data.gate_greeted = false
	game._start_conversation("fennick","pedlar",true)
	check(game.conversation.speech.text=="Three packs. One's good.\nThat one on your gate? Keep it. Lovely weather.","second Spring greeting mentions the endowed hook once")
	game.conversation.finish()
	check(game.state.pedlar.data.gate_greeted and not game.state.NpcRoster.service_greeting("fennick",game.state).contains("That one"),"hook greeting never repeats")
	game.hud._dex_tab = "superstitions"; game.hud.show_panel("dex",game.state); await settle()
	var labels: Array[Node] = game.hud._body.find_children("*","Label",true,false)
	check(labels.any(func(label): return label.text=="Not hung yet"),"sixth card is visible in Superstitions with Not hung yet")
	check(game.hud._body.find_children("Collected_*","PanelContainer",true,false).size()==6,"collection retains all owned superstitions")
	game.state.seed_inventory.blue_pearl = 1
	game.hud.show_market(true,game.state); await settle(); game.hud.advance_panel_entrance(.8)
	check(game.hud._refs.market_page.sale_rows.size()==6 and game.hud._refs.market_page.sale_rows.has("blue_pearl"),"held Blue Pearl joins the price and sale page")
	var sell = game.hud._refs.market_page
	for entry in sell.sale_rows.values():
		check(Rect2(Vector2.ZERO,game.hud.root.size).encloses(entry.card.get_global_rect()),"all six held-crop price rows fit the phone")
	check(await preload("res://tests/audio_fixture.gd").release(game,self),"audio releases before teardown")
	game.queue_free(); await settle()
	print("PEDLAR: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
