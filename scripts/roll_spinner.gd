extends Control
## Decorative reel; the supplied backend result is the only winning outcome.
signal finished(result: Dictionary)
const ItemIcon = preload("res://scripts/item_icon.gd")
const RewardFeedback = preload("res://scripts/reward_feedback.gd")
const ITEM_CATALOG: Dictionary = preload("res://scripts/game_state.gd").ITEM_CATALOG
var _build_deck: bool = false
const CARD_WIDTH: float = 112.0
const STEP: float = 126.0
const DURATION: float = 3.2
const COLORS: Dictionary = {"common": Color("9a98b0"), "rare": Color("6bbdb2"), "epic": Color("b28af3"), "legendary": Color("f3bf61"), "mythic": Color("e588ba"), "jackpot": Color("ffe89a"), "relic": Color("79dfde"), "mystery": Color("f9a1ff"), "build": Color("78b9a5")}
var spinning: bool = false
var _cards: Array[Dictionary] = []
var _result: Dictionary = {}
var _offset: float = STEP * 3.0
var _elapsed: float = 0.0
var _flash: float = 0.0
var _rare_reveal: bool = false
var _reveal_progress: float = 0.0
var _font: Font
var _styles: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _odds: Array[Dictionary] = []
var _odds_signature: String = ""

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 180)
	_font = get_theme_default_font()
	_rng.randomize()
	for tier: String in COLORS:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("fff8e9")
		style.border_color = COLORS[tier]
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		_styles[tier] = style
	for index: int in range(12):
		_cards.append(_filler())
	set_process(false)

func spin_to(result: Dictionary) -> void:
	if spinning:
		return
	_result = result.duplicate(true)
	_build_deck = str(result.get("tier", "")) == "build"
	_rare_reveal = str(result.get("tier", "common")) in ["relic", "mystery"]
	_reveal_progress = 0.0
	_cards.clear()
	for index: int in range(29):
		_cards.append(_filler())
	_cards[23] = {"tier": str(result.get("tier", "common")).to_lower(), "title": str(result.get("title", "Your reward")), "actual": true, "build_id": str(result.get("build_id", "farmer")), "item_id": str(result.get("item_id", ""))}
	_offset = STEP * 3.0
	_elapsed = 0.0
	_flash = 0.0
	spinning = true
	set_process(true)
	queue_redraw()

func set_build_deck(enabled: bool) -> void:
	_build_deck = enabled
	_result.clear()
	_cards.clear()
	for index: int in range(12):
		_cards.append(_filler())
	queue_redraw()

func set_odds(entries: Array) -> void:
	# This RNG only paints preview cards. It never chooses or changes a reward.
	var next_odds: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var tier: String = str(entry.get("tier", ""))
		var chance: float = float(entry.get("chance", 0.0))
		if COLORS.has(tier) and tier != "build" and is_finite(chance) and chance > 0.0:
			next_odds.append({"tier": tier, "chance": chance})
	var signature: String = JSON.stringify(next_odds)
	if signature == _odds_signature:
		return
	_odds_signature = signature
	_odds = next_odds
	if not spinning and _result.is_empty() and not _build_deck:
		_cards.clear()
		for index: int in range(12):
			_cards.append(_filler())
		queue_redraw()

func _preview_tier() -> String:
	var total: float = 0.0
	for entry: Dictionary in _odds:
		total += float(entry.chance)
	if total <= 0.0:
		return "common"
	var draw: float = _rng.randf() * total
	var cumulative: float = 0.0
	for entry: Dictionary in _odds:
		cumulative += float(entry.chance)
		if draw < cumulative:
			return str(entry.tier)
	return str(_odds.back().tier)

func _filler() -> Dictionary:
	if _build_deck:
		var builds: Array[String] = ["farmer", "gambler", "investor", "scientist", "industrialist"]
		var id: String = builds[_rng.randi_range(0, builds.size() - 1)]
		return {"tier": "build", "title": id.capitalize(), "build_id": id, "actual": false}
	if _odds.is_empty():
		return {"tier": "common", "title": "READY TO ROLL", "placeholder": true, "actual": false}
	var tier: String = _preview_tier()
	var gear_options: Array[String] = []
	for item_id: String in ITEM_CATALOG:
		if str(ITEM_CATALOG[item_id].get("kind", "")) == "gear" and str(ITEM_CATALOG[item_id].get("rarity", "")) == tier:
			gear_options.append(item_id)
	if not gear_options.is_empty():
		var item_id: String = gear_options[_rng.randi_range(0, gear_options.size() - 1)]
		return {"tier": tier, "title": str(ITEM_CATALOG[item_id].name), "item_id": item_id, "actual": false}
	var titles: Dictionary = {"common": "SPARE CHANGE", "rare": "LUCKY CAP", "epic": "TRADER'S VISOR", "legendary": "PROSPECTOR HAT", "mythic": "AURORA CROWN", "jackpot": "JACKPOT!", "relic": "MARKET MONOCLE", "mystery": "???"}
	var items: Dictionary = {"rare": "lucky_cap", "epic": "traders_visor", "legendary": "prospectors_hat", "mythic": "aurora_crown", "relic": "market_monocle", "mystery": "loaded_dice"}
	return {"tier": tier, "title": titles[tier], "item_id": items.get(tier, ""), "actual": false}

func _process(delta: float) -> void:
	if spinning:
		_elapsed += delta
		var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
		var curve: float = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		_offset = lerpf(STEP * 3.0, STEP * 23.0, curve)
		if _rare_reveal and t >= 1.0:
			_reveal_progress = clampf((_elapsed - DURATION) / 1.4, 0.0, 1.0)
		if t >= 1.0 and (not _rare_reveal or _reveal_progress >= 1.0):
			spinning = false
			_flash = 1.0 if RewardFeedback.celebrates(str(_result.get("tier", "common"))) else 0.0
			finished.emit(_result.duplicate(true))
	elif _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.8)
	else:
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if _font == null:
		return
	var center_x: float = size.x * 0.5
	for index: int in range(_cards.size()):
		var x: float = center_x + STEP * index - _offset - CARD_WIDTH * 0.5
		if x > size.x + CARD_WIDTH or x < -CARD_WIDTH * 2:
			continue
		_draw_card(_cards[index], Vector2(x, 18))
	# The pin always marks the one result supplied by the game simulation.
	draw_line(Vector2(center_x, 4), Vector2(center_x, 172), Color(1.0, 0.87, 0.52, 0.40), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(center_x - 8, 1), Vector2(center_x + 8, 1), Vector2(center_x, 12)]), Color("ffe5a1"))
	draw_colored_polygon(PackedVector2Array([Vector2(center_x - 8, 180), Vector2(center_x + 8, 180), Vector2(center_x, 169)]), Color("ffe5a1"))
	if _rare_reveal and _reveal_progress > 0.0:
		_draw_artifact_reveal()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.84, 0.51, _flash * 0.24))

func _draw_card(card: Dictionary, position: Vector2) -> void:
	var tier: String = str(card.get("tier", "common"))
	var accent: Color = COLORS.get(tier, COLORS.common)
	var rect: Rect2 = Rect2(position, Vector2(CARD_WIDTH, 144))
	draw_rect(Rect2(position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.24))
	draw_style_box(_styles.get(tier, _styles.common), rect)
	_text("READY" if bool(card.get("placeholder", false)) else ("???" if tier == "mystery" else tier.to_upper()), position + Vector2(0, 19), CARD_WIDTH, 10, Color("4c3a69"))
	var center: Vector2 = position + Vector2(CARD_WIDTH * 0.5, 71)
	var title: String = str(card.get("title", "POTATO"))
	var lowered: String = title.to_lower()
	if not str(card.get("item_id", "")).is_empty():
		ItemIcon.paint(self, {"kind": "gear", "id": str(card.item_id)}, Rect2(center - Vector2(38, 38), Vector2(76, 76)))
	elif tier == "build":
		ItemIcon.paint(self, {"kind": "build", "id": str(card.get("build_id", "farmer"))}, Rect2(center - Vector2(38, 38), Vector2(76, 76)))
	elif "build crate" in lowered:
		ItemIcon.paint(self, {"kind": "build_crate", "id": "build_crate"}, Rect2(center - Vector2(38, 38), Vector2(76, 76)))
	elif "nothing" in lowered or "empty" in lowered or "no luck" in lowered:
		_potato(center, Color("c6bfae"), true)
	elif tier in ["relic", "mystery"]:
		_gem(center, accent)
		draw_arc(center, 37, 0, TAU, 32, accent, 2, true)
		for p: Vector2 in [Vector2(-34, -22), Vector2(32, 24), Vector2(0, -41)]:
			draw_circle(center + p, 3, accent)
	elif tier == "jackpot":
		_dice(center, accent)
	elif tier == "legendary" or "tool" in lowered:
		_tool(center, accent)
	elif tier == "epic" or "luck" in lowered:
		_gem(center, accent)
	else:
		_potato(center, Color("e2b254") if tier != "mythic" else Color("d19ade"), false)
	var short_title: String = title.to_upper()
	if short_title.length() > 15:
		short_title = short_title.substr(0, 14) + "…"
	_text(short_title, position + Vector2(4, 124), CARD_WIDTH - 8, 10, Color("392851"))
	draw_circle(position + Vector2(12, 132), 2, accent)
	draw_circle(position + Vector2(CARD_WIDTH - 12, 132), 2, accent)

func _text(value: String, baseline: Vector2, width: float, size_px: int, color: Color) -> void:
	var measured: Vector2 = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(_font, baseline + Vector2((width - measured.x) * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _potato(center: Vector2, color: Color, sad: bool) -> void:
	draw_set_transform(center, -0.18, Vector2(0.85, 1.10))
	draw_circle(Vector2(3, 4), 29, Color(0.3, 0.15, 0.1, 0.17))
	draw_circle(Vector2.ZERO, 29, color)
	draw_circle(Vector2(-12, -13), 5, color.lightened(0.15))
	for p: Vector2 in [Vector2(-18, 4), Vector2(14, 17), Vector2(18, -10)]:
		draw_circle(p, 2.3, color.darkened(0.23))
	draw_circle(Vector2(-8, -2), 3, Color("392851"))
	draw_circle(Vector2(8, -2), 3, Color("392851"))
	draw_arc(Vector2(0, 10 if sad else 2), 7, PI if sad else 0.0, TAU if sad else PI, 12, Color("392851"), 2, true)
	draw_set_transform(Vector2.ZERO)
	if not sad:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-3, -30), center + Vector2(-15, -43), center + Vector2(5, -37)]), Color("68a073"))

func _gem(center: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(-27, -13), center + Vector2(-14, -31), center + Vector2(15, -31), center + Vector2(29, -13), center + Vector2(0, 31)])
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([points[0], points[1], center + Vector2(0, -12), points[4]]), color.lightened(0.28))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -12), points[2], points[3], points[4]]), color.darkened(0.18))
	draw_line(center + Vector2(-8, -25), center + Vector2(-3, -17), Color.WHITE, 3, true)

func _tool(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-17, 29), center + Vector2(12, -24), Color("79583d"), 8, true)
	draw_line(center + Vector2(-13, 29), center + Vector2(15, -23), Color("bd8650"), 3, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-8, -31), center + Vector2(29, -21), center + Vector2(31, -5), center + Vector2(2, -12)]), color)
	draw_line(center + Vector2(0, -27), center + Vector2(26, -19), color.lightened(0.35), 3, true)

func _dice(center: Vector2, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.border_color = Color("b08440")
	style.set_border_width_all(2)
	draw_set_transform(center, -0.12)
	draw_style_box(style, Rect2(-28, -28, 56, 56))
	for p: Vector2 in [Vector2(-14, -14), Vector2(14, -14), Vector2.ZERO, Vector2(-14, 14), Vector2(14, 14)]:
		draw_circle(p, 4.5, Color("4c3a69"))
	draw_set_transform(Vector2.ZERO)

func _draw_artifact_reveal() -> void:
	var mysterious: bool = str(_result.get("tier", "")) == "mystery"
	var accent: Color = COLORS.mystery if mysterious else COLORS.relic
	var progress: float = smoothstep(0.0, 1.0, _reveal_progress)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.055, 0.16, progress * 0.96))
	var center: Vector2 = Vector2(size.x * 0.5, 82)
	for ray: int in range(18):
		var angle: float = float(ray) / 18.0 * TAU + _reveal_progress * 0.4
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var start: Vector2 = center + direction * (43 + progress * 15)
		var end: Vector2 = center + direction * (57 + progress * 27)
		draw_line(start, end, Color(accent, progress * 0.70), 2, true)
	var scale: float = lerpf(0.5, 1.32, progress)
	draw_set_transform(center, sin(_reveal_progress * PI) * 0.08, Vector2(scale, scale))
	if not str(_result.get("item_id", "")).is_empty():
		draw_set_transform(Vector2.ZERO)
		ItemIcon.paint(self, {"kind": "gear", "id": str(_result.item_id)}, Rect2(center - Vector2(41, 41) * scale, Vector2(82, 82) * scale))
	else:
		_gem(Vector2.ZERO, accent)
	draw_set_transform(Vector2.ZERO)
	for mote: int in range(14):
		var angle: float = float(mote) / 14.0 * TAU
		var radius: float = 40.0 + progress * (32.0 + (mote % 3) * 17.0)
		var position: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(position, 1.5 + (mote % 2), Color(accent, progress * 0.8))
	_text("SOMETHING IMPOSSIBLE…" if mysterious else "AN ANCIENT RELIC", Vector2(0, 166), size.x, 16, Color("fff2d3"))
