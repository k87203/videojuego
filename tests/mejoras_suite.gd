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
