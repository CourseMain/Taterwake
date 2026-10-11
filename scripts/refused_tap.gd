extends RefCounted
## Cause and remedy share the caption; the instruction stays untouched.
static func caption(message: String) -> String:
	var text := message.to_lower()
	var rules: Array = [
		["can empty", "Can empty. Fill it at the tank."],
		["frozen", "Frozen beds. Clear the ice with Hoe."],
		["sprayer empty", "Sprayer empty. Wait for fresh supplies."],
		["no pests", "No pests. Spray an infested bed."],
		["barn full", "Barn full. Sell crops at Mara's stall."],
		["nothing to harvest", "Nothing grown. Plant a seed first."],
		["still growing", "Still growing. Wait before harvesting."],
		["water this", "Crop dry. Water it before harvesting."],
		["seeds", "No seeds. Buy them at Mara's stall."],
		["already planted", "Already planted. Choose an empty bed."],
		["till the soil", "Soil bare. Hoe it before planting."],
		["plant a seed", "Soil bare. Plant a seed here."],
		["ready to harvest", "Crop ripe. Use Harvest on this bed."],
		["already watered", "Already wet. Water a dry bed."],
		["soil ready", "Already tilled. Plant a seed here."],
		["spudions", "Too little cash. Reduce the purchase."],
		["tank water", "Tank empty. Wait for rain to refill."],
		["can is full", "Can full. Water a dry bed."],
		["tonnes", "Too little stock. Reduce the quantity."],
		["whole number", "Invalid amount. Enter a whole number."],
		["autumn", "Autumn planting. Choose Icecap seeds."],
		["spring", "Planting closed. Wait for Spring."],
		["run over", "Run over. Start a new farm."],
		["guided", "Not yet. Follow the guided step."],
		["glowing", "Wrong bed. Use the glowing practice bed."],
		["collected", "Already collected. Choose another quest."],
	]
	for rule in rules:
		if text.contains(rule[0]): return rule[1]
	return "Unavailable now. Follow the instruction."

static func shake(control: Control) -> void:
	if not is_instance_valid(control): return
	var previous = control.get_meta("refusal_tween") if control.has_meta("refusal_tween") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	control.rotation = 0
	control.pivot_offset = control.size * .5
	var tween := control.create_tween()
	control.set_meta("refusal_tween", tween)
	control.set_meta("refusal_duration_ms", 200)
	for angle: float in [.025, -.025, .025, -.025, 0.0]:
		tween.tween_property(control, "rotation", angle, .04)
