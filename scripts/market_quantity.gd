extends LineEdit
## A whole-tonne amount. Invalid draft text never becomes a sale quantity.
signal value_changed(value: float)
var max_value: int = 0
var min_value: int = 0
var valid: bool = true
var value: float:
	get: return float(_amount) if valid else 0.0
	set(amount): set_amount(int(amount), true)
var _amount: int = 0

func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	max_length = 16
	select_all_on_focus = true
	set_amount(_amount, false)
	text_changed.connect(_edited)
	text_submitted.connect(func(_text: String) -> void: apply())
	focus_exited.connect(apply)

func get_line_edit() -> LineEdit: return self

func set_value_no_signal(amount: float) -> void: set_amount(int(amount), false)

func set_amount(amount: int, notify: bool = true) -> void:
	_amount = clampi(amount, 1 if max_value > 0 else 0, max_value)
	valid = true
	text = str(_amount)
	if notify: value_changed.emit(value)

func set_available(owned: int) -> void:
	editable = owned > 0
	if max_value == owned: return
	max_value = maxi(0, owned)
	min_value = 1 if max_value > 0 else 0
	editable = max_value > 0
	if valid: set_amount(_amount, false)
	elif max_value == 0: set_amount(0, false)

func _edited(source: String) -> void:
	var parsed := source.strip_edges()
	valid = not parsed.is_empty() and parsed.is_valid_int() and not parsed.begins_with("-") and not parsed.begins_with("+")
	if valid:
		# Numeric input is bounded immediately, so every live payout is actionable.
		var wanted: int = parsed.to_int()
		_amount = clampi(wanted, 1 if max_value > 0 else 0, max_value)
		if wanted != _amount: text = str(_amount)
	value_changed.emit(value)

func apply() -> bool:
	_edited(text)
	if valid: text = str(_amount)
	return valid
