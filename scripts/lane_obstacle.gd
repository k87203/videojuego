extends Area2D
## Pursuit-course obstacle. "low": mop bucket on the floor (jump it). "high": flying hall reports
## at head height (slide or crouch under: a crouched student is 30 px tall, the reports start 39 px up).
var world
var lane := "low"
var clock := 0.0
var label := ""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("obstacles")
	add_to_group("lane_" + lane)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 32) if lane == "low" else Vector2(66, 26)
	col.shape = rect
	col.position = Vector2(0, -16) if lane == "low" else Vector2(0, -52)
	add_child(col)
	clock = fposmod(position.x * 0.01, TAU)
	if world.take_lane_hint(lane): label = "¡SALTA!" if lane == "low" else "¡DESLÍZATE!"

func _physics_process(delta: float) -> void:
	clock += delta
	var p = world.player
	visible = absf(position.x - p.position.x) < 1100
	if not visible: return
	for body in get_overlapping_bodies():
		if body == p: p.hurt(position + Vector2(-30, 0))
	queue_redraw()

func _draw() -> void:
	var p = world.player
	var ahead: float = position.x - p.position.x
	var warn := ahead > 0 and ahead < 520
	var ink := Color("203049")
	if warn:
		var pulse := Color(1, 0.3, 0.38, 0.35 + 0.3 * sin(clock * 18))
		var y := -14.0 if lane == "low" else -52.0
		draw_rect(Rect2(-60, y - 2, 120, 4), pulse)
		if label != "": draw_string(ThemeDB.fallback_font, Vector2(-40, y - (34 if lane == "low" else 26)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe08a"))
	if lane == "low":
		# Mop bucket with the mop leaning out of it.
		draw_line(Vector2(6, -30), Vector2(22, -64), Color("a77b58"), 4, true)
		draw_colored_polygon(PackedVector2Array([Vector2(16, -66), Vector2(30, -62), Vector2(27, -56), Vector2(14, -60)]), Color("d8d2c4"))
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -30), Vector2(20, -30), Vector2(16, 0), Vector2(-16, 0)]), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(14, -2), Vector2(-14, -2)]), Color("f2c14e"))
		draw_rect(Rect2(-14, -24, 28, 4), Color("5aa9ff"))
		draw_arc(Vector2(0, -30), 16, PI, TAU, 12, ink, 2, true)
	else:
		# Flying hall reports: three sheets fluttering at head height.
		for i in 3:
			var bob := sin(clock * 7 + i) * 3
			var x := -26.0 + i * 22
			draw_set_transform(Vector2(x, -52 + bob), sin(clock * 5 + i) * 0.2)
			draw_rect(Rect2(-10, -12, 20, 24), ink)
			draw_rect(Rect2(-9, -11, 18, 22), Color("fffaf0"))
			draw_line(Vector2(-6, -5), Vector2(6, -5), Color("e2475b"), 2)
			draw_line(Vector2(-6, 1), Vector2(6, 1), Color("a7bcc9"), 1.5)
			draw_line(Vector2(-6, 6), Vector2(3, 6), Color("a7bcc9"), 1.5)
		draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, Vector2(-28, -72), "REPORTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e2475b"))
