extends RefCounted
## Three working seasons, then a player-controlled Winter. No wall-clock progress.
const SEASON_SECONDS: float = 150.0
const LAST_YEAR: int = 10
const NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
var year: int = 1
var season: int = 0
var seconds: float = 0.0
var winter_menu: bool = false
var autumn_loss: int = 0

func remaining() -> float:
	return 0.0 if winter_menu else SEASON_SECONDS - seconds

func can_plant() -> bool:
	return season < 2 and not winter_menu

func advance(delta: float) -> bool:
	if winter_menu or not is_finite(delta) or delta <= 0: return false
	seconds = minf(SEASON_SECONDS, seconds + delta)
	if seconds < SEASON_SECONDS - 0.000001: return false
	season += 1
	seconds = 0.0
	winter_menu = season == 3
	return true

func start_next_year() -> bool:
	if not winter_menu or year >= LAST_YEAR: return false
	year += 1
	season = 0
	seconds = 0.0
	winter_menu = false
	autumn_loss = 0
	return true

func save_data() -> Dictionary:
	return {"year": year, "season": season, "seconds": seconds, "winter_menu": winter_menu, "autumn_loss": autumn_loss}

func load_data(raw: Dictionary) -> void:
	year = int(raw.year)
	season = int(raw.season)
	seconds = float(raw.seconds)
	winter_menu = raw.winter_menu
	autumn_loss = int(raw.autumn_loss)

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	var rules = preload("res://scripts/save_validation.gd")
	if not rules.number(raw.get("year"), 1, LAST_YEAR, true) or not rules.number(raw.get("season"), 0, 3, true): return false
	if not rules.number(raw.get("seconds"), 0, SEASON_SECONDS) or float(raw.seconds) >= SEASON_SECONDS: return false
	if not raw.get("winter_menu") is bool or raw.winter_menu != (int(raw.season) == 3): return false
	if raw.winter_menu and float(raw.seconds) != 0: return false
	if not rules.number(raw.get("autumn_loss"), 0, 24, true): return false
	return raw.winter_menu or int(raw.autumn_loss) == 0
