extends RefCounted
## Presentation layer only; existing navigation/save/character flows stay in Main.
static func build(app) -> void:
	var art := Node2D.new()
	art.set_script(preload("res://scripts/menu_showcase.gd"))
	art.character_id = str(Progress.data.character)
	app.ui.add_child(art)
	app.menu_art = art
	var white := Color("eef5ff")
	var muted := Color("8799b9")
	var cyan := Color("67ffe3")
	var display := SystemFont.new()
	display.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	display.font_weight = 800
	app.label(app.ui, "TEC / III", Rect2(54, 29, 190, 32), 25, white)
	app.label(app.ui, "TLÁHUAC III   /   EL FUTURO SE CONQUISTA", Rect2(249, 39, 650, 25), 12, muted)
	app.label(app.ui, "01—04    CAMPAÑA", Rect2(1035, 39, 210, 25), 12, cyan)
	app.label(app.ui, "UNA MISIÓN. TODO TU FUTURO.", Rect2(58, 112, 590, 27), 15, cyan)
	var title: Label = app.label(app.ui, "TECNO", Rect2(48, 151, 660, 118), 112, white)
	title.add_theme_font_override("font", display)
	title.add_theme_constant_override("outline_size", 1)
	var subtitle = app.label(app.ui, "AVENTURA", Rect2(51, 257, 700, 106), 87, white)
	subtitle.add_theme_font_override("font", display)
	app.label(app.ui, "III", Rect2(493, 156, 170, 118), 112, cyan)
	app.label(app.ui, "LA MISIÓN DEL TÍTULO", Rect2(58, 379, 590, 40), 27, Color("a69dff"))
	var description = app.label(app.ui, "Recupera tus créditos. Desafía al sistema.\nCon Aztli a tu lado, alcanza lo imposible.", Rect2(60, 437, 595, 66), 21, Color("b6c3db"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var play = app.button(app.ui, "INICIAR MISIÓN                         ↗", Rect2(58, 538, 410, 65), app._new_game_request, true)
	decorate(play, true)
	play.add_theme_font_size_override("font_size", 18)
	play.grab_focus()
	var cont = app.button(app.ui, "CONTINUAR  →", Rect2(483, 538, 188, 65), func(): app.start_level(int(Progress.data.current), true))
	cont.disabled = not FileAccess.file_exists(Progress.SAVE_PATH) and Progress.data.score == 0
	decorate(cont)
	for i in 3:
		var captions := ["NIVELES", "ESTUDIANTES", "AUDIO / CONTROL"]
		var callbacks: Array[Callable] = [app.level_select, func(): app.character_select(false), func(): app.settings("menu")]
		var b = app.button(app.ui, captions[i], Rect2(58 + i * 206, 621, 196, 42), callbacks[i])
		decorate(b)
		b.add_theme_font_size_override("font_size", 13)
	var exit_button = app.button(app.ui, "SALIR  ×", Rect2(1125, 667, 110, 32), app.quit_game)
	decorate(exit_button)
	exit_button.add_theme_font_size_override("font_size", 12)
	app.label(app.ui, "04 NIVELES     /     04 ESTUDIANTES     /     UN TÍTULO", Rect2(59, 683, 890, 22), 11, muted)
	app.label(app.ui, "AZTLI", Rect2(1014, 163, 210, 35), 25, cyan)
	app.label(app.ui, "TU ALIADO EN EL AIRE", Rect2(1014, 198, 220, 25), 10, muted)
	var profile: Dictionary = preload("res://scripts/characters.gd").spec(str(Progress.data.character))
	app.label(app.ui, str(profile.name).to_upper(), Rect2(850, 584, 350, 45), 34, white)
	app.label(app.ui, profile.role + "  /  " + profile.skill.to_upper(), Rect2(850, 633, 350, 25), 12, cyan)
	# Staggered fade/slide of text and controls; layout positions remain authoritative.
	var index := 0
	for child in app.ui.get_children():
		if child is Control:
			child.modulate.a = 0
			var destination: Vector2 = child.position
			child.position.x -= 16
			var tween = child.create_tween().set_parallel(true)
			tween.tween_property(child, "modulate:a", 1.0, 0.42).set_delay(minf(0.5, index * 0.025))
			tween.tween_property(child, "position", destination, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(minf(0.5, index * 0.025))
			index += 1

static func decorate(button: Button, primary: bool = false) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("07121e") if primary else Color("d7e5fa"))
	button.add_theme_color_override("font_hover_color", Color("07121e"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.bg_color = Color("68ffe2") if primary else Color("111f36")
		style.border_color = Color("68ffe2") if primary else Color("31425f")
		style.set_border_width_all(1)
		if state in ["hover", "pressed"]:
			style.bg_color = Color("a4ffec")
			style.border_color = Color("d8fff7")
			style.shadow_color = Color(0.2, 1, 0.8, 0.25)
			style.shadow_size = 12
		if state == "focus":
			style.border_color = Color("c2a7ff")
			style.set_border_width_all(2)
		if state == "disabled": style.bg_color = Color("172139")
		button.add_theme_stylebox_override(state, style)
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func():
		Sound.sfx("ui_hover")
		button.create_tween().tween_property(button, "scale", Vector2.ONE * 1.025, 0.14).set_trans(Tween.TRANS_CUBIC))
	button.mouse_exited.connect(func(): button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.14))
