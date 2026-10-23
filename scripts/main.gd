extends Node
const World = preload("res://scripts/world.gd")
const Data = preload("res://scripts/level_data.gd")
const NAVY := Color("101b30")
const CREAM := Color("eef5ff")
const GOLD := Color("9affdf")
const TEAL := Color("67ffe3")
const QUIZ_ANSWER := 8
var world
var layer: CanvasLayer
var ui: Control
var background: CanvasLayer
var menu_art: Node2D
var font: Font
var screen := "menu"
var dialogue_who := ""
var dialogue_text := ""
var dialogue_timer := 0.0
var hud: Dictionary = {}
var elapsed := 0.0
var capture_path := ""
var capture_at := 150
var frame := 0
var test_mode := false
var frame_times: Array[float] = []
var quitting := false
var smoke_frames := 0
var quiz_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	font = system_font
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	ui = Control.new()
	ui.size = Vector2(1280, 720)
	layer.add_child(ui)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--character="): Progress.data.character = arg.trim_prefix("--character=")
		if arg.begins_with("--smoke-frames="): smoke_frames = maxi(1, int(arg.trim_prefix("--smoke-frames=")))
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-at="): capture_at = int(arg.trim_prefix("--capture-at="))
		if arg == "--test":
			test_mode = true
			Progress.session_only = true
	show_menu()
	for arg in args:
		if arg.begins_with("--level="):
			Progress.session_only = true
			Progress.data.double_jump = true
			start_level(clampi(int(arg.trim_prefix("--level=")), 1, 4))
	for arg in args:
		if arg.begins_with("--position=") and is_instance_valid(world):
			world.player.position = Vector2(float(arg.trim_prefix("--position=")), 610)
			world.player.camera.reset_smoothing()
	if "--characters" in args: character_select(false)
	if capture_path != "" and is_instance_valid(world): world.player.invulnerable = 999
	if "--graduation" in args: graduation()

func clear_ui() -> void:
	hud.clear()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func panel(parent: Node, rect: Rect2, color: Color = NAVY, radius: int = 18) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = Color(0.65, 0.88, 0.88, 0.16)
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func label(parent: Node, words: String, rect: Rect2, size: int = 22, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.clip_text = true
	l.text = words
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, words: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = words
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", NAVY if primary else CREAM)
	b.add_theme_color_override("font_hover_color", NAVY)
	b.add_theme_color_override("font_focus_color", NAVY if primary else GOLD)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		s.bg_color = GOLD if primary else Color("233e57")
		if state in ["hover", "pressed"]: s.bg_color = TEAL
		if state == "disabled": s.bg_color = Color("344354")
		s.border_color = GOLD if state == "focus" else Color(0.65, 0.88, 0.88, 0.18)
		s.set_border_width_all(2 if state == "focus" else 1)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(func():
		Sound.sfx("coin", 0.75)
		callback.call())
	parent.add_child(b)
	return b

func show_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
		world = null
	clear_ui()
	screen = "menu"
	if is_instance_valid(background):
		background.queue_free()
		background = null
	preload("res://scripts/menu_screen.gd").build(self)
	MusicManager.menu()

func _new_game_request() -> void:
	if Progress.data.score > 0 or int(Progress.data.unlocked) > 1:
		clear_ui()
		screen = "confirm"
		panel(ui, Rect2(340, 185, 600, 335))
		label(ui, "Una nueva aventura", Rect2(380, 220, 520, 45), 32, GOLD)
		label(ui, "Se reemplazará el progreso de la partida actual.", Rect2(380, 290, 520, 65), 20)
		button(ui, "Nueva partida", Rect2(380, 390, 250, 55), func():
			Progress.new_game()
			character_select(true), true)
		button(ui, "Volver", Rect2(650, 390, 240, 55), show_menu)
	else:
		Progress.new_game()
		character_select(true)

func character_select(new_adventure: bool = false) -> void:
	clear_ui()
	screen = "characters"
	var definitions = preload("res://scripts/characters.gd")
	panel(ui, Rect2(30, 28, 1220, 658), Color(0.04, 0.1, 0.18, 0.97), 24)
	label(ui, "ELIGE TU ESTUDIANTE", Rect2(58, 51, 1100, 30), 17, TEAL)
	label(ui, "Cuatro formas de llegar al título", Rect2(58, 95, 1160, 58), 40, GOLD)
	label(ui, "Todos pueden completar la aventura. Q o LB activa la habilidad de cada estudiante.", Rect2(60, 159, 1160, 33), 19, Color("b9d2da"))
	for i in 4:
		var id: String = definitions.IDS[i]
		var spec: Dictionary = definitions.spec(id)
		var x := 54.0 + i * 296
		panel(ui, Rect2(x, 220, 282, 345), Color("365c69") if Progress.data.character == id else Color("203b54"), 17)
		label(ui, spec.name, Rect2(x + 18, 233, 246, 37), 29, Color(spec.accent))
		label(ui, spec.role, Rect2(x + 18, 275, 246, 23), 12, TEAL)
		var portrait := Node2D.new()
		portrait.set_script(preload("res://scripts/menu_actor.gd"))
		portrait.character_id = id
		portrait.position = Vector2(x + 142, 458)
		portrait.scale = Vector2(1.85, 1.85)
		portrait.facing = 1
		portrait.celebrating = false
		ui.add_child(portrait)
		var description := label(ui, spec.description, Rect2(x + 18, 470, 245, 76), 17)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(ui, "✓ Seleccionado" if Progress.data.character == id else "Elegir " + spec.name, Rect2(x, 578, 282, 46), func():
			Progress.data.character = id
			Progress.data.shield = id == "diego"
			Progress.save_game()
			character_select(new_adventure), Progress.data.character == id)
	button(ui, "Comenzar aventura →" if new_adventure else "Guardar y volver →", Rect2(54, 638, 1170, 37), func():
		if new_adventure: start_level(1)
		else: show_menu(), true).grab_focus()

func start_level(level: int, resume_checkpoint: bool = false) -> void:
	get_tree().paused = false
	clear_ui()
	if is_instance_valid(background):
		background.queue_free()
		background = null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	if int(Progress.data.lives) <= 0: Progress.data.lives = 4
	if not resume_checkpoint: Progress.data.checkpoints.erase(str(level))
	world = load("res://scenes/level_%d.tscn" % level).instantiate()
	world.resume_saved_checkpoint = resume_checkpoint
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.app = self
	world.level_id = level
	add_child(world)
	screen = "playing"
	build_hud()
	fade_in()

func build_hud() -> void:
	clear_ui()
	panel(ui, Rect2(22, 18, 1236, 78), Color(0.04, 0.1, 0.18, 0.95), 16)
	panel(ui, Rect2(38, 31, 49, 50), Color("2d5b68"), 12)
	label(ui, "%02d" % world.level_id, Rect2(46, 35, 43, 39), 28, TEAL)
	label(ui, Data.TITLES[world.level_id - 1], Rect2(103, 30, 360, 30), 23)
	label(ui, Data.SUBTITLES[world.level_id - 1], Rect2(104, 62, 360, 22), 12, Color("8eb3bf"))
	hud.health = label(ui, "", Rect2(465, 31, 165, 31), 27, Color("ff9aa5"))
	hud.lives = label(ui, "", Rect2(468, 64, 150, 21), 12, Color("a7bfca"))
	hud.credits = label(ui, "", Rect2(637, 29, 168, 32), 25, GOLD)
	hud.score = label(ui, "", Rect2(637, 62, 190, 23), 12, Color("a7bfca"))
	hud.items = label(ui, "", Rect2(832, 35, 290, 28), 17, TEAL)
	button(ui, "II", Rect2(1177, 32, 59, 48), pause_game)
	hud.power = label(ui, "", Rect2(28, 112, 510, 25), 15, GOLD)
	var objective_panel := panel(ui, Rect2(887, 111, 369, 36), Color(0.04, 0.1, 0.18, 0.9), 10)
	hud.objective = label(objective_panel, "", Rect2(12, 7, 346, 24), 15, TEAL)
	hud.section = label(ui, "", Rect2(28, 155, 820, 26), 17, CREAM)
	hud.timer = label(ui, "", Rect2(995, 157, 250, 32), 24, GOLD)
	var skill_panel := panel(ui, Rect2(24, 594, 236, 76), Color(0.04, 0.1, 0.18, 0.92), 12)
	hud.character = label(skill_panel, "", Rect2(14, 9, 210, 25), 18, TEAL)
	hud.skill = label(skill_panel, "", Rect2(14, 41, 210, 23), 14, GOLD)
	hud.dialogue = panel(ui, Rect2(282, 574, 716, 110), Color(0.055, 0.13, 0.21, 0.96), 16)
	hud.speaker = label(hud.dialogue, "AZTLI", Rect2(24, 12, 668, 27), 17, TEAL)
	hud.message = label(hud.dialogue, "", Rect2(24, 43, 668, 61), 18)
	hud.message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.boss_panel = panel(ui, Rect2(421, 111, 438, 63), Color(0.05, 0.1, 0.18, 0.92), 12)
	hud.boss_label = label(hud.boss_panel, "", Rect2(15, 6, 410, 25), 16, GOLD)
	hud.boss_bar = ProgressBar.new()
	hud.boss_bar.position = Vector2(15, 36)
	hud.boss_bar.size = Vector2(408, 12)
	hud.boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("eb829c")
	fill.set_corner_radius_all(6)
	hud.boss_bar.add_theme_stylebox_override("fill", fill)
	hud.boss_panel.add_child(hud.boss_bar)
	label(ui, "A/D Mover   Espacio Salto   Shift Correr   S Deslizar   J Atacar   Q Habilidad   E Interactuar   Esc Pausa", Rect2(28, 692, 1220, 20), 12, Color("d5e3dd"))

func say(who: String, message: String, duration: float = 5.0) -> void:
	dialogue_who = who
	dialogue_text = message
	dialogue_timer = duration

func _process(delta: float) -> void:
	elapsed += delta
	frame += 1
	if smoke_frames > 0 and frame >= smoke_frames:
		smoke_frames = 0
		print("RUNTIME SMOKE OK: " + ("level %d" % world.level_id if is_instance_valid(world) else screen))
		quit_game()
	if capture_path != "" and frame > 30:
		frame_times.append(delta)
	var dimensions := get_viewport().get_visible_rect().size
	var scale_factor := minf(dimensions.x / 1280.0, dimensions.y / 720.0)
	ui.scale = Vector2.ONE * scale_factor
	ui.position = (dimensions - Vector2(1280, 720) * scale_factor) * 0.5
	if screen == "playing" and is_instance_valid(world):
		dialogue_timer = maxf(0, dialogue_timer - delta)
		if not hud.is_empty():
			hud.health.text = "♥ ".repeat(maxi(0, world.player.health)) + "♡ ".repeat(maxi(0, world.player.max_health - world.player.health))
			hud.lives.text = "%d VIDAS" % int(Progress.data.lives)
			hud.credits.text = "C  %03d" % int(Progress.data.credits)
			hud.score.text = "%06d PUNTOS" % int(Progress.data.score)
			hud.items.text = "USB  %d/8     TÍTULO  %d/4" % [Progress.data.usb.size(), Progress.data.fragments.size()]
			hud.power.text = ("DOBLE SALTO   " if Progress.data.double_jump else "") + ("BECA   " if Progress.data.shield else "") + ("CAFÉ %ds" % int(world.player.coffee) if world.player.coffee > 0 else "")
			hud.objective.text = "→  " + world.objective()
			hud.character.text = world.player.character.name
			hud.skill.text = "Q  " + world.player.character.skill + (" · listo" if world.player.ability_cooldown <= 0 else " · %ds" % ceili(world.player.ability_cooldown))
			hud.section.text = world.extension.current_name + "   ·   %d%%" % int(clampf(world.player.position.x / world.level_length, 0, 1) * 100)
			hud.timer.text = "ENTREGA  %.1f s" % world.extension.trial_remaining if world.extension.trial_active else ""
			hud.dialogue.visible = dialogue_timer > 0
			hud.speaker.text = dialogue_who
			hud.message.text = dialogue_text
			hud.boss_panel.visible = is_instance_valid(world.boss) and world.boss.active
			if hud.boss_panel.visible:
				hud.boss_label.text = ("BUG 404" if world.boss.miniboss else "DOCTOR REPROBACIÓN") + "  ·  FASE %d" % world.boss.phase
				hud.boss_bar.max_value = world.boss.max_health
				hud.boss_bar.value = world.boss.health
	if capture_path != "" and frame >= capture_at:
		var path := capture_path
		capture_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("SCREENSHOT: " + path)
		if not frame_times.is_empty():
			var total := 0.0
			for dt in frame_times: total += dt
			frame_times.sort()
			print("RENDER SAMPLE: mean %.1f FPS, p99 %.2f ms (%d frames)" % [frame_times.size() / total, frame_times[int(frame_times.size() * 0.99)] * 1000, frame_times.size()])
		quit_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game() -> void:
	if quitting: return
	quitting = true
	if is_instance_valid(world): world.save_snapshot()
	Sound.shutdown()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if screen == "playing": pause_game()
		elif screen == "pause": resume_game()
		elif screen in ["levels", "settings", "confirm", "characters"]: show_menu() if not is_instance_valid(world) else pause_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart") and screen == "game_over": retry_level()

func fade_in() -> void:
	var shade := ColorRect.new()
	shade.color = NAVY
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var tween := shade.create_tween()
	tween.tween_property(shade, "modulate:a", 0, 0.45)
	tween.tween_callback(shade.queue_free)

func pause_game() -> void:
	if not is_instance_valid(world): return
	screen = "pause"
	get_tree().paused = true
	clear_ui()
	panel(ui, Rect2(0, 0, 1280, 720), Color(0.03, 0.08, 0.14, 0.6), 0)
	panel(ui, Rect2(410, 123, 460, 474))
	label(ui, "RESPIRA. VAS BIEN.", Rect2(451, 157, 400, 30), 17, TEAL)
	label(ui, "Pausa", Rect2(450, 198, 370, 60), 45, GOLD)
	button(ui, "Seguir aventura", Rect2(450, 287, 380, 54), resume_game, true).grab_focus()
	button(ui, "Audio y controles", Rect2(450, 358, 380, 52), func(): settings("pause"))
	button(ui, "Reiniciar nivel", Rect2(450, 429, 380, 52), func(): start_level(world.level_id))
	button(ui, "Guardar y volver al menú", Rect2(450, 500, 380, 52), func():
		world.save_snapshot()
		show_menu())

func resume_game() -> void:
	get_tree().paused = false
	screen = "playing"
	build_hud()

func settings(origin: String) -> void:
	screen = "settings"
	clear_ui()
	panel(ui, Rect2(230, 80, 820, 560))
	label(ui, "Hazlo a tu ritmo", Rect2(274, 111, 700, 48), 37, GOLD)
	for i in 2:
		label(ui, ["Música", "Efectos"][i], Rect2(280, 198 + i * 70, 220, 32), 23)
		var slider := HSlider.new()
		slider.position = Vector2(510, 208 + i * 70)
		slider.size = Vector2(460, 24)
		slider.min_value = 0
		slider.max_value = 100
		slider.value = (Progress.music_volume if i == 0 else Progress.effects_volume) * 100
		if i == 0:
			slider.value_changed.connect(func(v): Progress.music_volume = v / 100.0; Sound.apply_volume())
		else:
			slider.value_changed.connect(func(v): Progress.effects_volume = v / 100.0; Sound.apply_volume())
		ui.add_child(slider)
	label(ui, "A / D o flechas · Mover     Espacio / W · Saltar\nShift · Correr     S / ↓ · Deslizarse     Q / C · Habilidad\nJ / X · Atacar     E / Enter · Interactuar     Esc · Pausa\nMando: A salto · X ataque · Y interactuar · RB correr · LB habilidad", Rect2(280, 354, 720, 144), 18, Color("bdced7"))
	button(ui, "Guardar y volver", Rect2(280, 541, 720, 53), func():
		Progress.save_game()
		if origin == "pause": pause_game()
		else: show_menu(), true).grab_focus()

func level_select() -> void:
	screen = "levels"
	clear_ui()
	panel(ui, Rect2(64, 76, 1152, 568))
	label(ui, "Tu camino al título", Rect2(106, 112, 1000, 58), 43, GOLD)
	label(ui, "Cada fragmento cuenta. Vuelve para descubrir todos los secretos.", Rect2(108, 184, 1050, 35), 20, Color("b8ccd5"))
	for i in 4:
		var unlocked: bool = i < int(Progress.data.unlocked)
		panel(ui, Rect2(104 + i * 272, 260, 250, 235), Color("26465a"))
		label(ui, "%02d" % (i + 1), Rect2(123 + i * 272, 279, 200, 54), 45, TEAL if unlocked else Color("718491"))
		var title := label(ui, Data.TITLES[i], Rect2(123 + i * 272, 349, 215, 65), 22)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var level := i + 1
		var b := button(ui, "Entrar  →" if unlocked else "Bloqueado", Rect2(120 + i * 272, 431, 219, 46), func(): start_level(level), unlocked)
		b.disabled = not unlocked
		label(ui, "MEJOR: " + str(Progress.data.best.get(str(level), "—")), Rect2(125 + i * 272, 506, 215, 26), 14, TEAL)
	button(ui, "← Volver", Rect2(108, 566, 1036, 46), show_menu).grab_focus()

func quiz(terminal) -> void:
	get_tree().paused = true
	screen = "quiz"
	clear_ui()
	panel(ui, Rect2(250, 125, 780, 470))
	label(ui, "RETO DE LA BIBLIOTECA", Rect2(290, 158, 700, 35), 18, TEAL)
	label(ui, "¿Cuántos bits forman un byte?", Rect2(290, 215, 700, 55), 32, GOLD)
	label(ui, "Respuesta correcta: 10 créditos + beca protectora.", Rect2(290, 286, 700, 32), 18)
	# Same style for every option and a fresh order each time; the answer is checked by value.
	var answers := [4, 8, 16]
	answers.shuffle()
	quiz_buttons.clear()
	for i in answers.size():
		var answer: int = answers[i]
		quiz_buttons.append(button(ui, str(answer) + " bits", Rect2(290 + i * 238, 357, 220, 65), func():
			if answer == QUIZ_ANSWER:
				terminal.active = true
				Progress.credit(10)
				Progress.data.shield = true
				world.save_snapshot()
				Sound.sfx("power")
				resume_game()
				say("AZTLI", "¡Exacto! Un byte son 8 bits. Tu beca bloqueará el siguiente golpe.", 6)
			else:
				Sound.sfx("alert")
				resume_game()
				say("AZTLI", "Casi. Piensa en ocho interruptores binarios. Puedes intentarlo de nuevo.", 5)))
	button(ui, "Volver al campus", Rect2(290, 481, 700, 50), resume_game)

func game_over() -> void:
	screen = "game_over"
	get_tree().paused = true
	clear_ui()
	panel(ui, Rect2(300, 170, 680, 380))
	label(ui, "ESTE EXAMEN TIENE SEGUNDA OPORTUNIDAD", Rect2(342, 205, 610, 28), 15, TEAL)
	label(ui, "No te rindas", Rect2(340, 258, 600, 65), 48, GOLD)
	label(ui, "Conservas tus créditos, habilidades y documentos.", Rect2(341, 346, 600, 34), 20)
	button(ui, "Reintentar  ·  R", Rect2(340, 429, 290, 60), retry_level, true).grab_focus()
	button(ui, "Menú", Rect2(650, 429, 290, 60), show_menu)

func retry_level() -> void:
	Progress.data.lives = 4
	Progress.save_game()
	start_level(world.level_id)

func results(grade: String) -> void:
	screen = "results"
	clear_ui()
	panel(ui, Rect2(280, 95, 720, 530), Color(0.04, 0.1, 0.17, 0.97))
	label(ui, "MISIÓN COMPLETADA", Rect2(325, 133, 630, 32), 18, TEAL)
	label(ui, Data.TITLES[world.level_id - 1], Rect2(325, 181, 640, 55), 34, GOLD)
	panel(ui, Rect2(327, 268, 118, 127), Color("2d5863"), 18)
	label(ui, grade, Rect2(355, 277, 90, 90), 72, GOLD)
	label(ui, "CALIFICACIÓN", Rect2(334, 371, 120, 23), 11, TEAL)
	label(ui, "Créditos recuperados    %d\nEnemigos superados     %d\nSecretos encontrados   %d / 2\nTiempo   %02d:%02d" % [world.level_credits, world.enemies_defeated, world.secrets, int(world.level_time) / 60, int(world.level_time) % 60], Rect2(488, 268, 425, 145), 21)
	label(ui, "Fragmento recuperado. Tu progreso está guardado.", Rect2(326, 443, 640, 32), 18, Color("b8ced7"))
	button(ui, "Graduarme  →" if world.level_id == 4 else "Siguiente nivel  →", Rect2(325, 522, 380, 58), func():
		if world.level_id == 4: graduation()
		else: start_level(world.level_id + 1), true).grab_focus()
	button(ui, "Menú", Rect2(724, 522, 230, 58), show_menu)

func graduation() -> void:
	screen = "graduation"
	clear_ui()
	MusicManager.ending()
	panel(ui, Rect2(160, 65, 960, 589), Color("122a43"), 24)
	var ceremony := Node2D.new()
	ceremony.set_script(preload("res://scripts/ceremony.gd"))
	ui.add_child(ceremony)
	label(ui, "INSTITUTO TECNOLÓGICO DE TLÁHUAC III", Rect2(223, 101, 850, 30), 20, TEAL)
	label(ui, "El futuro\nes tuyo.", Rect2(223, 168, 570, 157), 58, GOLD)
	var message := label(ui, "Recuperaste los cuatro fragmentos y venciste al Doctor Reprobación. ¡Hoy te gradúas!", Rect2(225, 335, 480, 89), 22)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel(ui, Rect2(225, 445, 475, 82), Color("284b5b"), 14)
	label(ui, "TÍTULO UNIVERSITARIO", Rect2(245, 452, 440, 31), 24, CREAM)
	label(ui, "MENCIÓN HONORÍFICA · 8 USB" if Progress.data.usb.size() >= 8 else "%06d PUNTOS   ·   %d / 8 USB" % [int(Progress.data.score), Progress.data.usb.size()], Rect2(246, 492, 440, 25), 16, TEAL)
	button(ui, "Volver al campus", Rect2(225, 559, 475, 51), show_menu, true).grab_focus()
	for i in 50:
		var confetti := ColorRect.new()
		confetti.color = [GOLD, TEAL, Color("f696a4")][i % 3]
		confetti.position = Vector2(randf_range(170, 1100), randf_range(-680, -10))
		confetti.size = Vector2(6, 12)
		confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(confetti)
		var tween := confetti.create_tween().set_loops()
		tween.tween_property(confetti, "position:y", 720, randf_range(4, 9)).from(randf_range(-680, -10))
	fade_in()
