extends Resource
class_name battle_character_base
@export var name: String
@export var health : int = 1
@export var stamina : int = 4
@export var base_exp_score : int = 50
@export var base_exp_to_NL : int = 50
@export var stats : rpg_stats
@export var stat_increase : rpg_stats_increase
@export var skills : Array[rpg_skill]
@export var behaviour : Array[battle_move_behaviour]
@export var elemental_affinities : Array[elemental_affinity]
@export var character_colour : Color = Color.WHITE
@export var animation_player_loc : String
