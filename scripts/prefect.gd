extends Node2D
## El Prefecto: recurring hallway antagonist of the pursuit districts. He runs behind the
## student a little slower than their sprint, so walking gets you caught and running keeps you
## ahead. At the end of the district he slips on his own "piso mojado" sign.
const LINES := ["¡Alto ahí! ¿Y tu credencial?", "¡Prohibido correr en los pasillos!", "¡Te voy a levantar un reporte!", "¡No se escapa nadie!"]
var world
var slip_x := 0.0
var district := -1
var state := "run"
var clock := 0.0
var timer := 0.0
var speed := 0.0
var speech := ""
var speech_time := 0.0
var line_index := 0
var catches := 0
var facing := 1.0

func _ready() -> void:
	z_index = 4
	speed = float(world.player.character.run) * 0.9
	say(LINES[0])
	Sound.sfx("alert", 1.4)

func say(text: String) -> void:
	speech = text
	speech_time = 2.2

func _physics_process(delta: float) -> void:
	clock += delta
	timer += delta
	speech_time = maxf(0, speech_time - delta)
	var p = world.player
	match state:
		"run":
			position.x += speed * delta
			# Rubber band: never fall so far behind that the pressure disappears.
			position.x = maxf(position.x, p.position.x - 700)
			if timer > 4.5:
				timer = 0
				line_index = (line_index + 1) % LINES.size()
				say(LINES[line_index])
			if p.position.x - position.x < 34 and p.position.x - position.x > -40 and p.position.y > 540 and not p.locked:
				catches += 1
				p.hurt(position + Vector2(-60, 0))
				say("¡Te tengo! Reporte a dirección.")
				state = "caught"
				timer = 0
			if position.x >= slip_x:
				state = "slip"
				timer = 0
				Sound.sfx("crumble", 0.7)
				world.shake = maxf(world.shake, 7)
				world.fx.burst(position + Vector2(0, -40), Color("eef2f5"), 30)
				world.fx.floating(position + Vector2(-30, -110), "¡PAF!", Color("ffffff"))
				say("¡¿Quién dejó esto aquí?!")
				world.prefect_defeated()
		"caught":
			if timer > 0.8:
				state = "run"
				timer = 0
		"slip":
			if timer > 2.4:
				state = "out"
				queue_free()
	queue_redraw()

func _draw() -> void:
	var ink := Color("203049")
	# The wet-floor sign he will slip on.
	var sign_x := slip_x - position.x
	if state == "run" and sign_x < 1200:
		draw_colored_polygon(PackedVector2Array([Vector2(sign_x - 18, 0), Vector2(sign_x, -50), Vector2(sign_x + 18, 0)]), Color("f2c14e"))
		draw_polyline(PackedVector2Array([Vector2(sign_x - 18, 0), Vector2(sign_x, -50), Vector2(sign_x + 18, 0)]), ink, 2, true)
		draw_string(ThemeDB.fallback_font, Vector2(sign_x - 10, -16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		draw_string(ThemeDB.fallback_font, Vector2(sign_x - 36, -58), "PISO MOJADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe08a"))
		for i in 3: draw_circle(Vector2(sign_x - 40 + i * 30, -2), 6, Color(0.45, 0.75, 1, 0.45))
	var spin := 0.0
	var lift := 0.0
	if state == "slip":
		spin = minf(1.0, timer * 2.5) * -PI * 0.55
		lift = -sin(minf(1.0, timer * 2.5) * PI) * 40
	draw_set_transform(Vector2(0, lift), spin)
	var stride := sin(clock * 16) * 10 if state == "run" else 0.0
	draw_line(Vector2(-4, -30), Vector2(-6 + stride, 0), ink, 7, true)
	draw_line(Vector2(4, -30), Vector2(6 - stride, 0), ink, 7, true)
	# Uniform with a reflective vest and a clipboard full of reports.
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -70), Vector2(16, -70), Vector2(18, -28), Vector2(-18, -28)]), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -68), Vector2(14, -68), Vector2(16, -30), Vector2(-16, -30)]), Color("4a6b8f"))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -66), Vector2(-4, -66), Vector2(-2, -32), Vector2(-14, -32)]), Color("ff9f3d"))
	draw_colored_polygon(PackedVector2Array([Vector2(4, -66), Vector2(12, -66), Vector2(14, -32), Vector2(2, -32)]), Color("ff9f3d"))
	draw_line(Vector2(-14, -48), Vector2(14, -48), Color("e6eef6"), 2)
	draw_rect(Rect2(16, -58, 14, 18), ink)
	draw_rect(Rect2(17, -57, 12, 16), Color("fffaf0"))
	draw_circle(Vector2(0, -82), 13, ink)
	draw_circle(Vector2(0, -82), 11, Color("d39b78"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -88), Vector2(14, -88), Vector2(18, -84), Vector2(-12, -84)]), Color("203a5c"))
	draw_rect(Rect2(-11, -98, 22, 10), Color("203a5c"))
	draw_circle(Vector2(5, -83), 1.8, ink)
	draw_line(Vector2(-1, -76), Vector2(9, -76), Color("5c3a2a"), 3, true)
	# Whistle with a little blow puff.
	draw_circle(Vector2(12, -78), 3, Color("c9ced8"))
	if state == "run" and int(clock * 4) % 3 == 0:
		draw_arc(Vector2(18, -80), 6, -0.8, 0.8, 8, Color(1, 1, 1, 0.7), 2, true)
	draw_set_transform(Vector2.ZERO)
	if speech_time > 0:
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
		draw_rect(Rect2(-width * 0.5, -142, width, 28), ink)
		draw_rect(Rect2(-width * 0.5 + 2, -140, width - 4, 24), Color("fffaf0"))
		draw_string(font, Vector2(-width * 0.5 + 10, -122), speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
