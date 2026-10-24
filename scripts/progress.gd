extends Node
## Persistent progression. Level pickups are unique; retries cannot farm rewards.
const SAVE_PATH = "user://progress.json"
var save_path := SAVE_PATH
var data: Dictionary = {}
var session_only := false
var music_volume := 0.45
var effects_volume := 0.8
var audio_muted := false
const ACCOUNT_KEYS := ["wallet", "coin_claims", "score_claims", "purchases", "equipment", "relics", "times", "achievements", "best"]
const SHOP := {
	"mint": {"name": "Sudadera del humedal", "price": 30, "slot": "skin", "color": "48c9ab"},
	"sunset": {"name": "Sudadera atardecer", "price": 30, "slot": "skin", "color": "f29564"},
	"cap": {"name": "Gorra del campus", "price": 25, "slot": "accessory"},
	"scarf": {"name": "Bufanda de Aztli", "price": 25, "slot": "accessory"},
	"heart": {"name": "Un corazón extra", "price": 80, "slot": "upgrade"},
	"maestra_luz": {"name": "Maestra Luz", "price": 120, "slot": "character"},
	"profe_nico": {"name": "Profe Nico", "price": 120, "slot": "character"},
}
const ACHIEVEMENTS := {
	"first_purchase": "A tu estilo · compra en la tienda",
	"first_clear": "Primer paso · completa un nivel",
	"honors": "Excelencia · consigue una S",
	"speed": "Sin perder clase · termina en menos de 5 minutos",
	"untouched": "Expediente impecable · completa un nivel sin daño",
	"collector": "Memoria del campus · reúne las 12 reliquias",
	"graduate": "El futuro es tuyo · completa la campaña",
}

func _ready() -> void:
	reset_data()
	load_game()
	_setup_inputs()

func reset_data() -> void:
	data = {"version": 1, "unlocked": 1, "current": 1, "score": 0, "credits": 0, "lives": 4, "double_jump": false, "shield": false, "usb": [], "fragments": [], "collected": [], "best": {}, "checkpoints": {}, "character": "alex", "graduated": false}
	data["course_revision"] = 4
	data.merge({"wallet": 0, "coin_claims": [], "score_claims": [], "purchases": [], "equipment": {}, "relics": [], "times": {}, "achievements": []})

func new_game() -> void:
	var account := {}
	for key in ACCOUNT_KEYS: account[key] = data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key]
	reset_data()
	data.merge(account, true)
	save_game()

func save_game() -> void:
	if session_only:
		return
	data["music_volume"] = music_volume
	data["effects_volume"] = effects_volume
	data["audio_muted"] = audio_muted
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
		# Import the old credit balance exactly once; old pickups cannot pay again.
		if not parsed.has("wallet"):
			data.wallet = maxi(0, int(data.credits))
			data.coin_claims = data.collected.duplicate()
		data.wallet = maxi(0, int(data.wallet))
		data.purchases = data.purchases.filter(func(id): return SHOP.has(str(id)))
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
		if not parsed.has("wallet"): data.coin_claims = data.collected.duplicate()
		if not parsed.has("score_claims"): data.score_claims = data.collected.duplicate()
		if not character_available(str(data.character)): data.character = "alex"
		music_volume = clampf(float(parsed.get("music_volume", 0.45)), 0, 1)
		effects_volume = clampf(float(parsed.get("effects_volume", 0.8)), 0, 1)
		audio_muted = bool(parsed.get("audio_muted", false))

func credit(amount: int = 1, uid: String = "") -> bool:
	if amount <= 0 or (uid != "" and uid in data.coin_claims): return false
	if uid != "":
		data.coin_claims.append(uid)
		data.wallet += amount
	var before := int(data.credits) / 100
	data.credits += amount
	if uid == "": data.score += amount * 25
	else: award_score(uid, amount * 25)
	if int(data.credits) / 100 > before:
		data.lives += 1
		Sound.sfx("victory")
	save_game()
	return true

func award_score(uid: String, amount: int) -> bool:
	if uid == "" or uid in data.score_claims: return false
	data.score_claims.append(uid)
	data.score += amount
	return true

func reward_id(level: int, x: float, kind: String) -> String:
	const Course = preload("res://scripts/expansion_data.gd")
	if x < Course.START: return "%d_%s_x%d" % [level, kind, roundi(x)]
	var chunk := floori((x - Course.START) / Course.CHUNK)
	return "ex_%d_%d_%s_%d" % [level, chunk, kind, roundi(x - Course.START - chunk * Course.CHUNK)]

func buy(id: String) -> bool:
	if not SHOP.has(id) or id in data.purchases: return false
	var price := int(SHOP[id].price)
	if int(data.wallet) < price: return false
	data.wallet -= price
	data.purchases.append(id)
	unlock("first_purchase")
	save_game()
	return true

func equip(character: String, slot: String, id: String) -> bool:
	if not character_available(character) or slot not in ["skin", "accessory"]: return false
	if id != "" and (not SHOP.has(id) or not id in data.purchases or SHOP[id].slot != slot): return false
	var outfit: Dictionary = data.equipment.get(character, {}).duplicate()
	outfit[slot] = id
	data.equipment[character] = outfit
	save_game()
	return true

func outfit(character: String) -> Dictionary:
	return data.equipment.get(character, {})

func character_available(id: String) -> bool:
	const Characters = preload("res://scripts/characters.gd")
	return id in Characters.STARTERS or (id in Characters.IDS and id in data.purchases)

func select_character(id: String) -> bool:
	if not character_available(id): return false
	data.character = id
	data.shield = id == "diego"
	save_game()
	return true

func unlock(id: String) -> void:
	if ACHIEVEMENTS.has(id) and not id in data.achievements: data.achievements.append(id)

func relic_count(level: int) -> int:
	return data.relics.filter(func(id): return str(id).begins_with("ex_%d_" % level)).size()

func collect_relic(uid: String) -> bool:
	if uid in data.relics: return false
	data.relics.append(uid)
	award_score(uid, 300)
	if data.relics.size() >= 12: unlock("collector")
	save_game()
	return true

func complete(level: int, grade: String, seconds: float = 0.0, damage: int = -1) -> void:
	data.checkpoints.erase(str(level))
	data.unlocked = mini(4, maxi(int(data.unlocked), level + 1))
	data.current = mini(4, level + 1)
	var ranks := ["C", "B", "A", "S"]
	if ranks.find(grade) > ranks.find(str(data.best.get(str(level), ""))):
		data.best[str(level)] = grade
	if level == 4:
		data.graduated = true
		unlock("graduate")
	unlock("first_clear")
	if grade == "S": unlock("honors")
	if seconds > 0 and is_finite(seconds):
		var previous := float(data.times.get(str(level), INF))
		if seconds < previous: data.times[str(level)] = seconds
		if seconds < 300: unlock("speed")
	if damage == 0: unlock("untouched")
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
