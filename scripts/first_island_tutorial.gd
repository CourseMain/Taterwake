extends Node
## A small, saved first harvest and a tour of the Valley. No forced purchases
## beyond one Russet seed, no forced wagers, and no island-completion rewards.

const STEPS: Array[Dictionary] = [
	{"id": "welcome", "title": "Your first spud!", "body": "Grow. Sell. Meet the locals.\nPests and stock surges can wait.", "next": true, "label": "Start farming →", "icon": "russet"},
	{"id": "walk", "title": "Stretch those legs", "body": "Click the ground to walk.\nWASD works too. Scroll to zoom.", "key": "WASD"},
	{"id": "market", "title": "Grab a seed", "body": "Follow the arrow to the market.\nBuy 1 Russet seed.", "focus": "market", "icon": "russet"},
	{"id": "hoe", "title": "Break new ground", "body": "Click the gold bed to till it.", "tool": "hoe", "key": "1 · HOE"},
	{"id": "plant", "title": "Plant your spud", "body": "Click the gold bed to plant.", "tool": "plant", "key": "2 · SEEDS"},
	{"id": "water", "title": "A little drink", "body": "Water the gold bed once.", "tool": "water", "key": "3 · WATER"},
	{"id": "grow", "title": "Here it grows…", "body": "A few seconds to your first harvest.", "icon": "russet"},
	{"id": "harvest", "title": "Dig in!", "body": "Click the gold bed.\nYour potatoes go into storage.", "tool": "harvest", "key": "4 · HARVEST"},
	{"id": "sell", "title": "Your first payday", "body": "Follow the arrow to the barn.\nSell your Russets.", "focus": "barn"},
	{"id": "inventory", "title": "Your stash", "body": "Open your bag. Crops, gear and loot live here.", "panel": "inventory", "key": "I · INVENTORY"},
	{"id": "tools", "title": "Work more beds", "body": "Visit the toolsmith.\nBigger tools = fewer clicks.", "focus": "tools", "panel": "tools"},
	{"id": "builds", "title": "Pick your style", "body": "Visit Wash & Sort.\nStart Farmer. Unlock four more builds.", "focus": "builds", "panel": "builds"},
	{"id": "quests", "title": "Farm. Get rewarded.", "body": "Meet the challenge keeper.\nEarn rewards while you grow and sell.", "focus": "quests", "panel": "quests"},
	{"id": "roll", "title": "Meet the Roll House", "body": "Gear. Builds. Rare loot.\nHave a look—save your coins for now.", "focus": "roll", "panel": "roll"},
	{"id": "pest_intro", "title": "An uninvited guest", "body": "Pests nibble crops left too long.\nTry one harmless practice pest.", "next": true, "label": "Try the sprayer →"},
	{"id": "pest", "title": "Shoo!", "body": "Spray the gold bed.\nThis practice pest cannot hurt it.", "tool": "pest", "key": "5 · SPRAYER"},
	{"id": "ducks", "title": "Your feathered crew", "body": "Visit Duck Patrol.\nHire ducks. Upgrade their speed.", "focus": "duck_patrol", "panel": "duck_patrol"},
	{"id": "stocks", "title": "Catch the boom", "body": "Every 3 min: +500–2,999%.\n10 seconds to sell with F!", "next": true, "key": "F · SELL"},
	{"id": "dock", "title": "To the ferry!", "body": "Follow the path. Press E at the dock.\nOr click the ferry to walk there.", "focus": "island", "panel": "island"},
	{"id": "finish", "title": "Make it your farm", "body": "Plant → grow → sell → repeat.\nYour first surge is 3 minutes away.", "next": true, "label": "Let's farm! →"},
]
const TOUR_SKIP: Array[String] = ["walk", "hoe", "plant", "water", "grow", "harvest", "pest"]
var game: Node
var active: bool = false
var visited: bool = false
var movement_origin: Vector3
var sale_baseline: float = 0.0
var cue_count: int = 0

func setup(owner_game: Node) -> void:
	game = owner_game

func start(replay: bool = false) -> void:
	if game.state.current_island != 1:
		game.hud.show_toast("Return to the Valley to take the first-island tour.")
		return
	if replay:
		game.state.tutorial_progress = {"version": 1, "step": 0, "completed": false, "plot": 5, "tour_only": true}
	elif bool(game.state.tutorial_progress.get("completed", false)):
		return
	active = true
	game.state.set_tutorial_active(true)
	game.state.tutorial_progress["step"] = clampi(int(game.state.tutorial_progress.get("step", 0)), 0, STEPS.size() - 1)
	game._cancel_walk()
	_enter_step()

func current_id() -> String:
	return str(STEPS[_index()].id) if active else ""

func _index() -> int:
	return clampi(int(game.state.tutorial_progress.get("step", 0)), 0, STEPS.size() - 1)

func _tour_only() -> bool:
	return bool(game.state.tutorial_progress.get("tour_only", false))

func _plot_index() -> int:
	return clampi(int(game.state.tutorial_progress.get("plot", 5)), 0, game.state.plots.size() - 1)

func _pest_index() -> int:
	return clampi(int(game.state.tutorial_progress.get("pest_plot", 1)), 0, game.state.plots.size() - 1)

func _enter_step() -> void:
	visited = false
	game._cancel_walk()
	game.hud.close_panel()
	movement_origin = game.world.player.position
	sale_baseline = game.state.lifetime_sales
	var id: String = current_id()
	if id == "plant":
		game.state.select_crop("russet")
	if id == "pest":
		var target: int = _pest_index()
		if int(game.state.plots[target].stage) == 0:
			for index: int in range(game.state.plots.size()):
				if int(game.state.plots[index].stage) > 0:
					target = index
					break
		game.state.tutorial_progress["pest_plot"] = target
		if not game.state.spawn_tutorial_pest(target):
			_advance()
			return
	refresh()
	var step: Dictionary = STEPS[_index()]
	if step.has("tool"):
		game._select_tool(str(step.tool))
	game._on_state_changed()
	if id == "pest":
		_cue("pest")
	_save()

func _tools() -> Array[String]:
	var result: Array[String] = []
	if _tour_only():
		return result
	for entry: Array in [[3, "hoe"], [4, "plant"], [5, "water"], [7, "harvest"], [15, "pest"]]:
		if _index() >= int(entry[0]):
			result.append(str(entry[1]))
	return result

func _features() -> Array[String]:
	var result: Array[String] = []
	for entry: Array in [[2, "coins"], [2, "market"], [8, "barn"], [9, "inventory"], [10, "tools"], [11, "builds"], [12, "quests"], [13, "roll"], [16, "duck_patrol"], [17, "stock"], [18, "island"], [19, "menu"]]:
		if _index() >= int(entry[0]):
			result.append(str(entry[1]))
	return result

func allowed_actions() -> Array[String]:
	var result: Array[String] = ["close", "save", "tutorial:next", "tutorial:skip"]
	for feature: String in _features():
		if feature not in ["coins", "stock"]:
			result.append(feature)
	for tool: String in _tools():
		result.append("tool:" + tool)
	if "inventory" in _features():
		result.append("inventory_tab:")
	if current_id() == "market" and not _tour_only():
		result.append("buy:russet:1")
	if current_id() == "sell" and not _tour_only():
		result.append("sell:russet:")
		result.append("quick_sell")
	if current_id() == "plant":
		result.append("crop:russet")
	if current_id() == "finish":
		result.append("pause")
	return result

func allows_action(action: String) -> bool:
	if not active:
		return true
	for allowed: String in allowed_actions():
		if action == allowed or (allowed.ends_with(":") and action.begins_with(allowed)):
			return true
	return false

func allows_tool(tool: String) -> bool:
	return not active or tool in _tools()

func allows_plot(index: int, tool: String) -> bool:
	if not active:
		return true
	var id: String = current_id()
	if id == "pest":
		return index == _pest_index() and tool == "pest"
	var required: Dictionary = {"hoe": "hoe", "plant": "plant", "water": "water", "harvest": "harvest"}
	return required.has(id) and index == _plot_index() and tool == str(required[id])

func refresh() -> void:
	if not active:
		return
	var step: Dictionary = STEPS[_index()]
	var body: String = str(step.body)
	var can_continue: bool = bool(step.get("next", false)) or (step.has("panel") and visited)
	var focus: String = str(step.get("focus", ""))
	if current_id() in ["hoe", "plant", "water", "grow", "harvest"]:
		focus = "plot:%d" % _plot_index()
	elif current_id() == "pest":
		focus = "plot:%d" % _pest_index()
	if current_id() == "grow":
		var plot: Dictionary = game.state.plots[_plot_index()]
		var seconds: int = maxi(0, int(ceil(10.0 - float(plot.elapsed))))
		body = "Ready in %ds.\nYour first payday is growing!" % seconds
	if _tour_only() and current_id() == "market":
		body = "Visit the seed seller.\nSeed costs follow crop prices."
		can_continue = visited
	if _tour_only() and current_id() == "sell":
		body = "Visit the barn.\nStore your harvest. Sell at the right price."
		can_continue = visited
	if _tour_only() and current_id() == "welcome":
		body = "Meet the Valley crew.\nYour farm pauses while you explore."
	if _tour_only() and current_id() == "pest_intro":
		body = "Pests nibble idle crops.\nPress 5, then click a pest to spray."
	if _tour_only() and current_id() == "stocks":
		body = "Every 3 min: a 10-second surge.\nSell with F. Your market is paused."
	if _tour_only() and current_id() == "finish":
		body = "Ready to grow?\nYour farm resumes where you left it."
	var shown_step: int = 0
	var shown_total: int = 0
	for index: int in range(STEPS.size()):
		if _tour_only() and str(STEPS[index].id) in TOUR_SKIP:
			continue
		shown_total += 1
		if index <= _index():
			shown_step += 1
	game.hud.set_tutorial({"title": str(step.title), "body": body, "step": shown_step, "total": shown_total,
		"tools": _tools(), "features": _features(), "continue": can_continue,
		"continue_label": str(step.get("label", "Next stop →")) if not (_tour_only() and current_id() == "pest_intro") else "Next stop →",
		"id": current_id(), "key": str(step.get("key", "")), "tool": str(step.get("tool", "")),
		"tour_only": _tour_only(), "visited": visited, "focus": focus, "allowed_actions": allowed_actions()})
	game.world.set_tutorial_focus(focus)

func update(_delta: float) -> void:
	if not active:
		return
	var id: String = current_id()
	var plot: Dictionary = game.state.plots[_plot_index()]
	var done: bool = false
	match id:
		"walk": done = game.world.player.position.distance_to(movement_origin) >= 1.5
		"hoe": done = bool(plot.tilled)
		"plant": done = int(plot.stage) > 0
		"water": done = bool(plot.watered)
		"grow": done = int(plot.stage) == 3
		"harvest": done = int(plot.stage) == 0 and int(game.state.storage.russet) > 0
		"sell": done = game.state.lifetime_sales > sale_baseline
		"pest": done = not bool(game.state.plots[_pest_index()].pests)
	if done:
		_advance()
	elif id == "grow":
		refresh()

func observe_action(action: String) -> void:
	if not active:
		return
	var step: Dictionary = STEPS[_index()]
	var panel: String = str(step.get("panel", ""))
	if _tour_only() and current_id() in ["market", "sell"]:
		panel = "market" if current_id() == "market" else "barn"
	if action == panel and game.hud.is_panel_open():
		visited = true
		_cue("visit")
		refresh()
	update(0.0)

func observe_purchase(receipt: Dictionary) -> void:
	if active and current_id() == "market" and not _tour_only() and str(receipt.get("kind", "")) == "seeds" and str(receipt.get("id", "")) == "russet":
		_advance()

func next() -> void:
	if not active:
		return
	var step: Dictionary = STEPS[_index()]
	if bool(step.get("next", false)) or (step.has("panel") and visited) or (_tour_only() and current_id() in ["market", "sell"] and visited):
		_advance()

func _advance() -> void:
	if _index() >= STEPS.size() - 1:
		finish()
		return
	_cue("step")
	var index: int = _index() + 1
	while _tour_only() and index < STEPS.size() - 1 and str(STEPS[index].id) in TOUR_SKIP:
		index += 1
	game.state.tutorial_progress["step"] = index
	_enter_step()

func finish() -> void:
	if not active:
		return
	# Remove only the practice infestation; it was never allowed to damage crops.
	if current_id() == "pest":
		var plot: Dictionary = game.state.plots[_pest_index()]
		plot.pests = false
		plot.pest_elapsed = 0.0
	active = false
	game.state.tutorial_progress["completed"] = true
	game.state.set_tutorial_active(false)
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
	if not game.test_mode:
		game.state.save_game()
