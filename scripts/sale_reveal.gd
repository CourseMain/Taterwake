extends VBoxContainer
## Presentation-only receipt. The committed amount is supplied by the caller.
signal finished
const Kit = preload("res://scripts/ui_kit.gd")
const DURATION: float = 2.4
var elapsed: float = 0
var cue_step: int = -1
var completed: bool = false
var notes: AudioStreamPlayer
var sound_sequence: bool = false
const Mix = preload("res://scripts/sound_mix.gd")
const NOTES := [preload("res://assets/audio/cue-c.wav"), preload("res://assets/audio/cue-e.wav"), preload("res://assets/audio/cue-g.wav"), preload("res://assets/audio/cue-high-c.wav")]
var steps: Array[Control] = []
var shown: int = 0
var receipt: Dictionary
var hud
func setup(owner_hud, committed_receipt: Dictionary, fired: Array = []) -> void:
	name = "SaleReveal"
	notes = AudioStreamPlayer.new(); add_child(notes)
	notes.volume_db = -24.0 + Mix.gain()
	sound_sequence = Mix.allow_charm()
	hud = owner_hud; receipt = committed_receipt.duplicate(true)
	add_theme_constant_override("separation", ceili(8 * Kit.unit(hud)))
	preload("res://scripts/place_ui.gd").header(hud, self, "Nell", Kit.KEEPERS.nell, "nell", str(receipt.season_name) + " price. Write it down.")
	add_step("%d sacks" % int(receipt.tonnes), "%d t" % int(receipt.tonnes), {"kind":"control", "id":"sack"})
	var grade: String = str(receipt.grade)
	add_step(preload("res://scripts/grade_stamp.gd").GLOSSES[grade], "×%s" % str(receipt.grade_factor), {}, grade)
	add_step(str(receipt.season_name) + " price", "%s /t" % hud._state.format_number(receipt.price), {"kind":"metric", "id":"snowflake"})
	for rule in fired:
		add_step(preload("res://scripts/practice_tile.gd").DEFINITIONS[rule].name + " fired", "kept " + grade, {"kind":"practice", "id":rule})
		steps.back().add_theme_stylebox_override("panel", Kit.skin(Kit.CREAM, Kit.RARITIES[preload("res://scripts/practice_tile.gd").DEFINITIONS[rule].rarity], 8, 10, Kit.unit(hud), false))
	add_step("Sold", hud._state.money(receipt.amount), {}, "", true)
	var back: Button = Kit.button(hud, "Back to the barn", "barn", Kit.KEEPERS.mara)
	add_child(back)
	for step in steps: step.modulate.a = 0
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: skip())
func add_step(words: String, value: String, picture: Dictionary = {}, grade: String = "", money: bool = false) -> void:
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", Kit.skin(Color("fbe6a6") if money else Kit.CREAM, Kit.MONEY if money else Kit.RULE, 8, 10, Kit.unit(hud), false)); add_child(card)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", ceili(10 * Kit.unit(hud))); card.add_child(row)
	if not picture.is_empty(): row.add_child(hud._icon(picture, 28 * Kit.unit(hud)))
	if not grade.is_empty():
		var stamp: Label = Kit.label(hud, grade, 14)
		preload("res://scripts/grade_stamp.gd").apply(stamp, grade, hud.text_pixels(14)); row.add_child(stamp)
	var caption: Label = Kit.label(hud, words, 16); caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(caption)
	var amount: Label = Kit.label(hud, value, 22, Color("7a5a12") if money else Kit.CROPS.get(receipt.get("crop", "golden"), Kit.INK) if words.ends_with(" price") else Kit.INK, true)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF; row.add_child(amount); steps.append(card)
func _process(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	for i in range(steps.size()):
		var progress: float = clampf((elapsed - i * (2.0 / maxf(1, steps.size() - 1))) / .35, 0, 1)
		steps[i].modulate.a = progress
		steps[i].scale = Vector2.ONE * lerpf(.85, 1, progress)
		steps[i].pivot_offset = steps[i].size * .5
	shown = mini(steps.size(), 1 + floori(elapsed / (2.0 / maxf(1, steps.size() - 1))))
	if shown - 1 > cue_step:
		cue_step = shown - 1
		if sound_sequence and is_instance_valid(notes):
			notes.stream = NOTES[mini(cue_step, NOTES.size()-1)]
			notes.pitch_scale = 1.12 if cue_step >= NOTES.size() else 1.0
			notes.play()
			# The reveal is one short musical phrase. Other cues wait for it.
			Mix.last_sound = Mix.clock; Mix.last_alert = Mix.clock
	if elapsed == DURATION and not completed:
		completed = true; finished.emit()
func skip() -> void:
	if is_instance_valid(notes): notes.stop()
	elapsed = DURATION; cue_step = steps.size(); _process(0)
