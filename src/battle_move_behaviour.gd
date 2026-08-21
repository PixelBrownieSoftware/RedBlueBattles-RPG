# battle_move_behaviour.gd

extends Resource
class_name battle_move_behaviour

@export var behaviouir_conditions : Array[battle_character_behaviour]
@export var specific_skill : rpg_skill
@export var specific_element : element
@export var condition : MOVE_BEHAVIOUR_CONDITION

enum MOVE_BEHAVIOUR_CONDITION {
	SPECIFIC,
	ELEMENT,
	OFFENSIVE,
	SUPPORT,
}

func check_all_conditions(character: battle_character_data, target: battle_character_data, skill: rpg_skill, turn_number: int,round_number: int) -> bool:
	"""
	Check all behaviour conditions.
	If ANY condition is false, return false.
	If ALL conditions are true, return true.
	"""
	
	# Empty conditions = always true
	if behaviouir_conditions.is_empty():
		return true
	
	# Check each condition
	for behaviour_condition in behaviouir_conditions:
		if not behaviour_condition.check_cond(character, target, skill, turn_number,round_number):
			return false  # One failed, stop here
	
	# All passed
	return true


func get_conditions_description() -> String:
	"""Get human-readable description of all conditions"""
	
	var descriptions = []
	for condition in behaviouir_conditions:
		descriptions.append(condition.get_description())
	
	return " AND ".join(descriptions)
