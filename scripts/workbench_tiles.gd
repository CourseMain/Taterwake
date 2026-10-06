extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const Board = preload("res://scripts/place_board.gd")
const ACCENT := Color("7b684c")
static func build(page) -> void:
	var hud = page.hud
	hud.Kit.configure(hud)
	Place.header(hud, page, "Oda’s workbench", ACCENT, "bram")
	page._wallet = hud._wrap("", 14, Place.PAPER); page._wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; page.add_child(page._wallet)
	var bench := Board.new(); bench.board_kind = "peg"; bench.name = "PegboardWorkbench"
	bench.add_theme_stylebox_override("panel", Place.skin(Place.WOOD, 12, 3, Place.WOOD.darkened(.2))); page.add_child(bench)
	var grid: GridContainer = page._grid(bench)
	grid.columns = 2 if hud.Kit.desktop(hud) else 1
	for tool in ["hoe", "water", "harvest", "expansion"]:
		var action: String = "upgrade:" + tool
		var tile := PanelContainer.new(); tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tile.name = "ToolTile_" + tool
		tile.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 10, 7)); grid.add_child(tile); hud._refs[action + ":card"] = tile
		var body: VBoxContainer = hud._vbox(6); tile.add_child(body)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); body.add_child(row)
		row.add_child(hud._icon({"kind":"metric" if tool == "expansion" else "tool", "id":"beds" if tool == "expansion" else tool}, 48))
		var title: Label = hud._wrap({"hoe":"Hoe", "water":"Watering can", "harvest":"Harvest scythe", "expansion":"Open more Home beds"}[tool], 20, Place.INK, true); row.add_child(title)
		if tool == "expansion": hud._refs.expansion_title = title
		var level: Label = hud._label("", 16, Place.INK); row.add_child(level); page._levels[tool] = level
		level.visible = tool != "expansion"
		var effect: Label = hud._wrap("", 14, Place.MUTED); body.add_child(effect); hud._refs[action + ":detail"] = effect
		var button: Button = hud._button("", action); Place.pill(button, ACCENT, true); body.add_child(button); hud._refs[action] = button
		if tool == "expansion": body.add_child(hud._wrap("Rent Low or Hill · at the Winter accounts", 14, Place.MUTED))
	var barn := PanelContainer.new(); barn.add_theme_stylebox_override("panel", Place.skin()); page.add_child(barn)
	var barn_body: VBoxContainer = hud._vbox(6); barn.add_child(barn_body)
	barn_body.add_child(hud._wrap("Barn extension", 22, Place.INK, true))
	var detail: Label = hud._wrap("", 14, Place.MUTED); barn_body.add_child(detail); hud._refs["upgrade:barn:detail"] = detail
	var upgrade: Button = hud._button("", "upgrade:barn"); barn_body.add_child(upgrade); hud._refs["upgrade:barn"] = upgrade
static func refresh(page) -> void:
	var hud = page.hud; var farm = hud._state
	var rank: int = farm.barn_level
	var barn_cost: float = farm.BARN_COSTS[mini(2, rank)]
	hud._refs["upgrade:barn:detail"].text = "Maximum capacity" if rank >= 3 else "+%d t storage" % roundi(200 * pow(4, rank))
	hud._set_purchase_button("upgrade:barn", "Complete" if rank >= 3 else "Open · " + farm.money(barn_cost), barn_cost, rank >= 3)
	page._wallet.text = "Balance " + farm.money(farm.coins)
	for tool in page._levels:
		page._levels[tool].text = Place.pips(int(farm.tools.get(tool, 0)), 3)
	var field: String = "home"
	for id in farm.Land.IDS:
		if farm.Land.active(farm, id) and not farm.field_expansion_info(id).complete: field = id; break
	var land: Dictionary = farm.field_expansion_info(field)
	hud._refs.expansion_title.text = "Open more Home beds" if field == "home" else "Open more " + farm.Land.NAMES[field] + " beds"
	hud._refs["upgrade:expansion:detail"].text = "Open more Home beds · " + farm.format_number(land.cost) + " · any season" if field == "home" and not land.complete else farm.Land.NAMES[field] + (" · All beds open" if land.complete else " · open more beds · any season")
	var expand: Button = hud._refs["upgrade:expansion"]
	expand.set_meta("action", "upgrade:expansion:" + field); expand.set_meta("hud_action", expand.get_meta("action"))
	for c in expand.pressed.get_connections(): expand.pressed.disconnect(c.callable)
	expand.pressed.connect(func(): hud._act("upgrade:expansion:" + field))
	hud._set_purchase_button("upgrade:expansion", "Open · " + farm.money(land.cost) if not land.complete else "All beds open", land.cost, land.complete)
static func layout(page) -> void:
	Place.compact(page)
	for grid in page._grids: grid.columns = 2 if page.hud.Kit.desktop(page.hud) else 1
	for button in page.find_children("*", "Button", true, false):
		if str(button.get_meta("hud_action", "")).begins_with("upgrade:"):
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 44 * page.hud.Kit.unit(page.hud)
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, button.custom_minimum_size.y)
	page.hud.fit_text(page)
