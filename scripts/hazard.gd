extends Area2D
var world
var width := 85.0
var clock := 0.0
var electric := false
var on := true

func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 0
	collision_mask = 2
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 24)
	col.shape = rect
	col.position = Vector2(width / 2, -10)
	add_child(col)

func _physics_process(delta: float) -> void:
	clock += delta
	on = not electric or fmod(clock, 3.2) < 1.8
	visible = absf(position.x - world.player.position.x) < 1050
	if not visible: return
	if on:
		for body in get_overlapping_bodies():
			if body == world.player: body.hurt(position + Vector2(width / 2, 0))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, -5, width, 8), Color("253c55"))
	for x in range(0, int(width), 17):
		if electric:
			draw_circle(Vector2(x + 8, -6), 4, Color("75e6ed") if on else Color("57758e"))
			if on:
				draw_polyline(PackedVector2Array([Vector2(x, -8), Vector2(x + 6, -28 + sin(clock * 28 + x) * 6), Vector2(x + 11, -12), Vector2(x + 17, -22)]), Color("a2f5f4"), 2, true)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x, -5), Vector2(x + 8, -26), Vector2(x + 16, -5)]), Color("eaa78c"))
