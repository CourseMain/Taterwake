extends PanelContainer
## One live estimate per Spring. The guide owns its first year instead.
const Advice = preload("res://scripts/farm_advice.gd")
const Place = preload("res://scripts/place_ui.gd")
var hud
var heading: Button
var facts: Label
var assumption: Label
var calendar: String = ""
var collapsed: bool = false
var signature: String = ""

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "SpringBreakEven"
	add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 10, 8))
	var column := VBoxContainer.new(); add_child(column)
	heading = hud._button("Spring · the three numbers −", "")
	Place.pill(heading, Place.INK)
	heading.pressed.connect(func(): collapsed = not collapsed; refresh())
	column.add_child(heading)
	facts = hud._wrap("", 22, Place.INK); column.add_child(facts)
	assumption = hud._wrap("Healthy Table grade, base prices, bought seed deducted. Weather and storage can lower it.", 18, Place.MUTED)
	column.add_child(assumption)
	mouse_filter = Control.MOUSE_FILTER_PASS

func refresh() -> void:
	if not is_instance_valid(hud._state): return
	var farm = hud._state
	var season_key: String = "%d:%d" % [farm.season_clock.year, farm.season_clock.season]
	if calendar != season_key:
		calendar = season_key
		if farm.season_clock.season == 0: collapsed = false; signature = ""
	visible = farm.season_clock.season == 0 and not farm.tutorial_active and not farm.guided_first_year() and hud._tutorial.is_empty() and not farm.run_over and not farm.climate_report_open and not hud.is_panel_open()
	if not visible: return
	var estimate: Dictionary = Advice.spring(farm)
	var key: String = str(estimate) + farm.selected_crop
	if key != signature:
		signature = key
		facts.text = "Bills this Winter: %s. Your beds at this crop, planted twice: about %s. Short by %s." % [farm.format_number(estimate.bills), farm.format_number(estimate.net), farm.format_number(estimate.short)]
		facts.tooltip_text = "%d beds · %s · two sowings" % [estimate.beds, farm.CropTable.CROPS[farm.selected_crop].name]
	heading.text = "Spring · the three numbers " + ("+" if collapsed else "−")
	facts.visible = not collapsed; assumption.visible = not collapsed
	layout()

func layout() -> void:
	var touch = hud.get_parent().get("touch_controls")
	var phone: bool = is_instance_valid(touch) and touch.enabled
	var scale: float = float(hud.get_tree().root.size.x) / hud.root.size.x
	var width: float = minf(510 if phone else 390, hud.root.size.x - 32)
	var top: float = 208 if phone else 154
	if hud._weather_button.visible: top = maxf(top, hud._weather_button.get_global_rect().end.y + 14)
	if phone and touch.status.visible: top = maxf(top, touch.status.get_global_rect().end.y + 14)
	position = Vector2(16 if phone else 28, top)
	heading.custom_minimum_size.y = maxf(44, 44 / scale) if phone else 44
	heading.add_theme_font_size_override("font_size", 22 if phone else 16)
	facts.add_theme_font_size_override("font_size", 22 if phone else 16)
	assumption.add_theme_font_size_override("font_size", 20 if phone else 13)
	custom_minimum_size.x = width; size = Vector2(width, 0)
