extends RefCounted
## Shared palette and Godot Theme for every screen: menu, HUD, pause, results and dialogs.
const BG := Color("07121e")
const SURFACE := Color("101b30")
const PANEL := Color(0.04, 0.09, 0.16, 0.95)
const BORDER := Color("31425f")
const ACCENT := Color("67ffe3")
const ACCENT_HI := Color("a4ffec")
const MINT := Color("9affdf")
const VIOLET := Color("c2a7ff")
const TEXT := Color("eef5ff")
const MUTED := Color("8fa3c2")
const INK := Color("07121e")
const GOLD := Color("ffd47c")
const DANGER := Color("ff8fa0")
const OUTLINE := Color(0.01, 0.03, 0.07, 0.85)

static func build(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	# Outline and a soft drop shadow keep text legible over the moving campus.
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", OUTLINE)
	theme.set_constant("outline_size", "Label", 4)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)
	# Hovered buttons light up in the accent colors for clear feedback.
	button_styles(theme, "Button", SURFACE, ACCENT, TEXT, ACCENT)
	theme.set_type_variation("PrimaryButton", "Button")
	button_styles(theme, "PrimaryButton", ACCENT, ACCENT_HI, INK, VIOLET)
	theme.set_stylebox("panel", "Panel", flat(PANEL, 18, BORDER, 1, 10))
	theme.set_stylebox("background", "ProgressBar", flat(Color(0.02, 0.05, 0.1, 0.9), 6, BORDER, 1))
	theme.set_stylebox("fill", "ProgressBar", flat(Color("eb829c"), 6))
	theme.set_stylebox("slider", "HSlider", flat(Color(0.02, 0.05, 0.1, 0.9), 6, BORDER, 1))
	theme.set_stylebox("grabber_area", "HSlider", flat(ACCENT, 6))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT_HI, 6))
	return theme

static func button_styles(theme: Theme, type: String, base: Color, hover: Color, text: Color, focus: Color) -> void:
	theme.set_stylebox("normal", type, flat(base, 6, Color(0.65, 0.88, 0.88, 0.2), 1, 4))
	theme.set_stylebox("hover", type, flat(hover, 6, ACCENT_HI, 1, 12, Color(0.2, 1, 0.85, 0.25)))
	var pressed := flat(base.darkened(0.25), 6, ACCENT, 1)
	pressed.content_margin_top = 3
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("disabled", type, flat(Color("1a2436"), 6, Color(1, 1, 1, 0.06), 1))
	var ring := flat(Color(0, 0, 0, 0), 6, focus, 2)
	ring.draw_center = false
	theme.set_stylebox("focus", type, ring)
	theme.set_color("font_color", type, text)
	theme.set_color("font_hover_color", type, INK)
	theme.set_color("font_pressed_color", type, text)
	theme.set_color("font_focus_color", type, text)
	theme.set_color("font_hover_pressed_color", type, text)
	theme.set_color("font_disabled_color", type, Color("5d6b82"))
	theme.set_font_size("font_size", type, 20)

static func flat(color: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_width: int = 0, shadow: int = 0, shadow_color: Color = Color(0, 0, 0, 0.3)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_width)
	s.shadow_size = shadow
	s.shadow_color = shadow_color
	s.shadow_offset = Vector2(0, 2) if shadow > 0 else Vector2.ZERO
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s
