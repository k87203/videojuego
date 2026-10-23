extends Control
## Vector HUD icons with an ink outline so they read over any background.
const UI = preload("res://scripts/ui_theme.gd")
var kind := "coin"
var current := 0
var maximum := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_counts(value: int, limit: int) -> void:
	if value == current and limit == maximum: return
	current = value
	maximum = limit
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	match kind:
		"hearts":
			for i in maximum: heart(Vector2(14 + i * 30, size.y * 0.5), 12, i < current)
		"coin":
			draw_circle(c, r, UI.INK)
			draw_circle(c, r - 2, Color("c58e3e"))
			draw_circle(c + Vector2(-1, -1), r - 4, UI.GOLD)
			draw_arc(c + Vector2(-1, -1), r - 8, 0, TAU, 24, Color("fff0b8"), 1.5, true)
			draw_line(c + Vector2(-1, -r * 0.35), c + Vector2(-1, r * 0.3), Color("a77035"), 2.5, true)
		"usb":
			outlined_rect(Rect2(c.x - 7, c.y - 4, 14, 18), UI.GOLD)
			outlined_rect(Rect2(c.x - 5, c.y - 13, 10, 9), Color("e5edf2"))
			draw_circle(c + Vector2(0, 8), 2.5, Color("fff6db"))
		"document":
			outlined_rect(Rect2(c.x - 11, c.y - 12, 22, 24), Color("fff2d2"))
			draw_rect(Rect2(c.x - 7, c.y - 7, 14, 3), UI.ACCENT)
			draw_line(c + Vector2(-7, 0), c + Vector2(5, 0), UI.INK, 1.5)
			draw_circle(c + Vector2(5, 7), 4, UI.GOLD)
		"lives":
			draw_circle(c + Vector2(0, -4), 5.5, UI.INK)
			draw_circle(c + Vector2(0, -4), 4, UI.ACCENT)
			draw_arc(c + Vector2(0, 9), 7, PI, TAU, 14, UI.INK, 5, true)
			draw_arc(c + Vector2(0, 9), 7, PI, TAU, 14, UI.ACCENT, 3, true)
		"feather":
			var quill := PackedVector2Array([c + Vector2(-8, 10), c + Vector2(2, -11), c + Vector2(9, -10), c + Vector2(-3, 9)])
			draw_colored_polygon(grow(quill, c, 1.25), UI.INK)
			draw_colored_polygon(quill, UI.GOLD)
			draw_line(c + Vector2(-9, 12), c + Vector2(6, -8), Color("fff6dc"), 1.5, true)
		"shield":
			var crest := PackedVector2Array([c + Vector2(-9, -9), c + Vector2(9, -9), c + Vector2(7, 4), c + Vector2(0, 11), c + Vector2(-7, 4)])
			draw_colored_polygon(grow(crest, c, 1.25), UI.INK)
			draw_colored_polygon(crest, Color("6ee6de"))
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3), c + Vector2(5, -4)]), UI.INK, 2, true)
		"coffee":
			outlined_rect(Rect2(c.x - 8, c.y - 6, 14, 15), Color("fff0d6"))
			draw_rect(Rect2(c.x - 8, c.y - 2, 14, 5), Color("ba8154"))
			draw_arc(c + Vector2(7, 1), 4, -PI / 2, PI / 2, 10, UI.INK, 2.5, true)
			draw_line(c + Vector2(-3, -9), c + Vector2(-1, -13), Color("c5f2e9"), 1.5, true)
		"clock":
			draw_circle(c, r, UI.INK)
			draw_circle(c, r - 2, UI.GOLD)
			draw_circle(c, r - 4, Color("fff6dc"))
			draw_line(c, c + Vector2(0, -r * 0.55), UI.INK, 2, true)
			draw_line(c, c + Vector2(r * 0.4, 0), UI.INK, 2, true)

func heart(center: Vector2, radius: float, full: bool) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		points.append(center + Vector2(16 * pow(sin(a), 3), -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))) * radius / 17.0)
	draw_colored_polygon(grow(points, center, 1.2), UI.INK)
	draw_colored_polygon(points, Color("ff7f96") if full else Color(1, 0.6, 0.66, 0.16))
	if full: draw_circle(center + Vector2(-radius * 0.4, -radius * 0.35), radius * 0.18, Color(1, 1, 1, 0.55))

func outlined_rect(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(2), UI.INK)
	draw_rect(rect, color)

func grow(points: PackedVector2Array, center: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points: out.append(center + (p - center) * factor)
	return out
