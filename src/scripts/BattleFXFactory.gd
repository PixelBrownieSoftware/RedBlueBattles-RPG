extends Node
var hit_prefab = preload("res://objects/misc/hit_fx.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func spawn_damage_obj(user : battle_character_data, target : battle_character_data, number : int, pt : PRESS_TURN.PT):
	var actor = $"../Variables".get_actor(target)
	var hit = hit_prefab.instantiate()
	add_child(hit)
	hit.position = actor.position
	var is_player = $"../Variables".is_player_team(target)
	hit.set_values(number, is_player, target.assigned_data.character_colour)
