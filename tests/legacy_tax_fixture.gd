extends RefCounted
## Construct the collection state a pre-redesign save could contain.
## Current gameplay cannot create these retired market events.
static func set_count(farm, count: int) -> void:
	farm.blind_cycle.booms = count
	farm.blind_cycle.tax_rolled = true
	farm.blind_cycle.due_in = farm.BlindRules.COLLECTION_SECONDS if count == 3 else 0.0
