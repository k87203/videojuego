extends CharacterBody2D
## Feet-origin collision body; visual rig is independently animated.
const GRAVITY := 1450.0
var world
var health := 3
var facing := 1.0
var invulnerable := 0.0
var coffee := 0.0
var coyote := 0.0
var buffered_jump := 0.0
var jumps := 0
var slide_time := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var step_time := 0.0
var anim_time := 0.0
var crouched := false
var celebrating := false
var locked := false
var shape: CollisionShape2D
var visual: Node2D
var camera: Camera2D
var landing_squash := 0.0
var character_id := "alex"
var character: Dictionary = {}
var max_health := 3
var ability_cooldown := 0.0
var dash_time := 0.0
var radar_time := 0.0
## Instance IDs already struck by the current swing; cleared when a new attack starts.
var attack_hits: Dictionary = {}
## Visual-only pose read by student_art.gd. The collision capsule never scales or rotates.
var pose_scale := Vector2.ONE
var pose_tilt := 0.0
var run_phase := 0.0
var stretch := 0.0
var takeoff := 0.0
var hitstop := 0.0
var dust_time := 0.0
var dust_puffs := 0
var prev_velocity_x := 0.0

func _ready() -> void:
	character_id = str(Progress.data.character)
	character = preload("res://scripts/characters.gd").spec(character_id)
	max_health = int(character.health)
	health = max_health
	# The scholarship shield is per-run state: every level starts from this student's default.
	Progress.data.shield = character_id == "diego"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 9
	shape = CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14
	capsule.height = 58
	shape.shape = capsule
	shape.position.y = -29
	add_child(shape)
	visual = Node2D.new()
	visual.set_script(preload("res://scripts/student_art.gd"))
	visual.actor = self
	add_child(visual)
	camera = Camera2D.new()
	camera.position = Vector2(100, -210)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.limit_left = 0
	camera.limit_right = world.level_length
	camera.limit_top = 0
	camera.limit_bottom = 820
	add_child(camera)

func _physics_process(delta: float) -> void:
	# Hit-stop freezes only the drawn pose; physics and every gameplay timer keep running.
	if hitstop <= 0: anim_time += delta
	ability_cooldown = maxf(0, ability_cooldown - delta)
	dash_time = maxf(0, dash_time - delta)
	radar_time = maxf(0, radar_time - delta)
	landing_squash = move_toward(landing_squash, 0, delta * 6)
	invulnerable = maxf(0, invulnerable - delta)
	coffee = maxf(0, coffee - delta)
	attack_time = maxf(0, attack_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	buffered_jump = maxf(0, buffered_jump - delta)
	slide_time = maxf(0, slide_time - delta)
	if locked:
		velocity.x = 0
		update_pose(delta, 0)
		visual.queue_redraw()
		return
	var grounded := is_on_floor()
	if grounded:
		coyote = 0.12
		jumps = 0
	else:
		coyote = maxf(0, coyote - delta)
	velocity.y = minf(1000, velocity.y + GRAVITY * delta)
	if Input.is_action_just_pressed("jump"):
		buffered_jump = 0.14
	if buffered_jump > 0:
		if coyote > 0:
			jump(false)
		elif can_double_jump() and jumps < 2:
			jump(true)
	if Input.is_action_just_released("jump") and velocity.y < -220:
		velocity.y *= 0.53
	var direction := Input.get_axis("left", "right")
	if absf(direction) > 0.1:
		facing = signf(direction)
	var requested_crouch := Input.is_action_pressed("crouch") and grounded
	if requested_crouch and not crouched and absf(velocity.x) > 220:
		slide_time = 0.48
		Sound.sfx("slide")
	# Do not stand up inside ceilings.
	if not requested_crouch and crouched:
		var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -26), global_position + Vector2(0, -60), 1)
		requested_crouch = not get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	crouched = requested_crouch or slide_time > 0
	shape.shape.height = 30 if crouched else 58
	shape.position.y = -15 if crouched else -29
	if Input.is_action_just_pressed("ability"): use_ability()
	var speed: float = (character.run if Input.is_action_pressed("run") else character.walk) * (1.32 if coffee > 0 else 1.0)
	if crouched:
		speed = 110
	if dash_time > 0:
		velocity.x = facing * 650
		world.fx.burst(position + Vector2(-facing * 20, -30), Color(character.accent), 1)
	elif slide_time > 0:
		velocity.x = facing * 440
	else:
		var acceleration := (2700.0 if grounded else 1650.0) if direction != 0 else (3200.0 if grounded else 1500.0)
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		attack_time = 0.19
		attack_cooldown = 0.34
		attack_hits.clear()
		Sound.sfx("attack")
		world.fx.ring(position + Vector2(facing * 36, -35), Color("98ffe9"), 38)
		MusicManager.action(0.65, 1.4)
		world.player_attack()
	var old_y := velocity.y
	move_and_slide()
	# Keep the strike active through its animation, including targets reached just after input.
	# Per-target stun/hurt windows guarantee at most one hit per swing.
	if attack_time > 0: world.player_attack()
	if is_on_floor() and not grounded and old_y > 140:
		landing_squash = clampf(old_y / 650.0, 0.5, 1.0)
		Sound.sfx("land")
		world.fx.burst(position, Color("b3e7da"), 7)
	if is_on_floor() and absf(velocity.x) > 80:
		step_time -= delta
		if step_time <= 0:
			step_time = 0.22 if absf(velocity.x) > 300 else 0.3
			Sound.sfx("step", randf_range(0.9, 1.12))
	if position.y > 800:
		world.fall_respawn()
	update_pose(delta, direction)
	visual.queue_redraw()

func jump(air_jump: bool) -> void:
	MusicManager.action(0.62 if air_jump else 0.4, 1.2)
	velocity.y = -545 if air_jump else -float(character.jump)
	jumps = 2 if air_jump else 1
	coyote = 0
	buffered_jump = 0
	slide_time = 0
	# Takeoff is immediate; the art shows a brief crouch, then the stretch.
	takeoff = 0.09
	Sound.sfx("jump", 1.3 if air_jump else 1.0)
	world.fx.burst(position, Color("6ce5d4") if air_jump else Color("f5dda6"), 10)

func update_pose(delta: float, direction: float) -> void:
	takeoff = maxf(0, takeoff - delta)
	hitstop = maxf(0, hitstop - delta)
	dust_time = maxf(0, dust_time - delta)
	var on_floor := is_on_floor()
	var acceleration := (velocity.x - prev_velocity_x) / maxf(delta, 0.001)
	prev_velocity_x = velocity.x
	# Squash & stretch: anticipation crouch, takeoff stretch, airborne stretch, landing squash.
	var target := 0.0
	if takeoff > 0.05: target = -0.6
	elif takeoff > 0: target = 0.85
	elif not on_floor: target = clampf(absf(velocity.y) / 1100.0, 0, 0.5)
	target -= landing_squash
	stretch = lerpf(stretch, clampf(target, -1, 1), 1.0 - exp(-delta * 26))
	pose_scale = Vector2(1 - stretch * 0.14, 1 + stretch * 0.16)
	# Lean into speed and acceleration.
	var lean := clampf(velocity.x / 4200.0 + acceleration / 14000.0, -0.16, 0.16) if on_floor else clampf(velocity.x / 6000.0, -0.08, 0.08)
	if crouched: lean *= 0.4
	pose_tilt = lerpf(pose_tilt, lean, 1.0 - exp(-delta * 12))
	# The run cycle advances with distance, so feet do not slide at any speed.
	if on_floor: run_phase = fposmod(run_phase + absf(velocity.x) * delta / 125.0 * TAU, TAU)
	var braking := on_floor and absf(velocity.x) > 170 and (absf(direction) < 0.1 or signf(direction) != signf(velocity.x))
	if (braking or (slide_time > 0 and on_floor)) and dust_time <= 0:
		dust_time = 0.06
		dust_puffs += 1
		world.fx.dust(position + Vector2(signf(velocity.x) * 12, -3), -signf(velocity.x))

func on_hit_confirmed(target: Node2D) -> void:
	# Visual hit-stop: the pose holds, the target flashes and the camera kicks. No time scaling.
	hitstop = 0.07
	world.shake = maxf(world.shake, 2.5)
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		target.modulate = Color(1.9, 1.9, 1.9)
		target.create_tween().tween_property(target, "modulate", Color.WHITE, 0.14)

func can_double_jump() -> bool:
	return Progress.data.double_jump or character_id == "valeria"

func use_ability() -> void:
	if ability_cooldown > 0 or locked: return
	if character_id == "valeria" and (is_on_floor() or jumps >= 2): return
	if character_id == "diego" and Progress.data.shield:
		world.fx.floating(position + Vector2(-70, -95), "Ya tienes escudo", Color("78e8e0"))
		return
	ability_cooldown = float(character.cooldown)
	match character_id:
		"alex":
			dash_time = 0.18
			# The dash slips through shots and strikes what it touches (shields still block it).
			invulnerable = maxf(invulnerable, 0.24)
		"valeria": jump(true)
		"diego":
			Progress.data.shield = true
			world.shockwave(position, 170)
		"sofia": radar_time = 5
	Sound.sfx("ability_" + character_id)
	world.fx.burst(position + Vector2(0, -30), Color(character.accent), 20)

func hurt(from: Vector2) -> void:
	if invulnerable > 0 or locked:
		return
	invulnerable = 1.6
	if Progress.data.shield:
		Progress.data.shield = false
		world.fx.burst(position + Vector2(0, -30), Color("78e8e0"), 24)
		Sound.sfx("shield")
		return
	health -= 1
	world.fx.ring(position + Vector2(0, -30), Color("ff638a"), 64)
	MusicManager.action(1.0, 3.0)
	world.damage_taken += 1
	velocity = Vector2(300 * signf(position.x - from.x), -310)
	Sound.sfx("hurt")
	world.fx.burst(position + Vector2(0, -28), Color("ff6f79"), 16)
	world.shake = 8
	if health <= 0:
		world.lose_life()
