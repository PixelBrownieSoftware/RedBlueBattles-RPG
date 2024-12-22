extends Resource
class_name battle_group_member

@export var character : battle_character_base
@export var skills : Array[rpg_skill]
@export var min_level : int = 1
@export var max_level : int = 1
@export var inclusion_flag_requirements : Array[global_flag]
@export var perma_death : bool = false

func check_flags() -> bool:
	for flag in inclusion_flag_requirements:
		if !GlobalVariables.check_flag(flag):
			return false
	return true
