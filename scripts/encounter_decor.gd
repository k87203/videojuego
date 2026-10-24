extends Node2D
## Background set dressing for the authored encounters. Origin: chunk start, floor height.
var encounter := "clase"
var desks: Array = []

func _draw() -> void:
	var ink := Color("203049")
	match encounter:
		"clase":
			# Chalkboard with the day's lesson, a teacher's desk and student desks under the platforms.
			draw_rect(Rect2(250, -360, 560, 190), Color("5b3a29"))
			draw_rect(Rect2(262, -348, 536, 166), Color("2f5d4e"))
			draw_string(ThemeDB.fallback_font, Vector2(290, -300), "∫ x² dx = ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("eef5ff"))
			draw_string(ThemeDB.fallback_font, Vector2(290, -240), "EXAMEN: VIERNES", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe08a"))
			draw_line(Vector2(560, -230), Vector2(760, -270), Color(1, 1, 1, 0.6), 3, true)
			for desk in desks:
				var x: float = desk[0]
				var top: float = desk[1]
				for side in [8.0, desk[2] - 8.0]: draw_line(Vector2(x + side, top + 24), Vector2(x + side, 0), Color("6b4b36"), 5)
				draw_rect(Rect2(x + desk[2] * 0.5 - 14, top + 40, 28, 6), Color("8a6a52"))
			draw_rect(Rect2(900, -70, 180, 70), Color("8a6a52"))
			draw_rect(Rect2(900, -76, 180, 8), Color("b08d6b"))
		"ventanilla":
			# Service window with a queue rope, a turn display and stacks of paperwork.
			draw_rect(Rect2(820, -260, 330, 260), Color("3c5874"))
			draw_rect(Rect2(850, -230, 270, 120), Color("b9d6e6"))
			draw_rect(Rect2(840, -110, 290, 20), Color("8a6a52"))
			draw_string(ThemeDB.fallback_font, Vector2(850, -276), "SERVICIOS ESCOLARES", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffdf99"))
			draw_rect(Rect2(1000, -330, 120, 44), ink)
			draw_string(ThemeDB.fallback_font, Vector2(1010, -300), "TURNO 404", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff6b6b"))
			for i in 4:
				var post := 220.0 + i * 160
				draw_line(Vector2(post, 0), Vector2(post, -70), Color("c9a227"), 5)
				draw_circle(Vector2(post, -72), 6, Color("c9a227"))
				if i < 3: draw_arc(Vector2(post + 80, -90), 82, 0.55, PI - 0.55, 14, Color("b03a48"), 4, true)
			for i in 5: draw_rect(Rect2(870 + i * 8, -130 - i * 6, 60, 6), Color("fffaf0"))
		"laboratorio":
			# Rows of computer desks and a whiteboard with a failing build.
			for i in 4:
				var x := 120.0 + i * 260
				draw_rect(Rect2(x, -60, 200, 10), Color("6c7a8a"))
				draw_line(Vector2(x + 10, -50), Vector2(x + 10, 0), Color("4a5666"), 5)
				draw_line(Vector2(x + 190, -50), Vector2(x + 190, 0), Color("4a5666"), 5)
				for j in 2:
					draw_rect(Rect2(x + 20 + j * 95, -110, 70, 48), ink)
					draw_rect(Rect2(x + 24 + j * 95, -106, 62, 38), Color("3fd6a0") if (i + j) % 3 else Color("2a6fd6"))
			draw_rect(Rect2(300, -380, 520, 150), Color("e9eef2"))
			draw_string(ThemeDB.fallback_font, Vector2(320, -330), "BUILD FAILED: 404 bugs", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e2475b"))
			draw_string(ThemeDB.fallback_font, Vector2(320, -280), "while (examen) { estudiar(); }", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
