extends Node
## Defeats bosses through movement, jump and attack input. Normal three-heart health.
## Only the initial arena placement is a fixture; boss health/timers are never altered.
var app
var failed := false
var report := ""

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	seed(17)
	call_deferred("run")

func release() -> void:
	for action in ["left", "right", "run", "jump", "attack"]: Input.action_release(action)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	for battle in 8:
		var level := 3 + battle % 2
		Progress.data.character = preload("res://scripts/characters.gd").IDS[battle / 2]
		seed(17)
		release()
		Progress.data.shield = false
		Progress.data.double_jump = true
		app.start_level(level)
		var w = app.world
		var p = w.player
		p.position = Vector2(w.boss.home.x - 420, 610)
		var jump_hold := 0
		var attack_hold := 0
		var elapsed_frames := 0
		for frame in 10800:
			await get_tree().physics_frame
			elapsed_frames = frame
			if w.boss.dead or w.lives_lost > 0: break
			if frame % 600 == 0:
				print("COMBAT %d: t=%ds player=%d boss=%d phase=%d" % [level, frame / 60, p.health, w.boss.health, w.boss.phase])
			var target_x: float = w.boss.position.x - (78 if w.boss.vulnerable > 0 else 275)
			target_x = clampf(target_x, w.boss.home.x - 500, w.boss.home.x + 260)
			Input.action_release("left")
			Input.action_release("right")
			if absf(target_x - p.position.x) > 10:
				Input.action_press("right" if target_x > p.position.x else "left")
			elif w.boss.position.x > p.position.x:
				if p.facing < 0: Input.action_press("right")
			var danger := false
			for shot in get_tree().get_nodes_in_group("projectiles"):
				var rel: Vector2 = shot.position - (p.position + Vector2(0, -30))
				if rel.length() < 115 and rel.dot(shot.velocity) < 0 and absf(rel.y) < 75: danger = true
			var nearby_enemy := false
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if p.position.distance_to(enemy.position) < 110:
					nearby_enemy = true
			if w.boss.windup > 0 and w.boss.attack_kind == "dash": danger = true
			if jump_hold > 0:
				jump_hold -= 1
				if jump_hold == 0: Input.action_release("jump")
			if p.is_on_floor() and jump_hold == 0 and (danger or nearby_enemy):
				Input.action_press("jump")
				jump_hold = 20
			if attack_hold > 0:
				attack_hold -= 1
				if attack_hold == 0: Input.action_release("attack")
			elif (w.boss.vulnerable > 0 and p.position.distance_to(w.boss.position) < 108) or nearby_enemy:
				Input.action_press("attack")
				attack_hold = 2
		var success: bool = w.boss.dead and w.lives_lost == 0
		var line := "COMBAT RESULT level=%d character=%s %s time=%.1fs hearts=%d damage=%d deaths=%d phases=%s" % [level, p.character_id, "PASS" if success else "FAIL", elapsed_frames / 60.0, p.health, w.damage_taken, w.lives_lost, str(w.boss.phase_history)]
		print(line)
		report += line + "\n"
		if not success: failed = true
		release()
		await get_tree().process_frame
	var file := FileAccess.open("res://docs/combat-results.txt", FileAccess.WRITE)
	if file: file.store_string(report)
	app.queue_free()
	Sound.shutdown()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(1 if failed else 0)
