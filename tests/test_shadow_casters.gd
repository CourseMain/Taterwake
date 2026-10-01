extends SceneTree
## Caster roles survive compilation, animation and graphics-quality switches.
const World = preload("res://scripts/farm_world.gd")
const Compiler = preload("res://scripts/static_mesh_compiler.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func all_casting(node: Node, mode: int) -> bool:
	var geometry: Array[Node] = node.find_children("*", "GeometryInstance3D", true, false)
	if geometry.is_empty(): return false
	for mesh: GeometryInstance3D in geometry:
		if mesh.cast_shadow != mode: return false
	return true

func direct_caster(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is GeometryInstance3D and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			return true
	return false

func mixed_compilation() -> void:
	var compiler := Compiler.new()
	var source := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.set_meta("static_colour", true)
	var cached: Dictionary = {}
	for iteration in range(2):
		var fixture := Node3D.new()
		root.add_child(fixture)
		for index in range(4):
			var mesh := MeshInstance3D.new()
			mesh.mesh = source
			mesh.material_override = material
			mesh.position.x = index
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if index < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fixture.add_child(mesh)
		compiler.merge_siblings(fixture, {})
		check(fixture.get_child_count() == 2, "opaque casters and non-casters compile into separate groups")
		var groups: Dictionary = {}
		for mesh: MeshInstance3D in fixture.get_children():
			groups[mesh.cast_shadow] = mesh.mesh
		check(groups.has(GeometryInstance3D.SHADOW_CASTING_SETTING_ON) and groups.has(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "both casting flags survive compilation")
		if iteration == 0:
			cached = groups
		else:
			for mode: int in groups:
				check(groups[mode] == cached[mode], "cache reuses geometry without crossing casting groups")
		fixture.free()

func run() -> void:
	mixed_compilation()
	var world := World.new()
	root.add_child(world)
	world.build_world()
	world.set_climate_projects({})
	var mill: Node3D = world.get_node("Windmill")
	var blades: Array[Node3D] = []
	for child: Node in world._rotor.get_children():
		if child is Node3D and not child is GeometryInstance3D:
			blades.append(child)
	check(blades.size() == 4, "four sail roots remain independently animated")
	for quality in ["balanced", "crisp", "smooth"]:
		world.set_graphics_quality(quality)
		var sails_off := true
		for blade: Node3D in blades:
			sails_off = sails_off and all_casting(blade, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		check(sails_off, quality + " keeps all compiled sail pieces from casting")
		check(direct_caster(mill) and direct_caster(world._rotor), quality + " retains tower and hub casters")
		check(all_casting(world.weather_station.dish, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), quality + " keeps all moving dish pieces from casting")
		check(direct_caster(world.weather_station), quality + " retains station body casters")
		check(direct_caster(world._project_nodes.rainwater), quality + " retains the tank body caster")
	var rotor_before: float = world._rotor.rotation.z
	var dish_before: float = world.weather_station.dish.rotation.y
	world.animate(0.5, false)
	world.weather_station._process(0.5)
	check(not is_equal_approx(world._rotor.rotation.z, rotor_before), "sails still turn with shadows disabled")
	check(not is_equal_approx(world.weather_station.dish.rotation.y, dish_before), "dish still scans with shadows disabled")
	world.queue_free()
	await process_frame
	print("SHADOW CASTERS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
