extends VBoxContainer
const Place = preload("res://scripts/place_ui.gd")
const ACCENT := Color("997243")
var hud
var quest_notes: VBoxContainer
var loss_notes: VBoxContainer
var tabs: Array[Button] = []
var losses: bool = false
var signature: String = ""
func setup(owner_hud, show_losses: bool = false) -> void:
	hud = owner_hud; losses = show_losses
	set_meta("market_responsive", true)
	add_theme_constant_override("separation", 14)
	hud._modal_card.add_theme_stylebox_override("panel", Place.skin(Color("b89663"), 18, 3, Color("896537")))
	hud._modal_card.offset_top = -380; hud._modal_card.offset_bottom = 380
	Place.header(hud, self, "TESS’S BOARD", ACCENT, "tess")
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 10); add_child(bar)
	for index in range(2):
		var button: Button = hud._button("Quests" if index == 0 else "Losses", "")
		Place.pill(button, ACCENT); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(button); tabs.append(button)
		button.pressed.connect(func(): losses = index == 1; refresh())
	quest_notes = hud._vbox(14); add_child(quest_notes)
	loss_notes = hud._vbox(14); add_child(loss_notes)
	for q in hud._quests():
		var note := PanelContainer.new(); note.name = "PinnedQuestNote"
		note.add_theme_stylebox_override("panel", Place.skin(Place.PAPER, 18, 7)); quest_notes.add_child(note); hud._refs["quest:" + q.id + ":card"] = note
		var body: VBoxContainer = hud._vbox(8); note.add_child(body)
		body.add_child(hud._wrap(q.description, 21, Place.INK, true))
		var progress: ProgressBar = hud._meter(Place.INK, 8); body.add_child(progress); hud._refs["quest:" + q.id + ":bar"] = progress
		var detail: Label = hud._wrap("", 15, Place.MUTED); body.add_child(detail); hud._refs["quest:" + q.id + ":detail"] = detail
		var reward_row := HBoxContainer.new(); reward_row.add_theme_constant_override("separation", 12); body.add_child(reward_row)
		var reward: Label = hud._wrap(hud._money(q.coins), 26, Place.INK, true); reward.custom_minimum_size.x = 120; reward_row.add_child(reward)
		var extras: PackedStringArray = str(q.reward_text).split(" + ")
		if extras.size() > 1: reward_row.add_child(hud._wrap(extras[1], 14, Place.MUTED))
		var claim: Button = hud._button("Claim", "quest:" + q.id); Place.pill(claim, ACCENT, true); body.add_child(claim); hud._refs["quest:" + q.id] = claim
		pin(note)
	resized.connect(_layout); refresh(); _layout.call_deferred()
func pin(note: Control) -> void:
	var tack = preload("res://scripts/paper_detail.gd").new(); tack.kind = "pin"
	note.add_child(tack); tack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func refresh() -> void:
	quest_notes.visible = not losses; loss_notes.visible = losses
	for i in range(2):
		tabs[i].set_pressed_no_signal(losses == (i == 1)); Place.pill(tabs[i], ACCENT)
	for q in hud._quests():
		var key: String = "quest:" + q.id
		hud._refs[key + ":bar"].max_value = q.target; hud._refs[key + ":bar"].value = minf(q.progress, q.target)
		hud._refs[key + ":detail"].text = "%s of %s" % [hud._number(minf(q.progress, q.target)), hud._number(q.target)] + (" · Claimed" if q.claimed else "")
		hud._refs[key].visible = q.complete and not q.claimed; hud._refs[key].disabled = not q.complete or q.claimed
	var next: String = "%d:%d" % [hud._state.season_clock.year, hud._state.climate.data.protection.revision]
	if next != signature:
		signature = next
		for child in loss_notes.get_children(): loss_notes.remove_child(child); child.queue_free()
		hud._build_loss_cards(loss_notes, hud._state.season_clock.year)
		if not hud._tutorial.is_empty() and hud._tutorial.get("id") == "loss":
			var next_button: Button = hud._button("Harvest what remains →", "tutorial:next", true); Place.pill(next_button, ACCENT, true); loss_notes.add_child(next_button)
	var count: int = 0
	for e in hud._state.climate.data.protection.losses:
		if int(e.year) == hud._state.season_clock.year: count += 1
	tabs[1].text = "Losses %d" % count if count > 0 else "Losses"
func _layout() -> void:
	if not is_inside_tree(): return
	Place.compact(self)
	var touch: bool = is_instance_valid(hud.get_parent().get("touch_controls")) and hud.get_parent().touch_controls.enabled
	for button in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = hud.touch_target() if touch else 44
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, hud.touch_target() if touch else 44)
		button.add_theme_font_size_override("font_size", 22 if touch else 15)
	for label in find_children("*", "Label", true, false):
		if touch: label.add_theme_font_size_override("font_size", maxi(21, label.get_theme_font_size("font_size")))

func _draw() -> void:
	for x in range(5, int(size.x), 13):
		for y in range(5, int(size.y), 13): draw_circle(Vector2(x,y), .7, Color("6b4e29", .14))
