extends RefCounted
## Deliberately placed, reusable village props. All geometry shares the farm's
## earthy materials and low-poly silhouettes and is compiled with its parent.
const WOOD := Color("a6794b")
const PALE_WOOD := Color("cfaa72")
const INK := Color("66513e")

static func group(parent: Node3D, title: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = title
	root.position = at
	parent.add_child(root)
	return root

static func produce_crate(world, parent: Node3D, at: Vector3, full: bool, variant: int = 0) -> Node3D:
	var crate := group(parent, "ProduceCrate", at)
	crate.rotation.y = -.055 if variant % 2 else .035
	var timber: Color = [WOOD, Color("779181"), Color("b59b75")][variant % 3]
	world._box(crate, Vector3(0, .09, 0), Vector3(1.25, .16, .92), timber.darkened(.16))
	for x in [-.56, .56]:
		world._box(crate, Vector3(x, .35, 0), Vector3(.11, .65, .96), timber)
	for z in [-.46, .46]:
		for row in range(3):
			var slat = world._box(crate, Vector3(0, .18 + row * .18, z), Vector3(1.28, .125, .065), PALE_WOOD if row == variant % 3 else timber)
			if row == 1 and variant % 2: slat.rotation.z = .035
	# One pale replacement board and its dark nailheads tell the repair story.
	world._bar(crate, Vector3(-.45, .14, .505), Vector3(.38, .57, .505), .035, PALE_WOOD)
	for corner in [Vector3(-.45, .14, .54), Vector3(.38, .57, .54)]:
		world._sphere(crate, corner, Vector3.ONE * .025, INK)
	if full:
		for i in range(5):
			world._sphere(crate, Vector3(-.37 + (i % 3) * .37, .61 + (i % 2) * .055, -.15 + (i / 3) * .31), Vector3(.25, .19, .22), Color("d7aa69"))
	return crate

static func repaired_sack(world, parent: Node3D, at: Vector3, lean: float) -> Node3D:
	var sack := group(parent, "RepairedSeedSack", at)
	sack.rotation.z = lean
	world._sphere(sack, Vector3(0, .53, 0), Vector3(.50, .57, .40), Color("bca078"))
	world._sphere(sack, Vector3(0, .91, 0), Vector3(.31, .22, .29), Color("cdb187"))
	world._cylinder(sack, Vector3(0, 1.04, 0), .20, .15, .22, Color("96794f"), 7)
	world._cylinder(sack, Vector3(0, 1.00, 0), .22, .22, .065, INK, 7)
	var patch = world._box(sack, Vector3(.10, .51, .379), Vector3(.40, .37, .035), Color("769078"))
	patch.rotation.z = -.16
	for side in [-1.0, 1.0]:
		for i in range(3):
			world._bar(sack, Vector3(.10 + side * .20, .36 + i * .12, .406), Vector3(.10 + side * .15, .38 + i * .12, .410), .014, Color("a5cfd4"))
	return sack

static func mara_stall(world, stall: Node3D) -> void:
	var details := group(stall, "MaraRepairs", Vector3.ZERO)
	# Her seed supply is tucked against the counter, clear of the front approach.
	repaired_sack(world, details, Vector3(-3.02, .05, 1.30), -.12)
	var spare := repaired_sack(world, details, Vector3(-3.12, .05, .24), .10)
	spare.scale = Vector3.ONE * .83
	produce_crate(world, details, Vector3(2.92, .21, .82), true, 1)
	var returned := produce_crate(world, details, Vector3(3.00, .92, .77), false, 2)
	returned.rotation.y = -.14
	# The missing front foot is exactly the potato Mara refuses to discuss.
	var feet := group(details, "QuestionableCrateRepair", Vector3(2.92, 0, .82))
	for corner in [Vector3(-.50,.11,-.34), Vector3(.50,.11,-.34), Vector3(-.50,.11,.34)]:
		world._box(feet, corner, Vector3(.16,.22,.17), Color("806343"))
	world._sphere(feet, Vector3(.50,.12,.34), Vector3(.20,.13,.17), Color("d7aa69"))
	world._sphere(feet, Vector3(.57,.15,.46), Vector3(.025,.020,.014), INK)
	world._sphere(feet, Vector3(.44,.12,.48), Vector3(.020,.015,.013), INK)
	# A short leaning boundary protects the crates, not the walkable doorway.
	var fence := group(details, "CrookedCrateFence", Vector3(3.78, 0, -.30))
	for i in range(3):
		var post = world._box(fence, Vector3(0, .51, -.85 + i * .8), Vector3(.14, 1.03, .15), PALE_WOOD)
		post.rotation.z = [-.12, .08, -.05][i]
	for y in [.37, .72]:
		world._bar(fence, Vector3(-.06, y, -.86), Vector3(.08, y - .10, .79), .045, Color("ac9064"))
	world._bar(fence, Vector3(.12, .16, -.45), Vector3(.12, .78, .40), .047, Color("806343"))
	# One mended awning stripe and a proud hand-painted name, rather than clutter.
	var patch = world._box(details, Vector3(-1.65, 3.015, .233), Vector3(.43, .26, .025), Color("769078"))
	patch.rotation.z = -.09
	for x in [-1.82, -1.48]:
		world._box(details, Vector3(x, 3.015, .25), Vector3(.023, .22, .025), Color("ecdbac"))
	var nameboard := group(details, "MaraNameboard", Vector3(-.20, .51, 1.972))
	nameboard.rotation.z = -.035
	world._box(nameboard, Vector3.ZERO, Vector3(1.75, .39, .065), Color("769078"))
	var name_label: Label3D = world._label(nameboard, "MARA'S", Vector3(0, 0, .04), 26, Color("f7e4b6"), false)
	name_label.pixel_size = .013
