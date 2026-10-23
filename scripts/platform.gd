extends AnimatableBody2D
var size := Vector2(160, 26)
var travel := Vector2.ZERO
var period := 4.0
var phase := 0.0
var origin := Vector2.ZERO
var clock := 0.0
var tech := false
var ground := false
var gate := false
var world
var requirement := ""
var open := false
var col: CollisionShape2D
var crumbling := false
var break_delay := 0.8
var break_timer := -1.0
var restore_timer := 0.0
var fallen := false

func _ready() -> void:
	origin = position
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	col = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = size * 0.5
	col.one_way_collision = not ground and size.y < 60
	col.one_way_collision_margin = 8
	add_child(col)
	if travel != Vector2.ZERO:
		constant_linear_velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if travel == Vector2.ZERO and not crumbling and not gate:
		set_physics_process(false)
		return
	clock += delta
	if crumbling:
		if fallen:
			restore_timer -= delta
			position.y = origin.y + minf(160, (6 - restore_timer) * 220)
			modulate.a = maxf(0, restore_timer - 5)
			if restore_timer <= 0:
				fallen = false
				break_timer = -1
				position = origin
				modulate.a = 1
				col.set_deferred("disabled", false)
		elif is_instance_valid(world.player):
			var p = world.player
			if break_timer < 0 and p.is_on_floor() and absf(p.position.y - position.y) < 10 and p.position.x > position.x - 16 and p.position.x < position.x + size.x + 16:
				break_timer = break_delay
				Sound.sfx("crumble")
			if break_timer >= 0:
				break_timer -= delta
				position.x = origin.x + sin(clock * 60) * 2
				queue_redraw()
				if break_timer <= 0:
					fallen = true
					restore_timer = 6
					col.set_deferred("disabled", true)
	if travel != Vector2.ZERO:
		position = origin + travel * (0.5 - 0.5 * cos(clock * TAU / period + phase))
	if gate:
		var should_open: bool = world.has_credential if requirement == "credential" else (world.switch_on if requirement == "switch" else not world.arena_closed)
		if should_open != open:
			open = should_open
			col.set_deferred("disabled", open)
			Sound.sfx("door")
			queue_redraw()

func _draw() -> void:
	if gate:
		if open:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 12)), Color("61dac9"))
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("324c6c"))
		for y in range(8, int(size.y), 24):
			draw_line(Vector2(5, y), Vector2(size.x - 5, y), Color("8aafc1"), 3)
		draw_rect(Rect2(0, 0, 4, size.y), Color("ffb178"))
		return
	if ground:
		draw_rect(Rect2(Vector2(0, 8), size - Vector2(0, 8)), Color("273d50") if tech else Color("526464"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 18)), Color("66d4bf") if not tech else Color("6e91bc"))
		draw_line(Vector2(0, 19), Vector2(size.x, 19), Color("1d3a4d"), 4)
		for x in range(10, int(size.x), 76):
			draw_line(Vector2(x, 43), Vector2(x + 35, 43), Color(0.6, 0.75, 0.72, 0.15), 2)
			if not tech:
				draw_line(Vector2(x, 3), Vector2(x + 4, -5), Color("c1ebbb"), 2, true)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("d88859") if crumbling else (Color("395a78") if tech else Color("bd8e63"))
		s.border_color = Color("243b55")
		s.set_border_width_all(2)
		s.set_corner_radius_all(5)
		draw_style_box(s, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(3, 0, size.x - 6, 6), Color("7be5db") if tech else Color("e9c287"))
		for x in range(15, int(size.x), 32): draw_circle(Vector2(x, size.y - 7), 2, Color("f6dd9c"))
		if crumbling:
			for x in range(25, int(size.x), 45):
				draw_polyline(PackedVector2Array([Vector2(x, 5), Vector2(x + 8, 12), Vector2(x + 2, 18), Vector2(x + 10, size.y)]), Color("704c46"), 2, true)
		if travel != Vector2.ZERO:
			draw_line(Vector2(size.x * 0.5 - 12, size.y + 6), Vector2(size.x * 0.5 + 12, size.y + 6), Color("7df6e1"), 3)
