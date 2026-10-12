extends VBoxContainer
const Kit = preload("res://scripts/ui_kit.gd")
const Picture = preload("res://scripts/pedlar_picture.gd")
const Model = preload("res://scripts/pedlar_state.gd")
const Refused = preload("res://scripts/refused_tap.gd")
const WINDUP: float = .7
const CUE_SECONDS: float = .42
const LAND_AT: float = WINDUP + CUE_SECONDS
var hud
var cards: Dictionary = {}
var caption: Label
var result_card: PanelContainer
var pack_row: HBoxContainer
var last_touched: String = ""
var pending: Dictionary = {}
var windup_elapsed: float = 0.0
var revealing: bool = false
var cue_started: bool = false
var rise_origin: float = 0.0
var reveal_started_usec: int = 0
var reveal_landed_usec: int = 0

func setup(owner_hud) -> void:
	hud = owner_hud; name = "FennicksPage"
	Kit.configure(hud); size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var u: float = Kit.unit(hud)
	add_theme_constant_override("separation",ceili(10*u))
	var header := PanelContainer.new(); header.name = "FennickHeader"
	header.add_theme_stylebox_override("panel",Kit.skin(Kit.PAPER.lerp(Kit.KEEPERS.fennick,.30),Kit.PAPER.lerp(Kit.KEEPERS.fennick,.30),10,12,u,false))
	add_child(header)
	var heading := HBoxContainer.new(); heading.add_theme_constant_override("separation",ceili(8*u)); header.add_child(heading)
	var portrait = preload("res://scripts/npc_portrait.gd").new(); portrait.set_meta("kit_portrait",true)
	portrait.custom_minimum_size = Vector2(56,64)*u; heading.add_child(portrait); portrait.show_person("fennick"); portrait.set_expression("crooked")
	var words := VBoxContainer.new(); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(words)
	words.add_child(Kit.label(hud,"Fennick",22,Kit.INK,true))
	words.add_child(Kit.label(hud,"Three packs. One's good.",16))
	caption = Kit.label(hud,"",14); caption.name = "PedlarCaption"; caption.hide(); add_child(caption)
	pack_row = HBoxContainer.new(); pack_row.add_theme_constant_override("separation",ceili(8*u)); add_child(pack_row)
	for pack: String in Model.PACK_IDS: _build_pack(pack)
	result_card = preload("res://scripts/pedlar_result.gd").new(); result_card.unit = u; result_card.hide(); add_child(result_card)
	if not hud._state.pedlar.data.last_result.is_empty():
		last_touched = str(hud._state.pedlar.data.last_result.pack)
		if hud._state.pedlar.data.revealed: _show_result(hud._state.pedlar.data.last_result,false)
		else: _start_reveal.call_deferred(hud._state.pedlar.data.last_result)
	resized.connect(_layout); _layout.call_deferred()
	refresh()

func _build_pack(pack: String) -> void:
	var u: float = Kit.unit(hud)
	var card = preload("res://scripts/kit_card.gd").new(); card.unit = u; card.name = "PedlarPack_"+pack
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pack_row.add_child(card)
	var body := VBoxContainer.new(); body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation",ceili(4*u)); card.add_child(body)
	var picture := Picture.new(); picture.kind = pack; picture.custom_minimum_size = Vector2(60,60)*u
	body.add_child(picture)
	var title: Label = _centred(pack.capitalize()+" pack",14,true); title.name = "PackName"; body.add_child(title)
	body.add_child(_centred(hud._state.market_money(hud._state.Balance.PEDLAR_PACKS[pack].price),14,true))
	for row: Array in hud._state.Balance.PEDLAR_PACKS[pack].outcomes:
		var item: String = {"russet_seeds":"Ten Russet seeds", "oddity":"One oddity", "refund":"500 back", "stone":"Lucky stone", "blue_pearl":"Blue Pearl"}.get(str(row[0]),str(row[0]).capitalize())
		var odds: Label = _centred(item+"\n"+str(row[2]),14)
		odds.name = "Odds_"+str(row[0]); body.add_child(odds)
	var button := Button.new(); button.name = "BuyPedlar_"+pack
	button.set_meta("pack",pack); button.set_meta("plain_control",true)
	for variant in ["normal","hover","pressed","focus","disabled"]: button.add_theme_stylebox_override(variant,StyleBoxEmpty.new())
	card.add_child(button); button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(func(): buy(pack))
	button.mouse_entered.connect(func(): card._tilt(-2))
	button.mouse_exited.connect(func(): card._tilt(0))
	# The drawn back supplies the button's accessible name without extra UI copy.
	button.tooltip_text = pack.capitalize()+" pack"
	cards[pack] = {"card":card,"body":body,"button":button,"picture":picture,"title":title}

func _centred(text: String, tier: int, display: bool = false) -> Label:
	var label: Label = Kit.label(hud,text,tier,Kit.INK if display else Kit.MUTED,display)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	var u: float = Kit.unit(hud)
	for pack in cards:
		var entry: Dictionary = cards[pack]
		var available: float = minf((760 if Kit.desktop(hud) else 390)*u,hud.root.size.x-(64 if Kit.desktop(hud) else 24)*u)-30*u
		var width: float = maxf(0,(available-16*u)/3.4*(1.4 if pack == "superstition" else 1.0))
		entry.card.custom_minimum_size.x = width
		entry.body.custom_minimum_size.x = maxf(0,width-24*u)

func refresh() -> void:
	for pack in cards:
		var entry: Dictionary = cards[pack]
		var sold: bool = not hud._state.pedlar.unbought(hud._state,pack)
		entry.button.disabled = sold or revealing
		entry.title.text = "Sold" if sold else pack.capitalize()+" pack"
		var active: bool = pack == last_touched
		entry.picture.colour = Kit.KEEPERS.fennick if active else Kit.MUTED
		entry.picture.queue_redraw()
		entry.card.edge = Kit.KEEPERS.fennick if active else Kit.PAPER.lerp(Kit.KEEPERS.fennick,.30)
		entry.card.add_theme_stylebox_override("panel",Kit.skin(Kit.PAPER,entry.card.edge,8,12,Kit.unit(hud)))
		entry.card.queue_redraw()

func buy(pack: String) -> void:
	if revealing: return
	last_touched = pack; refresh()
	var result: Dictionary = hud._state.pedlar.buy(hud._state,pack)
	if result.has("error"):
		Refused.shake(cards[pack].card); caption.text = str(result.error); caption.show(); Kit.fit(hud); return
	if result.is_empty(): return
	caption.hide(); result_card.hide()
	_start_reveal(result)
	hud.get_parent()._save_checkpoint.call_deferred()

func _start_reveal(result: Dictionary) -> void:
	pending = result; last_touched = str(result.pack); revealing = true; windup_elapsed = 0; cue_started = false
	rise_origin = cards[last_touched].card.position.y
	reveal_started_usec = Time.get_ticks_usec(); reveal_landed_usec = 0
	cards[last_touched].card._tilt(0); refresh()
	hud.get_parent().feedback_audio._play(preload("res://assets/audio/pedlar-roll.wav"),"pedlar:roll")

func _process(delta: float) -> void:
	if revealing: advance_reveal(delta)

func advance_reveal(delta: float) -> void:
	if not revealing: return
	windup_elapsed += maxf(0,delta)
	var card: Control = cards[last_touched].card
	var rise: float = minf(1,windup_elapsed/.35)
	card.pivot_offset = card.size*.5
	card.position.y = rise_origin - 12*Kit.unit(hud)*rise
	card.scale = Vector2(1+.05*rise,1+.05*rise)
	if windup_elapsed > .4: card.scale.x = maxf(.02,absf(cos(minf(1,(windup_elapsed-.4)/.3)*PI)))
	if windup_elapsed >= WINDUP and not cue_started:
		cue_started = true
		hud.get_parent().feedback_audio._play(preload("res://assets/audio/harvest-two-notes.wav"),"pedlar:two-notes")
	if windup_elapsed < LAND_AT: return
	revealing = false; card.scale = Vector2.ONE; card.position.y = rise_origin
	hud._state.pedlar.data.revealed = true
	hud.get_parent()._save_checkpoint.call_deferred()
	_show_result(pending,true)
	reveal_landed_usec = Time.get_ticks_usec()
	refresh()

func _show_result(result: Dictionary, animate: bool) -> void:
	for child in result_card.get_children(): result_card.remove_child(child); child.queue_free()
	var u: float = Kit.unit(hud)
	result_card.edge = Kit.RARITIES[result.rarity]
	result_card.add_theme_stylebox_override("panel",Kit.skin(Kit.PAPER,result_card.edge,10,12,u))
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",ceili(5*u)); result_card.add_child(body)
	var picture := Picture.new(); picture.kind = "superstition_card" if result.kind == "superstition" else str(result.kind); picture.id = str(result.id)
	picture.colour = Kit.PAPER.lerp(Kit.KEEPERS.fennick,.30)
	picture.set_meta("oddity_name",str(result.name)); picture.custom_minimum_size = Vector2(68,68)*u; body.add_child(picture)
	body.add_child(_centred(str(result.name),22,true))
	body.add_child(_centred(str(result.cause),16))
	body.add_child(_centred(str(result.effect),16))
	body.add_child(_centred(str(result.odds),14))
	result_card.show(); result_card.queue_redraw()
	if animate:
		result_card.scale = Vector2(.92,.92); result_card.pivot_offset = result_card.size*.5
		var tween: Tween = create_tween(); tween.tween_property(result_card,"scale",Vector2(1.03,1.03),.10); tween.tween_property(result_card,"scale",Vector2.ONE,.12)
		result_card.flash_left = .3
		if result.rarity in ["rare","found"]: result_card.flame_left = .45
		hud.get_parent().feedback_audio._play(preload("res://assets/audio/pedlar-stamp.wav"),"pedlar:stamp")
	Kit.fit(hud)
