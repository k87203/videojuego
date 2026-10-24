extends RefCounted
## Account screens live outside gameplay, leaving the playfield unobstructed.
const MINT := Color("67ffe3")
const MUTED := Color("a9bed0")
const TITLES := ["Raíces del humedal", "Memoria de las aulas", "Ingenio compartido", "El vuelo de Aztli"]
const STORIES := [
	"El campus crece junto al agua. Entre ahuehuetes y canales, cada generación deja una nueva raíz.",
	"Un cuaderno pasa de mano en mano. Lo que alguien aprende hoy puede abrirle el camino a otra persona mañana.",
	"Un circuito no funciona al primer intento. Aquí el error se convierte en pregunta, y la pregunta en un proyecto compartido.",
	"El título recuerda el recorrido: amistades, desvelos e ideas que ahora pueden salir del campus. Aztli acompaña el siguiente vuelo.",
]

static func build(app, tab: String = "shop") -> void:
	app.clear_ui()
	app.screen = "collection"
	app.panel(app.ui, Rect2(35, 22, 1210, 675), Color("122a43"))
	app.label(app.ui, "VIDA EN EL CAMPUS", Rect2(65, 44, 600, 42), 30, MINT)
	app.label(app.ui, "%d MONEDAS" % int(Progress.data.wallet), Rect2(900, 47, 300, 35), 24, Color("ffda78"))
	for i in 3:
		var target: String = ["shop", "gallery", "records"][i]
		app.button(app.ui, ["Tienda", "Galería", "Récords y logros"][i], Rect2(65 + i * 375, 105, 355, 44), func(): build(app, target), tab == target)
	match tab:
		"shop": shop(app)
		"gallery": gallery(app)
		"records": records(app)
	app.button(app.ui, "← Volver al menú", Rect2(65, 635, 1110, 42), app.show_menu).grab_focus()

static func shop(app) -> void:
	var character := str(Progress.data.character)
	var profile: Dictionary = preload("res://scripts/characters.gd").spec(character)
	app.label(app.ui, "Vista previa de cada producto · personaje actual: %s" % profile.name, Rect2(65, 158, 1060, 28), 18, MUTED)
	var index := 0
	for id in Progress.SHOP:
		var item: Dictionary = Progress.SHOP[id]
		var x := 65 + (index % 4) * 280
		var y := 196 + (index / 4) * 213
		app.panel(app.ui, Rect2(x, y, 260, 199), Color("203b54"), 14)
		app.label(app.ui, item.name, Rect2(x + 12, y + 10, 240, 28), 18, MINT)
		var owned: bool = id in Progress.data.purchases
		var slot := str(item.slot)
		var equipped: bool = owned and (slot == "upgrade" or (character == id if slot == "character" else Progress.outfit(character).get(slot, "") == id))
		var description := "Color de sudadera · solo apariencia" if slot == "skin" else "Accesorio · solo apariencia"
		if slot == "upgrade": description = "+1 corazón al explorar. Salud original en jefes."
		if slot == "character":
			description = "Robótica\nImpulso de taller\n3 corazones" if id == "maestra_luz" else "Tecnología\nRadar de diagnóstico\n3 corazones"
		var copy = app.label(app.ui, description, Rect2(x + 108, y + 55, 140, 100), 14, MUTED)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var preview := Node2D.new()
		preview.set_script(preload("res://scripts/shop_preview.gd"))
		preview.product_id = id
		preview.character_id = character
		preview.position = Vector2(x + 54, y + 150)
		preview.set_meta("shop_product", id)
		app.ui.add_child(preview)
		var caption := ("Seleccionado" if slot == "character" else "Equipado") if equipped else ("Elegir personaje" if slot == "character" else "Equipar")
		if not owned: caption = "Comprar · %d monedas" % int(item.price)
		var action = app.button(app.ui, caption, Rect2(x + 12, y + 160, 236, 34), func():
			if not owned and not Progress.buy(id): return
			if slot == "character": Progress.select_character(id)
			elif slot != "upgrade": Progress.equip(character, slot, id)
			build(app, "shop"))
		action.add_theme_font_size_override("font_size", 17)
		action.set_meta("shop_buy", id)
		action.disabled = equipped or (not owned and int(Progress.data.wallet) < int(item.price))
		index += 1
	app.panel(app.ui, Rect2(905, 409, 260, 199), Color("18364b"), 14)
	app.label(app.ui, "Tu personaje", Rect2(917, 419, 236, 28), 18, MINT)
	var actor := Node2D.new()
	actor.set_script(preload("res://scripts/menu_actor.gd"))
	actor.character_id = character
	actor.position = Vector2(962, 559)
	actor.scale = Vector2(1.12, 1.12)
	actor.facing = 1
	actor.celebrating = false
	app.ui.add_child(actor)
	app.label(app.ui, profile.name, Rect2(1013, 471, 140, 30), 16, MUTED)
	app.button(app.ui, "Restaurar atuendo", Rect2(917, 569, 236, 34), func():
		Progress.equip(character, "skin", "")
		Progress.equip(character, "accessory", "")
		build(app, "shop"))
	app.label(app.ui, "Compras permanentes · los maestros también se eligen en Personajes", Rect2(65, 609, 1100, 23), 13, MUTED)

static func gallery(app) -> void:
	app.label(app.ui, "Reúne las 3 reliquias de cada nivel para quitar el candado y abrir su recuerdo.", Rect2(65, 170, 1100, 30), 19, MUTED)
	for i in 4:
		var level := i + 1
		var count := Progress.relic_count(level)
		var x := 65 + i * 280
		app.panel(app.ui, Rect2(x, 240, 260, 330), Color("203b54"), 16)
		app.label(app.ui, "NIVEL %d · %d/3" % [level, count], Rect2(x + 18, 260, 225, 30), 20, MINT)
		var art := Node2D.new()
		art.set_script(preload("res://scripts/gallery_art.gd"))
		art.level = level
		art.locked = count < 3
		art.position = Vector2(x + 20, 310)
		art.scale = Vector2(0.30, 0.30)
		app.ui.add_child(art)
		app.label(app.ui, TITLES[i], Rect2(x + 18, 467, 230, 30), 16, MUTED)
		var open = app.button(app.ui, "Ver recuerdo" if count >= 3 else "Bloqueado · %d/3" % count, Rect2(x + 18, 515, 224, 40), func(): gallery_page(app, level))
		open.disabled = count < 3

static func gallery_page(app, level: int) -> void:
	if Progress.relic_count(level) < 3: return
	app.clear_ui()
	app.screen = "collection"
	app.panel(app.ui, Rect2(35, 22, 1210, 675), Color("122a43"))
	app.label(app.ui, TITLES[level - 1], Rect2(65, 45, 1100, 45), 32, MINT)
	var art := Node2D.new()
	art.set_script(preload("res://scripts/gallery_art.gd"))
	art.level = level
	art.position = Vector2(250, 110)
	app.ui.add_child(art)
	var story = app.label(app.ui, STORIES[level - 1], Rect2(150, 510, 980, 95), 22, MUTED)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.button(app.ui, "← Galería", Rect2(150, 632, 980, 43), func(): build(app, "gallery")).grab_focus()

static func records(app) -> void:
	app.label(app.ui, "Tus mejores calificaciones y tiempos se conservan entre aventuras.", Rect2(65, 164, 1100, 30), 18, MUTED)
	for i in 4:
		var key := str(i + 1)
		var seconds := float(Progress.data.times.get(key, 0))
		var clock := "%02d:%02d.%02d" % [int(seconds) / 60, int(seconds) % 60, int(seconds * 100) % 100] if seconds > 0 else "—"
		app.panel(app.ui, Rect2(65 + i * 280, 213, 260, 125), Color("203b54"), 12)
		app.label(app.ui, "NIVEL %s · %s" % [key, str(Progress.data.best.get(key, "—"))], Rect2(83 + i * 280, 229, 225, 32), 23, MINT)
		app.label(app.ui, "Mejor tiempo: " + clock, Rect2(83 + i * 280, 284, 235, 28), 17, MUTED)
	var row := 0
	for id in Progress.ACHIEVEMENTS:
		var earned: bool = id in Progress.data.achievements
		app.label(app.ui, ("✓  " if earned else "○  ") + Progress.ACHIEVEMENTS[id], Rect2(75, 359 + row * 36, 1090, 31), 18, MINT if earned else MUTED)
		row += 1
