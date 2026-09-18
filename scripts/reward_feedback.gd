extends RefCounted
## One shared threshold for reel flashes, screen effects and celebration audio.
const CELEBRATION_TIERS: Array[String] = ["epic", "legendary", "mythic", "jackpot", "relic", "mystery"]

static func celebrates(tier: String) -> bool:
	return tier.to_lower() in CELEBRATION_TIERS
