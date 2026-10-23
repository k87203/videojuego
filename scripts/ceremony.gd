extends Node2D
## Short in-engine graduation animation; original vector props and reusable character rig.
var clock := 0.0
var student: Node2D
var eagle: Node2D

func _ready() -> void:
	student = Node2D.new()
	student.set_script(preload("res://scripts/menu_actor.gd"))
	student.position = Vector2(880, 550)
	student.scale = Vector2(2.7, 2.7)
	student.facing = 1
	add_child(student)
	eagle = Node2D.new()
	eagle.set_script(preload("res://scripts/aztli.gd"))
	eagle.scale = Vector2(1.8, 1.8)
	add_child(eagle)
	eagle.set_process(false)

func _process(delta: float) -> void:
	clock += delta
	eagle.clock = clock
	eagle.position = Vector2(965 + sin(clock * 1.3) * 45, 275 + sin(clock * 2) * 15)
	eagle.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(735, 550, 350, 15), Color("cfae7c"))
	draw_rect(Rect2(755, 565, 310, 15), Color("8e7383"))
	var y := 320 - absf(sin(minf(clock, PI))) * 110
	var x := 880 + sin(clock * 1.7) * 10
	draw_colored_polygon(PackedVector2Array([Vector2(x - 50, y), Vector2(x, y - 25), Vector2(x + 50, y), Vector2(x, y + 25)]), Color("16394c"))
	draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + 37, y + 6), Vector2(x + 39, y + 42)]), Color("f6cf7d"), 3, true)
	draw_circle(Vector2(x + 39, y + 45), 5, Color("f6cf7d"))
	if clock > 1:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("ffedbd")
		paper.set_corner_radius_all(5)
		draw_style_box(paper, Rect2(960, 430 + sin(clock * 3) * 3, 80, 58))
		draw_line(Vector2(973, 445), Vector2(1025, 445), Color("bd9c65"), 3)
		draw_circle(Vector2(1004, 468), 10, Color("dfad62"))
