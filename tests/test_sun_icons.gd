extends SceneTree
## Segment 21g: the same sun drives the sky and materials; art keeps real targets.
var checks: int = 0
var failures: int = 0
var game
const ButtonArt = preload("res://scripts/illustrated_button.gd")
const Art = preload("res://scripts/item_icon.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + note)
func settle() -> void:
	for frame in range(12): await process_frame
	game.hud._process(.21); game.touch_controls._process(.21)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	# Freeze before yielding: a slow parallel test boot must not advance the
	# farm into random weather while a calm-noon light is being measured.
	game.set_process(false)
	game.state.climate.data.phase = "calm"
	game.state.climate.data.event = ""
	game.state.climate.data.timer = 0
	game._on_state_changed()
	await settle()
	if game.title_active(): game.title_scene.finish()
	game.tutorial.finish(); game.hud.close_panel()
	var world = game.world
	var energies: Array[float] = []
	var elevations: Array[float] = []
	for season in range(4):
		world.set_calendar(3, season, 75)
		world._season_blend = 1.0; world.set_day_time(74, season == 3); world.set_day_time(75, season == 3)
		world._animate_sun(3); world._animate_sun(.4)
		energies.append(world._sun.light_energy); elevations.append(-world._sun.rotation_degrees.x)
		check(is_equal_approx(world._day_environment.ambient_light_energy, .22) and is_equal_approx(world._sun.shadow_opacity, .85), "defined sun shadow with modest cool ambient in season %d" % season)
		check(world._day_environment.ambient_light_color.b > world._day_environment.ambient_light_color.r, "cool fill survives in each season")
		var sky: Dictionary = world.sun_sky_info()
		check(sky.direction.is_equal_approx(world._sun.global_basis.z.normalized()), "sky follows the rendered sun, including easing")
		check(world.coast.water_material.get_shader_parameter("sun_direction").is_equal_approx(sky.direction) and world.play_sky.get_shader_parameter("sun_direction").is_equal_approx(sky.direction), "water reflection and sky share one direction")
		check(sky.screen.x >= .2 and sky.screen.x <= .8 and sky.screen.y < .2, "sun stays in the sky behind farm geometry")
	check(is_equal_approx(energies[0],1.4) and is_equal_approx(energies[1],1.4) and energies[3] < energies[0], "calm noon sun is 1.4 with weaker Winter light: " + str(energies))
	check(elevations[2] < elevations[0] and elevations[3] < elevations[1], "Autumn and Winter have longer shadows")
	world.set_calendar(3,0,75); world._season_blend=1
	world.set_day_time(0); world._animate_sun(3); world._animate_sun(.4)
	var morning: Vector2 = world.sun_sky_info().screen
	world.set_day_time(150); world._animate_sun(3); world._animate_sun(.4)
	check(not morning.is_equal_approx(world.sun_sky_info().screen), "visible sun travels with the shadow arc")
	var tank: MeshInstance3D = world._project_nodes.rainwater.get_node("TankSteel")
	check(tank.material_override.roughness < .3 and tank.material_override.metallic_specular > .8 and not tank.material_override.get_meta("static_colour"), "tank keeps a direct sun highlight through batching")
	for sky in ["sun","cloud","rain","storm","snow"]:
		var climate: Dictionary = {"phase":"active", "event":{"sun":"drought","cloud":"","rain":"flood","storm":"storm","snow":"blizzard"}[sky],"forecast":{"high":.5}}
		check(Art.forecast_picture(climate).id == sky, "live icon distinguishes " + sky)
		climate.phase = "warning"
		check(Art.forecast_picture(climate).warning, "warning dot is independent of the drawn forecast")
	game.state.season_clock.season=2; game._on_state_changed()
	for dimensions: Vector2i in [Vector2i(1440,900),Vector2i(390,844),Vector2i(844,390)]:
		root.min_size=Vector2i.ZERO; root.size=dimensions
		game.touch_controls.enabled=dimensions.x<900
		if game.touch_controls.enabled: game.touch_controls._build_touch_sheets()
		game.touch_controls.resize(); await settle()
		var hud=game.hud
		for button: Button in [hud._menu_button,hud._weather_button]:
			check(button.get_script()==ButtonArt and button.has_picture(), "Weather and Menu have actual drawn art")
			check(button.get_theme_stylebox("normal").get_meta("surface_material")=="wood", "tool-tile wood surface")
			check(button.get_theme_stylebox("normal").content_margin_top>button.picture_pixels/button.picture_scale, "drawing is above the caption, not over it")
		check(game.touch_controls.fullscreen.position.x<12/hud._ui_scale and game.touch_controls.fullscreen.position.y<12/hud._ui_scale, "fullscreen has the reserved top-left target")
		check(not hud._season_strip.get_global_rect().intersects(game.touch_controls.fullscreen.get_global_rect()), "calendar leaves fullscreen clear")
		var sell: Button = game.touch_controls.sell_button if game.touch_controls.enabled else hud._quick_sell
		check(sell.has_picture() and Art.control_picture("barn",sell.text).id=="sack", "Sell shares the tool-tile sack")
		if game.touch_controls.enabled:
			check(not game.touch_controls.use_button.get_global_rect().intersects(game.touch_controls.tools_button.get_global_rect()), "taller drawn touch actions never overlap")
			check(Art.control_picture("", "Hoe / Tools").id=="hoe", "Tools depicts the equipped hoe")
		for page in ["market","barn","tools","accounts","pause"]:
			hud.show_panel(page,game.state); await settle()
			for button: Node in hud._modal_card.find_children("*","Button",true,false):
				if button.is_visible_in_tree() and not button.get_meta("kit_type", false) and not button.text.is_empty() and button.text not in ["×","?","+","−","←","→"] and not button.text.is_valid_float() and not button.text.begins_with("×"):
					check(button.has_method("has_picture") and button.has_picture(), "every word control has art: " + button.text)
					check(not Art.control_picture(str(button.get_meta("action","")),button.text).is_empty(), "page action keeps a drawing: " + button.text)
			hud.close_panel()
		hud.show_panel("climate", game.state); await settle()
		var help: Button = hud._refs.weather_page.find_children("*", "Button", true, false).filter(func(button): return button.text == "?")[0]
		help.pressed.emit(); await settle()
		var dialog: AcceptDialog = hud.root.find_children("*", "AcceptDialog", true, false)[0]
		check(dialog.get_ok_button().has_method("has_picture") and dialog.get_ok_button().has_picture(), "native field-notes Close also has a drawing")
		check(dialog.get_ok_button().get_theme_stylebox("normal").content_margin_top > dialog.get_ok_button().picture_pixels, "field-notes drawing leaves its Close caption clear")
		dialog.queue_free(); hud.close_panel(); await settle()
		game._start_conversation("mara", "market", true); await settle()
		check(game.conversation.scroll.get_global_rect().encloses(game.conversation.choice_buttons[0].get_global_rect()), "Mara's greeting leaves the illustrated seed button fully visible")
		game.conversation.finish(); await settle()
		if game.touch_controls.enabled:
			game.touch_controls.open_drawer("tools"); await settle()
			var water: Button = game.touch_controls.drawer_body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Water")[0]
			check(game.touch_controls.drawer.get_child(0).get_global_rect().encloses(water.get_global_rect()), "illustrated Water stays fully reachable in the touch drawer")
			game.touch_controls.drawer.hide()
	check(not InputMap.has_action("hurry"), "the removed Hurry control stays removed")
	game.queue_free(); await process_frame; await create_timer(.3).timeout
	print("SUN AND ICONS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
