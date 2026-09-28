extends Control
## A modal conversation; the main loop pauses all farm clocks while visible.
signal finished(service: String)
const Roster = preload("res://scripts/npc_roster.gd")
const Portrait = preload("res://scripts/npc_portrait.gd")
const Voice = preload("res://scripts/npc_voice.gd")
const Type = preload("res://scripts/ui_type.gd")
var state
var npc_id: String = ""
var service: String = ""
var page: String = ""
var portrait
var card: Panel
var text_card: PanelContainer
var speech_bubble: PanelContainer
var speech: RichTextLabel
var title: Label
var role: Label
var hint: Label
var close_button: Button
var choices: VBoxContainer
var choice_buttons: Array[Button] = []
var choice_ids: Array[String] = []
var scroll: ScrollContainer
var body: VBoxContainer
var elapsed: float = 0
var _revealed: float = 0
var _entry_time: float = 0
var _touch: bool = false
var voice

func _ready() -> void:
	voice = Voice.new()
	add_child(voice)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = face(Type.BODY, 500)
	theme.default_font_size = 22
	self.theme = theme
	card = Panel.new()
	card.add_theme_stylebox_override("panel", style(Color("152f2b"),24,0))
	add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = label("Farm paused",16,Color("c2d4c3"))
	add_child(hint)
	close_button = button("Leave  ×",func(): finish())
	add_child(close_button)
	close_button.tooltip_text = "Leave conversation (Escape)"
	text_card = PanelContainer.new()
	text_card.add_theme_stylebox_override("panel",style(Color("fff8e8"),18,24))
	add_child(text_card)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_card.add_child(scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	title = label("",34,Color("17382d"))
	title.add_theme_font_override("font",face(Type.DISPLAY,600))
	body.add_child(title)
	role = label("",17,Color("637869"))
	body.add_child(role)
	speech = RichTextLabel.new()
	speech.bbcode_enabled = false
	speech.fit_content = true
	speech.scroll_active = false
	speech.add_theme_color_override("default_color",Color("253e34"))
	speech.add_theme_font_size_override("normal_font_size",24)
	speech.custom_minimum_size.y = 128
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech.mouse_filter = Control.MOUSE_FILTER_STOP
	speech.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: reveal())
	speech_bubble = PanelContainer.new()
	var bubble := style(Color.WHITE,16,16)
	bubble.border_color = Color("24362e")
	bubble.set_border_width_all(2)
	bubble.shadow_color = Color(0,0,0,.10)
	bubble.shadow_size = 2
	bubble.shadow_offset = Vector2(0,3)
	speech_bubble.add_theme_stylebox_override("panel",bubble)
	body.add_child(speech_bubble)
	speech_bubble.add_child(speech)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(space)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	body.add_child(choices)
	for i in range(3):
		var choice := button("",func(): choose(i))
		choices.add_child(choice)
		choice_buttons.append(choice)
	resized.connect(layout)
	hide()
	set_process(false)

func face(font: Font, weight: float) -> FontVariation:
	var result: FontVariation = Type.face(font,weight)
	# Keep dialogue metrics compact; only the small currency glyph needs a fallback.
	result.fallbacks = [Type.SPUDION]
	return result

func style(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box

func label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_font_override("font",face(Type.BODY,600))
	b.add_theme_color_override("font_color",Color("fff8e8"))
	b.add_theme_color_override("font_hover_color",Color("ffffff"))
	b.add_theme_color_override("font_pressed_color",Color("ffffff"))
	for variant in ["normal","hover","pressed"]:
		b.add_theme_stylebox_override(variant,style(Color("315e4d") if variant == "normal" else Color("497e60"),10,12))
	var focus := style(Color(0,0,0,0),10,0)
	focus.border_color = Color("e8bd69")
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus",focus)
	b.pressed.connect(callback)
	return b

func start(id: String, farm, return_service: String, touch: bool = false) -> void:
	state = farm
	npc_id = id
	service = return_service
	_touch = touch
	if not is_instance_valid(portrait):
		portrait = Portrait.new()
		add_child(portrait)
		# Keep the portrait above its background even when nonvisual children
		# (such as the voice player) are inserted before the card.
		move_child(portrait, card.get_index() + 1)
	show()
	set_process(true)
	portrait.show_person(id)
	title.text = str(Roster.PEOPLE[id].name)
	role.text = str(Roster.PEOPLE[id].role)
	var accent := Color(Roster.PEOPLE[id].color).darkened(.32)
	title.add_theme_color_override("font_color",accent)
	var name_tag := style(Color(Roster.PEOPLE[id].color).lightened(.76),10,10)
	name_tag.border_color = accent
	name_tag.border_width_left = 5
	title.add_theme_stylebox_override("normal",name_tag)
	_entry_time = 0
	layout()
	show_page("greeting",Roster.greeting(id,state,true))
	close_button.grab_focus()

func layout() -> void:
	if not is_instance_valid(card): return
	var width: float = minf(1160,size.x-32)
	var height: float = minf(1100 if width < 700 else 760,size.y-32)
	var origin := Vector2((size.x-width)/2,(size.y-height)/2)
	card.position = origin
	card.size = Vector2(width,height)
	var target_height: float = maxf(68 if _touch else 48,close_button.get_minimum_size().y)
	close_button.custom_minimum_size = Vector2(146,target_height)
	close_button.position = origin+Vector2(width-162,12)
	close_button.size = Vector2(146,target_height)
	hint.position = origin+Vector2(24,22)
	var top: float = target_height+24
	var inner := Rect2(origin+Vector2(16,top),Vector2(width-32,height-top-16))
	if width < 700:
		# Tall phones keep the face above the speech; choices scroll on tiny windows.
		var ph: float = clampf(inner.size.y*.29,120,270)
		if is_instance_valid(portrait):
			portrait.position = inner.position
			portrait.size = Vector2(inner.size.x,ph)
		text_card.position = inner.position+Vector2(0,ph+12)
		text_card.size = Vector2(inner.size.x,maxf(100,inner.size.y-ph-12))
	else:
		var pw: float = inner.size.x*.36
		if is_instance_valid(portrait):
			portrait.position = inner.position
			portrait.size = Vector2(pw,inner.size.y)
		text_card.position = inner.position+Vector2(pw+16,0)
		text_card.size = Vector2(inner.size.x-pw-16,inner.size.y)
	# Explicit heights ensure choice targets remain usable after rotation.
	for b: Button in choice_buttons: b.custom_minimum_size.y = target_height
	speech.add_theme_font_size_override("normal_font_size",22 if height < 640 else 24 if _touch else 23)
	speech.custom_minimum_size.y = 60 if height < 640 else 112
	title.add_theme_font_size_override("font_size",30 if height < 640 else 34)
	if title.has_theme_stylebox_override("normal"):
		var tag: StyleBox = title.get_theme_stylebox("normal")
		tag.content_margin_top = 4 if height < 640 else 10
		tag.content_margin_bottom = tag.content_margin_top
	var bubble: StyleBox = speech_bubble.get_theme_stylebox("panel")
	bubble.content_margin_top = 12 if height < 640 else 16
	bubble.content_margin_bottom = bubble.content_margin_top
	body.add_theme_constant_override("separation",6 if height < 640 else 10)
	body.custom_minimum_size.y = maxf(0,text_card.size.y-48)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.075,.065,.88))

func show_page(next_page: String, text: String = "") -> void:
	page = next_page
	var p: Dictionary = Roster.PEOPLE[npc_id]
	var labels: Array[String] = []
	match page:
		"greeting":
			if text.is_empty(): text = "What would you like to talk about?"
			labels = [service_label(),str(p.topic),"How's the weather looking?"]
			choice_ids = ["service","story","weather"]
		"story":
			text = p.story
			labels = [str(p.reply),str(p.help),"Let's get back to work."]
			choice_ids = ["reply","advice","service"]
		"reply":
			text = p.answer
			state.npc_history[npc_id].kind = true
			labels = [str(p.help),service_label(),"I'll see you later."]
			choice_ids = ["advice","service","leave"]
		"advice", "weather":
			text = p.advice if page == "advice" else Roster.weather_line(npc_id,state)
			labels = [service_label(),"Can I ask you something else?","Thanks. See you around."]
			choice_ids = ["service","greeting","leave"]
	speech.text = text
	speech.visible_characters = 0
	_revealed = 0
	elapsed = 0
	portrait.avatar.speaking = true
	portrait.avatar.expression = "concerned" if page == "weather" else "warm"
	voice.begin_line(npc_id, speech.get_total_character_count(), page == "weather")
	for i in range(3):
		var b: Button = choice_buttons[i]
		b.text = labels[i]
		var is_service: bool = choice_ids[i] == "service"
		for variant in ["normal","hover","pressed"]:
			var color := Color("f6d47a") if is_service else Color("fffdf5")
			if variant != "normal": color = color.darkened(.09)
			var box := style(color,12,12)
			box.border_color = Color("34463c")
			box.set_border_width_all(2)
			b.add_theme_stylebox_override(variant,box)
		for variant in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			b.add_theme_color_override(variant,Color("21382d"))
	scroll.scroll_vertical = 0
	layout()

func service_label() -> String:
	return str(Roster.PEOPLE[npc_id].service_label)

func choose(index: int) -> void:
	if not visible or index < 0 or index >= choice_ids.size(): return
	var action: String = choice_ids[index]
	if action == "service": finish(service)
	elif action == "leave": finish()
	else: show_page(action)

func reveal() -> void:
	voice.stop()
	speech.visible_characters = -1
	_revealed = float(speech.get_total_character_count())
	portrait.avatar.speaking = false

func _process(delta: float) -> void:
	elapsed += minf(delta,.1)
	_entry_time += delta
	if speech.visible_characters >= 0:
		_revealed += minf(delta,.25)*42
		speech.visible_characters = int(_revealed)
		var count: int = speech.get_total_character_count()
		if _revealed >= count: reveal()
		else:
			var current: String = speech.text.substr(maxi(0,speech.visible_characters-1),1)
			portrait.avatar.speaking = current not in [" ",".",",","!","?","—","\n"]

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed: return
	if event.physical_keycode == KEY_F11: return
	if event.echo:
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_ESCAPE: finish()
		KEY_SPACE:
			# Space/E that opened a conversation cannot immediately close it.
			if _entry_time > .15: reveal()
		KEY_1,KEY_2,KEY_3: choose(event.physical_keycode-KEY_1)
		KEY_TAB,KEY_ENTER: return
		_: pass
	get_viewport().set_input_as_handled()

func finish(next_service: String = "") -> void:
	if not visible: return
	voice.stop()
	hide()
	set_process(false)
	if is_instance_valid(portrait): portrait.avatar.speaking = false
	finished.emit(next_service)
