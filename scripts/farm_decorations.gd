extends RefCounted
const ITEMS := {"bench": "Bench", "flowers": "Flower border", "scarecrow": "Scarecrow", "barn_door": "Painted barn door", "duck_house": "Duck house", "gate_flag": "Flag on the gate"}
const FIXED_PLACES := {"barn_door": 2, "duck_house": 1, "gate_flag": 0}
static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() > ITEMS.size(): return false
	for id in raw:
		if id not in ITEMS or not (raw[id] is float or raw[id] is int) or float(raw[id]) != floorf(float(raw[id])) or int(raw[id]) < 0 or int(raw[id]) > 2: return false
	return true
static func build(world, kept: Dictionary) -> Node3D:
	var root := Node3D.new(); root.name = "KeptDecorations"; world.add_child(root)
	# All three sites are outside beds and service approaches. Props have no collision.
	var sites: Array[Vector3] = [Vector3(-10.8, 0, 10.5), Vector3(-22.7, 0, 6.2), Vector3(15.5, 0, -12)]
	for id in ITEMS:
		if not kept.has(id): continue
		var item := Node3D.new(); item.name = "Decoration_" + id; root.add_child(item)
		var index: int = ITEMS.keys().find(id)
		var place: int = FIXED_PLACES.get(id, int(kept[id]))
		item.position = world.layout_point(sites[place] + Vector3(index % 3 * 1.9, 0, index / 3 * 1.8))
		item.position.y = world.ground_height(item.position.x, item.position.z)
		match id:
			"bench":
				world._box(item, Vector3(0, .65, 0), Vector3(1.7, .16, .7), Color("ad8158"))
				world._box(item, Vector3(0, 1.1, -.28), Vector3(1.7, .65, .12), Color("b99063"))
				for x in [-.6, .6]: world._box(item, Vector3(x, .3, 0), Vector3(.13, .6, .55), Color("775a41"))
			"flowers":
				for x in range(7):
					var p := Vector3(x * .28 - .84, .32, 0)
					world._bar(item, p - Vector3(0, .32, 0), p, .025, Color("6b8d5c"))
					for petal in range(5): world._sphere(item, p + Vector3(cos(petal * TAU / 5) * .08, .02, sin(petal * TAU / 5) * .08), Vector3(.10, .04, .10), Color("f1c6cb"))
			"scarecrow":
				world._bar(item, Vector3.ZERO, Vector3(0, 1.6, 0), .07, Color("927048"))
				world._bar(item, Vector3(-.7, 1.1, 0), Vector3(.7, 1.1, 0), .08, Color("927048"))
				world._sphere(item, Vector3(0, 1.3, 0), Vector3(.34, .4, .24), Color("99ad7f"))
				world._sphere(item, Vector3(0, 1.85, 0), Vector3(.31, .34, .29), Color("e4c89c"))
				world._cylinder(item, Vector3(0, 2.05, 0), .44, .44, .08, Color("b79859"))
			"barn_door":
				var barn = world.get_node("RedBarn")
				item.global_position = barn.to_global(Vector3(0, .95, 2.48))
				world._box(item, Vector3.ZERO, Vector3(1.45, 1.85, .07), Color("769b91"))
				world._bar(item, Vector3(-.62, -.8, .05), Vector3(.62, .8, .05), .05, Color("e8d7b5"))
			"duck_house":
				world._box(item, Vector3(0, .45, 0), Vector3(1.15, .9, .95), Color("aa875b"))
				world._roof(item, 1.4, 1.1, .9, .35, Color("6a8983"))
				world._box(item, Vector3(0, .27, .49), Vector3(.42, .54, .03), Color("514538"))
			"gate_flag":
				world._bar(item, Vector3.ZERO, Vector3(0, 2.3, 0), .06, Color("b29667"))
				world._box(item, Vector3(.34, 1.95, 0), Vector3(.68, .46, .025), Color("d29a77"))
	return root
