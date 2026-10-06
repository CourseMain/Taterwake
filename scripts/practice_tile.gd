extends "res://scripts/kit_card.gd"
## The Segment 22 tile component. It presents a rule; it never applies one.
const DEFINITIONS := {
	"second_sowing":{"name":"Second sowing", "line":"A second planting gives one more tonne.", "rarity":"common", "drawing":"sowing"},
	"cold_store":{"name":"Cold store", "line":"Stored potatoes don't age in a storm year.", "rarity":"uncommon", "drawing":"store"},
	"duck_patrol":{"name":"Duck patrol", "line":"Ducks eat the first pest wave.", "rarity":"rare", "drawing":"duck"},
	"blue_pearl":{"name":"Blue Pearl", "line":"Tolerates frost. Sells like Golden.", "rarity":"found", "drawing":"pearl"},
}
var rule_id: String = ""
func setup(hud, id: String) -> void:
	rule_id = id; unit = Kit.unit(hud); edge = Kit.RARITIES[DEFINITIONS[id].rarity]
	custom_minimum_size = Vector2(185, 260) * unit if Kit.desktop(hud) else Vector2(150, 200) * unit
	add_theme_stylebox_override("panel", Kit.skin(fill, edge, 12, 12, unit))
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", ceili(6 * unit)); add_child(column)
	var drawing = preload("res://scripts/practice_picture.gd").new(); drawing.kind = DEFINITIONS[id].drawing
	drawing.custom_minimum_size = Vector2(84,84) * unit; drawing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; column.add_child(drawing)
	for field in ["name", "line"]:
		var words: Label = Kit.label(hud, DEFINITIONS[id][field], 22 if field == "name" else 14, Kit.INK if field == "name" else Kit.MUTED, field == "name")
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; words.custom_minimum_size.x = 120 * unit; column.add_child(words)
