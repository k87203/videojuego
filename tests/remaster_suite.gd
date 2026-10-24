extends Node
## Behavioral fixtures in real physics; no code/assets from the reference project.
const Data = preload("res://scripts/expansion_data.gd")
var app
var w
var p
var failures: Array[String] = []
var checks := 0

func ticks(n: int) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
	print(("PASS: " if value else "FAIL: ") + message)

func clear_enemies() -> void:
	for group in ["enemies", "projectiles"]:
		for node in get_tree().get_nodes_in_group(group): node.queue_free()
	p.attack_time = 0
	p.velocity = Vector2.ZERO
	await ticks(2)

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	seed(42)
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(3)
	check(app.menu_art.get_script() == preload("res://scripts/menu_showcase.gd"), "New animated menu key art is active")
	var play: Button
	for child in app.ui.get_children():
		if child is Button and child.text.begins_with("INICIAR"): play = child
	check(is_instance_valid(play) and play.has_focus(), "New primary action supports keyboard focus")
	check(Data.LENGTH == 96000 and Data.CHUNKS_PER_DISTRICT == 4, "Only repeated stretches were condensed; four level scenes remain")
	check(Data.valid_checkpoint(Data.migrate_checkpoint(169940, 3)), "Legacy long-course checkpoint maps to a valid short-course beacon")
	check(Data.migrate_checkpoint(224220, 3) == Data.LENGTH - 1380, "Legacy boss checkpoint migrates to the relocated arena")
	Progress.data.checkpoints["1"] = {"x": 169940, "layout": 3, "trials": {"trial_3": true}, "defeated_ids": {"ex_1_134_enemy_0": true}}
	app.start_level(1, true)
	await ticks(3)
	check(app.world.checkpoint.x == Data.migrate_checkpoint(169940, 3) and app.world.trials_completed.has("trial_3"), "Real scene resume migrates an old checkpoint and keeps its delivery seals")
	check(app.world.defeated_ids.has("ex_1_53_enemy_0"), "Defeated enemy IDs follow their original district when the course shrinks")
	app.start_level(1)
	await ticks(3)
	w = app.world
	p = w.player
	w.extension.set_process(false)
	w.set_process(false)
	p.set_physics_process(false)
	p.invulnerable = 999
	w.platform(Vector2(50000, 610), Vector2(800, 220), true)
	w.platform(Vector2(50950, 610), Vector2(1300, 220), true)
	await clear_enemies()
	p.position = Vector2(50550, 610)
	p.velocity.x = 100
	var e = w.spawn_enemy("robot", Vector2(50100, 610))
	e.tier = 2
	await ticks(60)
	check(e.state_history.has(e.State.ALERT) and e.state_history.has(e.State.CHASE) and absf(e.velocity.x) >= 260, "Robot detects motion and accelerates into a faster chase")
	await clear_enemies()
	p.position = Vector2(50240, 610)
	p.velocity.x = 40
	e = w.spawn_enemy("robot", Vector2(50100, 610))
	await ticks(35)
	check(e.windup > 0 and e.attacks_released == 0, "Robot telegraphs before releasing a charge")
	e.hit()
	await ticks(12)
	check(e.life == 1 and e.windup == 0 and e.attacks_released == 0, "A landed hit interrupts the telegraphed attack")
	await clear_enemies()
	p.position = Vector2(50240, 610)
	p.velocity.x = 40
	e = w.spawn_enemy("robot", Vector2(50100, 610))
	var peak := 0.0
	for i in 100:
		await ticks(1)
		peak = maxf(peak, absf(e.velocity.x))
	check(e.attacks_released > 0 and peak >= 400, "Robot charge releases a fast physical burst after its warning")
	await clear_enemies()
	p.position = Vector2(50300, 610)
	e = w.spawn_enemy("virus", Vector2(50160, 610))
	e.tier = 2
	await ticks(2)
	e.change_state(e.State.CHASE)
	e.attack_timer = 2
	p.attack_time = 0.19
	await ticks(2)
	check(e.dodges_performed == 1 and e.dodge_time > 0 and e.velocity.x < 0, "Elite virus backsteps an early attack with a limited dodge")
	await clear_enemies()
	p.position = Vector2(50480, 610)
	p.velocity.x = 80
	e = w.spawn_enemy("clock", Vector2(50100, 430))
	e.tier = 3
	await ticks(120)
	check(e.attacks_released > 0 and e.aim.x > 0.6, "Clock aims and releases its telegraphed projectile pattern")
	await clear_enemies()
	p.position = Vector2(50400, 610)
	var wall = w.platform(Vector2(50260, 200), Vector2(35, 410), true)
	e = w.spawn_enemy("virus", Vector2(50100, 610))
	await ticks(80)
	check(not e.state_history.has(e.State.ALERT), "Solid walls block enemy detection and attack acquisition")
	wall.queue_free()
	p.position = e.position + Vector2(210, 0)
	await ticks(35)
	check(e.state_history.has(e.State.CHASE), "Enemy reacquires player after line of sight opens")
	await clear_enemies()
	p.position = Vector2(51550, 610)
	e = w.spawn_enemy("robot", Vector2(50740, 610))
	e.direction = 1
	e.change_state(e.State.PATROL)
	var safe := true
	for i in 240:
		await ticks(1)
		if e.position.y > 615 or e.position.x > 50810: safe = false
	check(safe, "Patrol checks ledges and never walks into the test void")
	await clear_enemies()
	p.position = Vector2(50175, 610)
	e = w.spawn_enemy("virus", Vector2(50035, 610))
	e.tier = 2
	await ticks(2)
	e.change_state(e.State.CHASE)
	e.attack_timer = 2
	p.attack_time = 0.19
	await ticks(20)
	check(e.position.x >= 50018 and e.position.y <= 615, "A backstep also checks the retreat edge and cannot dodge into a void")
	await clear_enemies()
	p.position = Vector2(50400, 610)
	var obstacle = w.platform(Vector2(50230, 550), Vector2(45, 60), true)
	e = w.spawn_enemy("task", Vector2(50130, 610))
	e.direction = 1
	e.change_state(e.State.CHASE)
	await ticks(70)
	check(e.jumps_performed > 0, "Ground enemy jumps a short obstacle after checking landing and headroom")
	obstacle.queue_free()
	await clear_enemies()
	MusicManager.enter_level(1)
	MusicManager.action(.8, 2)
	check(Sound.current_track == "campus_1_intense", "A single combat event immediately raises musical intensity")
	check(MusicManager.bpm("urgent_chase") > MusicManager.bpm("campus_1") and MusicManager.bpm("epic_final") == 176, "Pursuit and final combat use faster original arrangements")
	check(Sound.music.stream.mix_rate == 32000, "New synthesized score uses the higher-resolution audio source")
	# Real legacy-file migration, including IDs whose kind contains an underscore.
	Progress.save_path = "user://remaster-migration-%d.json" % Time.get_ticks_usec()
	var legacy := Progress.data.duplicate(true)
	legacy.erase("course_revision")
	legacy.collected = ["ex_1_133_cache_0", "ex_1_134_cache_0", "1_feather", "ex_2_22_high_credit_1"]
	var legacy_file := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	Progress.reset_data()
	Progress.load_game()
	var expected := ["ex_1_53_cache_0", "1_feather", "ex_2_8_high_credit_1"]
	check(Progress.data.collected == expected, "Legacy reward IDs migrate by district, deduplicate and retain original intro IDs")
	Progress.session_only = false
	Progress.save_game()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.collected == expected and Progress.data.course_revision == 4, "Saving and reloading cannot apply the course migration a second time")
	var early_build := Progress.data.duplicate(true)
	early_build.erase("course_revision")
	early_build.checkpoints = {"1": {"layout": 4, "x": 6740}}
	early_build.collected = ["ex_1_5_cache_0"]
	legacy_file = FileAccess.open(Progress.save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(early_build))
	legacy_file.close()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.collected == ["ex_1_5_cache_0"], "An early 0.4 checkpoint prevents remapping already condensed reward IDs")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = Progress.SAVE_PATH
	Progress.session_only = true
	print("REMASTER RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report := FileAccess.open("res://docs/remaster-results.txt", FileAccess.WRITE)
	if report: report.store_string("%d checks; %d failures\n%s\n" % [checks, failures.size(), "\n".join(failures)])
	app.queue_free()
	Sound.shutdown()
	await ticks(3)
	await get_tree().create_timer(.2).timeout
	OS.delay_msec(250)
	get_tree().quit(0 if failures.is_empty() else 1)
