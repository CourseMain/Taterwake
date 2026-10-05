extends RefCounted
const HATS := ["seasonal", "straw", "none"]
const SHIRTS := ["719798", "a86f62", "6c875b", "b99b50"]
const SKINS := ["f0cc9d", "dca86d", "b9825c", "78533b"]
static func fresh() -> Dictionary:
	return {"name": "Farmer", "hat": "seasonal", "shirt": "719798", "skin": "dca86d", "chosen": false}
static func valid(raw: Variant) -> bool:
	return raw is Dictionary and raw.get("name") is String and raw.name.length() > 0 and raw.name.length() <= 20 and raw.name == raw.name.strip_edges() and not raw.name.contains("\n") and raw.get("hat") in HATS and raw.get("shirt") in SHIRTS and raw.get("skin") in SKINS and raw.get("chosen") is bool
