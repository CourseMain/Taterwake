class_name FarmWorld
extends Node3D

const FarmerAvatar = preload("res://scripts/farmer_avatar.gd")
const GeometryBatcher = preload("res://scripts/world_geometry_batcher.gd")

signal plot_clicked(index: int)
signal station_clicked(station: String)
signal pest_warning(index: int, destroyed: bool)

var plot_positions: Array[Vector3] = []
var camera: Camera3D
var player: Node3D
var _player_heading: float = 0.45
var _plot_nodes: Array[Node3D] = []
var _crop_roots: Array[Node3D] = []
var _soil_meshes: Array[MeshInstance3D] = []
var _plot_states: Array[String] = []
var _selection: Node3D
var _player_body: Node3D
var _tool: Node3D
var _tool_time: float = 0.0
var _tool_duration: float = 0.5
var _tool_action: String = ""
var _effect_particles: Array[Dictionary] = []
var _area_selection: Node3D
var _area_key: String = ""
var _furrow_roots: Array[Node3D] = []
var _rare_gem: Node3D
var _ripe_sparkles: Array[Node3D] = []
var _rotor: Node3D
var _clouds: Array[Node3D] = []
var _villagers: Array[Node3D] = []
var _toolsmiths: Array[Node3D] = []
var _time: float = 0.0
var _day_elapsed: float = 0.0
var _applied_day_time: float = -1.0
var _day_environment: Environment
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Dictionary = {}
# Primitive resources are immutable and reused across crops and island rebuilds.
var _box_meshes: Dictionary = {}
var _cylinder_meshes: Dictionary = {}
var _sphere_mesh: SphereMesh
var _geometry_batcher := GeometryBatcher.new()
var current_island: int = 1
var _island2_unlocked: bool = false
var _island3_unlocked: bool = false
var _frost_active: bool = false
var _frost_seconds: float = 0.0
var _frost_label: Label3D
var _frost_beacon: Node3D
var _ice_roots: Array[Node3D] = []
var _pest_roots: Array[Node3D] = []
var _pest_borders: Array[Node3D] = []
var _pest_labels: Array[Label3D] = []
var _pest_visuals: Array[Dictionary] = []
var _pest_focus: int = -1
var _snowflakes: Array[Node3D] = []
var _roll_available: bool = true
var _roll_label: Label3D
var _roll_gate: Node3D
var _processing_active: bool = false
var _processing_progress: float = 0.0
var _processing_rotors: Array[Node3D] = []
var _processing_potatoes: Array[Node3D] = []
var _processing_steam: Array[Node3D] = []
var _processing_label: Label3D
var _processing_light: MeshInstance3D
var _travel_label: Label3D
var _dock_label: Label3D
var _dock_gate: Node3D
var _export_boat: Node3D
var _export_label: Label3D
var _export_flags: Array[Node3D] = []
var _export_active: bool = false
var _export_seconds: float = 0.0
var _export_particle_clock: float = 0.0
var _golden_hat: bool = false
var _hat_decoration: Node3D
var _impact_root: Node3D
var _boat_dock: Vector3 = Vector3(24.5, -0.25, 8.5)
var _boat_away: Vector3 = Vector3(27.0, -0.1, 1.0)
var _activity_info: Dictionary = {}
var _activity_label: Label3D
var _duck: Node3D
var _duck_body: Node3D
var _ducks: Array[Node3D] = []
var _duck_bodies: Array[Node3D] = []
var _duck_label: Label3D
var _duck_home: Vector3 = Vector3.ZERO
var _furnace_flame: Node3D
var _furnace_steam: Array[Node3D] = []
var _gear_hat_id: String = ""
var _gear_hat: Node3D
var _equipped_loadout: Dictionary = {}
var _gear_catalog: Dictionary = {}
var _tutorial_focus: String = ""
var _tutorial_show_labels: bool = true
var _tutorial_station_roots: Dictionary = {}
var _tutorial_label_layers: Array[Node3D] = []
var _tutorial_marker: Label3D
var _tutorial_plot_outline: Node3D
var _tutorial_marker_height: float = 0.0
var _tutorial_trail: Array[Node3D] = []

const GRASS := Color("8ebd78")
const SOIL := Color("705037")
const LEAF := Color("517e43")
const TEAL := Color("367b7d")
const CREAM := Color("f7e4b6")
const GOLD := Color("efbe53")
const DAY_CYCLE_SECONDS: float = 60.0
const FERRY_ROUTES: Dictionary = {
	1: [Vector3(7, 0, 7.7), Vector3(7, 0, -4.7), Vector3(15, 0, -4.7), Vector3(15, 0, -12), Vector3(11.5, 0, -12), Vector3(11.5, 0, -15.5)],
	2: [Vector3(10.2, 0, 10.6), Vector3(16, 0, 10.6), Vector3(16, 0, 9.6)],
	3: [Vector3(12.8, 0, 14), Vector3(20.6, 0, 14), Vector3(20.6, 0, 10), Vector3(22, 0, 10)],
}
const TUTORIAL_STATION_NAMES: Dictionary = {
	"barn": "THE BARN", "market": "SEED MARKET", "tools": "TOOLSMITH",
	"roll": "ROLL HOUSE", "builds": "WASH & SORT", "duck_patrol": "DUCK PATROL",
	"quests": "FARMING CHALLENGES", "island": "ISLAND FERRY", "activities": "ISLAND ACTIVITY",
}

func build_world(island: int = 1) -> void:
	_clear_world()
	current_island = island if island in [1, 2, 3] else 1
	_rng.seed = 8105 if current_island == 1 else (20482 if current_island == 2 else 31803)
	_lighting()
	if current_island == 1:
		_island()
		_paths()
		_barn(Vector3(-12.0, 0.0, -8.0))
		_market(Vector3(0.0, 0.0, -9.0))
		_tool_upgrade_station(Vector3(-6.4, 0.0, -8.5))
		_roll_house(Vector3(10.0, 0.0, -8.0))
		_windmill(Vector3(-13.2, 0.0, 4.0))
		_garden()
		_scenery()
		_golden_shores()
		_quest_board(Vector3(-12.0, 0.0, 8.1))
	elif current_island == 2:
		_tropical_island()
		_tropical_paths()
		_barn(Vector3(-15.0, 0.0, -10.0))
		_market(Vector3(-1.0, 0.0, -11.0))
		_tool_upgrade_station(Vector3(-8.0, 0.0, -10.6))
		_roll_house(Vector3(13.0, 0.0, -10.0))
		_garden()
		_tropical_scenery()
		_return_valley()
		_quest_board(Vector3(-12.0, 0.0, 11.0))
		_export_dock()
	else:
		_winter_island()
		_winter_paths()
		_barn(Vector3(-18.0, 0.0, -12.0))
		_market(Vector3(-3.0, 0.0, -14.0))
		_roll_house(Vector3(15.0, 0.0, -12.0))
		_garden()
		_winter_scenery()
		_quest_board(Vector3(-15.0, 0.0, 14.0))
		_winter_ferry()
		_ice_forge(Vector3(18.0, 0.0, 2.0))
	_ferry_path()
	_processing_station(Vector3(-18.0, 0.0, 3.5) if current_island == 3 else (Vector3(-15.0, 0.0, -1.0) if current_island == 2 else Vector3(-12.0, 0.0, -1.0)))
	_activity_station()
	player = Node3D.new()
	player.name = "PotatoFarmer"
	add_child(player)
	player.position = Vector3(0.0, 0.0, 12.5 if current_island == 3 else (10.5 if current_island == 2 else 9.0))
	_player_body = FarmerAvatar.new()
	player.add_child(_player_body)
	_player_body.setup()
	player.rotation.y = 0.45
	_player_heading = player.rotation.y
	_tool = Node3D.new()
	player.add_child(_tool)
	_tool.position = Vector3(0.65, 0.8, 0.22)
	_tool.visible = false
	_area_selection = Node3D.new()
	add_child(_area_selection)
	_selection = Node3D.new()
	add_child(_selection)
	for x in [-1.03, 1.03]:
		_box(_selection, Vector3(x, 0.20, 0.0), Vector3(0.085, 0.055, 2.13), Color("ffeaa1"))
	for z in [-1.03, 1.03]:
		_box(_selection, Vector3(0.0, 0.20, z), Vector3(2.13, 0.055, 0.085), Color("ffeaa1"))
	_selection.visible = false
	set_island2_unlocked(_island2_unlocked)
	set_island3_unlocked(_island3_unlocked)
	set_frost_state(_frost_active, _frost_seconds)
	set_golden_hat(_golden_hat)
	set_equipment(_equipped_loadout, _gear_catalog)
	set_export_state(_export_active, _export_seconds)
	set_roll_available(_roll_available)
	set_processing(_processing_active, _processing_progress)
	set_activity_state(_activity_info)
	_batch_world_geometry()
	_prepare_tutorial_guidance()
	set_tutorial_focus(_tutorial_focus, _tutorial_show_labels)


func _batch_world_geometry() -> void:
	# These individual meshes change transform, material or visibility at runtime.
	# All Node3D roots stay intact, including gates, ducks, rotors and tutorials.
	var mutable_meshes: Dictionary = {}
	for collection: Array in [_soil_meshes, _snowflakes, _processing_potatoes, _processing_steam, _furnace_steam, _export_flags]:
		for node: Node3D in collection:
			mutable_meshes[node.get_instance_id()] = true
	if is_instance_valid(_processing_light):
		mutable_meshes[_processing_light.get_instance_id()] = true
	_geometry_batcher.batch_tree(self, mutable_meshes)


func _prepare_tutorial_guidance() -> void:
	# A parent layer hides signs without overwriting their own visibility. This
	# keeps live station status updates and normal label visibility intact.
	for station_roots: Array in _tutorial_station_roots.values():
		for station_root: Node3D in station_roots:
			for label: Label3D in station_root.find_children("*", "Label3D", true, false):
				if label.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
					continue
				var layer := Node3D.new()
				layer.name = "TutorialSignVisibility"
				label.get_parent().add_child(layer)
				label.reparent(layer)
				_tutorial_label_layers.append(layer)
	_tutorial_marker = _label(self, "", Vector3.ZERO, 30, Color("fff0a3"))
	_tutorial_marker.name = "TutorialDestination"
	_tutorial_marker.outline_modulate = Color("354b3a")
	_tutorial_marker.outline_size = 10
	_tutorial_marker.visible = false
	_tutorial_plot_outline = Node3D.new()
	_tutorial_plot_outline.name = "TutorialTargetBed"
	add_child(_tutorial_plot_outline)
	for axis: int in range(2):
		for side: float in [-1.0, 1.0]:
			var point := Vector3(side * 1.06, 0.25, 0.0) if axis == 0 else Vector3(0.0, 0.25, side * 1.06)
			var dimensions := Vector3(0.12, 0.06, 2.24) if axis == 0 else Vector3(2.24, 0.06, 0.12)
			var edge := _box(_tutorial_plot_outline, point, dimensions, Color("ffe290"))
			var material := edge.material_override.duplicate() as StandardMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			edge.material_override = material
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tutorial_plot_outline.visible = false
	for index: int in range(6):
		var chevron := Node3D.new()
		chevron.name = "TutorialTrail%d" % index
		add_child(chevron)
		for side: float in [-1.0, 1.0]:
			var wing := _box(chevron, Vector3(side * 0.26, 0.0, -0.26), Vector3(0.20, 0.05, 0.80), Color("ffe290"))
			wing.rotation.y = -side * PI / 4.0
			var glow: StandardMaterial3D = wing.material_override.duplicate()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wing.material_override = glow
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chevron.hide()
		_tutorial_trail.append(chevron)


func station_position(station: String) -> Vector3:
	if station == "island":
		return ferry_position()
	# The last target for a station is its main entrance (the ferry dock rather
	# than the distant island miniature, and the workshop rather than its NPC).
	var station_roots: Array = _tutorial_station_roots.get(station, [])
	return (station_roots.back() as Node3D).position if not station_roots.is_empty() else Vector3.ZERO


func ferry_position() -> Vector3:
	return FERRY_ROUTES[current_island].back()


func farm_bounds() -> Rect2:
	return Rect2(-25, -8, 50, 26) if current_island == 3 else (Rect2(-20, -6, 40, 20) if current_island == 2 else Rect2(-17, -5, 35, 17))


func clamp_walk_position(point: Vector3) -> Vector3:
	point.y = 0.0
	var bounds: Rect2 = farm_bounds()
	var closest := Vector3(clampf(point.x, bounds.position.x, bounds.end.x), 0, clampf(point.z, bounds.position.y, bounds.end.y))
	# Extend the first island only along its new path and pier, not into the sea
	# or through the row of shops. The other two boarding areas are on land.
	if current_island == 1:
		var route: Array = FERRY_ROUTES[1]
		for index: int in range(2, route.size() - 1):
			var a: Vector3 = route[index]
			var b: Vector3 = route[index + 1]
			var margin: float = 0.65
			var candidate := Vector3(clampf(point.x, minf(a.x, b.x) - margin, maxf(a.x, b.x) + margin), 0,
				clampf(point.z, minf(a.z, b.z) - margin, maxf(a.z, b.z) + margin))
			if point.distance_squared_to(candidate) < point.distance_squared_to(closest):
				closest = candidate
	return closest


func _route_anchor(point: Vector3) -> Dictionary:
	var route: Array = FERRY_ROUTES[current_island]
	var best: Dictionary = {"point": route[0], "distance": INF, "along": 0.0}
	var along: float = 0.0
	for index: int in range(route.size() - 1):
		var a: Vector3 = route[index]
		var b: Vector3 = route[index + 1]
		var candidate: Vector3 = Geometry3D.get_closest_point_to_segment(point, a, b)
		var distance: float = point.distance_squared_to(candidate)
		if distance < float(best.distance):
			best = {"point": candidate, "distance": distance, "along": along + a.distance_to(candidate)}
		along += a.distance_to(b)
	return best


func walk_route(from: Vector3, to: Vector3, follow_ferry: bool = false) -> Array[Vector3]:
	from.y = 0.0
	to = clamp_walk_position(to)
	if not follow_ferry and not (current_island == 1 and (from.z < -5.0 or to.z < -5.0)):
		return [to]
	var start: Dictionary = _route_anchor(from)
	var finish: Dictionary = _route_anchor(to)
	var route: Array = FERRY_ROUTES[current_island]
	var result: Array[Vector3] = [start.point]
	var bends: Array[Vector3] = []
	var along: float = 0.0
	for index: int in range(1, route.size()):
		along += (route[index - 1] as Vector3).distance_to(route[index])
		if along > minf(start.along, finish.along) and along < maxf(start.along, finish.along):
			bends.append(route[index])
	if float(start.along) > float(finish.along):
		bends.reverse()
	result.append_array(bends)
	result.append(finish.point)
	result.append(to)
	return result


func _ferry_path() -> void:
	var path := _root("FerryPath", Vector3.ZERO)
	var route: Array = FERRY_ROUTES[current_island]
	var color := Color("d4bc82") if current_island == 1 else (Color("e2c78e") if current_island == 2 else Color("a9bbc6"))
	# Existing village roads lead to these spurs; leave the wooden pier exposed.
	var first: int = 1 if current_island == 1 else 0
	for index: int in range(first, route.size() - 1):
		var a: Vector3 = route[index]
		var b: Vector3 = route[index + 1]
		if current_island == 1 and index == route.size() - 2:
			b.z = -14.0
		var length: float = a.distance_to(b)
		var strip := _box(path, (a + b) * 0.5 + Vector3(0, 0.045, 0), Vector3(2.2, 0.08, length + 0.25), color)
		strip.rotation.y = atan2(b.x - a.x, b.z - a.z)
		for step: int in range(int(length / 0.85)):
			var paver := _box(path, a.move_toward(b, (step + 0.5) * 0.85) + Vector3(0, 0.10, 0), Vector3(0.78, 0.035, 0.43), color.lightened(0.18))
			paver.rotation.y = strip.rotation.y
	# Compact signs stay in the world; the tutorial can hide them with other signs.
	var sign := _root("FerryWayfinder", route[first] + Vector3(1.35, 0, 1.15))
	_cylinder(sign, Vector3(0, 0.65, 0), 0.08, 0.08, 1.3, Color("8d704f"), 6)
	_box(sign, Vector3(0, 1.3, 0), Vector3(1.9, 0.65, 0.15), TEAL if current_island != 3 else Color("577c97"))
	_label(sign, "FERRY →", Vector3(0, 1.32, 0.1), 23, CREAM, false)
	_target(sign, Vector3(0, 0.85, 0), Vector3(2.0, 1.7, 0.4), "station", "island")


func set_tutorial_focus(station: String, show_labels: bool = false) -> void:
	_tutorial_focus = station
	_tutorial_show_labels = show_labels
	for layer: Node3D in _tutorial_label_layers:
		layer.visible = show_labels
	if not is_instance_valid(_tutorial_marker):
		return
	_tutorial_marker.visible = false
	_tutorial_plot_outline.visible = false
	for chevron: Node3D in _tutorial_trail:
		chevron.hide()
	if station.is_empty():
		return
	var point: Vector3
	var title: String = str(TUTORIAL_STATION_NAMES.get(station, ""))
	if station.begins_with("plot:"):
		var plot_text: String = station.trim_prefix("plot:")
		if not plot_text.is_valid_int():
			return
		var index: int = int(plot_text)
		if index < 0 or index >= plot_positions.size():
			return
		point = plot_positions[index] + Vector3(0.0, 1.85, 0.0)
		_tutorial_plot_outline.position = plot_positions[index]
		_tutorial_plot_outline.visible = true
		_tutorial_marker.font_size = 72
		_tutorial_marker.pixel_size = 0.025
	elif _tutorial_station_roots.has(station):
		_tutorial_marker.font_size = 38
		_tutorial_marker.pixel_size = 0.019
		var station_roots: Array = _tutorial_station_roots[station]
		var station_root: Node3D = station_roots.back()
		point = station_position(station) + Vector3(0.0, 3.0, 0.0)
		for label: Label3D in station_root.find_children("*", "Label3D", true, false):
			if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				point.y = maxf(point.y, to_local(label.global_position).y + 0.8)
	else:
		return
	_tutorial_marker.text = "▼" if title.is_empty() else title + "\n▼"
	_tutorial_marker.position = point
	_tutorial_marker_height = point.y
	_tutorial_marker.visible = true


func switch_island(id: int) -> void:
	var destination: int = id if id in [1, 2, 3] else 1
	if destination == current_island and is_instance_valid(camera):
		return
	build_world(destination)


func _clear_world() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	plot_positions.clear()
	_plot_nodes.clear()
	_crop_roots.clear()
	_soil_meshes.clear()
	_plot_states.clear()
	_furrow_roots.clear()
	_ripe_sparkles.clear()
	_clouds.clear()
	_villagers.clear()
	_toolsmiths.clear()
	_effect_particles.clear()
	_export_flags.clear()
	_ice_roots.clear()
	_pest_roots.clear()
	_pest_borders.clear()
	_pest_labels.clear()
	_pest_visuals.clear()
	_pest_focus = -1
	_snowflakes.clear()
	_processing_rotors.clear()
	_processing_potatoes.clear()
	_processing_steam.clear()
	_furnace_steam.clear()
	_ducks.clear()
	_duck_bodies.clear()
	_materials.clear()
	_area_key = ""
	_tool_time = 0.0
	_time = 0.0
	_day_environment = null
	_applied_day_time = -1.0
	_sun = null
	_moon = null
	_export_particle_clock = 0.0
	camera = null
	player = null
	_player_body = null
	_tool = null
	_selection = null
	_area_selection = null
	_rare_gem = null
	_rotor = null
	_travel_label = null
	_dock_label = null
	_dock_gate = null
	_export_boat = null
	_export_label = null
	_hat_decoration = null
	_impact_root = null
	_frost_label = null
	_frost_beacon = null
	_roll_label = null
	_roll_gate = null
	_processing_label = null
	_processing_light = null
	_activity_label = null
	_duck = null
	_duck_body = null
	_duck_label = null
	_furnace_flame = null
	_gear_hat = null
	_tutorial_station_roots.clear()
	_tutorial_label_layers.clear()
	_tutorial_marker = null
	_tutorial_plot_outline = null
	_tutorial_trail.clear()

func _lighting() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "DayNightEnvironment"
	_day_environment = Environment.new()
	_day_environment.background_mode = Environment.BG_COLOR
	_day_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_day_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = _day_environment
	add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "CycleSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0
	_sun.shadow_bias = 0.08
	add_child(_sun)
	# A gentle fill keeps crops, paths and the farmer readable throughout night.
	# Both lights use Compatibility features shared by native and web renderers.
	_moon = DirectionalLight3D.new()
	_moon.name = "CycleMoon"
	_moon.rotation_degrees = Vector3(-58.0, -15.0, 0.0)
	_moon.light_color = Color("b8d4ff") if current_island == 3 else Color("b6caf0")
	_moon.shadow_enabled = false
	add_child(_moon)
	set_day_time(_day_elapsed)
	camera = Camera3D.new()
	camera.name = "DioramaCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 49.0 if current_island == 3 else (43.0 if current_island == 2 else 38.0)
	camera.position = Vector3(23.0, 31.0, 33.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.3, 0.5) if current_island == 3 else (Vector3(0.0, 0.3, -1.0) if current_island == 2 else Vector3(-0.3, 0.3, -1.2)))
	camera.current = true
	camera.far = 200.0


func set_day_time(elapsed: float) -> void:
	# The farm's saved elapsed time owns this clock: travelling and loading a
	# save preserve the same sky, and paused gameplay cannot advance it twice.
	if not is_finite(elapsed) or elapsed < 0.0:
		return
	_day_elapsed = fposmod(elapsed, DAY_CYCLE_SECONDS)
	if not is_instance_valid(_sun) or _day_environment == null:
		return
	if _day_elapsed == _applied_day_time:
		return
	_applied_day_time = _day_elapsed
	var phase: float = _day_elapsed / DAY_CYCLE_SECONDS
	var orbit: float = phase * TAU
	var height: float = cos(orbit)
	var daylight: float = smoothstep(0.0, 1.0, (height + 1.0) * 0.5)
	var twilight: float = pow(1.0 - absf(height), 3.0)
	var day_sky: Color = Color("c3dce8") if current_island == 3 else (Color("b7e3df") if current_island == 2 else Color("c5deda"))
	var night_sky: Color = Color("263758") if current_island == 3 else (Color("263951") if current_island == 2 else Color("28364f"))
	var dusk_sky: Color = Color("b69bc5") if current_island == 3 else (Color("ecb986") if current_island == 2 else Color("d7a5a1"))
	var day_sun: Color = Color("f0f6ff") if current_island == 3 else Color("fff8ed")
	var dusk_sun: Color = Color("ffcddc") if current_island == 3 else Color("ffd1a0")
	_day_environment.background_color = night_sky.lerp(day_sky, daylight).lerp(dusk_sky, twilight * 0.72)
	_day_environment.ambient_light_color = Color("9dafd0").lerp(Color("f0f3e8"), daylight).lerp(dusk_sun, twilight * 0.25)
	_day_environment.ambient_light_energy = lerpf(0.44, 0.45, daylight)
	_sun.light_color = day_sun.lerp(dusk_sun, twilight * 0.75)
	_sun.light_energy = 0.65 * daylight
	_sun.rotation_degrees = Vector3(-48.0 + 24.0 * sin(orbit), -35.0 + 32.0 * sin(orbit), 0.0)
	_moon.light_energy = 0.48 * (1.0 - daylight)


func day_cycle_info() -> Dictionary:
	var phase: float = _day_elapsed / DAY_CYCLE_SECONDS
	return {"seconds": _day_elapsed, "duration": DAY_CYCLE_SECONDS, "phase": phase,
		"daylight": smoothstep(0.0, 1.0, (cos(phase * TAU) + 1.0) * 0.5)}

func _island() -> void:
	_prism(self, Vector3(0.0, -1.35, 0.0), 39.5, 30.0, 1.7, Color("8a6346"))
	_prism(self, Vector3(0.0, -0.58, 0.0), 40.0, 30.4, 0.55, Color("b68b59"))
	_prism(self, Vector3(0.0, -0.17, 0.0), 40.3, 30.7, 0.3, GRASS)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.set_meta("ground", true)
	add_child(ground)
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.15, 30.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.08
	ground.add_child(collision)
	# Repeated strata and embedded stones make the floating soil edge readable.
	for i in range(24):
		var x: float = -17.0 + float(i) * 1.45
		var stone := _sphere(self, Vector3(x, -0.98, 15.05), Vector3(0.26, 0.13, 0.07), Color("bd9668"))
		stone.rotation.z = _rng.randf_range(-0.6, 0.6)

func _paths() -> void:
	_box(self, Vector3(0.0, 0.025, -4.7), Vector3(30.0, 0.065, 2.0), Color("d4bc82"))
	_box(self, Vector3(7.0, 0.028, 1.5), Vector3(2.0, 0.07, 13.6), Color("d4bc82"))
	_box(self, Vector3(-2.0, 0.03, 7.7), Vector3(19.6, 0.065, 2.15), Color("d4bc82"))
	for i in range(32):
		var pos := Vector3(-15.0 + float(i) * 0.95, 0.067, -4.7 + _rng.randf_range(-0.62, 0.62))
		var paver := _box(self, pos, Vector3(_rng.randf_range(0.35, 0.7), 0.04, _rng.randf_range(0.35, 0.6)), Color("e4ce98"))
		paver.rotation.y = _rng.randf_range(-0.22, 0.22)
	for i in range(15):
		var pos := Vector3(7.0 + _rng.randf_range(-0.4, 0.4), 0.085, -3.9 + float(i) * 0.8)
		_box(self, pos, Vector3(0.8, 0.055, 0.48), Color("e4ce98"))

func _garden() -> void:
	var tropical: bool = current_island == 2
	var winter: bool = current_island == 3
	var columns: int = 10 if winter else (8 if tropical else 6)
	var rows: int = 8 if winter else (6 if tropical else 4)
	var field_center: Vector3 = Vector3(-0.45, 0.025, 2.55) if winter else (Vector3(-0.35, 0.025, 1.95) if tropical else Vector3(-1.75, 0.025, 1.45))
	var field_size: Vector3 = Vector3(23.3, 0.08, 18.7) if winter else (Vector3(18.75, 0.08, 14.1) if tropical else Vector3(14.25, 0.08, 9.0))
	_box(self, field_center, field_size, Color("acbbc0") if winter else (Color("d2b676") if tropical else Color("b9ad71")))
	for row in range(rows):
		for col in range(columns):
			var index: int = row * columns + col
			var pos := Vector3((-10.8 if winter else (-8.4 if tropical else -7.5)) + float(col) * 2.3, 0.0, (-5.5 if winter else (-3.8 if tropical else -2.0)) + float(row) * 2.3)
			plot_positions.append(pos)
			var root := Node3D.new()
			root.name = "Plot_%02d" % index
			root.position = pos
			add_child(root)
			_plot_nodes.append(root)
			var soil := _box(root, Vector3(0.0, 0.105, 0.0), Vector3(1.93, 0.2, 1.93), SOIL)
			_soil_meshes.append(soil)
			var furrows := Node3D.new()
			root.add_child(furrows)
			_furrow_roots.append(furrows)
			for furrow in [-0.56, 0.0, 0.56]:
				_box(furrows, Vector3(furrow, 0.22, 0.0), Vector3(0.25, 0.085, 1.7), Color("8c6747"))
			var crops := Node3D.new()
			root.add_child(crops)
			_crop_roots.append(crops)
			var ice := Node3D.new()
			ice.name = "FrostbreakIce"
			root.add_child(ice)
			_ice_roots.append(ice)
			if winter:
				_box(ice, Vector3(0.0, 0.27, 0.0), Vector3(1.88, 0.10, 1.88), Color("aed8e8"))
				for point in [Vector3(-0.61, 0.52, -0.55), Vector3(0.57, 0.48, 0.50)]:
					var crystal := _cylinder(ice, point, 0.19, 0.05, 0.52, Color("d2ecf4"), 5)
					crystal.rotation.z = -0.22
				_bar(ice, Vector3(-0.76, 0.334, 0.12), Vector3(0.59, 0.334, -0.37), 0.018, Color("eef8fa"))
				_bar(ice, Vector3(-0.10, 0.335, -0.76), Vector3(0.38, 0.335, 0.67), 0.018, Color("eaf5f8"))
			ice.visible = false
			var pests := Node3D.new()
			pests.name = "CropPests"
			root.add_child(pests)
			pests.visible = false
			_pest_roots.append(pests)
			var pest_border := Node3D.new()
			pest_border.name = "PestBorder"
			root.add_child(pest_border)
			pest_border.visible = false
			_pest_borders.append(pest_border)
			var warning: Label3D = _label(root, "", Vector3(0.0, 2.14, 0.0), 32, Color("ffde70"))
			warning.name = "PestYield"
			warning.pixel_size = 0.020
			warning.outline_modulate = Color("4a241e")
			warning.outline_size = 8
			warning.visible = false
			_pest_labels.append(warning)
			_pest_visuals.append({"active": false, "ticks": 0, "destroyed": false, "caption_time": 0.0, "shake_time": 0.0})
			_plot_states.append("")
			_target(root, Vector3(0.0, 0.17, 0.0), Vector3(2.08, 0.5, 2.08), "plot_index", index)
	# Low, open fence leaves each individual plot accessible to the camera.
	if winter:
		_fence(Vector3(-12.4, 0.0, -6.8), Vector3(-12.4, 0.0, 12.0), 9)
		_fence(Vector3(-12.4, 0.0, 12.0), Vector3(11.5, 0.0, 12.0), 11)
	elif tropical:
		_fence(Vector3(-10.0, 0.0, -5.0), Vector3(-10.0, 0.0, 9.0), 7)
		_fence(Vector3(-10.0, 0.0, 9.0), Vector3(9.1, 0.0, 9.0), 9)
	else:
		_fence(Vector3(-9.05, 0.0, -3.2), Vector3(-9.05, 0.0, 6.3), 5)
		_fence(Vector3(-9.05, 0.0, 6.3), Vector3(5.45, 0.0, 6.3), 7)

func update_plots(plots: Array) -> void:
	for i in range(mini(plots.size(), _crop_roots.size())):
		var data: Dictionary = plots[i]
		if i < _ice_roots.size():
			_ice_roots[i].visible = current_island == 3 and bool(data.get("frozen", false))
		var unlocked: bool = bool(data.get("unlocked", true))
		var stage: int = int(data.get("stage", 0))
		var infested: bool = unlocked and stage > 0 and bool(data.get("pests", false))
		var pest_damage: float = clampf(float(data.get("pest_damage", 0.0)), 0.0, 1.0)
		var damage_level: int = int(pest_damage * 10.0)
		_update_pest_visual(i, data, infested, pest_damage)
		var watered: bool = bool(data.get("watered", false))
		var tilled: bool = bool(data.get("tilled", true))
		var crop_kind: String = str(data.get("crop", "russet"))
		var crop_color: Color = Color("dfb36f")
		var foliage_color: Color = Color("749e44")
		var crop_scale: float = 1.0
		match crop_kind:
			"golden":
				crop_color = Color("f5cc38")
				foliage_color = Color("9ba149")
			"giant":
				crop_color = Color("d7a37b")
				crop_scale = 1.7
				foliage_color = Color("729758")
			"radioactive":
				crop_color = Color("afff48")
				foliage_color = Color("75c962")
			"sunburst":
				crop_color = Color("ffa629")
				foliage_color = Color("83a746")
				crop_scale = 1.2
			"icecap":
				crop_color = Color("d8f1ff")
				foliage_color = Color("759ba5")
				crop_scale = 1.25
		foliage_color = foliage_color.lerp(Color("988759"), float(damage_level) * 0.065)
		crop_color = crop_color.lerp(Color("9e8969"), float(damage_level) * 0.035)
		var elapsed: float = float(data.get("elapsed", 0.0))
		_crop_roots[i].scale.y = 0.72 + minf(elapsed / 35.0, 1.0) * 0.28 if stage == 2 else 1.0
		var key: String = "%s/%d/%s/%s/%s/%s/%d/%s" % [str(unlocked), stage, str(watered), str(tilled), crop_kind, str(infested), damage_level, str(data.get("pest_destroyed", false))]
		if key == _plot_states[i]:
			continue
		_plot_states[i] = key
		var root: Node3D = _crop_roots[i]
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
		_furrow_roots[i].visible = unlocked and tilled
		_soil_meshes[i].material_override = _mat(Color("66513b") if watered else (SOIL if tilled else Color("8d9c70")))
		if not unlocked:
			_soil_meshes[i].material_override = _mat(Color("89916a"))
			for point in [Vector3(-0.55, 0.25, -0.35), Vector3(0.42, 0.26, 0.42)]:
				_sphere(root, point, Vector3(0.32, 0.2, 0.25), Color("969888"))
			_box(root, Vector3(0.0, 0.43, 0.0), Vector3(1.15, 0.12, 0.16), Color("bc9d6d")).rotation.z = 0.46
			_box(root, Vector3(0.0, 0.43, 0.0), Vector3(1.15, 0.12, 0.16), Color("bc9d6d")).rotation.z = -0.46
			_geometry_batcher.batch_siblings(root)
			continue
		if not tilled and stage == 0:
			for weed_index in range(3):
				var weed_pos := Vector3(-0.55 + float(weed_index) * 0.53, 0.30, 0.2 * sin(float(weed_index) * 3.0))
				_leaf(root, weed_pos, Vector3(0.08, 0.23, 0.08), Color("809d61"), -0.3)
				_leaf(root, weed_pos + Vector3(0.10, 0.03, 0.0), Vector3(0.08, 0.25, 0.08), Color("9bab75"), 0.3)
		if watered and stage < 3:
			for p in range(4):
				_sphere(root, Vector3(-0.65 + float(p % 2) * 1.3, 0.225, -0.6 + float(p / 2) * 1.2), Vector3(0.13, 0.025, 0.18), Color("8ba39a"))
		if stage <= 0:
			if bool(data.get("pest_destroyed", false)):
				# A few chewed stems remain after the warning fades; planting clears them.
				for stalk in range(3):
					var remains := Vector3(-0.48 + float(stalk) * 0.48, 0.33, 0.05)
					_bar(root, remains, remains + Vector3(0.08, 0.16, 0.0), 0.035, Color("b69255"))
					_sphere(root, remains + Vector3(0.10, -0.08, 0.16), Vector3(0.14, 0.055, 0.09), Color("ad8545"))
			_geometry_batcher.batch_siblings(root)
			continue
		for crop in range(4):
			var pos := Vector3(-0.48 + float(crop % 2) * 0.96, 0.25, -0.48 + float(crop / 2) * 0.96)
			if stage == 1:
				_sphere(root, pos, Vector3(0.24, 0.08, 0.18), Color("af865a"))
				_leaf(root, pos + Vector3(-0.07, 0.14, 0.0), Vector3(0.17, 0.08, 0.11), Color("8eaf4f"), -0.4)
				_leaf(root, pos + Vector3(0.07, 0.2, 0.0), Vector3(0.17, 0.08, 0.11), Color("a2bc62"), 0.4)
			else:
				var height: float = 0.53 if stage == 2 else 0.77
				_cylinder(root, pos + Vector3(0.0, height * 0.48, 0.0), 0.045, 0.025, height, LEAF, 5)
				for leaf_index in range(5):
					var angle: float = float(leaf_index) * 2.4 + float(crop)
					var radius: float = 0.16 if stage == 2 else 0.23
					var leaf_pos: Vector3 = pos + Vector3(cos(angle) * radius, 0.20 + float(leaf_index) * height * 0.13, sin(angle) * radius)
					var leaf_color: Color = foliage_color if leaf_index % 2 == 0 else foliage_color.darkened(0.20)
					var leaf := _sphere(root, leaf_pos, Vector3(0.30, 0.11, 0.19) * (0.84 if stage == 2 else 1.0), leaf_color)
					leaf.rotation = Vector3(0.0, -angle, 0.28)
				if stage == 3:
					for potato_index in range(2):
						var potato_pos: Vector3 = pos + Vector3(-0.2 + float(potato_index) * 0.39, 0.02, 0.20)
						var potato := _sphere(root, potato_pos, Vector3(0.22, 0.17, 0.18) * crop_scale, crop_color)
						potato.rotation.y = 0.6
						_sphere(root, potato_pos + Vector3(0.08, 0.14, 0.04) * crop_scale, Vector3(0.025, 0.015, 0.025), crop_color.darkened(0.22))
					_sphere(root, pos + Vector3(0.0, height + 0.06, 0.0), Vector3(0.09, 0.055, 0.09), Color("f5dfdc"))
					_sphere(root, pos + Vector3(0.0, height + 0.10, 0.0), Vector3(0.025, 0.025, 0.025), GOLD)
					if crop_kind == "sunburst":
						_sunburst_bloom(root, pos + Vector3(0.0, height + 0.11, 0.0))
					elif crop_kind == "icecap":
						_icecap_bloom(root, pos + Vector3(0.0, height + 0.13, 0.0))
		if stage == 3:
			var sparkle := _gem(root, Vector3(0.0, 1.53, 0.0), crop_color if crop_kind == "radioactive" else GOLD, 0.12)
			_ripe_sparkles.append(sparkle)
		_geometry_batcher.batch_siblings(root)
	_update_pest_caption_density()


func highlight_plot(index: int) -> void:
	if _selection == null:
		return
	if _pest_focus != index:
		_pest_focus = index
		_update_pest_caption_density()
	_selection.visible = index >= 0 and index < plot_positions.size()
	if _selection.visible:
		_selection.position = plot_positions[index]

func set_player_position(pos: Vector3) -> void:
	if player == null:
		return
	var direction: Vector3 = pos - player.position
	if Vector2(direction.x, direction.z).length() > 0.005:
		_player_heading = atan2(direction.x, direction.z)
	player.position = Vector3(pos.x, 0.0, pos.z)

func animate(delta: float, moving: bool) -> void:
	_time += delta
	if is_instance_valid(_tutorial_marker) and _tutorial_marker.visible:
		_tutorial_marker.position.y = _tutorial_marker_height + sin(_time * 2.8) * 0.16
		var destination: Vector3 = _tutorial_marker.position
		destination.y = 1.15
		var origin: Vector3 = player.position
		origin.y = 1.15
		var direction: Vector3 = destination - origin
		var distance: float = direction.length()
		var guide: Curve3D
		if _tutorial_focus == "island" and distance > 3.0:
			guide = Curve3D.new()
			guide.add_point(origin)
			for point: Vector3 in walk_route(player.position, ferry_position(), true):
				var raised := Vector3(point.x, 1.15, point.z)
				if raised.distance_to(guide.get_point_position(guide.point_count - 1)) > 0.01:
					guide.add_point(raised)
		for index: int in range(_tutorial_trail.size()):
			var chevron: Node3D = _tutorial_trail[index]
			chevron.visible = distance > 3.0
			chevron.position = origin.lerp(destination, float(index + 1) / 8.0)
			if guide != null:
				var along: float = guide.get_baked_length() * float(index + 1) / 8.0
				chevron.position = guide.sample_baked(along)
				direction = guide.sample_baked(along + 0.1) - chevron.position
			chevron.rotation.y = atan2(direction.x, direction.z)
			chevron.scale = Vector3.ONE * (1.05 + 0.15 * sin(_time * 3.0 - index * 0.65))
	if is_instance_valid(player):
		player.rotation.y = lerp_angle(player.rotation.y, _player_heading, 1.0 - exp(-12.0 * delta))
	if is_instance_valid(_player_body):
		_player_body.animate(delta, moving)
	if is_instance_valid(_rotor):
		_rotor.rotation.z += delta * 0.38
	_animate_effects(delta)
	_animate_export(delta)
	_animate_winter(delta)
	_animate_processing(delta)
	_animate_pests(delta)
	_animate_activities(delta)
	if is_instance_valid(_rare_gem):
		_rare_gem.rotation.y += delta * 0.75
		_rare_gem.position.y = 1.65 + sin(_time * 2.1) * 0.09
	for i in range(_ripe_sparkles.size() - 1, -1, -1):
		if not is_instance_valid(_ripe_sparkles[i]):
			_ripe_sparkles.remove_at(i)
		else:
			_ripe_sparkles[i].rotation.y += delta * 1.5
			_ripe_sparkles[i].scale = Vector3.ONE * (0.9 + sin(_time * 3.0 + float(i)) * 0.16)

	for i in range(_villagers.size()):
		_villagers[i].position.y = sin(_time * 1.5 + float(i)) * 0.035
	for toolsmith in _toolsmiths:
		toolsmith.animate(delta, false)
	for i in range(_clouds.size()):
		_clouds[i].position.x += delta * 0.06
		if _clouds[i].position.x > 24.0:
			_clouds[i].position.x = -24.0

func pick(screen_pos: Vector2) -> Dictionary:
	if camera == null or not is_inside_tree():
		return {}
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var end: Vector3 = origin + camera.project_ray_normal(screen_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Node = result["collider"]
	if collider.has_meta("plot_index"):
		return {"plot_index": int(collider.get_meta("plot_index"))}
	if collider.has_meta("station"):
		return {"station": str(collider.get_meta("station"))}
	return {"ground": result["position"]}

func _barn(pos: Vector3) -> void:
	var root := _root("RedBarn", pos)
	_box(root, Vector3(0.0, 1.9, 0.0), Vector3(5.2, 3.8, 4.1), Color("93775e") if current_island == 3 else (Color("f2d69e") if current_island == 2 else Color("b95647")))
	_box(root, Vector3(0.0, 0.17, 0.0), Vector3(5.55, 0.35, 4.4), Color("d4c2a2"))
	for x in [-2.55, -1.7, -0.85, 0.0, 0.85, 1.7, 2.55]:
		_box(root, Vector3(x, 2.0, 2.08), Vector3(0.055, 3.7, 0.045), Color("d8775b"))
	for x in [-2.57, 2.57]:
		_box(root, Vector3(x, 1.97, 2.12), Vector3(0.16, 3.9, 0.15), CREAM)
	_box(root, Vector3(0.0, 1.48, 2.13), Vector3(2.36, 2.8, 0.12), CREAM)
	_box(root, Vector3(0.0, 1.43, 2.23), Vector3(2.07, 2.55, 0.11), Color("7c443b"))
	_box(root, Vector3(0.0, 1.45, 2.31), Vector3(0.10, 2.55, 0.06), CREAM)
	_bar(root, Vector3(-0.96, 0.26, 2.31), Vector3(0.96, 2.58, 2.31), 0.09, CREAM)
	_bar(root, Vector3(0.96, 0.26, 2.32), Vector3(-0.96, 2.58, 2.32), 0.09, CREAM)
	_roof(root, 6.0, 5.0, 3.85, 1.4, Color("6b7f89") if current_island == 3 else (Color("db8066") if current_island == 2 else TEAL))
	if current_island == 3:
		_snow_roof(root, 6.0, 5.0, 3.85, 1.4)
	_box(root, Vector3(0.0, 3.49, 2.14), Vector3(0.8, 0.53, 0.14), CREAM)
	_box(root, Vector3(0.0, 3.5, 2.24), Vector3(0.57, 0.34, 0.06), Color("425c67"))
	for x in [-1.8, 1.8]:
		_box(root, Vector3(x, 2.54, 2.18), Vector3(0.57, 0.72, 0.14), CREAM)
		_box(root, Vector3(x, 2.56, 2.27), Vector3(0.39, 0.49, 0.06), Color("ffd087") if current_island == 3 else Color("7dada6"))
	for z in [-1.65, -0.5, 0.65, 1.65]:
		_box(root, Vector3(2.63, 1.95, z), Vector3(0.10, 3.7, 0.08), Color("db8969"))
	_box(root, Vector3(3.3, 0.43, 1.45), Vector3(0.95, 0.85, 1.22), Color("d2b266"))
	_box(root, Vector3(3.3, 0.87, 1.45), Vector3(0.98, 0.07, 1.23), Color("ecd18a"))
	_target(root, Vector3(0.0, 2.5, 0.0), Vector3(5.6, 5.0, 4.6), "station", "barn")
	_label(root, "WINTER BARN" if current_island == 3 else ("BEACH BARN" if current_island == 2 else "THE BARN"), Vector3(0.0, 5.65, 0.0), 34, CREAM)

func _market(pos: Vector3) -> void:
	var root := _root("MarketStall", pos)
	_box(root, Vector3(0.0, 0.15, 0.0), Vector3(5.3, 0.3, 3.6), Color("b49d74"))
	for x in [-2.2, 2.2]:
		for z in [-1.2, 1.2]:
			_box(root, Vector3(x, 1.75, z), Vector3(0.18, 3.3, 0.18), Color("765940"))
	_box(root, Vector3(0.0, 1.0, 0.8), Vector3(4.7, 1.0, 0.9), Color("aa7950"))
	_box(root, Vector3(0.0, 1.56, 0.8), Vector3(4.9, 0.16, 1.15), CREAM)
	for i in range(8):
		var x: float = -2.45 + float(i) * 0.7
		var stripe_color: Color = (Color("638b9d") if current_island == 3 else (Color("46b8a8") if current_island == 2 else Color("e4a257"))) if i % 2 == 0 else (Color("e6f0ee") if current_island == 3 else Color("f7e7ba"))
		var awning := _box(root, Vector3(x, 3.23, 0.0), Vector3(0.71, 0.15, 3.9), stripe_color)
		awning.rotation.x = -0.12
		_box(root, Vector3(x, 2.90, 1.90), Vector3(0.71, 0.43, 0.14), stripe_color)
	for i in range(3):
		var crate_pos := Vector3(-1.55 + float(i) * 1.55, 1.72, 0.8)
		_crate(root, crate_pos, true)
	_crate(root, Vector3(2.9, 0.42, 0.8), true)
	_crate(root, Vector3(3.0, 1.2, 0.8), false)
	var vendor := _potato_person(root, Vector3(0.0, 0.25, -0.35), Color("d5a46b"), Color("818f69"), false)
	_cylinder(vendor, Vector3(0.0, 1.55, 0.0), 0.46, 0.46, 0.12, Color("f0d58d"), 10)
	_label(root, "FROST MARKET" if current_island == 3 else ("SHORES MARKET" if current_island == 2 else "FARMERS' MARKET"), Vector3(0.0, 4.45, 0.0), 34, CREAM)
	_target(root, Vector3(0.0, 1.8, 0.0), Vector3(5.3, 3.6, 4.0), "station", "market")

func _roll_house(pos: Vector3) -> void:
	var root := _root("RollHouse", pos)
	_box(root, Vector3(0.0, 0.16, 0.0), Vector3(5.5, 0.35, 4.5), Color("aaa58e"))
	_box(root, Vector3(0.0, 1.88, 0.0), Vector3(4.7, 3.45, 3.6), Color("b0a394") if current_island == 3 else (Color("82c8ba") if current_island == 2 else Color("ead4a8")))
	_box(root, Vector3(0.0, 0.21, 2.35), Vector3(5.65, 0.35, 1.0), Color("c4c1a6"))
	_box(root, Vector3(0.0, 0.12, 2.89), Vector3(6.0, 0.2, 0.55), Color("d5ceb2"))
	_roof(root, 5.55, 4.45, 3.68, 1.25, Color("5b748b") if current_island == 3 else (Color("ec996d") if current_island == 2 else Color("4b8688")))
	if current_island == 3:
		_snow_roof(root, 5.55, 4.45, 3.68, 1.25)
	_box(root, Vector3(0.0, 1.34, 1.88), Vector3(1.25, 2.4, 0.18), Color("647966"))
	_box(root, Vector3(0.0, 1.38, 1.99), Vector3(0.96, 2.1, 0.06), Color("45685f"))
	_sphere(root, Vector3(0.29, 1.32, 2.05), Vector3(0.065, 0.065, 0.065), GOLD)
	for x in [-1.66, 1.66]:
		_box(root, Vector3(x, 2.27, 1.87), Vector3(0.81, 1.28, 0.14), CREAM)
		_box(root, Vector3(x, 2.27, 1.97), Vector3(0.6, 1.03, 0.07), Color("ffd48c") if current_island == 3 else Color("749e9a"))
		_box(root, Vector3(x, 2.27, 2.03), Vector3(0.07, 1.05, 0.07), CREAM)
		_box(root, Vector3(x, 2.27, 2.03), Vector3(0.6, 0.07, 0.07), CREAM)
	for x in [-2.1, 2.1]:
		_cylinder(root, Vector3(x, 1.96, 2.1), 0.16, 0.14, 3.3, CREAM, 8)
		_box(root, Vector3(x, 0.39, 2.1), Vector3(0.46, 0.3, 0.43), Color("e8d8b8"))
	_box(root, Vector3(0.0, 3.55, 2.12), Vector3(5.1, 0.36, 0.35), CREAM)
	_cylinder(root, Vector3(0.0, 5.3, 0.0), 0.045, 0.045, 1.6, Color("8b704c"), 6)
	_box(root, Vector3(0.58, 5.75, 0.0), Vector3(1.15, 0.57, 0.06), Color("e2b255"))
	_sphere(root, Vector3(0.58, 5.77, 0.065), Vector3(0.17, 0.22, 0.04), Color("7f693d"))
	# The gem display and dice identify the high-stakes Roll House.
	_box(root, Vector3(3.4, 0.52, 1.7), Vector3(0.94, 1.02, 0.78), Color("807093"))
	_box(root, Vector3(3.4, 1.07, 1.7), Vector3(1.02, 0.11, 0.88), Color("a493b0"))
	_box(root, Vector3(3.4, 1.14, 1.7), Vector3(0.5, 0.025, 0.065), Color("423e50"))
	_box(root, Vector3(3.4, 0.62, 2.10), Vector3(0.40, 0.45, 0.035), CREAM)
	_label(root, "ROLL", Vector3(3.4, 0.64, 2.15), 20, Color("655175"), false)
	_rare_gem = _gem(root, Vector3(3.4, 1.65, 1.7), Color("ba8de8"), 0.43)
	_die(root, Vector3(-3.1, 0.64, 2.0), 0.72, 0.3)
	_die(root, Vector3(-2.9, 1.23, 2.0), 0.5, -0.2)
	_roll_label = _label(root, "THE WARM ROLL HOUSE" if current_island == 3 else ("BEACH ROLL HOUSE" if current_island == 2 else "THE ROLL HOUSE"), Vector3(0.0, 6.50, 0.0), 34, CREAM)
	_target(root, Vector3(0.55, 2.6, 0.4), Vector3(6.4, 5.2, 4.7), "station", "roll")
	_roll_gate = Node3D.new()
	root.add_child(_roll_gate)
	for side in [-1.0, 1.0]:
		var board := _box(_roll_gate, Vector3(0.0, 1.38, 2.13), Vector3(1.58, 0.22, 0.12), Color("af9470"))
		board.rotation.z = side * 0.50
	_box(_roll_gate, Vector3(0.0, 1.39, 2.24), Vector3(0.23, 0.28, 0.08), Color("d3b06d"))
	_roll_gate.visible = false
	for i in range(7):
		var x: float = -2.15 + float(i) * 0.72
		var flag := _box(root, Vector3(x, 3.16 - sin(float(i) * PI / 6.0) * 0.34, 2.34), Vector3(0.33, 0.45, 0.04), Color("a88dad") if i % 2 == 0 else GOLD)
		flag.rotation.z = 0.15 * sin(float(i))

func _windmill(pos: Vector3) -> void:
	var root := _root("Windmill", pos)
	_cylinder(root, Vector3(0.0, 1.75, 0.0), 1.03, 0.67, 3.5, Color("eadab5"), 8)
	_cylinder(root, Vector3(0.0, 3.95, 0.0), 1.04, 0.0, 1.25, Color("538388"), 8)
	_box(root, Vector3(0.0, 0.73, 0.98), Vector3(0.58, 1.35, 0.08), Color("846449"))
	_rotor = Node3D.new()
	root.add_child(_rotor)
	_rotor.position = Vector3(0.0, 3.20, 0.83)
	for i in range(4):
		var blade := Node3D.new()
		_rotor.add_child(blade)
		blade.rotation.z = float(i) * PI * 0.5 + 0.4
		_box(blade, Vector3(0.0, 1.47, 0.0), Vector3(0.12, 3.0, 0.10), Color("765c43"))
		_box(blade, Vector3(0.30, 1.8, 0.035), Vector3(0.56, 1.60, 0.10), Color("f3e4bc"))
		for r in range(4):
			_box(blade, Vector3(0.30, 1.17 + float(r) * 0.42, 0.1), Vector3(0.58, 0.055, 0.04), Color("b99b68"))
	_sphere(_rotor, Vector3(0.0, 0.0, 0.14), Vector3(0.27, 0.27, 0.18), GOLD)

func _scenery() -> void:
	for pos in [Vector3(-17.1, 0, -11), Vector3(-17.2, 0, -1), Vector3(-16.9, 0, 10.3), Vector3(-11.3, 0, 11.8), Vector3(17.4, 0, -10.5), Vector3(17.3, 0, -0.5), Vector3(14.7, 0, 9.7), Vector3(9.2, 0, 12.4)]:
		_tree(pos, _rng.randf_range(0.85, 1.2))
	for pos in [Vector3(-13, 0, 12), Vector3(-18, 0, 4), Vector3(17, 0, 5), Vector3(12, 0, 12), Vector3(17, 0, -6), Vector3(-7, 0, -12)]:
		for i in range(3):
			_sphere(self, pos + Vector3(float(i) * 0.53, 0.38, 0.0), Vector3(0.65, 0.59, 0.6), Color("63905c"))
	for i in range(70):
		var x: float = _rng.randf_range(-18.0, 18.0)
		var z: float = _rng.randf_range(9.2, 13.1) if i < 40 else _rng.randf_range(-12.9, 10.0)
		if i >= 40 and absf(x) < 15.0:
			x = 17.0 * (-1.0 if i % 2 == 0 else 1.0) + _rng.randf_range(-0.8, 0.8)
		var pos := Vector3(x, 0.15, z)
		_cylinder(self, pos, 0.025, 0.02, 0.32, Color("567e4b"), 4)
		var flower_color: Color = Color("f8daa2") if i % 3 == 0 else (Color("d8a3a0") if i % 3 == 1 else Color("f7f0cd"))
		_sphere(self, pos + Vector3(0.0, 0.19, 0.0), Vector3(0.13, 0.07, 0.13), flower_color)
	# Leave a proper opening where the ferry path crosses the northern fence.
	_fence(Vector3(-15.7, 0.0, -13.0), Vector3(10.0, 0.0, -13.0), 12)
	_fence(Vector3(13.0, 0.0, -13.0), Vector3(14.6, 0.0, -13.0), 1)
	_fence(Vector3(18.6, 0.0, -11.3), Vector3(18.6, 0.0, 9.0), 10)
	# A pond, bridge and dock form a quiet corner beside the village.
	var pond := _sphere(self, Vector3(12.0, 0.0, 4.5), Vector3(3.45, 0.055, 2.6), Color("729f96"))
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere(self, Vector3(11.9, 0.04, 4.4), Vector3(3.1, 0.025, 2.28), Color("8bb9ab"))
	for i in range(6):
		_box(self, Vector3(9.4 + float(i) * 0.43, 0.24, 5.5), Vector3(0.38, 0.14, 1.2), Color("b59364"))
	for pos in [Vector3(12, 0.1, 3.5), Vector3(13.5, 0.1, 4.7), Vector3(11, 0.1, 4.1)]:
		_cylinder(self, pos, 0.32, 0.32, 0.035, Color("7ba061"), 7)
	_sphere(self, Vector3(12.1, 0.20, 3.5), Vector3(0.12, 0.10, 0.12), Color("e8b2ba"))
	var bench := _root("VillageBench", Vector3(10.9, 0.0, 0.4))
	for z in [-0.2, 0.2]:
		_box(bench, Vector3(0.0, 0.57, z), Vector3(2.4, 0.15, 0.27), Color("a77b55"))
	for x in [-0.9, 0.9]:
		_box(bench, Vector3(x, 0.29, 0.0), Vector3(0.14, 0.59, 0.55), Color("486f62"))
	_box(bench, Vector3(0.0, 1.04, -0.35), Vector3(2.4, 0.44, 0.12), Color("b58a5b"))
	for data in [[Vector3(5.9, 0, -4.5), Color("b88355"), Color("a07885")], [Vector3(9.2, 0, 1.2), Color("d8ab74"), Color("dba464")], [Vector3(-4.8, 0, -5.0), Color("bd8e60"), Color("68928a")]]:
		var villager := _potato_person(self, data[0], data[1], data[2], false)
		villager.rotation.y = _rng.randf_range(-0.5, 0.7)
		_villagers.append(villager)
	for i in range(4):
		var cloud := _root("Cloud", Vector3(-18.0 + float(i) * 13.0, 10.5 + float(i % 2) * 2.0, -19.0 - float(i % 2) * 3.0))
		_clouds.append(cloud)
		for j in range(4):
			var puff := _sphere(cloud, Vector3(float(j) * 1.1 - 1.5, 0.0 if j % 2 == 0 else 0.4, 0.0), Vector3(1.25, 0.65, 0.8), Color("f4f0d8"))
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign(Vector3(-6.0, 0, 9.7), "SPUD VALLEY", Color("41675e"))
	# Farm props: a wheelbarrow, watering can, and a tiny produce cart.
	var barrow := _root("Wheelbarrow", Vector3(-9.8, 0.0, 1.1))
	_box(barrow, Vector3(0.0, 0.64, 0.0), Vector3(0.75, 0.35, 1.1), Color("b98151"))
	var wheel := _cylinder(barrow, Vector3(0.0, 0.26, -0.65), 0.27, 0.27, 0.15, Color("55584b"), 10)
	wheel.rotation.z = PI * 0.5
	for x in [-0.28, 0.28]:
		_bar(barrow, Vector3(x, 0.55, 0.1), Vector3(x, 0.78, 1.0), 0.05, Color("6a5640"))
	_cylinder(self, Vector3(5.3, 0.33, 5.1), 0.29, 0.29, 0.55, Color("7cabb1"), 8)
	_bar(self, Vector3(5.5, 0.4, 5.1), Vector3(5.97, 0.64, 5.1), 0.09, Color("7cabb1"))

func _tree(pos: Vector3, size: float) -> void:
	var root := _root("OrchardTree", pos)
	root.scale = Vector3.ONE * size
	_cylinder(root, Vector3(0.0, 1.1, 0.0), 0.22, 0.13, 2.2, Color("876346"), 7)
	_sphere(root, Vector3(0.0, 2.8, 0.0), Vector3(1.36, 1.7, 1.30), Color("6b965b"))
	_sphere(root, Vector3(-0.72, 2.4, 0.18), Vector3(0.88, 1.03, 0.9), Color("80a768"))
	_sphere(root, Vector3(0.68, 2.5, 0.1), Vector3(0.85, 1.2, 0.87), Color("8eae6b"))
	for i in range(3):
		_sphere(root, Vector3(-0.65 + float(i) * 0.58, 2.45 + float(i % 2) * 0.65, 1.03), Vector3(0.15, 0.16, 0.15), Color("d5a660"))

func _potato_person(parent: Node3D, pos: Vector3, skin: Color, clothes: Color, farmer: bool) -> Node3D:
	var body := Node3D.new()
	parent.add_child(body)
	body.position = pos
	for x in [-0.21, 0.21]:
		_sphere(body, Vector3(x, 0.14, 0.04), Vector3(0.17, 0.14, 0.26), Color("695342"))
	_sphere(body, Vector3(0.0, 0.84, 0.0), Vector3(0.52, 0.74, 0.43), skin)
	_sphere(body, Vector3(0.0, 0.52, 0.03), Vector3(0.48, 0.39, 0.43), clothes)
	_box(body, Vector3(0.0, 0.84, 0.398), Vector3(0.50, 0.34, 0.06), clothes)
	for x in [-0.2, 0.2]:
		_box(body, Vector3(x, 1.0, 0.358), Vector3(0.08, 0.35, 0.09), clothes)
		_sphere(body, Vector3(x, 0.94, 0.416), Vector3(0.04, 0.04, 0.025), GOLD)
	for x in [-0.17, 0.17]:
		_sphere(body, Vector3(x, 1.15, 0.383), Vector3(0.078, 0.086, 0.038), Color("fff3d8"))
		_sphere(body, Vector3(x + 0.008, 1.15, 0.422), Vector3(0.035, 0.047, 0.022), Color("413a31"))
		_sphere(body, Vector3(x * 1.58, 1.00, 0.372), Vector3(0.07, 0.038, 0.015), Color("ce876a"))
	_sphere(body, Vector3(0.0, 1.055, 0.437), Vector3(0.07, 0.05, 0.045), skin.lightened(0.1))
	_box(body, Vector3(0.0, 0.970, 0.427), Vector3(0.12, 0.027, 0.03), Color("855941"))
	for side in [-1.0, 1.0]:
		var arm := _sphere(body, Vector3(side * 0.5, 0.73, 0.04), Vector3(0.15, 0.30, 0.17), skin)
		arm.rotation.z = side * 0.22
	for i in range(4):
		_sphere(body, Vector3(-0.29 + float(i % 2) * 0.58, 1.27 + float(i / 2) * 0.12, 0.31), Vector3(0.026, 0.028, 0.017), skin.darkened(0.18))
	if farmer:
		_cylinder(body, Vector3(0.0, 1.53, 0.0), 0.66, 0.66, 0.13, Color("e4c27b"), 12)
		_cylinder(body, Vector3(0.0, 1.69, -0.035), 0.38, 0.31, 0.32, Color("efd495"), 10)
		_cylinder(body, Vector3(0.0, 1.59, -0.035), 0.387, 0.38, 0.10, Color("9a734d"), 10)
	return body

func _fence(start: Vector3, end: Vector3, segments: int) -> void:
	for i in range(segments + 1):
		var pos: Vector3 = start.lerp(end, float(i) / float(segments))
		_box(self, pos + Vector3(0.0, 0.48, 0.0), Vector3(0.16, 0.96, 0.16), Color("e3d4a8"))
		_cylinder(self, pos + Vector3(0.0, 1.01, 0.0), 0.135, 0.0, 0.16, Color("f1dfb6"), 4)
	for y in [0.35, 0.71]:
		_bar(self, start + Vector3(0, y, 0), end + Vector3(0, y, 0), 0.065, Color("e1d2a7"))

func _crate(parent: Node3D, pos: Vector3, full: bool) -> void:
	_box(parent, pos, Vector3(1.2, 0.5, 0.9), Color("a6794b"))
	for z in [-0.45, 0.45]:
		for y in [-0.18, 0.17]:
			_box(parent, pos + Vector3(0.0, y, z), Vector3(1.25, 0.13, 0.065), Color("cfaa72"))
	for x in [-0.55, 0.55]:
		_box(parent, pos + Vector3(x, 0.0, 0.0), Vector3(0.1, 0.56, 0.92), Color("bd9961"))
	if full:
		for i in range(5):
			_sphere(parent, pos + Vector3(-0.39 + float(i % 3) * 0.38, 0.29, -0.16 + float(i / 3) * 0.35), Vector3(0.24, 0.18, 0.20), Color("d7aa69"))

func _sign(pos: Vector3, title: String, color: Color) -> void:
	var root := _root("VillageSign", pos)
	for x in [-1.08, 1.08]:
		_box(root, Vector3(x, 0.75, 0.0), Vector3(0.16, 1.5, 0.16), Color("816544"))
	_box(root, Vector3(0.0, 1.25, 0.0), Vector3(3.18, 0.8, 0.19), color)
	_label(root, title, Vector3(0.0, 1.25, 0.13), 27, CREAM, false)

func _target(parent: Node3D, pos: Vector3, size: Vector3, key: String, value: Variant) -> void:
	if key == "station":
		var station: String = str(value)
		var station_roots: Array = _tutorial_station_roots.get(station, [])
		if not station_roots.has(parent):
			station_roots.append(parent)
		_tutorial_station_roots[station] = station_roots
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.set_meta(key, value)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

func _root(title: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = title
	root.position = pos
	add_child(root)
	return root

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color.srgb_to_linear()
	material.roughness = 0.88
	_materials[key] = material
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if not _box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_box_meshes[size] = mesh
	instance.mesh = _box_meshes[size]
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 1.0
		_sphere_mesh.height = 2.0
		_sphere_mesh.radial_segments = 9
		_sphere_mesh.rings = 5
	instance.mesh = _sphere_mesh
	instance.scale = size
	instance.position = pos
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance

func _leaf(parent: Node3D, pos: Vector3, size: Vector3, color: Color, angle: float) -> void:
	var leaf := _sphere(parent, pos, size, color)
	leaf.rotation.z = angle

func _cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, sides: int = 8) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := Vector4(bottom, top, height, float(sides))
	if not _cylinder_meshes.has(shape):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = bottom
		mesh.top_radius = top
		mesh.height = height
		mesh.radial_segments = sides
		_cylinder_meshes[shape] = mesh
	instance.mesh = _cylinder_meshes[shape]
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

func _bar(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var rod := _cylinder(parent, (start + end) * 0.5, radius, radius, start.distance_to(end), color, 5)
	var direction: Vector3 = (end - start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		rod.quaternion = Quaternion(Vector3.UP, direction)
	return rod

func _label(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color, billboard: bool = true) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.pixel_size = 0.017
	label.modulate = color
	label.outline_modulate = Color("42574a")
	label.outline_size = 6 if billboard else 0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = billboard
	parent.add_child(label)
	return label

func _roof(parent: Node3D, width: float, depth: float, base: float, rise: float, color: Color) -> void:
	var verts: Array[Vector3] = [Vector3(-width / 2, base, -depth / 2), Vector3(width / 2, base, -depth / 2), Vector3(0, base + rise, -depth / 2), Vector3(-width / 2, base, depth / 2), Vector3(width / 2, base, depth / 2), Vector3(0, base + rise, depth / 2)]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[1, 2, 0], [5, 4, 3], [5, 3, 0], [2, 5, 0], [5, 2, 1], [4, 5, 1]]:
		for index in triangle:
			mesh.add_vertex(verts[index])
	mesh.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh.commit()
	var material := _mat(color).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	parent.add_child(instance)
	_bar(parent, verts[3], verts[5], 0.065, CREAM)
	_bar(parent, verts[5], verts[4], 0.065, CREAM)
	_bar(parent, verts[2], verts[5], 0.075, color.lightened(0.15))

func _prism(parent: Node3D, pos: Vector3, width: float, depth: float, height: float, color: Color) -> void:
	var x: float = width * 0.5
	var z: float = depth * 0.5
	var cut: float = 2.3
	var points: Array[Vector3] = [Vector3(-x + cut, 0, -z), Vector3(x - cut, 0, -z), Vector3(x, 0, -z + cut), Vector3(x, 0, z - cut), Vector3(x - cut, 0, z), Vector3(-x + cut, 0, z), Vector3(-x, 0, z - cut), Vector3(-x, 0, -z + cut)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		for vertex in [a + Vector3.UP * height / 2, b + Vector3.UP * height / 2, Vector3(0, height / 2, 0), b + Vector3.UP * height / 2, a + Vector3.UP * height / 2, a - Vector3.UP * height / 2, b - Vector3.UP * height / 2, b + Vector3.UP * height / 2, a - Vector3.UP * height / 2]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)

func highlight_tiles(indices: Array[int]) -> void:
	if not is_instance_valid(_area_selection):
		return
	var key: String = str(indices)
	if key == _area_key:
		return
	_area_key = key
	for child in _area_selection.get_children():
		_area_selection.remove_child(child)
		child.queue_free()
	for index in indices:
		if index < 0 or index >= plot_positions.size():
			continue
		var pos: Vector3 = plot_positions[index]
		for side in [-1.02, 1.02]:
			_box(_area_selection, pos + Vector3(side, 0.25, 0.0), Vector3(0.075, 0.04, 2.1), Color("8ce5d2"))
			_box(_area_selection, pos + Vector3(0.0, 0.25, side), Vector3(2.1, 0.04, 0.075), Color("8ce5d2"))

func play_farm_effect(indices: Array, action: String, multiplier: int = 1, grade: int = 0) -> void:
	if not is_instance_valid(_tool):
		return
	_tool_action = action
	_tool_duration = 0.5 / (1.0 + float(grade) * 0.35)
	_tool_time = _tool_duration
	_tool.scale = Vector3.ONE * (1.0 + float(grade) * 0.2)
	_tool.visible = true
	for child in _tool.get_children():
		_tool.remove_child(child)
		child.queue_free()
	if action == "water":
		_cylinder(_tool, Vector3.ZERO, 0.22, 0.22, 0.37, Color("73bac8"), 8)
		_bar(_tool, Vector3(0.1, 0.0, 0.0), Vector3(0.38, 0.15, 0.0), 0.06, Color("73bac8"))
	elif action == "pest":
		_cylinder(_tool, Vector3(0.0, 0.07, 0.0), 0.22, 0.26, 0.55, Color("66d5b6"), 12)
		_box(_tool, Vector3(0.0, 0.37, 0.0), Vector3(0.32, 0.13, 0.24), Color("263c44"))
		_bar(_tool, Vector3(0.05, 0.41, 0.0), Vector3(0.42, 0.41, 0.0), 0.075, Color("ffd15c"))
		_bar(_tool, Vector3(0.16, 0.34, 0.0), Vector3(0.11, 0.20, 0.0), 0.035, Color("263c44"))
		_box(_tool, Vector3(0.0, 0.05, 0.23), Vector3(0.17, 0.21, 0.025), Color("fff6d5"))
	elif action == "hoe" or action == "harvest" or action in ["ice", "break_ice", "frostbreak"]:
		_bar(_tool, Vector3(0.0, -0.4, 0.0), Vector3(0.0, 0.7, 0.0), 0.045, Color("b79461"))
		_box(_tool, Vector3(0.0, 0.70, 0.14), Vector3(0.46 if action == "harvest" else 0.29, 0.06, 0.26), Color("a8b9b3"))
	else:
		_sphere(_tool, Vector3.ZERO, Vector3(0.17, 0.12, 0.15), Color("e4bd7c"))
	var valid_indices: Array[int] = []
	for raw_index in indices:
		var index: int = int(raw_index)
		if index < 0 or index >= plot_positions.size():
			continue
		valid_indices.append(index)
		var pos: Vector3 = plot_positions[index]
		# Keep the action readable without filling a large field with hundreds of particles.
		var budget: int = 64 if action == "harvest" and multiplier >= 8 else 40
		var per_patch: int = 6 if action == "harvest" and multiplier >= 8 else 4
		var particle_count: int = maxi(1, mini(per_patch, int(budget / maxi(1, indices.size()))))
		for i in range(particle_count):
			var color: Color = Color("72f4ce") if action == "pest" else (GOLD if action == "harvest" else (Color("bfe9fb") if action in ["ice", "break_ice", "frostbreak"] or (current_island == 3 and action == "hoe") else (Color("8ddbe8") if action == "water" else Color("bc9669"))))
			var initial: Vector3 = pos + Vector3(_rng.randf_range(-0.65, 0.65), 1.3 if action in ["water", "pest"] else 0.35, _rng.randf_range(-0.65, 0.65))
			var particle := _sphere(self, initial, Vector3(0.18, 0.07, 0.18) if action == "pest" else Vector3(0.08, 0.18 if action == "water" else 0.08, 0.08), color)
			var velocity := Vector3(_rng.randf_range(-1.0, 1.0), -1.3 if action == "water" else (-0.3 if action == "pest" else _rng.randf_range(1.3, 3.0)), _rng.randf_range(-1.0, 1.0))
			_effect_particles.append({"node": particle, "velocity": velocity, "life": 0.8, "total": 0.8})
	if action == "harvest" and multiplier >= 8 and valid_indices.size() >= 6:
		var center: Vector3 = Vector3.ZERO
		for index in valid_indices:
			center += plot_positions[index]
		center /= float(valid_indices.size())
		_show_impact("x%d COMBO" % multiplier, center + Vector3(0.0, 1.7, 0.0), Color("ffe9a3"), 31, 0.85)


func play_reward(rarity: String) -> void:
	if not is_instance_valid(player):
		return
	var tier: String = rarity.to_lower()
	if tier not in ["rare", "epic", "legendary", "mythic", "mutation", "jackpot", "relic", "mystery", "build"]:
		return
	var major: bool = tier in ["legendary", "mythic", "mutation", "jackpot", "relic", "mystery", "build"]
	var island_color: Color = Color("62ffa0") if current_island == 1 else (Color("ffdb62") if current_island == 2 else Color("8ee7ff"))
	var color: Color = island_color if major else (Color("c4a3ff") if tier == "epic" else GOLD)
	var count: int = 42 if tier in ["jackpot", "mystery"] else (34 if tier == "relic" else (28 if major else 12))
	var lifetime: float = 3.6 if major else 1.6
	for i in range(count):
		var angle: float = float(i) * TAU / float(count)
		var pos: Vector3 = player.position + Vector3(cos(angle) * 0.45, 1.1, sin(angle) * 0.45)
		var particle: Node3D = _gem(self, pos, color if i % 3 else Color("fff2ba"), 0.17 if major else 0.095)
		var velocity := Vector3(cos(angle) * (1.45 if major else 0.9), _rng.randf_range(1.4, 2.3), sin(angle) * (1.45 if major else 0.9))
		_effect_particles.append({"node": particle, "velocity": velocity, "life": lifetime, "total": lifetime, "gravity": 0.75 if major else 2.0})
	if major:
		_reward_halo(island_color, lifetime)
		_show_impact(tier.to_upper() + "!", player.position + Vector3(0.0, 2.5, 0.0), color, 39 if tier == "jackpot" else 34, 3.0)


func _reward_halo(color: Color, lifetime: float) -> void:
	var halo := Node3D.new()
	halo.name = "RewardHalo"
	halo.position = player.position + Vector3(0.0, 0.3, 0.0)
	add_child(halo)
	for segment in range(24):
		var angle: float = float(segment) * TAU / 24.0
		var next_angle: float = float(segment + 1) * TAU / 24.0
		var start := Vector3(cos(angle) * 1.52, 0.0, sin(angle) * 1.52)
		var end := Vector3(cos(next_angle) * 1.52, 0.0, sin(next_angle) * 1.52)
		var ray: MeshInstance3D = _bar(halo, start, end, 0.047, color)
		ray.material_override = _bright_material(color)
		if segment % 3 == 0:
			var spark: MeshInstance3D = _bar(halo, start * 1.10, start * 1.35, 0.055, color)
			spark.material_override = _bright_material(color)
	_effect_particles.append({"node": halo, "velocity": Vector3(0.0, 0.13, 0.0), "life": lifetime, "total": lifetime, "float": true, "halo": true})


func _bright_material(color: Color) -> StandardMaterial3D:
	var material_key: String = "bright:" + color.to_html()
	if not _materials.has(material_key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[material_key] = material
	return _materials[material_key]


func _show_impact(text: String, pos: Vector3, color: Color, font_size: int, lifetime: float) -> void:
	# A new highlight replaces the last one; reward reels and routine feedback live in the HUD.
	if is_instance_valid(_impact_root):
		for i in range(_effect_particles.size() - 1, -1, -1):
			if _effect_particles[i]["node"] == _impact_root:
				_effect_particles.remove_at(i)
		remove_child(_impact_root)
		_impact_root.queue_free()
	_impact_root = Node3D.new()
	_impact_root.name = "SingleImpactCaption"
	add_child(_impact_root)
	_impact_root.position = pos
	_label(_impact_root, text, Vector3.ZERO, font_size, color)
	_effect_particles.append({"node": _impact_root, "velocity": Vector3(0.0, 0.55, 0.0), "life": lifetime, "total": lifetime, "float": true})

func _animate_effects(delta: float) -> void:
	if _tool_time > 0.0:
		_tool_time = maxf(0.0, _tool_time - delta)
		var progress: float = 1.0 - _tool_time / _tool_duration
		_tool.rotation.z = sin(progress * PI) * (-0.85 if _tool_action == "water" else 1.15)
		_player_body.rotation.x = sin(progress * PI) * -0.14
		_tool.visible = _tool_time > 0.0
		if _tool_time == 0.0:
			_player_body.rotation.x = 0.0
	for i in range(_effect_particles.size() - 1, -1, -1):
		var data: Dictionary = _effect_particles[i]
		var node: Node3D = data["node"]
		data["life"] = float(data["life"]) - delta
		if not is_instance_valid(node) or float(data["life"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_effect_particles.remove_at(i)
			continue
		var velocity: Vector3 = data["velocity"]
		node.position += velocity * delta
		if bool(data.get("halo", false)):
			node.rotation.y += delta * 0.7
			var fade: float = minf(1.0, float(data["life"]) / 0.4)
			node.scale = Vector3.ONE * (1.0 + sin(_time * 4.5) * 0.09) * fade
		if not bool(data.get("float", false)):
			velocity.y -= delta * float(data.get("gravity", 4.0))
			node.rotation.y += delta * 2.2
			if not data.has("scale"):
				data["scale"] = node.scale
			node.scale = Vector3(data["scale"]) * minf(1.0, float(data["life"]) / 0.22)
		data["velocity"] = velocity

func _gem(parent: Node3D, pos: Vector3, color: Color, size: float) -> Node3D:
	var gem := Node3D.new()
	parent.add_child(gem)
	gem.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color.srgb_to_linear()
	material.emission_energy_multiplier = 0.35
	for side in [-1.0, 1.0]:
		var half := _cylinder(gem, Vector3(0.0, side * size * 0.45, 0.0), size, 0.0, size * 0.9, color, 4)
		if side < 0.0:
			half.rotation.z = PI
		half.material_override = material
	return gem

func _die(parent: Node3D, pos: Vector3, size: float, angle: float) -> void:
	var die := Node3D.new()
	parent.add_child(die)
	die.position = pos
	die.rotation.y = angle
	_box(die, Vector3.ZERO, Vector3.ONE * size, CREAM)
	for i in range(3):
		var offset: float = (-0.26 + float(i) * 0.26) * size
		_sphere(die, Vector3(offset, offset, size * 0.505), Vector3(0.065, 0.065, 0.018) * size, Color("73607d"))
	for x in [-0.23, 0.23]:
		for z in [-0.23, 0.23]:
			_sphere(die, Vector3(x * size, size * 0.505, z * size), Vector3(0.065, 0.018, 0.065) * size, Color("73607d"))
	_sphere(die, Vector3(size * 0.505, 0.0, 0.0), Vector3(0.018, 0.085, 0.085) * size, Color("73607d"))

func _golden_shores() -> void:
	var root := _root("GoldenShoresLocked", Vector3(7.0, -1.1, -25.0))
	var water := _cylinder(root, Vector3(0.0, -0.98, 0.0), 6.2, 6.2, 0.045, Color("aacfc6"), 24)
	water.scale.z = 0.75
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prism(root, Vector3(0.0, -0.6, 0.0), 9.0, 6.8, 0.8, Color("b7975e"))
	_prism(root, Vector3(0.0, -0.12, 0.0), 9.2, 7.0, 0.25, Color("eed89a"))
	for tree_pos in [Vector3(-2.7, 0.0, -1.6), Vector3(2.5, 0.0, -1.7)]:
		_cylinder(root, tree_pos + Vector3(0.0, 1.32, 0.0), 0.17, 0.11, 2.65, Color("a18454"), 7)
		for leaf_index in range(6):
			var angle: float = float(leaf_index) * TAU / 6.0
			var leaf := _sphere(root, tree_pos + Vector3(cos(angle) * 0.58, 2.56, sin(angle) * 0.58), Vector3(1.08, 0.17, 0.38), Color("c8b659") if leaf_index % 2 == 0 else Color("e3ca65"))
			leaf.rotation.y = -angle
			leaf.rotation.z = 0.23
		_sphere(root, tree_pos + Vector3(0.0, 2.40, 0.16), Vector3(0.24, 0.23, 0.22), Color("b99154"))
	for pos in [Vector3(-1.9, 0.0, 1.1), Vector3(-0.25, 0.0, 1.1), Vector3(1.4, 0.0, 1.1)]:
		_box(root, pos + Vector3(0.0, 0.08, 0.0), Vector3(1.25, 0.16, 1.15), Color("b6975f"))
		for j in range(3):
			_sphere(root, pos + Vector3(-0.36 + float(j) * 0.36, 0.26, 0.0), Vector3(0.22, 0.19, 0.21), Color("f7c752"))
	_sphere(root, Vector3(3.0, 0.41, 0.55), Vector3(0.9, 0.52, 0.8), Color("d4b578"))
	_gem(root, Vector3(0.0, 1.1, -0.6), GOLD, 0.42)
	_travel_label = _label(root, "GOLDEN SHORES  ·  LOCKED", Vector3(0.0, 4.8, 0.0), 32, Color("ffe5a4"))
	_target(root, Vector3(0.0, 1.25, 0.0), Vector3(9.0, 3.8, 7.0), "station", "island")
	# The boarding area stays reachable even before the next island unlocks.
	var dock := _root("GoldenShoresDock", Vector3(11.5, 0.0, -14.0))
	for i in range(10):
		_box(dock, Vector3(0.0, 0.13, -float(i) * 0.44), Vector3(1.9, 0.15, 0.39), Color("b79867"))
	for x in [-0.87, 0.87]:
		for z in [0.0, -3.9]:
			_cylinder(dock, Vector3(x, 0.38, z), 0.10, 0.10, 1.25, Color("8d704f"), 6)
	_dock_gate = Node3D.new()
	dock.add_child(_dock_gate)
	_dock_gate.position.z = -3.7
	_box(_dock_gate, Vector3(0.0, 0.78, 0.0), Vector3(1.95, 0.30, 0.13), Color("746447"))
	_box(_dock_gate, Vector3(0.0, 0.93, 0.12), Vector3(0.30, 0.34, 0.13), GOLD)
	_dock_label = _label(dock, "ISLAND 2  /  LOCKED", Vector3(0.0, 1.85, -0.4), 22, Color("ffe6aa"))
	_target(dock, Vector3(0.0, 0.75, -1.4), Vector3(2.6, 2.4, 4.4), "station", "island")


func _tropical_island() -> void:
	var ocean := _cylinder(self, Vector3(0.0, -1.35, 0.0), 33.0, 33.0, 0.12, Color("67bdb5"), 40)
	ocean.scale.z = 0.79
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prism(self, Vector3(0.0, -0.68, 0.0), 49.2, 39.0, 0.12, Color("a1ded0"))
	_prism(self, Vector3(0.0, -1.35, 0.0), 45.7, 35.5, 1.6, Color("b99563"))
	_prism(self, Vector3(0.0, -0.58, 0.0), 46.0, 36.0, 0.55, Color("d6b97d"))
	_prism(self, Vector3(0.0, -0.17, 0.0), 46.3, 36.3, 0.30, Color("efdaa0"))
	var ground := StaticBody3D.new()
	ground.name = "GoldenShoresGround"
	ground.set_meta("ground", true)
	add_child(ground)
	var shape := BoxShape3D.new()
	shape.size = Vector3(46.0, 0.15, 36.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.08
	ground.add_child(collision)
	for i in range(18):
		var x: float = -20.0 + float(i) * 2.35
		_box(self, Vector3(x, -0.54, 18.7 + sin(float(i) * 1.6) * 0.18), Vector3(1.2, 0.035, 0.14), Color("d8f0d8"))
	for i in range(13):
		_box(self, Vector3(-23.8, -0.54, -15.0 + float(i) * 2.5), Vector3(0.14, 0.035, 1.45), Color("dbefdb"))


func _tropical_paths() -> void:
	_box(self, Vector3(0.0, 0.027, -6.6), Vector3(35.0, 0.07, 2.0), Color("e2c78e"))
	_box(self, Vector3(10.2, 0.029, 2.0), Vector3(2.0, 0.07, 18.0), Color("e2c78e"))
	_box(self, Vector3(1.0, 0.032, 10.6), Vector3(30.5, 0.07, 2.1), Color("e2c78e"))
	for i in range(29):
		_box(self, Vector3(-15.5 + float(i) * 1.1, 0.075, -6.6 + _rng.randf_range(-0.35, 0.35)), Vector3(0.60, 0.035, 0.65), Color("f4e5b8"))
	for i in range(15):
		var paver := _box(self, Vector3(10.2, 0.078, -5.5 + float(i) * 1.02), Vector3(0.76, 0.036, 0.42), Color("f4e5b8"))
		paver.rotation.y = _rng.randf_range(-0.1, 0.1)


func _tropical_scenery() -> void:
	for point in [Vector3(-21.0, 0.0, -12.5), Vector3(-20.0, 0.0, -3.0), Vector3(-20.3, 0.0, 9.5), Vector3(-16.2, 0.0, 14.7), Vector3(20.1, 0.0, -12.5), Vector3(20.4, 0.0, -1.3), Vector3(20.0, 0.0, 14.6), Vector3(10.9, 0.0, 15.7)]:
		_palm(self, point, _rng.randf_range(0.9, 1.25))
	for i in range(24):
		var point := Vector3(_rng.randf_range(-20.0, 20.0), 0.1, _rng.randf_range(13.0, 16.6))
		if absf(point.x) < 6.0:
			point.z = 16.0
		_sphere(self, point, Vector3(0.14, 0.07, 0.11), Color("fff1ce") if i % 2 == 0 else Color("dfad87"))
	for point in [Vector3(-19.0, 0.0, 5.0), Vector3(-17.8, 0.0, -15.0), Vector3(17.1, 0.0, -15.0), Vector3(17.8, 0.0, 13.9)]:
		for index in range(4):
			var angle: float = float(index) * 1.9
			var leaf := _sphere(self, point + Vector3(cos(angle) * 0.35, 0.40, sin(angle) * 0.3), Vector3(0.70, 0.12, 0.28), Color("78a76e"))
			leaf.rotation = Vector3(0.0, -angle, 0.6)
		_sphere(self, point + Vector3(0.0, 0.53, 0.0), Vector3(0.17, 0.15, 0.17), Color("f0a269"))
	for data in [[Vector3(-12.0, 0.0, -6.4), Color("d3a268"), Color("4baca3")], [Vector3(8.8, 0.0, -6.6), Color("c29161"), Color("e99a7c")], [Vector3(13.5, 0.0, 4.0), Color("dca76e"), Color("88b194")], [Vector3(-14.0, 0.0, 9.0), Color("bd8f61"), Color("63a9b9")]]:
		var villager := _potato_person(self, data[0], data[1], data[2], false)
		villager.rotation.y = _rng.randf_range(-0.8, 0.7)
		_tropical_hat(villager)
		_villagers.append(villager)
	# A beach umbrella and chairs sit clear of the harvest rows.
	var umbrella := _root("BeachUmbrella", Vector3(-16.2, 0.0, 3.2))
	_cylinder(umbrella, Vector3(0.0, 1.55, 0.0), 0.045, 0.045, 3.1, Color("a98959"), 6)
	_cylinder(umbrella, Vector3(0.0, 2.83, 0.0), 1.9, 0.0, 0.62, Color("f0a177"), 10)
	for x in [-0.7, 0.7]:
		_box(umbrella, Vector3(x, 0.38, 0.65), Vector3(0.62, 0.12, 1.7), Color("f5e6b9"))
		var back := _box(umbrella, Vector3(x, 0.76, -0.25), Vector3(0.62, 0.95, 0.12), Color("60b0a4"))
		back.rotation.x = -0.2
	for point in [Vector3(-11.5, 0.32, -10.3), Vector3(-11.5, 0.87, -10.3), Vector3(3.0, 0.3, -10.0), Vector3(4.3, 0.3, -10.1)]:
		_crate(self, point, true)
	for point in [Vector3(24.2, -0.15, 14.0), Vector3(25.3, -0.15, -5.0), Vector3(-24.8, -0.15, 8.0)]:
		var buoy := _root("SeaBuoy", point)
		_sphere(buoy, Vector3.ZERO, Vector3(0.28, 0.34, 0.28), Color("ef906c"))
		_cylinder(buoy, Vector3(0.0, 0.38, 0.0), 0.06, 0.045, 0.55, CREAM, 6)
	for i in range(3):
		var cloud := _root("SeaCloud", Vector3(-21.0 + float(i) * 19.0, 11.0, -23.0))
		_clouds.append(cloud)
		for j in range(4):
			var puff := _sphere(cloud, Vector3(float(j) * 1.1, 0.2 if j % 2 == 0 else 0.0, 0.0), Vector3(1.3, 0.6, 0.75), Color("fbefd4"))
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign(Vector3(-5.0, 0.0, 13.2), "GOLDEN SHORES", Color("497f70"))


func _palm(parent: Node3D, pos: Vector3, size: float) -> void:
	var palm := Node3D.new()
	palm.name = "GoldenPalm"
	palm.position = pos
	palm.scale = Vector3.ONE * size
	parent.add_child(palm)
	for section in range(5):
		var fraction: float = float(section) / 5.0
		var trunk := _cylinder(palm, Vector3(fraction * 0.38, 0.38 + float(section) * 0.64, 0.0), 0.20 - fraction * 0.055, 0.18 - fraction * 0.05, 0.76, Color("aa8755") if section % 2 == 0 else Color("bc9962"), 7)
		trunk.rotation.z = -0.11
	for leaf_index in range(8):
		var angle: float = float(leaf_index) * TAU / 8.0
		var frond := _sphere(palm, Vector3(0.38 + cos(angle) * 0.86, 3.52, sin(angle) * 0.86), Vector3(1.75, 0.18, 0.46), Color("7aab66") if leaf_index % 2 == 0 else Color("a8ba65"))
		frond.rotation = Vector3(0.0, -angle, 0.17)
		var tip := _sphere(palm, Vector3(0.38 + cos(angle) * 1.95, 3.28, sin(angle) * 1.95), Vector3(0.80, 0.13, 0.28), Color("9ebb70"))
		tip.rotation = Vector3(0.0, -angle, 0.4)
	for offset in [Vector3(-0.12, 3.24, 0.1), Vector3(0.36, 3.19, 0.2), Vector3(0.13, 3.30, -0.25)]:
		_sphere(palm, offset + Vector3(0.25, 0.0, 0.0), Vector3(0.22, 0.25, 0.23), Color("a17b4b"))


func _tropical_hat(body: Node3D) -> void:
	_cylinder(body, Vector3(0.0, 1.53, 0.0), 0.67, 0.67, 0.10, Color("ead091"), 12)
	_cylinder(body, Vector3(0.0, 1.70, 0.0), 0.36, 0.31, 0.32, Color("f0dca3"), 10)
	_cylinder(body, Vector3(0.0, 1.61, 0.0), 0.37, 0.36, 0.08, Color("57a99b"), 10)
	for petal in range(5):
		var angle: float = float(petal) * TAU / 5.0
		_sphere(body, Vector3(0.30 + cos(angle) * 0.08, 1.62 + sin(angle) * 0.08, 0.29), Vector3(0.075, 0.07, 0.025), Color("f0a085"))
	_sphere(body, Vector3(0.30, 1.62, 0.32), Vector3(0.04, 0.04, 0.02), GOLD)


func _sunburst_bloom(parent: Node3D, pos: Vector3) -> void:
	_sphere(parent, pos + Vector3(0.0, 0.02, 0.0), Vector3(0.14, 0.09, 0.14), Color("dd802a"))
	for petal in range(8):
		var angle: float = float(petal) * TAU / 8.0
		var ray := _sphere(parent, pos + Vector3(cos(angle) * 0.19, 0.0, sin(angle) * 0.19), Vector3(0.16, 0.045, 0.065), Color("ffdb61") if petal % 2 == 0 else Color("ffbd3f"))
		ray.rotation.y = -angle


func _quest_board(pos: Vector3) -> void:
	var board := _root("FarmingQuestBoard", pos)
	for x in [-0.86, 0.86]:
		_box(board, Vector3(x, 1.05, 0.0), Vector3(0.18, 2.1, 0.18), Color("987449"))
	_box(board, Vector3(0.0, 1.52, 0.0), Vector3(2.45, 1.45, 0.19), Color("8a6945"))
	_box(board, Vector3(0.0, 1.53, 0.13), Vector3(2.17, 1.18, 0.05), Color("b9925f"))
	for x in [-0.64, 0.0, 0.64]:
		var paper := _box(board, Vector3(x, 1.55, 0.19), Vector3(0.49, 0.76, 0.03), CREAM)
		paper.rotation.z = x * 0.12
		_sphere(board, Vector3(x, 1.82, 0.23), Vector3(0.045, 0.045, 0.02), Color("cd795b"))
		_box(board, Vector3(x, 1.52, 0.23), Vector3(0.28, 0.055, 0.02), Color("90a280"))
	_roof(board, 2.90, 0.83, 2.30, 0.39, Color("52968b") if current_island == 2 else TEAL)
	_label(board, "FARMING CHALLENGES", Vector3(0.0, 3.18, 0.0), 24, CREAM)
	_target(board, Vector3(0.0, 1.35, 0.05), Vector3(2.9, 2.9, 1.05), "station", "quests")


func _return_valley() -> void:
	var valley := _root("SpudValleyReturn", Vector3(5.0, -1.3, -29.5))
	_prism(valley, Vector3(0.0, -0.55, 0.0), 9.4, 7.2, 0.8, Color("98734e"))
	_prism(valley, Vector3(0.0, -0.08, 0.0), 9.6, 7.4, 0.22, GRASS)
	_box(valley, Vector3(-1.9, 0.75, -0.65), Vector3(2.3, 1.5, 1.7), Color("b95647"))
	var barn_roof := Node3D.new()
	valley.add_child(barn_roof)
	barn_roof.position = Vector3(-1.9, 0.0, -0.65)
	_roof(barn_roof, 2.7, 2.1, 1.48, 0.65, TEAL)
	_box(valley, Vector3(-1.9, 0.48, 0.22), Vector3(0.75, 0.95, 0.06), CREAM)
	for row in range(2):
		for column in range(3):
			var pos := Vector3(0.1 + float(column) * 1.03, 0.08, 0.35 + float(row) * 1.01)
			_box(valley, pos, Vector3(0.83, 0.16, 0.80), SOIL)
			_sphere(valley, pos + Vector3(0.0, 0.22, 0.0), Vector3(0.29, 0.21, 0.29), Color("80a05c"))
	for x in [-3.3, 3.0]:
		_cylinder(valley, Vector3(x, 0.67, -2.0), 0.12, 0.08, 1.34, Color("876346"), 6)
		_sphere(valley, Vector3(x, 1.78, -2.0), Vector3(0.84, 1.15, 0.8), Color("729b61"))
	_travel_label = _label(valley, "SPUD VALLEY · RETURN", Vector3(0.0, 3.8, 0.0), 29, Color("f6e6b4"))
	_target(valley, Vector3(0.0, 1.0, 0.0), Vector3(9.5, 3.2, 7.2), "station", "island")


func _export_dock() -> void:
	var dock := _root("GoldenShoresHarbor", Vector3(16.0, 0.0, 7.0))
	for i in range(14):
		_box(dock, Vector3(0.0, 0.18, -1.8 + float(i) * 0.46), Vector3(3.3, 0.18, 0.41), Color("bd9c67") if i % 2 == 0 else Color("cba974"))
	# A narrow pier continues from the land-side boarding area over the water.
	for i in range(20):
		_box(dock, Vector3(0.60 + float(i) * 0.42, 0.17, 1.65), Vector3(0.37, 0.16, 1.8), Color("bc9b68") if i % 2 == 0 else Color("caaa74"))
	for x in [3.0, 6.0, 8.35]:
		for z in [0.85, 2.43]:
			_cylinder(dock, Vector3(x, -0.05, z), 0.10, 0.10, 1.6, Color("8e704b"), 6)
	for x in [-1.48, 1.48]:
		for z in [-1.7, 1.4, 4.0]:
			_cylinder(dock, Vector3(x, 0.36, z), 0.14, 0.13, 1.30, Color("8e704b"), 7)
			_cylinder(dock, Vector3(x, 0.87, z), 0.18, 0.18, 0.12, CREAM, 8)
	_crate(dock, Vector3(-0.67, 0.60, -0.70), true)
	_crate(dock, Vector3(-0.64, 1.14, -0.70), true)
	_cylinder(dock, Vector3(0.62, 0.49, -0.60), 0.31, 0.31, 0.32, Color("92816a"), 10)
	_dock_label = _label(dock, "SPUD VALLEY · RETURN", Vector3(0.0, 2.8, 0.8), 26, Color("fff0bd"))
	_target(dock, Vector3(0.0, 0.85, 1.0), Vector3(3.6, 2.5, 6.4), "station", "island")
	for z in [-1.6, 3.8]:
		var flag_root := Node3D.new()
		dock.add_child(flag_root)
		flag_root.position = Vector3(1.50, 0.0, z)
		_cylinder(flag_root, Vector3(0.0, 1.75, 0.0), 0.045, 0.045, 3.2, Color("a37d49"), 6)
		_box(flag_root, Vector3(0.43, 2.7, 0.0), Vector3(0.86, 0.53, 0.055), GOLD)
		_sphere(flag_root, Vector3(0.44, 2.71, 0.05), Vector3(0.13, 0.16, 0.035), Color("fff2bc"))
		_export_flags.append(flag_root)
	_export_boat = _root("GoldenExportBoat", _boat_away)
	_sphere(_export_boat, Vector3(0.0, 0.05, 0.0), Vector3(1.10, 0.52, 2.17), Color("79614a"))
	_box(_export_boat, Vector3(0.0, 0.34, 0.0), Vector3(1.85, 0.16, 3.20), Color("d6b47e"))
	for x in [-0.89, 0.89]:
		_box(_export_boat, Vector3(x, 0.55, 0.0), Vector3(0.10, 0.35, 3.05), Color("eee0b4"))
	_box(_export_boat, Vector3(0.0, 0.91, -0.93), Vector3(1.35, 1.04, 0.97), Color("74b9ad"))
	_box(_export_boat, Vector3(0.0, 1.46, -0.93), Vector3(1.57, 0.15, 1.18), Color("e69573"))
	_box(_export_boat, Vector3(0.0, 1.10, -0.40), Vector3(0.78, 0.35, 0.055), Color("dcf1dc"))
	_crate(_export_boat, Vector3(0.0, 0.65, 0.56), true)
	_cylinder(_export_boat, Vector3(0.0, 1.31, 0.10), 0.045, 0.045, 2.0, Color("ab8859"), 6)
	_box(_export_boat, Vector3(0.39, 2.15, 0.1), Vector3(0.80, 0.43, 0.05), GOLD)
	_export_label = _label(_export_boat, "EXPORT BUYER", Vector3(0.0, 3.1, 0.0), 27, Color("fff1b1"))


func set_island2_unlocked(value: bool) -> void:
	_island2_unlocked = value
	if current_island == 1:
		if is_instance_valid(_travel_label):
			_travel_label.text = "GOLDEN SHORES · TRAVEL" if value else "GOLDEN SHORES · LOCKED"
		if is_instance_valid(_dock_label):
			_dock_label.text = "ISLAND 2 / TRAVEL" if value else "ISLAND 2 / LOCKED"
		if is_instance_valid(_dock_gate):
			_dock_gate.visible = not value
	elif current_island == 2:
		if is_instance_valid(_travel_label):
			_travel_label.text = "SPUD VALLEY · RETURN"
		if is_instance_valid(_dock_label):
			_dock_label.text = "SPUD VALLEY · RETURN"


func set_export_state(active: bool, seconds: float) -> void:
	var was_active: bool = _export_active
	_export_seconds = maxf(0.0, seconds)
	_export_active = active and _export_seconds > 0.0
	for flag in _export_flags:
		if is_instance_valid(flag):
			flag.visible = _export_active
	if is_instance_valid(_export_label):
		_export_label.visible = _export_active
		_export_label.text = "EXPORT OPEN · %.1fs" % _export_seconds
	if was_active and not _export_active:
		for i in range(_effect_particles.size() - 1, -1, -1):
			if not bool(_effect_particles[i].get("export", false)):
				continue
			var particle: Node3D = _effect_particles[i]["node"]
			if is_instance_valid(particle):
				remove_child(particle)
				particle.queue_free()
			_effect_particles.remove_at(i)


func _animate_export(delta: float) -> void:
	if current_island != 2 or not is_instance_valid(_export_boat):
		return
	var target: Vector3 = _boat_dock if _export_active else _boat_away
	_export_boat.position = _export_boat.position.lerp(target, minf(1.0, delta * (12.0 if _export_active else 1.65)))
	_export_boat.position.y = target.y + sin(_time * 1.7) * 0.075
	_export_boat.rotation.z = sin(_time * 1.8) * 0.025
	_export_boat.rotation.y = lerp_angle(_export_boat.rotation.y, 0.12 if _export_active else 0.75, minf(1.0, delta * 1.5))
	for i in range(_export_flags.size()):
		_export_flags[i].rotation.z = sin(_time * 3.2 + float(i)) * 0.025
	if not _export_active:
		return
	_export_particle_clock += delta
	if _export_particle_clock >= 0.40:
		_export_particle_clock = 0.0
		for i in range(3):
			var particle: Node3D = _gem(self, _boat_dock + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(1.5, 2.8), _rng.randf_range(-1.7, 1.7)), GOLD, 0.075)
			_effect_particles.append({"node": particle, "velocity": Vector3(0.0, 0.9, 0.0), "life": 0.7, "total": 0.7, "export": true})


func set_golden_hat(value: bool) -> void:
	_golden_hat = value
	if is_instance_valid(_player_body):
		_player_body.set_golden_hat(value)
		_gear_hat = _player_body.hat


func _winter_island() -> void:
	var sea := _cylinder(self, Vector3(0.0, -1.42, 0.0), 39.0, 39.0, 0.13, Color("8db7cc"), 40)
	sea.scale.z = 0.79
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prism(self, Vector3(0.0, -0.62, 0.0), 58.1, 46.0, 0.16, Color("c1dce7"))
	_prism(self, Vector3(0.0, -1.35, 0.0), 55.4, 43.4, 1.7, Color("7d8c97"))
	_prism(self, Vector3(0.0, -0.59, 0.0), 55.8, 43.8, 0.57, Color("b4c4ca"))
	_prism(self, Vector3(0.0, -0.15, 0.0), 56.2, 44.2, 0.34, Color("e6eef0"))
	var ground := StaticBody3D.new()
	ground.name = "FrosthollowGround"
	ground.set_meta("ground", true)
	add_child(ground)
	var shape := BoxShape3D.new()
	shape.size = Vector3(56.0, 0.15, 44.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.07
	ground.add_child(collision)
	for i in range(24):
		var x: float = -25.0 + float(i) * 2.15
		var icicle := _cylinder(self, Vector3(x, -0.65, 21.98), 0.02, 0.14, _rng.randf_range(0.45, 0.85), Color("d4e8f0"), 5)
		icicle.rotation.z = 0.05


func _winter_paths() -> void:
	_box(self, Vector3(0.0, 0.035, -8.2), Vector3(40.0, 0.09, 2.0), Color("c4cbc9"))
	_box(self, Vector3(12.8, 0.038, 3.0), Vector3(2.0, 0.09, 22.0), Color("c4cbc9"))
	_box(self, Vector3(1.5, 0.040, 14.0), Vector3(38.0, 0.09, 2.2), Color("c4cbc9"))
	for i in range(34):
		var paver := _box(self, Vector3(-19.0 + float(i) * 1.12, 0.094, -8.2 + _rng.randf_range(-0.30, 0.30)), Vector3(0.67, 0.04, 0.59), Color("a9b5b9"))
		paver.rotation.y = _rng.randf_range(-0.12, 0.12)
	for i in range(17):
		_box(self, Vector3(12.8, 0.097, -6.8 + float(i) * 1.16), Vector3(0.80, 0.035, 0.46), Color("e2e8e8"))
	for i in range(20):
		_box(self, Vector3(-13.0 + float(i) * 1.4, 0.105, 14.0 + (0.14 if i % 2 == 0 else -0.14)), Vector3(0.17, 0.026, 0.29), Color("b6c9d2"))


func _snow_roof(parent: Node3D, width: float, depth: float, base: float, rise: float) -> void:
	var half_width: float = width * 0.5
	var angle: float = atan2(rise, half_width)
	var roof_length: float = sqrt(half_width * half_width + rise * rise)
	for side in [-1.0, 1.0]:
		var snow := _box(parent, Vector3(side * width * 0.25, base + rise * 0.5 + 0.11, 0.0), Vector3(roof_length + 0.10, 0.15, depth + 0.16), Color("edf4f5"))
		snow.rotation.z = -side * angle
	for i in range(7):
		_cylinder(parent, Vector3(-width * 0.46 + float(i) * width * 0.153, base + 0.03, depth * 0.515), 0.01, 0.055, 0.25 + float(i % 3) * 0.08, Color("cce2eb"), 5)


func _winter_scenery() -> void:
	for point in [Vector3(-25,0,-17), Vector3(-25,0,-7), Vector3(-24,0,4), Vector3(-25,0,15), Vector3(-19,0,19), Vector3(25,0,-17), Vector3(25,0,-7), Vector3(25,0,1), Vector3(25,0,17), Vector3(17,0,19)]:
		_snow_pine(point, _rng.randf_range(0.9, 1.2))
	for point in [Vector3(-23.5,0,9), Vector3(-23,0,-19), Vector3(4,0,-19), Vector3(24,0,-2), Vector3(12,0,19), Vector3(-10,0,19)]:
		for i in range(3):
			var size: float = _rng.randf_range(0.62, 1.1)
			var pos: Vector3 = point + Vector3(float(i) * 0.68, 0.34, float(i % 2) * 0.35)
			_sphere(self, pos, Vector3(0.82, 0.65, 0.64) * size, Color("8999a4"))
			_sphere(self, pos + Vector3(0.0, 0.34 * size, -0.02), Vector3(0.79, 0.31, 0.61) * size, Color("e9f0f1"))
	# The frozen pond is decorative; the nearby forge is the manual Frostbreak station.
	_sphere(self, Vector3(19.1, 0.00, -4.6), Vector3(4.0, 0.055, 2.35), Color("accedf"))
	_sphere(self, Vector3(19.0, 0.045, -4.55), Vector3(3.68, 0.03, 2.06), Color("c6e1ed"))
	for endpoints in [[Vector3(16.3,0.084,-4.2),Vector3(20.2,0.084,-4.8)],[Vector3(18.4,0.086,-6.2),Vector3(19.7,0.086,-3.2)],[Vector3(19.6,0.087,-3.7),Vector3(21.5,0.087,-4.0)]]:
		_bar(self, endpoints[0], endpoints[1], 0.025, Color("94bbcf"))
	for i in range(7):
		_box(self, Vector3(15.3 + float(i) * 0.40, 0.19, -3.3), Vector3(0.34, 0.16, 1.3), Color("9f8e7a"))
	for data in [[Vector3(-14,0,-8.2),Color("c89b6c"),Color("926d78")],[Vector3(9,0,-8.3),Color("d9b47b"),Color("73929e")],[Vector3(15,0,11.8),Color("c5976d"),Color("9e8868")],[Vector3(-17,0,11.5),Color("d2a574"),Color("728a91")]]:
		var resident := _potato_person(self, data[0], data[1], data[2], false)
		_winter_hat(resident, data[2])
		resident.rotation.y = _rng.randf_range(-0.6, 0.65)
		_villagers.append(resident)
	for point in [Vector3(-13.8,0.33,-12.2),Vector3(-13.8,0.89,-12.2),Vector3(1.1,0.3,-12.8),Vector3(2.4,0.3,-12.8)]:
		_crate(self, point, true)
		_box(self, point + Vector3(0.0,0.55,0.0), Vector3(1.15,0.09,0.84), Color("eef3f3"))
	for point in [Vector3(-13.8,0,-7.9),Vector3(12.6,0,12.4),Vector3(-16.2,0,14.4)]:
		_winter_lantern(point)
	_sign(Vector3(-4.0,0.0,16.0), "FROSTHOLLOW", Color("627d8d"))
	for i in range(28):
		var snowflake := _sphere(self, Vector3(_rng.randf_range(-25,25), _rng.randf_range(1.5,8.0), _rng.randf_range(-17,18)), Vector3.ONE * 0.035, Color("f1f7f8"))
		snowflake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_snowflakes.append(snowflake)


func _snow_pine(pos: Vector3, size: float) -> void:
	var tree := _root("SnowPine", pos)
	tree.scale = Vector3.ONE * size
	_cylinder(tree, Vector3(0.0,1.5,0.0), 0.24,0.16,3.0,Color("897968"),7)
	for tier in range(3):
		var height: float = 1.55 + float(tier) * 1.18
		var width: float = 1.68 - float(tier) * 0.37
		_cylinder(tree,Vector3(0.0,height,0.0),width,0.05,2.10,Color("597d79"),8)
		_cylinder(tree,Vector3(0.0,height+0.20,0.0),width*0.87,0.0,1.88,Color("e5eff1"),8)
	_sphere(tree,Vector3(0.0,0.10,0.0),Vector3(0.95,0.17,0.85),Color("edf3f3"))


func _winter_hat(body: Node3D, color: Color) -> void:
	_sphere(body,Vector3(0.0,1.52,-0.02),Vector3(0.49,0.30,0.43),color)
	_cylinder(body,Vector3(0.0,1.48,-0.02),0.51,0.50,0.16,color.lightened(0.12),12)
	_sphere(body,Vector3(0.0,1.84,-0.02),Vector3(0.13,0.13,0.13),Color("f1ebdb"))
	_box(body,Vector3(0.0,0.98,0.41),Vector3(0.69,0.14,0.09),Color("dfb082"))
	_box(body,Vector3(0.25,0.78,0.46),Vector3(0.13,0.43,0.055),Color("dfb082"))


func _winter_lantern(pos: Vector3) -> void:
	var post := _root("WinterLantern",pos)
	_cylinder(post,Vector3(0.0,1.13,0.0),0.09,0.07,2.26,Color("7d8077"),6)
	_box(post,Vector3(0.0,2.36,0.0),Vector3(0.39,0.55,0.39),Color("ffe0a1"))
	_cylinder(post,Vector3(0.0,2.72,0.0),0.35,0.0,0.28,Color("e6eef0"),4)
	for x in [-0.20,0.20]:
		for z in [-0.20,0.20]:
			_box(post,Vector3(x,2.36,z),Vector3(0.035,0.61,0.035),Color("74858b"))


func _icecap_bloom(parent: Node3D, pos: Vector3) -> void:
	_sphere(parent,pos,Vector3(0.12,0.075,0.12),Color("78bada"))
	for petal in range(6):
		var angle: float = float(petal)*TAU/6.0
		var flake := _sphere(parent,pos+Vector3(cos(angle)*0.19,0.02,sin(angle)*0.19),Vector3(0.19,0.045,0.065),Color("eaf8ff"))
		flake.rotation.y = -angle
		_sphere(parent,pos+Vector3(cos(angle)*0.31,0.02,sin(angle)*0.31),Vector3(0.045,0.045,0.045),Color("b9e6fa"))


func _winter_ferry() -> void:
	var ferry := _root("FrosthollowFerry",Vector3(22.0,0.0,10.0))
	for i in range(19):
		_box(ferry,Vector3(float(i)*0.42-1.0,0.21,0.0),Vector3(0.37,0.20,2.7),Color("ac9980"))
	for x in [-0.9,2.0,4.9,6.65]:
		for z in [-1.22,1.22]:
			_cylinder(ferry,Vector3(x,0.35,z),0.14,0.13,1.8,Color("8b7f70"),7)
			_sphere(ferry,Vector3(x,1.30,z),Vector3(0.22,0.10,0.22),Color("edf4f5"))
	_crate(ferry,Vector3(1.1,0.66,-0.75),true)
	_dock_label = _label(ferry,"FERRY · VALLEY / SHORES",Vector3(0.0,2.35,0.0),25,Color("f6edcd"))
	_target(ferry,Vector3(0.1,0.95,0.0),Vector3(3.7,2.5,3.2),"station","island")
	# Only the two already-playable destinations appear offshore.
	for destination in [1,2]:
		var miniature := _root("ValleyReturn" if destination == 1 else "ShoresReturn",Vector3(-2.5 if destination == 1 else 11.0,-1.1,-33.0))
		_prism(miniature,Vector3(0.0,-0.55,0.0),8.2,6.0,0.75,Color("937859"))
		_prism(miniature,Vector3(0.0,-0.08,0.0),8.4,6.2,0.22,GRASS if destination == 1 else Color("eed89a"))
		_box(miniature,Vector3(-1.2,0.67,-0.4),Vector3(2.2,1.35,1.7),Color("b95647") if destination == 1 else Color("f2d69e"))
		var rooftop := Node3D.new()
		miniature.add_child(rooftop)
		rooftop.position = Vector3(-1.2,0.0,-0.4)
		_roof(rooftop,2.55,2.1,1.3,0.65,TEAL if destination == 1 else Color("db8066"))
		if destination == 2:
			_palm(miniature,Vector3(2.6,0.0,-1.0),0.57)
		else:
			_cylinder(miniature,Vector3(2.6,0.65,-1.0),0.14,0.08,1.3,Color("8a6a49"),6)
			_sphere(miniature,Vector3(2.6,1.7,-1.0),Vector3(0.86,1.15,0.82),Color("729b61"))
		for i in range(3):
			_box(miniature,Vector3(-0.8+float(i)*1.15,0.08,1.47),Vector3(0.90,0.15,0.78),SOIL)
			_sphere(miniature,Vector3(-0.8+float(i)*1.15,0.33,1.47),Vector3(0.23,0.18,0.25),Color("96b86b") if destination == 1 else GOLD)
		_label(miniature,"SPUD VALLEY · RETURN" if destination == 1 else "GOLDEN SHORES · RETURN",Vector3(0.0,3.1,0.0),25,Color("f6e6b5"))
		_target(miniature,Vector3(0.0,1.0,0.0),Vector3(8.3,3.3,6.1),"station","island")


func _toolsmith(parent: Node3D, pos: Vector3) -> void:
	var smith := FarmerAvatar.new()
	parent.add_child(smith)
	smith.setup()
	smith.name = "PotatoToolsmith"
	smith.position = pos
	smith.rotation.y = 0.30
	smith.set_equipment({"head": "prospectors_hat", "body": "industrialist_overalls", "feet": "industrialist_boots", "hands": "harvest_gloves"}, {})
	_toolsmiths.append(smith)
	# The NPC has its own compact hit box: clicking their face or boots opens
	# upgrades, as does clicking the bench. It never extends over crop beds.
	_target(parent, pos + Vector3(0, 1.05, 0), Vector3(1.55, 2.1, 1.35), "station", "tools")


func _tool_upgrade_station(pos: Vector3) -> void:
	var shop := _root("ToolUpgradeWorkshop", pos)
	var trim := Color("4b8579") if current_island == 1 else Color("4ea69c")
	_box(shop, Vector3(0, 0.10, 0), Vector3(4.8, 0.20, 3.1), Color("c5ae7a"))
	# A shallow canopy leaves the toolsmith and workbench visible from the
	# normal farm camera, with a tool rack identifying this as a workshop.
	for x: float in [-2.10, 2.10]:
		_box(shop, Vector3(x, 1.5, -0.95), Vector3(0.17, 3.0, 0.17), Color("806044"))
	_roof(shop, 4.8, 1.85, 2.85, 0.65, trim)
	_box(shop, Vector3(-0.65, 1.82, -0.87), Vector3(2.45, 1.27, 0.16), Color("93704e"))
	for x: float in [-1.25, -0.45]:
		_bar(shop, Vector3(x, 1.25, -0.69), Vector3(x + 0.15, 2.20, -0.69), 0.05, Color("e0bd7e"))
	_box(shop, Vector3(-1.10, 2.20, -0.69), Vector3(0.53, 0.20, 0.14), Color("afc8c3"))
	_box(shop, Vector3(-0.30, 2.17, -0.69), Vector3(0.47, 0.09, 0.17), Color("afc8c3"))
	for offset: float in [-0.18, 0, 0.18]:
		_box(shop, Vector3(-0.30 + offset, 2.29, -0.69), Vector3(0.055, 0.28, 0.12), Color("afc8c3"))
	for x: float in [-1.65, -0.15]:
		for z: float in [0.05, 1.10]:
			_box(shop, Vector3(x, 0.56, z), Vector3(0.15, 0.94, 0.15), Color("89613e"))
	_box(shop, Vector3(-0.9, 1.05, 0.57), Vector3(2.15, 0.21, 1.45), Color("d2ae70"))
	_box(shop, Vector3(-0.9, 0.43, 0.57), Vector3(1.95, 0.10, 1.2), Color("ac804f"))
	_box(shop, Vector3(-1.05, 1.29, 0.62), Vector3(0.53, 0.30, 0.45), Color("60757b"))
	_box(shop, Vector3(-1.05, 1.49, 0.62), Vector3(0.95, 0.15, 0.53), Color("98b5b8"))
	_bar(shop, Vector3(-0.41, 1.20, 0.93), Vector3(-0.07, 1.20, 0.55), 0.045, Color("9e774e"))
	_box(shop, Vector3(-0.04, 1.22, 0.50), Vector3(0.35, 0.14, 0.20), Color("bed0cd"))
	_toolsmith(shop, Vector3(1.15, 0.11, 0.69))
	_label(shop, "TOOL UPGRADES", Vector3(0, 3.95, 0), 28, CREAM)
	_target(shop, Vector3(0, 1.5, 0), Vector3(4.8, 3.2, 3.15), "station", "tools")


func _ice_forge(pos: Vector3) -> void:
	var forge := _root("IceForge",pos)
	_box(forge,Vector3(0.0,0.18,0.0),Vector3(4.1,0.37,3.6),Color("9ba7aa"))
	_box(forge,Vector3(0.0,1.40,-0.15),Vector3(3.35,2.45,2.7),Color("8f8b82"))
	_roof(forge,4.0,3.4,2.70,0.85,Color("66818d"))
	_snow_roof(forge,4.0,3.4,2.70,0.85)
	_box(forge,Vector3(-0.6,1.1,1.23),Vector3(1.4,1.67,0.17),Color("59616a"))
	_box(forge,Vector3(-0.6,0.95,1.34),Vector3(1.05,1.25,0.07),Color("efaf72"))
	_box(forge,Vector3(-0.6,0.64,1.39),Vector3(0.9,0.38,0.045),Color("ffd993"))
	_box(forge,Vector3(1.25,3.22,-0.35),Vector3(0.57,1.83,0.63),Color("8c9296"))
	_box(forge,Vector3(1.25,4.16,-0.35),Vector3(0.73,0.17,0.77),Color("d9e7eb"))
	_box(forge,Vector3(1.13,0.54,1.85),Vector3(0.6,0.8,0.66),Color("776f64"))
	_box(forge,Vector3(1.13,1.03,1.85),Vector3(1.15,0.23,0.76),Color("829ba9"))
	var horn := _cylinder(forge,Vector3(1.85,1.04,1.85),0.19,0.035,0.74,Color("a2b7c3"),6)
	horn.rotation.z = -PI*0.5
	_bar(forge,Vector3(0.78,1.15,1.89),Vector3(1.13,1.59,1.89),0.045,Color("c1a274"))
	_box(forge,Vector3(1.16,1.61,1.89),Vector3(0.45,0.21,0.20),Color("b7cdd8"))
	_frost_beacon = _gem(forge,Vector3(-1.30,3.12,1.5),Color("a8dff5"),0.29)
	_frost_beacon.visible = false
	_toolsmith(forge, Vector3(-1.1, 0.0, 2.1))
	_frost_label = _label(forge,"TOOL UPGRADES",Vector3(0.0,4.75,0.0),28,Color("eaf5fa"))
	_target(forge,Vector3(0.0,1.95,0.4),Vector3(4.6,4.0,4.5),"station","tools")


func set_island3_unlocked(value: bool) -> void:
	_island3_unlocked = value
	if is_instance_valid(_dock_label) and current_island != 3 and value:
		_dock_label.text = "FERRY · THREE ISLANDS"


func set_frost_state(active: bool, seconds: float, frozen_indices: Array = []) -> void:
	_frost_active = active and seconds > 0.0
	_frost_seconds = maxf(0.0,seconds)
	if current_island != 3:
		return
	if is_instance_valid(_frost_label):
		_frost_label.text = "TOOL UPGRADES · FROSTBREAK %.1fs" % _frost_seconds if _frost_active else "TOOL UPGRADES"
	if is_instance_valid(_frost_beacon):
		_frost_beacon.visible = _frost_active
	if not _frost_active:
		for ice in _ice_roots:
			ice.visible = false
	elif not frozen_indices.is_empty():
		for i in range(_ice_roots.size()):
			_ice_roots[i].visible = frozen_indices.has(i)


func _animate_winter(delta: float) -> void:
	if current_island != 3:
		return
	for i in range(_snowflakes.size()):
		var snowflake: Node3D = _snowflakes[i]
		snowflake.position.y -= delta*(0.26+float(i%3)*0.08)
		snowflake.position.x += delta*sin(_time*0.6+float(i))*0.045
		if snowflake.position.y < 0.35:
			snowflake.position.y = 8.0
	if is_instance_valid(_frost_beacon):
		_frost_beacon.rotation.y += delta*0.7


func _processing_station(pos: Vector3) -> void:
	var workshop := _root("WashAndSortWorkshop", pos)
	_box(workshop, Vector3(0.0,0.13,0.0), Vector3(4.7,0.26,3.5), Color("b8b39b") if current_island != 3 else Color("b8c3c8"))
	for x in [-2.15,2.15]:
		_box(workshop, Vector3(x,1.23,-1.15), Vector3(0.13,2.2,0.13), Color("987b54"))
	_roof(workshop,4.7,1.1,2.46,0.55,Color("669791"))
	if current_island == 3:
		_snow_roof(workshop,4.7,1.1,2.46,0.55)
	# The washer and belt process player-loaded crops; the garden remains manual.
	_box(workshop,Vector3(-1.3,1.02,0.0),Vector3(1.37,1.61,1.44),Color("79a6a5"))
	var drum := _cylinder(workshop,Vector3(-1.3,1.07,0.79),0.54,0.54,0.17,Color("c2d2cd"),12)
	drum.rotation.x = PI*0.5
	var glass := _cylinder(workshop,Vector3(-1.3,1.07,0.90),0.40,0.40,0.09,Color("7dabb8"),12)
	glass.rotation.x = PI*0.5
	_processing_light = _sphere(workshop,Vector3(-1.72,1.64,0.76),Vector3(0.06,0.06,0.03),Color("80958b"))
	for x in [-1.35,-1.02]:
		_box(workshop,Vector3(x,1.64,0.75),Vector3(0.16,0.06,0.035),CREAM)
	_cylinder(workshop,Vector3(-1.30,1.96,-0.13),0.28,0.53,0.43,Color("b5beb3"),8)
	_bar(workshop,Vector3(-1.97,0.61,-0.58),Vector3(-1.97,2.09,-0.58),0.075,Color("99adad"))
	_bar(workshop,Vector3(-1.97,2.09,-0.58),Vector3(-1.54,2.09,-0.58),0.075,Color("99adad"))
	for z in [-0.68,0.68]:
		_box(workshop,Vector3(0.70,0.73,z),Vector3(2.65,0.22,0.12),Color("6f8c88"))
		for x in [-0.28,1.70]:
			_box(workshop,Vector3(x,0.42,z),Vector3(0.13,0.80,0.13),Color("8b9d96"))
	for index in range(7):
		var roller := Node3D.new()
		workshop.add_child(roller)
		roller.position = Vector3(-0.40+float(index)*0.34,0.85,0.0)
		var cylinder := _cylinder(roller,Vector3.ZERO,0.12,0.12,1.30,Color("bccac0") if index%2==0 else Color("98afaa"),8)
		cylinder.rotation.x = PI*0.5
		_box(roller,Vector3(0.0,0.12,0.0),Vector3(0.04,0.035,1.18),Color("d8e0d3"))
		_processing_rotors.append(roller)
	for i in range(3):
		var potato := _sphere(workshop,Vector3(0.0,1.05,-0.27+float(i)*0.27),Vector3(0.20,0.16,0.16),Color("d1a56d"))
		potato.visible = false
		_processing_potatoes.append(potato)
	for i in range(4):
		var steam := _sphere(workshop,Vector3(-1.94,2.1,-0.58),Vector3.ONE*0.12,Color("e5eee5"))
		steam.visible = false
		steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_processing_steam.append(steam)
	_crate(workshop,Vector3(1.67,0.39,1.11),false)
	_processing_label = _label(workshop,"WASH & SORT",Vector3(0.0,3.44,0.0),25,Color("f1edce"))
	_target(workshop,Vector3(0.0,1.42,0.15),Vector3(4.8,3.0,3.6),"station","builds")


func set_processing(active: bool, progress: float) -> void:
	_processing_active = active
	_processing_progress = clampf(progress,0.0,1.0)
	if is_instance_valid(_processing_label):
		_processing_label.text = "WASH & SORT · %d%%" % int(_processing_progress*100.0) if active else "WASH & SORT"
	if is_instance_valid(_processing_light):
		_processing_light.material_override = _mat(Color("bade87") if active else Color("80958b"))
	for potato in _processing_potatoes:
		potato.visible = active
	for steam in _processing_steam:
		steam.visible = active


func _animate_processing(delta: float) -> void:
	if not _processing_active:
		return
	for roller in _processing_rotors:
		roller.rotation.z -= delta*3.0
	for i in range(_processing_potatoes.size()):
		var potato: Node3D = _processing_potatoes[i]
		potato.position.x = -0.39 + fmod(_time*0.58+float(i)*0.73,2.12)
		potato.rotation.z -= delta*1.45
	for i in range(_processing_steam.size()):
		var steam: Node3D = _processing_steam[i]
		var travel: float = fmod(_time*0.65+float(i)*0.25,1.0)
		steam.position = Vector3(-1.95+sin(travel*3.0+float(i))*0.10,2.06+travel*0.88,-0.58)
		steam.scale = Vector3.ONE*(0.07+travel*0.09)


func set_roll_available(value: bool) -> void:
	_roll_available = value
	if is_instance_valid(_roll_label):
		_roll_label.text = ("THE WARM ROLL HOUSE" if current_island == 3 else ("BEACH ROLL HOUSE" if current_island == 2 else "THE ROLL HOUSE")) if value else "ROLL HOUSE · CLOSED"
	if is_instance_valid(_roll_gate):
		_roll_gate.visible = not value
	if is_instance_valid(_rare_gem):
		_rare_gem.visible = value


func _build_pest_swarm(parent: Node3D) -> void:
	for i in range(3):
		var bug := Node3D.new()
		bug.name = "PotatoBeetle_%d" % i
		bug.scale = Vector3.ONE * 1.40
		parent.add_child(bug)
		_sphere(bug, Vector3.ZERO, Vector3(0.14, 0.085, 0.19), Color("eaa94f"))
		_sphere(bug, Vector3(0.0, 0.035, 0.15), Vector3(0.095, 0.075, 0.095), Color("485446"))
		_box(bug, Vector3(0.0, 0.085, 0.0), Vector3(0.035, 0.026, 0.25), Color("566042"))
		for side in [-1.0, 1.0]:
			var wing := _sphere(bug, Vector3(side*0.16, 0.07, -0.03), Vector3(0.15, 0.025, 0.095), Color("d8dfb6"))
			wing.rotation.z = side*0.28
			_bar(bug, Vector3(side*0.052,0.08,0.19),Vector3(side*0.11,0.15,0.27),0.009,Color("536044"))
		_geometry_batcher.batch_siblings(bug)


func _update_pest_visual(index: int, data: Dictionary, infested: bool, damage: float) -> void:
	var visual: Dictionary = _pest_visuals[index]
	var ticks: int = clampi(int(data.get("pest_ticks", roundi(damage * 3.0))), 0, 3)
	var destroyed: bool = bool(data.get("pest_destroyed", false))
	var was_infested: bool = bool(visual["active"])
	var swarm: Node3D = _pest_roots[index]
	swarm.visible = infested
	var border: Node3D = _pest_borders[index]
	border.visible = infested
	if infested:
		var warning_color: Color = Color("ffcc4c") if ticks == 0 else (Color("ff9743") if ticks == 1 else Color("ff6043"))
		if border.get_child_count() == 0:
			for side in [-0.96, 0.96]:
				_box(border, Vector3(side, 0.37, 0.0), Vector3(0.07, 0.055, 1.98), warning_color)
				_box(border, Vector3(0.0, 0.37, side), Vector3(1.98, 0.055, 0.07), warning_color)
		for edge in border.get_children():
			edge.material_override = _bright_material(warning_color)
	if infested and swarm.get_child_count() == 0:
		_build_pest_swarm(swarm)
	if infested and not was_infested:
		visual["shake_time"] = 0.85
		pest_warning.emit(index, false)
	if ticks > int(visual["ticks"]) and (infested or destroyed):
		visual["shake_time"] = 0.72
		_pest_bite_burst(index, destroyed)
	if destroyed and not bool(visual["destroyed"]):
		visual["caption_time"] = 1.4 if was_infested else 0.0
		if was_infested:
			pest_warning.emit(index, true)
	if not destroyed:
		visual["caption_time"] = 0.0
	visual["active"] = infested
	visual["ticks"] = ticks
	visual["destroyed"] = destroyed
	var warning: Label3D = _pest_labels[index]
	if infested:
		warning.text = "! PESTS\nYIELD %d/3" % maxi(0, 3 - ticks)
		warning.modulate = Color("ffdf70") if ticks == 0 else (Color("ffb34e") if ticks == 1 else Color("ff6c50"))
	elif destroyed:
		warning.text = "CROP LOST" if float(visual["caption_time"]) > 0.0 else ""
		warning.modulate = Color("ffc19a")
	elif ticks > 0 and int(data.get("stage", 0)) > 0:
		warning.text = "YIELD %d/3" % maxi(0, 3 - ticks)
		warning.modulate = Color("eadba9")
	else:
		warning.text = ""
	warning.visible = not warning.text.is_empty()
	if not infested:
		warning.scale = Vector3.ONE
		_crop_roots[index].position = Vector3.ZERO
		_crop_roots[index].rotation = Vector3.ZERO


func _pest_bite_burst(index: int, destroyed: bool) -> void:
	# The cap keeps simultaneous attacks on a full winter field inexpensive.
	var count: int = mini(10 if destroyed else 6, maxi(0, 144 - _effect_particles.size()))
	for particle_index in range(count):
		var pos: Vector3 = plot_positions[index] + Vector3(_rng.randf_range(-0.55, 0.55), _rng.randf_range(0.6, 1.1), _rng.randf_range(-0.55, 0.55))
		var chip: MeshInstance3D = _box(self, pos, Vector3(0.12, 0.055, 0.08), Color("dec46e") if destroyed else Color("b3d375"))
		chip.rotation = Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), 0.0)
		var velocity := Vector3(_rng.randf_range(-1.3, 1.3), _rng.randf_range(1.2, 2.0), _rng.randf_range(-1.3, 1.3))
		_effect_particles.append({"node": chip, "velocity": velocity, "life": 1.1, "total": 1.1})


func _update_pest_caption_density() -> void:
	var affected: Array[int] = []
	for index in range(_pest_visuals.size()):
		if bool(_pest_visuals[index]["active"]):
			affected.append(index)
	if affected.size() > 8 and is_instance_valid(player):
		affected.sort_custom(func(a: int, b: int) -> bool: return plot_positions[a].distance_squared_to(player.position) < plot_positions[b].distance_squared_to(player.position))
	for order in range(affected.size()):
		var index: int = affected[order]
		var expanded: bool = affected.size() <= 8 or order < 5 or index == _pest_focus
		var warning: Label3D = _pest_labels[index]
		var remaining: int = maxi(0, 3 - int(_pest_visuals[index]["ticks"]))
		# Whole fields can become ripe together. Keep distant labels compact;
		# every affected bed still has its bright outline and exact yield fraction.
		warning.text = "! PESTS\nYIELD %d/3" % remaining if expanded else "! %d/3" % remaining
		warning.font_size = 32 if expanded else 25
		warning.pixel_size = 0.020 if expanded else 0.016


func _animate_pests(delta: float) -> void:
	for i in range(_pest_roots.size()):
		var swarm: Node3D = _pest_roots[i]
		var visual: Dictionary = _pest_visuals[i]
		var warning: Label3D = _pest_labels[i]
		if bool(visual["destroyed"]) and float(visual["caption_time"]) > 0.0:
			visual["caption_time"] = maxf(0.0, float(visual["caption_time"]) - delta)
			if float(visual["caption_time"]) == 0.0:
				warning.text = ""
				warning.hide()
		# Healthy beds and expired captions need no scene-property writes.
		if not swarm.visible:
			continue
		_pest_borders[i].position.y = (sin(_time * 5.0 + float(i) * 0.4) + 1.0) * 0.025
		visual["shake_time"] = maxf(0.0, float(visual["shake_time"]) - delta)
		var bite: float = float(visual["shake_time"]) / 0.85
		var strength: float = 0.025 + bite * 0.09
		_crop_roots[i].rotation.z = sin(_time * 24.0 + float(i) * 0.81) * strength
		_crop_roots[i].position.x = sin(_time * 27.0 + float(i)) * strength * 0.45
		warning.scale = Vector3.ONE * (1.0 + sin(_time * 5.0 + float(i) * 0.4) * 0.035)
		for j in range(swarm.get_child_count()):
			var bug: Node3D = swarm.get_child(j)
			var angle: float = _time*1.9+float(j)*TAU/3.0+float(i)*0.43
			bug.position = Vector3(cos(angle)*0.68, 1.35+sin(_time*4.3+float(j))*0.13, sin(angle)*0.64)
			bug.rotation.y = -angle
			bug.rotation.z = sin(_time*12.0+float(j))*0.12

func _duck_station() -> void:
	_duck_home = Vector3(10.8, 0, 4.6) if current_island == 1 else (Vector3(-15.2, 0, 5.3) if current_island == 2 else Vector3(-18.5, 0, 9.0))
	var coop: Node3D = _root("DuckPatrolHouse", _duck_home)
	_cylinder(coop, Vector3(0, 0.05, 1.0), 1.9, 1.9, 0.10, Color("73b8be") if current_island < 3 else Color("92c5d5"), 20)
	_box(coop, Vector3(0, 0.66, -0.5), Vector3(1.9, 1.3, 1.55), Color("d9bf83"))
	_roof(coop, 2.35, 1.95, 1.30, 0.6, Color("648972") if current_island < 3 else Color("a6c9d7"))
	_box(coop, Vector3(0, 0.44, 0.3), Vector3(0.6, 0.82, 0.04), Color("534f39"))
	for x: float in [-0.75, 0.75]:
		_box(coop, Vector3(x, 0.40, 0.30), Vector3(0.15, 0.8, 0.07), Color("f0d897"))
	_duck_label = _label(coop, "DUCK PATROL", Vector3(0, 2.5, 0), 26, CREAM)
	_target(coop, Vector3(0, 0.8, 0.1), Vector3(3.3, 2.5, 3.5), "station", "duck_patrol")
	for index in range(current_island):
		var duck: Node3D = _root("PestPatrolDuck%d" % (index + 1), _duck_home + Vector3((index - (current_island - 1) * 0.5) * 1.0, 0.12, 1.6))
		var body := Node3D.new()
		duck.add_child(body)
		_sphere(body, Vector3(0, 0.42, 0), Vector3(0.42, 0.33, 0.55), Color("fff0c7"))
		_sphere(body, Vector3(0, 0.83, 0.30), Vector3(0.26, 0.28, 0.28), Color("fff3d7"))
		_sphere(body, Vector3(0, 0.77, 0.59), Vector3(0.22, 0.075, 0.21), Color("eea644"))
		for side: float in [-1.0, 1.0]:
			_sphere(body, Vector3(side * 0.23, 0.9, 0.39), Vector3(0.035, 0.044, 0.035), Color("263b35"))
			_sphere(body, Vector3(side * 0.38, 0.45, -0.05), Vector3(0.07, 0.21, 0.33), Color("ecddb5"))
			_box(body, Vector3(side * 0.19, 0.075, 0.20), Vector3(0.19, 0.07, 0.27), Color("efa441"))
		var band_color: Color = [Color("72c888"), Color("edc35c"), Color("79c9e9")][current_island - 1]
		_box(body, Vector3(0, 0.68, 0.29), Vector3(0.48, 0.10, 0.31), band_color)
		duck.scale = Vector3.ONE * 1.25
		_ducks.append(duck)
		_duck_bodies.append(body)
	_duck = _ducks[0]
	_duck_body = _duck_bodies[0]

func _activity_station() -> void:
	_duck_station()
	if current_island == 1:
		_activity_label = _duck_label
		return
	if current_island == 2:
		var booth: Node3D = _root("BuyerContracts", Vector3(13.5, 0, 2.8))
		for x: float in [-1.25, 1.25]:
			_box(booth, Vector3(x, 1.4, 0), Vector3(0.14, 2.8, 0.14), Color("826342"))
		_box(booth, Vector3(0, 1.72, 0), Vector3(2.75, 1.75, 0.17), Color("87654b"))
		for x: float in [-0.65, 0.65]:
			_box(booth, Vector3(x, 1.76, 0.105), Vector3(1.03, 1.22, 0.055), Color("ffebbe"))
			for y: float in [1.5, 1.7, 1.9]: _box(booth, Vector3(x, y, 0.14), Vector3(0.67, 0.04, 0.02), Color("bfaf7e"))
		_roof(booth, 3.4, 1.55, 2.7, 0.5, Color("d19c54"))
		_crate(booth, Vector3(-0.9, 0.35, 0.9), true)
		_gem(booth, Vector3(0.85, 0.62, 1.0), Color("b4ddec"), 0.30)
		_activity_label = _label(booth, "BUYER CONTRACTS", Vector3(0, 3.6, 0), 26, CREAM)
		_target(booth, Vector3(0, 1.35, 0.4), Vector3(3.7, 3.2, 2.4), "station", "activities")
	else:
		var furnace: Node3D = _root("FrostFurnace", Vector3(17.8, 0, 10))
		_box(furnace, Vector3(0, 0.22, 0), Vector3(3.3, 0.44, 2.8), Color("668291"))
		_box(furnace, Vector3(0, 1.2, 0), Vector3(2.5, 2.1, 2.2), Color("7395a6"))
		_box(furnace, Vector3(0, 1.0, 1.15), Vector3(1.8, 1.2, 0.10), Color("273e4d"))
		_box(furnace, Vector3(0.74, 2.8, -0.45), Vector3(0.64, 1.9, 0.68), Color("476373"))
		_box(furnace, Vector3(0.74, 3.81, -0.45), Vector3(0.93, 0.18, 0.94), Color("cbe8ed"))
		_box(furnace, Vector3(-0.3, 2.3, 0), Vector3(2.2, 0.16, 2.3), Color("d9f0f0"))
		_furnace_flame = Node3D.new()
		furnace.add_child(_furnace_flame)
		for x: float in [-0.55, 0.0, 0.55]:
			var flame: MeshInstance3D = _sphere(_furnace_flame, Vector3(x, 0.89, 1.26), Vector3(0.27, 0.44 if x == 0 else 0.28, 0.12), Color("ffb44f"))
			flame.material_override = _bright_material(Color("ffc05f"))
		for index: int in range(5):
			var steam: MeshInstance3D = _sphere(furnace, Vector3(0.74, 4.0, -0.45), Vector3.ONE * 0.2, Color("eaf7ef"))
			_furnace_steam.append(steam)
		_activity_label = _label(furnace, "FROST FURNACE", Vector3(0, 4.55, 0), 26, CREAM)
		_target(furnace, Vector3(0, 1.8, 0), Vector3(3.4, 4.0, 3.3), "station", "activities")

func set_activity_state(info: Dictionary) -> void:
	_activity_info = info.duplicate(true)
	if is_instance_valid(_duck_label):
		_duck_label.text = "DUCK PATROL · %d / %d" % [int(info.get("duck_count", 0)), current_island]
	if not is_instance_valid(_activity_label):
		return
	match current_island:
		1:
			pass
		2:
			var contract: Dictionary = info.get("contract", {})
			_activity_label.text = "BUYER CONTRACTS" if contract.is_empty() else "CONTRACT · %d / %d" % [int(contract.get("delivered", 0)), int(contract.get("target", 1))]
		3:
			var remaining: float = float(info.get("furnace_remaining", 0))
			_activity_label.text = "FURNACE · %.0fs HEAT" % remaining if remaining > 0 else "FROST FURNACE"
			_furnace_flame.visible = remaining > 0
			for steam: Node3D in _furnace_steam: steam.visible = remaining > 0

func _animate_activities(delta: float) -> void:
	var patrols: Array = _activity_info.get("ducks", [])
	for index in range(_ducks.size()):
		var duck: Node3D = _ducks[index]
		var body: Node3D = _duck_bodies[index]
		var patrol: Dictionary = patrols[index] if index < patrols.size() else {}
		var target: int = int(patrol.get("target", -1))
		var from: int = int(patrol.get("from", target))
		var active: bool = bool(patrol.get("trained", false))
		if active and target >= 0 and target < plot_positions.size():
			var destination: Vector3 = plot_positions[target] + Vector3(0.65, 0.08, 0.35)
			var origin: Vector3 = plot_positions[from] + Vector3(0.65, 0.08, 0.35) if from >= 0 and from < plot_positions.size() else destination
			var position_next: Vector3 = origin.lerp(destination, clampf(float(patrol.get("progress", 0)), 0, 1))
			var direction: Vector3 = destination - origin
			if direction.length_squared() > 0.01:
				duck.rotation.y = lerp_angle(duck.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 10))
			duck.position = duck.position.lerp(position_next, minf(1.0, delta * 16))
		var clock: float = _time + index * 0.7
		body.rotation.z = sin(clock * (11 if active else 2)) * (0.10 if active else 0.03)
		body.position.y = absf(sin(clock * (11 if active else 2))) * (0.09 if active else 0.015)
		body.rotation.x = sin(float(patrol.get("peck", 0)) * 18) * 0.35 if float(patrol.get("peck", 0)) > 0 else 0.0
	if current_island == 3 and is_instance_valid(_furnace_flame) and _furnace_flame.visible:
		_furnace_flame.scale = Vector3(1, 0.95 + sin(_time * 12) * 0.12, 1)
		for index: int in range(_furnace_steam.size()):
			var phase: float = fmod(_time * 0.5 + float(index) / 5, 1.0)
			_furnace_steam[index].position = Vector3(0.74 + phase * 0.8, 4.0 + phase * 2.3, -0.45)
			_furnace_steam[index].scale = Vector3.ONE * (0.4 + sin(phase * PI) * 1.8)

func set_gear_hat(id: String) -> void:
	# Compatibility for captures and tools; gameplay passes the entire loadout.
	var loadout: Dictionary = _equipped_loadout.duplicate(true)
	loadout["head"] = id
	set_equipment(loadout, _gear_catalog)

func set_equipment(loadout: Dictionary, catalog: Dictionary) -> void:
	_equipped_loadout = loadout.duplicate(true)
	_gear_catalog = catalog
	_gear_hat_id = str(loadout.get("head", ""))
	if is_instance_valid(_player_body):
		_player_body.set_equipment(loadout, catalog)
		_gear_hat = _player_body.hat
