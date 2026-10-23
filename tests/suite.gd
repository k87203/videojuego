extends Node
## Actual-engine integration checks. Uses an isolated save file, never the player's save.
var app
var failures: Array[String] = []
var checks := 0
var checkpoint_fixture: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func ticks(count: int) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Progress.session_only = true
	Progress.reset_data()
	Engine.time_scale = 1
	call_deferred("run")

func release_inputs() -> void:
	for action in ["right", "left", "jump", "run", "crouch", "attack", "interact"]: Input.action_release(action)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(3)
	check(app.screen == "menu", "Main menu constructed")
	app.level_select()
	await ticks(2)
	check(app.screen == "levels", "Level selection opens")
	app.settings("menu")
	await ticks(2)
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Effects") >= 0, "Independent audio buses")
	app.start_level(1)
	await ticks(20)
	var w = app.world
	var p = w.player
	check(p.is_on_floor() and absf(p.position.y - 610) < 2, "Player settles on floor")
	Input.action_press("right")
	await ticks(12)
	Input.action_release("right")
	check(p.position.x > 210, "Accelerated horizontal movement")
	await ticks(15)
	check(absf(p.velocity.x) < 1, "Deceleration reaches rest")
	# Buffer while descending; double jump remains locked for this assertion.
	p.position = Vector2(400, 560)
	p.velocity = Vector2(0, 330)
	p.coyote = 0
	await ticks(3)
	p.coyote = 0
	Input.action_press("jump")
	await ticks(8)
	check(p.velocity.y < -300, "Buffered jump fires immediately after landing")
	Input.action_release("jump")
	await ticks(60)
	p.position = Vector2(1048, 610)
	p.velocity = Vector2(360, 0)
	Input.action_press("right")
	Input.action_press("run")
	await ticks(6)
	Input.action_press("jump")
	await ticks(2)
	check(p.velocity.y < -300, "Coyote jump works after leaving edge")
	release_inputs()
	p.position = Vector2(400, 610)
	p.velocity = Vector2.ZERO
	await ticks(10)
	Input.action_press("jump")
	await ticks(2)
	check(p.velocity.y < -300, "Jump starts upward")
	Input.action_release("jump")
	await ticks(2)
	check(p.velocity.y > -330, "Early release shortens jump")
	await ticks(60)
	Progress.data.double_jump = true
	Input.action_press("jump")
	await ticks(8)
	Input.action_release("jump")
	await ticks(3)
	Input.action_press("jump")
	await ticks(2)
	check(p.jumps == 2 and p.velocity.y < -350, "Unlocked air jump")
	release_inputs()
	await ticks(65)
	p.position = Vector2(180, 610)
	p.velocity = Vector2.ZERO
	await ticks(6)
	Input.action_press("right")
	Input.action_press("run")
	await ticks(24)
	Input.action_press("crouch")
	await ticks(2)
	check(p.crouched and p.shape.shape.height == 30 and p.slide_time > 0, "Slide changes collision capsule")
	release_inputs()
	await ticks(40)
	p.position = Vector2(400, 610)
	p.velocity = Vector2.ZERO
	p.health = 3
	p.invulnerable = 0
	Progress.data.shield = true
	p.hurt(p.position - Vector2(50, 0))
	check(p.health == 3 and not Progress.data.shield, "Scholarship absorbs one hit")
	p.invulnerable = 0
	p.hurt(p.position - Vector2(50, 0))
	check(p.health == 2, "Damage removes health")
	var life_before := int(Progress.data.lives)
	Progress.credit(100)
	check(int(Progress.data.lives) == life_before + 1, "100 credits grant one life")
	w.checkpoint = Vector2(1370, 610)
	w.fall_respawn()
	check(p.position.distance_to(w.checkpoint) < 2 and p.health == 3, "Fall respawns at checkpoint")
	app.pause_game()
	var pause_pos: Vector2 = p.position
	await ticks(6)
	check(p.position == pause_pos and get_tree().paused, "Pause freezes gameplay")
	app.resume_game()
	await ticks(3)
	check(not get_tree().paused, "Resume restores physics")
	Progress.data.lives = 1
	p.health = 1
	p.invulnerable = 0
	p.hurt(p.position - Vector2(50, 0))
	check(app.screen == "game_over" and int(Progress.data.lives) == 0 and Progress.checkpoint_state(1).has("x"), "Last hit opens Game Over and records exhausted lives")
	app.retry_level()
	await ticks(5)
	w = app.world
	p = w.player
	check(not get_tree().paused and int(Progress.data.lives) == 4 and p.health == 3, "Game Over retry restores four lives and active controls")
	# Natural AI transition via Area2D and line of sight.
	var e = w.spawn_enemy("task", Vector2(1700, 610))
	p.position = Vector2(1850, 610)
	p.invulnerable = 100
	await ticks(55)
	check(e.state_history.has(e.State.ALERT) and e.state_history.has(e.State.CHASE), "Enemy senses and chases player")
	p.position = Vector2(3700, 610)
	await ticks(170)
	check(e.state_history.has(e.State.SEARCH) and e.state_history.has(e.State.RETURN), "Enemy searches and returns after losing player")
	# Instantiate every stage and exercise objective gates, rewards and victory state.
	for level in range(1, 5):
		release_inputs()
		app.start_level(level)
		await ticks(20)
		w = app.world
		p = w.player
		p.invulnerable = 999
		check(w.get_child_count() > 75, "Level %d has populated geometry and rewards" % level)
		w.try_complete()
		check(not w.completed, "Level %d rejects premature completion" % level)
		if level == 2:
			var credential = find_prop(w, "credential")
			credential.collect()
			await ticks(3)
			check(w.has_credential, "Credential pickup unlocks library")
			var quiz = find_prop(w, "quiz")
			app.quiz(quiz)
			for child in app.ui.get_children():
				if child is Button and child.text == "8 bits": child.pressed.emit(); break
			await ticks(2)
			check(quiz.active and Progress.data.shield, "Academic question grants reward")
			w.checkpoint = Vector2(2880, 610)
			w.save_snapshot()
			app.start_level(2, true)
			await ticks(3)
			w = app.world
			p = w.player
			p.invulnerable = 999
			check(absf(p.position.x - 2880) < 2 and find_prop(w, "quiz").active, "Continue restores checkpoint and solved academic question")
		if level == 3:
			var switch = find_prop(w, "switch")
			p.position = switch.position
			p.velocity = Vector2.ZERO
			await ticks(3)
			Input.action_press("interact")
			await ticks(2)
			Input.action_release("interact")
			await ticks(2)
			check(w.switch_on, "Switch opens laboratory gate")
			w.checkpoint = Vector2(4950, 610)
			w.save_snapshot()
			checkpoint_fixture = Progress.checkpoint_state(3).duplicate(true)
			app.start_level(3, true)
			await ticks(3)
			w = app.world
			p = w.player
			p.invulnerable = 999
			check(absf(p.position.x - 4950) < 2 and w.switch_on, "Continue restores laboratory checkpoint and gate switch")
		if level >= 3:
			p.position = Vector2(w.boss.home.x - 400, 610)
			await ticks(4)
			check(w.boss.active and w.arena_closed, "Boss %d activates arena" % level)
			var before: int = w.boss.health
			w.boss.vulnerable = 0
			w.boss.hit()
			check(w.boss.health == before, "Boss shield rejects damage")
			w.eagle.help_timer = 0
			await ticks(3)
			check(w.boss.vulnerable > 0, "Aztli exposes boss")
			for i in w.boss.max_health:
				w.boss.expose(3)
				w.boss.hurt_timer = 0
				w.boss.hit()
				await ticks(2)
			check(w.boss.dead and not w.arena_closed, "Boss %d defeated and arena unlocked" % level)
			if level == 4: check(w.boss.phase_history == [1, 2, 3], "Final boss executes all three phases")
		w.trials_completed = {"trial_3": true, "trial_9": true, "trial_15": true}
		var fragment = find_prop(w, "fragment")
		check(fragment != null, "Level %d provides title fragment" % level)
		if fragment: fragment.collect()
		w.try_complete()
		await ticks(2)
		check(w.completed and app.screen == "results", "Level %d reaches results" % level)
	check(Progress.data.fragments.size() == 4 and Progress.data.graduated, "Campaign tracks all four documents and graduation")
	app.graduation()
	await ticks(3)
	check(app.screen == "graduation", "Graduation finale opens")
	# Real file round-trip, using a unique disposable path in user://.
	Progress.save_path = "user://integration-save-%d.json" % Time.get_ticks_usec()
	Progress.session_only = false
	Progress.data.checkpoints["3"] = checkpoint_fixture
	Progress.save_game()
	Progress.data.score += 25
	Progress.save_game()
	var saved_score: int = Progress.data.score
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.score == saved_score and Progress.data.graduated and Progress.data.fragments.size() == 4, "Save overwrites atomically and restores progression")
	check(1 in Progress.data.fragments and 2 in Progress.data.fragments and 3 in Progress.data.fragments and 4 in Progress.data.fragments, "Saved fragment IDs still unlock all four completion gates")
	check(Progress.checkpoint_state(3).get("x") == 4950 and Progress.checkpoint_state(3).get("switch"), "Checkpoint data survives real save-file reload")
	var bad_save := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	bad_save.store_string("{broken save")
	bad_save.close()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.unlocked == 1 and Progress.data.lives == 4, "Corrupt save falls back safely")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = Progress.SAVE_PATH
	Progress.session_only = true
	app.show_menu()
	await ticks(3)
	release_inputs()
	Engine.time_scale = 1
	print("INTEGRATION RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report := FileAccess.open("res://docs/test-results.txt", FileAccess.WRITE)
	if report: report.store_string("Godot %s\n%d checks; %d failures\n%s\n" % [Engine.get_version_info().string, checks, failures.size(), "\n".join(failures)])
	app.queue_free()
	Sound.shutdown()
	await ticks(3)
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(0 if failures.is_empty() else 1)

func find_prop(w, kind: String):
	for child in w.get_children():
		if child.get_script() == preload("res://scripts/prop.gd") and child.kind == kind and not child.collected: return child
	return null
