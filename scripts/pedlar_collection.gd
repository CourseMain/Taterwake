extends VBoxContainer
## V1 collection only. Hanging and swapping wait for Tess in part J.
const Kit = preload("res://scripts/ui_kit.gd")
const Model = preload("res://scripts/pedlar_state.gd")
func setup(hud, superstitions: bool) -> void:
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation",ceili(10*Kit.unit(hud)))
	grid.add_theme_constant_override("v_separation",ceili(10*Kit.unit(hud))); add_child(grid)
	if superstitions:
		for id: String in hud._state.pedlar.data.superstitions:
			var rarity: String = "common"
			for tier: String in Model.SUPERSTITIONS:
				if id in Model.SUPERSTITIONS[tier]: rarity = tier
			_card(hud,grid,"superstition_card",id,id,"Takes effect next Winter" if id in hud._state.pedlar.data.hooks else "Not hung yet",rarity)
	else:
		for item: Dictionary in hud._state.pedlar.data.oddities:
			_card(hud,grid,"oddity",item.crop,item.name,"Sells for grade price plus 500.","uncommon")
		if hud._state.pedlar.data.stone:
			_card(hud,grid,"stone","stone","Lucky stone","It does nothing. Keep it.","common")
func _card(hud, grid: GridContainer, kind: String, id: String, title: String, line: String, rarity: String) -> void:
	var u: float = Kit.unit(hud)
	var card = preload("res://scripts/kit_card.gd").new(); card.unit = u; card.edge = Kit.RARITIES[rarity]
	card.name = "Collected_"+title.replace(" ","_")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = maxf(0,(hud._body.custom_minimum_size.x-10*u)/2)
	card.add_theme_stylebox_override("panel",Kit.skin(Kit.PAPER,card.edge,8,12,u)); grid.add_child(card)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",ceili(5*u)); card.add_child(body)
	var picture = preload("res://scripts/pedlar_picture.gd").new(); picture.kind = kind; picture.id = id
	picture.set_meta("oddity_name",title); picture.custom_minimum_size = Vector2(68,68)*u; body.add_child(picture)
	for words in [[title,18,true],[line,14,false]]:
		var text: Label = Kit.label(hud,words[0],words[1],Kit.INK,words[2]); text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(text)
