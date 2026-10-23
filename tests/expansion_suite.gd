extends Node
## New systems exercised in the engine, using an isolated profile and controlled fixtures.
const Data = preload("res://scripts/expansion_data.gd")
const Characters = preload("res://scripts/characters.gd")
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
	for action in ["left", "right", "run", "jump", "attack", "ability"]: Input.action_release(action)

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	app.character_select(false)
	await ticks(3)
	var portraits := 0
	for child in app.ui.get_children():
		if child.get_script() == preload("res://scripts/menu_actor.gd"): portraits += 1
	check(app.screen == "characters" and portraits == 4, "Four animated character portraits")
	for child in app.ui.get_children():
		if child is Button and child.text == "Elegir Sofía":
			child.pressed.emit()
			break
	await ticks(2)
	check(Progress.data.character == "sofia", "Character selection button updates profile")
	for id in Characters.IDS:
		release()
		Progress.data.character = id
		Progress.data.double_jump = false
		Progress.data.shield = false
		app.start_level(1)
		await ticks(12)
		var p = app.world.player
		p.invulnerable = 100
		check(p.character_id == id and p.health == int(Characters.spec(id).health), "%s profile and health" % id)
		Input.action_press("right")
		Input.action_press("run")
		await ticks(18)
		check(p.velocity.x >= float(Characters.spec(id).run) - 2, "%s reaches its running speed" % id)
		release()
		await ticks(12)
		Input.action_press("jump")
		await ticks(5)
		Input.action_release("jump")
		await ticks(2)
		if id == "valeria":
			Input.action_press("ability")
			await ticks(2)
			check(p.jumps == 2 and p.velocity.y < -450 and p.ability_cooldown > 0, "Valeria air jump works before eagle feather")
		else:
			Input.action_press("jump")
			await ticks(2)
			check(p.jumps == 1, "%s respects locked double jump" % id)
			Input.action_release("jump")
			# Diego starts shielded; spend that shield so the ability press tests a real activation.
			if id == "diego": Progress.data.shield = false
			Input.action_press("ability")
			await ticks(2)
			if id == "alex": check(p.dash_time > 0 and absf(p.velocity.x) >= 640, "Alex dash accelerates through actual input")
			if id == "diego":
				p.invulnerable = 0
				p.hurt(p.position - Vector2(50, 0))
				check(p.health == 4 and not Progress.data.shield, "Diego shield absorbs a real hit")
			if id == "sofia": check(p.radar_time > 4 and p.ability_cooldown > 0, "Sofia radar activates through input")
		Input.action_release("ability")
		await ticks(2)
		var cooldown: float = p.ability_cooldown
		Input.action_press("ability")
		await ticks(2)
		check(p.ability_cooldown < cooldown and p.ability_cooldown > 0, "%s ability cannot bypass cooldown" % id)
	release()
	Progress.data.character = "sofia"
	app.start_level(3)
	await ticks(3)
	var w = app.world
	var p = w.player
	p.invulnerable = 999
	# Checkpoint entry, timed delivery success, timeout recovery, and save restoration.
	var start := float(Data.START + 3 * Data.DISTRICT)
	p.position = Vector2(start + 140, 610)
	p.velocity = Vector2.ZERO
	await ticks(5)
	check(absf(w.checkpoint.x - start - 140) < 1, "Streamed checkpoint activates from collision")
	p.position.x = start + 320
	await ticks(3)
	check(w.extension.trial_active and w.extension.trial_remaining > 20, "Delivery starts automatically on entry")
	p.position.x = start + 3410
	await ticks(3)
	check(w.trials_completed.has("trial_3") and not w.extension.trial_active, "Crossing delivery arch records success")
	start = float(Data.START + 9 * Data.DISTRICT)
	p.position = Vector2(start + 320, 610)
	await ticks(3)
	w.extension.trial_remaining = 0.01
	var lives: int = Progress.data.lives
	await ticks(3)
	check(not w.extension.trial_active and absf(p.position.x - start - 140) < 1 and int(Progress.data.lives) == lives, "Timeout returns to beacon without losing a life")
	w.save_snapshot()
	app.start_level(3, true)
	await ticks(4)
	w = app.world
	p = w.player
	p.invulnerable = 999
	check(w.trials_completed.has("trial_3") and absf(w.checkpoint.x - start - 140) < 1, "Continue restores expanded checkpoint and delivery seals")
	# Collected secrets and defeated enemies must not respawn when chunks reload.
	var cache_x := float(Data.START + Data.CHUNK + 765)
	p.position = Vector2(cache_x - 500, 610)
	await ticks(4)
	var cache
	for prop in get_tree().get_nodes_in_group("pickups"):
		if prop.world == w and prop.kind == "cache": cache = prop; break
	check(is_instance_valid(cache) and cache.modulate.a > 0.9, "Sofia detects hidden reward at range")
	var cache_id: String = cache.uid if is_instance_valid(cache) else "missing"
	if is_instance_valid(cache): cache.collect()
	var enemy_id := ""
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.world == w and enemy.uid != "":
			enemy_id = enemy.uid
			while enemy.life > 0:
				enemy.stun = 0
				enemy.hit()
			break
	p.position.x += 18000
	await ticks(4)
	p.position = Vector2(cache_x - 500, 610)
	await ticks(4)
	var duplicate := false
	for prop in get_tree().get_nodes_in_group("pickups"):
		if prop.uid == cache_id and not prop.collected: duplicate = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.uid == enemy_id: duplicate = true
	check(not duplicate and w.defeated_ids.has(enemy_id), "Streaming preserves rewards and defeated enemy IDs")
	check(w.extension.loaded.size() <= 6, "Streaming limits active chunks to six")
	# Real standing contact triggers a crumble, then the platform restores.
	p.position = Vector2(7300, 510)
	p.velocity = Vector2.ZERO
	var ledge = w.platform(Vector2(7200, 510), Vector2(220, 25))
	ledge.crumbling = true
	ledge.break_delay = 0.2
	await ticks(25)
	check(ledge.fallen and ledge.col.disabled, "Standing on unstable platform collapses its collider")
	p.position = Vector2(6800, 610)
	p.velocity = Vector2.ZERO
	await ticks(365)
	check(not ledge.fallen and not ledge.col.disabled and ledge.position == ledge.origin, "Collapsed platform restores for retries")
	# Prevent world context from overwriting the deliberate music event fixtures.
	w.set_process(false)
	MusicManager.enter_level(2)
	check(Sound.current_track == "campus_2", "Exploration chooses level theme")
	check(absf(float(Sound.music.stream.loop_end) / Sound.music.stream.mix_rate - 96.0) < 0.05, "Compressed music loops over its full arrangement")
	MusicManager.context(0.9, false, 0, false)
	check(Sound.current_track == "campus_2_intense", "Difficulty selects synchronized intense arrangement")
	MusicManager.context(0.9, true, 0, false)
	check(Sound.current_track == "urgent_chase" and is_instance_valid(Sound.fade), "Pursuit crossfades into tension music")
	MusicManager.context(0.9, true, 1, false)
	check(Sound.current_track == "epic_boss", "Boss music takes priority over chase")
	MusicManager.context(0.9, true, 3, false)
	check(Sound.current_track == "epic_final", "Third boss phase immediately raises musical intensity")
	MusicManager.context(0, false, 0, false)
	check(Sound.current_track == "epic_final", "Music hysteresis prevents rapid toggling")
	MusicManager.hold = 0
	MusicManager.choose(false)
	check(Sound.current_track == "campus_2", "Music returns smoothly after danger ends")
	await ticks(80)
	MusicManager.context(0, true, 0, false)
	await ticks(33)
	var power := 0.0
	var playing := 0
	for voice in Sound.music_players:
		power += voice.volume_linear * voice.volume_linear
		if voice.playing: playing += 1
	check(playing == 2 and absf(power - pow(db_to_linear(-8.0), 2)) < 0.015, "Crossfade maintains power without an audible volume hole")
	# A real disk round trip and a legacy v0.2 profile without character field.
	Progress.save_path = "user://expansion-test-%d.json" % Time.get_ticks_usec()
	Progress.session_only = false
	Progress.save_game()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.character == "sofia" and Progress.checkpoint_state(3).get("trials", {}).has("trial_3"), "Disk save restores character and expanded progression")
	var old_data := Progress.data.duplicate(true)
	old_data.erase("character")
	old_data.score = 1234
	var file := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.character == "alex" and Progress.data.score == 1234, "Legacy save migrates without losing existing score")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = Progress.SAVE_PATH
	Progress.session_only = true
	release()
	print("EXPANSION RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report := FileAccess.open("res://docs/expansion-results.txt", FileAccess.WRITE)
	if report: report.store_string("%d checks; %d failures\n%s\n" % [checks, failures.size(), "\n".join(failures)])
	app.queue_free()
	Sound.shutdown()
	await ticks(3)
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(0 if failures.is_empty() else 1)
