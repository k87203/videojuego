extends Node2D
var particles: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var font: Font = ThemeDB.fallback_font

func burst(pos: Vector2, color: Color, count: int = 14) -> void:
	for i in mini(count, 240 - particles.size()):
		particles.append({"p": pos, "v": Vector2(randf_range(-130, 130), randf_range(-210, -40)), "life": randf_range(0.3, 0.8), "color": color, "size": randf_range(2, 5)})

func floating(pos: Vector2, message: String, color: Color = Color("ffdc79")) -> void:
	labels.append({"p": pos, "text": message, "life": 1.4, "color": color})

func ring(pos: Vector2, color: Color, radius: float = 40) -> void:
	if rings.size() >= 24: rings.pop_front()
	rings.append({"p": pos, "color": color, "r": radius, "life": 0.3})

func _process(delta: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i].life -= delta
		if rings[i].life <= 0: rings.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= delta
		p.v.y += 420 * delta
		p.p += p.v * delta
		if p.life <= 0:
			particles.remove_at(i)
	for i in range(labels.size() - 1, -1, -1):
		labels[i].life -= delta
		labels[i].p.y -= delta * 32
		if labels[i].life <= 0:
			labels.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for r in rings:
		var color: Color = r.color
		color.a *= r.life / 0.3
		draw_arc(r.p, r.r * (1.25 - r.life / 0.3), 0, TAU, 36, color, 3, true)
	for p in particles:
		var color: Color = p.color
		color.a = minf(1, p.life * 3)
		draw_circle(p.p, p.size, color)
	for label in labels:
		var color: Color = label.color
		color.a = minf(1, label.life * 2)
		draw_string(font, label.p, label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 19, color)
