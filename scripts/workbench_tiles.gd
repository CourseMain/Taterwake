extends RefCounted
const Place = preload("res://scripts/place_ui.gd")
const Board = preload("res://scripts/place_board.gd")
const ACCENT := Color("7b684c")
static func build(page) -> void:
	var hud = page.hud
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Place.INK, 18, 3, Place.WOOD))
	Place.header(hud, page, "BRAM’S WORKBENCH", ACCENT, "bram")
	page._wallet = hud._wrap("", 14, Place.PAPER); page._wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; page.add_child(page._wallet)
	var bench := Board.new(); bench.board_kind = "peg"; bench.name = "PegboardWorkbench"
	bench.add_theme_stylebox_override("panel", Place.skin(Place.WOOD, 12, 3, Place.WOOD.darkened(.2))); page.add_child(bench)
	var grid: GridContainer = page._grid(bench)
	for tool in ["hoe", "water", "harvest", "expansion", "irrigation"]:
		var action: String = "climate_fund:irrigation" if tool == "irrigation" else "upgrade:" + tool
		var tile := PanelContainer.new(); tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tile.name = "ToolTile_" + tool
		tile.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 10, 7)); grid.add_child(tile); hud._refs[action + ":card"] = tile
		var body: VBoxContainer = hud._vbox(6); tile.add_child(body)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); body.add_child(row)
		row.add_child(hud._icon({"kind":"metric" if tool in ["expansion", "irrigation"] else "tool", "id":"beds" if tool == "expansion" else ("drop" if tool == "irrigation" else tool)}, 48))
		var title: Label = hud._wrap({"hoe":"Hoe", "water":"Watering can", "harvest":"Harvest scythe", "expansion":"Open more Home beds", "irrigation":"Sprinklers"}[tool], 20, Place.INK, true); row.add_child(title)
		if tool == "expansion": hud._refs.expansion_title = title
		var level: Label = hud._label("", 16, Place.INK); row.add_child(level); page._levels[tool] = level
		level.visible = tool != "expansion"
		var effect: Label = hud._wrap("", 14, Place.MUTED); body.add_child(effect); hud._refs[action + ":detail"] = effect
		var button: Button = hud._button("", action); Place.pill(button, ACCENT, true); body.add_child(button); hud._refs[action] = button
		if tool == "expansion": body.add_child(hud._wrap("Rent Low or Hill · at the Winter accounts", 14, Place.MUTED))
		if tool == "irrigation":
			var practice: Button = hud._button("Water practice", "climate_operate:lesson_start"); Place.pill(practice, ACCENT); body.add_child(practice); hud._refs.climate_practice = practice
static func refresh(page) -> void:
	var hud = page.hud; var farm = hud._state
	page._wallet.text = "Balance " + farm.money(farm.coins)
	for tool in page._levels:
		page._levels[tool].text = Place.pips(int(farm.climate.data.projects.get("irrigation", 0)) if tool == "irrigation" else int(farm.tools.get(tool, 0)), 2 if tool == "irrigation" else 3)
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
	var level: int = int(farm.climate.data.projects.get("irrigation", 0)); var cost: float = farm.ClimateSystem.PROJECTS.irrigation.cost * (level + 1)
	hud._refs["climate_fund:irrigation:detail"].text = "%d tank water per patch" % (4 if level == 2 else 6)
	hud._set_purchase_button("climate_fund:irrigation", "Installed" if level == 2 else "Install · " + farm.money(cost), cost, level == 2)
	hud._refs.climate_practice.visible = level > 0; hud._refs.climate_practice.disabled = farm.run_over or farm.climate.data.phase != "calm"
static func layout(page) -> void:
	Place.compact(page)
	var touch: bool = is_instance_valid(page.hud.get_parent().get("touch_controls")) and page.hud.get_parent().touch_controls.enabled
	for grid in page._grids: grid.columns = 1 if page.size.x < 650 else (3 if page.size.x >= 850 else 2)
	for button in page.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = page.hud.touch_target() if touch else 44
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, page.hud.touch_target() if touch else 44)
		button.add_theme_font_size_override("font_size", 20 if touch else 15)
	for label in page.find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(20, label.get_theme_font_size("font_size")))
