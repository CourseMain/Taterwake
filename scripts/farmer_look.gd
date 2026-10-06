extends RefCounted
const HATS := ["seasonal", "straw", "none", "flower", "scarf", "glasses"]
const SHIRTS := ["5f9fd6", "b5523c", "6f9a4a", "d9a948", "719798", "a86f62", "6c875b", "b99b50"]
const SKINS := ["f5d9b8", "dbab78", "b57a4a", "7a4a2a", "f0cc9d", "dca86d", "b9825c", "78533b"]
static func fresh() -> Dictionary:
	return {"name": "Farmer", "hat": "straw", "shirt": "5f9fd6", "skin": "dbab78", "chosen": false}
static func valid(raw: Variant) -> bool:
	return raw is Dictionary and raw.get("name") is String and raw.name.length() > 0 and raw.name.length() <= 20 and raw.name == raw.name.strip_edges() and not raw.name.contains("\n") and raw.get("hat") in HATS and raw.get("shirt") in SHIRTS and raw.get("skin") in SKINS and raw.get("chosen") is bool

static func choices(farm, field: String) -> Array:
	if field == "hat":
		var result: Array = ["straw", "flower", "scarf", "none"]
		if "glasses" in farm.clothing_unlocked: result.insert(3, "glasses")
		if farm.farmer_appearance.hat == "seasonal": result.append("seasonal")
		return result
	var result: Array = (SHIRTS if field == "shirt" else SKINS).slice(0, 4)
	if farm.farmer_appearance[field] not in result: result.append(farm.farmer_appearance[field])
	return result
