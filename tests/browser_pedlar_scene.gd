extends "res://tests/browser_surfaces_scene.gd"
## V1 screenshots use real state, purchases, card phases and cart geometry.
func command(args: Array) -> void:
	if not args.is_empty() and str(args[0]).begins_with("pedlar_"):
		request += 1; _present_pedlar(str(args[0]),request)
	else: super.command(args)
func _present_pedlar(view: String, ticket: int) -> void:
	await super._present("play_spring",ticket)
	if ticket != request: return
	is_ready = false; current_page = view
	game.state.season_clock.year = 2; game.state.season_clock.season = 0
	game.state.pedlar.data = game.state.Pedlar.fresh()
	game.state.farmer_appearance.farm_name = "Copper Acres"
	game.state.seed_inventory.blue_pearl = 0; game.state.storage.blue_pearl = game.state.Stock.pile()
	game.state.pedlar.endow(game.state.storage)
	game.state.coins = 80000; game.state.rng.seed = 6
	game._on_state_changed()
	game.pedlar_cart.set_process(false)
	game.hud.root.show(); game.touch_controls.root.show()
	if view == "pedlar_passing":
		game.state.season_clock.year = 1; game.state.pedlar.data.passing_seconds = 8.5
		game._on_state_changed()
		game.pedlar_cart.sync_state(); game.pedlar_cart._process(0)
	else: game.pedlar_cart.sync_state()
	if view in ["pedlar_passing","pedlar_parked","pedlar_gate"]:
		game.world.camera.size = 30
		game.world.camera.position = Vector3(-4,1,11.5)+game.world.camera.basis.z*260
		game.world.fit_camera_depth()
		game.touch_controls.root.hide()
	if view == "pedlar_gate":
		game.state.pedlar.buy(game.state,"superstition"); game.pedlar_cart.sync_state()
		game.world.camera.size = 24
		game.world.camera.position = Vector3(-5.5,1.6,10.5)+game.world.camera.basis.z*260
		game.hud.root.hide()
	if view in ["pedlar_page","pedlar_odds","pedlar_windup","pedlar_result","pedlar_refused"]:
		game.hud.show_panel("pedlar",game.state)
		for frame in range(12): await get_tree().process_frame
		var page = game.hud._refs.pedlar_page; page.set_process(false)
		if view in ["pedlar_windup","pedlar_result"]:
			page.buy("seed"); page.advance_reveal(.50 if view=="pedlar_windup" else 1.12)
		if view=="pedlar_refused": game.state.coins = 0; page.buy("mystery")
	if view == "pedlar_collection":
		game.state.pedlar.data.superstitions = game.state.Pedlar.SUPERSTITIONS.common.duplicate()+["Lucky Boot"]
		game.state.pedlar.data.hooks = game.state.Pedlar.SUPERSTITIONS.common.duplicate()
		game.hud._dex_tab = "superstitions"; game.hud.show_panel("dex",game.state)
	if view == "pedlar_blue_sell":
		game.state.seed_inventory.blue_pearl = 1; game.state.pedlar.data.discovered.append("blue_pearl")
		game.hud.show_market(true,game.state)
	if view == "pedlar_farmer": game.hud.show_panel("farmer",game.state)
	game.hud.advance_panel_entrance(.8)
	for frame in range(10): await get_tree().process_frame
	game.hud.Kit.fit(game.hud); game.touch_controls.fit_modal()
	is_ready = true; _publish()
func _publish() -> void:
	super._publish()
	if not is_instance_valid(game.pedlar_cart): return
	last_report.pedlar = {"presence":game.state.pedlar.presence(game.state),"farm_name":game.state.farm_name(),"bought":game.state.pedlar.data.bought,"hooks":game.state.pedlar.data.hooks,"target_layer":game.pedlar_cart.target.collision_layer}
	if game.hud._refs.has("pedlar_page"):
		var page = game.hud._refs.pedlar_page
		last_report.pedlar.revealing = page.revealing
		last_report.pedlar.windup = page.windup_elapsed
		last_report.pedlar.result_visible = page.result_card.visible
	_publish_raw()
