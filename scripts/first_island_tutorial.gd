extends Node
## A guided first year through real Winter accounts. Later help is optional.
const WAIT_SPEED: float = 10.0
const STEPS: Array[Dictionary] = [
	{"id": "welcome", "title": "Your first year", "body": "Plant, water, weather, harvest. Then Nell reads the bills.\nThis guided year has one small Summer storm. Decisions pause time.\nWASD to walk; drag to look.", "next": true, "label": "Meet Mara →"},
	{"id": "market", "title": "Choose your first crop card", "body": "Tap Mara’s whole stall or press B to read Russet’s card. You already have twelve starter seeds; use one for your first bed.", "focus": "market", "key": "B · SEEDS", "next": true, "label": "Use my starter seeds →"},
	{"id": "hoe", "title": "Prepare the soil", "body": "Hoe selected. Click the gold bed to walk over and till it.", "tool": "hoe", "key": "1 · HOE"},
	{"id": "plant", "title": "Plant your seed", "body": "Seeds selected. Click the same gold bed to plant a Russet.", "tool": "plant", "key": "2 · SEEDS"},
	{"id": "water", "title": "Water once", "body": "Watering can selected. Click the gold bed to start it growing.", "tool": "water", "key": "3 · WATER"},
	{"id": "grow", "title": "Spring into Summer", "body": "The calendar runs at 10× while you wait, then at 1× from the storm warning. One mild Summer storm will show what a loss costs. Later years use the changing climate forecast."},
	{"id": "loss", "title": "Tess counts the damage", "body": "Read the cause card. One tonne lost; two left to harvest. Continue when you are ready.", "next": true, "label": "Harvest what remains →"},
	{"id": "harvest", "title": "Bring in your crop", "body": "Harvest tool selected. Click the gold bed to put your potatoes in the barn.", "tool": "harvest", "key": "4 · HARVEST"},
	{"id": "sell", "title": "Sell now or store?", "body": "Sell your Russet in the barn [F] for cash now. Or keep it: Winter charges storage and spoilage, while prices rise. Either choice leads to the same honest accounts.", "focus": "barn", "key": "F · SELL", "next": true, "label": "Store for Winter →"},
	{"id": "winter", "title": "The bills are coming", "body": "Harvest the remaining starter beds before Winter. You can work the other beds now; Nell opens the accounts as Winter begins. Unsold crops stay in the barn."},
]
const TOUR: Array[Dictionary] = [
	{"id": "welcome", "title": "Meet the Valley", "body": "An optional look around. Your farm pauses during this tour. Leave whenever you like.", "label": "Look around →"},
	{"id": "market", "title": "Seed market", "body": "Click the market to browse. Seeds cost 75% of each variety’s base price.", "focus": "market"},
	{"id": "sell", "title": "The barn", "body": "Click the barn to compare what you hold and what it is worth. F sells your selected raw crop.", "focus": "barn"},
	{"id": "inventory", "title": "Your inventory", "body": "Press I to inspect your crops, seeds and tools."},
	{"id": "tools", "title": "Toolsmith", "body": "Click the toolsmith to browse wider tools. Upgrades cover more beds per click.", "focus": "tools"},
	{"id": "quests", "title": "Local challenges", "body": "Click the challenge board for goals and rewards. Claim rewards after meeting each goal.", "focus": "quests"},
	{"id": "ducks", "title": "Duck Patrol", "body": "Click Ducks to browse a helper that clears pests. Up to two ducks can patrol your farm.", "focus": "duck_patrol"},
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
		game.hud.show_panel("loss_notices", game.state)
		game.conversation.voice.begin_line("tess", game.state.NpcRoster.weather_cost(game.state).length(), true)
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
		return ["coins", "market", "barn", "inventory", "tools", "quests", "duck_patrol", "stock", "menu"]
	return ["coins", "market", "barn"] if _index() >= 1 else []

func allowed_actions() -> Array[String]:
	var result: Array[String] = ["close", "save", "graphics", "graphics:", "tutorial:next", "tutorial:skip"]
	if _tour_only():
		result.append_array(["market", "sell_potatoes", "grade:", "barn", "inventory", "winter_stores", "inventory_tab:", "tools", "quests", "duck_patrol", "menu", "pause", "help", "toggle_details:"])
		return result
	for feature: String in _features():
		if feature != "coins": result.append(feature)
	if "barn" in _features(): result.append("inventory_tab:crops")
	for tool: String in _tools(): result.append("tool:" + tool)
	if current_id() == "market": result.append("buy:russet:1")
	if current_id() == "sell": result.append_array(["sell:russet:", "quick_sell", "sell_potatoes", "market_sell", "quantity_minus", "quantity_plus", "market_all", "history_older", "history_newer"])
	if current_id() in ["grow", "winter"]: result.append_array(["quick_sell", "sell_potatoes", "sell:russet:", "market_sell", "market_all", "quantity_minus", "quantity_plus", "grade:"])
	if current_id() == "plant": result.append("crop:russet")
	if current_id() == "loss": result.append("loss_notices")
	return result

func allows_action(action: String) -> bool:
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
		return game.state.plots[index].unlocked and tool in ["hoe", "water", "harvest"] and (id == "winter" or index != _plot_index())
	# A different empty bed is a valid choice; move the cue to that bed.
	if id == "hoe" and tool == "hoe" and index >= 0 and index < game.state.plots.size():
		var candidate: Dictionary = game.state.plots[index]
		if candidate.unlocked and int(candidate.stage) == 0 and not candidate.tilled:
			game.state.tutorial_progress.plot = index
			refresh()
	return id in ["hoe", "plant", "water", "harvest"] and index == _plot_index() and tool == id

func explain_block() -> void:
	if not active: return
	var message: String = "This tour only previews shops. Resume farming to use them."
	if not _tour_only():
		var step: Dictionary = _steps()[_index()]
		refresh()
		message = "That action is not part of this step. You can skip the guided year to farm freely."
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
			var seconds: int = ceili(game.state.season_clock.remaining(game.state.season_seconds()) / WAIT_SPEED)
			body = "Spring is passing at 10×. Summer in %ds.\nIris will warn us before one small storm. Harvest the other ripe starter beds with tool 4 while Iris watches the sky." % seconds
			wait_label = "Summer in %ds · 10×" % seconds
		else:
			forecaster = true
			title = "Iris · Summer warning"
			var seconds: int = ceili(game.state.climate.data.timer)
			body = "Iris, on the radio: a small storm is coming in %ds. Watch the sky and your gold bed.\nThe warning runs at 1×. Harvest the other starter beds now; Tess will show the loss on the gold bed." % seconds
			wait_label = "Storm in %ds · 1×" % seconds
	elif current_id() == "winter":
		var left: float = (3 - game.state.season_clock.season) * game.state.season_seconds() - game.state.season_clock.seconds
		var ripe: int = game.state.plots.filter(func(bed): return int(bed.stage) == 3 and bed.crop != "icecap").size()
		if ripe > 0:
			body = "Harvest %d remaining ripe bed%s with tool 4. The calendar pauses so the guide cannot leave them to die in the cold. Unsold sacks stay in the barn." % [ripe, "" if ripe == 1 else "s"]
			wait_label = "Harvest remaining beds · time paused"
		else:
			body += "\nTend or hoe the other beds while time runs at 10×."
			wait_label = "Accounts in %ds · 10×" % ceili(left / WAIT_SPEED)
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
		"grow": done = not game.state.tutorial_loss().is_empty()
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
