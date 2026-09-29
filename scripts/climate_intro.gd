extends "res://scripts/chapter_subtitles.gd"
## Annual front page, reusing the former intro's subtitle, timed reveal and skip.
const Strip = preload("res://scripts/climate_strip.gd")
const HEADLINES: Array[String] = ["A farm under an uncertain sky", "The old seasons start to shift", "Rain arrives at the wrong time", "The safe seasons grow shorter", "Another year of harder choices", "Even quiet summers leave the grass dry", "The weather takes a larger share", "Familiar seasons, unfamiliar losses", "Little room left for a bad harvest", "Ten years beneath a changing sky"]
var forecaster: Label
var portrait
var voice
var subtitle: Label
var strip: Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	var page := PanelContainer.new()
	add_child(page); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new(); style.bg_color = Color("f5ecd6")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: style.set_content_margin(side, 22)
	page.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)
	var top := HBoxContainer.new(); column.add_child(top)
	var masthead := label("THE VALLEY WEATHER RECORD", 18)
	masthead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(masthead)
	chapter = label("", 36); column.add_child(chapter)
	var broadcast := HBoxContainer.new(); broadcast.add_theme_constant_override("separation", 18)
	column.add_child(broadcast)
	portrait = preload("res://scripts/npc_portrait.gd").new()
	portrait.custom_minimum_size = Vector2(110, 140)
	broadcast.add_child(portrait)
	forecaster = label("", 18); forecaster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	broadcast.add_child(forecaster)
	voice = preload("res://scripts/npc_voice.gd").new(); add_child(voice)
	subtitle = label("", 19); column.add_child(subtitle)
	column.add_child(label("TEN YEARS · RECORDED DISASTERS", 15))
	strip = Strip.new(); column.add_child(strip)
	column.add_child(label("Sun: drought · Waves: flood · Bolt: storm\nSnowflake: freeze · Ring: deep freeze · Wind: blizzard", 14))
	skip = Button.new(); skip.text = "Skip → Return to farm"; skip.custom_minimum_size.y = 54
	skip.add_theme_font_override("font", Type.face(Type.BODY)); skip.add_theme_font_size_override("font_size", 18)
	top.add_child(skip); skip.pressed.connect(finish)
	stop()
func label(words: String, pixels: int) -> Label:
	var result := Label.new(); result.text = words; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font", Type.face(Type.EDITORIAL if pixels > 25 else Type.BODY))
	result.add_theme_font_size_override("font_size", pixels); result.add_theme_color_override("font_color", Color("3f392b"))
	return result
func present(farm) -> void:
	elapsed = 0
	var year: int = farm.season_clock.year
	chapter.text = "YEAR %d\n%s" % [year, HEADLINES[year - 1]]
	subtitle.text = "Disaster chance per season: %d%%. Mean severity: %d%%.\nAt most one disaster each season, three this year.\nDry ground, extra rain and wind can hint at next season; they are no promise." % [roundi(farm.ClimateSystem.chance(year) * 100), roundi(farm.ClimateSystem.severity_mean(year) * 100)]
	if farm.guided_first_year():
		subtitle.text = "Guided Spring–Autumn: one Summer storm at 20% severity.\nAfter the first accounts, seasonal forecasts use the normal climate odds.\nDry ground, extra rain and wind can hint at next season; they are no promise."
	forecaster.text = "Iris · Weather forecaster\n" + farm.NpcRoster.forecast_line(farm)
	portrait.show()
	portrait.show_person("iris")
	strip.setup(farm.climate.data.outlook.records, year)
	super.start(chapter.text)
	voice.begin_line("iris", forecaster.text.length())
func stop() -> void:
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(portrait): portrait.hide()
	super.stop()

func finish() -> void:
	stop(); finished.emit()
func _process(delta: float) -> void:
	_tick(delta)
	if is_instance_valid(portrait.avatar): portrait.avatar.speaking = voice.player.playing
	subtitle.modulate.a = clampf(elapsed / 0.6, 0, 1)
