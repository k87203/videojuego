extends Node2D
var world
var level_id := 1
var clock := 0.0
var sky: Texture2D
var campus: Texture2D

func _ready() -> void:
	sky = load("res://assets/art/sky%d.svg" % level_id)
	campus = load("res://assets/art/campus%d.svg" % level_id)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var ratio := viewport / Vector2(1280, 720)
	draw_set_transform(Vector2.ZERO, 0, ratio)
	if sky: draw_texture_rect(sky, Rect2(0, 0, 1280, 720), false)
	var scroll := clock * 8
	if world != null and is_instance_valid(world.player):
		scroll = world.player.camera.get_screen_center_position().x * 0.25
	var shift := fmod(scroll, 1600)
	if campus:
		for i in range(-1, 2):
			draw_texture(campus, Vector2(i * 1600 - shift, 0), Color(1, 1, 1, 0.88 if level_id == 1 else 1.0))
			var offset := i * 1600 - shift
			if level_id == 1:
				draw_string(ThemeDB.fallback_font, Vector2(offset + 468, 264), "TECNOLÓGICO · TLÁHUAC III", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9efdd"))
			else:
				for room in 4:
					var title: String = ["", "", "BIBLIOTECA  /  a² + b² = c²", "LABORATORIO DE SISTEMAS", "CEREMONIA DE TITULACIÓN"][level_id]
					draw_string(ThemeDB.fallback_font, Vector2(offset + room * 400 + 53, 154), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e4dfcc"))
	# Midground garden strips and walkway produce an independent depth layer.
	draw_rect(Rect2(0, 625, 1280, 95), Color("84aa9e") if level_id < 3 else Color("405875"))
	draw_rect(Rect2(0, 646, 1280, 18), Color("c2c5aa") if level_id < 3 else Color("667895"))
	for i in range(18):
		var x := fposmod(i * 85.0 - scroll * 1.8, 1400) - 60
		draw_line(Vector2(x, 665), Vector2(x - 20, 720), Color(0.85, 0.91, 0.87, 0.18), 2)
	# Ambient dust/fireflies are capped and deterministic.
	if world != null and is_instance_valid(world.player):
		var beat_glow := pow(1 - MusicManager.beat_phase(), 3)
		var intensity := maxf(MusicManager.difficulty, MusicManager.action_energy)
		var light := Color("72ffe2") if level_id < 3 else Color("b28dff")
		for i in 7:
			var x := fposmod(i * 205.0 - scroll * 1.8, 1450) - 80
			draw_line(Vector2(x, 628), Vector2(x + 95, 628), Color(light, .08 + beat_glow * intensity * .18), 3, true)
		# Low-opacity stage lights pulse with the actual music clock.
		for i in 3:
			var x := 200.0 + i * 450
			var polygon := PackedVector2Array([Vector2(x, 110), Vector2(x - 130, 620), Vector2(x + 170, 620)])
			draw_colored_polygon(polygon, Color(light, .012 + beat_glow * intensity * .018))
	for i in 18:
		var p := Vector2(fposmod(i * 91 + clock * (8 + i % 4), 1280), 180 + fposmod(i * 67.0 + sin(clock + i) * 12, 420))
		draw_circle(p, 1.5 + i % 2, Color(1, 0.94, 0.72, 0.18 + 0.12 * sin(clock * 1.7 + i)))
	if world != null and is_instance_valid(world.extension) and world.extension.chase_active:
		# Capped streaks and a soft edge pulse signal a pursuit without hiding hazards.
		for i in 9:
			var x := fposmod(i * 173.0 - clock * 620, 1500) - 100
			var y := 210.0 + i * 42
			draw_line(Vector2(x, y), Vector2(x + 75, y), Color(1, 0.85, 0.63, 0.14), 2, true)
		var alpha := 0.035 + 0.025 * sin(clock * 5)
		draw_rect(Rect2(0, 90, 16, 540), Color(1, 0.35, 0.4, alpha))
		draw_rect(Rect2(1264, 90, 16, 540), Color(1, 0.35, 0.4, alpha))
	draw_set_transform(Vector2.ZERO)
