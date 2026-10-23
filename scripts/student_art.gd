extends Node2D
var actor
const INK := Color("182944")
var styles: Dictionary = {}

func line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, INK, width + 3, true)
	draw_line(a, b, color, width, true)
	draw_circle(b, width / 2, color)

func _draw() -> void:
	if actor.invulnerable > 0 and actor.invulnerable < 3 and int(actor.anim_time * 16) % 2 == 0:
		return
	var t: float = actor.anim_time
	var profile: Dictionary = preload("res://scripts/characters.gd").spec(actor.character_id)
	var primary := Color(profile.primary)
	var dark := Color(profile.dark)
	var accent := Color(profile.accent)
	var hair := Color(profile.hair)
	var skin := Color(profile.skin)
	var moving: bool = absf(actor.velocity.x) > 20 and actor.is_on_floor()
	var gait := 15.0 if actor.character_id == "valeria" else (11.0 if actor.character_id == "diego" else 13.0)
	# Gameplay actors provide a pose; menu portraits fall back to the idle defaults.
	var pose_scale: Vector2 = actor.pose_scale if "pose_scale" in actor else Vector2.ONE
	var tilt: float = actor.pose_tilt if "pose_tilt" in actor else 0.0
	var phase: float = actor.run_phase if "run_phase" in actor else t * gait
	var frozen: bool = "hitstop" in actor and actor.hitstop > 0
	var stride: float = sin(phase) * ((15.0 if absf(actor.velocity.x) > 300 else 11.0) if moving else 0.0)
	var lift_a: float = maxf(0, cos(phase)) * 7 if moving else 0.0
	var lift_b: float = maxf(0, -cos(phase)) * 7 if moving else 0.0
	var bob: float = absf(sin(phase)) * 2.5 if moving else sin(t * 3) * 1.3
	var bend: float = 22 if actor.crouched else 0
	var airborne: bool = not actor.is_on_floor()
	var rising: bool = airborne and actor.velocity.y < 0
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	var jolt := Vector2(randf_range(-1.5, 1.5), 0) if frozen else Vector2.ZERO
	# Scale and tilt pivot on the feet, which is the node origin.
	draw_set_transform(Vector2(0, bob) + jolt, tilt, Vector2(actor.facing * pose_scale.x, pose_scale.y))
	if actor.coffee > 0:
		for i in 3:
			draw_line(Vector2(-24 - i * 9, -24 + i * 8), Vector2(-42 - i * 9, -24 + i * 8), Color("ffda75"), 2, true)
	# Backpack and straps.
	if actor.character_id == "valeria":
		draw_line(Vector2(-7, -69 + bend), Vector2(-26 - sin(t * 10) * 4, -48 + bend), hair, 13, true)
	if actor.character_id == "sofia": draw_style_box(box(hair, 6, 1), Rect2(-15, -70 + bend, 28, 31))
	draw_style_box(box(Color(profile.bag), 6, 2), Rect2(-24, -49 + bend, 21, 31))
	draw_style_box(box(Color("f5b65c"), 4, 2), Rect2(-27, -35 + bend, 10, 15))
	draw_line(Vector2(-20, -43 + bend), Vector2(-10, -43 + bend), Color("ffce87"), 2, true)
	draw_line(Vector2(-22, -27 + bend), Vector2(-18, -27 + bend), INK, 1.5, true)
	draw_arc(Vector2(-14, -48 + bend), 6, PI, TAU, 12, INK, 2, true)
	line(Vector2(-7, -43 + bend), Vector2(-15 + stride * 0.4, -26 + bend), Color("c88c6e"), 6)
	var hip := Vector2(0, -23 + bend * 0.5)
	var foot_a := Vector2(-7 + stride, -4 - lift_a)
	var foot_b := Vector2(9 - stride, -4 - lift_b)
	if airborne:
		foot_a = Vector2(-13, -15 if rising else -6)
		foot_b = Vector2(11, -5 if rising else -13)
	# Two-segment legs: knees bend forward and rise with the swinging foot.
	var knee_a := hip.lerp(foot_a, 0.5) + Vector2(4 + lift_a * 0.5, 0)
	var knee_b := hip.lerp(foot_b, 0.5) + Vector2(4 + lift_b * 0.5, 0)
	line(hip, knee_a, Color("354b70"), 9)
	line(knee_a, foot_a, Color("354b70"), 9)
	line(hip, knee_b, Color("48648b"), 9)
	line(knee_b, foot_b, Color("48648b"), 9)
	draw_style_box(box(Color("f6eee3"), 3, 2), Rect2(foot_a.x - 5, foot_a.y - 3, 16, 7))
	draw_style_box(box(Color("f6eee3"), 3, 2), Rect2(foot_b.x - 5, foot_b.y - 3, 16, 7))
	for foot in [foot_a, foot_b]:
		draw_line(foot + Vector2(-2, -1), foot + Vector2(6, -1), Color("75cfc9"), 2, true)
		draw_line(foot + Vector2(1, -4), foot + Vector2(3, -2), INK, 1, true)
		draw_line(foot + Vector2(5, -4), foot + Vector2(7, -2), INK, 1, true)
	draw_style_box(box(primary, 7, 2), Rect2(-12, -48 + bend, 30 if actor.character_id == "diego" else 27, 29 - bend * 0.4))
	# Hoodie panels, collar, drawstrings, pocket and institute-inspired badge.
	draw_style_box(box(dark, 4, 0), Rect2(-10, -30 + bend * 0.65, 22, 9))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -48 + bend), Vector2(0, -41 + bend), Vector2(8, -48 + bend)]), Color("c5e9d9"))
	draw_line(Vector2(-3, -43 + bend), Vector2(-4, -34 + bend), Color("f8ecd0"), 1.4, true)
	draw_line(Vector2(3, -43 + bend), Vector2(4, -35 + bend), Color("f8ecd0"), 1.4, true)
	draw_line(Vector2(-7, -45 + bend), Vector2(-7, -23 + bend * 0.6), Color("f3cd7a"), 3, true)
	draw_circle(Vector2(7, -35 + bend), 3, Color("fff3cc"))
	var hand := Vector2(12 - stride * 0.6, -24 + bend)
	if actor.attack_time > 0:
		hand = Vector2(37, -36 + bend)
		draw_arc(Vector2(22, -34), 29, -1.1, 1.1, 18, Color("b3fff0"), 5, true)
		if frozen:
			for i in 6:
				var ray := Vector2.from_angle(i * TAU / 6 + 0.3)
				draw_line(Vector2(44, -36) + ray * 6, Vector2(44, -36) + ray * 15, Color("fff6cf"), 3, true)
	elif actor.celebrating:
		hand = Vector2(23, -75)
	elif airborne:
		hand = Vector2(22, -48 if rising else -37)
	var shoulder := Vector2(9, -43 + bend)
	var elbow := shoulder.lerp(hand, 0.5) + Vector2(4, 3)
	line(shoulder, elbow, primary.darkened(0.08), 8)
	line(elbow, hand, skin, 6)
	draw_circle(hand, 4, skin.lightened(0.1))
	# Head, hair and expressive eyes.
	draw_circle(Vector2(2, -58 + bend), 15, INK)
	draw_circle(Vector2(2, -58 + bend), 13, skin)
	draw_circle(Vector2(6, -55 + bend), 10, skin.lightened(0.1))
	draw_circle(Vector2(-9, -67 + bend), 7, hair)
	draw_circle(Vector2(0, -70 + bend), 10, hair)
	draw_circle(Vector2(9, -68 + bend), 7, hair)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -65 + bend), Vector2(-6, -78 + bend), Vector2(1, -74 + bend), Vector2(9, -78 + bend), Vector2(17, -67 + bend), Vector2(8, -65 + bend), Vector2(2, -68 + bend), Vector2(-5, -62 + bend)]), hair)
	draw_arc(Vector2(0, -68 + bend), 9, -2.8, -1.2, 12, Color("3c465d"), 2.5, true)
	draw_circle(Vector2(-8, -56 + bend), 4, Color("e3a17e"))
	draw_arc(Vector2(-8, -56 + bend), 2, -1.4, 1.4, 8, Color("c28265"), 1, true)
	for eye_x in [4, 11]:
		if fmod(t, 4.1) < 0.12:
			draw_line(Vector2(eye_x - 1.5, -59 + bend), Vector2(eye_x + 1.5, -59 + bend), INK, 1.5, true)
		else:
			draw_circle(Vector2(eye_x, -59 + bend), 1.8, INK)
			draw_circle(Vector2(eye_x + 0.5, -59.7 + bend), 0.6, Color.WHITE)
	draw_line(Vector2(3, -63 + bend), Vector2(6, -64 + bend), INK, 1.2, true)
	draw_circle(Vector2(10, -53 + bend), 2, Color("ef9a81"))
	draw_arc(Vector2(7, -53 + bend), 4, 0.1, 1.5, 10, INK, 1.4, true)
	if actor.character_id == "valeria":
		draw_line(Vector2(-7, -67 + bend), Vector2(13, -69 + bend), accent, 3, true)
	elif actor.character_id == "diego":
		for eye_x in [4, 11]: draw_arc(Vector2(eye_x, -59 + bend), 4, 0, TAU, 12, Color("7ccee0"), 1.5, true)
	elif actor.character_id == "sofia":
		draw_arc(Vector2(0, -61 + bend), 14, -3, -0.2, 18, accent, 3, true)
		draw_circle(Vector2(-10, -56 + bend), 5, accent)
		draw_style_box(box(accent, 2, 1), Rect2(hand.x - 6, hand.y - 4, 9, 7))
		if actor is CharacterBody2D and actor.radar_time > 0:
			draw_arc(Vector2(0, -32), 35 + fmod(t * 95, 100), 0, TAU, 48, Color(accent, 0.5), 2, true)
	if Progress.data.shield:
		draw_arc(Vector2(0, -36), 43, 0, TAU, 48, Color(0.4, 0.95, 0.93, 0.5 + 0.2 * sin(t * 4)), 2, true)
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 21, Color(0.02, 0.06, 0.12, 0.23))
	draw_set_transform(Vector2.ZERO)

func box(color: Color, radius: int, border: int) -> StyleBoxFlat:
	var key := "%s_%d_%d" % [color.to_html(), radius, border]
	if styles.has(key): return styles[key]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	styles[key] = style
	return style
