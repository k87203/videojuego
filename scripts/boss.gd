extends CharacterBody2D
var world
var miniboss := false
var health := 12
var max_health := 12
var phase := 1
var active := false
var dead := false
var clock := 0.0
var cycle := 0.0
var shot_timer := 0.0
var vulnerable := 0.0
var hurt_timer := 0.0
var shield_feedback := 0.0
var shield_feedbacks := 0
var home := Vector2.ZERO
var phase_history: Array[int] = [1]
var windup := 0.0
var aim_direction := Vector2.LEFT
var attack_sequence := 0
var dash_time := 0.0
var attack_kind := "shot"
var summon_time := 0.0
var summon_position := Vector2.ZERO

func _ready() -> void:
	home = position
	health = 6 if miniboss else 12
	max_health = health
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(66, 88)
	col.shape = rect
	col.position.y = -44
	add_child(col)
	add_to_group("bosses")

func expose(seconds: float) -> void:
	vulnerable = maxf(vulnerable, seconds)
	windup = 0
	dash_time = 0

func begin_attack() -> void:
	attack_sequence += 1
	attack_kind = "dash" if phase == 3 and attack_sequence % 3 == 0 else "shot"
	windup = 0.75 if attack_kind == "dash" else (0.7 if miniboss else 0.6)
	aim_direction = (world.player.position + Vector2(0, -32) - (position + Vector2(0, -62))).normalized()
	Sound.sfx("alert", 0.65 if attack_kind == "dash" else 0.85)

func release_attack() -> void:
	if attack_kind == "dash":
		dash_time = 0.48
		return
	var origin := position + Vector2(50 * signf(aim_direction.x), -62)
	var angles: Array[float] = [0.0]
	if miniboss and attack_sequence % 2 == 0: angles = [-0.23, 0.0, 0.23]
	elif phase >= 2: angles = [-0.32, 0.0, 0.32]
	if phase == 3 and attack_sequence % 2 == 0: angles = [-0.48, -0.24, 0.0, 0.24, 0.48]
	for angle in angles:
		world.fire(origin, aim_direction.rotated(angle) * (205 + phase * 15), Color("85e8d5") if miniboss else Color("ff9aac"))
	Sound.sfx("attack", 0.65)

func _physics_process(delta: float) -> void:
	clock += delta
	if dead:
		queue_redraw()
		return
	var p = world.player
	if not active and p.position.x > home.x - 450:
		active = true
		world.activate_arena()
		MusicManager.boss_started()
		world.say("BUG 404" if miniboss else "DOCTOR REPROBACIÓN", "¡Error: título no encontrado!" if miniboss else "¡Nadie se gradúa de mi examen final!", 4)
	if not active:
		queue_redraw()
		return
	cycle += delta
	shot_timer -= delta
	vulnerable = maxf(0, vulnerable - delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	shield_feedback = maxf(0, shield_feedback - delta)
	if summon_time > 0:
		summon_time -= delta
		if summon_time <= 0:
			world.spawn_enemy("virus" if phase == 3 else "task", summon_position)
			world.fx.burst(summon_position + Vector2(0, -30), Color("b8a1ff"), 14)
	if dash_time > 0:
		dash_time = maxf(0, dash_time - delta)
		if dash_time <= 0: expose(1.8)
	phase = 1 if miniboss else (2 if health > 4 and health <= 8 else (3 if health <= 4 else 1))
	if not phase_history.has(phase):
		phase_history.append(phase)
		world.say("AZTLI", "¡Fase %d! Esquiva las ráfagas; ataca cuando el escudo desaparezca." % phase, 4)
		world.fx.burst(position + Vector2(0, -60), Color("ff7e8b"), 30)
	var period := 5.5 if phase == 1 else 4.6
	if cycle >= period:
		cycle = 0
		expose(2.8)
		var arena_enemies := 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.home.x > home.x - 600: arena_enemies += 1
		if phase >= 2 and arena_enemies < 2:
			summon_position = Vector2(clampf(position.x + 170, home.x - 400, home.x + 300), 610)
			summon_time = 0.8
	if windup > 0:
		windup = maxf(0, windup - delta)
		if windup <= 0 and vulnerable <= 0: release_attack()
	elif vulnerable <= 0 and shot_timer <= 0 and dash_time <= 0:
		shot_timer = 1.85 - phase * 0.12
		begin_attack()
	velocity.y = minf(900, velocity.y + 1450 * delta)
	velocity.x = sin(clock * 1.5) * (100 if phase >= 2 else 35) if vulnerable <= 0 else 0
	if windup > 0: velocity.x = 0
	if dash_time > 0: velocity.x = signf(aim_direction.x) * 260
	if position.x < home.x - 210: velocity.x = 80
	if position.x > home.x + 120: velocity.x = -80
	move_and_slide()
	if absf(p.position.x - position.x) < 51 and absf(p.position.y - position.y) < 90:
		if p.velocity.y > 90 and p.position.y < position.y - 68:
			hit()
			p.velocity.y = -490
		else:
			p.hurt(position)
	queue_redraw()

func hit() -> bool:
	if not active or dead or hurt_timer > 0: return false
	if vulnerable <= 0:
		# A block still counts as the swing's impact; feedback is throttled for stomps and quick swings.
		if shield_feedback <= 0:
			shield_feedback = 0.4
			shield_feedbacks += 1
			Sound.sfx("shield", 0.7)
			world.fx.floating(position + Vector2(-50, -110), "ESCUDO", Color("a7b9ef"))
		return true
	health -= 1
	hurt_timer = 0.45
	Sound.sfx("hit", 0.7)
	world.fx.burst(position + Vector2(0, -50), Color("ffe1a1"), 22)
	world.shake = 5
	if health <= 0:
		dead = true
		active = false
		summon_time = 0
		windup = 0
		dash_time = 0
		Progress.data.score += 1500 if miniboss else 4000
		world.boss_defeated()
	return true

func _draw() -> void:
	if summon_time > 0:
		var local := summon_position - position
		draw_arc(local + Vector2(0, -6), 25, 0, TAU, 32, Color("c7a6ff"), 3, true)
		draw_string(ThemeDB.fallback_font, local + Vector2(-7, -38), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e7c6ff"))
	if windup > 0:
		var telegraph := Color(1, 0.58, 0.64, 0.25 + 0.22 * sin(clock * 24))
		if attack_kind == "dash":
			draw_rect(Rect2(-235 if aim_direction.x < 0 else 0, -15, 235, 14), telegraph)
		else:
			draw_line(Vector2(0, -62), Vector2(0, -62) + aim_direction * 380, telegraph, 3, true)
		draw_string(ThemeDB.fallback_font, Vector2(-45, -143), "¡CARGA!" if attack_kind == "dash" else "¡ALERTA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffb0b5"))
	if dead:
		draw_set_transform(Vector2(0, -20), PI / 2, Vector2(0.7, 0.7))
	var ink := Color("202940")
	if vulnerable <= 0 and not dead:
		draw_arc(Vector2(0, -50), 65, clock, clock + TAU - 0.3, 48, Color(0.65, 0.52, 1, 0.65), 3, true)
	elif not dead:
		draw_arc(Vector2(0, -50), 65, -PI / 2, -PI / 2 + TAU * clampf(vulnerable / 3.0, 0, 1), 48, Color("ffdf90"), 3, true)
	if miniboss:
		draw_style_box(box(Color("674c9d")), Rect2(-42, -92, 84, 68))
		draw_style_box(box(Color("19293f")), Rect2(-32, -82, 64, 46))
		draw_string(ThemeDB.fallback_font, Vector2(-26, -51), "404", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("9cf3d0"))
		for side in [-1, 1]:
			draw_line(Vector2(side * 27, -28), Vector2(side * 37, -3), ink, 13, true)
			draw_line(Vector2(side * 42, -64), Vector2(side * 60, -34), Color("a68ed5"), 10, true)
	else:
		for side in [-1, 1]:
			draw_line(Vector2(side * 13, -30), Vector2(side * 20, -5), ink, 15, true)
			draw_style_box(box(ink), Rect2(side * 20 - 10, -9, 25, 10))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -75), Vector2(23, -75), Vector2(34, -22), Vector2(-35, -22)]), Color("eee5e7"))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -75), Vector2(8, -75), Vector2(3, -40)]), Color("dc667a"))
		draw_circle(Vector2(0, -94), 22, ink)
		draw_circle(Vector2(0, -94), 19, Color("d4a596"))
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([Vector2(side * 13, -105), Vector2(side * 33, -121), Vector2(side * 25, -90)]), Color("e5e6ef"))
			draw_circle(Vector2(side * 9, -97), 8, ink)
			draw_circle(Vector2(side * 9, -97), 5, Color("b1f1ee"))
		draw_line(Vector2(-8, -82), Vector2(9, -85), ink, 3, true)
		draw_line(Vector2(-24, -68), Vector2(-43, -49), Color("eee5e7"), 13, true)
		draw_style_box(box(Color("b95c79")), Rect2(-60, -60, 27, 35))
		draw_string(ThemeDB.fallback_font, Vector2(-55, -37), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff0dc"))
	if vulnerable > 0 and not dead:
		draw_string(ThemeDB.fallback_font, Vector2(-41, -133), "¡AHORA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffe294"))

func box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.border_color = Color("202940")
	s.set_border_width_all(2)
	return s
