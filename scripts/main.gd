extends Node
const World = preload("res://scripts/world.gd")
const Data = preload("res://scripts/level_data.gd")
const UI = preload("res://scripts/ui_theme.gd")
const HudIcon = preload("res://scripts/hud_icon.gd")
const NAVY := UI.SURFACE
const CREAM := UI.TEXT
const GOLD := UI.MINT
const TEAL := UI.ACCENT
const QUIZ_ANSWER := 8
var world
var layer: CanvasLayer
var ui: Control
var background: CanvasLayer
var menu_art: Node2D
var font: Font
var screen := "menu"
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
var ui_fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	system_font.font_weight = 600
	font = system_font
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	ui = Control.new()
	ui.size = Vector2(1280, 720)
	ui.theme = UI.build(font)
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
	for arg in args:
		if arg.begins_with("--collection="): preload("res://scripts/campus_collection.gd").build(self, arg.trim_prefix("--collection="))
	if "--paused" in args and is_instance_valid(world): pause_game()

func clear_ui() -> void:
	hud.clear()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	# Every screen change fades in; input is accepted immediately.
	if is_instance_valid(ui_fade): ui_fade.kill()
	ui.modulate.a = 0.0
	ui_fade = ui.create_tween()
	ui_fade.tween_property(ui, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func panel(parent: Node, rect: Rect2, color: Color = NAVY, radius: int = 18) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.flat(color, radius, Color(0.65, 0.88, 0.88, 0.16), 1, 10 if color.a > 0.8 and rect.size.x < 1280 else 0))
	parent.add_child(p)
	return p

func label(parent: Node, words: String, rect: Rect2, size: int = 22, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.clip_text = true
	l.text = words
	l.position = rect.position
	l.size = rect.size
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
	# Normal / hover / pressed / focus / disabled states come from the shared Theme.
	b.theme_type_variation = &"PrimaryButton" if primary else &""
	b.pivot_offset = rect.size * 0.5
	b.mouse_entered.connect(func():
		if b.disabled: return
		Sound.sfx("ui_hover")
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.03, 0.12).set_trans(Tween.TRANS_CUBIC))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.button_down.connect(func(): b.scale = Vector2.ONE * 0.97)
	b.button_up.connect(func(): b.scale = Vector2.ONE)
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
		var warning := label(ui, "Reinicia la campaña. Conservas monedas, compras, reliquias, récords y logros.", Rect2(380, 290, 520, 80), 18)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	label(ui, "ELIGE TU PERSONAJE", Rect2(58, 46, 850, 30), 17, TEAL)
	label(ui, "Tu lugar en el campus", Rect2(58, 81, 850, 55), 36, GOLD)
	label(ui, "Cuatro estudiantes y dos maestros desbloqueables. Q / LB: habilidad.", Rect2(60, 137, 1120, 30), 17, Color("b9d2da"))
	button(ui, "Ir a la tienda", Rect2(1000, 83, 205, 42), collection)
	for i in definitions.IDS.size():
		var id: String = definitions.IDS[i]
		var spec: Dictionary = definitions.spec(id)
		var available: bool = Progress.character_available(id)
		var x: float = 54.0 + (i % 3) * 395
		var y: float = 181.0 + int(i / 3) * 220
		panel(ui, Rect2(x, y, 376, 207), Color("365c69") if Progress.data.character == id else Color("203b54"), 17)
		label(ui, spec.name, Rect2(x + 122, y + 14, 240, 32), 24, Color(spec.accent))
		label(ui, spec.role, Rect2(x + 122, y + 49, 240, 23), 12, TEAL)
		var portrait := Node2D.new()
		portrait.set_script(preload("res://scripts/menu_actor.gd"))
		portrait.character_id = id
		portrait.position = Vector2(x + 62, y + 171)
		portrait.scale = Vector2(1.45, 1.45)
		portrait.facing = 1
		portrait.celebrating = false
		ui.add_child(portrait)
		var description := label(ui, spec.description, Rect2(x + 122, y + 80, 240, 65), 15)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var caption := "✓ Seleccionado" if Progress.data.character == id else "Elegir"
		if not available: caption = "En tienda · %d monedas" % int(Progress.SHOP[id].price)
		var choose := button(ui, caption, Rect2(x + 122, y + 157, 240, 37), func():
			if Progress.select_character(id): character_select(new_adventure), Progress.data.character == id)
		choose.disabled = not available
		choose.set_meta("character_choice", id)
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
	hud.hearts = icon(ui, "hearts", Rect2(463, 28, 165, 32))
	icon(ui, "lives", Rect2(466, 63, 18, 22))
	hud.lives = label(ui, "", Rect2(489, 64, 130, 21), 12, Color("a7bfca"))
	icon(ui, "coin", Rect2(637, 31, 28, 28))
	hud.credits = label(ui, "", Rect2(671, 28, 140, 32), 25, GOLD)
	hud.score = label(ui, "", Rect2(637, 62, 190, 23), 12, Color("a7bfca"))
	icon(ui, "usb", Rect2(834, 32, 22, 32))
	hud.usb = label(ui, "", Rect2(862, 34, 80, 28), 18, TEAL)
	icon(ui, "document", Rect2(948, 32, 26, 32))
	hud.docs = label(ui, "", Rect2(980, 34, 90, 28), 18, TEAL)
	button(ui, "II", Rect2(1177, 32, 59, 48), pause_game)
	# Active power-ups: icon + short caption, shown only while active.
	hud.powers = []
	for power in [["feather", "DOBLE SALTO", 160], ["shield", "BECA", 100], ["coffee", "", 120]]:
		var power_icon: Control = icon(ui, power[0], Rect2(28, 110, 26, 28))
		var caption := label(ui, power[1], Rect2(58, 113, power[2] - 34, 25), 15, GOLD)
		hud.powers.append({"kind": power[0], "icon": power_icon, "label": caption, "width": power[2]})
	var objective_panel := panel(ui, Rect2(887, 111, 369, 36), Color(0.04, 0.1, 0.18, 0.9), 10)
	hud.objective = label(objective_panel, "", Rect2(12, 7, 346, 24), 15, TEAL)
	hud.section = label(ui, "", Rect2(28, 155, 820, 26), 17, CREAM)
	hud.timer_icon = icon(ui, "clock", Rect2(966, 159, 26, 26))
	hud.timer = label(ui, "", Rect2(998, 157, 250, 32), 24, GOLD)
	var skill_panel := panel(ui, Rect2(24, 594, 236, 76), Color(0.04, 0.1, 0.18, 0.92), 12)
	hud.character = label(skill_panel, "", Rect2(14, 9, 210, 25), 18, TEAL)
	hud.skill = label(skill_panel, "", Rect2(14, 41, 210, 23), 14, GOLD)
	hud.boss_panel = panel(ui, Rect2(421, 111, 438, 63), Color(0.05, 0.1, 0.18, 0.92), 12)
	hud.boss_label = label(hud.boss_panel, "", Rect2(15, 6, 410, 25), 16, GOLD)
	hud.boss_bar = ProgressBar.new()
	hud.boss_bar.position = Vector2(15, 36)
	hud.boss_bar.size = Vector2(408, 12)
	hud.boss_bar.show_percentage = false
	hud.boss_panel.add_child(hud.boss_bar)
	label(ui, "A/D Mover   Espacio Salto   Shift Correr   S Deslizar   J Atacar   Q Habilidad   E Interactuar   Esc Pausa", Rect2(28, 692, 1220, 20), 12, Color("d5e3dd"))

func banner(text: String, color: Color = GOLD) -> void:
	# Big centered call-out for encounters and chases; it pops in, holds, then fades.
	if screen != "playing": return
	if is_instance_valid(hud.get("banner")): hud.banner.queue_free()
	var l := label(ui, text, Rect2(90, 200, 1100, 70), 40, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 10)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	hud.banner = l
	var tween := l.create_tween()
	tween.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.6)
	tween.tween_property(l, "modulate:a", 0.0, 0.4)
	tween.tween_callback(l.queue_free)
	Sound.sfx("trial", 1.2)

func icon(parent: Node, kind: String, rect: Rect2) -> Control:
	var node := Control.new()
	node.set_script(HudIcon)
	node.kind = kind
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node

func say(_who: String, _message: String, _duration: float = 5.0) -> void:
	# Gameplay notifications no longer cover the lower part of the scene.
	pass

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
		if not hud.is_empty():
			hud.hearts.set_counts(maxi(0, world.player.health), world.player.max_health)
			hud.lives.text = "%d VIDAS" % int(Progress.data.lives)
			hud.credits.text = "%03d" % int(Progress.data.wallet)
			hud.score.text = "%06d PUNTOS" % int(Progress.data.score)
			hud.usb.text = "%d/8" % Progress.data.usb.size()
			hud.docs.text = "TÍTULO %d/4" % Progress.data.fragments.size()
			var power_x := 28.0
			for power in hud.powers:
				var active: bool = {"feather": Progress.data.double_jump, "shield": Progress.data.shield, "coffee": world.player.coffee > 0}[power.kind]
				power.icon.visible = active
				power.label.visible = active
				if power.kind == "coffee": power.label.text = "CAFÉ %ds" % int(world.player.coffee)
				if active:
					power.icon.position.x = power_x
					power.label.position.x = power_x + 30
					power_x += power.width
			hud.objective.text = "→  " + world.objective()
			hud.character.text = world.player.character.name
			hud.skill.text = "Q  " + world.player.character.skill + (" · listo" if world.player.ability_cooldown <= 0 else " · %ds" % ceili(world.player.ability_cooldown))
			hud.section.text = world.extension.current_name + "   ·   %d%%" % int(clampf(world.player.position.x / world.level_length, 0, 1) * 100)
			hud.timer.text = "ENTREGA  %.1f s" % world.extension.trial_remaining if world.extension.trial_active else ""
			hud.timer_icon.visible = world.extension.trial_active
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
		elif screen in ["levels", "settings", "confirm", "characters", "collection"]: show_menu() if not is_instance_valid(world) else pause_game()
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
	panel(ui, Rect2(370, 62, 540, 594))
	label(ui, "RESPIRA. VAS BIEN.", Rect2(410, 89, 460, 27), 17, TEAL)
	label(ui, "Pausa", Rect2(410, 122, 460, 55), 43, GOLD)
	button(ui, "Seguir aventura", Rect2(410, 192, 460, 49), resume_game, true).grab_focus()
	label(ui, "Música", Rect2(410, 263, 140, 30), 20)
	audio_slider(0, Rect2(568, 267, 300, 25))
	label(ui, "Efectos", Rect2(410, 311, 140, 30), 20)
	audio_slider(1, Rect2(568, 315, 300, 25))
	audio_mute_button(Rect2(410, 363, 460, 43))
	button(ui, "Controles y audio", Rect2(410, 421, 460, 43), func(): settings("pause"))
	button(ui, "Reiniciar nivel", Rect2(410, 479, 460, 43), func(): start_level(world.level_id))
	button(ui, "Guardar y volver al menú", Rect2(410, 537, 460, 49), func():
		world.save_snapshot()
		show_menu())

func resume_game() -> void:
	Progress.save_game()
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
		audio_slider(i, Rect2(510, 208 + i * 70, 460, 24))
	audio_mute_button(Rect2(280, 318, 720, 36))
	label(ui, "A / D o flechas · Mover     Espacio / W · Saltar\nShift · Correr     S / ↓ · Deslizarse     Q / C · Habilidad\nJ / X · Atacar     E / Enter · Interactuar     Esc · Pausa\nMando: A salto · X ataque · Y interactuar · RB correr · LB habilidad", Rect2(280, 354, 720, 144), 18, Color("bdced7"))
	button(ui, "Guardar y volver", Rect2(280, 541, 720, 53), func():
		Progress.save_game()
		if origin == "pause": pause_game()
		else: show_menu(), true).grab_focus()

func audio_slider(kind: int, rect: Rect2) -> HSlider:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = (Progress.music_volume if kind == 0 else Progress.effects_volume) * 100
	slider.set_meta("audio_volume", "music" if kind == 0 else "effects")
	slider.value_changed.connect(func(value):
		if kind == 0: Progress.music_volume = value / 100.0
		else: Progress.effects_volume = value / 100.0
		Sound.apply_volume())
	slider.drag_ended.connect(func(_changed): Progress.save_game())
	slider.focus_exited.connect(Progress.save_game)
	ui.add_child(slider)
	return slider

func audio_mute_button(rect: Rect2) -> void:
	var mute := button(ui, "Activar sonido" if Progress.audio_muted else "Silenciar todo", rect, func():
		Sound.toggle_mute()
		for child in ui.get_children():
			if child.has_meta("audio_mute"): child.text = "Activar sonido" if Progress.audio_muted else "Silenciar todo")
	mute.set_meta("audio_mute", true)

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

func collection() -> void:
	preload("res://scripts/campus_collection.gd").build(self)

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
				Progress.credit(10, Progress.reward_id(world.level_id, terminal.position.x, "quiz"))
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
	var best_time := float(Progress.data.times.get(str(world.level_id), world.level_time))
	label(ui, "MEJOR %s · %02d:%02d · RELIQUIAS %d/3" % [str(Progress.data.best.get(str(world.level_id), grade)), int(best_time) / 60, int(best_time) % 60, Progress.relic_count(world.level_id)], Rect2(326, 443, 640, 32), 18, Color("b8ced7"))
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
