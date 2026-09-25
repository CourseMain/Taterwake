extends BoxContainer
## Three presentation steps; the backend's frozen odds still choose the prize.
const Type = preload("res://scripts/ui_type.gd")
const COLORS: Array[Color] = [Color("52778b"), Color("66835c"), Color("977447")]
signal explanation_changed(text: String)
signal completed
const STEP_SECONDS: float = 0.65
const DURATION: float = STEP_SECONDS * 3
var description: String = ""
var operators: Array[Label] = []
var values: Dictionary = {}
var playing: bool = false
var elapsed: float = 0.0
var captions: Array[Label] = []
var numbers: Array[Label] = []
var details: Array[Label] = []
var tiles: Array[PanelContainer] = []
var _body_font: Font = Type.face(Type.BODY, 600.0)

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size.y = 76
	mouse_filter = Control.MOUSE_FILTER_PASS
	for index: int in range(3):
		if index > 0:
			var operator := _label("›", 17, _body_font)
			operator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			add_child(operator)
			operators.append(operator)
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS[index].lerp(Color("fffbed"), 0.92)
		style.border_color = COLORS[index].lerp(Color("fffbed"), 0.65)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		tile.add_theme_stylebox_override("panel", style)
		add_child(tile)
		tiles.append(tile)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(column)
		var caption := _label(["1 · Roll", "2 · Add earned + gear", "3 · Multiply luck"][index], 11, _body_font)
		var number_label := _label("", 22, Type.face(Type.BODY, 750))
		var detail := _label("", 10, _body_font)
		column.add_child(caption)
		column.add_child(number_label)
		column.add_child(detail)
		captions.append(caption)
		numbers.append(number_label)
		details.append(detail)
	set_process(false)

func _label(text: String, pixels: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", Color("17382d"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func set_values(info: Dictionary) -> void:
	if values == info: return
	values = info.duplicate(true)
	finish()
	tooltip_text = "Luck: 100%% base + %s%% earned + %s%% gear, capped at 1,000%% before the ×%s multiplier. Stake and build affect roll quality separately. See the full calculation for rarity weighting." % [number(float(info.earned) * 100), number(float(info.gear) * 100), number(info.multiplier)]
	for tile in tiles: tile.tooltip_text = tooltip_text

func play() -> void:
	if values.is_empty(): return
	playing = true
	elapsed = 0.0
	set_process(true)
	_paint()

func finish() -> void:
	playing = false
	elapsed = DURATION
	set_process(false)
	_paint()

func _process(delta: float) -> void:
	if not playing: return
	elapsed = minf(DURATION, elapsed + delta)
	if elapsed >= DURATION:
		finish()
		completed.emit()
	else:
		_paint()

func _paint() -> void:
	if values.is_empty() or numbers.size() != 3: return
	var stake: float = 1.0 + float(values.get("stake_bonus", 0)) / 100.0
	var build: float = float(values.get("build_quality", 1))
	var quality: float = stake * build
	var bonus: float = (float(values.normal) - 1.0) * 100.0
	numbers[0].text = number(quality) + "×"
	numbers[1].text = "+" + number(bonus) + "%"
	numbers[2].text = "×" + number(float(values.multiplier))
	details[0].text = "%s× stake · %s× build" % [number(stake), number(build)]
	details[1].text = "100%% base / %s%%" % number(float(values.normal) * 100.0)
	details[2].text = "+%s%% final bonus" % number((float(values.total) - 1.0) * 100.0)
	var stage: int = mini(2, int(elapsed / STEP_SECONDS))
	var explanations: Array[String] = [
		"1 / 3 · Roll with %s× quality from your stake and build." % number(quality),
		"2 / 3 · Add earned + equipped luck: +%s%% after the normal cap." % number(bonus),
		"3 / 3 · Multiply luck: %s%% × %s = %s%% (%s× base luck)." % [number(float(values.normal) * 100), number(float(values.multiplier)), number(float(values.total) * 100), number(float(values.total))],
	]
	description = explanations[stage]
	if playing: explanation_changed.emit(description)
	for index: int in range(tiles.size()):
		var active: bool = playing and stage == index
		var style: StyleBoxFlat = tiles[index].get_theme_stylebox("panel")
		style.bg_color = COLORS[index].lerp(Color("fffbed"), 0.78 if active else 0.94)
		style.border_color = COLORS[index].lerp(Color("fffbed"), 0.1 if active else 0.65)

static func number(value: float) -> String:
	var text: String = String.num(value, 3)
	while text.contains(".") and text.ends_with("0"): text = text.left(-1)
	text = text.trim_suffix(".")
	var parts: PackedStringArray = text.split(".")
	var whole: String = parts[0]
	var at: int = whole.length() - 3
	while at > (1 if whole.begins_with("-") else 0):
		whole = whole.insert(at, ",")
		at -= 3
	return whole + ("." + parts[1] if parts.size() > 1 else "")
