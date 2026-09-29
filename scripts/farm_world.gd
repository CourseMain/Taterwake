class_name FarmWorld
extends Node3D

const NpcAvatar = preload("res://scripts/npc_avatar.gd")
const FarmerAvatar = preload("res://scripts/farmer_avatar.gd")
const Type = preload("res://scripts/ui_type.gd")
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
var _tool_grade_scale: float = 1.0
var _effect_particles: Array[Dictionary] = []
var harvest_feedback: Node3D
var _crop_tubers: Dictionary = {}
var _area_selection: Node3D
var _area_key: String = ""
var _furrow_roots: Array[Node3D] = []
var _ripe_sparkles: Array[Node3D] = []
var _rotor: Node3D
var _clouds: Array[Node3D] = []
const Climate = preload("res://scripts/climate_system.gd")
const ClimateProjects = preload("res://scripts/climate_projects.gd")
var weather_station: Node3D
var coast: Node3D
var _climate_field: Node3D
var _project_nodes: Dictionary = {}
var _work_nodes: Dictionary = {}
var _cover_nodes: Dictionary = {}
var _work_progress: Dictionary = {}
var _climate_ice: Dictionary = {}
var _project_levels: Dictionary = {}
var _weather_strength: float = 0.0
var _weather_drought: bool = false
var _npc_actors: Dictionary = {}
var _staff_by_station: Dictionary = {}
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
var _shop_font: Font = Type.face(Type.SIGN, 600.0)
# Primitive resources are immutable and reused across crops and island rebuilds.
var _box_meshes: Dictionary = {}
var _cylinder_meshes: Dictionary = {}
var _sphere_mesh: SphereMesh
var _geometry_batcher := GeometryBatcher.new()
var graphics_quality: String = "balanced"
## Dormant region builders remain available for future regions. Gameplay uses Valley.
const REGION: int = 1
var current_island: int = REGION
var _ice_roots: Array[Node3D] = []
var _pest_roots: Array[Node3D] = []
var _pest_borders: Array[Node3D] = []
var _pest_labels: Array[Label3D] = []
var _pest_visuals: Array[Dictionary] = []
var _pest_focus: int = -1
var _snowflakes: Array[Node3D] = []
var _dock_label: Label3D
var _dock_gate: Node3D
var _impact_root: Node3D
var _activity_info: Dictionary = {}
var _duck_body: Node3D
var _ducks: Array[Node3D] = []
var _duck_bodies: Array[Node3D] = []
var _duck_label: Label3D
var _duck_home: Vector3 = Vector3.ZERO
var _tutorial_focus: String = ""
var _tutorial_show_labels: bool = true
var _tutorial_station_roots: Dictionary = {}
var _interaction_targets: Array[StaticBody3D] = []
var _tutorial_label_layers: Array[Node3D] = []
var _tutorial_marker: Label3D
var _tutorial_plot_outline: Node3D
var _tutorial_marker_height: float = 0.0
var _tutorial_trail: Array[Node3D] = []

## 50% more land area; props and saved crop coordinates retain their size.
const LAND_SPACING: float = 1.2247448714

const GRASS := Color("8ebd78")
const SOIL := Color("705037")
const LEAF := Color("517e43")
const TEAL := Color("367b7d")
const CREAM := Color("f7e4b6")
const GOLD := Color("efbe53")
const DAY_CYCLE_SECONDS: float = preload("res://scripts/season_clock.gd").SEASON_SECONDS
var _season_year: int = 1
var _season_index: int = 0
var _season_signal: String = ""
var _season_key: String = ""
var _season_blend: float = 1.0
var _season_from: Dictionary = {}
var _season_light: Dictionary = {}
var _season_materials: Array[Dictionary] = []
var _season_palette: Dictionary = {}
var _winter_visible: bool = false
var _winter_cover: Node3D
var _winter_roofs: Array[Node3D] = []

const TUTORIAL_STATION_NAMES: Dictionary = {
	"barn": "Barn", "market": "Seeds", "tools": "Tools",
	"duck_patrol": "Ducks",
	"contracts": "Contracts", "quests": "Quests", "activities": "Activities",
}

func build_world() -> void:
	_clear_world()
	current_island = REGION
	_rng.seed = 8105 if current_island == 1 else (20482 if current_island == 2 else 31803)
	_lighting()
	if current_island == 1:
		_build_land(_island)
		_build_land(_paths)
		_barn(Vector3(-12.0, 0.0, -8.0))
		_market(Vector3(0.0, 0.0, -9.0))
		_tool_upgrade_station(Vector3(-6.4, 0.0, -8.5))
		_windmill(Vector3(-13.2, 0.0, 4.0))
		_scenery()
		_valley_dock()
		_quest_board(Vector3(-12.0, 0.0, 8.1))
		_buyer_board()
	elif current_island == 2:
		_build_land(_tropical_island)
		_build_land(_tropical_paths)
		_barn(Vector3(-15.0, 0.0, -10.0))
		_market(Vector3(-1.0, 0.0, -11.0))
		_tool_upgrade_station(Vector3(-8.0, 0.0, -10.6))
		_tropical_scenery()
		_quest_board(Vector3(-12.0, 0.0, 11.0))
		_shores_jetty()
	else:
		_build_land(_winter_island)
		_build_land(_winter_paths)
		_barn(Vector3(-18.0, 0.0, -12.0))
		_market(Vector3(-3.0, 0.0, -14.0))
		_winter_scenery()
		_quest_board(Vector3(-15.0, 0.0, 14.0))
		_winter_jetty()
		_ice_forge(Vector3(18.0, 0.0, 2.0))
	_activity_station()
	_staff_stalls()
	_expand_village()
	_garden()
	coast = preload("res://scripts/coastal_world.gd").new()
	add_child(coast)
	coast.setup(self)
	weather_station = preload("res://scripts/weather_station.gd").new()
	add_child(weather_station)
	weather_station.setup(self)
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
	set_activity_state(_activity_info)
	_batch_world_geometry()
	_climate_field = load("res://scripts/climate_field_visuals.gd").new()
	add_child(_climate_field)
	_climate_field.setup(self)
	_prepare_tutorial_guidance()
	set_tutorial_focus(_tutorial_focus, _tutorial_show_labels)
	harvest_feedback = preload("res://scripts/harvest_feedback.gd").new()
	add_child(harvest_feedback)
	harvest_feedback.setup(self)
	_apply_season()


static func layout_point(point: Vector3) -> Vector3:
	return Vector3(point.x * LAND_SPACING, point.y, point.z * LAND_SPACING)

func _build_land(builder: Callable) -> void:
	var first: int = get_child_count()
	builder.call()
	for i in range(first, get_child_count()):
		var node := get_child(i) as Node3D
		node.position = layout_point(node.position)
		node.scale *= Vector3(LAND_SPACING, 1, LAND_SPACING)
		node.set_meta("land_layout", true)

func _expand_village() -> void:
	# Run once before the garden, player and climate equipment are added.
	# Moving roots also moves labels/colliders, without stretching their models.
	for node in get_children():
		if not node is Node3D or node is Camera3D or node is Light3D or node is WorldEnvironment or node.has_meta("land_layout"):
			continue
		node.position = layout_point(node.position)
		var building_scale: float = {"MarketStall": 1.16, "ToolUpgradeWorkshop": 1.14, "Windmill": 1.12, "IceForge": 1.16, "WashAndSortWorkshop": 1.10}.get(str(node.name), 1.0)
		node.scale *= building_scale
		# Keep the toolsmith at the same human scale as the player.
		for smith: Node3D in _toolsmiths:
			if smith.get_parent() == node: smith.scale /= building_scale
		if node.name in ["GoldenShoresDock", "GoldenShoresHarbor", "FrosthollowJetty"] or node.has_meta("layout_stretch"):
			node.scale *= Vector3(LAND_SPACING, 1, LAND_SPACING)
		for actor in _npc_actors.values():
			if actor.get_parent() == node:
				actor.scale = NpcAvatar.Roster.PEOPLE[actor.npc_id].shape / node.scale
	_duck_home = layout_point(_duck_home)

func _batch_world_geometry() -> void:
	# These individual meshes change transform, material or visibility at runtime.
	# All Node3D roots stay intact, including gates, ducks and tutorials.
	var mutable_meshes: Dictionary = {}
	for collection: Array in [_soil_meshes, _snowflakes]:
		for node: Node3D in collection:
			mutable_meshes[node.get_instance_id()] = true
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
	# The last target for a station is its main entrance rather than its NPC.
	var station_roots: Array = _tutorial_station_roots.get(station, [])
	return (station_roots.back() as Node3D).position if not station_roots.is_empty() else Vector3.ZERO


func farm_bounds() -> Rect2:
	var bounds := Rect2(-25, -8, 50, 26) if current_island == 3 else (Rect2(-20, -6, 40, 20) if current_island == 2 else Rect2(-17, -5, 35, 17))
	return Rect2(bounds.position * LAND_SPACING, bounds.size * LAND_SPACING)


func clamp_walk_position(point: Vector3) -> Vector3:
	var bounds: Rect2 = farm_bounds()
	return Vector3(clampf(point.x, bounds.position.x, bounds.end.x), 0, clampf(point.z, bounds.position.y, bounds.end.y))

func walk_route(_from: Vector3, to: Vector3) -> Array[Vector3]:
	return [clamp_walk_position(to)]

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
	_weather_strength = 0.0
	_weather_drought = false
	weather_station = null
	_project_nodes.clear()
	_work_nodes.clear()
	_cover_nodes.clear()
	_work_progress.clear()
	_climate_ice.clear()
	_project_levels.clear()
	_npc_actors.clear()
	_staff_by_station.clear()
	_villagers.clear()
	_toolsmiths.clear()
	_effect_particles.clear()
	_crop_tubers.clear()
	harvest_feedback = null
	_ice_roots.clear()
	_pest_roots.clear()
	_pest_borders.clear()
	_pest_labels.clear()
	_pest_visuals.clear()
	_pest_focus = -1
	_snowflakes.clear()
	_season_materials.clear()
	_season_key = ""
	_season_palette.clear()
	_winter_cover = null
	_winter_roofs.clear()
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
	coast = null
	camera = null
	player = null
	_player_body = null
	_tool = null
	_selection = null
	_area_selection = null
	_rotor = null
	_dock_label = null
	_dock_gate = null
	_impact_root = null
	_duck_body = null
	_duck_label = null
	_tutorial_station_roots.clear()
	_interaction_targets.clear()
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
	add_child(_sun)
	_apply_graphics_quality()
	# A gentle fill keeps crops, paths and the farmer readable throughout night.
	# Both lights use Compatibility features shared by native and web renderers.
	_moon = DirectionalLight3D.new()
	_moon.name = "CycleMoon"
	_moon.rotation_degrees = Vector3(-58.0, -15.0, 0.0)
	_moon.light_color = Color("b8d4ff") if current_island == 3 else Color("b6caf0")
	_moon.shadow_enabled = false
	add_child(_moon)
	set_day_time(_day_elapsed, _winter_visible)
	camera = Camera3D.new()
	camera.name = "DioramaCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (49.0 if current_island == 3 else (43.0 if current_island == 2 else 38.0)) * LAND_SPACING
	camera.position = Vector3(23.0, 31.0, 33.0) * LAND_SPACING
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.3, 0.5) if current_island == 3 else (Vector3(0.0, 0.3, -1.0) if current_island == 2 else Vector3(-0.3, 0.3, -1.2)))
	camera.current = true
	# Include the expanded shore and offshore previews in the camera depth.
	camera.far = 140.0


func set_graphics_quality(mode: String) -> void:
	graphics_quality = mode if mode in ["balanced", "smooth", "crisp"] else "balanced"
	_apply_graphics_quality()


func _apply_graphics_quality() -> void:
	if not is_instance_valid(_sun):
		return
	# One map suits this orthographic diorama; four perspective shadow splits
	# waste detail and introduce visible boundaries across the flat island.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 140.0
	_sun.directional_shadow_fade_start = 1.0
	# Large unsubdivided terrain near a shadow frustum can produce triangular
	# pancake artifacts. Keep the full geometry inside the shadow projection.
	_sun.directional_shadow_pancake_size = 0.0
	_sun.shadow_bias = 0.04
	_sun.shadow_opacity = 0.68
	# The calendar owns the sun direction; quality changes only shadow rendering.
	_sun.shadow_enabled = graphics_quality != "smooth"


func set_climate_projects(projects: Dictionary) -> void:
	var levels: Dictionary = projects.duplicate()
	levels.rainwater = int(levels.get("rainwater", 0)) + 1
	if levels == _project_levels: return
	for id: String in Climate.PROJECTS:
		var level: int = int(levels.get(id, 0))
		if level == int(_project_levels.get(id, 0)): continue
		if _project_nodes.has(id):
			var old: Node3D = _project_nodes[id]
			_retire_climate_node(old)
			_project_nodes.erase(id)
		if level > 0:
			var project: Node3D = ClimateProjects.build(self, id, level)
			_project_nodes[id] = project
			_geometry_batcher.batch_tree(project, {})
	_project_levels = levels.duplicate(true)


func set_climate(info: Dictionary) -> void:
	_climate_ice = info.get("operations", {}).get("ice", {})
	for i in range(_ice_roots.size()):
		_ice_roots[i].visible = _climate_ice.has(str(i))
	set_climate_projects(info.get("projects", {}))
	set_protection_work(info.get("protection", {}))
	if is_instance_valid(_climate_field): _climate_field.set_weather(info)
	var strength: float = 0.0
	if info.phase == "warning": strength = float(info.severity) * lerpf(0.15, 0.65, 1.0 - float(info.timer) / Climate.WARNING_SECONDS)
	elif info.phase == "active": strength = float(info.severity)
	elif info.phase == "recovery": strength = float(info.severity) * float(info.timer) / Climate.RECOVERY_SECONDS
	var drought: bool = info.event == "drought"
	if not is_equal_approx(strength, _weather_strength) or drought != _weather_drought:
		_weather_strength = strength
		_weather_drought = drought
		_applied_day_time = -1.0
		set_day_time(_day_elapsed, _winter_visible)

func set_day_time(elapsed: float, winter: bool = false) -> void:
	# The calendar supplies time within this season: dawn to dusk, never a daily loop.
	if not is_finite(elapsed) or elapsed < 0.0:
		return
	var winter_changed: bool = _winter_visible != winter
	_winter_visible = winter
	_day_elapsed = clampf(elapsed, 0.0, DAY_CYCLE_SECONDS)
	if is_instance_valid(player): _set_winter_cover(winter)
	if not is_instance_valid(_sun) or _day_environment == null:
		return
	if _day_elapsed == _applied_day_time and not winter_changed:
		return
	_applied_day_time = _day_elapsed
	var phase: float = _day_elapsed / DAY_CYCLE_SECONDS
	var height: float = sin(phase * PI)
	var daylight: float = 0.25 + 0.75 * height
	var twilight: float = pow(1.0 - height, 2.0 if _season_index == 2 else 3.0)
	_sun.rotation_degrees = Vector3(-lerpf(15.0 if winter else 25.0, 40.0 if winter else 70.0, height), lerpf(-70.0, 70.0, phase), 0)
	var day_sky: Color = Color("c3dce8") if current_island == 3 else (Color("b7e3df") if current_island == 2 else Color("c5deda"))
	var night_sky: Color = Color("263758") if current_island == 3 else (Color("263951") if current_island == 2 else Color("28364f"))
	var dusk_sky: Color = Color("b69bc5") if current_island == 3 else (Color("ecb986") if current_island == 2 else Color("d7a5a1"))
	var day_sun: Color = Color("f0f6ff") if winter or current_island == 3 else Color("fff8ed")
	var dusk_sun: Color = Color("ffcddc") if winter or current_island == 3 else Color("ffd1a0")
	_day_environment.background_color = night_sky.lerp(day_sky, daylight).lerp(dusk_sky, twilight * 0.72)
	_day_environment.ambient_light_color = Color("9dafd0").lerp(Color("f0f3e8"), daylight).lerp(dusk_sun, twilight * 0.25)
	_day_environment.ambient_light_energy = lerpf(0.44, 0.45, daylight)
	_sun.light_color = day_sun.lerp(dusk_sun, twilight * 0.75)
	_sun.light_energy = (0.48 if winter else 0.65) * daylight
	_moon.light_energy = 0.48 * (1.0 - daylight)
	if _weather_strength > 0.0:
		_day_environment.background_color = _day_environment.background_color.lerp(Color("b88b53") if _weather_drought else Color("344b5c"), _weather_strength * 0.85)
		_day_environment.ambient_light_color = _day_environment.ambient_light_color.lerp(Color("e9b36b") if _weather_drought else Color("8da5b9"), _weather_strength * 0.55)
		_sun.light_energy *= 1.0 - _weather_strength * (0.10 if _weather_drought else 0.55)
		if _weather_drought:
			_sun.light_energy = maxf(_sun.light_energy, 0.95 * _weather_strength)
			_sun.light_color = Color("ffe0a0")
	if _season_blend < 1.0 and not _season_light.is_empty():
		_day_environment.background_color = _season_light.sky.lerp(_day_environment.background_color, _season_blend)
		_day_environment.ambient_light_color = _season_light.ambient.lerp(_day_environment.ambient_light_color, _season_blend)
		_sun.light_color = _season_light.sun.lerp(_sun.light_color, _season_blend)
		_sun.light_energy = lerpf(_season_light.energy, _sun.light_energy, _season_blend)
		_sun.rotation_degrees = _season_light.rotation.lerp(_sun.rotation_degrees, _season_blend)
	if is_instance_valid(coast): coast.sync_light()



func day_cycle_info() -> Dictionary:
	var phase: float = _day_elapsed / DAY_CYCLE_SECONDS
	return {"seconds": _day_elapsed, "duration": DAY_CYCLE_SECONDS, "phase": phase,
		"daylight": 0.25 + 0.75 * sin(phase * PI)}

func _island() -> void:
	_prism(self, Vector3(0.0, -1.35, 0.0), 39.5, 30.0, 1.7, Color("8a6346"))
	_prism(self, Vector3(0.0, -0.58, 0.0), 40.0, 30.4, 0.55, Color("b68b59"))
	_season_mesh(_prism(self, Vector3(0.0, -0.17, 0.0), 40.3, 30.7, 0.3, GRASS), "grass")
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
			ice.name = "ClimateIce"
			root.add_child(ice)
			_ice_roots.append(ice)
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
		# Loading can replace a plot dictionary without changing its visual key.
		if _crop_tubers.has(i): _crop_tubers[i].plot = data
		if i < _ice_roots.size():
			_ice_roots[i].visible = _climate_ice.has(str(i))
		var unlocked: bool = bool(data.get("unlocked", true))
		var stage: int = int(data.get("stage", 0))
		var infested: bool = unlocked and stage > 0 and bool(data.get("pests", false))
		var pest_damage: float = clampf(float(data.get("pest_damage", 0.0)), 0.0, 1.0)
		var damage_level: int = int(pest_damage * 10.0)
		_update_pest_visual(i, data, infested, pest_damage)
		var watered: bool = bool(data.get("watered", false))
		var tilled: bool = bool(data.get("tilled", true))
		var crop_kind: String = str(data.get("crop", "russet"))
		var crop_color: Color = _crop_appearance(data).crop
		# Only the plant grows. Soil marks and the pest-shaking parent stay fixed.
		_crop_roots[i].scale = Vector3.ONE
		var key: String = "%s/%d/%s/%s/%s/%s/%d/%s" % [str(unlocked), stage, str(watered), str(tilled), crop_kind, str(infested), damage_level, str(data.get("pest_destroyed", false))]
		if key == _plot_states[i]:
			if _crop_tubers.has(i): _update_crop_tuber(_crop_tubers[i])
			continue
		_plot_states[i] = key
		_crop_tubers.erase(i)
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
		var tuber: Node3D = _create_crop_tuber(root, data)
		tuber.position = Vector3(0, .25, 0)
		_crop_tubers[i] = {"node": tuber, "plot": data}
		_update_crop_tuber(_crop_tubers[i])
		if stage == 3:
			var sparkle := _gem(root, Vector3(0.0, .45 + 1.58 * _crop_tuber_size(data), 0.0), GOLD, 0.12)
			_ripe_sparkles.append(sparkle)
		_geometry_batcher.batch_siblings(root)
	_update_pest_caption_density()

func _crop_appearance(plot: Dictionary) -> Dictionary:
	var crop_kind: String = str(plot.get("crop", "russet"))
	var crop_color := Color(str({"russet":"dfb36f", "giant":"d7a37b", "golden":"f5cc38", "sunburst":"ffa629", "icecap":"d8f1ff"}.get(crop_kind, "dfb36f")))
	var foliage := Color(str({"russet":"749e44", "giant":"729758", "golden":"9ba149", "sunburst":"83a746", "icecap":"759ba5"}.get(crop_kind, "749e44")))
	var damage: int = int(clampf(float(plot.get("pest_damage", 0)), 0, 1) * 10)
	return {"crop": crop_color.lerp(Color("9e8969"), damage * .035), "foliage": foliage.lerp(Color("988759"), damage * .065)}

func _crop_tuber_size(plot: Dictionary) -> float:
	return float({"giant": .90, "sunburst": .70, "icecap": .72}.get(str(plot.get("crop", "russet")), .62))

func _create_crop_tuber(parent: Node3D, plot: Dictionary) -> Node3D:
	# The intro, ordinary growth and harvest all use this same potato.
	var tuber := Node3D.new()
	tuber.name = "PotatoTuber"
	parent.add_child(tuber)
	var appearance: Dictionary = _crop_appearance(plot)
	var color: Color = appearance.crop
	_sphere(tuber, Vector3(0,.58,0), Vector3(1.03,.87,.83), color)
	_sphere(tuber, Vector3(-.65,.48,.03), Vector3(.45,.52,.59), color.darkened(.07))
	for eye: Vector3 in [Vector3(.35,1.19,.43), Vector3(-.30,.72,.79), Vector3(.65,.38,.63)]:
		_sphere(tuber, eye, Vector3(.05,.035,.025), color.darkened(.27))
	for side: float in [-1, 1]:
		_leaf(tuber, Vector3(side*.22,1.44,0), Vector3(.42,.14,.24), appearance.foliage, side*.35)
	if int(plot.get("stage", 0)) == 3:
		if plot.get("crop") == "sunburst": _sunburst_bloom(tuber, Vector3(0,1.58,0))
		elif plot.get("crop") == "icecap": _icecap_bloom(tuber, Vector3(0,1.58,0))
	_geometry_batcher.batch_siblings(tuber)
	return tuber

func _update_crop_tuber(entry: Dictionary) -> void:
	var plot: Dictionary = entry.plot
	var progress: float = 1.0 if int(plot.stage) == 3 else clampf(float(plot.get("elapsed", 0)) / float(FarmState.CropTable.CROPS[str(plot.crop)].grow), 0, 1)
	entry.node.scale = Vector3.ONE * _crop_tuber_size(plot) * lerpf(.375, 1.0, smoothstep(0, 1, progress))


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

func animate(delta: float, moving: bool, sprint: float = 0.0) -> void:
	_time += delta
	if is_instance_valid(harvest_feedback): harvest_feedback.animate(delta)
	for entry: Dictionary in _crop_tubers.values():
		if is_instance_valid(entry.node): _update_crop_tuber(entry)
	if is_instance_valid(coast): coast.animate(delta)
	if is_instance_valid(_tutorial_marker) and _tutorial_marker.visible:
		_tutorial_marker.position.y = _tutorial_marker_height + sin(_time * 2.8) * 0.16
		var destination: Vector3 = _tutorial_marker.position
		destination.y = 1.15
		var origin: Vector3 = player.position
		origin.y = 1.15
		var direction: Vector3 = destination - origin
		var distance: float = direction.length()
		var guide: Curve3D
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
		_player_body.carry_weight = 1.0
		_player_body.pour_pose = pow(sin((1.0 - _tool_time / _tool_duration) * PI), 2) if _tool_time > 0 and _tool_action == "water" else 0.0
		_player_body.harvest_pose = harvest_feedback.pull_pose if is_instance_valid(harvest_feedback) else 0.0
		_player_body.animate(delta, moving, sprint)
	if is_instance_valid(_rotor):
		_rotor.rotation.z += delta * 0.38
	_animate_effects(delta)
	_animate_winter(delta)
	_animate_pests(delta)
	_animate_activities(delta)
	for i in range(_ripe_sparkles.size() - 1, -1, -1):
		if not is_instance_valid(_ripe_sparkles[i]):
			_ripe_sparkles.remove_at(i)
		else:
			_ripe_sparkles[i].rotation.y += delta * 1.5
			_ripe_sparkles[i].scale = Vector3.ONE * (0.9 + sin(_time * 3.0 + float(i)) * 0.16)

	for villager in _villagers:
		if villager.has_method("animate"): villager.animate(delta, false)
	for toolsmith in _toolsmiths:
		toolsmith.animate(delta, false)
	for i in range(_clouds.size()):
		_clouds[i].position.x += delta * (0.06 + _weather_strength * 1.8)
		_clouds[i].scale = Vector3.ONE * (1.0 + _weather_strength * 0.45)
		if _clouds[i].position.x > 24.0 * LAND_SPACING:
			_clouds[i].position.x = -24.0 * LAND_SPACING

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
	_shop_label(root, "Barn", Vector3(0.0, 5.65, 0.0))

func _market(pos: Vector3) -> void:
	var root := _root("MarketStall", pos)
	_box(root, Vector3(0.0, 0.15, 0.0), Vector3(5.3, 0.3, 3.6), Color("b49d74"))
	for x in [-2.2, 2.2]:
		for z in [-1.45, 0.15]:
			_box(root, Vector3(x, 1.75, z), Vector3(0.18, 3.3, 0.18), Color("765940"))
	_box(root, Vector3(0.0, 0.55, 1.6), Vector3(4.7, 0.7, 0.65), Color("aa7950"))
	_box(root, Vector3(0.0, 0.95, 1.6), Vector3(4.9, 0.12, 0.85), CREAM)
	for i in range(8):
		var x: float = -2.45 + float(i) * 0.7
		var stripe_color: Color = (Color("638b9d") if current_island == 3 else (Color("46b8a8") if current_island == 2 else Color("e4a257"))) if i % 2 == 0 else (Color("e6f0ee") if current_island == 3 else Color("f7e7ba"))
		var awning := _box(root, Vector3(x, 3.23, -0.75), Vector3(0.71, 0.15, 1.8), stripe_color)
		awning.rotation.x = -0.12
		_box(root, Vector3(x, 3.0, 0.15), Vector3(0.71, 0.43, 0.14), stripe_color)
	for i in range(2):
		var crate_pos := Vector3(-1.65 + float(i) * 3.3, 1.08, 1.6)
		_crate(root, crate_pos, true)
	preload("res://scripts/village_details.gd").mara_stall(self, root)
	var vendor := _npc_person(root, Vector3(0.0, 0.18, 0.65), "mara")
	_villagers.append(vendor)
	_shop_label(root, "Seeds", Vector3(0.0, 4.45, 0.0))
	_target(root, Vector3(0.0, 1.8, 0.0), Vector3(5.3, 3.6, 4.0), "station", "market")

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
	_season_verges()
	for i in range(70):
		var x: float = _rng.randf_range(-18.0, 18.0)
		var z: float = _rng.randf_range(9.2, 13.1) if i < 40 else _rng.randf_range(-12.9, 10.0)
		if i >= 40 and absf(x) < 15.0:
			x = 17.0 * (-1.0 if i % 2 == 0 else 1.0) + _rng.randf_range(-0.8, 0.8)
		var pos := Vector3(x, 0.15, z)
		_cylinder(self, pos, 0.025, 0.02, 0.32, Color("567e4b"), 4)
		var flower_color: Color = Color("f8daa2") if i % 3 == 0 else (Color("d8a3a0") if i % 3 == 1 else Color("f7f0cd"))
		_sphere(self, pos + Vector3(0.0, 0.19, 0.0), Vector3(0.13, 0.07, 0.13), flower_color)
	# Leave a proper opening beside the northern path.
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
	for data in [[Vector3(9.2, 0, 1.2), Color("d8ab74"), Color("dba464")], [Vector3(-4.8, 0, -5.0), Color("bd8e60"), Color("68928a")]]:
		var id: String = "pip" if is_equal_approx(data[0].x, 9.2) else "nell"
		var villager := _npc_person(self, data[0], id, NpcAvatar.Roster.PEOPLE[id].service)
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
	var spare_can := _root("SpareWateringCan", Vector3(5.3, 0, 5.1))
	_cylinder(spare_can, Vector3(0, 0.33, 0), 0.29, 0.29, 0.55, Color("7cabb1"), 8)
	_bar(spare_can, Vector3(0.2, 0.4, 0), Vector3(0.67, 0.64, 0), 0.09, Color("7cabb1"))

func _tree(pos: Vector3, size: float) -> void:
	var root := _root("OrchardTree", pos)
	root.scale = Vector3.ONE * size
	_cylinder(root, Vector3(0.0, 1.1, 0.0), 0.22, 0.13, 2.2, Color("876346"), 7)
	_season_mesh(_sphere(root, Vector3(0.0, 2.8, 0.0), Vector3(1.36, 1.7, 1.30), Color("6b965b")), "canopy")
	_season_mesh(_sphere(root, Vector3(-0.72, 2.4, 0.18), Vector3(0.88, 1.03, 0.9), Color("80a768")), "canopy")
	_season_mesh(_sphere(root, Vector3(0.68, 2.5, 0.1), Vector3(0.85, 1.2, 0.87), Color("8eae6b")), "canopy")
	for i in range(3):
		_sphere(root, Vector3(-0.65 + float(i) * 0.58, 2.45 + float(i % 2) * 0.65, 1.03), Vector3(0.15, 0.16, 0.15), Color("d5a660"))

	for i in range(9):
		var point := Vector3(sin(i * 2.4) * 1.08, 2.6 + cos(i * 1.7) * 0.8, cos(i * 2.4) * 1.05)
		_season_mesh(_sphere(root, point, Vector3.ONE * 0.22, Color("f3c4d2")), "blossom")

func _staff_stalls() -> void:
	# Each keeper has a reason to stand here: serve the counter, mind the
	# doorway, inspect the belt or watch the ducks. Leave their approaches open.
	_place_stallholder("mara", "market", "MarketStall", Vector3(-.25,.18,.68), -12)
	_place_stallholder("nell", "barn", "RedBarn", Vector3(-1.8,.05,3.05), 75)
	_place_stallholder("pip", "duck_patrol", "DuckPatrolHouse", Vector3(2.1,0,1.4), -84)
	_place_stallholder("tess", "quests", "FarmingQuestBoard", Vector3(1.65,0,1.05), -58)

func _place_stallholder(id: String, station: String, stall_name: String, at: Vector3, facing_degrees: float) -> void:
	var stall: Node3D = get_node(stall_name)
	var actor: Node3D = _npc_actors.get(id)
	if actor == null:
		actor = _npc_person(stall, at, id, station)
		_villagers.append(actor)
	elif actor.get_parent() != stall:
		actor.reparent(stall, false)
	actor.position = at
	actor.rotation.y = deg_to_rad(facing_degrees)
	_staff_by_station[station] = actor

func _npc_person(parent: Node3D, pos: Vector3, id: String, station: String = "") -> Node3D:
	var person := NpcAvatar.new()
	parent.add_child(person)
	person.configure(id)
	_npc_actors[id] = person
	person.position = pos
	if not station.is_empty():
		# Preserve the shop entrance used by the farm tour.
		var entrances: Array = _tutorial_station_roots.get(station, []).duplicate()
		_target(person, Vector3(0,1,0), Vector3(1.4,2,1.15), "station", station)
		_tutorial_station_roots[station] = entrances
	return person

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
	var fence := _root("Fence", Vector3.ZERO)
	fence.set_meta("layout_stretch", true)
	for i in range(segments + 1):
		var pos: Vector3 = start.lerp(end, float(i) / float(segments))
		_box(fence, pos + Vector3(0.0, 0.48, 0.0), Vector3(0.16, 0.96, 0.16), Color("e3d4a8"))
		_cylinder(fence, pos + Vector3(0.0, 1.01, 0.0), 0.135, 0.0, 0.16, Color("f1dfb6"), 4)
	for y in [0.35, 0.71]:
		_bar(fence, start + Vector3(0, y, 0), end + Vector3(0, y, 0), 0.065, Color("e1d2a7"))

func _crate(parent: Node3D, pos: Vector3, full: bool) -> void:
	if parent == self:
		parent = _root("VillageCrate", pos)
		pos = Vector3.ZERO
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
	if key == "station": _interaction_targets.append(body)

func nearby_station() -> Dictionary:
	# Choose the closest interaction; standing on a bed always keeps crop work.
	var closest: Dictionary = {}
	var reach: float = 2.0
	for point: Vector3 in plot_positions:
		reach = minf(reach, player.position.distance_to(point))
	for body: StaticBody3D in _interaction_targets:
		if not is_instance_valid(body) or not body.is_inside_tree() or not body.is_visible_in_tree() or body.collision_layer == 0: continue
		var station: String = str(body.get_meta("station"))
		if station.begins_with("equipment:"): continue
		var shape: BoxShape3D = body.get_child(0).shape
		var local: Vector3 = body.to_local(player.global_position)
		var edge := Vector3(clampf(local.x, -shape.size.x / 2, shape.size.x / 2), local.y, clampf(local.z, -shape.size.z / 2, shape.size.z / 2))
		var distance: float = player.global_position.distance_to(body.to_global(edge))
		# Resolve overlapping shop/NPC hit boxes by their horizontal centers.
		distance += Vector2(local.x, local.z).length() * 0.001
		if distance < reach:
			reach = distance
			closest = {"station": station, "point": body.to_global(Vector3(0, shape.size.y / 2 + 0.4, 0))}
	if not closest.is_empty():
		var actor: Node3D = _staff_by_station.get(str(closest.station))
		if is_instance_valid(actor) and actor.is_visible_in_tree():
			closest.point = actor.global_position + Vector3(0,2.6,0)
	return closest

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
	material.set_meta("static_colour", true)
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

func _shop_label(parent: Node3D, text: String, pos: Vector3, distant: bool = false) -> Label3D:
	var ink := Color("171c19")
	var label := _label(parent, text, pos, 28 if distant else 32, Color("ffffff"))
	label.font = _shop_font
	label.pixel_size = 0.019
	label.outline_modulate = ink
	label.outline_size = 7
	label.set_meta("shop_label", true)
	return label


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

func _prism(parent: Node3D, pos: Vector3, width: float, depth: float, height: float, color: Color) -> MeshInstance3D:
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
	# The broad island shells receive prop shadows but do not cast enormous
	# low-poly silhouettes onto the ocean or their own thin shoreline layers.
	instance.name = "IslandTerrainShell"
	instance.set_meta("terrain_shell", true)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

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

func play_farm_effect(indices: Array, action: String, grade: int = 0, snapshots: Dictionary = {}) -> void:
	if not is_instance_valid(_tool):
		return
	if is_instance_valid(harvest_feedback):
		if action == "harvest" and not snapshots.is_empty(): harvest_feedback.harvest(snapshots)
		else: harvest_feedback.audio.play_action(action)
	_tool_action = action
	_tool_duration = 0.5 / (1.0 + float(grade) * 0.35)
	_tool_time = _tool_duration
	_tool_grade_scale = 1.0 + float(grade) * 0.2
	_tool.scale = Vector3.ONE * 0.001
	_tool.visible = action not in ["water", "harvest"]
	for child in _tool.get_children():
		_tool.remove_child(child)
		child.queue_free()
	if action == "water":
		pass # The persistent carried can performs the pour; no duplicate model.
	elif action == "pest":
		_cylinder(_tool, Vector3(0.0, 0.07, 0.0), 0.22, 0.26, 0.55, Color("66d5b6"), 12)
		_box(_tool, Vector3(0.0, 0.37, 0.0), Vector3(0.32, 0.13, 0.24), Color("263c44"))
		_bar(_tool, Vector3(0.05, 0.41, 0.0), Vector3(0.42, 0.41, 0.0), 0.075, Color("ffd15c"))
		_bar(_tool, Vector3(0.16, 0.34, 0.0), Vector3(0.11, 0.20, 0.0), 0.035, Color("263c44"))
		_box(_tool, Vector3(0.0, 0.05, 0.23), Vector3(0.17, 0.21, 0.025), Color("fff6d5"))
	elif action == "hoe" or action == "harvest" or action in ["ice", "break_ice"]:
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
		if action in ["harvest"]: continue
		var pos: Vector3 = plot_positions[index]
		# Keep the action readable without filling a large field with hundreds of particles.
		var budget: int = 40
		var per_patch: int = 4
		var particle_count: int = maxi(1, mini(per_patch, int(budget / maxi(1, indices.size()))))
		for i in range(particle_count):
			var color: Color = Color("72f4ce") if action == "pest" else (GOLD if action == "harvest" else (Color("bfe9fb") if action in ["ice", "break_ice"] or (current_island == 3 and action == "hoe") else (Color("8ddbe8") if action == "water" else Color("bc9669"))))
			var initial: Vector3 = pos + Vector3(_rng.randf_range(-0.65, 0.65), 1.3 if action in ["water", "pest"] else 0.35, _rng.randf_range(-0.65, 0.65))
			var particle := _sphere(self, initial, Vector3(0.18, 0.07, 0.18) if action == "pest" else Vector3(0.08, 0.18 if action == "water" else 0.08, 0.08), color)
			var velocity := Vector3(_rng.randf_range(-1.0, 1.0), -1.3 if action == "water" else (-0.3 if action == "pest" else _rng.randf_range(1.3, 3.0)), _rng.randf_range(-1.0, 1.0))
			_effect_particles.append({"node": particle, "velocity": velocity, "life": 0.8, "total": 0.8})
func play_reward(rarity: String) -> void:
	if not is_instance_valid(player):
		return
	var tier: String = rarity.to_lower()
	if tier not in ["legendary"]:
		return
	var island_color: Color = Color("62ffa0") if current_island == 1 else (Color("ffdb62") if current_island == 2 else Color("8ee7ff"))
	var count: int = 28
	var lifetime: float = 3.6
	for i in range(count):
		var angle: float = float(i) * TAU / float(count)
		var pos: Vector3 = player.position + Vector3(cos(angle) * 0.45, 1.1, sin(angle) * 0.45)
		var particle: Node3D = _gem(self, pos, island_color if i % 3 else Color("fff2ba"), 0.17)
		var velocity := Vector3(cos(angle) * 1.45, _rng.randf_range(1.4, 2.3), sin(angle) * 1.45)
		_effect_particles.append({"node": particle, "velocity": velocity, "life": lifetime, "total": lifetime, "gravity": 0.75})
	_reward_halo(island_color, lifetime)
	_show_impact(tier.to_upper() + "!", player.position + Vector3(0.0, 2.5, 0.0), island_color, 34, 3.0)


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
	# A new highlight replaces the last one; routine feedback lives in the HUD.
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
		var stroke: float = pow(sin(progress * PI), 2)
		_tool.rotation.z = stroke * 1.15
		var hand: Vector3 = player.to_local(_player_body.hand_transform().origin)
		_tool.position = hand + Vector3(0.05, 0.10, 0.12)
		# Brief eased pickup/put-away avoids a full-size tool popping into existence.
		var envelope: float = smoothstep(0, 0.18, progress) * (1.0 - smoothstep(0.76, 1.0, progress))
		_tool.scale = Vector3.ONE * maxf(0.001, envelope) * _tool_grade_scale
		_player_body.rotation.x = stroke * -0.14 if _tool_action != "harvest" else 0.0
		_tool.visible = _tool_time > 0.0 and _tool_action not in ["water", "harvest"]
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

func _valley_dock() -> void:
	# Decorative jetty; no boarding route or interaction.
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
	_dock_label = _shop_label(dock, "Pier", Vector3(0.0, 1.85, -0.4))


func _tropical_island() -> void:
	_prism(self, Vector3(0.0, -1.35, 0.0), 45.7, 35.5, 1.6, Color("9d8668"))
	_prism(self, Vector3(0.0, -0.58, 0.0), 46.0, 36.0, 0.55, Color("b9a884"))
	var sand := _prism(self, Vector3(0.0, -0.17, 0.0), 46.3, 36.3, 0.30, Color("e5d4ac"))
	sand.material_override = preload("res://scripts/island_terrain.gd").material(false, Vector2(46.3, 36.3))
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


func _tropical_paths() -> void:
	_box(self, Vector3(0.0, 0.027, -6.6), Vector3(35.0, 0.07, 2.0), Color("c9b99a"))
	_box(self, Vector3(10.2, 0.029, 2.0), Vector3(2.0, 0.07, 18.0), Color("c9b99a"))
	_box(self, Vector3(1.0, 0.032, 10.6), Vector3(30.5, 0.07, 2.1), Color("c9b99a"))
	for i in range(29):
		_box(self, Vector3(-15.5 + float(i) * 1.1, 0.075, -6.6 + _rng.randf_range(-0.35, 0.35)), Vector3(0.60, 0.035, 0.65), Color("e4d6b6"))
	for i in range(15):
		var paver := _box(self, Vector3(10.2, 0.078, -5.5 + float(i) * 1.02), Vector3(0.76, 0.036, 0.42), Color("e4d6b6"))
		paver.rotation.y = _rng.randf_range(-0.1, 0.1)


func _tropical_scenery() -> void:
	for point in [Vector3(-21.0, 0.0, -12.5), Vector3(-20.0, 0.0, -3.0), Vector3(-20.3, 0.0, 9.5), Vector3(-16.2, 0.0, 14.7), Vector3(20.1, 0.0, -12.5), Vector3(21.2, 0.0, 3.5), Vector3(20.0, 0.0, 14.6), Vector3(10.9, 0.0, 15.7)]:
		_palm(self, point, _rng.randf_range(0.9, 1.25))
	preload("res://scripts/island_terrain.gd").beach_shells(self)
	for point in [Vector3(-19.0, 0.0, 5.0), Vector3(-17.8, 0.0, -15.0), Vector3(17.1, 0.0, -15.0), Vector3(17.8, 0.0, 13.9)]:
		for index in range(4):
			var angle: float = float(index) * 1.9
			var leaf := _sphere(self, point + Vector3(cos(angle) * 0.35, 0.40, sin(angle) * 0.3), Vector3(0.70, 0.12, 0.28), Color("78a76e"))
			leaf.rotation = Vector3(0.0, -angle, 0.6)
		_sphere(self, point + Vector3(0.0, 0.53, 0.0), Vector3(0.17, 0.15, 0.17), Color("f0a269"))
	for data in [[Vector3(-12.0, 0.0, -6.4), Color("d3a268"), Color("4baca3")], [Vector3(13.5, 0.0, 4.0), Color("dca76e"), Color("88b194")], [Vector3(-14.0, 0.0, 9.0), Color("bd8f61"), Color("63a9b9")]]:
		var id: String = "nell" if data[0].x == -12 else "edwin" if data[0].x == 13.5 else "tess"
		var villager := _npc_person(self, data[0], id, NpcAvatar.Roster.PEOPLE[id].service)
		villager.rotation.y = _rng.randf_range(-0.8, 0.7)
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
	_shop_label(board, "Quests", Vector3(0.0, 3.18, 0.0))
	_target(board, Vector3(0.0, 1.35, 0.05), Vector3(2.9, 2.9, 1.05), "station", "quests")


func _shores_jetty() -> void:
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
	_dock_label = _shop_label(dock, "Pier", Vector3(0.0, 2.8, 0.8))
	for z in [-1.6, 3.8]:
		var flag_root := Node3D.new()
		dock.add_child(flag_root)
		flag_root.position = Vector3(1.50, 0.0, z)
		_cylinder(flag_root, Vector3(0.0, 1.75, 0.0), 0.045, 0.045, 3.2, Color("a37d49"), 6)
		_box(flag_root, Vector3(0.43, 2.7, 0.0), Vector3(0.86, 0.53, 0.055), GOLD)
		_sphere(flag_root, Vector3(0.44, 2.71, 0.05), Vector3(0.13, 0.16, 0.035), Color("fff2bc"))

func _winter_island() -> void:
	_prism(self, Vector3(0.0, -1.35, 0.0), 55.4, 43.4, 1.7, Color("7d8c97"))
	_prism(self, Vector3(0.0, -0.59, 0.0), 55.8, 43.8, 0.57, Color("b4c4ca"))
	var snow := _prism(self, Vector3(0.0, -0.15, 0.0), 56.2, 44.2, 0.34, Color("e6eef0"))
	snow.material_override = preload("res://scripts/island_terrain.gd").material(true, Vector2(56.2, 44.2))
	preload("res://scripts/island_terrain.gd").snowbanks(self)
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
	for point in [Vector3(-25,0,-17), Vector3(-25,0,-7), Vector3(-24,0,4), Vector3(-25,0,15), Vector3(-19,0,19), Vector3(25,0,-17), Vector3(25,0,-11), Vector3(25,0,1), Vector3(25,0,17), Vector3(17,0,19)]:
		_snow_pine(point, _rng.randf_range(0.9, 1.2))
	for point in [Vector3(-23.5,0,9), Vector3(-23,0,-19), Vector3(4,0,-19), Vector3(24,0,-2), Vector3(12,0,19), Vector3(-10,0,19)]:
		for i in range(3):
			var size: float = _rng.randf_range(0.62, 1.1)
			var pos: Vector3 = point + Vector3(float(i) * 0.68, 0.34, float(i % 2) * 0.35)
			_sphere(self, pos, Vector3(0.82, 0.65, 0.64) * size, Color("8999a4"))
			_sphere(self, pos + Vector3(0.0, 0.34 * size, -0.02), Vector3(0.79, 0.31, 0.61) * size, Color("e9f0f1"))
	# The frozen pond is decorative.
	_sphere(self, Vector3(19.1, 0.00, -4.6), Vector3(4.0, 0.055, 2.35), Color("accedf"))
	_sphere(self, Vector3(19.0, 0.045, -4.55), Vector3(3.68, 0.03, 2.06), Color("c6e1ed"))
	for endpoints in [[Vector3(16.3,0.084,-4.2),Vector3(20.2,0.084,-4.8)],[Vector3(18.4,0.086,-6.2),Vector3(19.7,0.086,-3.2)],[Vector3(19.6,0.087,-3.7),Vector3(21.5,0.087,-4.0)]]:
		_bar(self, endpoints[0], endpoints[1], 0.025, Color("94bbcf"))
	for i in range(7):
		_box(self, Vector3(15.3 + float(i) * 0.40, 0.19, -3.3), Vector3(0.34, 0.16, 1.3), Color("9f8e7a"))
	for data in [[Vector3(-14,0,-8.2),Color("c89b6c"),Color("926d78")],[Vector3(15,0,11.8),Color("c5976d"),Color("9e8868")],[Vector3(-17,0,11.5),Color("d2a574"),Color("728a91")]]:
		var id: String = "nell" if data[0].x == -14 else "edwin" if data[0].x == 15 else "tess"
		var resident := _npc_person(self, data[0], id, NpcAvatar.Roster.PEOPLE[id].service)
		resident.rotation.y = _rng.randf_range(-0.6, 0.65)
		_villagers.append(resident)
	for point in [Vector3(-13.8,0.33,-12.2),Vector3(-13.8,0.89,-12.2),Vector3(1.1,0.3,-12.8),Vector3(2.4,0.3,-12.8)]:
		_crate(self, point, true)
		_box(self, point + Vector3(0.0,0.55,0.0), Vector3(1.15,0.09,0.84), Color("eef3f3"))
	for point in [Vector3(-13.8,0,-7.9),Vector3(12.6,0,12.4),Vector3(-16.2,0,14.4)]:
		_winter_lantern(point)
	_sign(Vector3(-4.0,0.0,16.0), "FROSTHOLLOW", Color("627d8d"))
	_falling_snow(self, Vector2(25, 18))


func _falling_snow(parent: Node3D, extent: Vector2) -> void:
	for i in range(28):
		var snowflake := _sphere(parent, Vector3(_rng.randf_range(-extent.x, extent.x), _rng.randf_range(1.5, 8.0), _rng.randf_range(-extent.y, extent.y)), Vector3.ONE * 0.035, Color("f1f7f8"))
		snowflake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_snowflakes.append(snowflake)

func _set_winter_cover(enabled: bool) -> void:
	if enabled and not is_instance_valid(_winter_cover):
		_winter_cover = _root("WinterSnow", Vector3.ZERO)
		var snow := _prism(_winter_cover, Vector3(0, 0.0, 0), 40.3 * LAND_SPACING, 30.7 * LAND_SPACING, 0.03, Color("e6eef0"))
		snow.material_override = preload("res://scripts/island_terrain.gd").material(true, Vector2(40.3, 30.7) * LAND_SPACING)
		snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_falling_snow(_winter_cover, Vector2(19, 14) * LAND_SPACING)
		var barn: Node3D = get_node_or_null("RedBarn")
		if is_instance_valid(barn):
			var roof := Node3D.new()
			barn.add_child(roof)
			_snow_roof(roof, 6.0, 5.0, 3.85, 1.4)
			_winter_roofs.append(roof)
	if is_instance_valid(_winter_cover):
		var snow_weight: float = float(_season_palette.get("snow", 1.0 if enabled else 0.0)) if not _season_key.is_empty() else (1.0 if enabled else 0.0)
		_winter_cover.visible = enabled or snow_weight > 0.001
		var surface: ShaderMaterial = _winter_cover.get_child(0).material_override
		surface.set_shader_parameter("snow_cover", snow_weight)
		surface.set_shader_parameter("exposed_ground", _season_palette.get("grass", GRASS))
	for roof in _winter_roofs: roof.visible = enabled


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


func _winter_jetty() -> void:
	var jetty := _root("FrosthollowJetty",Vector3(22.0,0.0,10.0))
	for i in range(19):
		_box(jetty,Vector3(float(i)*0.42-1.0,0.21,0.0),Vector3(0.37,0.20,2.7),Color("ac9980"))
	for x in [-0.9,2.0,4.9,6.65]:
		for z in [-1.22,1.22]:
			_cylinder(jetty,Vector3(x,0.35,z),0.14,0.13,1.8,Color("8b7f70"),7)
			_sphere(jetty,Vector3(x,1.30,z),Vector3(0.22,0.10,0.22),Color("edf4f5"))
	_crate(jetty,Vector3(1.1,0.66,-0.75),true)
	_dock_label = _shop_label(jetty, "Pier", Vector3(0.0,2.35,0.0))


func _toolsmith(parent: Node3D, pos: Vector3) -> void:
	var smith := NpcAvatar.new()
	parent.add_child(smith)
	smith.configure("bram")
	_npc_actors["bram"] = smith
	_staff_by_station["tools"] = smith
	smith.name = "PotatoToolsmith"
	smith.position = pos
	smith.rotation.y = deg_to_rad(55 if current_island == 3 else -55)
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
	_shop_label(shop, "Tools", Vector3(0, 3.95, 0))
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
	_toolsmith(forge, Vector3(-1.1, 0.0, 2.1))
	_target(forge,Vector3(0.0,1.95,0.4),Vector3(4.6,4.0,4.5),"station","tools")


func _animate_winter(delta: float) -> void:
	if current_island != 3 and not _winter_visible:
		return
	for i in range(_snowflakes.size()):
		var snowflake: Node3D = _snowflakes[i]
		snowflake.position.y -= delta*(0.26+float(i%3)*0.08)
		snowflake.position.x += delta*sin(_time*0.6+float(i))*0.045
		if snowflake.position.y < 0.35:
			snowflake.position.y = 8.0
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
		warning.text = "! PESTS\n%d sacks remain" % Climate.Protection.remaining(data) if int(data.get("weather_lost", 0)) > 0 else "! PESTS\nYIELD %d/3" % maxi(0, 3 - ticks)
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
	_duck_label = _shop_label(coop, "Ducks", Vector3(0, 2.5, 0))
	_target(coop, Vector3(0, 0.8, 0.1), Vector3(3.3, 2.5, 3.5), "station", "duck_patrol")
	for index in range(2):
		var duck: Node3D = _root("PestPatrolDuck%d" % (index + 1), _duck_home + Vector3((index - 0.5) * 1.0, 0.12, 1.6))
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
	_duck_body = _duck_bodies[0]

func _activity_station() -> void:
	_duck_station()

func set_activity_state(info: Dictionary) -> void:
	_activity_info = info.duplicate(true)
	if is_instance_valid(_duck_label):
		_duck_label.text = "Ducks · %d/2" % int(info.get("duck_count", 0))

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


func _buyer_board() -> void:
	# Reuse the Golden Shores buyer board on the Valley farm.
	var booth: Node3D = _root("BuyerContracts", Vector3(8, 0, -9))
	for x: float in [-1.25, 1.25]:
		_box(booth, Vector3(x, 1.4, 0), Vector3(0.14, 2.8, 0.14), Color("826342"))
	_box(booth, Vector3(0, 1.72, 0), Vector3(2.75, 1.75, 0.17), Color("87654b"))
	for x: float in [-0.65, 0.65]:
		_box(booth, Vector3(x, 1.76, 0.105), Vector3(1.03, 1.22, 0.055), Color("ffebbe"))
		for y: float in [1.5, 1.7, 1.9]: _box(booth, Vector3(x, y, 0.14), Vector3(0.67, 0.04, 0.02), Color("bfaf7e"))
	_roof(booth, 3.4, 1.55, 2.7, 0.5, Color("d19c54"))
	_shop_label(booth, "Contracts", Vector3(0, 3.6, 0))
	_target(booth, Vector3(0, 1.35, 0.4), Vector3(3.7, 3.2, 2.4), "station", "contracts")

func set_protection_work(info: Dictionary) -> void:
	var pending: Dictionary = info.get("pending", {})
	for id in _work_nodes.keys():
		if not pending.has(id) or pending[id] != _work_progress.get(id):
			_retire_climate_node(_work_nodes[id]); _work_nodes.erase(id)
	for id in pending:
		if not _work_nodes.has(id):
			_work_nodes[id] = ClimateProjects.work_site(self, id, int(pending[id]))
			_geometry_batcher.batch_tree(_work_nodes[id], {})
	_work_progress = pending.duplicate()
	var covers: Dictionary = info.get("covers", {})
	for key in _cover_nodes.keys():
		if not covers.has(key):
			_retire_climate_node(_cover_nodes[key]); _cover_nodes.erase(key)
	for key in covers:
		if not _cover_nodes.has(key):
			_cover_nodes[key] = ClimateProjects.bed_cover(self, int(key))
			_geometry_batcher.batch_tree(_cover_nodes[key], {})

func _retire_climate_node(node: Node3D) -> void:
	for body in node.find_children("*", "StaticBody3D", true, false): _interaction_targets.erase(body)
	for station in _tutorial_station_roots.keys():
		_tutorial_station_roots[station].erase(node)
		if _tutorial_station_roots[station].is_empty(): _tutorial_station_roots.erase(station)
	remove_child(node)
	node.queue_free()

## Calendar presentation is deterministic; only the one-second blend uses real time.
static func season_tints(year: int, season: int, hint: String = "") -> Dictionary:
	var age: float = clampf((year - 1) / 9.0, 0, 1)
	var grass: Color = [Color("8daa68"), Color("adab65"), Color("b8995b"), Color("ccd7cd")][season]
	if season == 1: grass = grass.lerp(Color("c4a16d"), age * 0.85)
	if hint == "drought": grass = grass.lerp(Color("c5ad7c"), 0.42)
	return {"grass": grass, "canopy": [Color("86a96b"), Color("789457"), Color("bb713f"), Color("727e65")][season],
		"blossom": 1.0 if season == 0 else 0.0, "flower": 1.0 if season == 0 else 0.0, "leaf": 1.0 if season == 2 else 0.0,
		"snow": 1.0 if season == 3 else 0.0, "haze": (0.06 + age * 0.32) if season == 1 else 0.0}

func _season_mesh(mesh: MeshInstance3D, kind: String) -> void:
	for entry in _season_materials:
		if entry.kind == kind and entry.base == mesh.material_override.albedo_color:
			mesh.material_override = entry.material
			return
	var material: StandardMaterial3D = mesh.material_override.duplicate()
	mesh.material_override = material
	material.set_meta("season_tint", true)
	if kind in ["blossom", "flower", "leaf"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_season_materials.append({"material": material, "kind": kind, "base": material.albedo_color})

func _season_verges() -> void:
	var flowers := _root("SpringFlowers", Vector3.ZERO)
	var leaves := _root("AutumnLeaves", Vector3.ZERO)
	for i in range(36):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(-16.0 + (i / 2) * 1.85, 0.12, side * 10.8)
		_season_mesh(_sphere(flowers, pos, Vector3(0.13, 0.16, 0.13), Color("edd998") if i % 3 == 0 else Color("f2c5d2")), "flower")
		var leaf := _sphere(leaves, Vector3(pos.x, 0.22, side * 8.6 + sin(i) * 0.7), Vector3(0.30, 0.025, 0.16), Color("ba693b") if i % 2 == 0 else Color("8e6241"))
		leaf.rotation.y = i * 1.3
		_season_mesh(leaf, "leaf")

func set_calendar(year: int, season: int, seconds: float, hint: String = "") -> void:
	var key: String = "%d/%d/%s" % [year, season, hint]
	if key != _season_key:
		var first: bool = _season_key.is_empty()
		_season_from = season_tints(year, season, hint) if first else _season_palette.duplicate()
		if is_instance_valid(_sun) and _day_environment != null:
			_season_light = {"sky": _day_environment.background_color, "ambient": _day_environment.ambient_light_color, "sun": _sun.light_color, "energy": _sun.light_energy, "rotation": _sun.rotation_degrees}
		_season_key = key
		_season_year = year; _season_index = season; _season_signal = hint
		_season_blend = 1.0 if first else 0.0
		_apply_season()
		_applied_day_time = -1.0
	set_day_time(seconds, season == 3)

func _process(delta: float) -> void:
	if _season_blend >= 1.0: return
	_season_blend = minf(1.0, _season_blend + delta)
	_apply_season()
	_applied_day_time = -1.0
	set_day_time(_day_elapsed, _season_index == 3)

func _apply_season() -> void:
	var target: Dictionary = season_tints(_season_year, _season_index, _season_signal)
	for key in target:
		_season_palette[key] = _season_from.get(key, target[key]).lerp(target[key], _season_blend) if target[key] is Color else lerpf(float(_season_from.get(key, target[key])), float(target[key]), _season_blend)
	for entry in _season_materials:
		if entry.kind == "grass": entry.material.albedo_color = _season_palette.grass
		elif entry.kind == "canopy":
			entry.material.albedo_color = _season_palette.canopy.darkened(clampf((0.68 - entry.base.g) * 1.8, 0, 0.24))
		else:
			var color: Color = entry.base
			color.a = _season_palette[entry.kind]
			entry.material.albedo_color = color

func draw_season_signals(v, time: float) -> void:
	var haze: float = float(_season_palette.get("haze", 0)) + (_weather_strength * 0.20 if _weather_drought else 0.0)
	if haze > 0:
		for band in range(5):
			for j in range(15):
				var x: float = plot_positions[0].x + j * 0.8
				var z: float = plot_positions[0].z + band * 1.6
				v._line(Vector3(x, 0.75 + sin(time * 2.1 + j + band) * 0.08, z), Vector3(x + 0.8, 0.75 + sin(time * 2.1 + j + 1 + band) * 0.08, z), 0.08, Color(1.0, 0.86, 0.62, haze * 0.18), true)
	if _season_signal == "flood" and fposmod(time, 8.0) < 5.0:
		for i in range(48):
			var p := Vector3(plot_positions[0].x + fposmod(i * 1.71, 13), 0.3 + fposmod(i * 0.41 - time * 4, 4.5), plot_positions[0].z + fposmod(i * 1.33, 8))
			v._line(p, p + Vector3(-0.04, -0.38, 0), 0.022, Color(0.74, 0.88, 0.94, 0.48), true)
	if _season_signal == "storm":
		for i in range(7):
			var x: float = plot_positions[0].x - 3 + fposmod(time * 4 + i * 2.8, 19)
			for j in range(8):
				var p := Vector3(x + j * 0.3, 1.4 + sin(time + j * 0.3) * 0.16, plot_positions[0].z + i * 1.2)
				v._line(p, p + Vector3(0.31, cos(time + j * 0.3) * 0.04, 0), 0.025, Color(0.9, 0.9, 0.78, 0.4), true)

var grade_tag: Label3D
func show_grade(index: int, plot: Dictionary) -> void:
	if not is_instance_valid(grade_tag):
		grade_tag = Label3D.new()
		grade_tag.name = "BedGrade"
		grade_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		grade_tag.font_size = 28
		grade_tag.pixel_size = 0.019
		grade_tag.no_depth_test = true
		grade_tag.modulate = CREAM
		add_child(grade_tag)
	grade_tag.visible = index >= 0 and int(plot.get("stage", 0)) > 0
	if grade_tag.visible:
		grade_tag.text = "Grade: " + preload("res://scripts/crop_quality.gd").grade(int(plot.quality))
		grade_tag.position = plot_positions[index] + Vector3(0, 1.9, 0)
