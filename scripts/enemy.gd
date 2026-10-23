extends CharacterBody2D
enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, SEARCH, RETURN }
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

func _ready() -> void:
	home = position
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 8
	life = 2 if kind == "robot" else 1
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 43)
	col.shape = rect
	col.position.y = -23
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
	if state != State.ATTACK:
		windup = 0
		burst_time = 0

func sees_player() -> bool:
	if not target_in_range or world.player.locked: return false
	if kind == "robot" and not hunter and absf(world.player.velocity.x) < 12 and state in [State.IDLE, State.PATROL, State.RETURN]: return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -28), world.player.global_position + Vector2(0, -30), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func has_floor_ahead() -> bool:
	return floor_in_direction(direction)

func floor_in_direction(look_direction: float) -> bool:
	var margin := 65.0 if burst_time > 0 else 42.0
	var query := PhysicsRayQueryParameters2D.create(position + Vector2(look_direction * margin, -10), position + Vector2(look_direction * margin, 80), 1)
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
	windup = {"task": 0.34, "virus": 0.30, "robot": 0.48, "clock": 0.50}[kind]
	var lead: Vector2 = world.player.velocity * 0.16
	lead.x = clampf(lead.x, -75, 75)
	lead.y = clampf(lead.y, -35, 35)
	aim = (world.player.position + Vector2(0, -30) + lead - (position + Vector2(0, -27))).normalized()
	attack_serial += 1
	Sound.sfx("windup", 1.0 + tier * 0.05)
	MusicManager.action(0.9, 2.5)

func release_attack() -> void:
	attacks_released += 1
	attack_timer = maxf(0.9, 1.65 - tier * 0.15)
	recovery = 0.34
	Sound.sfx("enemy_attack", 0.9 if kind == "robot" else 1.1)
	if kind == "clock":
		world.fire(position + Vector2(0, -24), aim * (300 + tier * 20), Color("ffb75d"))
		if tier >= 3:
			world.fire(position + Vector2(0, -24), aim.rotated(0.20) * 310, Color("ffb75d"))
	elif kind == "task" and is_on_floor() and can_hop():
		velocity.y = -465
		burst_time = 0.42
		jumps_performed += 1
	else:
		burst_time = 0.24 if kind == "virus" else 0.30
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
	var sees := sees_player()
	var distance: float = position.distance_to(p.position)
	if sees:
		lost_time = 0
		if state in [State.IDLE, State.PATROL, State.SEARCH, State.RETURN]: change_state(State.ALERT)
	else: lost_time += delta
	var speed := (285.0 if kind == "virus" else (225.0 if kind == "task" else 250.0)) * (1 + (tier - 1) * 0.08)
	if hunter: speed = maxf(speed, 365 + world.level_id * 8)
	match state:
		State.IDLE:
			velocity.x = 0
			if timer > 0.35: change_state(State.PATROL)
		State.PATROL:
			velocity.x = direction * (88 + tier * 12)
			if absf(position.x - home.x) > 185: direction = signf(home.x - position.x)
		State.ALERT:
			velocity.x = move_toward(velocity.x, 0, delta * 1800)
			if timer > maxf(0.24, 0.42 - tier * 0.04): change_state(State.CHASE)
		State.CHASE:
			direction = 1 if p.position.x >= position.x else -1
			velocity.x = move_toward(velocity.x, direction * speed, delta * 1750)
			var attack_range: float = {"task": 230, "virus": 165, "robot": 150, "clock": 460}[kind]
			if sees and distance < attack_range and attack_timer <= 0: start_attack()
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
				velocity.x = direction * (455 if kind == "virus" else (405 if kind == "robot" else 265))
			else:
				recovery = maxf(0, recovery - delta)
				if recovery <= 0: change_state(State.CHASE if sees else State.SEARCH)
		State.SEARCH:
			velocity.x = direction * 70
			if timer > 0.8: change_state(State.RETURN)
		State.RETURN:
			direction = signf(home.x - position.x)
			velocity.x = direction * 155
			if absf(home.x - position.x) < 20: change_state(State.IDLE)
	if dodge_time > 0:
		if kind == "clock" or floor_in_direction(-direction): velocity.x = -direction * 240
		else: dodge_time = 0; velocity.x = 0
	if kind == "clock":
		var altitude := home.y + sin(clock * 3.2) * 52
		if dodge_time > 0: altitude -= 60
		velocity.y = clampf((altitude - position.y) * 5, -180, 180)
	else:
		velocity.y = minf(800, velocity.y + 1450 * delta)
		if is_on_floor() and (not has_floor_ahead() or is_on_wall()):
			if state == State.CHASE and attack_timer <= 0 and can_hop():
				velocity.y = -475
				velocity.x = direction * 245
				attack_timer = 1.2
				jumps_performed += 1
			else:
				velocity.x = 0
				if state in [State.PATROL, State.RETURN]: direction *= -1
				elif state in [State.CHASE, State.ATTACK]: change_state(State.SEARCH)
	if stun > 0: velocity.x = 0
	move_and_slide()
	if position.y > 820:
		position = home
		velocity = Vector2.ZERO
	if absf(p.position.x - position.x) < 35 and absf((p.position.y - 26) - (position.y - 22)) < 42 and not p.locked:
		if p.velocity.y > 70 and p.position.y < position.y - 24:
			hit()
			p.velocity.y = -420
		elif p.slide_time > 0 and kind != "robot": hit()
		else: p.hurt(position)
	queue_redraw()

func hit() -> void:
	if dead or stun > 0: return
	life -= 1
	stun = 0.4
	windup = 0
	burst_time = 0
	recovery = 0.35
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

func _draw() -> void:
	if windup > 0:
		var color := Color(1, 0.38, 0.48, 0.5 + 0.2 * sin(clock * 26))
		if kind == "clock": draw_line(Vector2(0, -24), Vector2(0, -24) + aim * 340, color, 2, true)
		else: draw_rect(Rect2(-140 if direction < 0 else 0, -8, 140, 7), color)
		draw_arc(Vector2(0, -25), 33, -PI / 2, -PI / 2 + TAU * (1 - windup / 0.5), 28, Color("ffcc7b"), 3, true)
	if tier >= 2: draw_circle(Vector2(0, -75), 3 + tier, Color("ff727e") if tier == 3 else Color("bc9bff"))
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
	if state in [State.ALERT, State.CHASE, State.ATTACK]:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -65), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffbd78"))

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
