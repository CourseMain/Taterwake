extends "res://scripts/chapter_subtitles.gd"
## Annual front page, reusing the former intro's subtitle, timed reveal and skip.
const Strip = preload("res://scripts/climate_strip.gd")
const Cozy = preload("res://scripts/cozy_ui.gd")
const FADE_SECONDS: float = 0.6
const HEADLINES: Array[String] = ["A farm under an uncertain sky", "The old seasons start to shift", "Rain arrives at the wrong time", "The safe seasons grow shorter", "Another year of harder choices", "Even quiet summers leave the grass dry", "The weather takes a larger share", "Familiar seasons, unfamiliar losses", "Little room left for a bad harvest", "Ten years beneath a changing sky"]
var forecaster: Label
var portrait
var voice
var subtitle: Label
var strip: Control
var accounts_box: PanelContainer
var last_net: Label
var source_offset := Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	var page := PanelContainer.new()
	add_child(page); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 24; page.offset_right = -24
	page.offset_top = 24; page.offset_bottom = -24
	var style := Cozy.paper(Cozy.INK, 22, 4, Cozy.WOOD)
	page.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)
	var masthead := label("THE SPUD VALLEY RECORD", 42)
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(masthead)
	column.add_child(label("WEATHER • FARMING • THE YEAR AHEAD", 14))
	var rule := HSeparator.new()
	column.add_child(rule)
	var news := BoxContainer.new()
	news.add_theme_constant_override("separation", 30)
	column.add_child(news)
	var lead := VBoxContainer.new()
	lead.add_theme_constant_override("separation", 18)
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	news.add_child(lead)
	chapter = label("", 48); lead.add_child(chapter)
	var broadcast := HBoxContainer.new(); broadcast.add_theme_constant_override("separation", 18)
	lead.add_child(broadcast)
	portrait = preload("res://scripts/npc_portrait.gd").new()
	portrait.custom_minimum_size = Vector2(64, 82)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	broadcast.add_child(portrait)
	forecaster = label("", 18); forecaster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	broadcast.add_child(forecaster)
	voice = preload("res://scripts/npc_voice.gd").new(); add_child(voice)
	subtitle = label("", 19); lead.add_child(subtitle)
	var weather := VBoxContainer.new()
	weather.custom_minimum_size.x = 260
	news.add_child(weather)
	weather.add_child(label("THE WEATHER COLUMN", 22))
	weather.add_child(label("Ten years · recorded disasters", 14))
	strip = Strip.new()
	strip.custom_minimum_size = Vector2(230, 104)
	weather.add_child(strip)
	var legend_row := HBoxContainer.new(); weather.add_child(legend_row)
	preload("res://scripts/place_ui.gd").help(get_parent().get_parent().hud, legend_row, "Sun: drought. Waves: flood. Bolt: storm. Snowflake: freeze. Ring: deep freeze. Wind: blizzard. Empty boxes have no recorded disaster. The highlighted box is this year.")
	accounts_box = PanelContainer.new(); accounts_box.name = "LastYearAccounts"
	accounts_box.add_theme_stylebox_override("panel", preload("res://scripts/place_ui.gd").skin())
	weather.add_child(accounts_box)
	var accounts := VBoxContainer.new(); accounts_box.add_child(accounts)
	var caption: Label = label("ACCOUNTS · LAST YEAR", 14)
	caption.add_theme_color_override("font_color", Cozy.INK)
	accounts.add_child(caption)
	last_net = label("", 24); accounts.add_child(last_net)
	last_net.add_theme_color_override("font_color", Cozy.INK)
	var fit_layout: Callable = func() -> void:
		if not is_inside_tree(): return
		news.vertical = size.x < 760
		chapter.add_theme_font_size_override("font_size", 36 if size.x < 760 else 48)
		var scale: float = minf(float(get_tree().root.size.x) / size.x, float(get_tree().root.size.y) / size.y)
		var target: float = maxf(44, ceilf(44 / maxf(scale, 0.1)))
		for control in find_children("*", "Button", true, false):
			control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, target)
			control.custom_minimum_size.y = maxf(68 if control == skip else 44, target)
		for text in column.find_children("*", "Label", true, false):
			text.add_theme_font_size_override("font_size", maxi(int(text.get_meta("base_font_size", 14)), ceili(14 / maxf(scale, 0.1))))
	resized.connect(fit_layout)
	skip = Button.new(); skip.text = "Start the year →"; skip.custom_minimum_size.y = 68
	skip.add_theme_font_override("font", Type.face(Type.BODY)); skip.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed"]: skip.add_theme_stylebox_override(state, preload("res://scripts/cozy_ui.gd").button_style(state, false))
	preload("res://scripts/place_ui.gd").pill(skip, Color("34362c"))
	# The skip control stays outside the article's scroll area on a short phone.
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	page.remove_child(scroll)
	page.add_child(frame)
	frame.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(skip)
	skip.pressed.connect(finish)
	# Browser parents can already have their final size before _ready connects
	# resized. Apply the phone column layout once even without a new resize.
	fit_layout.call_deferred()
	stop()
func label(words: String, pixels: int) -> Label:
	var result := Label.new(); result.text = words; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var face: FontVariation = Type.face(Type.EDITORIAL if pixels > 25 else Type.BODY)
	face.fallbacks = [Type.SPUDION]
	result.add_theme_font_override("font", face)
	result.set_meta("base_font_size", pixels)
	result.add_theme_font_size_override("font_size", pixels); result.add_theme_color_override("font_color", Cozy.CREAM)
	return result
func present(farm) -> void:
	elapsed = 0
	modulate.a = 0
	var game = get_parent().get_parent()
	source_offset = game.hud.panel_source_position("climate") - size * .5
	var year: int = farm.season_clock.year
	chapter.text = "YEAR %d\n%s" % [year, HEADLINES[year - 1]]
	subtitle.text = "Mean severity %d%% · three disasters per year at most" % roundi(farm.ClimateSystem.severity_mean(year) * 100)
	if farm.guided_first_year(): subtitle.text = "Summer storm · 20% severity"
	forecaster.text = "Iris · Weather forecaster\n" + farm.NpcRoster.forecast_line(farm)
	portrait.show()
	portrait.show_person("iris")
	strip.setup(farm.climate.data.outlook.records, year)
	accounts_box.visible = year > 1 and farm.ledger.is_closed(year - 1)
	last_net.text = farm.money(farm.ledger.total(year - 1))
	super.start(chapter.text)
	_update_presentation()
	voice.begin_page("iris")
func stop() -> void:
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(portrait): portrait.hide()
	super.stop()
	modulate.a = 1
	RenderingServer.canvas_item_set_transform(get_canvas_item(), Transform2D.IDENTITY)

func finish() -> void:
	stop(); finished.emit()
func _process(delta: float) -> void:
	_tick(delta)
	if is_instance_valid(portrait.avatar): portrait.avatar.speaking = voice.player.playing
	_update_presentation()

func _update_presentation() -> void:
	var progress: float = front_page_progress()
	modulate.a = progress
	RenderingServer.canvas_item_set_transform(get_canvas_item(), Transform2D(0, source_offset * pow(1 - progress, 3)))

func front_page_progress() -> float:
	return clampf(elapsed / FADE_SECONDS, 0, 1)
