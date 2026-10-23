extends Node
## Rendered sheet of every enemy archetype: idle pose and attack warning (needs a window). Output: docs/enemigos-05.png
const KINDS := ["task", "virus", "robot", "clock", "hopper", "calc", "review", "coder", "dropper", "shield"]
var app

func _ready() -> void:
	Progress.session_only = true
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func crop(enemy, tall: bool) -> Image:
	await RenderingServer.frame_post_draw
	var at: Vector2 = enemy.get_global_transform_with_canvas().origin
	var image := get_viewport().get_texture().get_image()
	var top := int(at.y) - (360 if tall else 130)
	var region := image.get_region(Rect2i(int(at.x) - 130, top, 260, 400 if tall else 170))
	region.resize(260, 170, Image.INTERPOLATE_BILINEAR)
	return region

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks(2)
	app.start_level(3)
	await ticks(5)
	var w = app.world
	var p = w.player
	p.invulnerable = 999
	p.set_physics_process(false)
	w.set_process(false)
	w.extension.set_process(false)
	w.eagle.visible = false
	app.ui.visible = false
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	var sheet := Image.create(2 * 270, KINDS.size() * 180, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("07121e"))
	for row in KINDS.size():
		var kind: String = KINDS[row]
		p.position = Vector2(1700, 610)
		p.camera.reset_smoothing()
		var y := 410.0 if kind == "clock" else (330.0 if kind == "dropper" else 610.0)
		var e = w.spawn_enemy(kind, Vector2(1520, y))
		await ticks(3)
		e.set_physics_process(false)
		e.direction = 1
		e.queue_redraw()
		await ticks(2)
		sheet.blit_rect(await crop(e, kind == "dropper"), Rect2i(0, 0, 260, 170), Vector2i(5, row * 180 + 5))
		# Force the warning pose so every telegraph is visible in the same frame.
		e.direction = 1
		if kind == "dropper": e.drop_state = "warn"; e.drop_floor_y = 610.0
		if kind in ["hopper", "dropper"]: e.change_state(e.State.ATTACK)
		else: e.start_attack()
		e.windup = float(e.spec.windup) * 0.6
		e.queue_redraw()
		await ticks(1)
		sheet.blit_rect(await crop(e, kind == "dropper"), Rect2i(0, 0, 260, 170), Vector2i(275, row * 180 + 5))
		e.queue_free()
		await ticks(2)
	sheet.save_png("res://docs/enemigos-05.png")
	print("ENEMY SHEET: " + ", ".join(KINDS))
	Sound.shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
