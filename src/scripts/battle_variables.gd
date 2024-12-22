extends Node
class_name battle_variables

@export var is_player_turn : bool = false
@export var turn : int
@export var pressed_turn : int
@export var net_turn : int:
	get:
		return turn + pressed_turn

@export var current_character : battle_character_data
@export var target_character : battle_character_data
@export var selected_move : rpg_skill
@export var final_press_turn_flag : PRESS_TURN.PT
@export var targets : Array[battle_character_data]
@export var all_actors : Array[battle_character_actor]:
	get:
		var returned_actors : Array[battle_character_actor]
		returned_actors.append_array(($"../BattleActors/Actors".get_children() as Array[battle_character_actor]))
		return returned_actors

func get_actor(char_data : battle_character_data) -> battle_character_actor:
	for chara_actor : battle_character_actor in all_actors:
		if chara_actor.character_data == char_data:
			return chara_actor
	return null
