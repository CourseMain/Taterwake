extends PanelContainer
## One live estimate per Spring. The guide owns its first year instead.
const Advice = preload("res://scripts/farm_advice.gd")
const Place = preload("res://scripts/place_ui.gd")
var hud
var heading: Button
var facts: RichTextLabel
var calendar: String = ""
var collapsed: bool = false
var signature: String = ""

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "SpringBreakEven"
	add_theme_stylebox_override("panel", Place.skin(Color("e5efdb"), 10, 12))
	var column := VBoxContainer.new(); add_child(column)
	heading = hud._button("Spring plan −", "")
	Place.pill(heading, Color("b6d2a4"))
	heading.pressed.connect(func(): collapsed = not collapsed; refresh())
	column.add_child(heading)
	facts = RichTextLabel.new()
	facts.bbcode_enabled = true; facts.fit_content = true; facts.scroll_active = false
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	facts.add_theme_color_override("default_color", Place.INK)
	facts.add_theme_font_override("normal_font", hud.Type.face(hud.Type.BODY, 600))
	facts.set_meta("text_tier", 16)
	column.add_child(facts)
	mouse_filter = Control.MOUSE_FILTER_PASS

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var farm = hud._state
	var season_key: String = "%d:%d" % [farm.season_clock.year, farm.season_clock.season]
	if calendar != season_key:
		calendar = season_key
		if farm.season_clock.season == 0: collapsed = false; signature = ""
	visible = farm.season_clock.season == 0 and not farm.tutorial_active and not farm.guided_first_year() and hud._tutorial.is_empty() and not farm.run_over and not farm.climate_report_open and not hud.farm_page_open()
	if not visible: return
	var estimate: Dictionary = Advice.spring(farm)
	var key: String = str(estimate) + farm.selected_crop
	if key != signature:
		signature = key
		facts.text = "Winter bills    [color=#856023]%s[/color]\nTwo plantings    [color=#315d3e]≈ %s[/color]\nShort by    [color=#954e40]%s[/color]" % [farm.money(estimate.bills), farm.money(estimate.net), farm.money(estimate.short)]
		facts.tooltip_text = "%d %s beds, planted twice. Healthy Table crop at base prices, seed costs deducted. Weather and storage may lower it." % [estimate.beds, farm.CropTable.CROPS[farm.selected_crop].name]
	heading.text = "Spring plan " + ("+" if collapsed else "−")
	facts.visible = not collapsed
	layout()

func layout() -> void:
	var touch = hud.get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	var scale: float = float(hud.get_tree().root.size.x) / hud.root.size.x
	var width: float = minf(380 if phone else 330, hud.root.size.x - 32)
	var top: float = hud._play_band.size.y + 16 if phone else 180
	if hud._weather_button.visible: top = maxf(top, hud._weather_button.get_global_rect().end.y + 14)
	position = Vector2(16 if phone else 28, top)
	heading.custom_minimum_size.y = maxf(44, 44 / scale) if phone else 44
	hud.fit_text(self)
	custom_minimum_size.x = width; size = Vector2(width, 0)
