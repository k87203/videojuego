extends Area2D
var world
var velocity := Vector2.ZERO
var tint := Color("ff9e8a")
var lifetime := 5.0
var age := 0.0
## Optional shapes of fire: arcing lobs, ground-crawling bugs and glyph art.
var fall_gravity := 0.0
var crawl := false
var glyph := ""
var destructible := false
## "low" shots must be jumped, "high" shots slid or crouched under; route bots read these groups.
var lane := ""

func _ready() -> void:
	collision_layer = 0
	# Crawlers walk on the floor, so they only react to the student; walls are checked by ray.
	collision_mask = 2 if crawl else 3
	if lane != "": add_to_group("lane_" + lane)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9
	col.shape = circle
	add_child(col)
	body_entered.connect(func(body):
		if body == world.player: body.hurt(position)
		world.fx.burst(position, tint, 6)
		queue_free())

func _physics_process(delta: float) -> void:
	age += delta
	if crawl:
		var space := get_world_2d().direct_space_state
		var heading := signf(velocity.x)
		var wall := PhysicsRayQueryParameters2D.create(position + Vector2(0, -6), position + Vector2(heading * 14, -6), 1)
		if not space.intersect_ray(wall).is_empty():
			smash()
			return
		var ground := PhysicsRayQueryParameters2D.create(position + Vector2(heading * 8, -4), position + Vector2(heading * 8, 30), 1)
		if fall_gravity == 0 and space.intersect_ray(ground).is_empty(): fall_gravity = 1200
	velocity.y += fall_gravity * delta
	position += velocity * delta
	if age > lifetime or position.y > 840: queue_free()
	queue_redraw()

func smash() -> void:
	world.fx.burst(position, tint, 8)
	queue_free()

func _draw() -> void:
	match glyph:
		"∫":
			draw_circle(Vector2.ZERO, 15, Color(tint, 0.16))
			draw_set_transform(Vector2.ZERO, age * 5)
			draw_string(ThemeDB.fallback_font, Vector2(-7, 10), "∫", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("203049"))
			draw_string(ThemeDB.fallback_font, Vector2(-8, 9), "∫", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, tint)
		"paper":
			for i in 3:
				var flutter := sin(age * 20 + i) * 2
				draw_rect(Rect2(-14 + i * 6, -12 + i * 2 + flutter, 16, 12), Color("203049"))
				draw_rect(Rect2(-13 + i * 6, -11 + i * 2 + flutter, 14, 10), tint)
				draw_line(Vector2(-10 + i * 6, -6 + i * 2 + flutter), Vector2(-2 + i * 6, -6 + i * 2 + flutter), Color("e2475b"), 1.5)
		"error":
			draw_rect(Rect2(-16, -11, 32, 22), Color("203049"))
			draw_rect(Rect2(-15, -10, 30, 20), Color("eef5ff"))
			draw_rect(Rect2(-15, -10, 30, 6), tint)
			draw_line(Vector2(-5, -1), Vector2(5, 8), Color("e2475b"), 2.5)
			draw_line(Vector2(5, -1), Vector2(-5, 8), Color("e2475b"), 2.5)
		"bug":
			var step := sin(age * 30) * 2
			for i in 3:
				draw_line(Vector2(-5 + i * 5, 0), Vector2(-8 + i * 5, 6 + (step if i % 2 else -step)), Color("203049"), 2, true)
			draw_circle(Vector2(0, -2), 8, Color("203049"))
			draw_circle(Vector2(0, -2), 6, Color("e2475b"))
			draw_line(Vector2(0, -8), Vector2(0, 4), Color("203049"), 1.5)
			var front := signf(velocity.x) if velocity.x != 0 else 1.0
			draw_line(Vector2(front * 6, -6), Vector2(front * 11, -12), Color("203049"), 1.5, true)
			draw_circle(Vector2(front * 4, -4), 1.5, Color("fff6dc"))
		_:
			draw_circle(Vector2.ZERO, 14, Color(tint, 0.16))
			draw_circle(Vector2.ZERO, 8, tint)
			draw_circle(Vector2(-2, -2), 3, Color("fff4dc"))
			draw_line(-velocity.normalized() * 11, -velocity.normalized() * 26, Color(tint, 0.5), 3, true)
