extends RefCounted
const BODY = preload("res://assets/fonts/NunitoSans.ttf")
const DISPLAY = preload("res://assets/fonts/Fredoka.ttf")
const SIGN = preload("res://assets/fonts/PatrickHand.ttf")
const EDITORIAL = preload("res://assets/fonts/Oswald.ttf")
static func face(source: Font, weight: float = 600.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = source
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font
