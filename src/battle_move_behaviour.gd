extends Resource
class_name battle_move_behaviour
@export var behaviouir_conditions : Array[battle_character_behaviour]
@export var specific_skill : rpg_skill
@export var specific_element : element
@export var condition : MOVE_BEHAVIOUR_CONDITION
enum MOVE_BEHAVIOUR_CONDITION
{
	SPECIFIC,
	ELEMENT,
	OFFENSIVE,
	SUPPORT,
}
