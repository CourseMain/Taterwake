extends RefCounted
const SPUDION = preload("res://assets/fonts/SpudionGlyph.ttf")
const BODY = preload("res://assets/fonts/AtkinsonHyperlegible.ttf")
const DISPLAY = preload("res://assets/fonts/Slackey.ttf")
const SIGN = DISPLAY
const SHOP = DISPLAY
const EDITORIAL = DISPLAY
const BODY_BOLD = preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")
const SYMBOLS = preload("res://assets/fonts/NotoSansSymbols.ttf")
const SYMBOLS_2 = preload("res://assets/fonts/NotoSansSymbols2.ttf")
static func face(source: Font, weight: float = 600.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = BODY_BOLD if source == BODY and weight >= 600 else source
	font.fallbacks = [SPUDION, SYMBOLS, SYMBOLS_2]
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font

static func uses_symbols(words: String) -> bool:
	return words.contains("→") or words.contains("●") or words.contains("○")
