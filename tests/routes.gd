extends Node
## Geometry traversal with real input + physics. Invulnerability isolates geometry from combat.
var app
var failed := false
var report := ""
var focused := false
## --route-vulnerable: real damage; health refills on entering each chunk, so a death means one chunk is unsurvivable at full health.
var vulnerable := false

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	Engine.time_scale = 1
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	var levels := [1, 2, 3, 4]
	var start_x := 0.0
	var route_length := 0.0
	var character_override := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route-level="): levels = [int(arg.trim_prefix("--route-level="))]; focused = true
		if arg.begins_with("--route-start="): start_x = float(arg.trim_prefix("--route-start=")); focused = true
		if arg.begins_with("--route-length="): route_length = float(arg.trim_prefix("--route-length=")); focused = true
		if arg.begins_with("--route-character="): character_override = arg.trim_prefix("--route-character=")
		if arg == "--route-vulnerable": vulnerable = true
	for level in levels:
		for action in ["right", "left", "run", "jump", "attack", "interact"]: Input.action_release(action)
		Progress.data.character = character_override if character_override != "" else preload("res://scripts/characters.gd").IDS[level - 1]
		app.start_level(level)
		app.set_process(false) # UI rendering is verified separately; keep world/physics active.
		Progress.data.double_jump = level > 1 or start_x > 1510
		var w = app.world
		var p = w.player
		p.invulnerable = 0 if vulnerable else 999
		var chunk := -999
		var chunk_damage := 0
		var worst_chunk := 0
		var worst_index := -1
		if start_x > 0: p.position = Vector2(start_x, 610)
		var lives: int = Progress.data.lives
		var jump_hold := 0
		var success := false
		var previous_pos := Vector2.ZERO
		var stalled := 0
		var steering := false
		Input.action_press("right")
		Input.action_press("run")
		for frame in 50000:
			previous_pos = p.position
			await get_tree().physics_frame
			stalled = stalled + 1 if absf(p.position.x - previous_pos.x) < 0.1 else 0
			if vulnerable:
				var index := int(floor((p.position.x - 6600) / 1200.0))
				if index != chunk:
					chunk = index
					chunk_damage = w.damage_taken
					p.health = p.max_health
				if w.damage_taken - chunk_damage > worst_chunk:
					worst_chunk = w.damage_taken - chunk_damage
					worst_index = chunk
			if stalled == 120:
				print("ROUTE STALL x=%s velocity=%s floor=%s jumps=%d" % [str(p.position), str(p.velocity), p.is_on_floor(), p.jumps])
			if frame % 24 == 0: Input.action_press("attack")
			elif frame % 24 == 2: Input.action_release("attack")
			if level == 3:
				for child in w.get_children():
					if child.get_script() == preload("res://scripts/prop.gd") and child.kind == "switch" and child.inside:
						if frame % 4 == 0: Input.action_press("interact")
						elif frame % 4 == 2: Input.action_release("interact")
			if jump_hold > 0:
				jump_hold -= 1
				if jump_hold == 0: Input.action_release("jump")
			var ray := PhysicsRayQueryParameters2D.create(p.position + Vector2(95, -10), p.position + Vector2(95, 120), 1)
			var gap: bool = p.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
			var wall_ray := PhysicsRayQueryParameters2D.create(p.position + Vector2(0, -30), p.position + Vector2(85, -30), 1)
			var step_ahead: bool = not p.get_world_2d().direct_space_state.intersect_ray(wall_ray).is_empty()
			var danger := false
			for child in get_tree().get_nodes_in_group("hazards"):
				if child.position.x - p.position.x > -20 and child.position.x - p.position.x < 110: danger = true
			if p.is_on_floor() and jump_hold == 0 and (gap or danger or step_ahead or stalled > 12):
				Input.action_press("jump")
				jump_hold = 20
			elif not p.is_on_floor() and gap and p.velocity.y > 40 and p.jumps < 2 and Progress.data.double_jump and jump_hold == 0:
				Input.action_press("jump")
				jump_hold = 16
			# Air control, as a player would: with no jumps left and no floor at the predicted
			# landing point, stop pushing forward and drift back to the last floor.
			var out_of_jumps: bool = p.jumps >= 2 or not Progress.data.double_jump
			if not p.is_on_floor() and p.velocity.y > 0 and out_of_jumps and not steering:
				var fall_time: float = (-p.velocity.y + sqrt(p.velocity.y * p.velocity.y + 2.0 * 1450.0 * maxf(0.0, 610.0 - p.position.y))) / 1450.0
				var landing_x: float = p.position.x + p.velocity.x * fall_time
				var landing := PhysicsRayQueryParameters2D.create(Vector2(landing_x, p.position.y - 10), Vector2(landing_x, 700), 1)
				if p.get_world_2d().direct_space_state.intersect_ray(landing).is_empty():
					steering = true
					Input.action_release("right")
					Input.action_press("left")
			elif steering and p.is_on_floor():
				steering = false
				Input.action_release("left")
				Input.action_press("right")
			var goal: float = start_x + route_length if route_length > 0 else (w.level_length - 270 if level < 3 else w.boss.home.x - 400)
			if p.position.x > goal:
				success = true
				break
			if w.lives_lost > 0:
				break
		var line := "Level %d (%s): %s; x=%.1f; previous=%s; lives_lost=%d; key=%s; switch=%s; duration=%.1fs; trials=%d; streamed=%d" % [level, p.character_id, "PASS" if success else "FAIL", p.position.x, str(previous_pos), w.lives_lost, w.has_credential, w.switch_on, w.level_time, w.trials_completed.size(), w.extension.loaded.size()]
		if vulnerable: line += "; vulnerable; damage=%d; worst_chunk=%d (index %d)" % [w.damage_taken, worst_chunk, worst_index]
		print(line)
		report += line + "\n"
		if not success: failed = true
		await get_tree().process_frame
	for action in ["right", "left", "run", "jump", "attack", "interact"]: Input.action_release(action)
	var file := FileAccess.open("res://docs/route-encounter-results.txt" if vulnerable else ("res://docs/route-focus-results.txt" if focused else "res://docs/route-results.txt"), FileAccess.WRITE)
	if file: file.store_string(report)
	app.queue_free()
	Sound.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(1 if failed else 0)
