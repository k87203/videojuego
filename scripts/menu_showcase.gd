extends Node2D
## Original vector key art. Geometry is deliberately different from the in-game rig.
var character_id := "alex"
var clock := 0.0
var mouse := Vector2.ZERO
const CYAN := Color("67ffe3")
const VIOLET := Color("9f83ff")

func _process(delta: float) -> void:
	clock += delta
	var target := (get_local_mouse_position() - Vector2(850, 360)) * 0.013
	target = target.limit_length(10)
	mouse = mouse.lerp(target, 1 - exp(-delta * 3))
	queue_redraw()

func poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p in points: packed.append(Vector2(p[0], p[1]))
	draw_colored_polygon(packed, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("080e1c"))
	for i in 24:
		var y := float(i) * 30
		draw_rect(Rect2(0, y, 1280, 30), Color(0.025 + i * 0.0007, 0.045 + i * 0.001, 0.09 + i * 0.0018))
	poly([[748, 75], [1250, 75], [1250, 646], [697, 646], [637, 554]], Color("101a30"))
	poly([[932, 76], [1250, 76], [1250, 344], [729, 646], [694, 646]], Color("192440"))
	var pulse := pow(1 - MusicManager.beat_phase(), 3)
	for j in range(12, 0, -1):
		draw_circle(Vector2(1006, 356), 80 + j * 16, Color(0.35, 0.27, 1, 0.008 + pulse * 0.001))
	for i in 14:
		var x := 660.0 + i * 44
		draw_line(Vector2(x, 92), Vector2(x, 647), Color(0.5, 0.65, 1, 0.04), 1)
	for i in 13: draw_line(Vector2(658, 100 + i * 44), Vector2(1247, 100 + i * 44), Color(0.5, 0.65, 1, 0.04), 1)
	draw_line(Vector2(54, 83), Vector2(1225, 83), Color("24334c"), 1)
	draw_line(Vector2(58, 362), Vector2(644, 362), Color("2a3f58"), 1)
	draw_line(Vector2(58, 362), Vector2(212 + pulse * 30, 362), CYAN, 3, true)
	for i in 40:
		var p := Vector2(fposmod(i * 213.7 + clock * (9 + i % 5), 1280), fposmod(i * 71.3 - clock * 16, 720))
		var alpha := 0.07 + 0.12 * (0.5 + 0.5 * sin(clock + i))
		draw_circle(p, 1.0 if i % 3 else 2, Color(CYAN if i % 2 else VIOLET, alpha))
	for i in 3:
		draw_arc(Vector2(996, 345), 175 + i * 27, -1.9 + clock * .06 * (i + 1), .7 + clock * .06 * (i + 1), 60, Color(CYAN if i == 1 else VIOLET, .35 if i == 1 else .18), 2, true)
	# Distant campus silhouette maintains the university identity.
	for i in 7:
		var x := 685.0 + i * 85
		var h := 40 + (i * 43) % 110
		draw_rect(Rect2(x, 613 - h, 72, h), Color("12273a"))
		for j in 3: draw_rect(Rect2(x + 10 + j * 19, 627 - h, 8, 15), Color(0.2, 0.8, 0.75, .14))
	draw_set_transform(Vector2(910, 545) + mouse + Vector2(0, sin(clock * 1.7) * 3))
	hero()
	draw_set_transform(Vector2(1045, 286) + mouse * 1.5, -.13, Vector2.ONE * .95)
	eagle()
	draw_set_transform(Vector2.ZERO)
	for i in 27:
		var h := 4 + (0.5 + sin(i * 1.7 + clock * 2)) * (5 + pulse * 17)
		draw_rect(Rect2(833 + i * 12, 691 - h, 5, h), Color(CYAN if i % 3 else VIOLET, .6))

func hero() -> void:
	var spec: Dictionary = preload("res://scripts/characters.gd").spec(character_id)
	var skin := Color(spec.skin)
	var accent := Color(spec.primary)
	var hair := Color(spec.hair)
	# Ground halo, backpack, legs and layered technical jacket.
	draw_set_transform(Vector2(910, 545) + mouse, 0, Vector2(1, .22))
	draw_circle(Vector2(0, 0), 103, Color(0.1, 1, .8, .12))
	draw_set_transform(Vector2(910, 545) + mouse + Vector2(0, sin(clock * 1.7) * 3))
	poly([[-70, -233], [-27, -245], [24, -204], [15, -84], [-76, -92], [-94, -168]], Color("0b101d"))
	poly([[-71, -222], [-32, -230], [-9, -174], [-17, -102], [-73, -105], [-82, -163]], Color(spec.bag).darkened(.4))
	draw_line(Vector2(-77, -189), Vector2(-73, -126), Color(spec.bag), 4, true)
	poly([[-23, -121], [33, -111], [30, -70], [-6, 0], [-40, -3], [-25, -73]], Color("273850"))
	poly([[28, -113], [65, -109], [79, -64], [106, -20], [81, 0], [49, -54], [14, -82]], Color("1b2941"))
	draw_line(Vector2(56, -94), Vector2(81, -33), Color("52647d"), 3, true)
	poly([[-43, -13], [-9, -12], [7, 1], [7, 12], [-53, 12], [-55, 3]], Color("b8d4e0"))
	poly([[80, -15], [103, -25], [128, -12], [128, 0], [91, 13], [77, 6]], Color("a9becd"))
	draw_line(Vector2(-51, 10), Vector2(4, 10), accent, 4, true)
	draw_line(Vector2(92, 10), Vector2(126, -1), accent, 4, true)
	poly([[-36, -244], [9, -254], [48, -238], [70, -197], [57, -121], [-33, -121], [-47, -181]], Color("111a2c"))
	poly([[-31, -238], [3, -241], [1, -133], [-31, -132], [-40, -179]], accent.darkened(.45))
	poly([[13, -243], [45, -229], [59, -195], [48, -136], [15, -132]], accent.darkened(.6))
	poly([[-9, -244], [8, -227], [22, -243], [20, -158], [-8, -158]], Color("a5c4d2"))
	draw_line(Vector2(-20, -229), Vector2(-16, -139), Color(spec.accent), 5, true)
	draw_line(Vector2(16, -224), Vector2(17, -139), Color("7e9cbb"), 2, true)
	draw_line(Vector2(-40, -231), Vector2(-27, -149), Color("0b1121"), 11, true)
	draw_line(Vector2(-40, -231), Vector2(-27, -149), Color("526478"), 3, true)
	# Bent arm presents a holographic student credential.
	poly([[42, -226], [66, -219], [88, -179], [119, -187], [131, -166], [79, -149], [55, -169]], accent.darkened(.35))
	poly([[115, -190], [139, -198], [154, -188], [145, -169], [125, -168]], skin)
	poly([[-42, -229], [-61, -218], [-63, -157], [-45, -127], [-26, -140], [-43, -171]], accent.darkened(.2))
	draw_circle(Vector2(-34, -136), 10, skin)
	poly([[-6, -267], [18, -266], [22, -242], [8, -229], [-8, -244]], skin.darkened(.1))
	poly([[-33, -313], [-22, -338], [12, -343], [36, -324], [35, -290], [13, -263], [-13, -270], [-30, -288]], skin)
	poly([[-30, -315], [-18, -333], [15, -335], [31, -318], [29, -297], [13, -278], [5, -279], [8, -306]], skin.lightened(.12))
	poly([[-36, -307], [-39, -335], [-28, -354], [-7, -349], [6, -359], [31, -346], [43, -325], [24, -318], [4, -330], [-13, -312], [-22, -295]], hair)
	draw_line(Vector2(-26, -339), Vector2(-3, -345), hair.lightened(.25), 5, true)
	if character_id == "valeria": poly([[-33, -332], [-64, -332], [-76, -284], [-45, -299]], hair)
	if character_id == "sofia": draw_arc(Vector2(2, -313), 36, -PI, -.1, 24, Color(spec.accent), 5, true)
	for x in [9, 26]:
		draw_line(Vector2(x - 6, -308), Vector2(x + 2, -311), Color("30263a"), 3, true)
		draw_circle(Vector2(x, -300), 2.7, Color("14233b"))
		if character_id == "diego": draw_arc(Vector2(x, -300), 8, 0, TAU, 18, CYAN, 2, true)
	draw_line(Vector2(13, -282), Vector2(24, -285), Color("9c6459"), 2, true)
	# Rim lighting separates the figure from the arena illustration.
	draw_polyline(PackedVector2Array([Vector2(-35, -348), Vector2(-46, -333), Vector2(-42, -298), Vector2(-54, -238), Vector2(-68, -212), Vector2(-68, -169)]), Color(CYAN, .55), 3, true)
	for j in range(7, 0, -1): draw_rect(Rect2(134 - j, -247 - j, 65 + j * 2, 44 + j * 2), Color(.2, 1, .8, .012))
	draw_rect(Rect2(134, -247, 65, 44), Color(.08, .2, .25, .86))
	draw_rect(Rect2(134, -247, 65, 44), CYAN, false, 1.5)
	draw_circle(Vector2(149, -228), 6, CYAN)
	for j in 3: draw_line(Vector2(163, -238 + j * 9), Vector2(191 - j * 6, -238 + j * 9), Color(CYAN, .65), 2)

func eagle() -> void:
	var flap := sin(clock * 3.5) * 9
	for side in [-1, 1]:
		poly([[side * 8, 3], [side * 39, -27 - flap], [side * 117, -45 - flap], [side * 83, 7], [side * 30, 26]], Color("172941"))
		for j in range(6, 0, -1):
			var x: float = side * (25 + j * 12)
			poly([[side * 22, -6], [x, -35 - flap + j], [x + side * 14, -24 - flap], [side * (32 + j * 7), 13 + j]], Color("d9ae65").darkened(j * .065))
			draw_line(Vector2(x, -31 - flap), Vector2(side * (28 + j * 7), 12), Color("ffe0a1"), 1.5, true)
	poly([[-14, 8], [-20, 52], [0, 40], [18, 50], [12, 8]], Color("9a704b"))
	poly([[-15, -10], [-19, 12], [-1, 31], [17, 10], [13, -11]], Color("846548"))
	poly([[-10, -24], [5, -30], [25, -20], [27, -8], [8, 5], [-6, -1]], Color("fff0cd"))
	poly([[24, -17], [42, -7], [25, -3]], Color("ffd273"))
	draw_line(Vector2(13, -19), Vector2(24, -18), Color("20324c"), 3, true)
	draw_circle(Vector2(22, -14), 2.5, Color("1a2940"))
	draw_arc(Vector2(0, 0), 67, clock * .3, clock * .3 + 1.3, 28, Color(CYAN, .35), 2, true)
