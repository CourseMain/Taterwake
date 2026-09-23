extends Node
## One real harvest. Further introductions belong to optional, contextual help.
const STEPS: Array[Dictionary] = [
	{"id": "welcome", "title": "Grow your first potato", "body": "One seed, one harvest, one sale.\nThen the farm is yours.\nClick to walk; WASD works too.", "next": true, "label": "Start farming →"},
	{"id": "market", "title": "Buy a seed", "body": "Click Seeds, then Buy 1 Russet. Or press B.", "focus": "market", "key": "B · SEEDS"},
	{"id": "hoe", "title": "Prepare the soil", "body": "Hoe selected. Click the gold bed to walk over and till it.", "tool": "hoe", "key": "1 · HOE"},
	{"id": "plant", "title": "Plant your seed", "body": "Seeds selected. Click the same gold bed to plant a Russet.", "tool": "plant", "key": "2 · SEEDS"},
	{"id": "water", "title": "Water once", "body": "Watering can selected. Click the gold bed to start it growing.", "tool": "water", "key": "3 · WATER"},
	{"id": "grow", "title": "Let it grow", "body": "Watered potatoes grow on their own. You can walk around while you wait."},
	{"id": "harvest", "title": "Bring in your crop", "body": "Harvest tool selected. Click the gold bed to put your potatoes in the barn.", "tool": "harvest", "key": "4 · HARVEST"},
	{"id": "sell", "title": "Your first sale", "body": "Press F to sell your Russets. Or click the barn, then Sell all.\nThat finishes the lesson.", "focus": "barn", "key": "F · SELL"},
]
const TOUR: Array[Dictionary] = [
	{"id": "welcome", "title": "Meet the Valley", "body": "An optional look around. Your farm pauses during this tour. Leave whenever you like.", "label": "Look around →"},
	{"id": "market", "title": "Seed market", "body": "Click the market to browse. Seeds follow crop prices, so buying during a boom is expensive.", "focus": "market"},
	{"id": "sell", "title": "The barn", "body": "Click the barn to compare what you hold and what it is worth. F sells your selected raw crop.", "focus": "barn"},
	{"id": "inventory", "title": "Your inventory", "body": "Press I to inspect crops, equipment and Build Crates. Clothing helps only while equipped."},
	{"id": "tools", "title": "Toolsmith", "body": "Click the toolsmith to browse wider tools. Upgrades cover more beds per click.", "focus": "tools"},
	{"id": "builds", "title": "Builds", "body": "Click Builds to inspect your abilities. Farmer starts unlocked; Build Crates unlock the others.", "focus": "builds"},
	{"id": "quests", "title": "Local challenges", "body": "Click the challenge keeper for goals and rewards. Claim rewards after meeting each goal.", "focus": "quests"},
	{"id": "roll", "title": "Roll House", "body": "Click the Roll House to inspect odds. Rolls spend earned coins and can return little. Keep seed money.", "focus": "roll"},
	{"id": "ducks", "title": "Duck Patrol", "body": "Click Ducks to browse a helper that clears pests. Ducks work on the island you visit.", "focus": "duck_patrol"},
	{"id": "dock", "title": "The ferry", "body": "Click the ferry to walk to it, or press E nearby. Sailing needs the island unlock.", "focus": "island"},
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
	if game.state.current_island != 1:
		game.hud.show_toast("Return to the Valley for the optional tour.")
		return
	if replay:
		game.state.tutorial_progress = {"version": 2, "step": 0, "completed": false, "plot": 5, "tour_only": true}
	else:
		_migrate()
		if bool(game.state.tutorial_progress.get("completed", false)):
			return
	active = true
	game.state.set_tutorial_active(true)
	_enter_step()

func _migrate() -> void:
	var progress: Dictionary = game.state.tutorial_progress
	if int(progress.version) >= 2:
		return
	progress.version = 2
	if bool(progress.get("tour_only", false)):
		progress.step = 0
	elif not progress.completed:
		var old_step: int = int(progress.step)
		progress.step = maxi(0, old_step - 1) if old_step >= 2 else old_step
		if old_step >= 9:
			# The first sale already happened. Retire the remaining compulsory tour.
			progress.completed = true
			game.state.set_tutorial_active(false)
			game.state.farm_help.enable()
			_save()

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
	refresh()
	var step: Dictionary = _steps()[_index()]
	if step.has("tool"):
		game._select_tool(str(step.tool))
	game._on_state_changed()
	_save()

func _tools() -> Array[String]:
	var result: Array[String] = []
	if _tour_only(): return result
	for entry: Array in [[2, "hoe"], [3, "plant"], [4, "water"], [6, "harvest"]]:
		if _index() >= int(entry[0]): result.append(str(entry[1]))
	return result

func _features() -> Array[String]:
	if _tour_only():
		return ["coins", "market", "barn", "inventory", "tools", "builds", "quests", "roll", "duck_patrol", "stock", "island", "menu"]
	return ["coins", "market", "barn"] if _index() >= 1 else []

func allowed_actions() -> Array[String]:
	var result: Array[String] = ["close", "save", "graphics", "graphics:", "tutorial:next", "tutorial:skip"]
	if _tour_only():
		result.append_array(["market", "barn", "inventory", "inventory_tab:", "tools", "builds", "quests", "roll", "duck_patrol", "island", "menu", "pause", "help", "toggle_details:"])
		return result
	for feature: String in _features():
		if feature != "coins": result.append(feature)
	for tool: String in _tools(): result.append("tool:" + tool)
	if current_id() == "market": result.append("buy:russet:1")
	if current_id() == "sell": result.append_array(["sell:russet:", "quick_sell"])
	if current_id() == "plant": result.append("crop:russet")
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
		message = str(step.body)
		if step.has("tool"):
			game._select_tool(str(step.tool))
			message = "%s selected again. Click the gold bed." % str(step.tool).capitalize()
	game.hud.show_tutorial_feedback(message)

func refresh() -> void:
	if not active: return
	var step: Dictionary = _steps()[_index()]
	var body: String = str(step.body)
	var focus: String = str(step.get("focus", ""))
	if not _tour_only() and current_id() in ["hoe", "plant", "water", "grow", "harvest"]:
		focus = "plot:%d" % _plot_index()
	if current_id() == "grow":
		var plot: Dictionary = game.state.plots[_plot_index()]
		body = "Ready in %ds. Watering once is enough.\nYou can walk around while it grows." % maxi(0, int(ceil(10.0 - float(plot.elapsed))))
	game.hud.set_tutorial({"title": str(step.title), "body": body, "step": _index() + 1, "total": _steps().size(),
		"tools": _tools(), "features": _features(), "continue": _tour_only() or bool(step.get("next", false)),
		"continue_label": str(step.get("label", "Next place →")), "id": current_id(), "key": str(step.get("key", "")),
		"tool": str(step.get("tool", "")), "tour_only": _tour_only(), "visited": visited, "focus": focus, "allowed_actions": allowed_actions()})
	game.world.set_tutorial_focus(focus)

func update(_delta: float) -> void:
	if not active or _tour_only(): return
	var id: String = current_id()
	var plot: Dictionary = game.state.plots[_plot_index()]
	var done: bool = false
	match id:
		"hoe": done = bool(plot.tilled)
		"plant": done = int(plot.stage) > 0
		"water": done = bool(plot.watered)
		"grow": done = int(plot.stage) == 3
		"harvest": done = int(plot.stage) == 0 and int(game.state.storage.russet) > 0
		"sell": done = game.state.lifetime_sales > sale_baseline
	if done: _advance()
	elif id == "grow": refresh()

func observe_action(action: String) -> void:
	if not active: return
	if _tour_only() and action == str(_steps()[_index()].get("focus", "")) and game.hud.is_panel_open():
		visited = true
	update(0.0)

func observe_purchase(receipt: Dictionary) -> void:
	if active and current_id() == "market" and not _tour_only() and receipt.get("kind") == "seeds" and receipt.get("id") == "russet": _advance()

func next() -> void:
	if active and (_tour_only() or bool(_steps()[_index()].get("next", false))): _advance()

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
	game.hud.close_panel()
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
