extends Resource
class_name battle_character_behaviour
@export var condition : BEHAVIOUR_CONDITION
@export var compare : NUMBER_COMP
@export_range(0,1,0.01) var percentage: float 
@export_range(-2,2,0.01) var elemental: float 
@export var exact_number: int
@export_range(0.0,1.0) var execution_chance : float

enum BEHAVIOUR_CONDITION
{
	TARGET_HP,
	ELEMENTAL_AFFINITY,
	ALWAYS,
	TURN_ROUNDS_ELAPSED
}

enum NUMBER_COMP{
	EQUAL,
	LESS,
	LESS_EQUAL,
	GREATER,
	GREATER_EQUAL
}
