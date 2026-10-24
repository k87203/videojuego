extends CharacterBody2D
enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, SEARCH, RETURN }
## Per-kind tuning. The original four keep their exact 0.4 values; formulas below reproduce
## their old hitbox (36x43), contact box and stomp line.
const SPECS := {
	"task": {"name": "Tarea", "size": Vector2(36, 43), "life": 1, "windup": 0.34, "range": 230.0, "chase": 225.0, "burst": 265.0, "burst_time": 0.30, "mobile": true},
	"virus": {"name": "Virus", "size": Vector2(36, 43), "life": 1, "windup": 0.30, "range": 165.0, "chase": 285.0, "burst": 455.0, "burst_time": 0.24, "mobile": true},
	"robot": {"name": "Robot", "size": Vector2(36, 43), "life": 2, "windup": 0.48, "range": 150.0, "chase": 250.0, "burst": 405.0, "burst_time": 0.30, "mobile": true},
	"clock": {"name": "Reloj", "size": Vector2(36, 43), "life": 1, "windup": 0.50, "range": 460.0, "chase": 250.0, "burst": 265.0, "burst_time": 0.30, "mobile": true},
	"hopper": {"name": "Examen Sorpresa", "size": Vector2(34, 38), "life": 1, "windup": 0.35, "range": 0.0, "chase": 0.0, "burst": 0.0, "burst_time": 0.0, "mobile": true},
	"calc": {"name": "El Profe de Cálculo", "size": Vector2(40, 72), "life": 2, "windup": 0.62, "range": 520.0, "chase": 0.0, "burst": 0.0, "burst_time": 0.0, "mobile": false},
	"review": {"name": "La Revisión de Tarea", "size": Vector2(52, 44), "life": 2, "windup": 0.55, "range": 320.0, "chase": 230.0, "burst": 470.0, "burst_time": 0.62, "mobile": true},
	"coder": {"name": "El Maestro de Programación", "size": Vector2(44, 64), "life": 2, "windup": 0.55, "range": 520.0, "chase": 0.0, "burst": 0.0, "burst_time": 0.0, "mobile": false},
	"stamp": {"name": "El Sello de Servicios Escolares", "size": Vector2(46, 40), "life": 1, "windup": 0.45, "range": 0.0, "chase": 0.0, "burst": 0.0, "burst_time": 0.0, "mobile": false},
	"monitor": {"name": "El Monitor con Pantallazo", "size": Vector2(44, 38), "life": 1, "windup": 0.45, "range": 0.0, "chase": 0.0, "burst": 0.0, "burst_time": 0.0, "mobile": false},
	"shield": {"name": "La Carpeta Blindada", "size": Vector2(46, 54), "life": 1, "windup": 0.45, "range": 140.0, "chase": 170.0, "burst": 300.0, "burst_time": 0.22, "mobile": true},
}
## Kinds with their own movement step instead of the shared walker/chaser state machine.
const CUSTOM := ["hopper", "stamp", "monitor"]
## Ceiling droppers: hang, shake, drop onto the floor below, stay stuck, climb back.
const DROPPERS := ["stamp", "monitor"]
## What each archetype shouts the first time it spots the student.
const VOICE := {
	"task": ["¡Entrega pendiente!", "¡Te falta la portada!"],
	"virus": ["¡Te voy a infectar!", "¡Sin antivirus, eh!"],
	"robot": ["¡Movimiento detectado!", "¡Alumno fuera del aula!"],
	"clock": ["¡Se acaba el tiempo!", "¡Tic, tac, tic, tac!"],
	"hopper": ["¡Saquen una hoja!", "¡Examen sorpresa!"],
	"calc": ["¡Esto viene en el examen!", "¡Derivas o repruebas!"],
	"review": ["¡Sin nombre no cuenta!", "¡Esto está todo mal!"],
	"coder": ["¡En mi máquina sí compila!", "¡No es bug, es feature!"],
	"stamp": ["¡Trámite incompleto!", "¡SELLADO!"],
	"monitor": ["¡Error 404!", "¡Reiniciando...!"],
	"shield": ["¡Falta un requisito!", "¡Vuelva mañana!"],
}
## Seconds dazed after attacking (the opening to strike back). The original four keep 0.34 s.
const DIZZY := {"calc": 1.1, "review": 1.2, "coder": 1.1, "shield": 0.9}
## Attack rotations: low shots must be jumped, high shots must be slid or crouched under.
const PATTERNS := {"calc": ["lob", "low", "high"], "review": ["charge", "wave"], "coder": ["bug", "bug", "high"]}
const LANE_Y := {"low": -12.0, "high": -46.0}
const LOB_GRAVITY := 700.0
var state := State.IDLE
var kind := "task"
var world
var home := Vector2.ZERO
var direction := -1.0
var clock := 0.0
var timer := 0.5
var attack_timer := 0.0
var lost_time := 0.0
var life := 1
var stun := 0.0
var detection: Area2D
var target_in_range := false
var dead := false
var state_history: Array[int] = [State.IDLE]
var uid := ""
var hunter := false
var tier := 1
var windup := 0.0
var burst_time := 0.0
var recovery := 0.0
var dodge_time := 0.0
var dodge_cooldown := 0.0
var aim := Vector2.LEFT
var attack_serial := 0
var attacks_released := 0
var jumps_performed := 0
var dodges_performed := 0
var style_cache: Dictionary = {}
var spec: Dictionary = {}
var hop_timer := 1.0
var lob_origin := Vector2.ZERO
var lob_velocity := Vector2.ZERO
var lob_time := 1.0
var drop_state := "hang"
var drop_floor_y := INF
var block_feedback := 0.0
var blocks := 0
var pattern := ""
var lane_label := ""
var windup_total := 1.0
var voiced := false
var speech := ""
var speech_time := 0.0
var daze := 0.0

func _ready() -> void:
	home = position
	spec = SPECS.get(kind, SPECS.task)
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 8
	life = int(spec.life)
	hop_timer = 1.0 + fposmod(home.x, 0.6)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = spec.size
	col.shape = rect
	col.position.y = -(spec.size.y * 0.5 + 1.5)
	add_child(col)
	detection = Area2D.new()
	detection.collision_layer = 0
	detection.collision_mask = 2
	var sense := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 520
	sense.shape = circle
	detection.add_child(sense)
	add_child(detection)
	detection.body_entered.connect(func(body):
		if body == world.player: target_in_range = true)
	detection.body_exited.connect(func(body):
		if body == world.player: target_in_range = false)
	add_to_group("enemies")

func change_state(next: State) -> void:
	if next == state: return
	state = next
	state_history.append(state)
	if state_history.size() > 50: state_history.pop_front()
	timer = 0
	if state == State.ALERT:
		Sound.sfx("alert", 0.95 + tier * 0.04)
		world.fx.floating(position + Vector2(-5, -65), "!", Color("ffb76b"))
		MusicManager.action(0.7, 2.0)
		if not voiced:
			voiced = true
			world.enemy_voice(self)
	if state != State.ATTACK:
		windup = 0
		burst_time = 0

func reset_to_home() -> void:
	position = home
	velocity = Vector2.ZERO
	drop_state = "hang"
	daze = 0
	change_state(State.IDLE)

func say(text: String) -> void:
	speech = text
	speech_time = 2.0

func interrupt(seconds: float) -> void:
	# Diego's shield burst: cancels a telegraphed attack and freezes movement, but the enemy can still be hit.
	daze = maxf(daze, seconds)
	if state == State.ATTACK and windup > 0: change_state(State.SEARCH)
	burst_time = 0

func warning(seconds: float) -> float:
	# Sofía's radar gives every nearby warning 35% more time.
	var p = world.player
	if p.radar_time > 0 and absf(p.position.x - position.x) < 720: seconds *= 1.35
	windup_total = seconds
	return seconds

func sees_player() -> bool:
	if not target_in_range or world.player.locked: return false
	if kind == "robot" and not hunter and absf(world.player.velocity.x) < 12 and state in [State.IDLE, State.PATROL, State.RETURN]: return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -28), world.player.global_position + Vector2(0, -30), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func has_floor_ahead() -> bool:
	return floor_in_direction(direction)

func floor_in_direction(look_direction: float) -> bool:
	var margin := 65.0 if burst_time > 0 else 42.0
	return floor_at(look_direction * margin)

func floor_at(offset_x: float) -> bool:
	var query := PhysicsRayQueryParameters2D.create(position + Vector2(offset_x, -10), position + Vector2(offset_x, 80), 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func can_hop() -> bool:
	# A landing and headroom are required; no blind jumps into a void.
	var space := get_world_2d().direct_space_state
	var landing := PhysicsRayQueryParameters2D.create(position + Vector2(direction * 170, -90), position + Vector2(direction * 170, 110), 1)
	var headroom := PhysicsRayQueryParameters2D.create(position + Vector2(0, -48), position + Vector2(direction * 75, -125), 1)
	return not space.intersect_ray(landing).is_empty() and space.intersect_ray(headroom).is_empty()

func start_attack() -> void:
	change_state(State.ATTACK)
	direction = 1 if world.player.position.x >= position.x else -1
	windup = warning(float(spec.windup))
	pattern = PATTERNS[kind][attack_serial % PATTERNS[kind].size()] if PATTERNS.has(kind) else ""
	lane_label = ""
	if pattern in ["low", "high", "wave", "bug"]:
		var lane := "high" if pattern == "high" else "low"
		if world.take_lane_hint(lane): lane_label = "¡SALTA!" if lane == "low" else "¡AGÁCHATE!"
	var lead: Vector2 = world.player.velocity * 0.16
	lead.x = clampf(lead.x, -75, 75)
	lead.y = clampf(lead.y, -35, 35)
	aim = (world.player.position + Vector2(0, -30) + lead - (position + Vector2(0, -27))).normalized()
	if pattern == "lob": plan_lob()
	attack_serial += 1
	Sound.sfx("windup", 1.0 + tier * 0.05)
	MusicManager.action(0.9, 2.5)

func plan_lob() -> void:
	# The arc is fixed when the warning starts, so the dotted preview is exactly the throw.
	lob_origin = position + Vector2(direction * 22, -70)
	var target: Vector2 = world.player.position + Vector2(clampf(world.player.velocity.x * 0.25, -90, 90), -24)
	var dx := target.x - lob_origin.x
	lob_time = clampf(absf(dx) / 320.0, 0.75, 1.35)
	lob_velocity = Vector2(dx / lob_time, (target.y - lob_origin.y - 0.5 * LOB_GRAVITY * lob_time * lob_time) / lob_time)

func release_attack() -> void:
	attacks_released += 1
	attack_timer = maxf(0.9, 1.65 - tier * 0.15)
	recovery = 0.34
	Sound.sfx("enemy_attack", 0.9 if kind in ["robot", "review"] else 1.1)
	if kind == "clock":
		world.fire(position + Vector2(0, -24), aim * (300 + tier * 20), Color("ffb75d"))
		if tier >= 3:
			world.fire(position + Vector2(0, -24), aim.rotated(0.20) * 310, Color("ffb75d"))
	elif kind == "calc":
		if pattern == "lob":
			world.fire(lob_origin, lob_velocity, Color("fff3c8"), {"fall_gravity": LOB_GRAVITY, "glyph": "∫"})
			if tier >= 3: world.fire(lob_origin, lob_velocity * Vector2(0.75, 1.0), Color("fff3c8"), {"fall_gravity": LOB_GRAVITY, "glyph": "∫"})
		else:
			world.fire(position + Vector2(direction * 26, LANE_Y[pattern]), Vector2(direction * (290 + tier * 20), 0), Color("fff3c8"), {"glyph": "∫", "lane": pattern, "lifetime": 3.0})
		attack_timer = maxf(1.3, 2.1 - tier * 0.2)
	elif kind == "coder":
		if pattern == "high":
			world.fire(position + Vector2(direction * 26, LANE_Y.high), Vector2(direction * (250 + tier * 20), 0), Color("5aa9ff"), {"glyph": "error", "lane": "high", "lifetime": 3.0})
		else:
			world.fire(position + Vector2(direction * 26, -8), Vector2(direction * (200 + tier * 20), 0), Color("b6fa8d"), {"crawl": true, "glyph": "bug", "destructible": true, "lifetime": 3.2, "lane": "low"})
		attack_timer = maxf(1.4, 2.2 - tier * 0.2)
	elif kind == "review" and pattern == "wave":
		# A wave of graded sheets skims the floor: jump it, or swing to scatter it.
		world.fire(position + Vector2(direction * 30, -10), Vector2(direction * 320, 0), Color("fffaf0"), {"crawl": true, "glyph": "paper", "destructible": true, "lifetime": 2.6, "lane": "low"})
	elif kind == "task" and is_on_floor() and can_hop():
		velocity.y = -465
		burst_time = 0.42
		jumps_performed += 1
	else:
		burst_time = float(spec.burst_time)
	if DIZZY.has(kind): recovery = DIZZY[kind]
	world.fx.ring(position + Vector2(0, -24), Color("ffbd70"), 28)

func _physics_process(delta: float) -> void:
	if dead: return
	var p = world.player
	visible = absf(position.x - p.position.x) < 1150
	if not visible and state in [State.IDLE, State.PATROL]: return
	clock += delta
	timer += delta
	attack_timer = maxf(0, attack_timer - delta)
	stun = maxf(0, stun - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	block_feedback = maxf(0, block_feedback - delta)
	speech_time = maxf(0, speech_time - delta)
	daze = maxf(0, daze - delta)
	var sees := sees_player()
	var distance: float = position.distance_to(p.position)
	if sees:
		lost_time = 0
		if state in [State.IDLE, State.PATROL, State.SEARCH, State.RETURN]: change_state(State.ALERT)
	else: lost_time += delta
	var speed: float = float(spec.chase) * (1 + (tier - 1) * 0.08)
	if hunter: speed = maxf(speed, 365 + world.level_id * 8)
	if kind == "hopper": hopper_step(delta, p, sees)
	elif kind in DROPPERS: dropper_step(delta, p)
	else:
		match state:
			State.IDLE:
				velocity.x = 0
				if timer > 0.35: change_state(State.PATROL)
			State.PATROL:
				velocity.x = direction * (88 + tier * 12) if spec.mobile else 0.0
				if absf(position.x - home.x) > 185: direction = signf(home.x - position.x)
			State.ALERT:
				velocity.x = move_toward(velocity.x, 0, delta * 1800)
				if timer > maxf(0.24, 0.42 - tier * 0.04): change_state(State.CHASE)
			State.CHASE:
				direction = 1 if p.position.x >= position.x else -1
				velocity.x = move_toward(velocity.x, direction * speed, delta * 1750)
				var attack_range: float = spec.range
				if sees and distance < attack_range and attack_timer <= 0 and daze <= 0: start_attack()
				elif lost_time > 1.0: change_state(State.SEARCH)
				elif position.distance_to(home) > (2100 if hunter else 900): change_state(State.RETURN)
				if tier >= 2 and kind in ["virus", "clock"] and p.attack_time > 0 and distance > 100 and distance < 175 and dodge_cooldown <= 0:
					dodge_time = 0.22
					dodge_cooldown = 2.8
					dodges_performed += 1
			State.ATTACK:
				velocity.x = 0
				if windup > 0:
					windup = maxf(0, windup - delta)
					if windup <= 0: release_attack()
				elif burst_time > 0:
					burst_time = maxf(0, burst_time - delta)
					velocity.x = direction * float(spec.burst)
					if kind == "review" and int(clock * 30) % 3 == 0: world.fx.burst(position + Vector2(-direction * 20, -30), Color("fffaf0"), 1)
				else:
					recovery = maxf(0, recovery - delta)
					if recovery <= 0: change_state(State.CHASE if sees else State.SEARCH)
			State.SEARCH:
				velocity.x = direction * 70 if spec.mobile else 0.0
				if timer > 0.8: change_state(State.RETURN)
			State.RETURN:
				direction = signf(home.x - position.x)
				velocity.x = direction * 155 if spec.mobile else 0.0
				if absf(home.x - position.x) < 20 or not spec.mobile: change_state(State.IDLE)
	if dodge_time > 0:
		if kind == "clock" or floor_in_direction(-direction): velocity.x = -direction * 240
		else: dodge_time = 0; velocity.x = 0
	if kind == "clock":
		var altitude := home.y + sin(clock * 3.2) * 52
		if dodge_time > 0: altitude -= 60
		velocity.y = clampf((altitude - position.y) * 5, -180, 180)
	elif kind in DROPPERS:
		pass # dropper_step owns its vertical motion: hang, fall and climb back up its thread.
	elif kind == "hopper":
		velocity.y = minf(800, velocity.y + 1450 * delta)
		if is_on_floor() and velocity.y >= 0 and absf(velocity.x) > 1 and not floor_in_direction(signf(velocity.x)): velocity.x = 0
	else:
		velocity.y = minf(800, velocity.y + 1450 * delta)
		if spec.mobile and is_on_floor() and (not has_floor_ahead() or is_on_wall()):
			if state == State.CHASE and attack_timer <= 0 and can_hop():
				velocity.y = -475
				velocity.x = direction * 245
				attack_timer = 1.2
				jumps_performed += 1
			else:
				velocity.x = 0
				if state in [State.PATROL, State.RETURN]: direction *= -1
				elif state in [State.CHASE, State.ATTACK]: change_state(State.SEARCH)
	if stun > 0 or daze > 0: velocity.x = 0
	move_and_slide()
	if position.y > 820:
		position = home
		velocity = Vector2.ZERO
		drop_state = "hang"
	# Contact box derived from the hitbox; equals the 0.4 values (35 / 22 / 42 / 24) for 36x43.
	var size: Vector2 = spec.size
	if absf(p.position.x - position.x) < size.x * 0.5 + 17 and absf((p.position.y - 26) - (position.y - roundf(size.y * 0.5))) < size.y * 0.5 + 20.5 and not p.locked:
		if p.velocity.y > 70 and p.position.y < position.y - size.y * 24.0 / 43.0:
			hit("stomp")
			p.velocity.y = -420
		elif p.dash_time > 0: hit("dash")
		elif p.slide_time > 0 and kind not in ["robot", "shield"]: hit("slide")
		else: p.hurt(position)
	queue_redraw()

func hopper_step(delta: float, p, sees: bool) -> void:
	# Periodic hop: a visible crouch, then a jump toward the student (or in place at a ledge).
	if not is_on_floor(): return
	if windup > 0:
		velocity.x = 0
		windup = maxf(0, windup - delta)
		if windup <= 0: hop(sees)
		return
	velocity.x = move_toward(velocity.x, 0, delta * 900)
	if state in [State.ALERT, State.ATTACK]: change_state(State.CHASE if sees else State.PATROL)
	elif not sees and lost_time > 1.0 and state == State.CHASE: change_state(State.PATROL)
	hop_timer -= delta
	if hop_timer <= 0:
		if sees: direction = 1 if p.position.x >= position.x else -1
		elif absf(position.x - home.x) > 150: direction = signf(home.x - position.x)
		change_state(State.ATTACK)
		windup = warning(float(spec.windup))
		attack_serial += 1
		Sound.sfx("windup", 1.35)

func hop(sees: bool) -> void:
	var reach := 150.0 if sees else 80.0
	velocity.y = -560
	velocity.x = direction * reach / 0.77 if floor_at(direction * reach) else 0.0
	attacks_released += 1
	jumps_performed += 1
	hop_timer = maxf(0.9, 1.6 - (tier - 1) * 0.25)
	Sound.sfx("jump", 1.45)
	change_state(State.CHASE if sees else State.PATROL)

func dropper_step(delta: float, p) -> void:
	velocity.x = 0
	if drop_floor_y == INF:
		var query := PhysicsRayQueryParameters2D.create(home, home + Vector2(0, 700), 1)
		var found := get_world_2d().direct_space_state.intersect_ray(query)
		drop_floor_y = found.position.y if not found.is_empty() else 610.0
	match drop_state:
		"hang":
			velocity.y = 0
			position = home
			if attack_timer <= 0 and absf(p.position.x - position.x) < 150 and p.position.y > position.y + 60 and not p.locked:
				drop_state = "warn"
				change_state(State.ATTACK)
				windup = warning(float(spec.windup))
				if not voiced:
					voiced = true
					world.enemy_voice(self)
				attack_serial += 1
				Sound.sfx("windup", 0.8)
		"warn":
			velocity.y = 0
			windup = maxf(0, windup - delta)
			if windup <= 0:
				drop_state = "fall"
				velocity.y = 120
				attacks_released += 1
				Sound.sfx("enemy_attack", 0.8)
		"fall":
			velocity.y = minf(1100, velocity.y + 1900 * delta)
			if is_on_floor():
				drop_state = "dazed"
				recovery = 1.3
				world.shake = maxf(world.shake, 3)
				world.fx.burst(position + Vector2(0, -4), Color("eef2f5"), 14)
				change_state(State.SEARCH)
		"dazed":
			velocity.y = 0
			recovery = maxf(0, recovery - delta)
			if recovery <= 0: drop_state = "rise"
		"rise":
			velocity.y = -170
			if position.y <= home.y:
				position = home
				velocity.y = 0
				drop_state = "hang"
				attack_timer = 1.0
				change_state(State.IDLE)

func hit(source: String = "attack") -> bool:
	if dead or stun > 0: return false
	if kind == "shield" and source != "stomp":
		# The armored folder only yields to a stomp; blocks count as the swing's impact.
		blocks += 1
		if block_feedback <= 0:
			block_feedback = 0.4
			Sound.sfx("shield", 1.2)
			world.fx.floating(position + Vector2(-45, -80), "BLOQUEADO · ¡PISA!", Color("a7b9ef"))
		return true
	life -= 1
	stun = 0.4
	windup = 0
	burst_time = 0
	recovery = 0.35
	if kind in DROPPERS and drop_state in ["warn", "hang"]: drop_state = "fall"
	Sound.sfx("hit")
	world.fx.ring(position + Vector2(0, -25), Color("a2ffeb"), 48)
	world.fx.burst(position + Vector2(0, -25), Color("8deada"), 18)
	world.shake = maxf(world.shake, 3)
	MusicManager.action(0.8, 2)
	if life <= 0:
		dead = true
		if uid != "": world.defeated_ids[uid] = true
		Progress.data.score += 150
		world.enemies_defeated += 1
		world.fx.floating(position + Vector2(0, -45), "+150")
		queue_free()
	return true

func _draw() -> void:
	var size: Vector2 = spec.size
	if windup > 0:
		var color := Color(1, 0.38, 0.48, 0.5 + 0.2 * sin(clock * 26))
		match kind:
			"clock": draw_line(Vector2(0, -24), Vector2(0, -24) + aim * 340, color, 2, true)
			"calc", "coder", "review" when pattern in ["low", "high", "wave", "bug"]:
				# Lane bar at the exact height of the coming shot, plus a verb hint the first times.
				var lane_y: float = LANE_Y["high" if pattern == "high" else "low"]
				for i in 9: draw_rect(Rect2(direction * (30 + i * 30) - 9, lane_y - 2, 18, 4), color)
				if lane_label != "": draw_string(ThemeDB.fallback_font, Vector2(direction * 120 - 40, lane_y - 18), lane_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe08a"))
			"calc":
				# Dotted preview of the exact integral arc.
				var t := 0.0
				while t < lob_time:
					var point := lob_origin + lob_velocity * t + Vector2(0, 0.5 * LOB_GRAVITY * t * t) - position
					draw_circle(point, 3, color)
					t += 0.07
			"stamp", "monitor":
				var ground := drop_floor_y - position.y
				draw_set_transform(Vector2(0, ground), 0, Vector2(1, 0.25))
				draw_circle(Vector2.ZERO, 34, color)
				draw_set_transform(Vector2.ZERO)
			"hopper": draw_arc(Vector2(0, -2), 26, PI, TAU, 16, color, 3, true)
			_: draw_rect(Rect2(-140 if direction < 0 else 0, -8, 140, 7), color)
		draw_arc(Vector2(0, -size.y * 0.58), 33, -PI / 2, -PI / 2 + TAU * (1 - windup / maxf(windup_total, 0.01)), 28, Color("ffcc7b"), 3, true)
	if tier >= 2: draw_circle(Vector2(0, -size.y - 32), 3 + tier, Color("ff727e") if tier == 3 else Color("bc9bff"))
	var ink := Color("203049")
	var bob := sin(clock * 7) * 2
	draw_set_transform(Vector2(0, bob), sin(clock * 5) * 0.04)
	match kind:
		"task":
			draw_style_box(style(Color("fff3d6")), Rect2(-20, -45, 40, 40))
			for i in 3: draw_line(Vector2(-12, -36 + i * 7), Vector2(11, -36 + i * 7), Color("a7bcc9"), 2, true)
			draw_line(Vector2(-12, -18), Vector2(-3, -21), ink, 3, true)
			draw_line(Vector2(5, -21), Vector2(14, -18), ink, 3, true)
			draw_circle(Vector2(-8, -15), 2, ink)
			draw_circle(Vector2(9, -15), 2, ink)
			for side in [-1, 1]: draw_line(Vector2(side * 10, -6), Vector2(side * 18, 0), ink, 4, true)
		"virus":
			for i in 8:
				var a := i * TAU / 8 + clock * 0.5
				var v := Vector2.from_angle(a)
				draw_line(Vector2(0, -24) + v * 16, Vector2(0, -24) + v * 26, Color("58e4bb"), 4, true)
				draw_circle(Vector2(0, -24) + v * 26, 4, Color("b6fa8d"))
			draw_circle(Vector2(0, -24), 21, ink)
			draw_circle(Vector2(0, -24), 18, Color("38bfa5"))
			draw_circle(Vector2(-6, -27), 4, ink)
			draw_circle(Vector2(7, -27), 4, ink)
			draw_arc(Vector2(0, -22), 9, 0.2, PI - 0.2, 10, ink, 3, true)
		"robot":
			draw_style_box(style(Color("8ca6bb")), Rect2(-22, -44, 44, 34))
			draw_style_box(style(Color("273b59")), Rect2(-16, -37, 32, 14))
			for side in [-1, 1]:
				draw_circle(Vector2(side * 8, -30), 3, Color("ff9b72"))
				draw_circle(Vector2(side * 14, -6), 7, ink)
			draw_line(Vector2(0, -44), Vector2(5, -54), ink, 3, true)
			draw_circle(Vector2(5, -54), 4, Color("ffa17f"))
		"clock":
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([Vector2(side * 17, -27), Vector2(side * 43, -45 + sin(clock * 15) * 10), Vector2(side * 32, -12)]), Color("e7b77c"))
			draw_circle(Vector2(0, -24), 24, ink)
			draw_circle(Vector2(0, -24), 20, Color("ffd58d"))
			draw_circle(Vector2(0, -24), 16, Color("fff6dc"))
			draw_line(Vector2(0, -24), Vector2(-3, -36), ink, 3, true)
			draw_line(Vector2(0, -24), Vector2(10, -20), ink, 3, true)
		"hopper": draw_hopper(ink)
		"calc": draw_calc(ink)
		"review": draw_review(ink)
		"coder": draw_coder(ink)
		"stamp": draw_stamp(ink)
		"monitor": draw_monitor(ink)
		"shield": draw_shield(ink)
	draw_set_transform(Vector2.ZERO)
	if state in [State.ALERT, State.CHASE, State.ATTACK]:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -size.y - 22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffbd78"))
	if DIZZY.has(kind) and state == State.ATTACK and windup <= 0 and burst_time <= 0 and recovery > 0.2:
		# Dazed after attacking: circling stars mark the opening.
		for i in 3:
			var a := clock * 6 + i * TAU / 3
			draw_string(ThemeDB.fallback_font, Vector2(cos(a) * 18 - 5, -size.y - 6 + sin(a) * 5), "*", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe08a"))
	if daze > 0:
		draw_arc(Vector2(0, -size.y * 0.5), size.x * 0.7, 0, TAU, 20, Color(0.47, 0.91, 0.88, 0.6), 2, true)
	if speech_time > 0: draw_bubble(speech, -size.y - (78 if kind in DROPPERS else 48))

func draw_bubble(text: String, top: float) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
	draw_rect(Rect2(-width * 0.5, top - 28, width, 28), Color("203049"))
	draw_rect(Rect2(-width * 0.5 + 2, top - 26, width - 4, 24), Color("fffaf0"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, top - 2), Vector2(6, top - 2), Vector2(0, top + 8)]), Color("203049"))
	draw_string(font, Vector2(-width * 0.5 + 10, top - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("203049"))

# --- New archetypes: original vector silhouettes, no real people. Origin is at the feet. ---

func draw_hopper(ink: Color) -> void:
	# Examen Sorpresa: a folded pop quiz that crouches before every hop.
	var squash := Vector2(1.16, 0.8) if windup > 0 else (Vector2(0.9, 1.12) if not is_on_floor() else Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0, squash)
	draw_style_box(style(Color("fffaf0")), Rect2(-17, -38, 34, 34))
	draw_colored_polygon(PackedVector2Array([Vector2(9, -38), Vector2(17, -38), Vector2(17, -30)]), Color("d9dee6"))
	draw_string(ThemeDB.fallback_font, Vector2(-8, -12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("e2475b"))
	draw_circle(Vector2(-7, -26), 2.2, ink)
	draw_circle(Vector2(8, -26), 2.2, ink)
	for side in [-1, 1]: draw_line(Vector2(side * 8, -4), Vector2(side * 12, 0), ink, 4, true)

func draw_calc(ink: Color) -> void:
	# El Profe de Cálculo: tall coat, round glasses, chalk raised while aiming an integral.
	draw_set_transform(Vector2.ZERO, 0, Vector2(direction, 1))
	for side in [-1, 1]: draw_line(Vector2(side * 7, -24), Vector2(side * 8, -1), ink, 6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -58), Vector2(16, -58), Vector2(19, -20), Vector2(-19, -20)]), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -56), Vector2(14, -56), Vector2(17, -22), Vector2(-17, -22)]), Color("6d8fb3"))
	draw_line(Vector2(0, -56), Vector2(0, -36), Color("e2475b"), 3, true)
	draw_string(ThemeDB.fallback_font, Vector2(-12, -28), "∫", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff3c8"))
	draw_circle(Vector2(0, -66), 13, ink)
	draw_circle(Vector2(0, -66), 11, Color("e9c09a"))
	draw_arc(Vector2(0, -68), 11, PI * 0.95, PI * 2.05, 14, Color("c9ced8"), 4, true)
	for x in [-4, 6]: draw_arc(Vector2(x, -67), 4, 0, TAU, 12, ink, 1.6, true)
	draw_line(Vector2(-1, -60), Vector2(6, -60), Color("c9ced8"), 2.5, true)
	var hand := Vector2(19, -84) if windup > 0 else Vector2(21, -40)
	draw_line(Vector2(10, -52), hand, Color("6d8fb3"), 6, true)
	draw_rect(Rect2(hand.x - 2, hand.y - 7, 4, 9), Color("fffaf0"))

func draw_review(ink: Color) -> void:
	# La Revisión de Tarea: a stack of graded sheets with a red pen, leaning into its charge.
	draw_set_transform(Vector2.ZERO, 0.14 * direction if burst_time > 0 else 0.0, Vector2(direction, 1))
	draw_line(Vector2(-14, -44), Vector2(-26, -58), Color("e2475b"), 5, true)
	for i in 3:
		draw_style_box(style(Color("fffaf0").darkened(0.06 * (2 - i))), Rect2(-24 + i * 3, -44 + i * 3, 46, 38))
	for i in 3: draw_line(Vector2(-16, -30 + i * 7), Vector2(14, -30 + i * 7), Color("a7bcc9"), 2, true)
	draw_line(Vector2(4, -24), Vector2(14, -14), Color("e2475b"), 3, true)
	draw_line(Vector2(14, -24), Vector2(4, -14), Color("e2475b"), 3, true)
	draw_arc(Vector2(-10, -16), 7, 0, TAU, 14, Color("e2475b"), 2, true)
	draw_line(Vector2(-12, -40), Vector2(-3, -36), ink, 3, true)
	draw_line(Vector2(6, -36), Vector2(15, -40), ink, 3, true)
	for side in [-1, 1]: draw_line(Vector2(side * 12, -3), Vector2(side * 18, 0), ink, 4, true)

func draw_coder(ink: Color) -> void:
	# El Maestro de Programación: hoodie, headphones and a laptop whose screen turns red to warn.
	draw_set_transform(Vector2.ZERO, 0, Vector2(direction, 1))
	for side in [-1, 1]: draw_line(Vector2(side * 7, -22), Vector2(side * 8, -1), ink, 6, true)
	draw_style_box(style(Color("5b4b8a")), Rect2(-16, -50, 32, 30))
	draw_circle(Vector2(0, -56), 12, ink)
	draw_circle(Vector2(0, -56), 10, Color("c48d6c"))
	draw_arc(Vector2(0, -58), 13, PI, TAU, 16, Color("2a2f45"), 4, true)
	for x in [-12, 12]: draw_circle(Vector2(x, -56), 4, Color("2a2f45"))
	draw_circle(Vector2(4, -57), 1.8, ink)
	var warn := windup > 0 and int(clock * 12) % 2 == 0
	draw_style_box(style(Color("1e2a3a")), Rect2(4, -42, 28, 18))
	draw_rect(Rect2(7, -40, 22, 12), Color("ff5f6d") if warn else Color("3fd6a0"))
	draw_string(ThemeDB.fallback_font, Vector2(9, -30), "</>", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)

func draw_stamp(ink: Color) -> void:
	# El Sello de Servicios Escolares: a giant rubber stamp on a cord; it shakes and marks its spot.
	draw_line(Vector2(0, -40), Vector2(0, -position.y), Color(0.75, 0.7, 0.6, 0.8), 2)
	var shake := Vector2(sin(clock * 60) * 3, 0) if drop_state == "warn" else Vector2.ZERO
	draw_set_transform(shake)
	draw_circle(Vector2(0, -36), 9, ink)
	draw_circle(Vector2(0, -36), 7, Color("b5651d"))
	draw_style_box(style(Color("8a4b2a")), Rect2(-6, -30, 12, 14))
	draw_style_box(style(Color("c9ced8")), Rect2(-23, -17, 46, 10))
	draw_style_box(style(Color("b03a48")), Rect2(-23, -8, 46, 8))
	var stuck := drop_state == "dazed"
	for x in [-8, 8]:
		if stuck: draw_line(Vector2(x - 3, -14), Vector2(x + 3, -10), ink, 2, true)
		else: draw_circle(Vector2(x, -12), 2.2, ink)
	draw_set_transform(Vector2.ZERO)
	if stuck: draw_string(ThemeDB.fallback_font, Vector2(-38, 18), "¡SELLADO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e2475b"))

func draw_monitor(ink: Color) -> void:
	# El Monitor con Pantallazo: an old CRT hanging by its cable, blue screen and a sad face.
	draw_line(Vector2(0, -38), Vector2(0, -position.y), Color("2a2f45"), 2.5)
	var shake := Vector2(sin(clock * 60) * 3, 0) if drop_state == "warn" else Vector2.ZERO
	draw_set_transform(shake)
	draw_style_box(style(Color("d8d2c4")), Rect2(-22, -38, 44, 34))
	draw_rect(Rect2(-17, -33, 34, 24), Color("2a6fd6") if drop_state != "warn" or int(clock * 12) % 2 else Color("e2475b"))
	draw_string(ThemeDB.fallback_font, Vector2(-12, -14), ":(", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eef5ff"))
	draw_rect(Rect2(-10, -4, 20, 4), Color("a8a294"))

func draw_shield(ink: Color) -> void:
	# La Carpeta Blindada: a binder behind a riveted plate; the arrow says "stomp me".
	draw_set_transform(Vector2.ZERO, 0, Vector2(direction, 1))
	draw_style_box(style(Color("e0a450")), Rect2(-20, -54, 34, 52))
	draw_rect(Rect2(-16, -50, 6, 44), Color("c48a3c"))
	draw_circle(Vector2(-2, -38), 2.4, ink)
	draw_circle(Vector2(6, -38), 2.4, ink)
	draw_style_box(style(Color("9fb3c8").lightened(0.25) if block_feedback > 0.3 else Color("9fb3c8")), Rect2(12, -56, 12, 54))
	for y in [-48, -30, -12]: draw_circle(Vector2(18, y), 2, Color("e6eef6"))
	for side in [-1, 1]: draw_line(Vector2(side * 8, -3), Vector2(side * 12, 0), ink, 4, true)
	draw_set_transform(Vector2.ZERO)
	if absf(world.player.position.x - position.x) < 320:
		var bounce := sin(clock * 6) * 3
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -74 + bounce), Vector2(8, -74 + bounce), Vector2(0, -64 + bounce)]), Color("ffd47c"))

func style(color: Color) -> StyleBoxFlat:
	var key := color.to_html()
	if style_cache.has(key): return style_cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color("203049")
	s.set_corner_radius_all(5)
	s.set_border_width_all(2)
	style_cache[key] = s
	return s
