extends Node2D
var world
var clock := 0.0
var help_timer := 8.0
var tip_timer := 0.0
var last_zone := -1
var scan_timer := 0.0
var guided_target := Vector2.ZERO
var guiding := false

func _process(delta: float) -> void:
	clock += delta
	if not is_instance_valid(world.player): return
	var p = world.player
	var target: Vector2 = p.position + Vector2(-90 * p.facing, -130 + sin(clock * 2) * 14)
	scan_timer -= delta
	if scan_timer <= 0:
		scan_timer = 0.2
		guiding = false
		for child in world.all_props():
			if child.kind in ["usb", "cache"] and not child.collected and absf(child.position.x - p.position.x) < (600 if p.character_id == "sofia" else 220):
				guided_target = child.position + Vector2(-38, -45)
				guiding = true
				if tip_timer <= 0:
					world.say("AZTLI", "¡Sígueme arriba! Hay una recompensa escondida en esta ruta.", 4)
					tip_timer = 15
				break
		for child in get_tree().get_nodes_in_group("hazards"):
			if tip_timer <= 0 and child.position.x - p.position.x > 0 and child.position.x - p.position.x < 220:
				world.say("AZTLI", "¡Cuidado! Espera a que se apague la descarga." if child.electric else "¡Obstáculo adelante! Salta para evitarlo.", 3)
				tip_timer = 12
	if guiding: target = guided_target + Vector2(0, sin(clock * 2) * 10)
	position = position.lerp(target, 1.0 - exp(-delta * 4))
	help_timer -= delta
	tip_timer -= delta
	if world.boss != null and is_instance_valid(world.boss) and world.boss.active and not world.boss.dead and help_timer <= 0:
		help_timer = 10
		world.boss.expose(3.0)
		world.say("AZTLI", "¡Ahora! Lo distraje. Golpea con J o salta sobre él.", 3.5)
		Sound.sfx("eagle")
		world.fx.burst(world.boss.position + Vector2(0, -65), Color("ffdf87"), 24)
	var zone := int(p.position.x / 1200)
	if zone != last_zone and tip_timer <= 0:
		last_zone = zone
		tip_timer = 12
		if zone == 1:
			world.say("AZTLI", "Mira arriba: las USB doradas suelen esconderse en rutas altas.", 5)
		elif zone == 3:
			world.say("AZTLI", "Activa los faros turquesa. Son puntos de reaparición.", 5)
	queue_redraw()

func _draw() -> void:
	var flap := sin(clock * 11) * 19
	var gold := Color("e8af58")
	var dark := Color("654b3e")
	for side in [-1, 1]:
		var wing := PackedVector2Array([Vector2(side * 5, 3), Vector2(side * 25, -17 - flap), Vector2(side * 51, -8 - flap), Vector2(side * 40, 5 - flap * 0.3), Vector2(side * 29, 8), Vector2(side * 17, 17)])
		draw_colored_polygon(wing, dark)
		for i in 3:
			draw_line(Vector2(side * (18 + i * 8), -5 - flap * 0.5), Vector2(side * (25 + i * 8), 5 - flap * 0.4), gold, 5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 9), Vector2(-13, 28), Vector2(0, 22), Vector2(11, 28), Vector2(9, 9)]), gold)
	draw_circle(Vector2(0, 5), 13, dark)
	draw_circle(Vector2(3, -8), 12, Color("fff2d7"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, -9), Vector2(24, -3), Vector2(10, 1)]), Color("ffbd58"))
	draw_circle(Vector2(8, -10), 2.5, Color("203049"))
	draw_arc(Vector2(0, 0), 34, clock, clock + 1.7, 20, Color(1, 0.83, 0.45, 0.3), 1.5, true)
