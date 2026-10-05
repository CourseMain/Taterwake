extends SceneTree
## Standalone graphical settings fixture. Never instantiates save-owning state.
const World = preload("res://scripts/farm_world.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var world := World.new()
	root.add_child(world)
	world.set_graphics_quality("smooth")
	world.set_day_time(75.0)
	for island in [1]:
		world.build_world()
		check(world.graphics_quality == "smooth" and not world._sun.shadow_enabled, "chosen quality survives island construction")
		check(is_equal_approx(world.day_cycle_info().seconds, 75.0), "graphics construction preserves elapsed daylight")
		var camera_id: int = world.camera.get_instance_id()
		var light_id: int = world._sun.get_instance_id()
		var node_count: int = world.find_children("*", "", true, false).size()
		var terrain: int = 0
		var contained: bool = true
		for geometry: Node in world.find_children("*", "GeometryInstance3D", true, false):
			if geometry.has_meta("terrain_shell"):
				terrain += 1
				check(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "large terrain shell receives light without casting polygon artifacts")
			if not geometry is MeshInstance3D and not geometry is MultiMeshInstance3D:
				continue
			var bounds: AABB = geometry.get_aabb()
			# Coastal water deliberately continues beyond the far plane to fill the horizon.
			if geometry == world.coast.water:
				var nearest := INF
				var farthest := -INF
				for index in range(8):
					var corner: Vector3 = world.camera.global_transform.affine_inverse() * (geometry.global_transform * bounds.get_endpoint(index))
					nearest = minf(nearest, -corner.z)
					farthest = maxf(farthest, -corner.z)
				check(nearest < world.camera.far and farthest > world.camera.near, "horizon water intersects the visible depth interval")
				continue
			for index: int in range(8):
				var point: Vector3 = world.camera.global_transform.affine_inverse() * (geometry.global_transform * bounds.get_endpoint(index))
				contained = contained and -point.z < world.camera.far
		check(terrain == 1 and contained, "one terrain shell and all farm geometry fit the camera depth")
		world.set_graphics_quality("balanced")
		check(world._sun.shadow_enabled and world._sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "balanced uses one orthographic shadow map")
		check(is_zero_approx(world._sun.directional_shadow_pancake_size) and is_equal_approx(world._sun.shadow_opacity, .85), "balanced removes shadow pancaking and keeps a defined silhouette")
		world.set_day_time(0.0)
		world._animate_sun(3.0); world._animate_sun(0.4)
		var rotation: Vector3 = world._sun.rotation
		var daylight: Color = world._day_environment.background_color
		world.set_day_time(75.0)
		world._animate_sun(3.0); world._animate_sun(0.4)
		check(not world._day_environment.background_color.is_equal_approx(daylight) and not world._sun.rotation.is_equal_approx(rotation), "seasonal light and direction advance toward noon")
		world.set_day_time(150.0)
		check(world._sun.light_energy >= .75 and world._moon.light_energy >= .18, "season-end dusk retains readable fill light")
		world.set_day_time(75.0)
		var plots: Array = []
		for index: int in range(world.plot_positions.size()):
			plots.append({"unlocked": true, "tilled": true, "watered": true, "stage": 3, "pests": index == 4})
		world.update_plots(plots)
		world.set_graphics_quality("smooth")
		world.animate(0.1, false)
		await physics_frame
		await physics_frame
		check(int(world.pick(world.camera.unproject_position(world.plot_positions[4])).get("plot_index", -1)) == 4, "smooth keeps infested beds selectable")
		check(world._pest_roots[4].visible and world._pest_labels[4].visible, "smooth keeps pest feedback visible")
		world.set_tutorial_focus("market")
		world.animate(0.1, false)
		check(world._tutorial_marker.visible, "smooth keeps tutorial market guidance visible")
		world.set_graphics_quality("invalid")
		check(world.graphics_quality == "balanced" and world._sun.shadow_enabled, "unknown setting safely falls back to balanced")
		check(world.camera.get_instance_id() == camera_id and world._sun.get_instance_id() == light_id, "switching modes reuses existing camera and lights")
		check(world.find_children("*", "", true, false).size() >= node_count, "mode changes do not remove gameplay scene nodes")
		world.set_graphics_quality("smooth")
	world.queue_free()
	await process_frame
	print("WORLD GRAPHICS QUALITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
