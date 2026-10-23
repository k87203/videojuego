extends Node
## Event-driven music policy. Sound retains mixing/SFX and backwards-compatible track().
var level := 1
var mode := "menu"
var difficulty := 0.0
var chase := false
var boss_phase := 0
var timed := false
var hold := 0.0
var current_priority := 0
var transitions: Array[String] = []
var action_energy := 0.0
var action_hold := 0.0
const TEMPOS := {"campus_1": 156.0, "campus_2": 160.0, "campus_3": 168.0, "campus_4": 164.0, "modern_menu": 152.0, "urgent_chase": 176.0, "epic_boss": 172.0, "epic_final": 180.0, "ceremony": 148.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	hold = maxf(0, hold - delta)
	action_hold = maxf(0, action_hold - delta)
	if action_hold <= 0: action_energy = move_toward(action_energy, 0, delta * 0.7)
	if hold <= 0: choose(false)

func menu() -> void:
	mode = "menu"
	action_energy = 0
	choose(true)

func ending() -> void:
	mode = "ending"
	choose(true)

func enter_level(id: int) -> void:
	Sound.warm_level(id)
	level = id
	mode = "level"
	boss_phase = 0
	chase = false
	timed = false
	difficulty = 0
	action_energy = 0
	action_hold = 0
	choose(true)

func action(energy: float, seconds: float = 2.0) -> void:
	if mode != "level": return
	action_energy = maxf(action_energy, energy)
	action_hold = maxf(action_hold, seconds)
	choose(false)

func bpm(track: String = "") -> float:
	var key := Sound.current_track if track == "" else track
	return float(TEMPOS.get(key.trim_suffix("_intense"), 160.0))

func beat_phase() -> float:
	if not is_instance_valid(Sound.music) or not Sound.music.playing: return 0
	return fposmod(Sound.music.get_playback_position() * bpm() / 60.0, 1.0)

func boss_started() -> void:
	mode = "level"
	boss_phase = 1
	choose(true)

func context(intensity: float, pursuit: bool, phase: int, trial: bool) -> void:
	if mode != "level": return
	difficulty = intensity
	chase = pursuit
	boss_phase = phase
	timed = trial
	choose(false)

func choose(force: bool) -> void:
	var desired := "modern_menu"
	var priority := 0
	if mode == "ending": desired = "ceremony"
	elif mode == "level":
		var intense := maxf(difficulty, action_energy) >= 0.58
		desired = "campus_%d%s" % [level, "_intense" if intense else ""]
		priority = 1 if intense else 0
		if chase or timed:
			desired = "urgent_chase"
			priority = 2
		if boss_phase > 0:
			desired = "epic_final" if boss_phase >= 3 else "epic_boss"
			priority = 4 if boss_phase >= 3 else 3
	if Sound.current_track == desired: return
	if not force and hold > 0 and priority <= current_priority: return
	var align: bool = Sound.current_track.begins_with("campus_%d" % level) and desired.begins_with("campus_%d" % level)
	Sound.track(desired, align, 0.7)
	current_priority = priority
	hold = 2.8
	transitions.append(desired)
	if transitions.size() > 64: transitions.pop_front()
