extends RefCounted
## Four real-time seasons; the tenth Winter ends the run.
const SEASON_SECONDS: float = 150.0
const LAST_YEAR: int = 10
const NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
var year: int = 1
var season: int = 0
var seconds: float = 0.0
var autumn_loss: int = 0

func finished() -> bool:
	return year == LAST_YEAR and season == 3 and seconds == SEASON_SECONDS

func remaining(duration: float = SEASON_SECONDS) -> float:
	return duration - seconds

func can_plant() -> bool:
	return season < 2

func advance(delta: float, duration: float = SEASON_SECONDS) -> bool:
	if finished() or not is_finite(delta) or delta <= 0: return false
	seconds = minf(duration, seconds + delta)
	if seconds < duration - 0.000001: return false
	seconds = duration
	if finished(): return true
	seconds = 0.0
	season = (season + 1) % 4
	if season == 0: year += 1; autumn_loss = 0
	return true

func save_data() -> Dictionary:
	return {"year": year, "season": season, "seconds": seconds, "autumn_loss": autumn_loss}

func load_data(raw: Dictionary) -> void:
	year = int(raw.year)
	season = int(raw.season)
	seconds = float(raw.seconds)
	autumn_loss = int(raw.autumn_loss)

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.has("winter_menu"): return false
	var rules = preload("res://scripts/save_validation.gd")
	if not rules.number(raw.get("year"), 1, LAST_YEAR, true) or not rules.number(raw.get("season"), 0, 3, true): return false
	if not rules.number(raw.get("seconds"), 0, SEASON_SECONDS): return false
	if float(raw.seconds) == SEASON_SECONDS and not (int(raw.year) == LAST_YEAR and int(raw.season) == 3): return false
	if not rules.number(raw.get("autumn_loss"), 0, 24, true): return false
	return int(raw.season) == 3 or int(raw.autumn_loss) == 0
