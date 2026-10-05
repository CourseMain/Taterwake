extends VBoxContainer
## Place shells share fitting; the barn and workbench own their objects.
const Surface = preload("res://scripts/shop_surface.gd")
const Place = preload("res://scripts/place_ui.gd")
const Barn = preload("res://scripts/barn_crates.gd")
const Bench = preload("res://scripts/workbench_tiles.gd")
var hud
var barn: bool = false
var _grids: Array[GridContainer] = []
var _tabs: GridContainer
var _ledger_trade: Button
var _wallet: Label
var _levels: Dictionary = {}
var _item_quantities: Dictionary = {}
var _fit_pending: bool = false
func setup(owner_hud, barn_page: bool) -> void:
	hud = owner_hud; barn = barn_page
	set_meta("market_responsive", true); size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	hud._modal_card.offset_left = -500; hud._modal_card.offset_right = 500
	hud._modal_card.offset_top = -380; hud._modal_card.offset_bottom = 380
	if barn: Barn.build(self)
	else: Bench.build(self)
	resized.connect(_layout); minimum_size_changed.connect(_queue_modal_fit)
	_layout.call_deferred(); _queue_modal_fit()
func _queue_modal_fit() -> void:
	if _fit_pending or not is_inside_tree(): return
	_fit_pending = true
	var tree: SceneTree = get_tree()
	await tree.process_frame; await tree.process_frame
	_fit_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	if hud._refs.get("shop_page") == self: hud._fit_shop_modal()
static func content_height(owner_hud) -> float:
	return owner_hud.modal_content_height()
func _timber(parent: Control, name_value: String) -> PanelContainer:
	var crate := Surface.new(); crate.name = name_value
	crate.base = Place.PAPER; crate.edge = Color("b99d74"); crate.radius = 6; crate.frame = true
	crate.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(crate); return crate
func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 14)
	parent.add_child(grid); _grids.append(grid); return grid
func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud) or not is_instance_valid(hud._state): return
	if hud._refs.get("shop_page") != self: return
	if barn: Barn.refresh(self)
	else: Bench.refresh(self)
	_layout.call_deferred()
func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud): return
	if barn: Barn.layout(self)
	else: Bench.layout(self)
