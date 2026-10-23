extends Area2D
var world
var velocity := Vector2.ZERO
var tint := Color("ff9e8a")
var lifetime := 5.0
var age := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
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
	position += velocity * delta
	if age > lifetime: queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14, Color(tint, 0.16))
	draw_circle(Vector2.ZERO, 8, tint)
	draw_circle(Vector2(-2, -2), 3, Color("fff4dc"))
	draw_line(-velocity.normalized() * 11, -velocity.normalized() * 26, Color(tint, 0.5), 3, true)
