extends Node2D
## Draws the exact outfit/character sold, without granting or equipping the item.
var product_id := ""
var character_id := "alex"

func _ready() -> void:
	var item: Dictionary = Progress.SHOP.get(product_id, {})
	if item.get("slot", "") == "upgrade": return
	var portrait := Node2D.new()
	portrait.set_script(preload("res://scripts/menu_actor.gd"))
	portrait.character_id = product_id if item.get("slot", "") == "character" else character_id
	portrait.preview_outfit = {"skin": "", "accessory": ""}
	if item.get("slot", "") == "skin": portrait.preview_outfit.skin = product_id
	if item.get("slot", "") == "accessory": portrait.preview_outfit.accessory = product_id
	portrait.celebrating = false
	portrait.facing = 1
	portrait.scale = Vector2(1.12, 1.12)
	add_child(portrait)

func _draw() -> void:
	draw_circle(Vector2(0, -47), 46, Color("163044"))
	draw_arc(Vector2(0, -47), 46, 0, TAU, 48, Color(0.4, 1, 0.85, 0.18), 1.5, true)
	if product_id != "heart": return
	var pink := Color("ff8299")
	var ink := Color("182944")
	for offset in [0, 3]:
		var tint: Color = ink if offset == 0 else pink
		var radius: int = 15 - offset
		draw_circle(Vector2(-12, -57), radius, tint)
		draw_circle(Vector2(12, -57), radius, tint)
		draw_colored_polygon(PackedVector2Array([Vector2(-27 + offset, -56), Vector2(27 - offset, -56), Vector2(0, -23 - offset)]), tint)
	draw_string(ThemeDB.fallback_font, Vector2(-13, -8), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe1a0"))
