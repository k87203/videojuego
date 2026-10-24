extends Node2D
var invulnerable := 0.0
var anim_time := 0.0
var velocity := Vector2.ZERO
var crouched := false
var facing := -1.0
var coffee := 0.0
var attack_time := 0.0
var celebrating := true
var character_id := ""
## Shop-only appearance override; never changes owned items or the equipped outfit.
var preview_outfit: Dictionary = {}

func _ready() -> void:
	if character_id == "": character_id = str(Progress.data.character)
	var art := Node2D.new()
	art.set_script(preload("res://scripts/student_art.gd"))
	art.actor = self
	add_child(art)

func is_on_floor() -> bool:
	return true

func _process(delta: float) -> void:
	anim_time += delta
	get_child(0).queue_redraw()
