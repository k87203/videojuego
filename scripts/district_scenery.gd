extends Node2D
## Original cached vector foreground. District recipes change architecture and decoration.
var level_id := 1
var section := 0
var kind := "garden"
var title := ""

func _draw() -> void:
	var colors := [Color("4a9d87"), Color("8c748d"), Color("4e8697"), Color("ad8292")]
	var tint: Color = colors[level_id - 1]
	for i in 3:
		var x := 130.0 + i * 400
		if kind in ["garden", "terraces", "bridges"]:
			draw_line(Vector2(x, 0), Vector2(x, -160), Color("967654"), 10)
			for j in 3:
				draw_circle(Vector2(x - 28 + j * 26, -160 - (j % 2) * 26), 38, tint)
				draw_circle(Vector2(x - 33 + j * 26, -174 - (j % 2) * 26), 24, tint.lightened(0.18))
		elif kind in ["moving", "collapse", "workshop", "electric"]:
			draw_line(Vector2(x, -250), Vector2(x, 0), Color("526e83"), 9)
			draw_line(Vector2(x, -250), Vector2(x + 300, -250), Color("526e83"), 7)
			for j in 5: draw_line(Vector2(x + 20 + j * 60, -248), Vector2(x + 20 + j * 60, -190), Color(tint, 0.6), 3)
			draw_rect(Rect2(x + 32, -115, 160, 115), Color("34566e"))
			for j in 3:
				draw_rect(Rect2(x + 42, -100 + j * 31, 140, 22), tint)
				draw_circle(Vector2(x + 168, -89 + j * 31), 3, Color("abf5cc"))
		elif kind == "library":
			draw_rect(Rect2(x - 40, -210, 210, 210), Color("765f56"))
			for row in 3:
				for book in 8:
					draw_rect(Rect2(x - 32 + book * 24, -196 + row * 65 + book % 3 * 5, 17, 50 - book % 3 * 5), [tint, Color("e5bb86"), Color("8ec6ba")][book % 3])
				draw_line(Vector2(x - 40, -142 + row * 65), Vector2(x + 170, -142 + row * 65), Color("bd9b74"), 6)
		else:
			draw_line(Vector2(x, 0), Vector2(x, -125), Color("536d80"), 5)
			draw_colored_polygon(PackedVector2Array([Vector2(x, -125), Vector2(x + 100, -104), Vector2(x, -78)]), tint)
			draw_string(ThemeDB.fallback_font, Vector2(x + 15, -101), "%02d" % (section + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffedc5"))
	if title != "":
		draw_rect(Rect2(15, -310, 650, 50), Color("1c3b54"))
		draw_line(Vector2(15, -310), Vector2(665, -310), tint.lightened(0.35), 4)
		draw_string(ThemeDB.fallback_font, Vector2(35, -278), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ffdf99"))
