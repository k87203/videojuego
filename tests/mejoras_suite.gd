extends Node
## 0.5 improvements, stage by stage, in the real engine with an isolated profile.
const HudIcon = preload("res://scripts/hud_icon.gd")
var app
var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
	print(("PASS: " if value else "FAIL: ") + message)

func ticks(count: int) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func release() -> void:
	for action in ["left", "right", "run", "jump", "attack", "ability", "crouch"]: Input.action_release(action)

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	seed(11)
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(3)
	await stage1_motion()
	await stage1_hitstop()
	await stage1_interface()
	await stage2_roster()
	await stage2_telegraphs()
	await stage2_damage_rules()
	await stage2_projectiles()
	await stage2_duels()
	await stage2b_personality()
	await stage2b_lanes()
	await stage2b_abilities()
	await stage2b_encounters()
	await stage2b_prefect()
	print("MEJORAS RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report := FileAccess.open("res://docs/mejoras-results.txt", FileAccess.WRITE)
	if report: report.store_string("%d checks; %d failures\n%s\n" % [checks, failures.size(), "\n".join(failures)])
	release()
	app.queue_free()
	Sound.shutdown()
	await ticks(3)
	await get_tree().create_timer(.2).timeout
	OS.delay_msec(250)
	get_tree().quit(0 if failures.is_empty() else 1)

# Collision capsule, body and visual node must stay untouched by every animation effect.
var collision_ok := true
func sample_collision(p) -> void:
	var capsule: CapsuleShape2D = p.shape.shape
	var expected_height := 30.0 if p.crouched else 58.0
	var expected_y := -15.0 if p.crouched else -29.0
	if p.scale != Vector2.ONE or p.rotation != 0 or p.shape.scale != Vector2.ONE or p.shape.rotation != 0: collision_ok = false
	if capsule.radius != 14 or capsule.height != expected_height or p.shape.position != Vector2(0, expected_y): collision_ok = false
	if p.visual.scale != Vector2.ONE or p.visual.rotation != 0 or p.visual.position != Vector2.ZERO: collision_ok = false

func frames(p, count: int, log: Array) -> void:
	for i in count:
		await get_tree().physics_frame
		sample_collision(p)
		log.append({"scale": p.pose_scale, "tilt": p.pose_tilt, "vy": p.velocity.y, "floor": p.is_on_floor(), "phase": p.run_phase, "x": p.position.x})

func stage1_motion() -> void:
	release()
	Progress.data.character = "alex"
	app.start_level(1)
	await ticks(3)
	var w = app.world
	var p = w.player
	p.invulnerable = 999
	w.set_process(false)
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	p.position = Vector2(2760, 610)
	await ticks(20)
	var idle_puffs: int = p.dust_puffs
	await ticks(20)
	check(p.dust_puffs == idle_puffs, "Standing still raises no dust")
	var log: Array = []
	Input.action_press("right")
	Input.action_press("run")
	await frames(p, 40, log)
	var max_tilt := 0.0
	for s in log: max_tilt = maxf(max_tilt, s.tilt)
	check(max_tilt > 0.04, "Student leans into acceleration and speed (max tilt %.3f rad)" % max_tilt)
	var a = log[25]
	var b = log[35]
	var expected := fposmod(a.phase + (b.x - a.x) / 125.0 * TAU, TAU)
	check(absf(angle_difference(expected, b.phase)) < 0.05 and absf(b.x - a.x) > 30, "Run cycle advances with distance travelled, so feet do not slide")
	var puffs_before: int = p.dust_puffs
	Input.action_release("run")
	Input.action_release("right")
	Input.action_press("left")
	await frames(p, 6, log)
	check(p.dust_puffs > puffs_before, "Reversing at speed kicks up braking dust")
	release()
	await frames(p, 40, [])
	log = []
	Input.action_press("jump")
	await frames(p, 4, log)
	# Samples are taken at the start of each physics step, so they show the previous step's result.
	var anticipation := false
	for s in log.slice(0, 3): if s.vy < -400 and s.scale.y < 0.98: anticipation = true
	check(log[1].vy < -400 and anticipation, "Jump leaves on the first step while the art shows an anticipation crouch")
	await frames(p, 6, log)
	var stretched := false
	for s in log.slice(3): if s.scale.y > 1.06: stretched = true
	check(stretched, "Takeoff stretches the student vertically")
	Input.action_release("jump")
	log = []
	await frames(p, 70, log)
	var squashed := false
	var landed := false
	for s in log:
		if s.floor: landed = true
		if landed and s.scale.x > 1.04 and s.scale.y < 0.96: squashed = true
	check(landed and squashed, "Landing squashes the student")
	Input.action_press("right")
	Input.action_press("run")
	await frames(p, 25, [])
	Input.action_press("crouch")
	await frames(p, 12, [])
	release()
	await frames(p, 30, [])
	check(collision_ok, "Squash, tilt, run cycle and slide never touch the body, capsule or visual node transform")

func stage1_hitstop() -> void:
	release()
	app.start_level(3)
	await ticks(3)
	var w = app.world
	var p = w.player
	p.invulnerable = 999
	w.set_process(false)
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	p.position = Vector2(2000, 610)
	p.facing = 1
	await ticks(4)
	var enemy = w.spawn_enemy("robot", Vector2(2050, 610))
	await ticks(2)
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	var cooldown_at_hit: float = p.attack_cooldown
	check(p.hitstop > 0 and enemy.life == 1, "A landed hit triggers hit-stop")
	check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Hit-stop never scales engine time")
	await ticks(3)
	check(absf((cooldown_at_hit - p.attack_cooldown) - 3.0 / 60.0) < 0.02 and enemy.stun < 0.4, "Gameplay timers keep running during hit-stop")
	var boss = w.boss
	p.position = Vector2(boss.home.x - 60, 610)
	await ticks(4)
	check(boss.active, "Boss arena active for timing check")
	w.eagle.help_timer = 999
	boss.expose(3)
	boss.hurt_timer = 0
	await ticks(25)
	var cycle_before: float = boss.cycle
	Input.action_press("attack")
	await ticks(1)
	Input.action_release("attack")
	var hurt_at_hit: float = boss.hurt_timer
	await ticks(4)
	check(boss.hurt_timer > 0 and absf((hurt_at_hit - boss.hurt_timer) - 4.0 / 60.0) < 0.02, "Boss hurt window counts down normally through the hit-stop")
	check(absf((boss.cycle - cycle_before) - 5.0 / 60.0) < 0.02, "Boss attack cycle keeps real time during the hit-stop")

func stage1_interface() -> void:
	release()
	app.show_menu()
	check(app.ui.modulate.a < 0.5, "Screen changes start a fade-in transition")
	await ticks(20)
	check(app.ui.modulate.a == 1.0, "Fade-in completes in about 0.2 s")
	check(app.ui.theme is Theme and app.ui.theme.default_font != null, "UI uses a shared Godot Theme with its default font")
	var primary: Button
	var secondary: Button
	for child in app.ui.get_children():
		if child is Button and child.text.begins_with("INICIAR"): primary = child
		if child is Button and child.text == "NIVELES": secondary = child
	check(primary.theme_type_variation == &"PrimaryButton" and secondary.theme_type_variation == &"", "Primary and secondary buttons use Theme variations")
	var distinct := true
	for b in [primary, secondary]:
		var normal: StyleBoxFlat = b.get_theme_stylebox("normal")
		var hover: StyleBoxFlat = b.get_theme_stylebox("hover")
		var pressed: StyleBoxFlat = b.get_theme_stylebox("pressed")
		if normal.bg_color == hover.bg_color or normal.bg_color == pressed.bg_color or hover.bg_color == pressed.bg_color: distinct = false
		if not b.has_theme_stylebox("focus") or b.has_theme_stylebox_override("normal"): distinct = false
	check(distinct, "Buttons have distinct normal, hover and pressed states from the Theme")
	var title: Label
	for child in app.ui.get_children():
		if child is Label and child.text == "LA MISIÓN DEL TÍTULO": title = child
	check(title.get_theme_constant("outline_size") > 0 and title.get_theme_color("font_outline_color").a > 0.5, "Labels get an outline for legibility")
	app.start_level(1)
	await ticks(3)
	var icons := 0
	for node in app.ui.find_children("*", "Control", true, false):
		if node.get_script() == HudIcon: icons += 1
	check(icons >= 9, "HUD shows vector icons (%d)" % icons)
	var p = app.world.player
	p.invulnerable = 0
	p.hurt(p.position + Vector2(40, 0))
	await ticks(2)
	check(app.hud.hearts.maximum == p.max_health and app.hud.hearts.current == p.health, "Heart icons track health")
	app.pause_game()
	await ticks(2)
	var resume: Button
	for child in app.ui.get_children():
		if child is Button and child.text == "Seguir aventura": resume = child
	check(resume != null and resume.has_focus() and resume.theme_type_variation == &"PrimaryButton", "Pause menu keeps keyboard focus on the themed primary action")
	app.resume_game()

# ---------- Stage 2: enemy variety ----------
const Data = preload("res://scripts/expansion_data.gd")
## "stamp" replaced the 0.5 eraser ("dropper") on purpose: the eraser resembled the reference game.
const NEW_KINDS := ["hopper", "calc", "review", "coder", "stamp", "shield"]

func clear_combat() -> void:
	for group in ["enemies", "projectiles"]:
		for node in get_tree().get_nodes_in_group(group): node.queue_free()
	await ticks(2)

func arena(character: String = "alex"):
	release()
	Progress.data.character = character
	Progress.data.double_jump = true
	app.start_level(3)
	await ticks(3)
	var w = app.world
	w.set_process(false)
	w.extension.set_process(false)
	w.eagle.help_timer = 999
	w.platform(Vector2(50000, 610), Vector2(2400, 220), true)
	await clear_combat()
	w.player.position = Vector2(50600, 610)
	w.player.velocity = Vector2.ZERO
	w.player.camera.reset_smoothing()
	await ticks(3)
	return w

func stage2_roster() -> void:
	var first_seen := {}
	for level in [1, 2, 3, 4]:
		release()
		app.start_level(level)
		await ticks(2)
		var w = app.world
		w.set_process(false)
		w.extension.set_process(false)
		var kinds := {}
		for index in range(0, Data.COUNT * Data.CHUNKS_PER_DISTRICT, 3):
			w.extension.sync_chunks(Data.START + index * Data.CHUNK + 10)
			await ticks(1)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.is_queued_for_deletion() or e.home.x < Data.START: continue
				kinds[e.kind] = true
				var key := "%d_%s" % [level, e.kind]
				if not first_seen.has(key) or e.home.x < first_seen[key]: first_seen[key] = e.home.x
		var missing: Array = []
		for entry in Data.ENEMY_ROSTER[level]:
			if not kinds.has(entry[1]): missing.append(entry[1])
		check(missing.is_empty(), "Level %d streams every kind of its roster (missing: %s)" % [level, str(missing)])
	var all_new := true
	for kind in NEW_KINDS:
		var appears := false
		for level in [1, 2, 3, 4]:
			if first_seen.has("%d_%s" % [level, kind]): appears = true
		if not appears: all_new = false
	check(all_new, "All six new archetypes appear in the campaign")
	check(not first_seen.has("1_review") and not first_seen.has("1_coder") and not first_seen.has("1_shield") and not first_seen.has("2_coder") and not first_seen.has("2_shield"), "Advanced archetypes stay out of the early levels")
	check(first_seen.get("1_calc", 0.0) >= Data.START + 8 * Data.DISTRICT and first_seen.get("3_shield", 0.0) >= Data.START + 7 * Data.DISTRICT, "New archetypes enter after their introduction district")

func stage2_telegraphs() -> void:
	var w = await arena()
	var p = w.player
	p.invulnerable = 999
	var spots := {"hopper": Vector2(50760, 610), "calc": Vector2(50900, 610), "review": Vector2(50850, 610), "coder": Vector2(50900, 610), "stamp": Vector2(50600, 330), "shield": Vector2(50720, 610)}
	for kind in spots:
		await clear_combat()
		p.position = Vector2(50600, 610)
		var e = w.spawn_enemy(kind, spots[kind])
		await ticks(1)
		var shape: RectangleShape2D = e.get_child(0).shape
		check(shape.size == e.spec.size and e.spec.size != Vector2(36, 43), "%s has its own hitbox %s" % [e.spec.name, str(e.spec.size)])
		var warned := -1
		var released := -1
		for f in 420:
			await get_tree().physics_frame
			if not is_instance_valid(e): break
			if e.windup > 0 and warned < 0: warned = f
			if e.attacks_released > 0:
				released = f
				break
		check(warned >= 0 and released > warned and released - warned >= 18, "%s shows a warning at least 0.3 s before attacking (%d frames)" % [kind, released - warned])
	await clear_combat()
	var old = w.spawn_enemy("task", Vector2(50700, 610))
	await ticks(1)
	check(old.get_child(0).shape.size == Vector2(36, 43) and old.life == 1, "Original archetypes keep their 0.4 hitbox and life")

func swing_now(p) -> void:
	while p.attack_cooldown > 0: await ticks(1)
	Input.action_press("attack")
	await ticks(2)
	Input.action_release("attack")
	await ticks(12)

func stage2_damage_rules() -> void:
	var w = await arena()
	var p = w.player
	p.invulnerable = 999
	p.facing = 1
	var e = w.spawn_enemy("shield", Vector2(50660, 610))
	await ticks(2)
	e.set_physics_process(false)
	await swing_now(p)
	check(is_instance_valid(e) and not e.dead and e.blocks > 0, "La Carpeta Blindada blocks backpack swings")
	e.set_physics_process(true)
	p.position = Vector2(e.position.x, 470)
	p.velocity = Vector2(0, 300)
	await ticks(20)
	check(not is_instance_valid(e) or e.dead, "La Carpeta Blindada falls to a stomp")
	await clear_combat()
	p.position = Vector2(50600, 610)
	p.facing = 1
	var eraser = w.spawn_enemy("stamp", Vector2(50640, 330))
	await ticks(1)
	await swing_now(p)
	check(is_instance_valid(eraser) and eraser.life == 1, "A hanging stamp is out of reach")
	p.position.x = 50560
	for f in 120:
		await ticks(1)
		if eraser.drop_state == "dazed": break
	check(eraser.drop_state == "dazed" and absf(eraser.position.y - 610) < 4, "The stamp drops onto the floor below and stays stuck")
	await swing_now(p)
	check(not is_instance_valid(eraser) or eraser.dead, "A stuck stamp can be defeated")
	await clear_combat()
	p.position = Vector2(50600, 610)
	var calc = w.spawn_enemy("calc", Vector2(50660, 610))
	await ticks(2)
	calc.set_physics_process(false)
	await swing_now(p)
	check(calc.life == 1, "El Profe de Cálculo needs two hits")
	calc.stun = 0
	await swing_now(p)
	check(not is_instance_valid(calc) or calc.dead, "Second hit defeats El Profe de Cálculo")

func stage2_projectiles() -> void:
	var w = await arena()
	var p = w.player
	p.invulnerable = 999
	w.spawn_enemy("calc", Vector2(50950, 610))
	var closest := INF
	var tracked = null
	for f in 360:
		await get_tree().physics_frame
		if tracked == null:
			for shot in get_tree().get_nodes_in_group("projectiles"):
				if shot.glyph == "∫": tracked = shot
		if tracked != null:
			if not is_instance_valid(tracked): break
			closest = minf(closest, tracked.position.distance_to(p.position + Vector2(0, -24)))
	check(closest < 32, "Integral follows its previewed arc onto a standing student (closest %.0f px)" % closest)
	await clear_combat()
	p.position = Vector2(50600, 610)
	p.facing = 1
	p.invulnerable = 0
	var health: int = p.health
	var coder = w.spawn_enemy("coder", Vector2(51000, 610))
	# A freed Object compares equal to null in Godot 4, so detection uses its own flag.
	var bug = null
	var found_bug := false
	var level_y := 0.0
	var steady := true
	for f in 400:
		await get_tree().physics_frame
		if not found_bug:
			for shot in get_tree().get_nodes_in_group("projectiles"):
				if shot.glyph == "bug":
					bug = shot
					found_bug = true
					level_y = shot.position.y
		if found_bug and is_instance_valid(bug):
			if absf(bug.position.y - level_y) > 1: steady = false
			if bug.position.x - p.position.x < 70:
				coder.set_physics_process(false)
				await swing_now(p)
				break
	check(found_bug and steady, "Bugs crawl along the floor")
	check(found_bug and not is_instance_valid(bug) and p.health == health, "A swing smashes an incoming bug before it bites")
	await clear_combat()
	w.fire(Vector2(52380, 602), Vector2(220, 0), Color("b6fa8d"), {"crawl": true, "glyph": "bug", "destructible": true})
	await ticks(20)
	var falling = get_tree().get_nodes_in_group("projectiles")
	check(falling.is_empty() or falling[0].position.y > 615, "Bugs fall off ledges instead of floating")

func stage2_duels() -> void:
	var results := []
	for character in ["alex", "valeria", "diego", "sofia"]:
		for kind in NEW_KINDS:
			var outcome: Dictionary = await duel(character, kind)
			results.append(outcome)
			check(outcome.won, "%s beats %s with normal health (%.1f s, %d hits taken)" % [character, kind, outcome.time, outcome.hits])
	var log := FileAccess.open("res://docs/enemy-duels.txt", FileAccess.WRITE)
	if log:
		for r in results: log.store_line("%s vs %s: %s; time=%.1fs; hits=%d" % [r.character, r.kind, "PASS" if r.won else "FAIL", r.time, r.hits])

func duel(character: String, kind: String) -> Dictionary:
	var w = await arena(character)
	var p = w.player
	p.invulnerable = 0
	var spot := Vector2(51000, 330) if kind == "stamp" else Vector2(51000, 610)
	var e = w.spawn_enemy(kind, spot)
	var damage_before: int = w.damage_taken
	var jump_hold := 0
	var attack_wait := 0
	var won := false
	var frames_used := 0
	for f in 900:
		await get_tree().physics_frame
		frames_used = f
		if not is_instance_valid(e) or e.dead:
			won = true
			break
		if w.lives_lost > 0: break
		var dx: float = e.position.x - p.position.x
		var toward := signf(dx) if dx != 0 else 1.0
		var want := 0.0
		var jump := false
		var attack := false
		var duck := false
		match kind:
			"shield":
				want = toward
				jump = p.is_on_floor() and absf(dx) < 130
			"stamp":
				match e.drop_state:
					"hang": want = toward if absf(dx) > 8 else 0.0
					"warn", "fall": want = -toward if absf(dx) < 110 else 0.0
					"dazed":
						want = toward if absf(dx) > 50 else 0.0
						attack = absf(dx) < 80
			_:
				want = toward if absf(dx) > 55 else 0.0
				attack = absf(dx) < 85
				if kind == "review" and e.windup > 0 and absf(dx) < 340: jump = p.is_on_floor()
				# Read shot lanes like a player: jump low shots, crouch under high ones.
				for shot in get_tree().get_nodes_in_group("projectiles"):
					var rel: Vector2 = shot.position - (p.position + Vector2(0, -20))
					var incoming: bool = signf(shot.velocity.x) == -signf(rel.x) and absf(rel.x) < 150
					if incoming and shot.lane == "high": duck = true
					elif incoming and absf(rel.y) < 90 and (shot.lane == "low" or shot.glyph == "bug"): jump = p.is_on_floor()
		if attack and signf(dx) != p.facing: want = toward
		if duck:
			want = 0.0
			jump = false
			Input.action_press("crouch")
		else: Input.action_release("crouch")
		if want > 0:
			Input.action_release("left")
			Input.action_press("right")
		elif want < 0:
			Input.action_release("right")
			Input.action_press("left")
		else:
			Input.action_release("right")
			Input.action_release("left")
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0: Input.action_release("jump")
		elif jump:
			Input.action_press("jump")
			jump_hold = 18
		attack_wait -= 1
		if attack and attack_wait <= 0:
			Input.action_press("attack")
			attack_wait = 21
		elif attack_wait == 19: Input.action_release("attack")
	release()
	var outcome := {"character": character, "kind": kind, "won": won and w.lives_lost == 0, "time": frames_used / 60.0, "hits": w.damage_taken - damage_before}
	await clear_combat()
	return outcome

# ---------- Stage 2b: personality, lanes, abilities, encounters and El Prefecto ----------
const EnemyScript = preload("res://scripts/enemy.gd")

func wait_for(condition: Callable, frames: int) -> bool:
	for f in frames:
		if condition.call(): return true
		await ticks(1)
	return condition.call()

func stage2b_personality() -> void:
	var w = await arena()
	var p = w.player
	p.invulnerable = 999
	var calc = w.spawn_enemy("calc", Vector2(50900, 610))
	var spoke: bool = await wait_for(func(): return calc.speech_time > 0, 120)
	check(spoke and calc.speech in EnemyScript.VOICE.calc, "El Profe de Cálculo speaks when he spots the student (%s)" % calc.speech)
	var second = w.spawn_enemy("coder", Vector2(50300, 610))
	await ticks(40)
	check(second.voiced and second.speech_time == 0, "Lines are spaced out: a second archetype waits its turn")
	var dizzy: bool = await wait_for(func(): return calc.attacks_released > 0 and calc.windup <= 0 and calc.recovery > 0.8, 240)
	check(dizzy and calc.state == calc.State.ATTACK, "After attacking, the Profe stays dazed for about a second")
	var life: int = calc.life
	p.position = Vector2(calc.position.x - 50, 610)
	p.facing = 1
	await swing_now(p)
	check(calc.life == life - 1, "The dazed window is an opening to strike")

func stage2b_lanes() -> void:
	var w = await arena()
	var p = w.player
	p.invulnerable = 999
	var calc = w.spawn_enemy("calc", Vector2(50950, 610))
	var lanes: Array = []
	var labels: Array = []
	var seen := {}
	for f in 900:
		await get_tree().physics_frame
		if calc.windup > 0 and not seen.has(calc.attack_serial):
			seen[calc.attack_serial] = true
			labels.append(calc.lane_label)
		for shot in get_tree().get_nodes_in_group("projectiles"):
			if not seen.has(shot):
				seen[shot] = true
				lanes.append(shot.lane if shot.lane != "" else "lob")
		if lanes.size() >= 3: break
	check(lanes.slice(0, 3) == ["lob", "low", "high"], "El Profe rotates arc, low and high integrals (%s)" % str(lanes))
	check("¡SALTA!" in labels and "¡AGÁCHATE!" in labels, "The first lane shots spell out the verb to use")
	await clear_combat()
	p.position = Vector2(50600, 610)
	p.invulnerable = 0
	var health: int = p.health
	w.fire(Vector2(50800, 610 - 46), Vector2(-300, 0), Color.WHITE, {"lane": "high", "glyph": "error"})
	await ticks(50)
	check(p.health == health - 1, "A high shot hits a standing student")
	p.invulnerable = 0
	health = p.health
	Input.action_press("crouch")
	await ticks(3)
	w.fire(Vector2(50800, 610 - 46), Vector2(-300, 0), Color.WHITE, {"lane": "high", "glyph": "error"})
	await ticks(50)
	Input.action_release("crouch")
	check(p.health == health, "Crouching clears a high shot")
	await ticks(10)
	p.invulnerable = 0
	health = p.health
	w.fire(Vector2(50800, 610 - 12), Vector2(-300, 0), Color.WHITE, {"lane": "low", "glyph": "∫"})
	await ticks(50)
	check(p.health == health - 1, "A low shot hits a standing student")
	p.invulnerable = 0
	health = p.health
	w.fire(Vector2(50900, 610 - 12), Vector2(-300, 0), Color.WHITE, {"lane": "low", "glyph": "∫"})
	await ticks(50)
	Input.action_press("jump")
	await ticks(30)
	Input.action_release("jump")
	await wait_for(func(): return p.is_on_floor(), 60)
	check(p.health == health, "Jumping clears a low shot")
	await clear_combat()
	p.invulnerable = 0
	p.health = p.max_health
	health = p.health
	var bucket := Area2D.new()
	bucket.set_script(preload("res://scripts/lane_obstacle.gd"))
	bucket.world = w
	bucket.lane = "high"
	bucket.position = Vector2(50600, 610)
	p.position = Vector2(50600, 610)
	p.velocity = Vector2.ZERO
	p.health = p.max_health
	Input.action_press("crouch")
	await ticks(3)
	w.add_child(bucket)
	await ticks(20)
	check(p.health == health, "A crouched student fits under the flying reports")
	Input.action_release("crouch")
	await ticks(20)
	check(p.health == health - 1, "Standing up inside the reports hurts")
	bucket.queue_free()

func stage2b_abilities() -> void:
	var w = await arena("alex")
	var p = w.player
	p.facing = 1
	var task = w.spawn_enemy("task", Vector2(50700, 610))
	await ticks(2)
	task.set_physics_process(true)
	var health: int = p.health
	w.fire(Vector2(50760, 600), Vector2(-200, 0), Color.WHITE, {})
	Input.action_press("ability")
	await ticks(2)
	Input.action_release("ability")
	await ticks(20)
	check((not is_instance_valid(task) or task.dead) and p.health == health, "Alex's dash strikes through an enemy and its shot unharmed")
	w = await arena("diego")
	p = w.player
	Progress.data.shield = false
	var review = w.spawn_enemy("review", Vector2(50760, 610))
	await wait_for(func(): return review.windup > 0, 180)
	w.fire(Vector2(50700, 570), Vector2(-150, 0), Color.WHITE, {})
	Input.action_press("ability")
	await ticks(2)
	Input.action_release("ability")
	check(review.daze > 0.5 and review.windup == 0 and get_tree().get_nodes_in_group("projectiles").filter(func(s): return not s.is_queued_for_deletion()).is_empty(), "Diego's shield burst cancels a charge and clears nearby shots")
	w = await arena("sofia")
	p = w.player
	Input.action_press("ability")
	await ticks(2)
	Input.action_release("ability")
	var calc = w.spawn_enemy("calc", Vector2(50900, 610))
	await wait_for(func(): return calc.windup > 0, 180)
	check(absf(calc.windup_total - 0.62 * 1.35) < 0.01, "Sofía's radar gives warnings 35% more time")

func stage2b_encounters() -> void:
	var expected := {"clase": ["calc", "hopper"], "ventanilla": ["stamp", "stamp"], "laboratorio": ["monitor", "monitor", "coder"]}
	for level in Data.ENCOUNTERS:
		for district in Data.ENCOUNTERS[level]:
			var encounter: String = Data.ENCOUNTERS[level][district]
			release()
			app.start_level(level)
			await ticks(2)
			var w = app.world
			w.set_process(false)
			w.extension.set_process(false)
			var index: int = district * Data.CHUNKS_PER_DISTRICT + 1
			var x0: float = Data.START + index * Data.CHUNK
			w.extension.sync_chunks(x0 + 10)
			await ticks(1)
			var kinds: Array = []
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.is_queued_for_deletion() and e.home.x >= x0 and e.home.x < x0 + Data.CHUNK: kinds.append(e.kind)
			var decor_ok := false
			for node in w.extension.loaded[index].get_children():
				if node.get_script() == preload("res://scripts/encounter_decor.gd") and node.encounter == encounter: decor_ok = true
			var has_all := true
			for k in expected[encounter]: if kinds.count(k) < expected[encounter].count(k): has_all = false
			check(decor_ok and has_all, "Level %d district %d hosts the %s encounter (%s)" % [level, district + 1, encounter, str(kinds)])
	release()
	app.start_level(2)
	await ticks(2)
	var w = app.world
	w.player.invulnerable = 999
	w.player.position = Vector2(Data.START + (1 * Data.CHUNKS_PER_DISTRICT + 1) * Data.CHUNK + 200, 610)
	await ticks(4)
	check(is_instance_valid(app.hud.get("banner")) and app.hud.banner.text == "CLASE DE CÁLCULO", "Entering an encounter shows its banner")

func stage2b_prefect() -> void:
	release()
	Progress.data.character = "alex"
	app.start_level(1)
	await ticks(2)
	var w = app.world
	var p = w.player
	w.set_process(false)
	var begin := float(Data.START + 6 * Data.DISTRICT)
	w.extension.set_process(false)
	var lows := 0
	var highs := 0
	for index in range(6 * Data.CHUNKS_PER_DISTRICT, 7 * Data.CHUNKS_PER_DISTRICT):
		w.extension.sync_chunks(Data.START + index * Data.CHUNK + 10)
		await ticks(1)
		for o in get_tree().get_nodes_in_group("obstacles"):
			if o.is_queued_for_deletion() or o.has_meta("counted"): continue
			o.set_meta("counted", true)
			if o.lane == "low": lows += 1
			else: highs += 1
	check(lows == 5 and highs == 4, "The pursuit course teaches jumps, then slides, then mixes them (%d low, %d high)" % [lows, highs])
	w.extension.set_process(true)
	p.invulnerable = 999
	p.position = Vector2(begin + 420, 610)
	p.camera.reset_smoothing()
	var started: bool = await wait_for(func(): return is_instance_valid(w.prefect), 30)
	check(started and app.hud.has("banner"), "El Prefecto enters the pursuit district with a banner")
	var walker_caught: bool = await wait_for(func(): return w.prefect.catches > 0, 400)
	check(walker_caught, "A student who stands still gets caught")
	w.respawn()
	await ticks(2)
	check(not is_instance_valid(w.prefect) or w.prefect.is_queued_for_deletion(), "Respawning clears the chase")
	# Speed race only: obstacles with real damage are covered by the vulnerable route matrix.
	p.invulnerable = 999
	p.position = Vector2(begin + 420, 610)
	p.velocity = Vector2.ZERO
	await wait_for(func(): return is_instance_valid(w.prefect), 30)
	var chaser = w.prefect
	Input.action_press("right")
	Input.action_press("run")
	var slip_at: float = chaser.slip_x
	var passed: bool = await wait_for(func(): return p.position.x > slip_at + 60, 1200)
	var clean: bool = is_instance_valid(chaser) and chaser.catches == 0
	release()
	var slipped: bool = await wait_for(func(): return w.extension.prefect_done.has(6), 300)
	check(passed and clean, "A running student stays ahead of El Prefecto")
	check(slipped, "El Prefecto slips on his own wet-floor sign at the end of the district")
