extends VBoxContainer
## Cosmetic purchases live only at Oda's workbench.
const Kit = preload("res://scripts/ui_kit.gd")
const Place = preload("res://scripts/place_ui.gd")
var hud
var tiles: Dictionary = {}
var grid: GridContainer
func setup(owner_hud) -> void:
	hud = owner_hud
	name = "DecorationList"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.configure(hud, true)
	Place.header(hud, self, "Decorations", Kit.KEEPERS.bram, "bram", "Looks nice. That's all.")
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for id: String in hud._state.Decorations.ITEMS:
		var card := PanelContainer.new()
		card.name = "DecorationTile_" + id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", Kit.skin(Kit.PAPER))
		grid.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		card.add_child(body)
		body.add_child(hud._icon({"kind":"decoration", "id":id}, 72))
		body.add_child(Kit.label(hud, hud._state.Decorations.ITEMS[id], 16, Kit.INK, true))
		var site := preload("res://scripts/illustrated_choice.gd").new()
		for words: String in hud._state.Decorations.PLACES: site.add_item(words)
		var fixed: int = hud._state.Decorations.FIXED_PLACES.get(id, -1)
		if fixed >= 0: site.select(fixed); site.disabled = true
		hud._style_choice(site)
		body.add_child(site)
		var buy: Button = Kit.button(hud, "", "", Kit.WOOD, {"kind":"decoration", "id":id})
		buy.pressed.connect(func(): hud._act("decorate:%s:%d" % [id, site.selected]))
		body.add_child(buy)
		tiles[id] = {"buy":buy,"site":site}
	resized.connect(layout)
	refresh()
	layout.call_deferred()
func refresh() -> void:
	for id: String in tiles:
		var bought: bool = hud._state.decorations.has(id)
		var cost: float = hud._state.Balance.DECORATION_COSTS[id]
		tiles[id].buy.text = "Placed" if bought else "Buy · " + hud._state.money(cost)
		tiles[id].buy.disabled = bought or not hud._state.can_purchase(cost)
	layout()
func layout() -> void:
	grid.columns = 3 if Kit.desktop(hud) else 1
	hud.fit_text(self)
	Kit.fit(hud)
