extends SceneTree
const Reversal = preload("res://scripts/sale_undo.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for frame in range(8): await process_frame
	game.set_process(false); game.year_intro.stop(); game.hud.close_panel()
	game.tutorial.active = false; game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false); game.hud.set_tutorial({})
	var farm = game.state
	for season in [0,3]:
		farm.season_clock.season = season
		farm.storage = farm.Stock.empty(); farm.trading.held = farm.Stock.empty()
		for score in [20,55,60,90,100]: farm.Stock.add(farm.storage,"russet",4,score)
		if season == 3:
			farm.Stock.add(farm.trading.held,"russet",2,55)
			farm.Stock.add(farm.trading.held,"russet",2,90)
		for grade in ["Table","Standard","Feed"]:
			game.hud.show_market(true,farm)
			var page = game.hud._refs.market_page
			page.select_variety("russet",grade); page.quantity.set_value_no_signal(2)
			page.refresh()
			var journal: Dictionary = farm.ledger.save_data()
			var stock: Dictionary = farm.storage.duplicate(true)
			var held: Dictionary = farm.trading.held.duplicate(true)
			var sales: float = farm.lifetime_sales
			var quests: Dictionary = farm.quest_progress.duplicate(true)
			page._sell()
			check(farm.stock_count("russet",grade) == farm.Stock.count(stock,"russet",grade)-2 and farm.ledger.entry_count()>journal.entries.size(),"sale posts immediately: "+str(season)+grade)
			check(page.sell_button.text=="Undo" and not page.sell_button.disabled,"sell button becomes Undo")
			check(page._undo_sale.remaining(farm)>2.9 and page._undo_sale.remaining(farm)<=3.0,"Undo window is three seconds")
			page._sell()
			check(farm.ledger.save_data()==journal,"Undo restores the identical ledger")
			check(farm.storage==stock and farm.trading.held==held,"Undo restores exact fresh and Winter cohorts")
			check(farm.lifetime_sales==sales and farm.quest_progress==quests,"Undo reverses sale progress")
			check(page.sell_button.text=="1 tonne","Undo returns to the sale amount")
	farm.season_clock.season=0; game.hud.close_panel()
	var command: RefCounted=Reversal.new(farm)
	farm.sell_crop("russet",1,"Standard"); check(command.commit(farm),"capture a committed sale")
	farm.post_money("seeds","Russet seed",-270)
	farm.Stock.add(farm.storage,"giant",1,100)
	check(command.undo(farm),"Undo accepts unrelated later activity")
	check(farm.ledger.entries.back().label=="Russet seed" and farm.stock_count("giant")==1,"Undo preserves later ledger entries and other stock")
	command=Reversal.new(farm); farm.sell_crop("russet",1,"Standard"); command.commit(farm)
	var sold: Dictionary=farm.ledger.save_data(); command._deadline=Time.get_ticks_msec()-1
	check(not command.undo(farm) and farm.ledger.save_data()==sold,"expired Undo cannot alter a sale")
	# The first guided sale must also remain on its button through Undo.
	game.hud.close_panel(); farm.season_clock.year=1; farm.season_clock.season=1
	farm.tutorial_progress={"version":3,"step":8,"completed":false,"plot":5,"tour_only":false,"choice":""}
	farm.storage=farm.Stock.empty(); farm.trading.held=farm.Stock.empty(); farm.Stock.add(farm.storage,"russet",2,90)
	game.tutorial.start(); game.hud.show_market(true,farm)
	var page = game.hud._refs.market_page
	var guided_journal: Dictionary=farm.ledger.save_data()
	var guided_stock: Dictionary=farm.storage.duplicate(true)
	page.sale_rows.russet.sales[1].pressed.emit()
	check(game.hud.is_panel_open() and game.hud._refs.market_page == page and page.sell_button.text == "Undo","guided sale keeps its visible Undo button")
	check(game.tutorial.current_id() == "winter","guided sale still records its progress immediately")
	page.sale_rows.russet.sales[1].pressed.emit()
	check(farm.ledger.save_data()==guided_journal and farm.storage==guided_stock,"guided Undo restores the identical ledger and stock")
	check(game.tutorial.current_id()=="sell","guided Undo restores the sale instruction")
	page.sale_rows.russet.sales[1].pressed.emit()
	check(game.tutorial.current_id()=="winter" and page.sell_button.text=="Undo","a repeated guided sale can advance again")
	if is_instance_valid(page._undo_sale): page._undo_sale._deadline=Time.get_ticks_msec()-1
	page._process(0)
	check(not game.hud.is_panel_open(),"guided view returns to farming after the Undo window")
	check(await preload("res://tests/audio_fixture.gd").release(game,self),"audio releases before teardown")
	game.queue_free(); for frame in range(8): await process_frame
	print("SALE UNDO: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
