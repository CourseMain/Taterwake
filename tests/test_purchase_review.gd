extends SceneTree
const Review = preload("res://scripts/purchase_review.gd")
var game
var farm
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + note)
func settle() -> void:
	for i in range(8): await process_frame
func active_review() -> bool:
	return is_instance_valid(game.hud._purchase_review) and game.hud._purchase_review.visible
func review_has_text(text: String) -> bool:
	for node in game.hud._purchase_review.find_children("*", "Label", true, false):
		if node.text == text: return true
	return false
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
func cancel_review() -> void:
	if active_review(): game.hud._purchase_review.cancel_button.pressed.emit()
func fresh() -> void:
	cancel_review()
	game.hud.close_panel()
	farm.reset_game()
	farm.tutorial_progress.completed = true
	farm.tutorial_active = false
	game.tutorial.active = false
func tax_debt(amount: float) -> void:
	farm.coins = float(farm.blind_info().tax) - amount
	farm._resolve_blind()
func open_tools() -> void:
	game.hud.show_panel("tools",farm)
	await settle()
func run() -> void:
	if "--integration-test" not in OS.get_cmdline_user_args(): quit(1); return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_process(false)
	farm = game.state
	fresh()
	await open_tools()
	check(game.hud._refs["upgrade:hoe"].disabled, "cash overspend disabled in Tools")
	var saved: Dictionary = farm._save_data().duplicate(true)
	game._on_action("upgrade:hoe")
	check(active_review() and not game.hud._purchase_review.confirm_button.visible, "cash overspend through dispatcher shows blocked review")
	check(saved == farm._save_data(), "blocked cash overspend preserves farm")
	cancel_review()
	check(not active_review(), "blocked review dismisses without purchase")
	tax_debt(45000)
	await open_tools()
	check(not game.hud._refs["upgrade:hoe"].disabled and game.hud._refs["upgrade:hoe"].text.contains("On account"), "eligible tax account exposes purchase")
	saved = farm._save_data().duplicate(true)
	game.hud._refs["upgrade:hoe"].pressed.emit()
	await settle()
	check(active_review() and game.hud._purchase_review.confirm_button.visible, "near-limit purchase opens confirmation")
	check(saved == farm._save_data(), "opening bankruptcy warning does not charge or grant upgrade")
	check(game.hud.is_panel_open(), "review blocks world input as a modal")
	key(KEY_B)
	check(active_review() and not game.conversation.visible and saved == farm._save_data(), "shop hotkey cannot dismiss review or start NPC dialogue")
	var review = game.hud._purchase_review
	check(review.card.get_global_rect().end.x <= game.hud.root.size.x+1 and review.card.get_global_rect().end.y <= game.hud.root.size.y+1, "warning card fits viewport")
	cancel_review()
	check(saved == farm._save_data() and not active_review(), "cancel retains balance and upgrade")
	game._on_action("upgrade:hoe")
	var balance: float = farm.coins
	var confirm: Button = game.hud._purchase_review.confirm_button
	confirm.pressed.emit()
	check(not active_review() and farm.coins == balance-300 and farm.tools.hoe == 1, "confirm executes one reviewed purchase")
	confirm.pressed.emit()
	check(farm.coins == balance-300 and farm.tools.hoe == 1, "duplicate confirm cannot purchase twice")
	# While the warning is open, other routed actions cannot spend the account.
	game._on_action("upgrade:water")
	balance = farm.coins
	game._on_action("upgrade:harvest")
	check(active_review() and farm.coins == balance and farm.tools.harvest == 0, "warning captures competing purchase actions")
	cancel_review()
	farm.coins = farm.bankruptcy_limit()+100
	game.hud.update_state(farm)
	check(not game.hud._refs["upgrade:water"].disabled and game.hud._refs["upgrade:water"].text.contains("Limit"), "account limit remains inspectable in Tools")
	saved = farm._save_data().duplicate(true)
	game.hud._refs["upgrade:water"].pressed.emit()
	check(active_review() and not game.hud._purchase_review.confirm_button.visible, "insufficient allowance offers no confirmation")
	check(saved == farm._save_data() and not farm.run_over, "blocked allowance cannot bankrupt player")
	cancel_review()
	# A changed balance must produce a fresh warning, then a single correct buy.
	fresh()
	tax_debt(45000)
	await open_tools()
	game._on_action("upgrade:water")
	farm.coins -= 100
	balance = farm.coins
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and farm.coins == balance and farm.tools.water == 0, "changed debt is requoted before confirmation")
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(not active_review() and farm.coins == balance-450 and farm.tools.water == 1, "second confirmation uses updated debt exactly")
	# Live seed prices are read again when the player confirms.
	fresh()
	tax_debt(45000)
	game.hud.show_panel("market",farm)
	await settle()
	var count: int = farm.seed_inventory.russet
	game._on_action("buy:russet:1")
	farm.market.russet.seed = float(farm.market.russet.seed)*2
	var new_price: float = farm.market.russet.seed
	balance = farm.coins
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and farm.coins == balance and farm.seed_inventory.russet == count, "changed live price is requoted without granting seeds")
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(not active_review() and farm.coins == balance-new_price and farm.seed_inventory.russet == count+1, "confirmed live quote charges correct seed price")
	# Losing remaining allowance during review must switch to a hard block.
	game._on_action("buy:russet:1")
	farm.coins = farm.bankruptcy_limit()+1
	balance = farm.coins
	count = farm.seed_inventory.russet
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and not game.hud._purchase_review.confirm_button.visible, "stale quote becomes blocked if allowance vanishes")
	check(farm.coins == balance and farm.seed_inventory.russet == count and not farm.run_over, "stale over-limit quote never charges")
	cancel_review()
	# Even a safer replacement quote must be shown before charging it.
	fresh()
	tax_debt(45000)
	await open_tools()
	game._on_action("upgrade:water")
	farm.coins += 10000
	balance = farm.coins
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and farm.coins == balance and farm.tools.water == 0 and review_has_text("Purchase changed"), "improved allowance is requoted before purchase")
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(not active_review() and farm.coins == balance-450 and farm.tools.water == 1, "safer updated quote charges once after new confirmation")
	# Prices can change while a refund pays down debt; both are in the review.
	fresh()
	tax_debt(45000)
	game._on_action("buy:russet:1")
	farm.market.russet.seed = 57.0
	farm.coins += 20000
	balance = farm.coins
	count = farm.seed_inventory.russet
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and review_has_text("Purchase changed") and farm.coins == balance and farm.seed_inventory.russet == count, "changed price with safer debt still requires confirmation")
	check(game.hud._purchase_review.confirm_button.text.contains(farm.money(57)) and game.hud._purchase_review.confirm_button.text.contains("on account"), "updated account button shows actual new price")
	farm.coins = 100
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(active_review() and farm.coins == 100 and not game.hud._purchase_review.confirm_button.text.contains("account"), "debt repayment replaces account label with cash confirmation")
	game.hud._purchase_review.confirm_button.pressed.emit()
	check(not active_review() and farm.coins == 43 and farm.seed_inventory.russet == count+1, "cash replacement quote executes exactly once")
	tax_debt(45000)
	game._on_action("buy:russet:1")
	key(KEY_ESCAPE)
	check(not active_review() and farm.coins == -45000, "Escape cancels review without charge")
	# Maximum ranks and full flocks remain disabled regardless of account status.
	fresh()
	tax_debt(49000)
	farm.tools.hoe = 3
	farm.tools.water = 2
	await open_tools()
	check(game.hud._refs["upgrade:hoe"].disabled and game.hud._refs["upgrade:hoe"].text == "Fully upgraded", "maxed tool cannot enter checkout")
	check(game.hud._refs["upgrade:water"].disabled and game.hud._refs["upgrade:water"].text.contains("Frost"), "island-gated tool remains blocked")
	farm.barn_level = 20
	farm._recompute_capacity()
	game.hud.show_panel("barn",farm)
	await settle()
	check(game.hud._refs["upgrade:barn"].disabled, "maxed barn cannot enter checkout")
	game.activities.duck_counts["1"] = game.activities.duck_capacity()
	game.hud.show_panel("duck_patrol",farm)
	await settle()
	check(game.hud._refs["activity:duck"].disabled, "full flock stays blocked")
	# Each island presents its own paid garden-bed expansion in Tools.
	fresh()
	for island in [1,2,3]:
		cancel_review()
		game.hud.close_panel()
		farm.coins = 1e18
		if island > 1: farm.debug_unlock_island(island)
		farm.travel_to(island)
		farm.climate.acknowledge(farm)
		await open_tools()
		var land: Dictionary = farm.field_expansion_info()
		check(land.opened == land.total/2, "island %d starts with half its beds" % island)
		check(game.hud._refs["upgrade:expansion:detail"].text.contains("Unlock +%d" % int(land.remaining)), "island %d Tools describes exact remaining beds" % island)
		check(game.hud._refs["upgrade:expansion"].text.contains(farm.money(float(land.cost))), "island %d Tools displays local expansion cost" % island)
		check(Review.cost_for(game,"upgrade:expansion") == float(land.cost), "island %d checkout quotes matching land cost" % island)
		balance = farm.coins
		game.hud._refs["upgrade:expansion"].pressed.emit()
		check(farm.coins == balance-float(land.cost) and farm.field_expansion_info().complete, "island %d Tools actually purchases all remaining beds" % island)
		check(game.hud._refs["upgrade:expansion"].disabled and game.hud._refs["upgrade:expansion:detail"].text == "All %d beds open" % int(land.total), "island %d expansion becomes completed" % island)
	if game.touch_controls.enabled:
		for physical in [Vector2i(390,844),Vector2i(844,390)]:
			root.size = physical
			await settle()
			fresh()
			tax_debt(45000)
			game._on_action("upgrade:hoe")
			await settle()
			var bounds := root.get_visible_rect()
			var card: Control = game.hud._purchase_review.card
			check(bounds.grow(1).encloses(card.get_global_rect()), "warning fits touch viewport %s" % physical)
			for control in [game.hud._purchase_review.confirm_button,game.hud._purchase_review.cancel_button]:
				check(card.get_global_rect().grow(1).encloses(control.get_global_rect()), "review action fits card %s" % physical)
				check(control.size.y*float(physical.y)/bounds.size.y >= 43, "review action remains a 44px touch target at %s" % physical)
			cancel_review()
			farm.coins = farm.bankruptcy_limit()+1
			game._on_action("upgrade:hoe")
			await settle()
			check(bounds.grow(1).encloses(game.hud._purchase_review.card.get_global_rect()), "blocked warning fits touch viewport %s" % physical)
	game.queue_free()
	await settle()
	print("PURCHASE REVIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
