extends Node2D
## Keeps only nearby chunks alive. Stable pickup/enemy IDs survive unload/reload.
const Data = preload("res://scripts/expansion_data.gd")
var world
var loaded: Dictionary = {}
var last_chunk := -999
var district := -1
var current_name := "Entrada del campus"
var current_kind := "intro"
var difficulty := 0.0
var chase_active := false
var trial_active := false
var trial_remaining := 0.0
var trial_index := -1
var pulse := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	sync_chunks(world.checkpoint.x)

func sync_chunks(x: float) -> void:
	var index := int(floor((x - Data.START) / Data.CHUNK))
	if index == last_chunk: return
	last_chunk = index
	var wanted: Dictionary = {}
	for i in range(maxi(0, index - 2), mini(Data.COUNT * Data.CHUNKS_PER_DISTRICT, index + 4)):
		wanted[i] = true
		if not loaded.has(i): build_chunk(i)
	for i in loaded.keys():
		if not wanted.has(i):
			loaded[i].queue_free()
			loaded.erase(i)

func _process(delta: float) -> void:
	if not is_instance_valid(world.player) or world.completed: return
	var p = world.player
	pulse += delta
	sync_chunks(p.position.x)
	if p.position.x < Data.START:
		chase_active = false
		district = -1
		current_name = "Entrada del campus"
		current_kind = "intro"
		difficulty = 0
		return
	var next := Data.district_at(p.position.x)
	if next != district:
		district = next
		current_name = Data.title(world.level_id, district)
		current_kind = Data.RECIPES[district]
		difficulty = clampf((district + world.level_id * 2) / 24.0, 0, 1)
		world.say("AZTLI", "%s. %s" % [current_name, hint(current_kind)], 5)
	var begin := float(Data.START + district * Data.DISTRICT)
	chase_active = current_kind == "pursuit" and p.position.x > begin + 300 and p.position.x < begin + Data.DISTRICT - 250
	var trial_id := "trial_%d" % district
	if current_kind == "sprint" and not world.trials_completed.has(trial_id):
		if not trial_active and p.position.x >= begin + 280 and p.position.x < begin + 3400:
			trial_active = true
			trial_index = district
			trial_remaining = 22.0
			world.say("AZTLI", "¡Entrega urgente! Cruza el arco en 22 segundos. Si se acaba el tiempo, volvemos al faro sin perder una vida.", 5)
			Sound.sfx("trial")
	if trial_active:
		trial_remaining -= delta
		var target := float(Data.START + trial_index * Data.DISTRICT + 3400)
		if p.position.x >= target:
			world.trials_completed["trial_%d" % trial_index] = true
			trial_active = false
			Progress.credit(10)
			Progress.data.score += 500
			world.fx.floating(p.position + Vector2(-60, -90), "ENTREGA +500")
			world.say("AZTLI", "¡Entrega completada! Otro sello para tu expediente.", 4)
			world.save_snapshot()
			Sound.sfx("victory")
		elif trial_remaining <= 0:
			trial_active = false
			world.checkpoint = Vector2(Data.START + trial_index * Data.DISTRICT + 140, 610)
			world.respawn()
			world.say("AZTLI", "El tiempo terminó. Conservas tus recompensas: vuelve a intentarlo desde el faro.", 5)
	queue_redraw()

func hint(kind: String) -> String:
	match kind:
		"collapse": return "Las plataformas naranjas ceden al pisarlas: mantente en movimiento."
		"pursuit": return "¡Nos persiguen! Corre y utiliza las plataformas para ganar distancia."
		"sprint": return "Una entrega contrarreloj te espera al pasar el faro."
		"moving": return "Observa el ritmo de las plataformas; hay una ruta baja de recuperación."
		"garden": return "Respira y explora. Hay un escondite en la ruta alta."
		"electric": return "Las descargas alternan su ritmo. Salta o espera un momento seguro."
	return "Busca rutas altas y conserva tus corazones."

func build_chunk(index: int) -> void:
	var build_started := Time.get_ticks_usec()
	var chunk := Node2D.new()
	chunk.name = "DistrictChunk_%d" % index
	add_child(chunk)
	loaded[index] = chunk
	world.spawn_parent = chunk
	var x := float(Data.START + index * Data.CHUNK)
	var section := index / Data.CHUNKS_PER_DISTRICT
	var part := index % Data.CHUNKS_PER_DISTRICT
	var kind: String = Data.RECIPES[section]
	# Four contrasting encounters per district replace ten repetitions.
	var rest := part == 0 and section in [0, 5, 12, 16]
	if part == 2 and kind in ["terraces", "library", "garden"]:
		kind = "workshop" if world.level_id >= 3 else "bridges"
	elif part == 3 and kind not in ["sprint", "pursuit"]:
		kind = ["moving", "collapse", "mixed"][(section + world.level_id) % 3]
	var floors: Array = [[0, 1200]]
	if not rest:
		if kind in ["bridges", "mixed"]: floors = [[0, 330], [480, 310], [940, 260]]
		elif kind == "moving": floors = [[0, 280], [920, 280]]
		elif kind == "collapse" and section > 7: floors = [[0, 260], [960, 240]]
	for floor_part in floors:
		world.platform(Vector2(x + floor_part[0], 610), Vector2(floor_part[1], 220), true)
	if part == 0:
		var beacon = world.pickup("checkpoint", Vector2(x + 140, 610), stable(index, "checkpoint", 0))
		beacon.active = x + 140 <= world.checkpoint.x
	if part == 0:
		world.signpost(x + 220, Data.title(world.level_id, section) + " · " + hint(kind))
	if rest:
		# Slot is the local x offset: level, chunk and position identify each consumable.
		world.pickup("heart", Vector2(x + 650, 565), stable(index, "heart", 650))
		world.pickup("coffee" if section % 2 else "shield", Vector2(x + 850, 560), stable(index, "power", 850))
	else:
		match kind:
			"moving":
				var ferry = world.platform(Vector2(x + 300, 505), Vector2(160, 25))
				ferry.travel = Vector2(470, -45 if (index + world.level_id) % 2 else 0)
				ferry.period = 4.8 - minf(1, section * 0.04)
				world.platform(Vector2(x + 280, 665), Vector2(670, 25))
				# A broad last step lets every student recover from the lower route.
				world.platform(Vector2(x + 760, 635), Vector2(180, 25))
			"collapse":
				for j in 4:
					var ledge = world.platform(Vector2(x + 260 + j * 175, 580 - (j % 3) * 40), Vector2(155, 25))
					ledge.crumbling = true
					ledge.break_delay = 0.85 if section < 8 else 0.65
				if section > 7: world.platform(Vector2(x + 470, 700), Vector2(260, 25))
			"bridges", "mixed":
				world.platform(Vector2(x + 320, 660), Vector2(165, 25))
				world.platform(Vector2(x + 780, 660), Vector2(170, 25))
				world.platform(Vector2(x + 550, 495), Vector2(190, 25))
			"terraces", "library", "garden":
				for j in 3:
					var step_y: float = 515 - j * 85 if (section + part) % 2 == 0 else 505 - (1 - absi(j - 1)) * 90
					world.platform(Vector2(x + 340 + j * 180, step_y), Vector2(150, 25))
				if part == 1:
					var cache = world.pickup("cache", Vector2(x + 765, 300), stable(index, "cache", 0))
					cache.hidden_reward = true
			"workshop":
				world.platform(Vector2(x + 360, 520), Vector2(220, 25))
				var lift = world.platform(Vector2(x + 700, 510), Vector2(160, 25))
				lift.travel = Vector2(0, -165)
				lift.period = 4
			_:
				world.platform(Vector2(x + 450, 505), Vector2(180, 25))
		if kind in ["electric", "workshop", "sprint", "pursuit", "mixed"]:
			world.spawn_hazard(Vector2(x + 440, 610), 75 + (section % 3) * 12, world.level_id >= 3 or kind == "electric", chunk)
			if section > 8: world.spawn_hazard(Vector2(x + 820, 610), 85, kind != "sprint", chunk)
		if kind not in ["moving", "collapse"]:
			var enemy_kind := Data.enemy_kind(world.level_id, section, part)
			if kind == "pursuit": enemy_kind = "virus" if world.level_id >= 3 else "robot"
			var enemy_x := x + 650 if floors.size() == 1 else x + 1050
			var enemy_y: float = Data.ENEMY_HEIGHT.get(enemy_kind, 610.0)
			var uid := stable(index, "enemy", 0)
			if not world.defeated_ids.has(uid):
				var enemy = world.spawn_enemy(enemy_kind, Vector2(enemy_x, enemy_y))
				enemy.uid = uid
				enemy.hunter = kind == "pursuit"
				enemy.tier = 1 + int(section >= 6) + int(section >= 12 and world.level_id >= 3)
				if kind == "pursuit" and part == 2:
					var partner_id := stable(index, "enemy", 1)
					if not world.defeated_ids.has(partner_id):
						var partner = world.spawn_enemy("task", Vector2(x + 980, 610))
						partner.uid = partner_id
						partner.tier = 2
		for j in 3: world.pickup("credit", Vector2(x + 280 + j * 300, 555), stable(index, "credit", j))
		if kind in ["terraces", "library", "garden"]:
			for j in 3: world.pickup("credit", Vector2(x + 390 + j * 180, 470 - j * 85), stable(index, "high_credit", j))
	if kind == "sprint" and part == 2:
		world.pickup("trial_arch", Vector2(x + 1000, 610), stable(index, "arch", 0))
	world.spawn_parent = null
	# Local furniture silhouettes, cached in the chunk's display list.
	var scenery := Node2D.new()
	scenery.set_script(preload("res://scripts/district_scenery.gd"))
	scenery.position = Vector2(x, 610)
	scenery.level_id = world.level_id
	scenery.kind = kind
	scenery.section = section
	scenery.title = Data.title(world.level_id, section) if part == 0 else ""
	scenery.z_index = -1
	chunk.add_child(scenery)
	if "--profile-streaming" in OS.get_cmdline_user_args(): print("CHUNK BUILD index=%d elapsed=%.2fms" % [index, (Time.get_ticks_usec() - build_started) / 1000.0])

func stable(index: int, kind: String, slot: int) -> String:
	return "ex_%d_%d_%s_%d" % [world.level_id, index, kind, slot]

func _draw() -> void:
	if not is_instance_valid(world.player): return
	if trial_active:
		var x := float(Data.START + trial_index * Data.DISTRICT + 3400)
		draw_line(Vector2(x, 610), Vector2(x, 385), Color("8af1dc"), 4, true)
		draw_circle(Vector2(x, 385), 12, Color("ffe1a0"))
