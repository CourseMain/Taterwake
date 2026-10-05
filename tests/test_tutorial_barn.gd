extends SceneTree
const Stock = preload("res://scripts/graded_stock.gd")
## First-harvest sale remains reachable from a remembered inventory tab.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func button(action: String) -> Button:
	for candidate: Node in game.hud.root.find_children("*", "Button", true, false):
		if candidate.get_meta("hud_action", "") == action and candidate.is_visible_in_tree(): return candidate
	return null

func press(action: String) -> void:
	var target: Button = button(action)
	check(target != null and not target.disabled, "visible enabled action " + action)
	if target != null and not target.disabled: target.pressed.emit()

func settle() -> void:
	for frame: int in range(8): await process_frame

func walk_plot(tool: String, index: int = 4) -> void:
	game._on_action("tool:" + tool)
	game.queue_plot(index)
	for frame: int in range(400):
		game._process(0.04)
		if not game.walking: break

func check_crops() -> void:
	check(game.hud._panel_kind == "barn" and game.hud._refs.market_page.selling, "first sale opens the sole barn page")
	check(not game.hud._refs.has("tab:tools"), "no Tools tab can trap the first sale")
	check(button("market_all") != null and not button("market_all").disabled, "real sale controls remain enabled")

func sell_harvest() -> void:
	var coins_before: float = game.state.coins
	var sales_before: float = game.state.lifetime_sales
	check(Stock.count(game.state.storage, "russet") > 0, "real harvest stored before selling")
	press("market_all")
	press("market_sell")
	check(Stock.count(game.state.storage, "russet") == 0, "sale clears harvested Russets")
	check(game.state.coins > coins_before and game.state.lifetime_sales > sales_before, "sale credits coins")
	check(game.tutorial.current_id() == "winter" and not game.state.tutorial_progress.completed, "barn sale continues to Winter accounts")

func run() -> void:
	if not "--integration-test" in OS.get_cmdline_user_args():
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.start()
	press("tutorial:next")
	game._on_action("market")
	press("tutorial:next")
	walk_plot("hoe")
	walk_plot("plant")
	walk_plot("water")
	game._process(1000)
	game._process(40)
	check(game.tutorial.current_id() == "loss", "Summer loss precedes harvest")
	game.tutorial.next()
	walk_plot("harvest")
	game.hud.close_panel()
	check(game.tutorial.current_id() == "sell", "real Summer loss and harvest reach sell/store choice")
	var path: String = "user://tutorial-barn-%d.json" % OS.get_process_id()
	check(game.state.save_game(path), "save unfinished first sale")
	game._on_action("barn")
	await settle()
	check_crops()
	sell_harvest()
	# Existing saves resume at the sale; no tutorial restart or lost crop.
	check(game.state.load_game(path), "reload unfinished first sale")
	game.tutorial.start()
	check(game.tutorial.current_id() == "sell", "saved guide resumes first sale")
	game._on_action("barn")
	await settle()
	check_crops()
	sell_harvest()
	for advance in range(6):
		for index in range(game.state.plots.size()):
			if int(game.state.plots[index].stage) == 3: walk_plot("harvest", index)
		if game.state.accounts_open: break
		game._process(1000)
	while game.hud.accounts_building: await process_frame
	check(game.state.accounts_open and not game.tutorial.active, "barn choice reaches first accounts after reload")
	check(game.state.season_clock.autumn_loss == 0, "resumed barn lesson harvests starters before Autumn Cold")
	var credit_row = game.hud._refs.accounts_guided_credit.get_parent().get_parent()
	check(credit_row.is_visible_in_tree() and credit_row.caption.text == game.state.Ledger.GUIDED_CREDIT_LABEL and game.hud._refs.accounts_guided_credit.text == "+" + game.state.money(game.state.ledger.fixed_cost_total()), "accounts show the named credit at its exact amount")
	check(not game.hud._refs.accounts_other.get_parent().get_parent().visible, "credit is not also counted in a generic Other row")
	check(game.hud._refs.accountant.text == "Nell: Dad's last harvest paid this year. From now on it's yours.", "Nell's explanation stays visible after the guide closes")
	game._on_action("close")
	game.tutorial.start(true)
	game._on_action("barn")
	check(game.hud._panel_kind == "barn" and game.hud._refs.market_page.selling, "optional tour uses the same barn entrance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("TUTORIAL BARN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
