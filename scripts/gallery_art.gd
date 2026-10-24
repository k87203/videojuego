extends Node2D
## Four original campus prints, drawn with the game's own vector vocabulary.
var level := 1
var locked := false

func _draw() -> void:
	var colors := [Color("245968"), Color("54426e"), Color("243b67"), Color("725246")]
	var sky: Color = colors[clampi(level - 1, 0, 3)]
	draw_rect(Rect2(0, 0, 760, 370), sky)
	draw_circle(Vector2(590, 80), 45, Color("ffe1a0"))
	for i in 12: draw_circle(Vector2(30 + i * 61, 25 + (i * 47) % 145), 2, Color("bce9e4"))
	draw_rect(Rect2(0, 290, 760, 80), Color("173b49"))
	match level:
		1:
			for i in 3:
				var x := 100 + i * 185
				draw_line(Vector2(x, 300), Vector2(x + 10, 110), Color("a47d61"), 14, true)
				for j in 4: draw_circle(Vector2(x - 35 + j * 23, 120 - sin(j) * 40), 44, Color("53b69c"))
			for i in 7: draw_line(Vector2(30 + i * 115, 325), Vector2(100 + i * 115, 325), Color("6dc9d0"), 4, true)
		2:
			for i in 7:
				var height := 100 + (i * 37) % 95
				draw_rect(Rect2(100 + i * 78, 290 - height, 55, height), [Color("ffca80"), Color("9ce1cc"), Color("a69dff")][i % 3])
				draw_line(Vector2(113 + i * 78, 275 - height), Vector2(113 + i * 78, 275), Color("29425a"), 3)
		3:
			for i in 5:
				var y := 80 + i * 43
				draw_polyline(PackedVector2Array([Vector2(55, y), Vector2(210 + i * 50, y), Vector2(250 + i * 50, y + 32), Vector2(690, y + 32)]), Color("67ffe3"), 3, true)
				draw_circle(Vector2(690, y + 32), 7, Color("ffe1a0"))
			draw_rect(Rect2(285, 125, 160, 130), Color("182944"))
			draw_string(ThemeDB.fallback_font, Vector2(306, 202), "TEC III", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("67ffe3"))
		4:
			for i in 4:
				var x := 160 + i * 135
				draw_circle(Vector2(x, 205), 18, Color("edbe9c"))
				draw_rect(Rect2(x - 22, 226, 44, 66), [Color("67ffe3"), Color("a69dff"), Color("ffca80"), Color("f2959e")][i])
				draw_line(Vector2(x - 20, 240), Vector2(x - 44, 192), Color("edbe9c"), 8, true)
				draw_line(Vector2(x + 20, 240), Vector2(x + 44, 192), Color("edbe9c"), 8, true)
			draw_polyline(PackedVector2Array([Vector2(280, 95), Vector2(355, 120), Vector2(380, 103), Vector2(405, 120), Vector2(480, 95)]), Color("ffe1a0"), 10, true)
	if locked:
		# Keep the illustration visible; a small lock badge marks its unlock condition.
		draw_rect(Rect2(0, 0, 760, 370), Color(0.02, 0.05, 0.1, 0.14))
		draw_set_transform(Vector2(665, 275))
		draw_circle(Vector2.ZERO, 62, Color("10283f"))
		draw_arc(Vector2.ZERO, 62, 0, TAU, 40, Color("f7d48b"), 3, true)
		draw_arc(Vector2(0, -9), 23, PI, TAU, 24, Color("f7d48b"), 8, true)
		draw_rect(Rect2(-28, -9, 56, 42), Color("f7d48b"))
		draw_circle(Vector2(0, 7), 6, Color("10283f"))
		draw_line(Vector2(0, 9), Vector2(0, 20), Color("10283f"), 5, true)
		draw_set_transform(Vector2.ZERO)
