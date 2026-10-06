extends Node
## A guided first year through real Winter accounts. Later help is optional.
const WAIT_MESSAGE: String = "Your potatoes are growing. Water any dry beds."
const STEPS: Array[Dictionary] = [
	{"id": "welcome", "title": "Your first year", "body": "Let's grow one potato together.", "next": true, "label": "Meet Mara →"},
	{"id": "market", "title": "Choose your crop", "body": "Tap Mara's stall to see your starter seeds.", "focus": "market", "next": true, "label": "Use my starter seeds →"},
	{"id": "hoe", "title": "Prepare the soil", "body": "Tap the hoe, then tap the glowing bed.", "tool": "hoe"},
	{"id": "plant", "title": "Plant your seed", "body": "Tap the seeds, then tap the glowing bed.", "tool": "plant"},
	{"id": "water", "title": "Water once", "body": "Tap the watering can, then tap the glowing bed.", "tool": "water"},
	{"id": "grow", "title": "Spring is passing", "body": "Spring is passing. One small storm is coming. Iris will warn you."},
	{"id": "loss", "title": "Tess counts the damage", "body": "Tap Tess's board to see what the storm damaged.", "next": true, "label": "Return to the field →"},
	{"id": "harvest", "title": "Bring in your crop", "body": "Tap the harvest tool, then tap the glowing bed.", "tool": "harvest"},
	{"id": "sell", "title": "Sell or store", "body": "Open Mara’s Sell page, or leave potatoes stored.", "focus": "market", "next": true, "label": "Store for Winter →"},
	{"id": "winter", "title": "Winter brings the bills", "body": "Harvest the ripe beds before Winter comes."},
]
const TOUR: Array[Dictionary] = [
	{"id": "welcome", "title": "Meet the Valley", "body": "Your farm pauses while we look around together.", "label": "Look around →"},
	{"id": "market", "title": "Seed market", "body": "Tap Mara's stall to browse seeds.", "focus": "market"},
	{"id": "sell", "title": "Sell or store", "body": "Tap Mara’s Sell page, or leave potatoes stored.", "focus": "market"},
	{"id": "inventory", "title": "Your inventory", "body": "Open your bag to inspect potatoes and seeds."},
	{"id": "tools", "title": "Toolsmith", "body": "Tap the Tools shed to see upgrades.", "focus": "tools"},
	{"id": "quests", "title": "Local challenges", "body": "Tap Tess's board to see your challenges.", "focus": "quests"},
	{"id": "ducks", "title": "Duck Patrol", "body": "Tap Pip to meet the ducks that clear pests.", "focus": "duck_patrol"},
	{"id": "finish", "title": "Back to your farm", "body": "Your crops, prices and timers resume where you left them.", "label": "Resume farming →"},
]
var game: Node
var active: bool = false
var visited: bool = false
var sale_baseline: float = 0.0
var cue_count: int = 0

func setup(owner_game: Node) -> void:
	game = owner_game

func start(replay: bool = false) -> void:
	if replay:
		game.state.tutorial_progress = {"version": 3, "step": 0, "completed": false, "plot": 5, "tour_only": true}
	else:
		_migrate()
		if bool(game.state.tutorial_progress.get("completed", false)):
			return
	active = true
	game.state.set_tutorial_active(true)
	if not replay and (game.state.season_clock.season == 3 or game.state.season_clock.year > 1):
		finish()
		return
	_enter_step()

func _migrate() -> void:
	var progress: Dictionary = game.state.tutorial_progress
	if int(progress.version) >= 3: return
	var old_version: int = int(progress.version)
	progress.version = 3
	if bool(progress.get("tour_only", false)):
		progress.step = 0
	elif not progress.completed:
		if old_version == 1:
			progress.step = maxi(0, int(progress.step) - 1) if int(progress.step) >= 2 else int(progress.step)
			if int(progress.step) >= 8: progress.completed = true
		# Old unfinished harvests join at the weather demonstration; if already
		# harvested, retain the real sell/store choice instead of inventing a crop.
		if int(progress.step) >= 6: progress.step = 8 if int(game.state.plots[_plot_index()].stage) == 0 else 5
		if game.state.season_clock.season == 3 or game.state.season_clock.year > 1: progress.completed = true
		if progress.completed: game.state.farm_help.enable()
	progress.step = clampi(int(progress.step), 0, (TOUR.size() if progress.get("tour_only", false) else STEPS.size()) - 1)

func _steps() -> Array[Dictionary]:
	return TOUR if _tour_only() else STEPS

func current_id() -> String:
	return str(_steps()[_index()].id) if active else ""

func _index() -> int:
	return clampi(int(game.state.tutorial_progress.get("step", 0)), 0, _steps().size() - 1)

func _tour_only() -> bool:
	return bool(game.state.tutorial_progress.get("tour_only", false))

func _plot_index() -> int:
	return clampi(int(game.state.tutorial_progress.get("plot", 5)), 0, game.state.plots.size() - 1)

func _enter_step() -> void:
	visited = false
	game._cancel_walk()
	game.hud.close_panel()
	sale_baseline = game.state.lifetime_sales
	if not _tour_only() and current_id() in ["plant", "sell"]:
		game.state.select_crop("russet")
	_ensure_summer_warning()
	refresh()
	var step: Dictionary = _steps()[_index()]
	if step.has("tool"):
		game._select_tool(str(step.tool))
	game._on_state_changed()
	if current_id() == "grow" and game.state.climate.data.phase == "warning":
		game._on_climate_changed("warning")
	if current_id() == "loss":
		game.hud._climate_alert.dismiss()
		game.hud.show_panel("quests", game.state)
		game.hud._refs.tess_board.losses = true
		game.hud._refs.tess_board.refresh()
	_save()

func _tools() -> Array[String]:
	var result: Array[String] = []
	if _tour_only(): return result
	for entry: Array in [[2, "hoe"], [3, "plant"], [4, "water"], [7, "harvest"]]:
		if _index() >= int(entry[0]): result.append(str(entry[1]))
	if current_id() in ["grow", "winter"]:
		for tool in ["hoe", "water", "harvest"]:
			if tool not in result: result.append(tool)
	return result

func _features() -> Array[String]:
	if _tour_only():
		return ["coins", "market", "barn", "inventory", "tools", "quests", "duck_patrol", "stock", "menu", "climate", "calendar"]
	var result: Array[String] = []
	if _index() >= 1: result.append_array(["coins", "market"])
	if _index() >= 5: result.append_array(["climate", "calendar"])
	if _index() >= 8: result.append("barn")
	return result

func allowed_actions() -> Array[String]:
	var result: Array[String] = ["close", "grades", "grade_acknowledge", "save", "graphics", "graphics:", "tutorial:next", "tutorial:skip"]
	if _tour_only():
		result.append_array(["market", "grade:", "market:sell", "inventory", "inventory_tab:", "tools", "quests", "duck_patrol", "menu", "pause", "help", "toggle_details:"])
		return result
	for feature: String in _features():
		if feature != "coins": result.append(feature)
	if "barn" in _features(): result.append_array(["inventory_tab:crops", "market:sell"])
	for tool: String in _tools(): result.append("tool:" + tool)
	if current_id() == "market": result.append("buy:russet:1")
	if current_id() == "sell": result.append_array(["sell:russet:", "market_sell", "quantity_minus", "quantity_plus", "market_all", "history_older", "history_newer"])
	if current_id() in ["grow", "winter"]: result.append_array(["sell:russet:", "market_sell", "market_all", "quantity_minus", "quantity_plus", "grade:"])
	if current_id() == "plant": result.append("crop:russet")
	if current_id() == "loss": result.append("quests")
	return result

func allows_action(action: String) -> bool:
	if action.begins_with("current_sell:"): action = action.replace("current_sell:", "sell:")
	if not active: return true
	for allowed: String in allowed_actions():
		if action == allowed or (allowed.ends_with(":") and action.begins_with(allowed)): return true
	return false

func allows_tool(tool: String) -> bool:
	return not active or tool in _tools()

func allows_plot(index: int, tool: String) -> bool:
	if not active: return true
	if _tour_only(): return false
	var id: String = current_id()
	if id in ["grow", "winter"] and index >= 0 and index < game.state.plots.size():
		# Keep only the demonstration crop for the disclosed gust; other beds
		# are available immediately, before the guide could expose them to cold.
		return game.state.plots[index].unlocked and tool in ["hoe", "water", "harvest"]
	# A different empty bed is a valid choice; move the cue to that bed.
	if id == "hoe" and tool == "hoe" and index >= 0 and index < game.state.plots.size():
		var candidate: Dictionary = game.state.plots[index]
		if candidate.unlocked and int(candidate.stage) == 0 and not candidate.tilled:
			game.state.tutorial_progress.plot = index
			refresh()
	return id in ["hoe", "plant", "water", "harvest"] and index == _plot_index() and tool == id

func explain_block() -> void:
	if not active: return
	var message: String = "Shop tour only. Return to farming first."
	if not _tour_only():
		var step: Dictionary = _steps()[_index()]
		refresh()
		message = "Later. Skip guided year to farm freely."
		if step.has("tool"):
			game._select_tool(str(step.tool))
			message = "%s selected again. Click the gold bed." % str(step.tool).capitalize()
	game.hud.show_tutorial_feedback(message)

func refresh() -> void:
	if not active: return
	var step: Dictionary = _steps()[_index()]
	var body: String = str(step.body)
	var title: String = str(step.title)
	var focus: String = str(step.get("focus", ""))
	if not _tour_only() and current_id() in ["hoe", "plant", "water", "grow", "harvest"]:
		focus = "plot:%d" % _plot_index()
	var wait_label: String = ""
	var forecaster: bool = false
	if current_id() == "grow":
		if game.state.season_clock.season == 0:
			body = WAIT_MESSAGE
		else:
			forecaster = true
			title = "A small storm is coming"
			body = "Harvest the glowing bed before the storm."
			wait_label = "Iris will warn you."
	elif current_id() == "winter":
		var ripe: int = game.state.plots.filter(func(bed): return int(bed.stage) == 3 and bed.crop != "icecap").size()
		body = "Harvest the ripe beds before Winter comes." if ripe > 0 else WAIT_MESSAGE
		wait_label = "Harvest the ripe beds." if ripe > 0 else ""
	game.hud.set_tutorial({"title": title, "body": body, "step": _index() + 1, "total": _steps().size(),
		"tools": _tools(), "features": _features(), "continue": _tour_only() or bool(step.get("next", false)),
		"continue_label": str(step.get("label", "Next place →")), "wait_label": wait_label, "forecaster": forecaster, "id": current_id(), "key": str(step.get("key", "")),
		"tool": str(step.get("tool", "")), "tour_only": _tour_only(), "visited": visited, "focus": focus, "allowed_actions": allowed_actions()})
	game.world.set_tutorial_focus(focus)

func _ensure_summer_warning() -> void:
	# Resuming mid-Summer can have an already-started outlook but no lesson storm.
	# Start the real warned event; keep its loss, yield and journal arithmetic.
	if not _tour_only() and current_id() == "grow" and game.state.guided_first_year() and game.state.season_clock.season == 1 and game.state.tutorial_loss().is_empty() and game.state.climate.data.phase == "calm":
		if game.state.climate.begin_warning(game.state, "storm", 0.2):
			game.state.climate.data.timer = minf(game.state.ClimateSystem.GUIDED_WARNING_SECONDS, maxf(0.01, game.state.season_clock.remaining(game.state.season_seconds()) - 0.01))

func update(_delta: float) -> void:
	if not active or _tour_only(): return
	_ensure_summer_warning()
	var id: String = current_id()
	var plot: Dictionary = game.state.plots[_plot_index()]
	var done: bool = false
	match id:
		"hoe": done = bool(plot.tilled)
		"plant": done = int(plot.stage) > 0
		"water": done = bool(plot.watered)
		"grow":
			if int(plot.stage) == 0 and game.state.stock_count("russet") > 0:
				game.state.tutorial_progress.step = 8
				_enter_step()
				return
			done = not game.state.tutorial_loss().is_empty()
		"harvest": done = int(plot.stage) == 0 and game.state.stock_count("russet") > 0
		"sell":
			done = game.state.lifetime_sales > sale_baseline
			if done: game.state.tutorial_progress.choice = "sell"
		"winter":
			if game.state.season_clock.season == 3:
				finish()
				return
	if done: _advance()
	elif id in ["grow", "winter"]: refresh()

func observe_action(action: String) -> void:
	if not active: return
	if _tour_only() and action == str(_steps()[_index()].get("focus", "")) and game.hud.is_panel_open():
		visited = true
	update(0.0)

func observe_purchase(receipt: Dictionary) -> void:
	if active and current_id() == "market" and not _tour_only() and receipt.get("kind") == "seeds" and receipt.get("id") == "russet": _advance()

func next() -> void:
	if active and (_tour_only() or bool(_steps()[_index()].get("next", false))):
		if not _tour_only() and current_id() == "sell": game.state.tutorial_progress.choice = "store"
		_advance()

func _advance() -> void:
	if _index() >= _steps().size() - 1:
		finish()
		return
	_cue("step")
	game.state.tutorial_progress.step = _index() + 1
	_enter_step()

func finish() -> void:
	if not active: return
	var was_tour: bool = _tour_only()
	active = false
	game.state.tutorial_progress.completed = true
	game.state.set_tutorial_active(false)
	if not was_tour: game.state.farm_help.enable()
	game._cancel_walk()
	if not game.state.accounts_open: game.hud.close_panel()
	game.hud.set_tutorial({})
	game.world.set_tutorial_focus("", true)
	game._select_tool("hoe")
	game._on_state_changed()
	_cue("finish")
	_save()

func _cue(kind: String) -> void:
	cue_count += 1
	game.play_tutorial_cue(kind)

func _save() -> void:
	if not game.test_mode: game.state.save_game()
