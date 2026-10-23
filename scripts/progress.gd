extends Node
## Persistent progression. Level pickups are unique; retries cannot farm rewards.
const SAVE_PATH = "user://progress.json"
var save_path := SAVE_PATH
var data: Dictionary = {}
var session_only := false
var music_volume := 0.65
var effects_volume := 0.8

func _ready() -> void:
	reset_data()
	load_game()
	_setup_inputs()

func reset_data() -> void:
	data = {"version": 1, "unlocked": 1, "current": 1, "score": 0, "credits": 0, "lives": 4, "double_jump": false, "shield": false, "usb": [], "fragments": [], "collected": [], "best": {}, "checkpoints": {}, "character": "alex", "graduated": false}
	data["course_revision"] = 4

func new_game() -> void:
	reset_data()
	save_game()

func save_game() -> void:
	if session_only:
		return
	data["music_volume"] = music_volume
	data["effects_volume"] = effects_volume
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el progreso: " + str(FileAccess.get_open_error()))
		return
	# The scholarship shield belongs to the current run and student, never to the save file.
	var saved := data.duplicate()
	saved.erase("shield")
	file.store_string(JSON.stringify(saved))
	file.close()
	var error := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK: push_warning("No se pudo confirmar el guardado: " + str(error))

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return
	var parsed = parser.data
	if parsed is Dictionary and parsed.get("version") == 1:
		for key in data.keys():
			if key == "shield": continue
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
				data[key] = parsed[key]
			elif parsed.has(key) and data[key] is int and (parsed[key] is float or parsed[key] is int):
				data[key] = int(parsed[key])
		data.unlocked = clampi(int(data.unlocked), 1, 4)
		data.current = clampi(int(data.current), 1, int(data.unlocked))
		data.lives = maxi(0, int(data.lives))
		# JSON stores numbers as floats; Array.has compares Variant types strictly.
		# Normalize document IDs so saved fragments still satisfy completion gates.
		var fragment_ids: Array = []
		for value in data.fragments:
			if value is int or value is float:
				var fragment := int(value)
				if fragment >= 1 and fragment <= 4 and is_equal_approx(float(value), float(fragment)) and not fragment in fragment_ids:
					fragment_ids.append(fragment)
		data.fragments = fragment_ids
		# Early 0.4 builds recorded layout=4 before adding the global marker.
		var inferred_revision := 3
		for snapshot in data.checkpoints.values():
			if snapshot is Dictionary and int(snapshot.get("layout", 0)) >= 4:
				inferred_revision = 4
				break
		if int(parsed.get("course_revision", inferred_revision)) < 4:
			var migrated: Array = []
			for uid in data.collected:
				var new_id := preload("res://scripts/expansion_data.gd").migrate_id(str(uid))
				if not new_id in migrated: migrated.append(new_id)
			data.collected = migrated
		data.course_revision = 4
		if not str(data.character) in preload("res://scripts/characters.gd").IDS: data.character = "alex"
		music_volume = clampf(float(parsed.get("music_volume", 0.65)), 0, 1)
		effects_volume = clampf(float(parsed.get("effects_volume", 0.8)), 0, 1)

func credit(amount: int = 1) -> void:
	var before := int(data.credits) / 100
	data.credits += amount
	data.score += amount * 25
	if int(data.credits) / 100 > before:
		data.lives += 1
		Sound.sfx("victory")

func complete(level: int, grade: String) -> void:
	data.checkpoints.erase(str(level))
	data.unlocked = mini(4, maxi(int(data.unlocked), level + 1))
	data.current = mini(4, level + 1)
	var ranks := ["C", "B", "A", "S"]
	if ranks.find(grade) > ranks.find(str(data.best.get(str(level), ""))):
		data.best[str(level)] = grade
	if level == 4:
		data.graduated = true
	save_game()

func checkpoint_state(level: int) -> Dictionary:
	var value = data.checkpoints.get(str(level), {})
	return value if value is Dictionary else {}

func _setup_inputs() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "run": [KEY_SHIFT], "crouch": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_ENTER], "attack": [KEY_J, KEY_X], "pause": [KEY_ESCAPE], "restart": [KEY_R]}
	keys["ability"] = [KEY_Q, KEY_C]
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var buttons := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "interact": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "run": JOY_BUTTON_RIGHT_SHOULDER, "crouch": JOY_BUTTON_B, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}
	buttons["ability"] = JOY_BUTTON_LEFT_SHOULDER
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action, event)
	for action in ["left", "right"]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = -1 if action == "left" else 1
		InputMap.action_add_event(action, event)
