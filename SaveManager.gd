## SaveManager.gd — Autoload
## Serialises GameState to disk and restores it, including offline simulation.
##
## Version history:
##   1 — initial
##   2 — added discovered_species, time_of_day
##   3 — removed apex_energy; mutagens as BigNumber dict
##   4 — added current_day, current_season, starvation_counters, unlocked_traits
##   5 — added sun_energy (was accidentally reset to 50 on every load)
extends Node

const SAVE_PATH          := "user://save.json"
const SAVE_VERSION       := 5
const AUTO_SAVE_INTERVAL := 30.0

var _auto_save_timer: float = 0.0


func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save()


# ── Public API ─────────────────────────────────────────────────────────────────

func save() -> void:
	var gs  := GameState
	var data := {
		"version":               SAVE_VERSION,
		"timestamp":             Time.get_unix_time_from_system(),
		"biomass":               gs.biomass.to_save_dict(),
		"sun_energy":            gs.sun_energy.to_save_dict(),
		"dna":                   gs.dna.to_save_dict(),
		"mutagens":              gs.mutagens.to_save_dict(),
		"click_power":           gs.click_power.to_save_dict(),
		"populations":           gs.populations.duplicate(),
		"permanent_multipliers": gs.permanent_multipliers.duplicate(),
		"highest_tier_reached":  gs.highest_tier_reached,
		"run_start_time":        gs.run_start_time,
		"discovered_species":    gs.discovered_species.duplicate(),
		"unlocked_traits":       gs.unlocked_traits.duplicate(),
		"time_of_day":           gs.time_of_day,
		"current_day":           gs.current_day,
		"current_season":        gs.current_season,
		"starvation_counters":   gs._starvation_counters.duplicate(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("SaveManager: could not write to " + SAVE_PATH)


## Returns true if a save file was found and loaded successfully.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: save file is corrupted")
		return false

	var d:  Dictionary = parsed
	var gs := GameState

	gs.biomass     = BigNumber.from_save_dict(d.get("biomass",     {"m": 10.0, "e": 0}))
	gs.sun_energy  = BigNumber.from_save_dict(d.get("sun_energy",  {"m": 50.0, "e": 0}))
	gs.dna         = BigNumber.from_save_dict(d.get("dna",         {"m": 0.0,  "e": 0}))
	gs.click_power = BigNumber.from_save_dict(d.get("click_power", {"m": 1.0,  "e": 0}))

	# Mutagens: v2/v3 saves may be int/float; v3+ is a BigNumber dict.
	var raw_mut = d.get("mutagens", {"m": 0.0, "e": 0})
	if raw_mut is int or raw_mut is float:
		gs.mutagens = BigNumber.from_float(float(raw_mut))
	elif raw_mut is Dictionary:
		gs.mutagens = BigNumber.from_save_dict(raw_mut)
	else:
		gs.mutagens = BigNumber.zero()

	gs.populations          = d.get("populations", {})
	gs.highest_tier_reached = d.get("highest_tier_reached", 0)
	gs.run_start_time       = d.get("run_start_time", Time.get_unix_time_from_system())
	gs.time_of_day          = float(d.get("time_of_day", 8.0))
	gs.is_day               = gs.time_of_day >= 6.0 and gs.time_of_day < 18.0
	gs.daylight_factor      = gs._compute_daylight_factor(gs.time_of_day)
	gs.current_day          = int(d.get("current_day",    0))
	gs.current_season       = int(d.get("current_season", GameState.Season.SPRING))

	# Restore starvation counters so predators don't recover for free on load.
	var saved_starve: Dictionary = d.get("starvation_counters", {})
	for key: String in saved_starve:
		gs._starvation_counters[key] = float(saved_starve[key])

	# Restore cross-run discoveries.
	var saved_disc: Dictionary = d.get("discovered_species", {})
	for key: String in saved_disc:
		gs.discovered_species[key] = bool(saved_disc[key])

	# Restore unlocked genetic traits.
	var saved_traits = d.get("unlocked_traits", [])
	if saved_traits is Array:
		for trait_id in saved_traits:
			if not (trait_id in gs.unlocked_traits):
				gs.unlocked_traits.append(str(trait_id))

	# Restore permanent multipliers (ignore keys not present in current schema).
	var saved_mult: Dictionary = d.get("permanent_multipliers", {})
	for key: String in saved_mult:
		if gs.permanent_multipliers.has(key):
			gs.permanent_multipliers[key] = float(saved_mult[key])

	# Offline simulation intentionally disabled — the game only simulates while open.
	# The timestamp key is kept in the save file for potential future use.

	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
