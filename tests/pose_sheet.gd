extends Node
## Rendered contact sheet of student poses (needs a window, not --headless). Output: docs/poses-05.png
var app
var shots: Array[Dictionary] = []

func _ready() -> void:
	Progress.session_only = true
	Progress.data.double_jump = true
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func shot(caption: String) -> void:
	await RenderingServer.frame_post_draw
	var p = app.world.player
	var at: Vector2 = p.get_global_transform_with_canvas().origin
	var image := get_viewport().get_texture().get_image()
	var crop := image.get_region(Rect2i(int(at.x) - 70, int(at.y) - 120, 140, 140))
	crop.resize(280, 280, Image.INTERPOLATE_NEAREST)
	shots.append({"image": crop, "caption": caption})

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(2)
	app.start_level(1)
	await ticks(5)
	var w = app.world
	var p = w.player
	p.invulnerable = 999
	w.set_process(false)
	app.ui.visible = false
	p.position = Vector2(2760, 610)
	await ticks(30)
	await shot("quieto")
	Input.action_press("right")
	Input.action_press("run")
	await ticks(6)
	await shot("arranque (inclinación)")
	await ticks(30)
	for i in 4:
		await shot("carrera %d" % (i + 1))
		await ticks(3)
	Input.action_release("run")
	Input.action_release("right")
	Input.action_press("left")
	await ticks(4)
	await shot("frenado (polvo)")
	Input.action_release("left")
	await ticks(40)
	Input.action_press("jump")
	await ticks(1)
	await shot("anticipación")
	await ticks(4)
	await shot("despegue (estirar)")
	Input.action_release("jump")
	await ticks(14)
	await shot("en el aire")
	while not p.is_on_floor(): await ticks(1)
	await ticks(1)
	await shot("aterrizaje (aplastar)")
	await ticks(30)
	var target = w.spawn_enemy("task", p.position + Vector2(50 * p.facing, 0))
	await ticks(1)
	Input.action_press("attack")
	await ticks(2)
	await shot("golpe (hit-stop)")
	Input.action_release("attack")
	# Compose a 4-column sheet with captions drawn by the engine font onto a SubViewport-free image.
	var columns := 4
	var rows := ceili(shots.size() / float(columns))
	var sheet := Image.create(columns * 290, rows * 300, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("07121e"))
	for i in shots.size():
		sheet.blit_rect(shots[i].image, Rect2i(0, 0, 280, 280), Vector2i((i % columns) * 290 + 5, (i / columns) * 300 + 5))
	sheet.save_png("res://docs/poses-05.png")
	var names: Array = []
	for s in shots: names.append(s.caption)
	print("POSE SHEET: " + ", ".join(names))
	if is_instance_valid(target): target.queue_free()
	Sound.shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
