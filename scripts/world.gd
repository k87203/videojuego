extends Node2D
const Data = preload("res://scripts/level_data.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Prop = preload("res://scripts/prop.gd")
const Platform = preload("res://scripts/platform.gd")
var app
@export_range(1, 4) var level_id := 1
var player
var eagle
var boss
var fx
var backdrop
var checkpoint := Vector2(180, 610)
var level_time := 0.0
var level_credits := 0
var enemies_defeated := 0
var damage_taken := 0
var secrets := 0
var lives_lost := 0
var has_credential := false
var switch_on := false
var arena_closed := false
var completed := false
var shake := 0.0
var pickup_count := 0
var intro_time := 0.0
var chase_timer := 0.0
var decorations: Array[Dictionary] = []
var resume_saved_checkpoint := false
var restored_state: Dictionary = {}
var level_length := preload("res://scripts/expansion_data.gd").LENGTH
var spawn_parent: Node
var extension
var trials_completed: Dictionary = {}
var defeated_ids: Dictionary = {}
## Hearts, coffee and scholarships taken during this run; saved with the checkpoint.
var consumed_ids: Dictionary = {}

func _ready() -> void:
	has_credential = "2_credential" in Progress.data.collected
	if resume_saved_checkpoint:
		restored_state = Progress.checkpoint_state(level_id)
		var saved_x := preload("res://scripts/expansion_data.gd").migrate_checkpoint(float(restored_state.get("x", 180)), int(restored_state.get("layout", 0)))
		var valid_points: Array = Data.layout(level_id).checkpoints.duplicate()
		valid_points.append_array([180, 5520])
		for point in valid_points:
			if is_equal_approx(saved_x, float(point)): checkpoint.x = float(point)
		if preload("res://scripts/expansion_data.gd").valid_checkpoint(saved_x): checkpoint.x = saved_x
		level_time = maxf(0, float(restored_state.get("time", 0)))
		damage_taken = maxi(0, int(restored_state.get("damage", 0)))
		level_credits = maxi(0, int(restored_state.get("credits", 0)))
		enemies_defeated = maxi(0, int(restored_state.get("defeated", 0)))
		switch_on = bool(restored_state.get("switch", false))
		trials_completed = restored_state.get("trials", {}).duplicate()
		defeated_ids = restored_state.get("defeated_ids", {}).duplicate()
		consumed_ids = restored_state.get("consumed_ids", {}).duplicate()
		if int(restored_state.get("layout", 0)) < 4:
			var migrated_enemies: Dictionary = {}
			for uid in defeated_ids:
				migrated_enemies[preload("res://scripts/expansion_data.gd").migrate_id(str(uid))] = defeated_ids[uid]
			defeated_ids = migrated_enemies
	for uid in Progress.data.usb:
		if str(uid).begins_with("%d_usb_" % level_id): secrets += 1
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	backdrop = Node2D.new()
	backdrop.set_script(preload("res://scripts/background.gd"))
	backdrop.level_id = level_id
	backdrop.world = self
	bg.add_child(backdrop)
	fx = Node2D.new()
	fx.set_script(preload("res://scripts/fx.gd"))
	fx.z_index = 20
	add_child(fx)
	_build()
	player = CharacterBody2D.new()
	player.set_script(Player)
	player.world = self
	player.position = checkpoint
	player.z_index = 5
	add_child(player)
	player.camera.reset_smoothing()
	eagle = Node2D.new()
	eagle.set_script(preload("res://scripts/aztli.gd"))
	eagle.world = self
	eagle.position = player.position + Vector2(-80, -150)
	eagle.z_index = 6
	add_child(eagle)
	extension = Node2D.new()
	extension.set_script(preload("res://scripts/level_extension.gd"))
	extension.world = self
	add_child(extension)
	MusicManager.enter_level(level_id)
	Progress.data.current = level_id
	say("AZTLI", "¡Seguimos desde tu checkpoint! Tu progreso está a salvo." if resume_saved_checkpoint and checkpoint.x > 180 else Data.BRIEFINGS[level_id - 1], 7)
	queue_redraw()

func _build() -> void:
	var d := Data.layout(level_id)
	for ground in d.ground:
		platform(Vector2(ground[0], 610), Vector2(ground[1], 220), true)
	# Left and right bounds are solid; the void remains below intentional gaps.
	platform(Vector2(-50, -300), Vector2(50, 1100), true)
	platform(Vector2(level_length, -300), Vector2(50, 1100), true)
	platform(Vector2(level_length - 3000, 610), Vector2(3000, 220), true)
	for p in d.platforms:
		platform(Vector2(p[0], p[1]), Vector2(p[2], 25))
		for i in 3: pickup("credit", Vector2(p[0] + 30 + i * 43, p[1] - 45))
	for p in d.moving:
		var node = platform(Vector2(p[0], p[1]), Vector2(p[2], 25))
		node.travel = Vector2(p[3], p[4])
		node.period = p[5]
	for g in d.ground:
		for x in range(g[0] + 260, g[0] + g[1] - 90, 160):
			pickup("credit", Vector2(x, 557))
	for p in d.usb: pickup("usb", Vector2(p[0], p[1]))
	for x in d.checkpoints:
		var beacon = pickup("checkpoint", Vector2(x, 610))
		beacon.active = resume_saved_checkpoint and x <= checkpoint.x
	for x in d.coffee: pickup("coffee", Vector2(x, 565), "%d_coffee_x%d" % [level_id, x])
	for x in d.shield: pickup("shield", Vector2(x, 560), "%d_shield_x%d" % [level_id, x])
	for x in d.hearts: pickup("heart", Vector2(x, 560), "%d_heart_x%d" % [level_id, x])
	for e in d.enemies: spawn_enemy(e[0], Vector2(e[1], e[2]))
	for h in d.hazards:
		var hazard := Area2D.new()
		hazard.set_script(preload("res://scripts/hazard.gd"))
		hazard.world = self
		hazard.position = Vector2(h[0], 610)
		hazard.width = h[1]
		hazard.electric = level_id >= 3
		add_child(hazard)
	pickup("exit", Vector2(d.exit, 610))
	if level_id == 1:
		pickup("feather", Vector2(1510, 560), "1_feather")
		signpost(360, "A / D o flechas: moverte • Espacio: saltar • Shift: correr • J: golpe de mochila.")
		signpost(900, "Corre y salta para cruzar. Mantén Espacio para saltar más alto. S: agacharte; corriendo, deslizarte.")
		signpost(1620, "¡Ahora tienes doble salto! Puedes saltar desde abajo a las plataformas flotantes. Busca las USB arriba.")
	if level_id == 2:
		pickup("credential", Vector2(2100, 563), "2_credential")
		var terminal = pickup("quiz", Vector2(2940, 610))
		terminal.active = bool(restored_state.get("quiz", false))
		gate(Vector2(3080, 80), Vector2(38, 530), "credential")
		signpost(2860, "La credencial abre la biblioteca. Resuelve el reto de la terminal para ganar créditos y una beca.")
	if level_id == 3:
		var lever = pickup("switch", Vector2(3038, 610))
		lever.active = switch_on
		gate(Vector2(3080, 80), Vector2(40, 530), "switch")
		signpost(2800, "Pulsa E frente al interruptor. Los robots detectan movimiento; espera agachado para estudiar su patrulla.")
	if level_id >= 3:
		boss = CharacterBody2D.new()
		boss.set_script(preload("res://scripts/boss.gd"))
		boss.world = self
		boss.miniboss = level_id == 3
		boss.position = Vector2(d.arena_x, 610)
		boss.z_index = 4
		add_child(boss)
		if int(restored_state.get("layout", 0)) >= 3 and bool(restored_state.get("boss", false)):
			boss.dead = true
			boss.health = 0
			pickup("fragment", Vector2(d.arena_x + 100, 555), "%d_fragment" % level_id)
		gate(Vector2(d.arena_gate_x, 70), Vector2(28, 540), "arena")
		platform(Vector2(d.arena_x - 400, 490), Vector2(140, 24))
		platform(Vector2(d.arena_x + 170, 485), Vector2(140, 24))
		signpost(d.arena_sign_x, "Combate: esquiva y espera a que desaparezca el escudo. Aztli abre otra oportunidad cada 10 segundos.")
	else:
		pickup("fragment", Vector2(6020, 556), "%d_fragment" % level_id)
	for x in range(120, 6500, 380):
		decorations.append({"x": x, "kind": (x / 380) % 4})

func platform(pos: Vector2, size: Vector2, ground: bool = false):
	var node := AnimatableBody2D.new()
	node.set_script(Platform)
	node.position = pos
	node.size = size
	node.ground = ground
	node.tech = level_id >= 3
	node.world = self
	attach_spawn(node)
	return node

func gate(pos: Vector2, size: Vector2, requirement: String) -> void:
	var node = platform(pos, size)
	node.gate = true
	node.requirement = requirement

func pickup(kind: String, pos: Vector2, stable_id: String = ""):
	var node := Area2D.new()
	node.set_script(Prop)
	node.kind = kind
	node.position = pos
	node.uid = stable_id if stable_id != "" else "%d_%s_%d" % [level_id, kind, pickup_count]
	node.world = self
	node.z_index = 2
	pickup_count += 1
	attach_spawn(node)
	return node

func signpost(x: float, message: String) -> void:
	var node = pickup("sign", Vector2(x, 610))
	node.text = message

func spawn_enemy(kind: String, pos: Vector2):
	var node := CharacterBody2D.new()
	node.set_script(Enemy)
	node.kind = kind
	node.world = self
	node.position = pos
	node.z_index = 3
	attach_spawn(node)
	return node

func attach_spawn(node: Node) -> void:
	if is_instance_valid(spawn_parent): spawn_parent.add_child(node)
	else: add_child(node)

func all_props() -> Array[Node]:
	return get_tree().get_nodes_in_group("pickups")

func spawn_hazard(pos: Vector2, width: float, electric: bool, parent: Node = null) -> void:
	var hazard := Area2D.new()
	hazard.set_script(preload("res://scripts/hazard.gd"))
	hazard.world = self
	hazard.position = pos
	hazard.width = width
	hazard.electric = electric
	hazard.clock = fposmod(pos.x, 3.2)
	if parent != null: parent.add_child(hazard)
	else: add_child(hazard)

func fire(pos: Vector2, velocity: Vector2, tint: Color) -> void:
	var node := Area2D.new()
	node.set_script(preload("res://scripts/projectile.gd"))
	node.world = self
	node.position = pos
	node.velocity = velocity
	node.tint = tint
	node.add_to_group("projectiles")
	add_child(node)

func player_attack() -> void:
	# One registered impact per target per swing. A target that ignores the hit (still stunned)
	# stays eligible for the rest of the swing, as before.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var id: int = enemy.get_instance_id()
		if player.attack_hits.has(id): continue
		var offset: Vector2 = enemy.position - player.position
		if absf(offset.x) < 90 and absf(offset.y) < 72 and offset.x * player.facing > -18:
			if enemy.hit():
				player.attack_hits[id] = true
				player.on_hit_confirmed(enemy)
	if is_instance_valid(boss) and not player.attack_hits.has(boss.get_instance_id()) and player.position.distance_to(boss.position) < 110:
		if boss.hit():
			player.attack_hits[boss.get_instance_id()] = true
			player.on_hit_confirmed(boss)

func say(who: String, message: String, duration: float = 5.0) -> void:
	if app != null: app.say(who, message, duration)

func save_snapshot() -> void:
	if completed: return
	var solved_quiz := false
	for child in get_children():
		if child.get_script() == Prop and child.kind == "quiz": solved_quiz = child.active
	Progress.data.checkpoints[str(level_id)] = {"x": checkpoint.x, "time": level_time, "damage": damage_taken, "credits": level_credits, "defeated": enemies_defeated, "switch": switch_on, "quiz": solved_quiz, "boss": is_instance_valid(boss) and boss.dead, "layout": 4, "trials": trials_completed, "defeated_ids": defeated_ids, "consumed_ids": consumed_ids}
	Progress.save_game()

func objective() -> String:
	if level_id == 1 and not Progress.data.double_jump: return "Encuentra la pluma de Aztli"
	if level_id == 2 and not has_credential: return "Recupera tu credencial"
	if level_id == 3 and not switch_on: return "Activa el laboratorio"
	if trials_completed.size() < 3: return "Entregas del campus  %d/3" % trials_completed.size()
	if is_instance_valid(boss) and not boss.dead: return "Vence a BUG 404" if level_id == 3 else "Vence al Doctor Reprobación"
	if not level_id in Progress.data.fragments: return "Recupera el fragmento dorado"
	return "Llega a la salida y pulsa E"

func _process(delta: float) -> void:
	if completed: return
	level_time += delta
	intro_time += delta
	shake = move_toward(shake, 0, delta * 30)
	player.camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	chase_timer -= delta
	if chase_timer <= 0:
		chase_timer = 0.3
		for prop in all_props():
			if prop.world != self: continue
			var active: bool = absf(prop.position.x - player.position.x) < 1050 and not prop.collected
			prop.set_process(active or prop.kind in ["exit", "quiz", "switch", "sign", "gate"])
			prop.visible = active
		var pursuing := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(absf(e.position.x - player.position.x) < 1250 or e.state not in [e.State.IDLE, e.State.PATROL])
			if e.state in [e.State.CHASE, e.State.ATTACK]: pursuing += 1
		var phase: int = boss.phase if is_instance_valid(boss) and boss.active else 0
		MusicManager.context(extension.difficulty, extension.chase_active or pursuing >= 2, phase, extension.trial_active)

func fall_respawn() -> void:
	damage_taken += 1
	Sound.sfx("hurt")
	lose_life()

func lose_life() -> void:
	lives_lost += 1
	Progress.data.lives -= 1
	if Progress.data.lives <= 0:
		player.locked = true
		save_snapshot()
		app.game_over()
		return
	respawn()

func respawn() -> void:
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.invulnerable = 2
	player.camera.reset_smoothing()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.position = e.home
		e.velocity = Vector2.ZERO
		e.change_state(e.State.IDLE)
	for shot in get_tree().get_nodes_in_group("projectiles"): shot.queue_free()
	arena_closed = false
	if is_instance_valid(boss) and not boss.dead:
		boss.position = boss.home
		boss.health = boss.max_health
		boss.active = false
		boss.cycle = 0
		boss.vulnerable = 0
		boss.windup = 0
		boss.dash_time = 0
		boss.summon_time = 0
	MusicManager.enter_level(level_id)
	if is_instance_valid(extension):
		extension.trial_active = false
		extension.sync_chunks(checkpoint.x)
	save_snapshot()

func activate_arena() -> void:
	arena_closed = true

func boss_defeated() -> void:
	arena_closed = false
	checkpoint = Vector2(boss.home.x - 380, 610)
	for shot in get_tree().get_nodes_in_group("projectiles"): shot.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.home.x > boss.home.x - 600: enemy.queue_free()
	pickup("fragment", Vector2(boss.home.x + 100, 555), "%d_fragment" % level_id)
	pickup("heart", Vector2(boss.home.x + 200, 555), "%d_heart_boss" % level_id)
	Sound.sfx("victory")
	MusicManager.enter_level(level_id)
	say("AZTLI", "¡Lo logramos! Recoge el fragmento dorado y entra por la puerta de graduación.", 7)
	save_snapshot()

func show_quiz(terminal) -> void:
	if terminal.active:
		say("TERMINAL", "Reto resuelto. ¡Buen trabajo!", 3)
		return
	app.quiz(terminal)

func try_complete() -> void:
	if completed: return
	if trials_completed.size() < 3:
		say("AZTLI", "Faltan entregas del campus. Completa los tres arcos contrarreloj para validar tu expediente.", 5)
		return
	if is_instance_valid(boss) and not boss.dead:
		say("AZTLI", "Primero debemos derrotar al guardián de este nivel.", 4)
		return
	if not level_id in Progress.data.fragments:
		say("AZTLI", "Falta el fragmento del título: busca el documento dorado antes de la salida.", 4)
		return
	if level_id == 4 and Progress.data.fragments.size() < 4:
		say("AZTLI", "Necesitas los cuatro fragmentos. Revisa los niveles anteriores desde el menú.", 4)
		return
	completed = true
	player.celebrating = true
	player.locked = true
	var grade := "S" if secrets >= 2 and damage_taken <= 2 else ("A" if damage_taken <= 4 else ("B" if damage_taken <= 8 else "C"))
	Progress.data.score += 1000 + level_credits * 10
	Progress.complete(level_id, grade)
	Sound.sfx("victory")
	app.results(grade)

func _draw() -> void:
	# Foreground campus furniture. Original vector art, intentionally outside collisions.
	for d in decorations:
		var x: float = d.x
		var base := Vector2(x, 610)
		draw_set_transform(base)
		match int(d.kind):
			0:
				if level_id == 1:
					draw_rect(Rect2(-5, -140, 10, 140), Color("9d7759"))
					for v in [Vector2(-24, -134), Vector2(20, -152), Vector2(0, -177)]:
						draw_circle(v, 39, Color("358b7f"))
						draw_circle(v + Vector2(-7, -9), 28, Color("63b993"))
				else:
					draw_style_box(decor_style(Color("4d7083")), Rect2(-34, -92, 68, 92))
					for i in 3:
						draw_rect(Rect2(-28, -85 + i * 26, 56, 18), Color("91b1b9"))
						draw_circle(Vector2(18, -76 + i * 26), 2, Color("b6f0d5"))
			1:
				draw_rect(Rect2(-38, -31, 84, 8), Color("c89e73"))
				draw_rect(Rect2(-38, -54, 84, 15), Color("bc936d"))
				for side in [-1, 1]: draw_line(Vector2(side * 29, -40), Vector2(side * 29, 0), Color("2b5267"), 5)
			2:
				draw_rect(Rect2(-4, -150, 8, 150), Color("42637b"))
				draw_style_box(decor_style(Color("ffe5ab")), Rect2(-14, -164, 28, 27))
				draw_circle(Vector2(0, -151), 31, Color(1, 0.86, 0.55, 0.06))
			3:
				draw_style_box(decor_style(Color("bd8c6d")), Rect2(-24, -25, 48, 25))
				for i in 5:
					draw_line(Vector2(0, -22), Vector2(-28 + i * 14, -46 - (i % 2) * 12), Color("59af91"), 9, true)
	draw_set_transform(Vector2.ZERO)

func decor_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	return s
