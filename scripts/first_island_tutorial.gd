extends Node
## A small, saved first harvest and a tour of the Valley. No forced purchases
## beyond one Russet seed, no forced wagers, and no island-completion rewards.

const STEPS: Array[Dictionary] = [
	{"id": "welcome", "title": "Welcome to Taterland", "body": "Let's grow one potato together, then meet the island's helpers. Prices and pests will wait for you. Take your time.", "next": true, "label": "Show me around"},
	{"id": "walk", "title": "A little wander", "body": "Click an open patch of ground to walk there, or use WASD / arrow keys. Scroll or pinch your trackpad to zoom. Try moving a few steps."},
	{"id": "market", "title": "Meet the seed seller", "body": "Click the marked Farmer's Market, then buy 1 Russet seed. Seed prices normally follow crop values; today the market is calm.", "focus": "market"},
	{"id": "hoe", "title": "1 · Prepare the soil", "body": "Your first tool is the hoe. Press 1, then click the marked empty bed. Your farmer walks over and tills it. One action at a time.", "tool": "hoe"},
	{"id": "plant", "title": "2 · Plant a Russet", "body": "Press 2 for Seeds, then click the same marked bed. The seed tray appears only while you use seeds. Russets are quick, friendly starter potatoes.", "tool": "plant"},
	{"id": "water", "title": "3 · Give it a drink", "body": "Press 3, then click your planted bed. Crops need watering once before they grow. You do the farming; the clock handles the growing.", "tool": "water"},
	{"id": "grow", "title": "Watch it grow", "body": "A watered Russet takes about 10 seconds to ripen. Look for its full leafy plant. You can move or zoom while you wait. Nothing will attack it."},
	{"id": "harvest", "title": "4 · Your first harvest", "body": "Press 4, then click the marked ripe bed. Potatoes go into storage first. Harvesting and selling are separate, so you choose when to cash in.", "tool": "harvest"},
	{"id": "sell", "title": "Meet the barn keeper", "body": "Click the marked Barn and sell your Russets. The coins at the top are your spending money. Later, a good stock price makes the same harvest worth more.", "focus": "barn"},
	{"id": "inventory", "title": "Everything has a place", "body": "Press I to open Inventory. Crops, seeds, mutations, tools and clothing live here. Gear fits one item per body slot; its bonuses work while equipped.", "panel": "inventory"},
	{"id": "tools", "title": "Meet the toolsmith", "body": "Click the marked Tool Upgrades stall. Better tools work more beds with each action. Field and barn upgrades add room. Have a look; buying can wait until after the tour.", "focus": "tools", "panel": "tools"},
	{"id": "builds", "title": "Wash, sort and specialize", "body": "Click Wash & Sort. You start as a Farmer. Rolls can unlock Gambler, Investor, Scientist and Industrialist builds, each with different strengths. This is also your processing workshop.", "focus": "builds", "panel": "builds"},
	{"id": "quests", "title": "Meet the challenge keeper", "body": "Click Farming Challenges. These goals reward ordinary farming, smart buying and well-timed sales. Work toward them as you play; you do not need to finish the island during this tour.", "focus": "quests", "panel": "quests"},
	{"id": "roll", "title": "Meet the Roll House host", "body": "Click the Roll House to see gear, build crates and reward chances. Rolls spend earned game coins. Bigger stakes change the odds; keep money for seeds. No roll is required now.", "focus": "roll", "panel": "roll"},
	{"id": "pest_intro", "title": "Ready to meet a pest?", "body": "Normally pests arrive at random or after ripe crops sit for 25 seconds. They eat crop yield. Next, we'll place one harmless practice pest on a marked bed.", "next": true, "label": "Try the sprayer"},
	{"id": "pest", "title": "5 · Shoo that pest", "body": "Press 5 for the sprayer, then click the marked crop. Walk over and spray it clean. This practice pest cannot damage your potatoes, and no other pests can arrive yet.", "tool": "pest"},
	{"id": "ducks", "title": "Meet Duck Patrol", "body": "Click the marked duck pond. Hire and train ducks to clear pests for you: one here, two on the Shores, three in winter. You can still use your sprayer any time.", "focus": "duck_patrol", "panel": "duck_patrol"},
	{"id": "stocks", "title": "Catch the next big price", "body": "The stock timer tracks a surge every 3 minutes. Surges last 5 seconds and can reach +3,000%. Hold potatoes, then sell with F. The timer starts fresh after this tour.", "next": true},
	{"id": "dock", "title": "Meet the dock keeper", "body": "Click the marked dock to preview travel. Golden Shores brings buyer contracts; Frosthollow brings a furnace. Both unlock through farming progress. Stay here and build your farm at your own pace.", "focus": "island", "panel": "island"},
	{"id": "finish", "title": "Your farm, your pace", "body": "You know the loop: buy, hoe, plant, water, harvest, sell. The three-line menu holds everything else, including this tour. Start farming when you're ready; your first surge is 3 minutes away.", "next": true, "label": "Let's farm!"},
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
		body = "About %ds to ripe. Water once, then let it grow. You can move or zoom while you wait. Nothing will attack your crops during the tour." % seconds
	if _tour_only() and current_id() == "market":
		body = "Click the marked Farmer's Market. Buy seeds here, then plant and water them. Seeds follow crop prices, so compare costs before a big purchase. This replay does not spend your coins."
		can_continue = visited
	if _tour_only() and current_id() == "sell":
		body = "Click the marked Barn. Harvested potatoes wait here until you sell. Compare their price before cashing in, and expand storage when you need room. No sale is needed during this replay."
		can_continue = visited
	if _tour_only() and current_id() == "welcome":
		body = "Take a quick tour of the Valley's helpers. Your farm is paused while you look around. This replay keeps your crops and coins, and does not require any purchases."
	if _tour_only() and current_id() == "pest_intro":
		body = "Pests arrive at random or after ripe crops sit for 25 seconds. Press 5 and click an infested crop to walk over and spray. This replay leaves your crops alone."
	if _tour_only() and current_id() == "stocks":
		body = "The timer tracks a surge every 3 minutes. Surges last 5 seconds and can reach +3,000%. Hold potatoes, then sell with F. Your paused market resumes when this replay ends."
	if _tour_only() and current_id() == "finish":
		body = "Buy, hoe, plant, water, harvest, sell. Use the three-line menu for everything else. Your farm and market will resume where you left them when you close this tour."
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
		"continue_label": str(step.get("label", "Next")) if not (_tour_only() and current_id() == "pest_intro") else "Next",
		"focus": focus, "allowed_actions": allowed_actions()})
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
