extends RefCounted
## Exact tokens from the owner's UI kit; dimensions are screen pixels.
const INK := Color("1b4332")
const INK2 := Color("235640")
const PAPER := Color("fbf7e6")
const PAPER2 := Color("eee8d2")
const WOOD := Color("8a5a3c")
const WOOD2 := Color("6a4430")
const CREAM := Color("fffdf2")
const RULE := Color("cdbf9f")
const MUTED := Color("5f6b60")
const MONEY := Color("f0b429")
const RED := Color("e0583a")
const CROPS := {"russet":Color("b8803f"), "giant":Color("d98a4f"), "golden":Color("ffd23f"), "sunburst":Color("ff9f1c"), "icecap":Color("7fe3ff"), "blue_pearl":Color("7fe3ff")}
const KEEPERS := {"nell":Color("4f8fa8"), "mara":Color("5fb33a"), "tess":Color("e0583a"), "iris":Color("3fa9ff"), "bram":Color("7a7f8c"), "pip":MONEY, "edwin":Color("4f8fa8"), "fennick":Color("a2703f")}
const RARITIES := {"common":Color("7fc47a"), "uncommon":MONEY, "rare":RED, "found":Color("3fa9ff")}
const Type = preload("res://scripts/ui_type.gd")
static func desktop(hud) -> bool:
	var touch = hud.get_parent().get("touch_controls")
	return not is_instance_valid(touch) or not touch.enabled
static func pixels(hud, tier: int) -> int:
	return (18 if tier == 22 else tier) if desktop(hud) else ceili(tier / maxf(.1, hud._ui_scale))
static func unit(hud) -> float: return 1.0 if desktop(hud) else 1.0 / maxf(.1, hud._ui_scale)
static func skin(fill: Color, edge: Color = WOOD, padding: float = 12, radius: float = 12, scale: float = 1, shadow: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill; box.border_color = edge
	box.set_border_width_all(ceili(3 * scale)); box.set_corner_radius_all(ceili(radius * scale))
	box.set_content_margin_all(padding * scale)
	box.shadow_color = WOOD2; box.shadow_size = ceili(4 * scale) if shadow else 0
	box.shadow_offset = Vector2(0, 4 * scale) if shadow else Vector2.ZERO
	box.set_meta("surface_fill", fill); box.set_meta("surface_material", "wood" if fill == WOOD else ("ink" if fill in [INK, INK2] else "paper"))
	return box
static func label(hud, words: String, tier: int = 16, colour: Color = INK, display: bool = false) -> Label:
	var text: Label = hud._wrap(words, tier, colour, display)
	text.set_meta("kit_type", true); text.set_meta("text_tier", tier)
	text.add_theme_font_override("font", Type.face(Type.DISPLAY if display else Type.BODY, 400))
	text.add_theme_font_size_override("font_size", pixels(hud, tier))
	return text
static func button(hud, words: String, action: String, fill: Color = WOOD, picture: Dictionary = {}) -> Button:
	var control: Button = hud._button(words, action)
	var u: float = unit(hud)
	control.set_meta("kit_type", true)
	control.add_theme_font_override("font", Type.face(Type.DISPLAY))
	control.set_meta("plain_control", picture.is_empty())
	if not picture.is_empty(): control.picture = picture; control.picture_pixels = 44
	for variant in ["normal", "hover", "pressed", "disabled"]:
		control.add_theme_stylebox_override(variant, skin(fill.darkened(.08) if variant == "pressed" else fill, fill, 12, 12, u))
	for variant in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: control.add_theme_color_override(variant, CREAM if fill in [WOOD, KEEPERS.mara] else INK)
	control.custom_minimum_size = Vector2(44, 44) * u
	return control
static func configure(hud, board: bool = false) -> void:
	hud._modal_title.hide(); hud._modal_subtitle.hide()
	hud._modal_close.visible = hud._panel_kind not in ["farmer", "pause", "menu"]
	hud._modal_close.set_meta("plain_control", true)
	hud._modal_close.get_parent().visible = hud._modal_close.visible
	hud._modal_trade_footer.hide()
	hud._body.add_theme_constant_override("separation", ceili(10 * unit(hud)))
	hud._modal_card.set_meta("kit_screen", true)
	hud._modal_card.unit = unit(hud); hud._modal_card.fill = WOOD if board else PAPER
	hud._modal_card.queue_redraw()
	hud._modal_card.add_theme_stylebox_override("panel", skin(WOOD if board else PAPER, WOOD, 14 if board else 12, 16 if board else 14, unit(hud)))
	(hud._modal.get_child(0) as ColorRect).color = Color(INK, .30)
static func fit(hud) -> void:
	if not hud._modal_card.get_meta("kit_screen", false): return
	var u: float = unit(hud)
	var view: Vector2 = hud.root.size
	var wide: bool = desktop(hud)
	var target: float = {"farmer":600, "menu":780, "pause":780, "accounts":960, "market":1120, "barn":900, "grades":760, "pedlar":760, "practice":900, "sale_reveal":780}.get(hud._panel_kind, 780) if wide else 390
	var width: float = minf(target * u, view.x - (64 if wide else 24) * u)
	var scroll: ScrollContainer = hud._body.get_parent()
	var card_only: bool = hud._panel_kind in ["farmer", "menu", "pause", "grades", "practice", "sale_reveal", "pedlar"] or hud._panel_kind == "market" and hud._market_selling
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if card_only else ScrollContainer.SCROLL_MODE_AUTO
	hud._body.custom_minimum_size.x = maxf(0, width - 30 * u)
	var height: float = minf(view.y - 48 * u, hud.modal_content_height())
	var receipt_space: float = hud._purchase_box.size.y + 24 if wide and hud._purchase_box.is_visible_in_tree() and not hud._purchase_receipt.is_empty() else 0
	var notice_space: float = hud._toast_box.get_combined_minimum_size().y + 32 if wide and hud._toast_box.visible else 0
	height = minf(height, view.y - receipt_space - notice_space - 48 * u)
	if hud._panel_kind == "farmer": height = minf(view.y - 32 * u, (668 if wide else 518) * u)
	elif hud._panel_kind in ["menu", "pause"]: height = (350 if wide else 268) * u
	var rect := Rect2((view - Vector2(width, height)) * .5, Vector2(width, height))
	rect.position.y = receipt_space + (view.y - receipt_space - notice_space - height) * .5
	hud._modal_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud._modal_card.position = rect.position; hud._modal_card.size = rect.size
	hud.fit_text(hud._modal_card)
