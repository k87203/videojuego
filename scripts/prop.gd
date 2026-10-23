extends Area2D
## Pickups and interactables have stable IDs for persistent collection.
var world
var kind := "credit"
var uid := ""
var active := false
var clock := 0.0
var inside := false
var collected := false
var text := ""
var hidden_reward := false
## Consumables tracked per run, so streamed chunks cannot respawn them.
const RUN_REWARDS := ["heart", "coffee", "shield"]

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 90) if kind in ["checkpoint", "exit", "quiz", "switch", "gate", "sign"] else Vector2(35, 38)
	col.shape = rect
	col.position.y = -30 if kind in ["checkpoint", "exit", "quiz", "switch", "gate", "sign"] else 0
	add_child(col)
	body_entered.connect(_entered)
	body_exited.connect(func(body):
		if body == world.player: inside = false)
	if kind in ["credit", "usb", "feather", "fragment", "credential", "cache"] and uid in Progress.data.collected:
		collected = true
		visible = false
		set_deferred("monitoring", false)
	elif kind in RUN_REWARDS and world.consumed_ids.has(uid):
		collected = true
		visible = false
		set_deferred("monitoring", false)

func _entered(body: Node) -> void:
	if body != world.player or collected: return
	set_process(true)
	inside = true
	if kind in ["sign", "exit", "quiz", "switch", "gate", "trial_arch"]: return
	if kind == "checkpoint":
		if not active:
			active = true
			world.checkpoint = position
			world.player.health = world.player.max_health
			world.save_snapshot()
			Sound.sfx("checkpoint")
			world.fx.floating(position + Vector2(-50, -100), "PROGRESO GUARDADO")
		return
	collect()

func collect() -> void:
	if collected: return
	collected = true
	var color := Color("ffda78")
	var message := ""
	match kind:
		"credit":
			Progress.credit()
			world.level_credits += 1
			Sound.sfx("coin", randf_range(0.95, 1.2))
		"coffee":
			world.player.coffee = 12
			message = "CAFÉ • 12 s"
		"shield":
			Progress.data.shield = true
			message = "BECA PROTECTORA"
			color = Color("6ee6de")
		"heart":
			world.player.health = mini(world.player.max_health, world.player.health + 1)
			message = "+ SALUD"
			color = Color("ff90a1")
		"usb":
			Progress.data.usb.append(uid)
			Progress.data.score += 500
			world.secrets += 1
			message = "USB DORADA +500"
			world.say("AZTLI", "¡Un secreto recuperado! Reúne las 8 USB para la mención honorífica.", 4)
		"feather":
			Progress.data.double_jump = true
			message = "DOBLE SALTO DESBLOQUEADO"
			world.say("AZTLI", "Te regalo una de mis plumas. Pulsa salto otra vez en el aire para volar más alto.", 6)
			Sound.sfx("eagle")
		"fragment":
			if not world.level_id in Progress.data.fragments: Progress.data.fragments.append(world.level_id)
			message = "FRAGMENTO DEL TÍTULO"
			Progress.data.score += 1000
		"credential":
			world.has_credential = true
			message = "CREDENCIAL RECUPERADA"
		"cache":
			Progress.credit(15)
			Progress.data.score += 300
			message = "ESCONDITE +300"
	if kind != "credit": Sound.sfx("power")
	if kind in ["credit", "usb", "feather", "fragment", "credential", "cache"]:
		Progress.data.collected.append(uid)
		world.save_snapshot()
	elif kind in RUN_REWARDS:
		world.consumed_ids[uid] = true
		world.save_snapshot()
	world.fx.burst(position, color)
	world.fx.ring(position, color, 24 if kind == "credit" else 54)
	if message != "": world.fx.floating(position + Vector2(-40, -20), message, color)
	visible = false
	set_deferred("monitoring", false)

func _process(delta: float) -> void:
	if collected: return
	if is_instance_valid(world.player):
		visible = absf(position.x - world.player.position.x) < 1050
		if not visible: return
		if hidden_reward:
			var distance: float = position.distance_to(world.player.position)
			var revealed: bool = distance < 150 or (world.player.character_id == "sofia" and distance < 720) or world.player.radar_time > 0
			modulate.a = 1.0 if revealed else 0.15
	clock += delta
	if inside and Input.is_action_just_pressed("interact"):
		match kind:
			"exit": world.try_complete()
			"sign": world.say("CAMPUS", text, 6)
			"quiz": world.show_quiz(self)
			"switch":
				active = true
				world.switch_on = true
				world.save_snapshot()
				Sound.sfx("door")
				world.say("SISTEMA", "Energía restablecida. La compuerta del laboratorio está abierta.", 4)
			"gate": world.say("ACCESO", "Usa la credencial de la biblioteca." if not world.has_credential else "Credencial verificada.", 3)
	queue_redraw()

func _draw() -> void:
	if collected: return
	var t := clock
	var gold := Color("ffd47c")
	var ink := Color("1e3550")
	var teal := Color("6be0d0")
	if kind in ["credit", "coffee", "shield", "heart", "usb", "feather", "fragment", "credential"]:
		draw_set_transform(Vector2(0, sin(t * 3 + position.x) * 5))
		draw_circle(Vector2.ZERO, 25, Color(1, 0.8, 0.4, 0.08))
	match kind:
		"trial_arch":
			for side in [-1, 1]: draw_line(Vector2(side * 52, 0), Vector2(side * 52, -135), teal, 7, true)
			draw_arc(Vector2(0, -135), 52, PI, TAU, 24, teal, 7, true)
			draw_string(ThemeDB.fallback_font, Vector2(-34, -153), "META", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, gold)
		"cache":
			draw_style_box(style(Color("4c8e91")), Rect2(-24, -15, 48, 32))
			draw_style_box(style(gold), Rect2(-26, -18, 52, 10))
			draw_rect(Rect2(-5, -7, 10, 15), gold)
			draw_arc(Vector2.ZERO, 35, t, t + 2.6, 18, Color("a0f6d5"), 2, true)
		"credit":
			draw_circle(Vector2.ZERO, 13, Color("c58e3e"))
			draw_circle(Vector2(-1, -2), 11, gold)
			draw_arc(Vector2(-1, -2), 7, 0, TAU, 24, Color("fff0b8"), 1.5, true)
			draw_string(ThemeDB.fallback_font, Vector2(-5, 4), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a77035"))
		"usb":
			draw_style_box(style(gold), Rect2(-10, -8, 20, 28))
			draw_style_box(style(Color("e5edf2")), Rect2(-7, -20, 14, 13))
			draw_line(Vector2(-3, -16), Vector2(-3, -11), ink, 2)
			draw_line(Vector2(3, -16), Vector2(3, -11), ink, 2)
			draw_circle(Vector2(0, 8), 3, Color("fff6db"))
		"heart":
			draw_circle(Vector2(-7, -4), 9, Color("ff8299"))
			draw_circle(Vector2(7, -4), 9, Color("ff8299"))
			draw_colored_polygon(PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(0, 18)]), Color("ff8299"))
		"coffee":
			draw_style_box(style(Color("fff0d6")), Rect2(-12, -10, 24, 27))
			draw_arc(Vector2(13, 1), 8, -PI / 2, PI / 2, 12, gold, 4, true)
			draw_rect(Rect2(-12, -3, 24, 9), Color("ba8154"))
			for i in 2: draw_line(Vector2(-4 + i * 7, -15), Vector2(-1 + i * 7, -23), Color("c5f2e9"), 2, true)
		"shield":
			draw_colored_polygon(PackedVector2Array([Vector2(-17, -17), Vector2(17, -17), Vector2(14, 7), Vector2(0, 21), Vector2(-14, 7)]), teal)
			draw_line(Vector2(-8, -2), Vector2(-1, 5), ink, 3, true)
			draw_line(Vector2(-1, 5), Vector2(9, -9), ink, 3, true)
		"feather":
			draw_set_transform(Vector2(0, sin(t * 3) * 5), 0.5)
			draw_style_box(style(gold), Rect2(-8, -25, 16, 42))
			draw_line(Vector2(0, -21), Vector2(0, 26), Color("fff6dc"), 2, true)
			for i in 4: draw_line(Vector2(0, -13 + i * 7), Vector2(7, -19 + i * 7), Color("c48b3e"), 1.5, true)
		"fragment", "credential":
			draw_style_box(style(Color("fff2d2")), Rect2(-19, -15, 38, 30))
			draw_rect(Rect2(-14, -9, 28, 5), teal)
			draw_circle(Vector2(9, 7), 5, gold)
			draw_line(Vector2(-13, 4), Vector2(1, 4), ink, 2)
		"checkpoint":
			draw_style_box(style(ink), Rect2(-20, -9, 40, 9))
			draw_line(Vector2(0, -10), Vector2(0, -90), Color("8babbc"), 5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(3, -88), Vector2(47, -80 + sin(t * 3) * 3), Vector2(3, -59)]), teal if active else gold)
			if active:
				draw_circle(Vector2(0, -93), 8, teal)
				draw_circle(Vector2(0, -93), 16, Color(0.4, 1, 0.8, 0.15))
		"exit":
			draw_style_box(style(Color("234660")), Rect2(-37, -110, 74, 110))
			draw_style_box(style(Color("53bcb4")), Rect2(-28, -99, 56, 97))
			draw_circle(Vector2(0, -63), 21, Color("ebd39a"))
			draw_colored_polygon(PackedVector2Array([Vector2(-15, -66), Vector2(0, -75), Vector2(15, -66), Vector2(0, -58)]), ink)
			draw_string(ThemeDB.fallback_font, Vector2(-27, -119), "SALIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
		"quiz":
			draw_style_box(style(Color("365775")), Rect2(-27, -75, 54, 75))
			draw_style_box(style(Color("91e5d4")), Rect2(-21, -66, 42, 32))
			draw_string(ThemeDB.fallback_font, Vector2(-7, -42), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
			draw_line(Vector2(-14, -18), Vector2(14, -18), gold, 4)
		"switch":
			draw_style_box(style(Color("3c5874")), Rect2(-22, -50, 44, 50))
			draw_circle(Vector2(0, -29), 13, teal if active else Color("ff9a86"))
			draw_line(Vector2(0, -29), Vector2(12 if active else -12, -51), gold, 5, true)
		"sign":
			draw_line(Vector2(0, 0), Vector2(0, -55), Color("a77b58"), 6)
			draw_style_box(style(Color("284d68")), Rect2(-31, -75, 62, 34))
			draw_string(ThemeDB.fallback_font, Vector2(-3, -51), "i", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, gold)
	if inside and kind in ["exit", "quiz", "switch", "sign", "gate"]:
		draw_set_transform(Vector2.ZERO)
		draw_style_box(style(Color("fff1d8")), Rect2(-13, -145, 26, 24))
		draw_string(ThemeDB.fallback_font, Vector2(-5, -127), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)

func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color("233950")
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	return s
