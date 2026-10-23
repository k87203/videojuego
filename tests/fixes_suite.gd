extends Node
## Regression checks for the 0.4.1 code-review fixes, in the real engine with an isolated profile.
const Data = preload("res://scripts/expansion_data.gd")
const Layout = preload("res://scripts/level_data.gd")
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
	for action in ["left", "right", "run", "jump", "attack", "ability", "interact"]: Input.action_release(action)

func swing() -> void:
	# Press on the first frame the 0.34 s attack cooldown allows.
	while app.world.player.attack_cooldown > 0: await ticks(1)
	Input.action_press("attack")
	await ticks(2)
	Input.action_release("attack")
	await ticks(14)

func find_uid(w, uid: String):
	for prop in w.all_props():
		if prop.world == w and prop.uid == uid and not prop.is_queued_for_deletion(): return prop
	return null

func fresh_level(level: int, character: String = "alex", resume: bool = false):
	release()
	Progress.data.character = character
	app.start_level(level, resume)
	await ticks(3)
	var w = app.world
	w.player.invulnerable = 999
	return w

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	seed(7)
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(3)
	await boss_shield()
	await normal_damage()
	await quiz_order()
	await arena_sign()
	await diego_ability()
	await shield_between_students()
	await unique_rewards()
	check(Data.valid_checkpoint(Data.checkpoint_x(4)) and not Data.valid_checkpoint(Data.checkpoint_x(5)), "Simplified beacon rule keeps one checkpoint per district")
	print("FIXES RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report := FileAccess.open("res://docs/fixes-results.txt", FileAccess.WRITE)
	if report: report.store_string("%d checks; %d failures\n%s\n" % [checks, failures.size(), "\n".join(failures)])
	release()
	app.queue_free()
	Sound.shutdown()
	await ticks(3)
	await get_tree().create_timer(.2).timeout
	OS.delay_msec(250)
	get_tree().quit(0 if failures.is_empty() else 1)

func boss_shield() -> void:
	var w = await fresh_level(3)
	var p = w.player
	var b = w.boss
	w.eagle.help_timer = 999
	p.position = Vector2(b.home.x - 60, 610)
	p.facing = 1
	await ticks(4)
	check(b.active, "Boss arena activates for the shield test")
	b.vulnerable = 0
	b.cycle = 0
	var health: int = b.health
	var labels_before: int = w.fx.labels.size()
	await swing()
	var escudo := 0
	for label in w.fx.labels: if label.text == "ESCUDO": escudo += 1
	check(b.shield_feedbacks == 1 and escudo == 1 and b.health == health, "One swing against the shield shows ESCUDO and plays its sound exactly once")
	check(w.fx.labels.size() - labels_before <= 2, "A shielded swing no longer floods floating text")
	# Second swing at the 0.34 s cooldown lands inside the 0.4 s feedback window.
	b.cycle = 0
	p.attack_hits.clear()
	await ticks(5)
	await swing()
	check(p.attack_hits.has(b.get_instance_id()) and b.shield_feedbacks == 1, "ESCUDO feedback waits about 0.4 s before repeating")
	b.cycle = 0
	await ticks(20)
	await swing()
	check(b.shield_feedbacks == 2 and b.health == health, "After the short cooldown the shield gives feedback again")
	b.expose(3)
	b.hurt_timer = 0
	await swing()
	check(b.health == health - 1, "An exposed boss still takes exactly one damage per swing")

func normal_damage() -> void:
	var w = await fresh_level(1)
	var p = w.player
	w.set_process(false)
	w.extension.set_process(false)
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	await ticks(2)
	p.position = Vector2(2000, 610)
	p.facing = 1
	var task = w.spawn_enemy("task", Vector2(2045, 610))
	var robot = w.spawn_enemy("robot", Vector2(2060, 610))
	await ticks(2)
	await swing()
	check(not is_instance_valid(task) or task.dead, "A single swing still defeats a one-hit task")
	check(robot.life == 1, "A full swing registers only one hit on a robot")
	await ticks(8)
	await swing()
	check(not is_instance_valid(robot) or robot.dead, "Robot still needs exactly two swings")
	var stunned = w.spawn_enemy("robot", Vector2(2060, 610))
	await ticks(2)
	stunned.stun = 0.06
	await swing()
	check(is_instance_valid(stunned) and stunned.life == 1, "A swing that starts during stun still lands once the stun ends")
	stunned.queue_free()

func quiz_order() -> void:
	var w = await fresh_level(2)
	var terminal
	for prop in w.all_props(): if prop.kind == "quiz": terminal = prop
	var positions := {}
	var same_style := true
	var all_options := true
	for attempt in 12:
		app.quiz(terminal)
		var texts: Array = []
		var reference: StyleBoxFlat = app.quiz_buttons[0].get_theme_stylebox("normal")
		for i in app.quiz_buttons.size():
			var b: Button = app.quiz_buttons[i]
			texts.append(b.text)
			var style: StyleBoxFlat = b.get_theme_stylebox("normal")
			if style.bg_color != reference.bg_color or b.get_theme_color("font_color") != app.quiz_buttons[0].get_theme_color("font_color"): same_style = false
			if b.text == "8 bits": positions[i] = true
		texts.sort()
		if texts != ["16 bits", "4 bits", "8 bits"]: all_options = false
		app.resume_game()
	check(same_style, "Every quiz answer has the same style before answering")
	check(all_options, "The quiz always offers the same three answers")
	check(positions.size() >= 2, "The correct answer changes position between attempts (%d positions seen)" % positions.size())
	app.quiz(terminal)
	for b in app.quiz_buttons:
		if b.text == "16 bits": b.pressed.emit(); break
	await ticks(2)
	check(not terminal.active, "A wrong answer is rejected by value")
	app.quiz(terminal)
	for b in app.quiz_buttons:
		if b.text == "8 bits": b.pressed.emit(); break
	await ticks(2)
	check(terminal.active and Progress.data.shield, "The correct answer is accepted by value in any position")

func arena_sign() -> void:
	for level in [3, 4]:
		var w = await fresh_level(level)
		var d := Layout.layout(level)
		var sign_x := -1.0
		for prop in w.all_props():
			if prop.kind == "sign" and prop.text.begins_with("Combate"): sign_x = prop.position.x
		check(sign_x == d.arena_sign_x and sign_x < d.arena_gate_x and d.arena_gate_x - sign_x <= 200, "Level %d combat sign stands just before the arena gate (x=%d)" % [level, int(sign_x)])
		check(sign_x >= w.level_length - 3000, "Level %d combat sign sits on the arena's solid ground" % level)

func diego_ability() -> void:
	var w = await fresh_level(1, "diego")
	var p = w.player
	check(Progress.data.shield, "Diego starts the level with his shield")
	Input.action_press("ability")
	await ticks(2)
	Input.action_release("ability")
	var warned := false
	for label in w.fx.labels: if label.text == "Ya tienes escudo": warned = true
	check(p.ability_cooldown == 0 and Progress.data.shield and warned, "Q with an active shield keeps the cooldown and shows a warning")
	Progress.data.shield = false
	await ticks(2)
	Input.action_press("ability")
	await ticks(2)
	Input.action_release("ability")
	check(Progress.data.shield and p.ability_cooldown > 13, "Q without a shield activates it and starts the 14 s cooldown")

func shield_between_students() -> void:
	var w = await fresh_level(1, "diego")
	check(Progress.data.shield, "Diego's level begins shielded")
	w = await fresh_level(1, "alex")
	check(not Progress.data.shield, "Alex does not inherit Diego's shield")
	Progress.data.shield = true
	w = await fresh_level(2, "alex")
	check(not Progress.data.shield, "Starting a level resets a leftover shield to the student default")
	app.show_menu()
	app.character_select(false)
	await ticks(2)
	Progress.data.shield = true
	for child in app.ui.get_children():
		if child is Button and child.text == "Elegir Sofía": child.pressed.emit(); break
	await ticks(2)
	check(Progress.data.character == "sofia" and not Progress.data.shield, "Changing student clears the shield")
	Progress.save_path = "user://fixes-shield-%d.json" % Time.get_ticks_usec()
	Progress.session_only = false
	Progress.data.shield = true
	Progress.save_game()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Progress.save_path))
	check(parsed is Dictionary and not parsed.has("shield"), "The save file never stores the shield")
	parsed["shield"] = true
	var legacy := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify(parsed))
	legacy.close()
	Progress.reset_data()
	Progress.load_game()
	check(not Progress.data.shield and Progress.data.character == "sofia", "An old save with a stored shield loads without it")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = Progress.SAVE_PATH
	Progress.session_only = true
	app.show_menu()

func unique_rewards() -> void:
	var w = await fresh_level(1)
	w.set_process(false)
	w.extension.set_process(false)
	var heart_id: String = w.extension.stable(0, "heart", 650)
	var power_id: String = w.extension.stable(0, "power", 850)
	check(heart_id == "ex_1_0_heart_650" and power_id == "ex_1_0_power_850", "Rest-stop rewards use level, chunk and position IDs")
	w.extension.sync_chunks(Data.START + 10)
	await ticks(2)
	var heart = find_uid(w, heart_id)
	var power = find_uid(w, power_id)
	check(heart != null and power != null and not heart.collected, "Rest-stop heart and power-up spawn on first visit")
	heart.collect()
	power.collect()
	check(w.consumed_ids.has(heart_id) and w.consumed_ids.has(power_id), "Collected consumables are registered")
	w.extension.sync_chunks(Data.START + 12 * Data.CHUNK)
	await ticks(2)
	check(find_uid(w, heart_id) == null, "Leaving the area unloads the rest-stop chunk")
	w.extension.sync_chunks(Data.START + 10)
	await ticks(2)
	heart = find_uid(w, heart_id)
	power = find_uid(w, power_id)
	check(heart != null and heart.collected and not heart.visible and power.collected, "Returning to the chunk does not respawn collected rewards")
	var intro = find_uid(w, "1_heart_x3200")
	check(intro != null, "Intro hearts have position-based IDs")
	intro.collect()
	w.checkpoint = Vector2(Data.START + 140, 610)
	w.save_snapshot()
	w = await fresh_level(1, "alex", true)
	w.set_process(false)
	await ticks(2)
	var restored_heart = find_uid(w, heart_id)
	var restored_intro = find_uid(w, "1_heart_x3200")
	check(restored_heart != null and restored_heart.collected and restored_intro.collected, "Consumed rewards stay collected after saving and continuing")
	w = await fresh_level(1)
	check(not find_uid(w, "1_heart_x3200").collected, "Restarting a level from zero restores its consumables")
